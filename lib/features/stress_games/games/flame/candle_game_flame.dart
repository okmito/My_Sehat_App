import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class CandleGame extends FlameGame {
  late LightingOverlay _lighting;
  late CandleFlame _flame;
  late CandleBody _candle;
  late WickComponent _wick;

  double _energy = 0.5;
  static const double _decay = 0.05;

  @override
  Color backgroundColor() => Colors.black;

  @override
  Future<void> onLoad() async {
    // Center point of the screen
    final center = size / 2;

    // Candle Body
    // Anchor: TopCenter. Position: Center (so top of candle is at screen center)
    // Actually let's move it down a bit so the flame is at center.
    final candleTop = center + Vector2(0, 50);

    _candle = CandleBody(position: candleTop);
    add(_candle);

    // Wick
    // Anchor: BottomCenter. Position: candleTop (so bottom of wick is top of candle)
    _wick = WickComponent(position: candleTop);
    add(_wick);

    // Flame
    // Anchor: BottomCenter. Position: Top of Wick
    // Wick height is 15. So top of wick is candleTop - (0, 15).
    // Allow slight overlap (2px) so it touches well.
    final flamePos = candleTop - Vector2(0, 12);
    _flame = CandleFlame(position: flamePos);
    add(_flame);

    // Add lighting overlay (darkness)
    _lighting = LightingOverlay();
    add(_lighting);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Decay energy
    _energy = (_energy - (_decay * dt)).clamp(0.0, 1.0);

    // Update lighting based on energy
    _lighting.setDarkness(1.0 - _energy);

    // Update flame intensity
    _flame.intensity = _energy;
  }

  void boostEnergy() {
    _energy = (_energy + 0.15).clamp(0.0, 1.0); // Increased boost
  }
}

class CandleBody extends PositionComponent {
  CandleBody({required Vector2 position})
      : super(
            position: position,
            size: Vector2(80, 200),
            anchor: Anchor.topCenter);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.grey[300]!;
    // Standard rendering filling the component size
    final rect = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);

    // Gradient shading
    final shader = const LinearGradient(
      colors: [Colors.black12, Colors.transparent, Colors.black12],
      stops: [0.0, 0.5, 1.0],
    ).createShader(rect);

    canvas.drawRect(rect, Paint()..shader = shader);
  }
}

class WickComponent extends PositionComponent {
  WickComponent({required Vector2 position})
      : super(
            position: position,
            size: Vector2(6, 15),
            anchor: Anchor.bottomCenter);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.grey[900]!;
    // Standard rendering filling the component size
    final rect = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(rect, paint);
  }
}

class CandleFlame extends PositionComponent {
  double intensity = 0.5;
  final Random _rand = Random();

  // Anchor BottomCenter ensures the position we set is the BASE of the flame
  CandleFlame({required Vector2 position})
      : super(position: position, anchor: Anchor.bottomCenter);

  @override
  void update(double dt) {
    super.update(dt);
    if (_rand.nextDouble() < intensity * 2.0) {
      // More particles
      add(
        ParticleSystemComponent(
          particle: AcceleratedParticle(
            // Start at (0,0) which is BottomCenter of this component (due to anchor?)
            // Wait, Anchor affects placement of component.
            // Children of PositionComponent are relative to TopLeft of the component?
            // No, in Flame children are relative to the component's origin point (position).
            // Actually, "Coordinate System".
            // If I add a child to PositionComponent, the child's (0,0) is at the parent's (0,0) LOCAL coordinates.
            // Component's local (0,0) is TopLeft.
            // If Anchor is BottomCenter, then (0,0) is drawn at Position - (W/2, H).
            // This is confusing for 0-size component.
            // Let's assume 0-size component with Anchor BottomCenter: (0,0) is at Position.
            // Because Size is 0.
            position: Vector2(0, 0),
            speed: Vector2((_rand.nextDouble() - 0.5) * 50,
                -100 - (_rand.nextDouble() * 250 * intensity)),
            child: ComputedParticle(
              lifespan: 1.0 + (intensity * 0.5), // Longer life if intense
              renderer: (canvas, particle) {
                final startColor =
                    Color.lerp(Colors.orange, Colors.white, intensity * 0.6)!;
                final endColor = Colors.red.withValues(alpha: 0.0);

                final paint = Paint()
                  ..color = Color.lerp(startColor, endColor, particle.progress)!
                      .withValues(alpha: (1 - particle.progress) * intensity);

                // Radius
                double r = (15 * (1 - particle.progress)) * intensity;
                canvas.drawCircle(Offset.zero, r, paint);
              },
            ),
          ),
        ),
      );
    }
  }
}

class LightingOverlay extends PositionComponent
    with HasGameReference<CandleGame> {
  double darkness = 0.5;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  void setDarkness(double d) {
    darkness = d.clamp(0.0, 0.95);
  }

  @override
  void render(Canvas canvas) {
    final center = game.size / 2;
    // The glow center should be where the flame is: center + (0, 50 - 15) roughly
    final flameCenter = center + Vector2(0, 35);

    double brightness = 1.0 - darkness;
    final radius = (game.size.length / 2) * (0.8 + (brightness * 0.5));

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: darkness * 0.1),
          Colors.black.withValues(alpha: darkness),
        ],
        stops: [0.0, 0.6 + (brightness * 0.4)],
      ).createShader(
          Rect.fromCircle(center: flameCenter.toOffset(), radius: radius));

    canvas.drawRect(size.toRect(), paint);
  }
}
