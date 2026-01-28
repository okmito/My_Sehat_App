import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'services/ai_triage_service.dart';
import 'models/chat_message.dart';
import 'widgets/message_bubble.dart';
import 'widgets/risk_banner.dart';

class AiTriageChatScreen extends ConsumerStatefulWidget {
  const AiTriageChatScreen({super.key});

  @override
  ConsumerState<AiTriageChatScreen> createState() => _AiTriageChatScreenState();
}

class _AiTriageChatScreenState extends ConsumerState<AiTriageChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _sessionId = const Uuid().v4();
  final List<ChatMessage> _messages = [];

  bool _isTyping = false;
  bool _isHighRisk = false;

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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(
        id: const Uuid().v4(),
        role: 'user',
        text: text,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final service = ref.read(aiTriageServiceProvider);
      final response = await service.sendMessage(
        message: text,
        sessionId: _sessionId,
      );

      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          id: const Uuid().v4(),
          role: 'ai',
          text: response.reply,
          timestamp: DateTime.now(),
          advice: response.advice,
          riskLevel: response.riskLevel,
        ));

        if (response.riskLevel == 'high' ||
            response.riskLevel == 'critical' ||
            response.selfHarmDetected) {
          _isHighRisk = true;
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't reach AI service. Please check connection."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("AI Companion",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.withValues(alpha: 0.2),
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            color: Colors.blueGrey.shade50,
            child: Text(
              "Supportive AI, not a replacement for professionals.",
              style: GoogleFonts.outfit(
                  fontSize: 12, color: Colors.blueGrey.shade700),
              textAlign: TextAlign.center,
            ),
          ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, top: 8),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 4,
                          backgroundColor: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        const CircleAvatar(
                          radius: 4,
                          backgroundColor: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        const CircleAvatar(
                          radius: 4,
                          backgroundColor: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text("AI is thinking...",
                            style: GoogleFonts.outfit(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return MessageBubble(message: _messages[index]);
              },
            ),
          ),

          // Risk Banner
          RiskBanner(isRiskHigh: _isHighRisk),

          // Input Area
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        hintStyle: GoogleFonts.outfit(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      style: GoogleFonts.outfit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _isTyping ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      radius: 24,
                      child:
                          const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
