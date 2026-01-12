class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, required this.timestamp});
}

class TriageEngine {
  static String analyze(String input) {
    input = input.toLowerCase();
    if (input.contains('chest pain') || input.contains('breathing') || input.contains('unconsious')) {
      return "EMERGENCY: Please call ambulance or use SOS button immediately!";
    } else if (input.contains('fever') && input.contains('high')) {
      return "MODERATE: High fever requires attention. Please visit a doctor soon.";
    } else if (input.contains('fever')) {
      return "MILD: Rest and hydration recommended. Monitor temperature.";
    } else if (input.contains('sad') || input.contains('depressed')) {
      return "MENTAL_HEALTH: It seems you are feeling down. Try our Mental Health module.";
    }
    return "I'm not sure. Can you describe more symptoms?";
  }
}
