class TriageResponse {
  final String sessionId;
  final String status; // "needs_more_info" | "completed"
  final Question? nextQuestion;
  final FinalResult? finalOutput;

  TriageResponse({
    required this.sessionId,
    required this.status,
    this.nextQuestion,
    this.finalOutput,
  });

  factory TriageResponse.fromJson(Map<String, dynamic> json) {
    return TriageResponse(
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      nextQuestion: json['next_question'] != null
          ? Question.fromJson(json['next_question'])
          : null,
      finalOutput: json['final_output'] != null
          ? FinalResult.fromJson(json['final_output'])
          : null,
    );
  }
}

class Question {
  final String id;
  final String text;
  final List<dynamic>?
      options; // Can be List<String> or List<Map> depending on backend, confusing.
  // Swagger says:
  // "options": [ "string" ] or maybe objects?
  // Let's assume List<String> based on standard usage, or verify.
  // Wait, commonly options are simple strings or key-value.
  // Let's assume List<String> for now or handle dynamic.
  // The prompt says "next_question.options".

  final bool allowCustom;

  Question({
    required this.id,
    required this.text,
    this.options,
    this.allowCustom = false,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      text: json['text'] as String,
      options: json['options'] as List<dynamic>?,
      allowCustom: json['allow_custom'] ?? false,
    );
  }
}

class FinalResult {
  final String summary;
  final String severity;
  final List<String> causes;
  final List<String> homeCare;
  final List<String> redFlags;
  final String disclaimer;

  FinalResult({
    required this.summary,
    required this.severity,
    required this.causes,
    required this.homeCare,
    required this.redFlags,
    required this.disclaimer,
  });

  factory FinalResult.fromJson(Map<String, dynamic> json) {
    return FinalResult(
      summary: json['summary'] ?? '',
      severity: json['severity'] ?? '',
      causes: (json['causes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      homeCare: (json['home_care'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      redFlags: (json['red_flags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      disclaimer: json['disclaimer'] ?? '',
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final String? imageUrl;
  final Question? question; // If system message wraps a question

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.imageUrl,
    this.question,
  });
}
