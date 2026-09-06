import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../main_game.dart';
import '../managers/unit_registry.dart';
import 'floating_text.dart';

class DummyTarget extends PositionComponent with HasGameReference<NonoCombat> {
  final double radius;
  double maxHp = 500.0;
  double currentHp = 500.0;
  double armor = 2.0;

  bool get isDead => currentHp <= 0;

  // Biến phục vụ Hit Flash
  double hitFlashTimer = 0.0;

  DummyTarget({required this.radius, required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(radius * 2),
        anchor: Anchor.center,
      );

  void takeDamage(double rawDamage) {
    if (isDead) return;

    // Công thức tính giảm trừ sát thương theo Armor chuẩn Dota 1
    double actualDamage;
    if (armor >= 0) {
      final damageReduction = (0.06 * armor) / (1 + 0.06 * armor);
      actualDamage = rawDamage * (1 - damageReduction);
    } else {
      final damageIncrease = 1 - pow(0.94, -armor).toDouble();
      actualDamage = rawDamage * (1 + damageIncrease);
    }

    currentHp = (currentHp - actualDamage).clamp(0.0, maxHp);
    hitFlashTimer = 0.1; // Bật Flash trắng trong 0.1s

    // 1. Tạo Floating Damage Text
    final damageText = FloatingDamageText(
      text: '-${actualDamage.toInt()}',
      position: position + Vector2(0, -radius - 15),
    );
    game.world.add(damageText);

    if (isDead) {
      _onDeath();
    }
  }

  void _onDeath() {
    UnitRegistry().unregisterUnit('dummy_1');
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (hitFlashTimer > 0) {
      hitFlashTimer -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(size.x / 2, size.y / 2);

    // Thân Dummy (Chớp trắng khi bị dính đòn)
    final isFlashing = hitFlashTimer > 0;
    final bodyPaint = Paint()
      ..color = isFlashing ? Colors.white : Colors.red.shade400;
    canvas.drawCircle(center, radius, bodyPaint);

    // Viền ngoài
    final borderPaint = Paint()
      ..color = isFlashing ? Colors.yellowAccent : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Thanh máu (HP Bar)
    final hpBarWidth = size.x * 1.2;
    const hpBarHeight = 6.0;
    final hpBarLeft = (size.x - hpBarWidth) / 2;
    const hpBarTop = -12.0;

    canvas.drawRect(
      Rect.fromLTWH(hpBarLeft, hpBarTop, hpBarWidth, hpBarHeight),
      Paint()..color = Colors.black87,
    );

    final hpPercent = (currentHp / maxHp).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(hpBarLeft, hpBarTop, hpBarWidth * hpPercent, hpBarHeight),
      Paint()..color = Colors.greenAccent,
    );
  }
}
