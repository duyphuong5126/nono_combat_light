import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../enums/hero_state.dart';
import '../main_game.dart';
import '../models/game_command.dart';

/// Entity Nhân vật chính (Hero) xử lý Render, Di chuyển, Va chạm & FSM
class AnimeHero extends PositionComponent with HasGameReference<NonoCombat> {
  final double radius;

  HeroState currentState = HeroState.idle;
  double targetAngle = 0.0;

  GameCommand? currentCommand;
  List<Vector2> pathQueue = []; // Hàng chờ các điểm tọa độ cần đi qua (A* Path)
  Vector2? currentTargetPoint; // Điểm đến trung gian hiện tại

  AnimeHero({required this.radius, required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(radius * 2),
        anchor: Anchor.center,
      );

  /// Di chuyển bằng Joystick có xử lý trượt vật cản (Slide Collision)
  void moveWithJoystick(Vector2 direction, double dt) {
    if (direction.isZero()) return;

    stopMoving(); // Hủy bỏ đường đi A* nếu đang chạy tự động

    targetAngle = atan2(direction.y, direction.x);
    _updateRotation(targetAngle, dt);

    final step = GameConfig.heroMoveSpeed * dt;
    final stepVector = direction.normalized() * step;

    final mapWidth = game.mapComponent.width;
    final mapHeight = game.mapComponent.height;

    var nextX = position.x + stepVector.x;
    var nextY = position.y + stepVector.y;

    // Kẹp biên bản đồ
    nextX = nextX.clamp(radius, mapWidth - radius);
    nextY = nextY.clamp(radius, mapHeight - radius);

    // Kiểm tra trượt từng trục riêng biệt để không bị kẹt khi đi chéo vào tường
    if (!_isCollidingWithBarrierAt(Vector2(nextX, position.y))) {
      position.x = nextX;
    }

    if (!_isCollidingWithBarrierAt(Vector2(position.x, nextY))) {
      position.y = nextY;
    }
  }

  /// Thuật toán kiểm tra va chạm Hình tròn (Hero) vs Hình chữ nhật AABB (Tile Vật cản)
  bool _isCollidingWithBarrierAt(Vector2 candidatePos) {
    final tileSize = GameConfig.tileSize;

    // Chỉ kiểm tra các tile nằm trong phạm vi lân cận quanh vị trí dự định của Hero
    final minTileX = ((candidatePos.x - radius) / tileSize).floor();
    final maxTileX = ((candidatePos.x + radius) / tileSize).floor();
    final minTileY = ((candidatePos.y - radius) / tileSize).floor();
    final maxTileY = ((candidatePos.y + radius) / tileSize).floor();

    for (var tx = minTileX; tx <= maxTileX; tx++) {
      for (var ty = minTileY; ty <= maxTileY; ty++) {
        if (game.barrierSet.contains((tx, ty))) {
          final boxLeft = tx * tileSize;
          final boxTop = ty * tileSize;
          final boxRight = boxLeft + tileSize;
          final boxBottom = boxTop + tileSize;

          // Tìm điểm trên AABB gần tâm Hero nhất
          final closestX = candidatePos.x.clamp(boxLeft, boxRight);
          final closestY = candidatePos.y.clamp(boxTop, boxBottom);

          final distX = candidatePos.x - closestX;
          final distY = candidatePos.y - closestY;
          final distanceSquared = (distX * distX) + (distY * distY);

          if (distanceSquared < (radius * radius)) {
            return true; // Xảy ra va chạm
          }
        }
      }
    }
    return false;
  }

  /// Nhận chuỗi đường đi từ thuật toán A* và bắt đầu di chuyển
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

  /// Dừng mọi hành động di chuyển
  void stopMoving() {
    pathQueue.clear();
    currentTargetPoint = null;
    currentState = HeroState.idle;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Cập nhật Máy trạng thái (FSM)
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

  /// Xử lý di chuyển từng bước theo chuỗi đường đi A*
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

    // Khi đã đến đủ gần điểm trung gian (khoảng cách < 6px)
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

    // Tính toán góc quay và tiến lên khi đã quay đúng hướng
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

  /// Cập nhật hướng quay của Hero dựa trên Tốc độ quay (Turn Rate) kiểu Dota
  bool _updateRotation(double target, double dt) {
    var diff = target - angle;

    // Chuẩn hóa góc chênh lệch về khoảng [-pi, pi]
    while (diff < -pi) {
      diff += pi * 2;
    }
    while (diff > pi) {
      diff -= pi * 2;
    }

    if (diff.abs() <= GameConfig.turnTolerance) {
      angle = target;
      return true; // Đã quay đúng hướng mong muốn
    }

    final turnStep = GameConfig.heroTurnRate * dt;
    if (diff > 0) {
      angle += min(diff, turnStep);
    } else {
      angle -= min(-diff, turnStep);
    }

    return false; // Đang trong quá trình quay
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(size.x / 2, size.y / 2);
    final bodyPaint = Paint()..color = GameConfig.heroColor;
    canvas.drawCircle(center, radius, bodyPaint);

    // Vẽ điểm đỏ đánh dấu hướng mặt của Hero
    final eyePaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.x * 0.8, size.y / 2), 4.0, eyePaint);
  }
}
