import 'package:uuid/uuid.dart';

/// Chat message model for symptom checker
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessageType type;
  final List<String>? options;
  final bool allowCustomInput;
  final String? questionId;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.type = MessageType.text,
    this.options,
    this.allowCustomInput = true,
    this.questionId,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Create a system message (from AI)
  factory ChatMessage.system(
    String text, {
    List<String>? options,
    bool allowCustomInput = true,
    String? questionId,
    MessageType type = MessageType.text,
  }) {
    return ChatMessage(
      text: text,
      isUser: false,
      type: type,
      options: options,
      allowCustomInput: allowCustomInput,
      questionId: questionId,
    );
  }

  /// Create a user message
  factory ChatMessage.user(String text) {
    return ChatMessage(text: text, isUser: true);
  }
}

/// Types of messages in the chat
enum MessageType {
  text, // Regular text message
  question, // Question with options
  alert, // Emergency/warning alert
  suggestion, // Suggestion/recommendation
  healthContext, // Health record context info
  finalResult, // Final triage result
}

/// Severity levels for triage
enum TriageSeverity {
  emergency,
  high,
  moderate,
  low,
  mentalHealth,
  unknown;

  String get displayName {
    switch (this) {
      case TriageSeverity.emergency:
        return 'EMERGENCY';
      case TriageSeverity.high:
        return 'High Priority';
      case TriageSeverity.moderate:
        return 'Moderate';
      case TriageSeverity.low:
        return 'Low';
      case TriageSeverity.mentalHealth:
        return 'Mental Health';
      case TriageSeverity.unknown:
        return 'Unknown';
    }
  }

  String get color {
    switch (this) {
      case TriageSeverity.emergency:
        return '#FF0000';
      case TriageSeverity.high:
        return '#FF6600';
      case TriageSeverity.moderate:
        return '#FFCC00';
      case TriageSeverity.low:
        return '#00CC00';
      case TriageSeverity.mentalHealth:
        return '#9966FF';
      case TriageSeverity.unknown:
        return '#808080';
    }
  }
}

/// Represents a health condition from user's records
class HealthCondition {
  final String name;
  final String? severity;
  final DateTime? reportDate;
  final String source; // e.g., "Lab Report", "Prescription"

  HealthCondition({
    required this.name,
    this.severity,
    this.reportDate,
    required this.source,
  });

  bool get isRecent {
    if (reportDate == null) return false;
    return DateTime.now().difference(reportDate!).inDays <= 30;
  }
}

/// Local triage engine with smart analysis
class TriageEngine {
  /// Emergency keywords that require immediate attention
  static const List<String> _emergencyKeywords = [
    'chest pain',
    'heart attack',
    'stroke',
    'unconscious',
    'not breathing',
    'severe bleeding',
    'choking',
    'seizure',
    'collapse',
    'overdose',
    'suicide',
    'self harm',
    'accident',
    'severe injury',
    'can\'t breathe',
    'crushing pain',
    'severe allergic',
    'anaphylaxis'
  ];

  /// High priority keywords
  static const List<String> _highPriorityKeywords = [
    'high fever',
    'chest tightness',
    'difficulty breathing',
    'blood in stool',
    'blood in urine',
    'severe headache',
    'worst headache',
    'sudden confusion',
    'slurred speech',
    'vision changes',
    'severe abdominal pain'
  ];

  /// Mental health keywords
  static const List<String> _mentalHealthKeywords = [
    'sad',
    'depressed',
    'anxious',
    'anxiety',
    'panic',
    'stress',
    'stressed',
    'can\'t sleep',
    'insomnia',
    'hopeless',
    'worthless',
    'lonely',
    'worried',
    'nervous',
    'overwhelmed',
    'burnout',
    'mood',
    'cry',
    'crying'
  ];

  /// Quick local triage analysis
  static TriageSeverity quickAnalyze(String input) {
    final lowerInput = input.toLowerCase();

    // Check emergency keywords
    for (final keyword in _emergencyKeywords) {
      if (lowerInput.contains(keyword)) {
        return TriageSeverity.emergency;
      }
    }

    // Check high priority
    for (final keyword in _highPriorityKeywords) {
      if (lowerInput.contains(keyword)) {
        return TriageSeverity.high;
      }
    }

    // Check mental health
    for (final keyword in _mentalHealthKeywords) {
      if (lowerInput.contains(keyword)) {
        return TriageSeverity.mentalHealth;
      }
    }

    // Check moderate symptoms
    if (lowerInput.contains('fever') ||
        lowerInput.contains('pain') ||
        lowerInput.contains('vomit') ||
        lowerInput.contains('diarrhea')) {
      return TriageSeverity.moderate;
    }

    // Default to low/unknown
    return TriageSeverity.low;
  }

  /// Generate emergency response
  static String getEmergencyResponse() {
    return "🚨 **EMERGENCY DETECTED**\n\n"
        "This sounds like a medical emergency. Please:\n"
        "1. Call emergency services immediately (108/112)\n"
        "2. Use the SOS button in our app\n"
        "3. Stay calm and don't delay seeking help";
  }

  /// Generate mental health response
  static String getMentalHealthResponse() {
    return "💜 I understand you're going through a difficult time.\n\n"
        "Your feelings are valid, and it's okay to seek support. "
        "Would you like to:\n\n"
        "• Talk to our AI Mental Health Companion\n"
        "• Continue telling me more about how you're feeling\n\n"
        "Remember: You're not alone in this.";
  }

  /// Extract conditions from symptoms text that might relate to health records
  static List<String> extractPotentialConditions(String symptoms) {
    final conditions = <String>[];
    final lower = symptoms.toLowerCase();

    final conditionKeywords = {
      'diabetes': ['sugar', 'glucose', 'diabetic', 'insulin'],
      'hypertension': ['blood pressure', 'bp', 'hypertension'],
      'asthma': ['asthma', 'inhaler', 'wheez'],
      'thyroid': ['thyroid', 'tsh'],
      'heart disease': ['heart', 'cardiac', 'cholesterol'],
      'kidney': ['kidney', 'renal', 'creatinine'],
      'liver': ['liver', 'hepat', 'jaundice'],
    };

    for (final entry in conditionKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          conditions.add(entry.key);
          break;
        }
      }
    }

    return conditions;
  }
}
