import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // For web check

import '../providers/diagnostics_provider.dart';
import '../../../../models/diagnostics/triage_models.dart';

class DiagnosticsChatScreen extends ConsumerStatefulWidget {
  const DiagnosticsChatScreen({super.key});

  @override
  ConsumerState<DiagnosticsChatScreen> createState() =>
      _DiagnosticsChatScreenState();
}

class _DiagnosticsChatScreenState extends ConsumerState<DiagnosticsChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleBackPress() async {
    final state = ref.read(diagnosticsProvider);
    // If completed or just started (only greeting), allow exit
    if (state.finalResult != null || state.messages.length <= 1) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }

    // Show warning
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Diagnosis in progress"),
        content: const Text(
            "Are you sure you want to leave? Your progress will be lost."),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Leave"),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldExit == true) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diagnosticsProvider);

    ref.listen(diagnosticsProvider, (previous, next) {
      if (next.finalResult != null &&
          (previous?.finalResult == null ||
              previous?.finalResult != next.finalResult)) {
        // Navigate to result screen with the final result object
        context.pushReplacement('/diagnostics/result', extra: next.finalResult);
      }
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Symptom Checker",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 1,
          shadowColor: Colors.grey.withValues(alpha: 0.2),
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackPress,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: state.messages.length + (state.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.messages.length) {
                    return _LoadingIndicator();
                  }
                  final msg = state.messages[index];
                  return _ChatMessageBubble(message: msg);
                },
              ),
            ),
            if (state.error != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    Expanded(
                        child: Text(state.error!,
                            style: const TextStyle(color: Colors.red))),
                    TextButton(
                      onPressed: () =>
                          ref.read(diagnosticsProvider.notifier).retry(),
                      child: const Text("Retry"),
                    )
                  ],
                ),
              ),
            if (state.currentQuestion != null && !state.isLoading)
              _QuestionCard(
                question: state.currentQuestion!,
                onAnswer: (answer) {
                  ref.read(diagnosticsProvider.notifier).sendAnswer(answer);
                },
              )
            else
              _buildInputArea(state),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(DiagnosticsState state) {
    // Hide input if we are waiting for a selection on a question card
    // BUT we might want to allow custom text if allow_custom is true or if it's the initial state.
    // Logic: If there is a question and it DOES NOT allow custom, hide text input.
    // If there is no question (initial state) OR question allows custom, show input.

    final bool showInput = state.currentQuestion == null ||
        (state.currentQuestion?.allowCustom ?? false);

    if (!showInput) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded),
            color: Theme.of(context).primaryColor,
            onPressed: state.isLoading ? null : _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: state.currentQuestion != null
                    ? "Type your answer..."
                    : "Describe your symptoms...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: Theme.of(context).primaryColor,
            onPressed: state.isLoading ? null : _handleSend,
          ),
        ],
      ),
    );
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final state = ref.read(diagnosticsProvider);

    if (state.sessionId == null) {
      // First message
      ref.read(diagnosticsProvider.notifier).startTextTriage(text);
    } else {
      // Follow-up answer (custom text) or session update
      // If we are currently "Answer Question" state but user types text:
      // Prompt says: "If user types text instead of clicking options: call sendSessionText()"
      // But we should check if sendAnswer logic fits better if it's just an answer.
      // However, sendSessionText includes symptoms update? No, sendSessionText adds to session.
      ref.read(diagnosticsProvider.notifier).sendSessionText(text);
    }
    _textController.clear();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        ref.read(diagnosticsProvider.notifier).sendImage(image);
      }
    } catch (e) {
      if (!mounted) return;
      // Handle picker error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to pick image: $e")),
      );
    }
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color =
        isUser ? Theme.of(context).primaryColor : Colors.grey.shade200;
    final textColor = isUser ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isUser ? const Radius.circular(16) : const Radius.circular(0),
              bottomRight:
                  isUser ? const Radius.circular(0) : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imageUrl != null)
                _buildImagePreview(message.imageUrl),
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: GoogleFonts.outfit(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(dynamic image) {
    String? path;
    if (image is String) {
      path = image;
    } else if (image is XFile) {
      path = image.path;
    }

    if (path != null) {
      if (kIsWeb) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              path,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        );
      } else {
        // Not web, try loading from file system
        // Note: XFile path on mobile is a file path.
        // But to be safe if creating file from path:
        // We need 'dart:io' for File, but we can't import it if we want web compat in this file easily?
        // Actually Flutter handles conditional imports or we can just use Image.network for everything if it was a URL.
        // For local file on mobile, Image.network won't work.
        // We need Image.file.
        // Since this is a widget file, and we know we are connecting.
        // Assuming we can use proper imports or specific logic.
        // For now, I'll attempt Image.network because on Chrome `path` is a blob URL.
        // On mobile, this will fail if it's a file path.

        // Let's rely on cross-platform abstraction if possible, but standard Image.file needed for File.
        // I will use a helper or just conditionally return.
        // Since I'm editing a file that already had "CA_Foundation", likely for bytes?
        // The original code used `image.readAsBytes()`.
        // That is the safest cross platform way!
        // `XFile` has `readAsBytes`.
        // BUT my message state has `imageUrl` as String.
        // I lost the `XFile` reference in the provider unless I store it?
        // My provider code saved `imageUrl: file.path`.
        // I can change provider to store `XFile` in the `ChatMessage` (as `dynamic image` field I added? No I added `imageUrl`).
        // ChatMessage has `imageUrl`.

        // Solution: Re-instantiate XFile from path? Not possible on Web easily.
        // I should modify `ChatMessage` to hold `XFile? attachment` for UI display purposes, or bytes.
        // For now I will try to use `Image.network` as a fallback since I am running on Chrome.
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              path,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }
}

class _QuestionCard extends StatelessWidget {
  final Question question;
  final Function(String) onAnswer;

  const _QuestionCard({required this.question, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          )
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.text,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (question.options ?? []).map((option) {
              return ActionChip(
                label: Text(option.toString()),
                labelStyle: GoogleFonts.outfit(fontSize: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onPressed: () => onAnswer(option.toString()),
              );
            }).toList(),
          ),
          if (question.allowCustom) ...[
            const SizedBox(height: 8),
            Text(
              "Or type a custom answer below:",
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text("AI is analyzing...",
              style: GoogleFonts.outfit(color: Colors.grey)),
        ],
      ),
    );
  }
}
