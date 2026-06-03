import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/moderation/keyword_risk_scorer.dart';
import 'package:yamilink/core/moderation/moderation_models.dart';
import 'package:yamilink/core/moderation/moderation_service.dart';
import 'package:yamilink/core/moderation/spam_heuristic_engine.dart';

void main() {
  setUp(() {
    ModerationService.instance.clear();
  });

  group('Text Normalization Tests', () {
    final service = ModerationService.instance;

    test('ignores spaces, punctuation, symbols, and casing', () {
      expect(service.normalize('Hello World!'), 'helloworld');
      expect(service.normalize('s.p.a.m.m.i.n.g'), 'spamming');
      expect(service.normalize('t_h-r_e!a?t'), 'threat');
    });

    test('compresses repeated characters (3+ repeats down to 1)', () {
      expect(service.normalize('kiiiill'), 'kill');
      expect(service.normalize('sspamm'), 'sspamm');
      expect(service.normalize('ssspammm'), 'spam');
      expect(service.normalize('loooooove'), 'love');
    });
  });

  group('Keyword Risk Scorer Tests', () {
    final scorer = KeywordRiskScorer.instance;

    test('Clean text returns clean score', () {
      final res = scorer.score('friendlymessage');
      expect(res['riskScore'], 0.0);
      expect(matchedList(res['matchedRules']), isEmpty);
    });

    test('Insults and vulgarity trigger warnings (Yellow)', () {
      final res = scorer.score('thisisstupid');
      expect(res['riskScore'], 1.0);
      expect(matchedList(res['matchedRules']), contains('Insulto'));
    });

    test('Threats and doxxing trigger severe results (Red)', () {
      final res = scorer.score('iwillkillyou');
      expect(res['riskScore'], 5.0);
      expect(
        matchedList(res['matchedRules']),
        contains('Minaccia di violenza'),
      );
    });
  });

  group('Spam & Duplicate Heuristics Tests', () {
    test('Flood check returns true when sending > 5 messages in 3 seconds', () {
      final engine = SpamHeuristicEngine.instance;
      final peerId = 'peer_1';
      engine.clear();

      for (int i = 0; i < 5; i++) {
        expect(engine.checkFlood(peerId), isFalse);
      }
      expect(engine.checkFlood(peerId), isTrue);
    });

    test(
      'Duplicate check returns true on the 3rd identical sequential message',
      () {
        final engine = SpamHeuristicEngine.instance;
        final peerId = 'peer_2';
        engine.clear();

        expect(engine.checkDuplicate(peerId, 'hello'), isFalse);
        expect(engine.checkDuplicate(peerId, 'hello'), isFalse);
        expect(engine.checkDuplicate(peerId, 'hello'), isTrue);
      },
    );
  });

  group('Moderation Service Pipeline & Strike Escalation Tests', () {
    final service = ModerationService.instance;

    test('Incoming clean message is allowed', () {
      final dec = service.moderateIncoming('peer_3', 'msg_1', 'Clean message');
      expect(dec.action, ModerationAction.allow);
      expect(dec.severity, ModerationSeverity.clean);
      expect(dec.shouldHide, isFalse);
    });

    test(
      'Incoming sensitive message triggers warning (hide / tap-to-reveal)',
      () {
        final dec = service.moderateIncoming(
          'peer_4',
          'msg_2',
          'this is stupid',
        );
        expect(dec.action, ModerationAction.hide);
        expect(dec.severity, ModerationSeverity.warning);
        expect(dec.shouldHide, isTrue);
        expect(dec.requiresTapToReveal, isTrue);
      },
    );

    test('Incoming severe threat triggers strike 1 -> Mute 10s', () {
      final dec = service.moderateIncoming('peer_5', 'msg_3', 'i will killyou');
      expect(dec.action, ModerationAction.block);
      expect(dec.severity, ModerationSeverity.severe);

      final state = service.getPeerState('peer_5');
      expect(state, isNotNull);
      expect(state!.isMuted, isTrue);
      expect(state.spamStrikeCount + state.abuseStrikeCount, 1);
    });

    test('Peer strike escalation ladder leads to mute and eventual block', () {
      final peerId = 'peer_6';

      service.moderateIncoming(peerId, 'm1', 'i will killyou');
      var state = service.getPeerState(peerId);
      expect(state!.isMuted, isTrue);
      expect(state.isBlocked, isFalse);

      for (int i = 0; i < 5; i++) {
        service.moderateIncoming(peerId, 'm_spam_$i', 'regular content $i');
      }
      expect(state.spamStrikeCount, greaterThan(0));
      expect(state.isMuted, isTrue);
      expect(state.isBlocked, isFalse);

      service.moderateIncoming(peerId, 'm_abuse_2', 'i will killyou');
      expect(state.isBlocked, isTrue);

      final dec = service.moderateIncoming(peerId, 'm_after', 'normal text');
      expect(dec.action, ModerationAction.block);
    });

    test('Manual overrides work correctly', () {
      final peerId = 'peer_7';

      service.blockPeer(peerId);
      expect(service.isPeerBlocked(peerId), isTrue);

      service.unblockPeer(peerId);
      expect(service.isPeerBlocked(peerId), isFalse);

      service.mutePeer(peerId, const Duration(seconds: 5));
      expect(service.isPeerMuted(peerId), isTrue);

      service.unmutePeer(peerId);
      expect(service.isPeerMuted(peerId), isFalse);
    });
  });
}

List<String> matchedList(dynamic val) {
  if (val is List) {
    return List<String>.from(val);
  }
  return [];
}
