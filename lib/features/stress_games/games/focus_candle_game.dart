import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flame/game.dart';
import 'package:my_sehat_app/features/stress_games/games/flame/candle_game_flame.dart';

class FocusCandleGame extends StatefulWidget {
  const FocusCandleGame({super.key});

  @override
  State<FocusCandleGame> createState() => _FocusCandleGameState();
}

class _FocusCandleGameState extends State<FocusCandleGame> {
  late CandleGame _candleGame;

  Timer? _gameTimer;
  int _remainingSeconds = 0;
  bool _isPlaying = false;
  int _sessionDuration = 0;

  static const String _storageKey = 'focus_candle_best_time';

  @override
  void initState() {
    super.initState();
    _candleGame = CandleGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _onScreenTap() {
    if (!_isPlaying) return;
    _candleGame.boostEnergy();
  }

  void _startGame(int seconds) {
    setState(() {
      _remainingSeconds = seconds;
      _isPlaying = true;
      _sessionDuration = seconds;
    });

    _gameTimer?.cancel();

    // Game Timer (for session duration)
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0 || _sessionDuration == -1) {
          if (_sessionDuration != -1) _remainingSeconds--;
        } else {
          _finishGame(true); // Success
        }
      });
    });
  }

  Future<void> _finishGame(bool success) async {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      final int bestTime = prefs.getInt(_storageKey) ?? 0;
      if (_sessionDuration > bestTime) {
        prefs.setInt(_storageKey, _sessionDuration);
      }
      _showCompletionDialog("You kept the light alive. 🕯️ Focus achieved.");
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
            child:
                Text("Done", style: GoogleFonts.outfit(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _remainingSeconds = 0;
              });
            },
            child: Text("Play Again",
                style: GoogleFonts.outfit(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Focus Candle",
            style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Flame Game Layer
          Positioned.fill(
            child: GameWidget(game: _candleGame),
          ),

          // Tap Interceptor
          Positioned.fill(
              child: GestureDetector(
            onTap: _onScreenTap,
            behavior: HitTestBehavior.translucent,
            child: Container(),
          )),

          if (_isPlaying)
            Positioned(
              top: 100,
              child: Text("Tap gently to keep the flame alive",
                  style:
                      GoogleFonts.outfit(color: Colors.white30, fontSize: 12)),
            ),

          // UI Controls
          if (!_isPlaying)
            Positioned(
              bottom: 250, // Above candle
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Set Focus Timer",
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 16,
                      children: [
                        _TimerButton(
                            label: "1 min",
                            seconds: 60,
                            onTap: () => _startGame(60)),
                        _TimerButton(
                            label: "3 min",
                            seconds: 180,
                            onTap: () => _startGame(180)),
                        _TimerButton(
                            label: "5 min",
                            seconds: 300,
                            onTap: () => _startGame(300)),
                      ],
                    )
                  ],
                ),
              ),
            ),

          if (_isPlaying && _remainingSeconds > 0)
            Positioned(
              top: 40,
              child: Text(
                "${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                style: GoogleFonts.outfit(fontSize: 24, color: Colors.white54),
              ),
            ),
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
    // Using simple elevated button for better visibility on black bg
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(label, style: GoogleFonts.outfit()),
    );
  }
}
