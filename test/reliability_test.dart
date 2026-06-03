import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';
import 'package:yamilink/core/state/peer_manager.dart';
import 'package:yamilink/core/state/session_manager.dart';
import 'package:yamilink/models.dart';

void main() {
  group('YamiLink Reliability Layer Tests', () {
    test(
      'Incoming direct message produces ACK and avoids duplicate duplicates',
      () {
        final List<Frame> sentAcks = [];
        int changesCount = 0;

        final sessionManager = SessionManager(
          onChanged: () {
            changesCount++;
          },
          onRetransmit: (frame) {
            sentAcks.add(frame);
          },
        );

        final frame = Frame(
          type: FrameType.directMsg,
          senderId: 'peer_1',
          recipientId: 'user_node',
          sessionId: 'sess_abc',
          messageId: 101,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          payloadBody: 'Hello, this is a private message.',
        );

        sessionManager.processIncomingFrame(frame, 'Alice', 123);
        expect(sessionManager.getDirectMessages('peer_1').length, 1);
        expect(
          sessionManager.getDirectMessages('peer_1').first.content,
          'Hello, this is a private message.',
        );
        expect(sentAcks.length, 1);
        expect(sentAcks.first.type, FrameType.ack);
        expect(sentAcks.first.messageId, 101);

        final initialChanges = changesCount;

        sessionManager.processIncomingFrame(frame, 'Alice', 123);
        expect(sessionManager.getDirectMessages('peer_1').length, 1);
        expect(sentAcks.length, 2);
        expect(sentAcks.last.messageId, 101);
        expect(changesCount, initialChanges);
      },
    );

    test('Outgoing direct message status transitions to delivered on ACK', () {
      final List<Frame> retransmissions = [];
      final sessionManager = SessionManager(
        onChanged: () {},
        onRetransmit: (frame) {
          retransmissions.add(frame);
        },
      );

      final frame = Frame(
        type: FrameType.directMsg,
        senderId: 'user_node',
        recipientId: 'peer_1',
        sessionId: 'sess_abc',
        messageId: 202,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payloadBody: 'Direct question?',
      );

      final message = Message(
        id: 'msg_202',
        senderId: 'user_node',
        senderAlias: 'User',
        recipientId: 'peer_1',
        content: 'Direct question?',
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );

      sessionManager.addOutgoingMessage(message, frame);

      final messages = sessionManager.getDirectMessages('peer_1');
      expect(messages.length, 1);
      expect(messages.first.status, MessageStatus.sending);

      final ackFrame = Frame(
        type: FrameType.ack,
        senderId: 'peer_1',
        recipientId: 'user_node',
        sessionId: 'sess_abc',
        messageId: 202,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payloadBody: '',
      );

      sessionManager.processIncomingFrame(ackFrame, 'Alice', 0);
      expect(messages.first.status, MessageStatus.delivered);
    });

    test(
      'Outgoing direct message status transitions to failed on retry exhaustion',
      () async {
        final List<Frame> retransmissions = [];
        final sessionManager = SessionManager(
          onChanged: () {},
          onRetransmit: (frame) {
            retransmissions.add(frame);
          },
        );

        final frame = Frame(
          type: FrameType.directMsg,
          senderId: 'user_node',
          recipientId: 'peer_1',
          sessionId: 'sess_abc',
          messageId: 303,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          payloadBody: 'Hello?',
        );

        final message = Message(
          id: 'msg_303',
          senderId: 'user_node',
          senderAlias: 'User',
          recipientId: 'peer_1',
          content: 'Hello?',
          timestamp: DateTime.now(),
          status: MessageStatus.sending,
        );

        sessionManager.addOutgoingMessage(message, frame);

        await Future.delayed(const Duration(milliseconds: 1800));

        final messages = sessionManager.getDirectMessages('peer_1');
        expect(messages.first.status, MessageStatus.failed);
        expect(retransmissions.length, 3);
      },
    );
    group('PeerManager Sweep Tests', () {
      test('Stale peer transitions to unknown proximity and is deleted', () {
        int peerChanges = 0;
        final peerManager = PeerManager(
          onChanged: () {
            peerChanges++;
          },
        );

        peerManager.handlePeerFound(
          id: 'peer_test',
          alias: 'Tester',
          seed: 123,
          signal: 0.9,
        );

        expect(peerChanges, 1);

        expect(peerManager.peers.length, 1);
        expect(peerManager.peers.first.proximityHint, ProximityHint.immediate);

        peerManager.peers.first.lastSeen = DateTime.now().subtract(
          const Duration(seconds: 11),
        );
        peerManager.sweepStalePeers();
        expect(peerManager.peers.length, 1);
        expect(peerManager.peers.first.proximityHint, ProximityHint.unknown);

        peerManager.peers.first.lastSeen = DateTime.now().subtract(
          const Duration(seconds: 16),
        );
        peerManager.sweepStalePeers();
        expect(peerManager.peers.isEmpty, true);
      });
    });

    group('Conversation and Unread Tests', () {
      test(
        'Conversation is created and sorted on direct message transmission',
        () {
          final sessionManager = SessionManager(
            onChanged: () {},
            onRetransmit: (_) {},
          );

          final frame1 = Frame(
            type: FrameType.directMsg,
            senderId: 'user_node',
            recipientId: 'peer_1',
            sessionId: 'sess_abc',
            messageId: 401,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            payloadBody: 'Msg 1',
          );
          final msg1 = Message(
            id: 'msg_401',
            senderId: 'user_node',
            senderAlias: 'User',
            recipientId: 'peer_1',
            content: 'Msg 1',
            timestamp: DateTime.now(),
          );

          sessionManager.addOutgoingMessage(
            msg1,
            frame1,
            peerAlias: 'Alice',
            peerAvatarSeed: 123,
          );
          expect(sessionManager.conversations.length, 1);
          expect(sessionManager.conversations.first.peerId, 'peer_1');
          expect(sessionManager.conversations.first.lastMessage, 'Msg 1');

          final frame2 = Frame(
            type: FrameType.directMsg,
            senderId: 'user_node',
            recipientId: 'peer_2',
            sessionId: 'sess_abc',
            messageId: 402,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            payloadBody: 'Msg 2',
          );
          final msg2 = Message(
            id: 'msg_402',
            senderId: 'user_node',
            senderAlias: 'User',
            recipientId: 'peer_2',
            content: 'Msg 2',
            timestamp: DateTime.now(),
          );

          sessionManager.addOutgoingMessage(
            msg2,
            frame2,
            peerAlias: 'Bob',
            peerAvatarSeed: 456,
          );
          expect(sessionManager.conversations.length, 2);

          expect(sessionManager.conversations.first.peerId, 'peer_2');
        },
      );

      test('Unread counts increment only when conversation is not active', () {
        final sessionManager = SessionManager(
          onChanged: () {},
          onRetransmit: (_) {},
        );

        final frame = Frame(
          type: FrameType.directMsg,
          senderId: 'peer_1',
          recipientId: 'user_node',
          sessionId: 'sess_abc',
          messageId: 501,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          payloadBody: 'Msg 1',
        );

        sessionManager.activeConversationId = null;
        sessionManager.processIncomingFrame(frame, 'Alice', 123);
        expect(sessionManager.conversations.first.unreadCount, 1);

        sessionManager.activeConversationId = 'peer_1';
        final frame2 = Frame(
          type: FrameType.directMsg,
          senderId: 'peer_1',
          recipientId: 'user_node',
          sessionId: 'sess_abc',
          messageId: 502,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          payloadBody: 'Msg 2',
        );
        sessionManager.processIncomingFrame(frame2, 'Alice', 123);

        expect(sessionManager.conversations.first.unreadCount, 1);

        sessionManager.markAsRead('peer_1');
        expect(sessionManager.conversations.first.unreadCount, 0);
      });

      test('syncPeerOnlineStatus correctly updates online statuses', () {
        final sessionManager = SessionManager(
          onChanged: () {},
          onRetransmit: (_) {},
        );

        final frame = Frame(
          type: FrameType.directMsg,
          senderId: 'peer_1',
          recipientId: 'user_node',
          sessionId: 'sess_abc',
          messageId: 601,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          payloadBody: 'Hi',
        );

        sessionManager.processIncomingFrame(frame, 'Alice', 123);
        expect(sessionManager.conversations.first.isPeerOnline, true);

        sessionManager.syncPeerOnlineStatus([]);
        expect(sessionManager.conversations.first.isPeerOnline, false);

        sessionManager.syncPeerOnlineStatus(['peer_1']);
        expect(sessionManager.conversations.first.isPeerOnline, true);
      });
    });
  });
}
