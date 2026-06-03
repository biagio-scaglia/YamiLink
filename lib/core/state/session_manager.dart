import 'dart:async';
import '../../models.dart';
import '../protocol/frame.dart';

class PendingTransmission {
  final Frame frame;
  int retriesLeft;
  Timer? timer;

  PendingTransmission({required this.frame, this.retriesLeft = 3});
}

class SessionManager {
  final List<Message> _roomMessages = [];
  final Map<String, List<Message>> _directMessages = {};
  final List<Conversation> _conversations = [];
  final void Function() _onChanged;
  final void Function(Frame frame) _onRetransmit;

  String? activeConversationId;

  final Set<String> _processedMessageKeys = {};
  final List<String> _processedMessageHistory = [];

  final Map<String, PendingTransmission> _pendingTransmissions = {};

  SessionManager({
    required void Function() onChanged,
    required void Function(Frame frame) onRetransmit,
  }) : _onChanged = onChanged,
       _onRetransmit = onRetransmit;

  List<Message> get roomMessages => List.unmodifiable(_roomMessages);
  List<Conversation> get conversations => List.unmodifiable(_conversations);

  List<Message> getDirectMessages(String peerId) =>
      List.unmodifiable(_directMessages[peerId] ?? []);

  Conversation _getOrCreateConversation(
    String peerId,
    String peerAlias,
    int peerAvatarSeed,
  ) {
    final index = _conversations.indexWhere((c) => c.peerId == peerId);
    if (index == -1) {
      final newConv = Conversation(
        id: peerId,
        peerId: peerId,
        peerAlias: peerAlias,
        peerAvatarSeed: peerAvatarSeed,
        lastMessage: '',
        lastTimestamp: DateTime.now(),
        messages: [],
        isPeerOnline: true,
      );
      _conversations.add(newConv);
      return newConv;
    }
    return _conversations[index];
  }

  /// Adds a message sent by the user to the local list, initializing its status to sending.
  void addOutgoingMessage(
    Message message,
    Frame frame, {
    String? peerAlias,
    int? peerAvatarSeed,
  }) {
    if (message.recipientId == null) {
      _roomMessages.add(message);
    } else {
      final peerId = message.recipientId!;
      _directMessages.putIfAbsent(peerId, () => []).add(message);

      final conv = _getOrCreateConversation(
        peerId,
        peerAlias ?? 'External Peer',
        peerAvatarSeed ?? 0,
      );
      conv.messages.add(message);
      conv.lastMessage = message.content;
      conv.lastTimestamp = message.timestamp;
      conv.isPeerOnline = true;

      _conversations.remove(conv);
      _conversations.insert(0, conv);

      final key = '$peerId:${frame.messageId}';
      final pending = PendingTransmission(frame: frame);
      _pendingTransmissions[key] = pending;
      _startRetryTimer(key);
    }
    _onChanged();
  }

