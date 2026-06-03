enum ModerationSeverity {
  clean,
  warning,
  severe,
}

enum ModerationAction {
  allow,
  warn,
  hide,
  block,
}

class ModerationRule {
  final String name;
  final String description;
  final double riskWeight;

  ModerationRule({
    required this.name,
    required this.description,
    this.riskWeight = 1.0,
  });
}

class ModerationDecision {
  final String messageId;
  final String normalizedText;
  final List<String> matchedRules;
  final double riskScore;
  final ModerationSeverity severity;
  final ModerationAction action;
  final String explanation;
  final bool shouldHide;
  final bool requiresTapToReveal;
  final bool shouldBlockSend;
  final bool shouldIncrementPeerRisk;

  ModerationDecision({
    required this.messageId,
    required this.normalizedText,
    required this.matchedRules,
    required this.riskScore,
    required this.severity,
    required this.action,
    required this.explanation,
    required this.shouldHide,
    required this.requiresTapToReveal,
    required this.shouldBlockSend,
    required this.shouldIncrementPeerRisk,
  });

  factory ModerationDecision.clean({required String messageId, String normalizedText = ''}) {
    return ModerationDecision(
      messageId: messageId,
      normalizedText: normalizedText,
      matchedRules: [],
      riskScore: 0.0,
      severity: ModerationSeverity.clean,
      action: ModerationAction.allow,
      explanation: 'Testo approvato.',
      shouldHide: false,
      requiresTapToReveal: false,
      shouldBlockSend: false,
      shouldIncrementPeerRisk: false,
    );
  }
}

class PeerModerationState {
  final String peerId;
  double riskScore;
  int spamStrikeCount;
  int abuseStrikeCount;
  int duplicateStrikeCount;
  DateTime? muteUntil;
  bool isBlocked;
  DateTime lastEventTimestamp;

  PeerModerationState({
    required this.peerId,
    this.riskScore = 0.0,
    this.spamStrikeCount = 0,
    this.abuseStrikeCount = 0,
    this.duplicateStrikeCount = 0,
    this.muteUntil,
    this.isBlocked = false,
    required this.lastEventTimestamp,
  });

  bool get isMuted {
    if (muteUntil == null) return false;
    return muteUntil!.isAfter(DateTime.now());
  }
}
