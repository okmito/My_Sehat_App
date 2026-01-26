class AiTriageResponse {
  final String reply;
  final String riskLevel;
  final bool selfHarmDetected;
  final List<String> advice;
  final List<String> actions;
  final String? timestamp;

  AiTriageResponse({
    required this.reply,
    required this.riskLevel,
    required this.selfHarmDetected,
    this.advice = const [],
    this.actions = const [],
    this.timestamp,
  });

  factory AiTriageResponse.fromJson(Map<String, dynamic> json) {
    return AiTriageResponse(
      reply: json['reply'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ?? 'none',
      selfHarmDetected: json['self_harm_detected'] as bool? ?? false,
      advice:
          (json['advice'] as List?)?.map((e) => e.toString()).toList() ?? [],
      actions:
          (json['actions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      timestamp: json['timestamp'] as String?,
    );
  }
}
