import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/moderation/moderation_engine.dart';
import 'package:yamilink/core/state/peer_manager.dart';

void main() {
  group('Content Moderation Engine Tests', () {
    final engine = ModerationEngine.instance;

    test('Text Normalization ignores casing, spaces, and punctuation symbols', () {
      expect(engine.normalize('Hello World!'), 'helloworld');
      expect(engine.normalize('s.p.a.m.m.i.n.g'), 'spamming');
      expect(engine.normalize('t_h-r_e!a?t'), 'threat');
      expect(engine.normalize('K-I-L-L*Y-O-U'), 'killyou');
    });

    test('Clean text is classified as allowed and not blurred', () {
      final result = engine.analyze('This is a friendly message.');
      expect(result.isAllowed, isTrue);
      expect(result.shouldBlur, isFalse);
      expect(result.classification, 'clean');
    });

    test('Sensitive text triggers yellow card (allowed but blurred)', () {
      final result = engine.analyze('Watch out, this might be a s.c.a.m!');
      expect(result.isAllowed, isTrue);
      expect(result.shouldBlur, isTrue);
      expect(result.classification, 'sensitive');
      expect(result.ruleName, isNotEmpty);
    });

    test('Disallowed text triggers red card (blocked completely)', () {
      final result = engine.analyze('I am going to k.i.l.l.y.o.u!');
      expect(result.isAllowed, isFalse);
      expect(result.shouldBlur, isTrue);
      expect(result.classification, 'disallowed');
      expect(result.ruleName, isNotEmpty);
    });
  });

  group('PeerManager Spam Auto-Blocking Tests', () {
    test('Spam burst auto-detects and blocks peer (>5 messages in 3 seconds)', () {
      final peerManager = PeerManager(onChanged: () {});
      final peerId = 'spammer_node_1';

      // Discovered peer first
      peerManager.handlePeerFound(
        id: peerId,
        alias: 'SpammyNode',
        seed: 42,
        signal: 0.9,
      );

      expect(peerManager.isBlocked(peerId), isFalse);

      // Send 5 messages: should not trigger block yet
      for (int i = 0; i < 5; i++) {
        final isSpam = peerManager.registerMessageAndCheckSpam(peerId);
        expect(isSpam, isFalse, reason: 'Message $i should not be classified as spam yet');
      }

      // Send 6th message: should trigger block
      final isSpam6 = peerManager.registerMessageAndCheckSpam(peerId);
      expect(isSpam6, isTrue, reason: '6th message in burst should trigger block');
      expect(peerManager.isBlocked(peerId), isTrue);

      // Subsequent messages are blocked
      expect(peerManager.registerMessageAndCheckSpam(peerId), isTrue);
    });
  });
}
