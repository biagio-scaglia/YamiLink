import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';
import 'package:yamilink/core/state/peer_manager.dart';
import 'package:yamilink/core/state/session_manager.dart';
import 'package:yamilink/models.dart';

void main() {
  group('YamiLink Reliability Layer Tests', () {
    test('Incoming direct message produces ACK and avoids duplicate duplicates', () {
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

      // First receipt: process the message, verify it is logged and ACK is sent
      sessionManager.processIncomingFrame(frame, 'Alice');
      expect(sessionManager.getDirectMessages('peer_1').length, 1);
      expect(sessionManager.getDirectMessages('peer_1').first.content, 'Hello, this is a private message.');
      expect(sentAcks.length, 1);
      expect(sentAcks.first.type, FrameType.ack);
      expect(sentAcks.first.messageId, 101);

      final initialChanges = changesCount;

      // Second receipt: same frame is received (e.g. sender did not get our ACK).
      // Verify message is not duplicated, but a new ACK is sent.
      sessionManager.processIncomingFrame(frame, 'Alice');
      expect(sessionManager.getDirectMessages('peer_1').length, 1);
      expect(sentAcks.length, 2);
      expect(sentAcks.last.messageId, 101);
      expect(changesCount, initialChanges); // No change event since it was a duplicate payload
    });

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

      // Simulate receiving matching ACK from peer
      final ackFrame = Frame(
        type: FrameType.ack,
        senderId: 'peer_1',
        recipientId: 'user_node',
        sessionId: 'sess_abc',
        messageId: 202,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payloadBody: '',
      );

      sessionManager.processIncomingFrame(ackFrame, 'Alice');
      expect(messages.first.status, MessageStatus.delivered);
    });

    test('Outgoing direct message status transitions to failed on retry exhaustion', () async {
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

      // Wait for retry intervals to fire (3 retries * 400ms = 1200ms + 400ms failure wait)
      await Future.delayed(const Duration(milliseconds: 1800));

      final messages = sessionManager.getDirectMessages('peer_1');
      expect(messages.first.status, MessageStatus.failed);
      expect(retransmissions.length, 3); // 3 retries attempted
    });
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

        expect(peerManager.peers.length, 1);
        expect(peerManager.peers.first.proximityHint, ProximityHint.immediate);

        // Simulate passage of 11 seconds
        peerManager.peers.first.lastSeen = DateTime.now().subtract(const Duration(seconds: 11));
        peerManager.sweepStalePeers();
        expect(peerManager.peers.length, 1);
        expect(peerManager.peers.first.proximityHint, ProximityHint.unknown);

        // Simulate passage of 16 seconds
        peerManager.peers.first.lastSeen = DateTime.now().subtract(const Duration(seconds: 16));
        peerManager.sweepStalePeers();
        expect(peerManager.peers.isEmpty, true);
      });
    });
  });
}
