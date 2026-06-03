import 'moderation_models.dart';

class KeywordRiskScorer {
  static final KeywordRiskScorer instance = KeywordRiskScorer._();
  KeywordRiskScorer._();

  // Rules dictionary matching normalized keywords to risk weights and explanations
  final Map<String, ModerationRule> _rules = {
    // Red cards (Severe: weight >= 4.0)
    'killyou': ModerationRule(
      name: 'Minaccia di violenza',
      description: 'Rilevato intento violento o minaccia fisica.',
      riskWeight: 5.0,
    ),
    'threaten': ModerationRule(
      name: 'Minaccia verbale',
      description: 'Rilevato comportamento minaccioso verbale.',
      riskWeight: 4.0,
    ),
    'leakinfo': ModerationRule(
      name: 'Doxxing',
      description: 'Tentativo di divulgazione di dati sensibili privati.',
      riskWeight: 5.0,
    ),
    'doxx': ModerationRule(
      name: 'Doxxing',
      description: 'Tentativo di pubblicazione non autorizzata di dati personali.',
      riskWeight: 5.0,
    ),

    // Yellow cards (Warning: weight >= 1.0)
    'scam': ModerationRule(
      name: 'Sospetta truffa',
      description: 'Parola associata a truffe finanziarie o phishing.',
      riskWeight: 2.0,
    ),
    'phishing': ModerationRule(
      name: 'Sospetta truffa',
      description: 'Pattern associato a richieste fraudolente.',
      riskWeight: 2.0,
    ),
    'freecoins': ModerationRule(
      name: 'Promozione ingannevole',
      description: 'Spam pubblicitario finanziario sospetto.',
      riskWeight: 2.5,
    ),
    'giveaway': ModerationRule(
      name: 'Sospetto giveaway',
      description: 'Pattern promozionale non sollecitato.',
      riskWeight: 1.5,
    ),
    'stupid': ModerationRule(
      name: 'Insulto',
      description: 'Uso di termini offensivi o ingiuriosi.',
      riskWeight: 1.0,
    ),
    'badword': ModerationRule(
      name: 'Turpiloquio',
      description: 'Parola volgare non appropriata nei canali pubblici.',
      riskWeight: 1.2,
    ),
    'brutto': ModerationRule(
      name: 'Aggettivo offensivo',
      description: 'Termine dispregiativo rivolto ad altri.',
      riskWeight: 0.8,
    ),
    'cattivo': ModerationRule(
      name: 'Aggettivo offensivo',
      description: 'Termine dispregiativo rivolto ad altri.',
      riskWeight: 0.8,
    ),
  };

  /// Scans the normalized text against our rule dictionary.
  /// Returns a tuple containing: matched rule names, total risk weight, and primary explanation.
  Map<String, dynamic> score(String normalizedText) {
    final List<String> matched = [];
    double totalWeight = 0.0;
    String explanation = 'Testo pulito.';

    for (final entry in _rules.entries) {
      if (normalizedText.contains(entry.key)) {
        matched.add(entry.value.name);
        totalWeight += entry.value.riskWeight;
        if (explanation == 'Testo pulito.') {
          explanation = entry.value.description;
        } else {
          explanation = '$explanation Inoltre rilevato: ${entry.value.description}';
        }
      }
    }

    return {
      'matchedRules': matched,
      'riskScore': totalWeight,
      'explanation': explanation,
    };
  }
}
