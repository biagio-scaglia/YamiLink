import 'keyword_risk_scorer.dart';
import 'moderation_models.dart';
import 'spam_heuristic_engine.dart';

class ModerationService {
  static final ModerationService instance = ModerationService._();
  ModerationService._();

  final Map<String, PeerModerationState> _peerStates = {};

  /// Normalizes message text: lowercases, strips spaces & symbols, and compresses repeats of 3+ letters to 1.
  String normalize(String text) {
    String normalized = text.toLowerCase().replaceAll(
      RegExp(r'[\s\.\-_!\?,\*@#\$%\^&]'),
      '',
    );
    if (normalized.isEmpty) return normalized;

    return normalized.replaceAllMapped(RegExp(r'(.)\1{2,}'), (match) {
      return match.group(1)!;
    });
  }

  /// Processes an incoming message and updates the peer's strike counts and mute/block statuses.
  ModerationDecision moderateIncoming(
    String peerId,
    String messageId,
    String content,
  ) {
    if (isPeerBlocked(peerId)) {
      return ModerationDecision(
        messageId: messageId,
        normalizedText: '',
        matchedRules: ['Blocco locale'],
        riskScore: 10.0,
        severity: ModerationSeverity.severe,
        action: ModerationAction.block,
        explanation: 'Il mittente è bloccato.',
        shouldHide: true,
        requiresTapToReveal: false,
        shouldBlockSend: true,
        shouldIncrementPeerRisk: false,
      );
    }

    final normalized = normalize(content);
    final peerState = _peerStates.putIfAbsent(
      peerId,
      () => PeerModerationState(
        peerId: peerId,
        lastEventTimestamp: DateTime.now(),
      ),
    );
    peerState.lastEventTimestamp = DateTime.now();

    final isFlooding = SpamHeuristicEngine.instance.checkFlood(peerId);
    final isDuplicate = SpamHeuristicEngine.instance.checkDuplicate(
      peerId,
      normalized,
    );

    if (isFlooding || isDuplicate) {
      peerState.spamStrikeCount++;
      _escalatePeerStrikes(
        peerState,
        isFlooding ? 'Flooding' : 'Messaggio duplicato',
      );

      return ModerationDecision(
        messageId: messageId,
        normalizedText: normalized,
        matchedRules: [isFlooding ? 'Flooding' : 'Messaggio duplicato'],
        riskScore: 5.0,
        severity: ModerationSeverity.severe,
        action: peerState.isBlocked
            ? ModerationAction.block
            : ModerationAction.hide,
        explanation: isFlooding
            ? 'Spam burst rilevato (troppi messaggi in 3 secondi).'
            : 'Messaggio duplicato ripetuto consecutivamente.',
        shouldHide: true,
        requiresTapToReveal: !peerState.isBlocked,
        shouldBlockSend: peerState.isBlocked,
        shouldIncrementPeerRisk: true,
      );
    }

    final scoreResult = KeywordRiskScorer.instance.score(normalized);
    final List<String> matched = List<String>.from(scoreResult['matchedRules']);
    final double riskScore = scoreResult['riskScore'];
    final String keywordExplanation = scoreResult['explanation'];

    if (riskScore > 0) {
      peerState.riskScore += riskScore;
      ModerationSeverity severity = ModerationSeverity.clean;
      ModerationAction action = ModerationAction.allow;

      if (riskScore >= 4.0) {
        severity = ModerationSeverity.severe;
        action = ModerationAction.block;
        peerState.abuseStrikeCount++;
        _escalatePeerStrikes(peerState, 'Violazione grave');
      } else if (riskScore >= 1.0) {
        severity = ModerationSeverity.warning;
        action = ModerationAction.hide;
      }

      return ModerationDecision(
        messageId: messageId,
        normalizedText: normalized,
        matchedRules: matched,
        riskScore: riskScore,
        severity: severity,
        action: action,
        explanation: keywordExplanation,
        shouldHide:
            action == ModerationAction.hide || action == ModerationAction.block,
        requiresTapToReveal: action == ModerationAction.hide,
        shouldBlockSend: action == ModerationAction.block,
        shouldIncrementPeerRisk: true,
      );
    }

    if (peerState.isMuted) {
      return ModerationDecision(
        messageId: messageId,
        normalizedText: normalized,
        matchedRules: ['Mute attivo'],
        riskScore: 0.0,
        severity: ModerationSeverity.warning,
        action: ModerationAction.hide,
        explanation: 'Messaggio nascosto: il mittente è silenziato.',
        shouldHide: true,
        requiresTapToReveal: true,
        shouldBlockSend: false,
        shouldIncrementPeerRisk: false,
      );
    }

    return ModerationDecision.clean(
      messageId: messageId,
      normalizedText: normalized,
    );
  }

