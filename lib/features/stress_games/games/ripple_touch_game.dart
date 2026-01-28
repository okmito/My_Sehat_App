import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flame/game.dart'; // GameWidget
import 'package:my_sehat_app/features/stress_games/games/flame/ripple_game_flame.dart';

class RippleTouchGame extends StatefulWidget {
  const RippleTouchGame({super.key});

  @override
  State<RippleTouchGame> createState() => _RippleTouchGameState();
}

class _RippleTouchGameState extends State<RippleTouchGame> {
  late RippleGame _rippleGame;
  Timer? _gameTimer;
  int _remainingSeconds = 0;
  bool _isPlaying = false;
  int _sessionDuration = 0;

  // Storage key
  static const String _storageKey = 'ripple_touch_best_time';

  @override
  void initState() {
    super.initState();
    _rippleGame = RippleGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _addRipple(TapUpDetails details) {
    if (!_isPlaying && _remainingSeconds == 0) return;

    // Flame uses vector2
    // We need to account for the fact that GameWidget might not fill everything if constrained,
    // but here it is Positioned.fill.
    // However, we should be careful about coordinate space.
    // Ideally we tap on the GameWidget directly.
    _rippleGame
        .addRipple(Vector2(details.localPosition.dx, details.localPosition.dy));
  }

  void _startGame(int seconds) {
    setState(() {
      _remainingSeconds = seconds;
      _isPlaying = true;
      _sessionDuration = seconds;
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _finishGame();
        }
      });
    });
  }

  Future<void> _finishGame() async {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final int bestTime = prefs.getInt(_storageKey) ?? 0;

    String msg = "Good job taking time for yourself. 🌱";
    if (_sessionDuration > bestTime) {
      prefs.setInt(_storageKey, _sessionDuration);
      msg = "You stayed calm longer today! New record! 🌱";
    }

    if (mounted) {
      _showCompletionDialog(msg);
    }
  }

  void _showCompletionDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Session Complete",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("Done", style: GoogleFonts.outfit(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _remainingSeconds = 0;
                _remainingSeconds = 0;
              });
            },
            child: Text("Play Again",
                style: GoogleFonts.outfit(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Ripple Touch", style: GoogleFonts.outfit()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          // Game Layer
          Positioned.fill(
            child: GameWidget(
              game: _rippleGame,
            ),
          ),

          // Transparent gesture detector ON TOP OF GAME to capture taps if needed?
          // Actually GameWidget captures taps if we add TapDetector to the game,
          // but here we used external GestureDetector in previous logic.
          // Let's keep using external GestureDetector wrapping the GameWidget for simplicity
          // in passing coordinates relative to the widget.
          Positioned.fill(
              child: GestureDetector(
            onTapUp: _addRipple,
            behavior: HitTestBehavior.translucent,
            child: Container(),
          )),

          // Timer Selection
          if (!_isPlaying && _remainingSeconds == 0)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          spreadRadius: 2)
                    ]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Choose a duration",
                      style: GoogleFonts.outfit(
                          fontSize: 20, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        _TimerButton(
                            label: "30 sec",
                            seconds: 30,
                            onTap: () => _startGame(30)),
                        _TimerButton(
                            label: "1 min",
                            seconds: 60,
                            onTap: () => _startGame(60)),
                        _TimerButton(
                            label: "2 min",
                            seconds: 120,
                            onTap: () => _startGame(120)),
                        _TimerButton(
                            label: "Free Play",
                            seconds: -1,
                            onTap: () => _startGame(-1)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Timer
          if (_isPlaying && _remainingSeconds > 0)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ]),
                child: Text(
                  "${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                  style: GoogleFonts.outfit(
                      fontSize: 18, color: Colors.blueGrey[800]),
                ),
              ),
            ),

          if (_isPlaying && _sessionDuration == -1)
            Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text("Relaxing...",
                      style: GoogleFonts.outfit(
                          fontSize: 16, color: Colors.blueGrey[800])),
                ))
        ],
      ),
    );
  }
}

class _TimerButton extends StatelessWidget {
  final String label;
  final int seconds;
  final VoidCallback onTap;

  const _TimerButton(
      {required this.label, required this.seconds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.blue,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Colors.blue.withValues(alpha: 0.3))),
        elevation: 0,
      ),
      child: Text(label, style: GoogleFonts.outfit()),
    );
  }
}
