import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Help & Support",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "FAQ"),
            Tab(text: "Ask AI Assistant"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          FAQTab(),
          AIChatTab(),
        ],
      ),
    );
  }
}

class FAQTab extends StatelessWidget {
  const FAQTab({super.key});

  final List<Map<String, String>> faqs = const [
    {
      "question": "How do I add an emergency contact?",
      "answer":
          "Go to the Profile section and tap on 'Emergency Contacts'. You can add, edit, or remove contacts from there. These contacts will be notified when you use the SOS feature."
    },
    {
      "question": "Is my health data secure?",
      "answer":
          "Yes, MySehat is an offline-first application. Your data is stored locally on your device. We do not upload your personal health data to any cloud servers without your explicit permission."
    },
    {
      "question": "How does the Symptom Checker work?",
      "answer":
          "The Symptom Checker uses an on-device algorithm to analyze the symptoms you select. It provides potential causes and recommendations. Please note it is for informational purposes only and not a substitute for professional medical advice."
    },
    {
      "question": "Can I book appointments through the app?",
      "answer":
          "Yes, you can browse available doctors in the 'Appointments' section and schedule visits. You can also view your upcoming and past appointments."
    },
    {
      "question": "What should I do in a medical emergency?",
      "answer":
          "Use the red SOS button on the home screen or the SOS tab. This will immediately alert your emergency contacts and can help you call emergency services. Always call an ambulance first if the situation is critical."
    },
    {
      "question": "How do I change the app language?",
      "answer":
          "Navigate to Profile > Language Selection to choose your preferred language. The app currently supports English, Hindi, and Spanish."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: faqs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _FAQItem(
          question: faqs[index]["question"]!,
          answer: faqs[index]["answer"]!,
        );
      },
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            widget.question,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          trailing: Icon(
            _isExpanded
                ? Icons.remove_circle_outline
                : Icons.add_circle_outline,
            color: Theme.of(context).primaryColor,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.answer,
                style: GoogleFonts.outfit(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AIChatTab extends StatefulWidget {
  const AIChatTab({super.key});

  @override
  State<AIChatTab> createState() => _AIChatTabState();
}

class _AIChatTabState extends State<AIChatTab> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      "text": "Hi! I'm your MySehat assistant. Ask me anything about the app.",
      "isUser": false,
    }
  ];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    setState(() {
      _messages.add({"text": userMessage, "isUser": true});
      _controller.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    // Simulate AI response delay
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          "text": _getSimulatedResponse(userMessage),
          "isUser": false,
        });
      });
      _scrollToBottom();
    });
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

  String _getSimulatedResponse(String query) {
    final q = query.toLowerCase();
    if (q.contains("hello") || q.contains("hi")) {
      return "Hello! How can I help you with MySehat today?";
    } else if (q.contains("emergency") || q.contains("sos")) {
      return "The SOS feature is designed for emergencies. Tap the big red button on the home screen to alert your contacts. You can manage these contacts in your Profile.";
    } else if (q.contains("appointment") || q.contains("doctor")) {
      return "You can book appointments in the 'Appointments' tab. We have a list of specialists available for consultation.";
    } else if (q.contains("data") ||
        q.contains("privacy") ||
        q.contains("secure")) {
      return "Your privacy is our priority. All your health data is stored locally on your device and is not shared without your consent.";
    } else if (q.contains("symptom")) {
      return "Our Symptom Checker helps you understand potential health issues based on your symptoms. It's available on the home screen.";
    } else if (q.contains("medicine") || q.contains("pill")) {
      return "You can set reminders for your medications in the 'Reminders' section so you never miss a dose.";
    } else if (q.contains("thank")) {
      return "You're welcome! Stay healthy.";
    }
    return "I'm still learning! You can try asking about 'appointments', 'SOS', 'privacy', or 'symptoms'. Check the FAQ tab for more details.";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return const _TypingIndicator();
              }
              final msg = _messages[index];
              return _ChatBubble(
                text: msg['text'],
                isUser: msg['isUser'],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Ask a question...",
                    hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: isUser
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            color: isUser ? Colors.white : Colors.black87,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: 0),
            const SizedBox(width: 4),
            _Dot(delay: 1),
            const SizedBox(width: 4),
            _Dot(delay: 2),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    // Add start delay if needed, but simple reverse repeat works for now with offset
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            widget.delay * 0.2,
            1.0,
            curve: Curves.easeInOut,
          ),
        ),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
