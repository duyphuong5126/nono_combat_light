import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../enums/hero_state.dart';
import '../models/game_command.dart';

class AnimeHero extends PositionComponent {
  final double radius;

  HeroState currentState = HeroState.idle;
  double targetAngle = 0.0;

  GameCommand? currentCommand;
  List<Vector2> pathQueue = [];
  Vector2? currentTargetPoint;

  AnimeHero({required this.radius, required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(radius * 2),
        anchor: Anchor.center,
      );

  /// Nhận toàn bộ đường đi từ A* Pathfinding[span_0](start_span)[span_0](end_span)
  void moveAlongPath(List<Vector2> path, GameCommand command) {
    currentCommand = command;
    pathQueue = List.from(path);
    if (pathQueue.isNotEmpty) {
      currentTargetPoint = pathQueue.removeAt(0);
      currentState = HeroState.move;
    } else {
      currentState = HeroState.idle;
    }
  }

  void stopMoving() {
    pathQueue.clear();
    currentTargetPoint = null;
    currentState = HeroState.idle;
  }

  @override
  void update(double dt) {
    super.update(dt);

    switch (currentState) {
      case HeroState.idle:
        break;
      case HeroState.move:
        _handleMoveState(dt);
        break;
      case HeroState.attack:
        break;
      case HeroState.casting:
        break;
      case HeroState.stunned:
        break;
      case HeroState.dead:
        break;
    }
  }

  void _handleMoveState(double dt) {
    if (currentTargetPoint == null) {
      if (pathQueue.isNotEmpty) {
        currentTargetPoint = pathQueue.removeAt(0);
      } else {
        currentState = HeroState.idle;
        return;
      }
    }

    final distanceVector = currentTargetPoint! - position;
    final distance = distanceVector.length;

    // Khi đã đến đủ gần điểm waypoint hiện tại
    if (distance < 6.0) {
      position = currentTargetPoint!.clone();
      if (pathQueue.isNotEmpty) {
        currentTargetPoint = pathQueue.removeAt(0);
      } else {
        currentTargetPoint = null;
        currentState = HeroState.idle;
      }
      return;
    }

    // 1. Tính toán góc quay hướng tới điểm tiếp theo
    targetAngle = atan2(distanceVector.y, distanceVector.x);

    // 2. Cập nhật góc xoay theo Turn Rate[span_1](start_span)[span_1](end_span)[span_2](start_span)[span_2](end_span)
    final isFacingTarget = _updateRotation(targetAngle, dt);

    // 3. Tiến bước khi mặt đã quay đủ hướng[span_3](start_span)[span_3](end_span)[span_4](start_span)[span_4](end_span)
    if (isFacingTarget) {
      final step = GameConfig.heroMoveSpeed * dt;
      position += distanceVector.normalized() * min(step, distance);
    }
  }

  bool _updateRotation(double target, double dt) {
    var diff = target - angle;

    while (diff < -pi) {
      diff += pi * 2;
    }
    while (diff > pi) {
      diff -= pi * 2;
    }

    if (diff.abs() <= GameConfig.turnTolerance) {
      angle = target;
      return true;
    }

    final turnStep = GameConfig.heroTurnRate * dt;
    if (diff > 0) {
      angle += min(diff, turnStep);
    } else {
      angle -= min(-diff, turnStep);
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(size.x / 2, size.y / 2);

    final bodyPaint = Paint()..color = GameConfig.heroColor;
    canvas.drawCircle(center, radius, bodyPaint);

    final eyePaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.x * 0.8, size.y / 2), 4.0, eyePaint);
  }
}
