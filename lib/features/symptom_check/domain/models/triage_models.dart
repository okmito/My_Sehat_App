class TriageResponse {
  final String? sessionId;
  final String status;
  final Question? nextQuestion;
  final FinalResult? finalOutput;

  TriageResponse({
    this.sessionId,
    required this.status,
    this.nextQuestion,
    this.finalOutput,
  });

  factory TriageResponse.fromJson(Map<String, dynamic> json) {
    return TriageResponse(
      sessionId: json['session_id'],
      status: json['status'] ?? 'unknown',
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
  final List<String> options;
  final bool allowCustom;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.allowCustom,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      text: json['text'],
      options: List<String>.from(json['options'] ?? []),
      allowCustom: json['allow_custom'] ?? false,
    );
  }
}

class FinalResult {
  final String summary;
  final String severity;
  final List<String> possibleCauses;
  final List<String> homeCare;
  final List<String> prevention;
  final List<String> redFlags;
  final List<String> whenToSeekCare;
  final String disclaimer;

  FinalResult({
    required this.summary,
    required this.severity,
    required this.possibleCauses,
    required this.homeCare,
    required this.prevention,
    required this.redFlags,
    required this.whenToSeekCare,
    required this.disclaimer,
  });

  factory FinalResult.fromJson(Map<String, dynamic> json) {
    return FinalResult(
      summary: json['summary'] ?? '',
      severity: json['severity'] ?? 'unknown',
      possibleCauses: List<String>.from(json['possible_causes'] ?? []),
      homeCare: List<String>.from(json['home_care'] ?? []),
      prevention: List<String>.from(json['prevention'] ?? []),
      redFlags: List<String>.from(json['red_flags'] ?? []),
      whenToSeekCare: List<String>.from(json['when_to_seek_care'] ?? []),
      disclaimer: json['disclaimer'] ?? '',
    );
  }
}

class ChatMessage {
  final String? text;
  final bool isUser;
  final dynamic image; // Can be XFile or bytes, depending on implementation
  final DateTime timestamp;

  ChatMessage({
    this.text,
    required this.isUser,
    this.image,
    required this.timestamp,
  });
}
