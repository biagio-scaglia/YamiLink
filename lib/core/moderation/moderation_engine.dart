class ModerationResult {
  final bool isAllowed;
  final bool shouldBlur;
  final String classification; // 'clean', 'sensitive', 'disallowed'
  final String ruleName;

  ModerationResult({
    required this.isAllowed,
    required this.shouldBlur,
    required this.classification,
    required this.ruleName,
  });

  factory ModerationResult.clean() {
    return ModerationResult(
      isAllowed: true,
      shouldBlur: false,
      classification: 'clean',
      ruleName: '',
    );
  }
}

class ModerationEngine {
  static final ModerationEngine instance = ModerationEngine._();
  ModerationEngine._();

  // Red card keywords: blocked completely
  final List<String> _disallowedKeywords = [
    'killyou',
    'leakinfo',
    'doxx',
    'threaten',
  ];

  // Yellow card keywords: blurred by default
  final List<String> _sensitiveKeywords = [
    'scam',
    'phishing',
    'stupid',
    'badword',
    'brutto',
    'cattivo',
  ];

  /// Normalizes the input text by:
  /// 1. Converting to lowercase.
  /// 2. Stripping whitespaces.
  /// 3. Stripping common symbols and punctuation.
  String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\.\-_!\?,\*@#\$%\^&]'), '');
  }

  /// Analyzes a string and returns a ModerationResult.
  ModerationResult analyze(String text) {
    if (text.trim().isEmpty) {
      return ModerationResult.clean();
    }

    final normalized = normalize(text);

    // Check disallowed (Red Card)
    for (final word in _disallowedKeywords) {
      if (normalized.contains(word)) {
        return ModerationResult(
          isAllowed: false,
          shouldBlur: true,
          classification: 'disallowed',
          ruleName: 'Disallowed Behavior (Safety Guideline Violation)',
        );
      }
    }

    // Check sensitive (Yellow Card)
    for (final word in _sensitiveKeywords) {
      if (normalized.contains(word)) {
        return ModerationResult(
          isAllowed: true,
          shouldBlur: true,
          classification: 'sensitive',
          ruleName: 'Sensitive Content Warning',
        );
      }
    }

    return ModerationResult.clean();
  }
}
