import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/diagnostics/diagnostics_api_service.dart';
import '../../../../models/diagnostics/triage_models.dart' hide ChatMessage;
import '../../../health_records/presentation/providers/health_records_controller.dart';
import '../../../health_records/data/models/health_record_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/logic/triage_engine.dart';

/// Provider for diagnostics API service
final diagnosticsApiProvider = Provider<DiagnosticsApiService>((ref) {
  return DiagnosticsApiService();
});

/// Chat state for symptom checker
class SymptomCheckerState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? sessionId;
  final String? errorMessage;
  final List<HealthRecordModel> healthRecords;
  final bool hasAskedAboutRecords;
  final ConversationPhase phase;

  const SymptomCheckerState({
    this.messages = const [],
    this.isLoading = false,
    this.sessionId,
    this.errorMessage,
    this.healthRecords = const [],
    this.hasAskedAboutRecords = false,
    this.phase = ConversationPhase.greeting,
  });

  SymptomCheckerState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? sessionId,
    String? errorMessage,
    List<HealthRecordModel>? healthRecords,
    bool? hasAskedAboutRecords,
    ConversationPhase? phase,
  }) {
    return SymptomCheckerState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: errorMessage,
      healthRecords: healthRecords ?? this.healthRecords,
      hasAskedAboutRecords: hasAskedAboutRecords ?? this.hasAskedAboutRecords,
      phase: phase ?? this.phase,
    );
  }
}

/// Conversation phases
enum ConversationPhase {
  greeting,
  askingAboutRecords,
  collectingSymptoms,
  followUpQuestions,
  completed,
}

/// Symptom Checker Controller
class SymptomCheckerController extends StateNotifier<SymptomCheckerState> {
  final DiagnosticsApiService _api;
  final Ref _ref;

  SymptomCheckerController(this._api, this._ref)
      : super(const SymptomCheckerState()) {
    // Initialize greeting immediately in constructor
    _initializeGreeting();
  }

  String get _userId {
    final user = _ref.read(authStateProvider).value;
    return user?.id ?? user?.phoneNumber ?? 'guest-user';
  }

  /// Initialize greeting synchronously
  void _initializeGreeting() {
    final greeting = ChatMessage.system(
      "👋 Hello! I'm your Health Assistant.\n\n"
      "I'm here to help understand your symptoms and guide you to the right care. "
      "Tell me, what's been bothering you today?\n\n"
      "Feel free to describe:\n"
      "• What symptoms you're experiencing\n"
      "• When they started\n"
      "• How severe they feel",
      type: MessageType.text,
    );

    state = state.copyWith(
      messages: [greeting],
      isLoading: false,
      phase: ConversationPhase.greeting,
    );

    // Load health records in background (async is fine here)
    _loadHealthRecords();
  }

  /// Initialize with greeting and health records check (for clearChat)
  Future<void> initialize() async {
    _initializeGreeting();
  }

  /// Load user's health records
  Future<void> _loadHealthRecords() async {
    try {
      final healthState = _ref.read(healthRecordsControllerProvider);
      if (healthState.records.isEmpty) {
        await _ref.read(healthRecordsControllerProvider.notifier).loadRecords();
      }

      final records = _ref.read(healthRecordsControllerProvider).records;
      state = state.copyWith(healthRecords: records);
    } catch (e) {
      debugPrint('Failed to load health records: $e');
    }
  }

