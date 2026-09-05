import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../enums/hero_state.dart';
import '../main_game.dart';
import '../models/game_command.dart';

class AnimeHero extends PositionComponent with HasGameReference<NonoCombat> {
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

  /// Di chuyển bằng Joystick có kiểm tra va chạm chính xác theo hình học
  void moveWithJoystick(Vector2 direction, double dt) {
    if (direction.isZero()) return;

    stopMoving();

    targetAngle = atan2(direction.y, direction.x);
    _updateRotation(targetAngle, dt);

    final step = GameConfig.heroMoveSpeed * dt;
    final stepVector = direction.normalized() * step;

    final mapWidth = game.mapComponent.width;
    final mapHeight = game.mapComponent.height;

    // 1. Vị trí dự định kế tiếp
    var nextX = position.x + stepVector.x;
    var nextY = position.y + stepVector.y;

    // 2. Kẹp biên map
    nextX = nextX.clamp(radius, mapWidth - radius);
    nextY = nextY.clamp(radius, mapHeight - radius);

    // 3. Trượt theo vật cản (Slide movement): Kiểm tra từng trục riêng biệt
    if (!_isCollidingWithBarrierAt(Vector2(nextX, position.y))) {
      position.x = nextX;
    }

    if (!_isCollidingWithBarrierAt(Vector2(position.x, nextY))) {
      position.y = nextY;
    }
  }

  /// Thuật toán kiểm tra va chạm Hình tròn (Circle) vs Hình chữ nhật (AABB - Axis-Aligned Bounding Box)
  /// Đảm bảo không bị lấn góc dù đối tượng cản có hình dạng góc nhọn hay phức tạp
  bool _isCollidingWithBarrierAt(Vector2 candidatePos) {
    final tileSize = GameConfig.tileSize;

    // Chỉ quét các ô tile trong vùng lân cận quanh tâm Hero để tối ưu hiệu năng
    final minTileX = ((candidatePos.x - radius) / tileSize).floor();
    final maxTileX = ((candidatePos.x + radius) / tileSize).floor();
    final minTileY = ((candidatePos.y - radius) / tileSize).floor();
    final maxTileY = ((candidatePos.y + radius) / tileSize).floor();

    for (var tx = minTileX; tx <= maxTileX; tx++) {
      for (var ty = minTileY; ty <= maxTileY; ty++) {
        if (game.barrierSet.contains((tx, ty))) {
          // Định vị AABB của ô vật cản vuông/chữ nhật
          final boxLeft = tx * tileSize;
          final boxTop = ty * tileSize;
          final boxRight = boxLeft + tileSize;
          final boxBottom = boxTop + tileSize;

          // Tìm điểm trên/trong AABB gần với tâm Hero nhất
          final closestX = candidatePos.x.clamp(boxLeft, boxRight);
          final closestY = candidatePos.y.clamp(boxTop, boxBottom);

          // Tính khoảng cách từ tâm Hero tới điểm gần nhất đó
          final distX = candidatePos.x - closestX;
          final distY = candidatePos.y - closestY;
          final distanceSquared = (distX * distX) + (distY * distY);

          // Va chạm xảy ra nếu khoảng cách nhỏ hơn bán kính
          if (distanceSquared < (radius * radius)) {
            return true;
          }
        }
      }
    }
    return false;
  }

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

    if (distance < 6.0) {
      position = currentTargetPoint!.clone();
      _clampPositionToMap();
      if (pathQueue.isNotEmpty) {
        currentTargetPoint = pathQueue.removeAt(0);
      } else {
        currentTargetPoint = null;
        currentState = HeroState.idle;
      }
      return;
    }

    targetAngle = atan2(distanceVector.y, distanceVector.x);
    final isFacingTarget = _updateRotation(targetAngle, dt);

    if (isFacingTarget) {
      final step = GameConfig.heroMoveSpeed * dt;
      position += distanceVector.normalized() * min(step, distance);
      _clampPositionToMap();
    }
  }

  void _clampPositionToMap() {
    if (!isMounted) return;
    final mapWidth = game.mapComponent.width;
    final mapHeight = game.mapComponent.height;

    if (mapWidth > 0 && mapHeight > 0) {
      position.x = position.x.clamp(radius, mapWidth - radius);
      position.y = position.y.clamp(radius, mapHeight - radius);
    }
  }

  bool _updateRotation(double target, double dt) {
    var diff = target - angle;

    while (diff < -pi) diff += pi * 2;
    while (diff > pi) diff -= pi * 2;

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
