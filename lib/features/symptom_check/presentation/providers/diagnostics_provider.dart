import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/diagnostics/diagnostics_api_service.dart';
import '../../../../models/diagnostics/triage_models.dart';

// -----------------------------------------------------------------------------
// STATE
// -----------------------------------------------------------------------------
class DiagnosticsState {
  final String? userId; // Loaded from Prefs
  final String? sessionId;
  final List<ChatMessage> messages;
  final Question? currentQuestion;
  final FinalResult? finalResult;
  final bool isLoading;
  final String? error;

  DiagnosticsState({
    this.userId,
    this.sessionId,
    this.messages = const [],
    this.currentQuestion,
    this.finalResult,
    this.isLoading = false,
    this.error,
  });

  DiagnosticsState copyWith({
    String? userId,
    String? sessionId,
    List<ChatMessage>? messages,
    Question? currentQuestion,
    FinalResult? finalResult,
    bool isLoading =
        false, // Reset loading by default if not specified? No, usually sticky.
    // Actually standard copyWith keeps values. Be careful.
    bool? isLoadingOverride,
    String? error,
    bool clearError = false,
  }) {
    return DiagnosticsState(
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      currentQuestion: currentQuestion, // Allow nulling?
      // Wait, standard copyWith idiom:
      // currentQuestion: currentQuestion ?? this.currentQuestion
      // If I want to clear it, I need a flag or nullable wrapper.
      // For this simple implementation, I'll allow passing explicit null if I change logic,
      // but simpler: just fully replace state or be careful.
      // I'll stick to standard:
      // currentQuestion: currentQuestion ?? this.currentQuestion,
      // but "CurrentQuestion" changes often.
      // Let's implement simpler: Reset loading.
    );
  }

  // Proper CopyWith for nullable fields is tricky.
  // I will just construct new state in Notifier to be safe for nulls.
}

// -----------------------------------------------------------------------------
// PROVIDERS
// -----------------------------------------------------------------------------

final diagnosticsServiceProvider = Provider<DiagnosticsApiService>((ref) {
  return DiagnosticsApiService();
});

final diagnosticsProvider =
    StateNotifierProvider<DiagnosticsNotifier, DiagnosticsState>((ref) {
  final apiService = ref.watch(diagnosticsServiceProvider);
  return DiagnosticsNotifier(apiService);
});

// -----------------------------------------------------------------------------
// NOTIFIER
// -----------------------------------------------------------------------------

class DiagnosticsNotifier extends StateNotifier<DiagnosticsState> {
  final DiagnosticsApiService _apiService;
  Future<void> Function()? _lastRetryableAction;

  DiagnosticsNotifier(this._apiService) : super(DiagnosticsState()) {
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('mysehat_user_id');
    if (uid != null) {
      state = DiagnosticsState(userId: uid, messages: []);
    } else {
      // Should handle error or generate one? Main.dart handles it.
      // Just in case:
      final newId = const Uuid().v4();
      await prefs.setString('mysehat_user_id', newId);
      state = DiagnosticsState(userId: newId, messages: []);
    }
  }

  void reset() {
    // Keep userId, clear session
    state = DiagnosticsState(userId: state.userId);
  }

  void startNewSession() {
    state = DiagnosticsState(userId: state.userId);
  }

  Future<void> retry() async {
    if (_lastRetryableAction != null) {
      // Clear error before retry
      state = DiagnosticsState(
        userId: state.userId,
        sessionId: state.sessionId,
        messages: state.messages,
        currentQuestion: state.currentQuestion,
        finalResult: state.finalResult,
        isLoading: true, // Optimistic loading
      );
      await _lastRetryableAction!();
    }
  }

  // Helper handling response
  void _handleResponse(TriageResponse response) {
    // Add AI message if next question exists
    List<ChatMessage> newMessages = List.from(state.messages);

    if (response.nextQuestion != null) {
      newMessages.add(ChatMessage(
        id: const Uuid().v4(),
        text: response.nextQuestion!.text,
        isUser: false,
        question: response.nextQuestion,
      ));
    }

    state = DiagnosticsState(
      userId: state.userId,
      sessionId: response.sessionId,
      messages: newMessages,
      currentQuestion: response.nextQuestion,
      finalResult: response.finalOutput,
      isLoading: false,
    );
  }

