import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FloatingDamageText extends PositionComponent {
  final String text;
  final Color color;
  double opacity = 1.0;
  double lifetime = 0.6; // Tồn tại trong 0.6s
  double elapsed = 0.0;
  final double floatSpeed = 40.0;

  FloatingDamageText({
    required this.text,
    required Vector2 position,
    this.color = Colors.redAccent,
  }) : super(position: position);

  @override
  void update(double dt) {
    super.update(dt);
    elapsed += dt;

    // Bay lên trên
    position.y -= floatSpeed * dt;

    // Mờ dần theo thời gian
    opacity = (1.0 - (elapsed / lifetime)).clamp(0.0, 1.0);

    if (elapsed >= lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Phóng to nhẹ lúc vừa xuất hiện (Scale Effect)
    final scale = 1.0 + (0.3 * (1.0 - (elapsed / lifetime)));

    final textStyle = TextStyle(
      color: color.withValues(alpha: opacity),
      fontSize: 14.0 * scale,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          blurRadius: 2.0,
          color: Colors.black.withValues(alpha: opacity),
          offset: const Offset(1, 1),
        ),
      ],
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
  }
}
