import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../enums/hero_state.dart';
import '../main_game.dart';
import '../models/game_command.dart';
import 'dummy_target.dart';
import 'projectile.dart';

/// Entity Hero xử lý Render, Di chuyển, Va chạm, FSM, Combat và Skill
class AnimeHero extends PositionComponent with HasGameReference<NonoCombat> {
  final double radius;

  HeroState currentState = HeroState.idle;
  double targetAngle = 0.0;

  GameCommand? currentCommand;
  List<Vector2> pathQueue = [];
  Vector2? currentTargetPoint;

  // --- QUẢN LÝ TẤN CÔNG (AUTO ATTACK) ---
  DummyTarget? targetEnemy;
  double attackTimer = 0.0;
  bool hasDealtDamageInCurrentAttack = false;

  // --- QUẢN LÝ KỸ NĂNG (SKILLSHOT) ---
  Vector2? skillTargetPoint;
  double castTimer = 0.0;
  static const double skillCastPoint = 0.25; // Gồng chiêu 0.25s
  static const double skillCooldown = 3.0; // Cooldown 3s
  double currentCooldown = 0.0;

  AnimeHero({required this.radius, required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(radius * 2),
        anchor: Anchor.center,
      );

  /// Lệnh dừng mọi hành động (Di chuyển, Đánh thường, Gồng chiêu -> Animation Cancel)
  /// LƯU Ý: Đây là hàm custom của game, KHÔNG CÓ @override
  void stopMoving() {
    pathQueue.clear();
    currentTargetPoint = null;
    targetEnemy = null;
    skillTargetPoint = null;
    attackTimer = 0.0;
    castTimer = 0.0;
    hasDealtDamageInCurrentAttack = false;
    currentState = HeroState.idle;
  }

  /// Lệnh Tấn công mục tiêu
  void attackTarget(DummyTarget target) {
    stopMoving();
    targetEnemy = target;
    currentState = HeroState.attack;
  }

  /// Lệnh Kích hoạt Kỹ năng (Skillshot)
  void castSkill(Vector2 targetPos) {
    if (currentCooldown > 0) return; // Đang Cooldown

    stopMoving();
    skillTargetPoint = targetPos;
    currentState = HeroState.casting;
  }

  /// Bắn ra luồng chưởng Projectile
  void _fireSkillProjectile(Vector2 direction) {
    final projectile = SkillProjectile(
      position: position.clone(),
      direction: direction,
      speed: 450.0,
      range: 400.0,
      damage: 120.0,
      ownerId: 'hero_1',
    );
    game.world.add(projectile);
  }

  /// Di chuyển bằng Joystick có xử lý trượt vật cản (Slide Collision)
  void moveWithJoystick(Vector2 direction, double dt) {
    if (direction.isZero()) return;

    // Hủy các hành động cũ khi dùng Joystick
    if (currentState != HeroState.move || pathQueue.isNotEmpty) {
      stopMoving();
    }

    targetAngle = atan2(direction.y, direction.x);
    _updateRotation(targetAngle, dt);

    final step = GameConfig.heroMoveSpeed * dt;
    final stepVector = direction.normalized() * step;

    final mapWidth = game.mapComponent.width;
    final mapHeight = game.mapComponent.height;

    var nextX = (position.x + stepVector.x).clamp(radius, mapWidth - radius);
    var nextY = (position.y + stepVector.y).clamp(radius, mapHeight - radius);

    // Xử lý trượt tường độc lập trên từng trục
    if (!_isCollidingWithBarrierAt(Vector2(nextX, position.y))) {
      position.x = nextX;
    }

    if (!_isCollidingWithBarrierAt(Vector2(position.x, nextY))) {
      position.y = nextY;
    }
  }

  /// Va chạm Circle vs AABB Tile
  bool _isCollidingWithBarrierAt(Vector2 candidatePos) {
    final tileSize = GameConfig.tileSize;

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

          final closestX = candidatePos.x.clamp(boxLeft, boxRight);
          final closestY = candidatePos.y.clamp(boxTop, boxBottom);

          final distX = candidatePos.x - closestX;
          final distY = candidatePos.y - closestY;
          final distanceSquared = (distX * distX) + (distY * distY);

          if (distanceSquared < (radius * radius)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Nhận chuỗi đường đi từ A*
  void moveAlongPath(List<Vector2> path, GameCommand command) {
    stopMoving();
    currentCommand = command;
    pathQueue = List.from(path);
    if (pathQueue.isNotEmpty) {
      currentTargetPoint = pathQueue.removeAt(0);
      currentState = HeroState.move;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Cập nhật Cooldown Skill
    if (currentCooldown > 0) {
      currentCooldown = (currentCooldown - dt).clamp(0.0, skillCooldown);
    }

    switch (currentState) {
      case HeroState.idle:
        break;
      case HeroState.move:
        _handleMoveState(dt);
        break;
      case HeroState.attack:
        _handleAttackState(dt);
        break;
      case HeroState.casting:
        _handleCastingState(dt);
        break;
      case HeroState.stunned:
        break;
      case HeroState.dead:
        break;
    }
  }

  /// Logic di chuyển theo đường A*
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

  /// Logic Đánh thường chuẩn Dota (Kiểm tra va chạm để không lấn ô tường)
  void _handleAttackState(double dt) {
    if (targetEnemy == null) {
      currentState = HeroState.idle;
      return;
    }

    final distanceVector = targetEnemy!.position - position;
    final distance = distanceVector.length;

    // 1. Tự động di chuyển vào tầm đánh nếu chưa đủ gần (Có check va chạm)
    if (distance > GameConfig.attackRange) {
      targetAngle = atan2(distanceVector.y, distanceVector.x);
      _updateRotation(targetAngle, dt);

      final step = GameConfig.heroMoveSpeed * dt;
      final dir = distanceVector.normalized();

      final nextX = position.x + dir.x * step;
      final nextY = position.y + dir.y * step;

      if (!_isCollidingWithBarrierAt(Vector2(nextX, position.y))) {
        position.x = nextX;
      }
      if (!_isCollidingWithBarrierAt(Vector2(position.x, nextY))) {
        position.y = nextY;
      }

      _clampPositionToMap();
      return;
    }

    // 2. Xoay mặt về mục tiêu
    targetAngle = atan2(distanceVector.y, distanceVector.x);
    final isFacing = _updateRotation(targetAngle, dt);

    if (!isFacing) return;

    // 3. Tiến trình Attack Point & Backswing
    attackTimer += dt;

    if (attackTimer >= GameConfig.attackPoint &&
        !hasDealtDamageInCurrentAttack) {
      hasDealtDamageInCurrentAttack = true;
      targetEnemy!.takeDamage(50.0);
    }

    final totalAttackCycle = GameConfig.attackPoint + GameConfig.backswing;
    if (attackTimer >= totalAttackCycle) {
      attackTimer = 0.0;
      hasDealtDamageInCurrentAttack = false;
    }
  }

  /// Logic Gồng chiêu & Thi triển Skillshot
  void _handleCastingState(double dt) {
    if (skillTargetPoint == null) {
      currentState = HeroState.idle;
      return;
    }

    final dir = skillTargetPoint! - position;
    targetAngle = atan2(dir.y, dir.x);
    final isFacing = _updateRotation(targetAngle, dt);

    if (!isFacing) return;

    castTimer += dt;

    if (castTimer >= skillCastPoint) {
      _fireSkillProjectile(dir.normalized());
      currentCooldown = skillCooldown;
      skillTargetPoint = null;
      castTimer = 0.0;
      currentState = HeroState.idle;
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

  /// Cập nhật Turn Rate
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

    // Điểm đỏ hướng mặt
    final eyePaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.x * 0.8, size.y / 2), 4.0, eyePaint);

    // Vòng cung hiệu ứng khi tung đòn đánh (Backswing)
    if (currentState == HeroState.attack && hasDealtDamageInCurrentAttack) {
      final swingPaint = Paint()
        ..color = Colors.yellowAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 10),
        -pi / 4,
        pi / 2,
        false,
        swingPaint,
      );
    }
  }
}
