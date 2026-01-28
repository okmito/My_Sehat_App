import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Simple entity
class MoodEntry {
  final String mood; // 'Happy', 'Sad', 'Neutral', 'Stressed'
  final DateTime date;

  MoodEntry(this.mood, this.date);
}

// Simple provider
final moodListProvider =
    StateNotifierProvider<MoodNotifier, List<MoodEntry>>((ref) {
  return MoodNotifier();
});

class MoodNotifier extends StateNotifier<List<MoodEntry>> {
  MoodNotifier() : super([]);

  void addMood(String mood) {
    state = [...state, MoodEntry(mood, DateTime.now())];
  }
}

class MentalHealthScreen extends ConsumerWidget {
  const MentalHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(moodListProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Mental Wellness",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Mood Tracking Card
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text("How are you feeling today?",
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MoodButton("Happy", "😊", Colors.green, ref),
                        _MoodButton("Neutral", "😐", Colors.amber, ref),
                        _MoodButton("Sad", "😔", Colors.blue, ref),
                        _MoodButton("Stressed", "😫", Colors.red, ref),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Feature Grid
            Row(
              children: [
                Expanded(
                    child: _FeatureCard(
                        title: "Daily\nJournal",
                        icon: Icons.book,
                        color: Colors.orange,
                        onTap: () => context.push('/daily_journal'))),
                const SizedBox(width: 16),
                Expanded(
                    child: _FeatureCard(
                        title: "Stress Relief\nGames",
                        icon: Icons.videogame_asset,
                        color: Colors.purple,
                        onTap: () => context.push('/stress_games'))),
              ],
            ),
            const SizedBox(height: 16),
            _FeatureCard(
                title: "Chat with AI Companion (Anonymous)",
                icon: Icons.chat_bubble,
                color: Colors.teal,
                onTap: () {
                  context.push('/ai_chat');
                },
                isWide: true),

            const SizedBox(height: 24),
            Align(
                alignment: Alignment.centerLeft,
                child: Text("Mood History",
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.bold))),

            if (moods.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("No mood history yet."),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: moods.length,
                itemBuilder: (context, index) {
                  final entry = moods[moods.length - 1 - index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Text(_getIcon(entry.mood),
                          style: const TextStyle(fontSize: 24)),
                      title: Text(entry.mood,
                          style:
                              GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      subtitle: Text(entry.date.toString().substring(0, 16)),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _getIcon(String mood) {
    switch (mood) {
      case 'Happy':
        return '😊';
      case 'Neutral':
        return '😐';
      case 'Sad':
        return '😔';
      case 'Stressed':
        return '😫';
      default:
        return '❓';
    }
  }
}

class _MoodButton extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final WidgetRef ref;

  const _MoodButton(this.label, this.emoji, this.color, this.ref);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ref.read(moodListProvider.notifier).addMood(label);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Recorded: $label")));
      },
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.outfit(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isWide;

  const _FeatureCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.onTap,
      this.isWide = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          height: isWide ? 100 : 140,
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Text(title,
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    Text(title,
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                ),
        ),
      ),
    );
  }
}
