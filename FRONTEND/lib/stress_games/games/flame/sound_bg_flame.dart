import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'dart:math';

enum SoundMode { rain, forest, ocean, wind, none }

class SoundAtmosphereGame extends FlameGame {
  SoundMode _mode = SoundMode.none;
  late _ParticleGenerator _generator;

  @override
  Color backgroundColor() => Colors.white;

  @override
  Future<void> onLoad() async {
    _generator = _ParticleGenerator();
    add(_generator);
  }

  void setMode(SoundMode mode) {
    _mode = mode;
    _generator.setMode(mode);
  }
}

class _ParticleGenerator extends Component
    with HasGameRef<SoundAtmosphereGame> {
  SoundMode mode = SoundMode.none;
  final Random _rand = Random();
  double _timer = 0;

  void setMode(SoundMode m) {
    mode = m;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (mode == SoundMode.none) return;

    _timer += dt;
    double spawnRate = 0.1; // Default

    if (mode == SoundMode.rain) spawnRate = 0.05;
    if (mode == SoundMode.wind) spawnRate = 0.02;

    if (_timer > spawnRate) {
      _timer = 0;
      _spawnParticle();
    }
  }

  void _spawnParticle() {
    Vector2 startPos = Vector2.zero();
    Vector2 velocity = Vector2.zero();
    Color color = Colors.white;
    double life = 2.0;

    switch (mode) {
      case SoundMode.rain:
        startPos = Vector2(_rand.nextDouble() * gameRef.size.x, -10);
        velocity = Vector2(0, 400 + _rand.nextDouble() * 200);
        color = Colors.blueAccent;
        life = gameRef.size.y / velocity.y;
        gameRef.add(
          ParticleSystemComponent(
            particle: AcceleratedParticle(
              position: startPos,
              speed: velocity,
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  canvas.drawRect(
                    const Rect.fromLTWH(0, 0, 2, 10),
                    Paint()..color = color.withOpacity(0.6),
                  );
                },
              ),
              lifespan: life,
            ),
          ),
        );
        break;

      case SoundMode.forest:
        startPos = Vector2(_rand.nextDouble() * gameRef.size.x, -10);
        velocity = Vector2(
            (_rand.nextDouble() - 0.5) * 50, 50 + _rand.nextDouble() * 50);
        color = Colors.green;
        life = 5.0;
        gameRef.add(
          ParticleSystemComponent(
            particle: AcceleratedParticle(
              position: startPos,
              speed: velocity,
              child: RotatingParticle(
                to: _rand.nextDouble() * pi * 2,
                child: CircleParticle(
                  radius: 4,
                  paint: Paint()..color = color.withOpacity(0.4),
                ),
              ),
              lifespan: life,
            ),
          ),
        );
        break;

      case SoundMode.ocean:
        startPos =
            Vector2(_rand.nextDouble() * gameRef.size.x, gameRef.size.y + 10);
        velocity = Vector2(
            (_rand.nextDouble() - 0.5) * 20, -50 - _rand.nextDouble() * 50);
        color = Colors.cyan;
        life = 6.0;
        gameRef.add(
          ParticleSystemComponent(
            particle: AcceleratedParticle(
              position: startPos,
              speed: velocity,
              child: CircleParticle(
                radius: 2 + _rand.nextDouble() * 4,
                paint: Paint()..color = color.withOpacity(0.3),
              ),
              lifespan: life,
            ),
          ),
        );
        break;

      case SoundMode.wind:
        startPos = Vector2(-10, _rand.nextDouble() * gameRef.size.y);
        velocity = Vector2(
            300 + _rand.nextDouble() * 200, (_rand.nextDouble() - 0.5) * 50);
        color = Colors.grey;
        life = gameRef.size.x / velocity.x;
        gameRef.add(
          ParticleSystemComponent(
            particle: AcceleratedParticle(
              position: startPos,
              speed: velocity,
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  canvas.drawRect(
                    const Rect.fromLTWH(0, 0, 10, 1),
                    Paint()..color = color.withOpacity(0.2),
                  );
                },
              ),
              lifespan: life,
            ),
          ),
        );
        break;

      default:
        break;
    }
  }
}
