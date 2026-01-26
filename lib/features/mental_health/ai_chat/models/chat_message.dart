class ChatMessage {
  final String id;
  final String role; // 'user', 'ai'
  final String text;
  final DateTime timestamp;
  final List<String>? advice;
  final String? riskLevel;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.advice,
    this.riskLevel,
  });
}