  /// Process user message
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage.user(text);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      errorMessage: null,
    );

    try {
      // Quick local triage for emergencies
      final severity = TriageEngine.quickAnalyze(text);

      if (severity == TriageSeverity.emergency) {
        await _handleEmergency();
        return;
      }

      if (severity == TriageSeverity.mentalHealth) {
        await _handleMentalHealth();
        return;
      }

      // Check if we should ask about health records first
      if (!state.hasAskedAboutRecords && state.healthRecords.isNotEmpty) {
        await _askAboutHealthRecords(text);
        return;
      }

      // Proceed with AI triage
      await _processWithAI(text);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );

      _addSystemMessage(
        "I'm having trouble connecting to our health service. "
        "Let me help you with some basic guidance based on what you've shared.",
        type: MessageType.text,
      );

      // Fallback to local triage
      _provideFallbackGuidance(text);
    }
  }

  /// Handle emergency situations
  Future<void> _handleEmergency() async {
    await Future.delayed(const Duration(milliseconds: 300));

    _addSystemMessage(
      TriageEngine.getEmergencyResponse(),
      type: MessageType.alert,
      options: ["🚨 Open SOS", "📞 Call 108", "Continue Assessment"],
    );

    state = state.copyWith(isLoading: false);
  }

  /// Handle mental health situations
  Future<void> _handleMentalHealth() async {
    await Future.delayed(const Duration(milliseconds: 300));

    _addSystemMessage(
      TriageEngine.getMentalHealthResponse(),
      type: MessageType.suggestion,
      options: ["💬 Talk to Mental Health Companion", "Continue Here"],
    );

    state = state.copyWith(isLoading: false);
  }

  /// Ask about existing health records
  Future<void> _askAboutHealthRecords(String initialSymptoms) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Get recent conditions from records
    final conditions = _extractConditionsFromRecords();

    if (conditions.isEmpty) {
      state = state.copyWith(hasAskedAboutRecords: true);
      await _processWithAI(initialSymptoms);
      return;
    }

    String conditionsList = conditions.map((c) => "• $c").join("\n");

    _addSystemMessage(
      "📋 **I notice you have some health records on file.**\n\n"
      "Based on your records, you have these conditions:\n$conditionsList\n\n"
      "Are any of these conditions still affecting you or related to what you're experiencing today?",
      type: MessageType.healthContext,
      options: ["Yes, related", "No, this is different", "Tell me more"],
      questionId: "health_records_check",
    );

    state = state.copyWith(
      isLoading: false,
      hasAskedAboutRecords: true,
      phase: ConversationPhase.askingAboutRecords,
    );
  }

  /// Extract conditions from health records
  List<String> _extractConditionsFromRecords() {
    final conditions = <String>{};

    for (final record in state.healthRecords.take(10)) {
      // Check diagnosis
      if (record.diagnosis != null && record.diagnosis!.isNotEmpty) {
        conditions.add(record.diagnosis!);
      }

      // Check for medications that indicate conditions
      for (final med in record.medications) {
        final medName = med.name.toLowerCase();
        if (medName.contains('metformin') || medName.contains('insulin')) {
          conditions.add('Diabetes');
        } else if (medName.contains('amlodipine') ||
            medName.contains('losartan')) {
          conditions.add('Hypertension');
        } else if (medName.contains('levothyroxine')) {
          conditions.add('Thyroid condition');
        } else if (medName.contains('inhaler') ||
            medName.contains('salbutamol')) {
          conditions.add('Respiratory condition');
        }
      }

      // Check abnormal test results
      for (final test in record.testResults.where((t) => t.isAbnormal)) {
        if (test.testName.toLowerCase().contains('glucose')) {
          conditions.add('Blood sugar concerns');
        } else if (test.testName.toLowerCase().contains('cholesterol')) {
          conditions.add('Cholesterol concerns');
        }
      }
    }

    return conditions.take(5).toList();
  }

  /// Process with AI backend
  Future<void> _processWithAI(String symptoms) async {
    try {
      late TriageResponse response;

      if (state.sessionId == null) {
        // Start new session
        response = await _api.startTextTriage(
          userId: _userId,
          symptoms: _buildContextualSymptoms(symptoms),
          age: 30, // TODO: Get from user profile
          duration: "unknown",
          severity: "moderate",
        );
      } else {
        // Continue existing session
        response = await _api.sendSessionText(
          userId: _userId,
          sessionId: state.sessionId!,
          symptoms: symptoms,
          age: 30,
          duration: "unknown",
          severity: "moderate",
        );
      }

      state = state.copyWith(sessionId: response.sessionId);

      // Process response
      if (response.status == "completed" && response.finalOutput != null) {
        await _handleFinalResult(response.finalOutput!);
      } else if (response.nextQuestion != null) {
        await _handleFollowUpQuestion(response.nextQuestion!);
      } else {
        _addSystemMessage(
          "I've noted your symptoms. Can you tell me more about when this started "
          "and how it's affecting you?",
          type: MessageType.question,
        );
      }
    } catch (e) {
      debugPrint('AI triage error: $e');
      _provideFallbackGuidance(symptoms);
    }

    state = state.copyWith(isLoading: false);
  }

  /// Build symptoms with health context
  String _buildContextualSymptoms(String symptoms) {
    final conditions = _extractConditionsFromRecords();
    if (conditions.isEmpty) return symptoms;

    return "$symptoms (Patient has history of: ${conditions.join(', ')})";
  }

  /// Handle follow-up question from AI
  Future<void> _handleFollowUpQuestion(Question question) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final options = question.options?.map((o) => o.toString()).toList();

    _addSystemMessage(
      question.text,
      type: MessageType.question,
      options: options,
      allowCustomInput: question.allowCustom,
      questionId: question.id,
    );

    state = state.copyWith(phase: ConversationPhase.followUpQuestions);
  }

  /// Handle final triage result
  Future<void> _handleFinalResult(FinalResult result) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Build comprehensive response
    final buffer = StringBuffer();

    buffer.writeln("📊 **Assessment Complete**\n");
    buffer.writeln("**Summary:** ${result.summary}\n");
    buffer.writeln("**Severity Level:** ${result.severity}\n");

    if (result.causes.isNotEmpty) {
      buffer.writeln("\n**Possible Causes:**");
      for (final cause in result.causes) {
        buffer.writeln("• $cause");
      }
    }

    if (result.homeCare.isNotEmpty) {
      buffer.writeln("\n**🏠 Home Care Recommendations:**");
      for (final care in result.homeCare) {
        buffer.writeln("• $care");
      }
    }

    if (result.redFlags.isNotEmpty) {
      buffer.writeln("\n**⚠️ Watch for these warning signs:**");
      for (final flag in result.redFlags) {
        buffer.writeln("• $flag");
      }
    }

    // Add health record context if relevant
    final conditions = _extractConditionsFromRecords();
    if (conditions.isNotEmpty) {
      buffer.writeln("\n**📋 Considering your medical history:**");
      buffer.writeln("Given your history of ${conditions.join(', ')}, "
          "please monitor your symptoms closely and consult your doctor "
          "if symptoms persist or worsen.");
    }

    buffer.writeln("\n---\n⚕️ _${result.disclaimer}_");

    _addSystemMessage(
      buffer.toString(),
      type: MessageType.finalResult,
      options: [
        "🏥 Find Nearby Doctors",
        "💊 Check Medications",
        "Start New Check"
      ],
    );

    state = state.copyWith(phase: ConversationPhase.completed);
  }

  /// Provide fallback guidance when AI is unavailable
  void _provideFallbackGuidance(String symptoms) {
    final severity = TriageEngine.quickAnalyze(symptoms);

    String guidance;
    switch (severity) {
      case TriageSeverity.high:
        guidance =
            "Based on what you've described, I recommend seeking medical attention soon. "
            "Your symptoms warrant a professional evaluation.";
        break;
      case TriageSeverity.moderate:
        guidance =
            "Your symptoms seem moderate. Rest, stay hydrated, and monitor how you feel. "
            "If symptoms worsen or don't improve in 24-48 hours, please see a doctor.";
        break;
      default:
        guidance =
            "For mild symptoms like these, home care usually helps. Rest well, "
            "stay hydrated, and monitor your symptoms. See a doctor if things get worse.";
    }

    _addSystemMessage(guidance, type: MessageType.suggestion);
    state = state.copyWith(isLoading: false);
  }

  /// Handle option selection
  Future<void> selectOption(String option) async {
    // Add user's selection as message
    final userMessage = ChatMessage.user(option);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    // Handle special actions
    if (option.contains("SOS") || option.contains("108")) {
      // Navigate to SOS (handled by UI)
      state = state.copyWith(isLoading: false);
      return;
    }

    if (option.contains("Mental Health")) {
      // Navigate to mental health (handled by UI)
      state = state.copyWith(isLoading: false);
      return;
    }

    if (option == "Start New Check") {
      await initialize();
      return;
    }

    // For health records question
    if (option == "Yes, related") {
      _addSystemMessage(
        "Thanks for letting me know. I'll keep your medical history in mind "
        "while assessing your current symptoms. This helps me provide more "
        "relevant guidance.\n\n"
        "Now, please tell me more about what you're experiencing today.",
        type: MessageType.text,
      );
      state = state.copyWith(
        isLoading: false,
        phase: ConversationPhase.collectingSymptoms,
      );
      return;
    }

    if (option == "No, this is different") {
      _addSystemMessage(
        "Got it! This seems to be a new concern. "
        "Please describe your symptoms in detail - what you're feeling, "
        "when it started, and anything that makes it better or worse.",
        type: MessageType.text,
      );
      state = state.copyWith(
        isLoading: false,
        phase: ConversationPhase.collectingSymptoms,
      );
      return;
    }

    // For AI follow-up questions, send the answer
    if (state.sessionId != null) {
      try {
        final response = await _api.sendAnswer(
          userId: _userId,
          sessionId: state.sessionId!,
          answer: option,
        );

        if (response.status == "completed" && response.finalOutput != null) {
          await _handleFinalResult(response.finalOutput!);
        } else if (response.nextQuestion != null) {
          await _handleFollowUpQuestion(response.nextQuestion!);
        }
      } catch (e) {
        debugPrint('Error sending answer: $e');
        _addSystemMessage(
          "I understand. Based on all the information you've shared, "
          "let me provide some guidance.",
          type: MessageType.text,
        );
      }
    }

    state = state.copyWith(isLoading: false);
  }

  /// Add a system message
  void _addSystemMessage(
    String text, {
    MessageType type = MessageType.text,
    List<String>? options,
    bool allowCustomInput = true,
    String? questionId,
  }) {
    final message = ChatMessage.system(
      text,
      type: type,
      options: options,
      allowCustomInput: allowCustomInput,
      questionId: questionId,
    );
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Clear chat and start over
  void clearChat() {
    state = const SymptomCheckerState();
    initialize();
  }
}