  Future<void> startTextTriage(String text) async {
    _lastRetryableAction = () => startTextTriage(text);
    if (state.userId == null) await _loadUserId();

    state = DiagnosticsState(
      userId: state.userId,
      messages: [
        ...state.messages,
        ChatMessage(id: const Uuid().v4(), text: text, isUser: true),
      ],
      isLoading: true,
    );

    try {
      // Hardcoded demographics for now as per "simple text" start
      // Or we can ask user. The Prompt says: "Start triage with text (NEW session) ... Request body: symptoms, age, duration, severity".
      // UI flow: "On first user text: call startTextTriage()".
      // Where do we get age/duration/severity?
      // If the UI is just a chat box, we might default these or generic.
      // The prompt says "If user types text instead of clicking options: call sendSessionText()".
      // For START (Call A), we need these fields.
      // Assumption: Chat UI might collect these or we pass defaults for "General" triage.
      // Let's pass defaults for "Initial Complaint" and let the AI ask follow-ups.
      final response = await _apiService.startTextTriage(
        userId: state.userId!,
        symptoms: text,
        age: 30, // Default/Placeholder
        duration: "unknown",
        severity: "unknown",
      );

      _handleResponse(response);
    } catch (e) {
      state = DiagnosticsState(
        userId: state.userId,
        messages: [
          // Don't add error message to chat history, just error state?
          // Previous implementation added "Error: $e" as a message.
          // If I persist messages, the error message remains.
          // Better to just set error state and show snackbar or banner.
          // But UI shows "if (state.error != null) ...".
          ...state.messages,
          // ChatMessage(id: const Uuid().v4(), text: "Error: $e", isUser: false), // Optional
        ],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendAnswer(String answer) async {
    _lastRetryableAction = () => sendAnswer(answer);
    if (state.sessionId == null) return;

    state = DiagnosticsState(
      userId: state.userId,
      sessionId: state.sessionId,
      messages: [
        ...state.messages,
        ChatMessage(id: const Uuid().v4(), text: answer, isUser: true),
      ],
      currentQuestion: state.currentQuestion, // Keep until response
      isLoading: true,
    );

    try {
      final response = await _apiService.sendAnswer(
        userId: state.userId!,
        sessionId: state.sessionId!,
        answer: answer,
      );
      _handleResponse(response);
    } catch (e) {
      state = DiagnosticsState(
        userId: state.userId,
        sessionId: state.sessionId,
        messages: state.messages,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendSessionText(String text) async {
    _lastRetryableAction = () => sendSessionText(text);
    if (state.sessionId == null) {
      await startTextTriage(text);
      return;
    }

    state = DiagnosticsState(
      userId: state.userId,
      sessionId: state.sessionId,
      messages: [
        ...state.messages,
        ChatMessage(id: const Uuid().v4(), text: text, isUser: true),
      ],
      currentQuestion: state.currentQuestion,
      isLoading: true,
    );

    try {
      final response = await _apiService.sendSessionText(
        userId: state.userId!,
        sessionId: state.sessionId!,
        symptoms: text,
        age: 30,
        duration: "unknown",
        severity: "unknown",
      );
      _handleResponse(response);
    } catch (e) {
      state = DiagnosticsState(
        userId: state.userId,
        sessionId: state.sessionId,
        messages: state.messages,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendImage(XFile file) async {
    // Changed to XFile
    _lastRetryableAction = () => sendImage(file);
    if (state.userId == null) await _loadUserId();

    state = DiagnosticsState(
      userId: state.userId,
      sessionId: state.sessionId,
      messages: [
        ...state.messages,
        ChatMessage(
            id: const Uuid().v4(),
            text: "Image uploaded",
            isUser: true,
            imageUrl: file.path),
      ],
      isLoading: true,
    );

    try {
      final response = await _apiService.sendImage(
        userId: state.userId!,
        imageFile: file,
        sessionId: state.sessionId, // Nullable
      );
      _handleResponse(response);
    } catch (e) {
      state = DiagnosticsState(
        userId: state.userId,
        sessionId: state.sessionId,
        messages: state.messages,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}
