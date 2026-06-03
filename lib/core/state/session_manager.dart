import 'dart:async';
import '../../models.dart';
import '../protocol/frame.dart';

class PendingTransmission {
  final Frame frame;
  int retriesLeft;
  Timer? timer;

  PendingTransmission({
    required this.frame,
    this.retriesLeft = 3,
  });
}

class SessionManager {
  final List<Message> _roomMessages = [];
  final Map<String, List<Message>> _directMessages = {};
  final void Function() _onChanged;
  final void Function(Frame frame) _onRetransmit;

  // Deduplication: maximum 50 processed message IDs per sender hash
  // Keep key as "senderId:messageId"
  final Set<String> _processedMessageKeys = {};
  final List<String> _processedMessageHistory = [];

  // Reliability Queue: "recipientId:messageId" -> pending transmission
  final Map<String, PendingTransmission> _pendingTransmissions = {};

  SessionManager({
    required void Function() onChanged,
    required void Function(Frame frame) onRetransmit,
  })  : _onChanged = onChanged,
        _onRetransmit = onRetransmit;

  List<Message> get roomMessages => List.unmodifiable(_roomMessages);
  
  List<Message> getDirectMessages(String peerId) =>
      List.unmodifiable(_directMessages[peerId] ?? []);

  /// Adds a message sent by the user to the local list, initializing its status to sending.
  void addOutgoingMessage(Message message, Frame frame) {
    if (message.recipientId == null) {
      _roomMessages.add(message);
    } else {
      _directMessages.putIfAbsent(message.recipientId!, () => []).add(message);
      
      // Direct message requires reliability tracking
      final key = '${message.recipientId}:${frame.messageId}';
      final pending = PendingTransmission(frame: frame);
      _pendingTransmissions[key] = pending;
      _startRetryTimer(key);
    }
    _onChanged();
  }

  /// Process incoming frames
  void processIncomingFrame(Frame frame, String senderAlias) {
    // 1. Deduplication check
    final dupKey = '${frame.senderId}:${frame.messageId}';
    if (_processedMessageKeys.contains(dupKey)) {
      // Discard duplicate payloads, but if it is a message type that requires ACKs (like directMsg),
      // we must still send back the ACK just in case our previous ACK was lost.
      if (frame.type == FrameType.directMsg) {
        _sendAck(frame);
      }
      return;
    }

    // Cache message key for deduplication
    _processedMessageKeys.add(dupKey);
    _processedMessageHistory.add(dupKey);
    if (_processedMessageHistory.length > 50) {
      final oldKey = _processedMessageHistory.removeAt(0);
      _processedMessageKeys.remove(oldKey);
    }

    // 2. Route by type
    switch (frame.type) {
      case FrameType.roomMsg:
        final msg = Message(
          id: 'msg_recv_${frame.timestamp}_${frame.messageId}',
          senderId: frame.senderId,
          senderAlias: senderAlias,
          content: frame.payloadBody,
          timestamp: DateTime.fromMillisecondsSinceEpoch(frame.timestamp),
          status: MessageStatus.delivered,
        );
        _roomMessages.add(msg);
        _onChanged();
        break;

      case FrameType.directMsg:
        // Add direct message
        final msg = Message(
          id: 'msg_dm_recv_${frame.timestamp}_${frame.messageId}',
          senderId: frame.senderId,
          senderAlias: senderAlias,
          recipientId: frame.recipientId,
          content: frame.payloadBody,
          timestamp: DateTime.fromMillisecondsSinceEpoch(frame.timestamp),
          status: MessageStatus.delivered,
        );
        _directMessages.putIfAbsent(frame.senderId, () => []).add(msg);
        _onChanged();

        // Immediately send back an ACK frame
        _sendAck(frame);
        break;

      case FrameType.ack:
        // Match ACK
        final ackKey = '${frame.senderId}:${frame.messageId}';
        final pending = _pendingTransmissions.remove(ackKey);
        if (pending != null) {
          pending.timer?.cancel();
          // Update message status in our direct message history
          final peerId = frame.senderId;
          final dms = _directMessages[peerId];
          if (dms != null) {
            // Find message with matching message ID in the payload metadata or timestamp
            final msgIndex = dms.indexWhere((m) => m.status == MessageStatus.sending);
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
        // Handled by PeerManager or discarded for now
        break;
    }
  }

  void _sendAck(Frame frame) {
    // Send ACK to sender of the message
    final ackFrame = Frame(
      type: FrameType.ack,
      senderId: frame.recipientId, // We are sender of the ACK
      recipientId: frame.senderId,
      sessionId: frame.sessionId,
      messageId: frame.messageId, // Message ID being acknowledged
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
      // Max retries reached. Mark message as failed.
      _pendingTransmissions.remove(key);
      final parts = key.split(':');
      final peerId = parts[0];
      final dms = _directMessages[peerId];
      if (dms != null) {
        final msgIndex = dms.indexWhere((m) => m.status == MessageStatus.sending);
        if (msgIndex != -1) {
          dms[msgIndex].status = MessageStatus.failed;
          _onChanged();
        }
      }
    }
  }

  void loadInitialHistory(List<Message> history) {
    _roomMessages.addAll(history);
    _onChanged();
  }

  void clear() {
    _roomMessages.clear();
    _directMessages.clear();
    for (var pending in _pendingTransmissions.values) {
      pending.timer?.cancel();
    }
    _pendingTransmissions.clear();
    _processedMessageKeys.clear();
    _processedMessageHistory.clear();
    _onChanged();
  }
}