  /// Process incoming frames
  void processIncomingFrame(
    Frame frame,
    String senderAlias,
    int avatarSeed, {
    bool isFlagged = false,
    bool isBlurred = false,
    String? moderationExplanation,
  }) {
    final dupKey = '${frame.senderId}:${frame.messageId}';
    if (_processedMessageKeys.contains(dupKey)) {
      if (frame.type == FrameType.directMsg) {
        _sendAck(frame);
      }
      return;
    }

    _processedMessageKeys.add(dupKey);
    _processedMessageHistory.add(dupKey);
    if (_processedMessageHistory.length > 50) {
      final oldKey = _processedMessageHistory.removeAt(0);
      _processedMessageKeys.remove(oldKey);
    }

    switch (frame.type) {
      case FrameType.roomMsg:
        final msg = Message(
          id: 'msg_recv_${frame.timestamp}_${frame.messageId}',
          senderId: frame.senderId,
          senderAlias: senderAlias,
          content: frame.payloadBody,
          timestamp: DateTime.fromMillisecondsSinceEpoch(frame.timestamp),
          status: MessageStatus.delivered,
          isFlagged: isFlagged,
          isBlurred: isBlurred,
          moderationExplanation: moderationExplanation,
        );
        _roomMessages.add(msg);
        _onChanged();
        break;

      case FrameType.directMsg:
        final msg = Message(
          id: 'msg_dm_recv_${frame.timestamp}_${frame.messageId}',
          senderId: frame.senderId,
          senderAlias: senderAlias,
          recipientId: frame.recipientId,
          content: frame.payloadBody,
          timestamp: DateTime.fromMillisecondsSinceEpoch(frame.timestamp),
          status: MessageStatus.delivered,
          isFlagged: isFlagged,
          isBlurred: isBlurred,
          moderationExplanation: moderationExplanation,
        );
        _directMessages.putIfAbsent(frame.senderId, () => []).add(msg);

        final conv = _getOrCreateConversation(
          frame.senderId,
          senderAlias,
          avatarSeed,
        );
        conv.messages.add(msg);
        conv.lastMessage = msg.content;
        conv.lastTimestamp = msg.timestamp;
        conv.isPeerOnline = true;

        if (activeConversationId != frame.senderId) {
          conv.unreadCount++;
        }

        _conversations.remove(conv);
        _conversations.insert(0, conv);

        _onChanged();

        _sendAck(frame);
        break;

      case FrameType.ack:
        final ackKey = '${frame.senderId}:${frame.messageId}';
        final pending = _pendingTransmissions.remove(ackKey);
        if (pending != null) {
          pending.timer?.cancel();

          final peerId = frame.senderId;
          final dms = _directMessages[peerId];
          if (dms != null) {
            final msgIndex = dms.indexWhere(
              (m) => m.status == MessageStatus.sending,
            );
            if (msgIndex != -1) {
              dms[msgIndex].status = MessageStatus.delivered;
              _onChanged();
            }
          }
        }
        break;

      case FrameType.beacon:
      case FrameType.hello:
      case FrameType.goodbye:
      case FrameType.error:
        break;
    }
  }

  void _sendAck(Frame frame) {
    final ackFrame = Frame(
      type: FrameType.ack,
      senderId: frame.recipientId,
      recipientId: frame.senderId,
      sessionId: frame.sessionId,
      messageId: frame.messageId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      payloadBody: '',
    );
    _onRetransmit(ackFrame);
  }

  void _startRetryTimer(String key) {
    final pending = _pendingTransmissions[key];
    if (pending == null) return;

    pending.timer?.cancel();
    pending.timer = Timer(const Duration(milliseconds: 400), () {
      _handleRetry(key);
    });
  }

  void _handleRetry(String key) {
    final pending = _pendingTransmissions[key];
    if (pending == null) return;

    if (pending.retriesLeft > 0) {
      pending.retriesLeft--;
      _onRetransmit(pending.frame);
      _startRetryTimer(key);
    } else {
      _pendingTransmissions.remove(key);
      final parts = key.split(':');
      final peerId = parts[0];
      final dms = _directMessages[peerId];
      if (dms != null) {
        final msgIndex = dms.indexWhere(
          (m) => m.status == MessageStatus.sending,
        );
        if (msgIndex != -1) {
          dms[msgIndex].status = MessageStatus.failed;
          _onChanged();
        }
      }
    }
  }

  void markAsRead(String peerId) {
    final index = _conversations.indexWhere((c) => c.peerId == peerId);
    if (index != -1) {
      if (_conversations[index].unreadCount > 0) {
        _conversations[index].unreadCount = 0;
        _onChanged();
      }
    }
  }

  void syncPeerOnlineStatus(List<String> onlinePeerIds) {
    bool changed = false;
    for (var conv in _conversations) {
      final wasOnline = conv.isPeerOnline;
      final isOnline = onlinePeerIds.contains(conv.peerId);
      if (wasOnline != isOnline) {
        conv.isPeerOnline = isOnline;
        changed = true;
      }
    }
    if (changed) {
      _onChanged();
    }
  }

  void loadInitialHistory(List<Message> history) {
    _roomMessages.addAll(history);
    _onChanged();
  }

  void clear() {
    _roomMessages.clear();
    _directMessages.clear();
    _conversations.clear();
    for (var pending in _pendingTransmissions.values) {
      pending.timer?.cancel();
    }
    _pendingTransmissions.clear();
    _processedMessageKeys.clear();
    _processedMessageHistory.clear();
    _onChanged();
  }
}
