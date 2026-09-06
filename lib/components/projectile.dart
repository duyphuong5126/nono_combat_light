import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../main_game.dart';

class SkillProjectile extends PositionComponent
    with HasGameReference<NonoCombat> {
  final Vector2 direction;
  final double speed;
  final double range;
  final double damage;
  final String ownerId;

  double distanceTraveled = 0.0;
  final double hitRadius = 16.0;

  SkillProjectile({
    required Vector2 position,
    required this.direction,
    required this.speed,
    required this.range,
    required this.damage,
    required this.ownerId,
  }) : super(
         position: position,
         size: Vector2.all(16.0),
         anchor: Anchor.center,
       );

  @override
  void update(double dt) {
    // Để trống update, logic xử lý trong onTick
  }

  void onTick(double dt) {
    final step = speed * dt;
    position += direction * step;
    distanceTraveled += step;

    // 1. Kiểm tra va chạm với Target Dummy
    final dummy = game.dummy;
    final distToDummy = (position - dummy.position).length;
    if (distToDummy <= hitRadius + dummy.radius) {
      dummy.takeDamage(damage);
      removeFromParent(); // Xóa đạn sau khi trúng
      return;
    }

    // 2. Xóa đạn khi bay hết tầm
    if (distanceTraveled >= range) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(size.x / 2, size.y / 2);

    // Vẽ viên đạn hình tròn màu vàng cam sáng
    final paint = Paint()..color = Colors.orangeAccent;
    canvas.drawCircle(center, 8.0, paint);

    final corePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 4.0, corePaint);
  }
}
