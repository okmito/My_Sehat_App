import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flame/game.dart';
import 'package:my_sehat_app/stress_games/games/flame/sound_bg_flame.dart';

class SoundTapGame extends StatefulWidget {
  const SoundTapGame({super.key});

  @override
  State<SoundTapGame> createState() => _SoundTapGameState();
}

class _SoundTapGameState extends State<SoundTapGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late SoundAtmosphereGame _soundGame;

  Timer? _gameTimer;
  int _remainingSeconds = 0;
  bool _isPlaying = false;
  int _sessionDuration = 0;
  String _activeSoundName = "";

  // Storage key
  static const String _storageKey = 'sound_tap_best_time';

  @override
  void initState() {
    super.initState();
    _soundGame = SoundAtmosphereGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playSound(String soundFile, String name) async {
    if (!_isPlaying && _remainingSeconds == 0)
      return; // Must start timer/game first

    try {
      if (_activeSoundName == name) {
        // Stop if tapped again
        await _audioPlayer.stop();
        setState(() {
          _activeSoundName = "";
        });
        _soundGame.setMode(SoundMode.none);
      } else {
        // Play new sound
        await _audioPlayer.stop(); // Stop previous

        await _audioPlayer.setSource(AssetSource('sounds/$soundFile'));
        await _audioPlayer.setVolume(0.3); // Low and calming
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.resume();

        // Update Flame Background
        SoundMode mode = SoundMode.none;
        switch (name) {
          case "Rain":
            mode = SoundMode.rain;
            break;
          case "Forest":
            mode = SoundMode.forest;
            break;
          case "Ocean":
            mode = SoundMode.ocean;
            break;
          case "Wind":
            mode = SoundMode.wind;
            break;
        }
        _soundGame.setMode(mode);

        setState(() {
          _activeSoundName = name;
        });
      }
    } catch (e) {
      // Graceful fallback if assets missing
      debugPrint("Audio error: $e");
      setState(() {
        // Still update UI to show "playing" state visually
        _activeSoundName = (_activeSoundName == name) ? "" : name;
      });
    }
  }

  void _stopGame() async {
    _gameTimer?.cancel();
    await _audioPlayer.stop();
    _soundGame.setMode(SoundMode.none);

    setState(() {
      _isPlaying = false;
      _activeSoundName = "";
      _remainingSeconds = 0;
    });

    // Save
    final prefs = await SharedPreferences.getInstance();
    final int bestTime = prefs.getInt(_storageKey) ?? 0;

    if (_sessionDuration > bestTime) {
      prefs.setInt(_storageKey, _sessionDuration);
    }
  }

  void _startGame(int seconds) {
    setState(() {
      _remainingSeconds = seconds;
      _isPlaying = true;
      _sessionDuration = seconds;
      _activeSoundName = "";
      _soundGame.setMode(SoundMode.none);
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0 || _sessionDuration == -1) {
          if (_sessionDuration != -1)
            _remainingSeconds--; // Only decrease if not infinite
        } else {
          _finishGame();
        }
      });
    });
  }

  Future<void> _finishGame() async {
    _gameTimer?.cancel();
    await _audioPlayer.stop();
    _soundGame.setMode(SoundMode.none);

    setState(() {
      _isPlaying = false;
      _activeSoundName = "";
    });

    _showCompletionDialog("Nice choice taking time to relax. 🌿");
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
            child: Text("Done", style: GoogleFonts.outfit(color: Colors.green)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _remainingSeconds = 0;
              });
            },
            child: Text("Play Again",
                style: GoogleFonts.outfit(color: Colors.green)),
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
        title: Text("Sound Tap", style: GoogleFonts.outfit()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          // Background Game
          Positioned.fill(
            child: Opacity(
              opacity: 0.5, // Make it subtle so UI pops
              child: GameWidget(game: _soundGame),
            ),
          ),

          // Original UI
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isPlaying) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Select duration to start",
                          style: GoogleFonts.outfit(
                              fontSize: 18, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 20),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _TimerButton(
                                  label: "1 min",
                                  seconds: 60,
                                  onTap: () => _startGame(60)),
                              const SizedBox(width: 8),
                              _TimerButton(
                                  label: "2 min",
                                  seconds: 120,
                                  onTap: () => _startGame(120)),
                              const SizedBox(width: 8),
                              _TimerButton(
                                  label: "5 min",
                                  seconds: 300,
                                  onTap: () => _startGame(300)),
                              const SizedBox(width: 8),
                              _TimerButton(
                                  label: "Free Play",
                                  seconds: -1,
                                  onTap: () => _startGame(-1)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ] else ...[
                  Text(
                    _sessionDuration == -1
                        ? "Relaxing..."
                        : "${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                    style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Tap a sound to play",
                    style: GoogleFonts.outfit(
                        fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),

                  // Sound Buttons
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      _SoundButton(
                          name: "Rain",
                          icon: Icons.water_drop,
                          isActive: _activeSoundName == "Rain",
                          onTap: () => _playSound("rain.mp3", "Rain")),
                      _SoundButton(
                          name: "Forest",
                          icon: Icons.forest,
                          isActive: _activeSoundName == "Forest",
                          onTap: () => _playSound("forest.mp3", "Forest")),
                      _SoundButton(
                          name: "Ocean",
                          icon: Icons.waves,
                          isActive: _activeSoundName == "Ocean",
                          onTap: () => _playSound("ocean.mp3", "Ocean")),
                      _SoundButton(
                          name: "Wind",
                          icon: Icons.air,
                          isActive: _activeSoundName == "Wind",
                          onTap: () => _playSound("wind.mp3", "Wind")),
                    ],
                  ),

                  const SizedBox(height: 40),
                  TextButton(
                      onPressed: _stopGame,
                      child: Text("End Session",
                          style: GoogleFonts.outfit(color: Colors.grey[700])))
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundButton extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SoundButton(
      {required this.name,
      required this.icon,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 100,
        height: 100,
        decoration: BoxDecoration(
            color: isActive ? Colors.green[100] : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: isActive ? Colors.green : Colors.grey[300]!, width: 2),
            boxShadow: [
              if (isActive)
                BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2)
              else
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
            ]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 32,
                color: isActive ? Colors.green[800] : Colors.grey[600]),
            const SizedBox(height: 4),
            Text(name,
                style: GoogleFonts.outfit(
                    color: isActive ? Colors.green[800] : Colors.grey[600],
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal))
          ],
        ),
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
    return SizedBox(
      width: 100, // Fixed width for consistency
      height: 50, // Taller
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.green, width: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