/// Provider for symptom checker controller
final symptomCheckerControllerProvider = StateNotifierProvider.autoDispose<
    SymptomCheckerController, SymptomCheckerState>((ref) {
  // Controller initializes greeting in constructor
  return SymptomCheckerController(
    ref.watch(diagnosticsApiProvider),
    ref,
  );
});

class SymptomCheckerScreen extends ConsumerStatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  ConsumerState<SymptomCheckerScreen> createState() =>
      _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends ConsumerState<SymptomCheckerScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Provider auto-initializes, no need to call initialize here
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    ref
        .read(symptomCheckerControllerProvider.notifier)
        .sendMessage(_controller.text.trim());
    _controller.clear();
    _scrollToBottom();
  }

  void _selectOption(String option) {
    // Handle navigation options
    if (option.contains("SOS") || option.contains("108")) {
      Navigator.pushNamed(context, '/sos');
      return;
    }
    if (option.contains("Mental Health")) {
      Navigator.pushNamed(context, '/mental-health');
      return;
    }
    if (option.contains("Find Nearby")) {
      Navigator.pushNamed(context, '/doctors');
      return;
    }
    if (option.contains("Check Medications")) {
      Navigator.pushNamed(context, '/medicine');
      return;
    }

    ref.read(symptomCheckerControllerProvider.notifier).selectOption(option);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(symptomCheckerControllerProvider);

    // Scroll to bottom when new messages arrive
    ref.listen(symptomCheckerControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Symptom Checker"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Start Over",
            onPressed: () {
              ref.read(symptomCheckerControllerProvider.notifier).clearChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: state.messages.length + (state.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.messages.length && state.isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(state.messages[index]);
              },
            ),
          ),

          // Error message if any
          if (state.errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Input area
          _buildInputArea(state),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _getMessageColor(message),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildMessageContent(message),
          ),

          // Quick reply options
          if (!isUser && message.options != null && message.options!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.options!.map((option) {
                  return _buildOptionChip(option, message.type);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Color _getMessageColor(ChatMessage message) {
    if (message.isUser) {
      return Theme.of(context).primaryColor;
    }

    switch (message.type) {
      case MessageType.alert:
        return Colors.red.shade50;
      case MessageType.healthContext:
        return Colors.blue.shade50;
      case MessageType.finalResult:
        return Colors.green.shade50;
      case MessageType.suggestion:
        return Colors.amber.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  Widget _buildMessageContent(ChatMessage message) {
    final textColor = message.isUser ? Colors.white : Colors.black87;

    // Simple text rendering with basic markdown-like formatting
    String text = message.text;

    return SelectableText(
      text,
      style: TextStyle(
        color: textColor,
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  Widget _buildOptionChip(String option, MessageType type) {
    Color chipColor;
    Color textColor;

    if (option.contains("🚨") || option.contains("Emergency")) {
      chipColor = Colors.red;
      textColor = Colors.white;
    } else if (option.contains("💜") || option.contains("Mental")) {
      chipColor = Colors.purple;
      textColor = Colors.white;
    } else if (option.contains("🏥") || option.contains("Doctor")) {
      chipColor = Colors.blue;
      textColor = Colors.white;
    } else {
      chipColor = Theme.of(context).primaryColor.withOpacity(0.1);
      textColor = Theme.of(context).primaryColor;
    }

    return ActionChip(
      label: Text(
        option,
        style: TextStyle(color: textColor, fontSize: 13),
      ),
      backgroundColor: chipColor,
      side: BorderSide.none,
      onPressed: () => _selectOption(option),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade400.withOpacity(0.5 + (value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea(SymptomCheckerState state) {
    final canType =
        !state.isLoading && state.phase != ConversationPhase.completed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: canType,
                decoration: InputDecoration(
                  hintText: state.phase == ConversationPhase.completed
                      ? "Assessment complete. Start new check to continue."
                      : "Describe your symptoms...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: canType
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: canType ? _sendMessage : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
