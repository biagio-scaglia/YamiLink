import '../../models.dart';
import '../protocol/frame.dart';

class SessionRoom {
  final String localNodeId;
  final List<LocalRoomMessage> _roomMessages = [];
  final void Function() _onChanged;

  final Set<String> _processedMessageKeys = {};
  final List<String> _processedMessageHistory = [];

  SessionRoom({
    required this.localNodeId,
    required void Function() onChanged,
  }) : _onChanged = onChanged;

  List<LocalRoomMessage> get roomMessages => List.unmodifiable(_roomMessages);

  void addOutgoingMessage(
    LocalRoomMessage message,
    Frame frame,
  ) {
    _roomMessages.add(message);
    _onChanged();
  }

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
        final msg = LocalRoomMessage(
          id: 'msg_recv_${frame.timestamp}_${frame.messageId}',
          senderId: frame.senderId,
          senderAlias: senderAlias,
          content: frame.payloadBody,
          timestamp: DateTime.fromMillisecondsSinceEpoch(frame.timestamp),
          status: MessageStatus.delivered,
          hopCount: frame.hopCount,
          isFlagged: isFlagged,
          isBlurred: isBlurred,
          moderationExplanation: moderationExplanation,
        );
        _roomMessages.add(msg);
        _onChanged();
        break;

      default:
        break;
    }
  }

  void loadInitialHistory(List<LocalRoomMessage> history) {
    _roomMessages.addAll(history);
    _onChanged();
  }

  void clear() {
    _roomMessages.clear();
    _processedMessageKeys.clear();
    _processedMessageHistory.clear();
    _onChanged();
  }
}