  /// Evaluates an outgoing message draft, blocking severe words and warning about sensitive ones.
  ModerationDecision moderateOutgoing(String content) {
    final normalized = normalize(content);
    final scoreResult = KeywordRiskScorer.instance.score(normalized);
    final List<String> matched = List<String>.from(scoreResult['matchedRules']);
    final double riskScore = scoreResult['riskScore'];
    final String explanation = scoreResult['explanation'];

    if (riskScore >= 4.0) {
      return ModerationDecision(
        messageId: 'outgoing_temp',
        normalizedText: normalized,
        matchedRules: matched,
        riskScore: riskScore,
        severity: ModerationSeverity.severe,
        action: ModerationAction.block,
        explanation: explanation,
        shouldHide: true,
        requiresTapToReveal: false,
        shouldBlockSend: true,
        shouldIncrementPeerRisk: false,
      );
    } else if (riskScore >= 1.0) {
      return ModerationDecision(
        messageId: 'outgoing_temp',
        normalizedText: normalized,
        matchedRules: matched,
        riskScore: riskScore,
        severity: ModerationSeverity.warning,
        action: ModerationAction.warn,
        explanation: explanation,
        shouldHide: false,
        requiresTapToReveal: false,
        shouldBlockSend: false,
        shouldIncrementPeerRisk: false,
      );
    }

    return ModerationDecision.clean(
      messageId: 'outgoing_temp',
      normalizedText: normalized,
    );
  }

  /// Triggers escalation: strike 1 -> 10s mute, strike 2 -> 30s mute, strike 3 -> block.
  void _escalatePeerStrikes(PeerModerationState state, String reason) {
    final totalStrikes =
        state.spamStrikeCount +
        state.abuseStrikeCount +
        state.duplicateStrikeCount;
    if (totalStrikes == 1) {
      state.muteUntil = DateTime.now().add(const Duration(seconds: 10));
    } else if (totalStrikes == 2) {
      state.muteUntil = DateTime.now().add(const Duration(seconds: 30));
    } else if (totalStrikes >= 3) {
      state.isBlocked = true;
    }
  }

  void mutePeer(String peerId, Duration duration) {
    final state = _peerStates.putIfAbsent(
      peerId,
      () => PeerModerationState(
        peerId: peerId,
        lastEventTimestamp: DateTime.now(),
      ),
    );
    state.muteUntil = DateTime.now().add(duration);
    state.lastEventTimestamp = DateTime.now();
  }

  void unmutePeer(String peerId) {
    final state = _peerStates[peerId];
    if (state != null) {
      state.muteUntil = null;
    }
  }

  bool isPeerMuted(String peerId) {
    final state = _peerStates[peerId];
    return state != null && state.isMuted;
  }

  void blockPeer(String peerId) {
    final state = _peerStates.putIfAbsent(
      peerId,
      () => PeerModerationState(
        peerId: peerId,
        lastEventTimestamp: DateTime.now(),
      ),
    );
    state.isBlocked = true;
    state.lastEventTimestamp = DateTime.now();
  }

  void unblockPeer(String peerId) {
    final state = _peerStates[peerId];
    if (state != null) {
      state.isBlocked = false;
      state.spamStrikeCount = 0;
      state.abuseStrikeCount = 0;
      state.duplicateStrikeCount = 0;
      state.riskScore = 0.0;
      state.muteUntil = null;
    }
    SpamHeuristicEngine.instance.clearPeer(peerId);
  }

  bool isPeerBlocked(String peerId) {
    final state = _peerStates[peerId];
    return state != null && state.isBlocked;
  }

  PeerModerationState? getPeerState(String peerId) {
    return _peerStates[peerId];
  }

  void clear() {
    _peerStates.clear();
    SpamHeuristicEngine.instance.clear();
  }
}
