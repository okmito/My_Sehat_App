import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class RippleGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFFE3F2FD); // Light Blue background

  @override
  Future<void> onLoad() async {
    // Add subtle background movement or gradient?
    // For now simple background color is clean, but maybe we can add a simple
    // animated gradient overlay if requested.
  }

  void addRipple(Vector2 position) {
    // Add main organic ripple
    add(RippleComponent(position: position));

    // Add a second delayed one slightly offset for irregularity
    Future.delayed(const Duration(milliseconds: 150), () {
      add(RippleComponent(position: position));
    });

    // Add splashes
    _addSplash(position);
  }

  void _addSplash(Vector2 position) {
    final rand = Random();
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 12,
          lifespan: 0.8,
          generator: (i) => AcceleratedParticle(
            position: position,
            speed: Vector2(
              (rand.nextDouble() - 0.5) * 300,
              (rand.nextDouble() - 0.5) * 300,
            ),
            child: ComputedParticle(renderer: (canvas, particle) {
              // "Splashes" as small soft droplets
              final paint = Paint()
                ..color =
                    Colors.blueAccent.withOpacity((1 - particle.progress) * 0.7)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

              canvas.drawCircle(
                  Offset.zero, 3.0 * (1 - particle.progress), paint);
            }),
          ),
        ),
      ),
    );
  }
}

class RippleComponent extends PositionComponent {
  double radius = 10;
  double opacity = 1.0;
  final double maxRadius = 200.0;
  final double speed = 150.0;

  // Organic variation
  final double variationSeed = Random().nextDouble();

  RippleComponent({required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    radius += speed * dt;
    // Non-linear fade for better look
    double progress = radius / maxRadius;
    opacity = (1.0 - pow(progress, 2)).toDouble().clamp(0.0, 1.0);

    if (radius >= maxRadius) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0) return;

    // Use Blur to make it look like water refraction/softness
    final paint = Paint()
      ..color = Colors.blue.withOpacity(opacity * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 * opacity // Thicker, fading out
      ..maskFilter =
          const MaskFilter.blur(BlurStyle.normal, 4.0); // Soft glow/shadow

    // Draw slightly imperfect circle (oval-ish) to feel organic
    // actually, canvas.drawOval is better for 'perspective' feel if we want,
    // but just a circle is fine if blured.
    // Let's add an "inner" ripple for 3D effect (highlight/shadow)

    // Main Body (Darker/Shadow)
    canvas.drawCircle(Offset.zero, radius, paint);

    // Highlight (White/Bright) slightly inset
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * opacity
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.drawCircle(Offset.zero, radius * 0.9, highlightPaint);
  }
}
