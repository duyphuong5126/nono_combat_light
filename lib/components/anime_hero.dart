import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../enums/hero_state.dart';
import '../main_game.dart';
import '../managers/unit_registry.dart';
import '../models/game_command.dart';
import '../models/weapon_data.dart';
import 'dummy_target.dart';
import 'floating_text.dart';
import 'projectile.dart';

/// Entity Hero xử lý Render, Di chuyển, Va chạm, FSM, Combat và Skill
class AnimeHero extends PositionComponent with HasGameReference<NonoCombat> {
  final double radius;

  HeroState currentState = HeroState.idle;
  double targetAngle = 0.0;

  GameCommand? currentCommand;
  List<Vector2> pathQueue = [];
  Vector2? currentTargetPoint;

  // --- NỘI SUY HÌNH ẢNH (SMOOTHNESS) ---
  Vector2 prevPosition = Vector2.zero();
  Vector2 renderPosition = Vector2.zero();

  // --- THUỘC TÍNH COMBAT & CHỈ SỐ (DOTA 1 MECHANICS) ---
  double maxHp = 600.0;
  double currentHp = 600.0;
  double maxMp = 300.0;
  double currentMp = 300.0;
  double baseArmor = 3.0;

  // --- HỆ THỐNG VŨ KHÍ (DATA-DRIVEN) ---
  WeaponData? equippedWeapon;

  bool get isDead => currentState == HeroState.dead || currentHp <= 0;

  // --- QUẢN LÝ TẤN CÔNG (AUTO ATTACK & CHASE) ---
  DummyTarget? targetEnemy;
  double attackTimer = 0.0;
  bool hasDealtDamageInCurrentAttack = false;
  static const double chaseRange = 500.0; // Tầm nhìn để đuổi theo
  static const double autoScanRange =
      250.0; // Tầm tự động tìm mục tiêu khi idle

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
      ) {
    prevPosition = position.clone();
    renderPosition = position.clone();
  }

  /// Lệnh dừng mọi hành động (Di chuyển, Đánh thường, Gồng chiêu -> Animation Cancel)
  void stopMoving() {
    if (isDead) return;
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
    if (isDead || target.isDead) return;
    stopMoving();
    targetEnemy = target;
    currentState = HeroState.attack;
  }

  /// Trang bị vũ khí mới
  void equipWeapon(WeaponData weapon) {
    equippedWeapon = weapon;
    // Reset timer khi thay đổi vũ khí để tránh bug animation
    attackTimer = 0.0;
    hasDealtDamageInCurrentAttack = false;
    debugPrint('Equipped: ${weapon.name}');
  }

  /// Lệnh Kích hoạt Kỹ năng (Skillshot)
  void castSkill(Vector2 targetPos) {
    if (isDead || currentCooldown > 0) return; // Đang Cooldown hoặc đã chết

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

  /// Nhận sát thương và giảm trừ bởi Armor
  void takeDamage(double rawDamage) {
    if (isDead) return;

    // Công thức tính giảm sát thương chuẩn Dota 1
    double actualDamage;
    if (baseArmor >= 0) {
      final damageReduction = (0.06 * baseArmor) / (1 + 0.06 * baseArmor);
      actualDamage = rawDamage * (1 - damageReduction);
    } else {
      final damageIncrease = 1 - pow(0.94, -baseArmor).toDouble();
      actualDamage = rawDamage * (1 + damageIncrease);
    }

    currentHp = (currentHp - actualDamage).clamp(0.0, maxHp);

    // Hiển thị Floating Damage Text
    final damageText = FloatingDamageText(
      text: '-${actualDamage.toInt()}',
      position: position + Vector2(0, -radius - 20),
    );
    game.world.add(damageText);

    if (currentHp <= 0) {
      _onDeath();
    }
  }

  void _onDeath() {
    currentState = HeroState.dead;
    stopMoving();
    UnitRegistry().unregisterUnit('hero_1');
    removeFromParent();
  }

  /// Di chuyển bằng Joystick có xử lý trượt vật cản (Slide Collision)
  void moveWithJoystick(Vector2 direction, double dt) {
    if (isDead || direction.isZero()) return;

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

    // Xử lý trượt tường độc lập trên từng trục (Bao gồm va chạm với Unit)
    if (!_isCollidingAt(Vector2(nextX, position.y))) {
      position.x = nextX;
    }

    if (!_isCollidingAt(Vector2(position.x, nextY))) {
      position.y = nextY;
    }
  }

  /// Kiểm tra va chạm tổng hợp (Tường + Unit khác)
  bool _isCollidingAt(Vector2 candidatePos) {
    // 1. Va chạm với vật cản trên Map (Tiles)
    if (_isCollidingWithBarrierAt(candidatePos)) return true;

    // 2. Va chạm với các Unit khác (Entities)
    final allUnits = UnitRegistry().getAllUnits();
    for (final unit in allUnits) {
      if (unit == this || !unit.isMounted) continue;

      double otherRadius = 0;
      if (unit is AnimeHero) otherRadius = unit.radius;
      if (unit is DummyTarget) otherRadius = unit.radius;

      final dist = (candidatePos - unit.position).length;
      if (dist < (radius + otherRadius)) {
        return true;
      }
    }

    return false;
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
    if (isDead) return;
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
    // Nội suy vị trí hiển thị dựa trên accumulator của game
    final alpha = game.getInterpolationAlpha();
    renderPosition = prevPosition + (position - prevPosition) * alpha;
  }

  /// Logic nghiệp vụ chạy theo Fixed Tick Rate
  void onTick(double dt) {
    if (isDead) return;

    prevPosition = position.clone();

    // Cập nhật Cooldown Skill
    if (currentCooldown > 0) {
      currentCooldown = (currentCooldown - dt).clamp(0.0, skillCooldown);
    }

    switch (currentState) {
      case HeroState.idle:
        _handleIdleState(dt);
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

  /// Logic khi đứng yên: Tự động tìm mục tiêu gần đó
  void _handleIdleState(double dt) {
    // Quét tìm kẻ địch mỗi frame khi idle
    final allUnits = UnitRegistry().getAllUnits();
    DummyTarget? closestEnemy;
    double minPathDist = double.infinity;

    for (final unit in allUnits) {
      if (unit is DummyTarget && !unit.isDead) {
        final dist = (unit.position - position).length;
        if (dist <= autoScanRange && dist < minPathDist) {
          minPathDist = dist;
          closestEnemy = unit;
        }
      }
    }

    if (closestEnemy != null) {
      attackTarget(closestEnemy);
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
      final nextPos =
          position + distanceVector.normalized() * min(step, distance);

      // Khi di chuyển A*, nếu gặp vật cản Unit thì tạm dừng hoặc tìm cách lách (ở đây ta dừng để tránh chồng lấn)
      if (!_isCollidingAt(nextPos)) {
        position = nextPos;
      } else {
        // Nếu bị kẹt bởi Unit, coi như đã đến nơi hoặc dừng lại
        pathQueue.clear();
        currentTargetPoint = null;
        currentState = HeroState.idle;
      }

      _clampPositionToMap();
    }
  }

  /// Logic Đánh thường & Đuổi theo (Chase) chuẩn Dota
  void _handleAttackState(double dt) {
    if (targetEnemy == null || targetEnemy!.isDead || equippedWeapon == null) {
      targetEnemy = null;
      currentState = HeroState.idle;
      return;
    }

    final distanceVector = targetEnemy!.position - position;
    final distance = distanceVector.length;

    // 1. Tự động di chuyển vào tầm đánh nếu chưa đủ gần (Auto-Chase)
    if (distance > equippedWeapon!.range) {
      // Nếu mục tiêu quá xa tầm nhìn đuổi theo thì dừng lại
      if (distance > chaseRange) {
        stopMoving();
        return;
      }

      targetAngle = atan2(distanceVector.y, distanceVector.x);
      _updateRotation(targetAngle, dt);

      final step = GameConfig.heroMoveSpeed * dt;
      final dir = distanceVector.normalized();

      final nextX = position.x + dir.x * step;
      final nextY = position.y + dir.y * step;

      // Vẫn xử lý va chạm khi đuổi theo
      if (!_isCollidingWithBarrierAt(Vector2(nextX, position.y))) {
        position.x = nextX;
      }
      if (!_isCollidingWithBarrierAt(Vector2(position.x, nextY))) {
        position.y = nextY;
      }

      _clampPositionToMap();
      // Khi đang đuổi theo, reset timer tấn công để đảm bảo khi vào tầm mới bắt đầu vung tay
      attackTimer = 0.0;
      hasDealtDamageInCurrentAttack = false;
      return;
    }

    // 2. Xoay mặt về mục tiêu
    targetAngle = atan2(distanceVector.y, distanceVector.x);
    final isFacing = _updateRotation(targetAngle, dt);

    if (!isFacing) return;

    // 3. Tiến trình Attack Point & Backswing
    attackTimer += dt;

    if (attackTimer >= equippedWeapon!.attackPoint &&
        !hasDealtDamageInCurrentAttack) {
      hasDealtDamageInCurrentAttack = true;
      _executeDamage(targetEnemy!);
    }

    if (attackTimer >= equippedWeapon!.totalAttackCycle) {
      attackTimer = 0.0;
      hasDealtDamageInCurrentAttack = false;
    }
  }

  void _executeDamage(DummyTarget target) {
    if (equippedWeapon == null) return;

    if (equippedWeapon!.type == WeaponType.melee) {
      // Đánh cận chiến: Gây sát thương trực tiếp
      target.takeDamage(equippedWeapon!.damage);
      // Hiệu ứng rung camera nhẹ khi đánh trúng
      game.triggerCameraShake(intensity: 2.0);
    } else {
      // Đánh xa: Bắn Projectile
      final dir = (target.position - position).normalized();
      final projectile = SkillProjectile(
        position: position.clone(),
        direction: dir,
        speed: equippedWeapon!.projectileSpeed,
        range: equippedWeapon!.range + 50,
        // Thêm một chút buffer
        damage: equippedWeapon!.damage,
        ownerId: 'hero_1',
      );
      game.world.add(projectile);
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
    // Sử dụng renderPosition thay vì position để mượt mà
    final drawOffset = renderPosition - position;
    canvas.save();
    canvas.translate(drawOffset.x, drawOffset.y);

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

    // --- RENDER HP & MP BAR TRÊN ĐẦU HERO ---
    final barWidth = size.x * 1.3;
    const barHeight = 5.0;
    final barLeft = (size.x - barWidth) / 2;
    const hpTop = -16.0;
    const mpTop = -10.0;

    // HP Background & Green Bar
    canvas.drawRect(
      Rect.fromLTWH(barLeft, hpTop, barWidth, barHeight),
      Paint()..color = Colors.black87,
    );
    final hpPercent = (currentHp / maxHp).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(barLeft, hpTop, barWidth * hpPercent, barHeight),
      Paint()..color = Colors.greenAccent,
    );

    // MP Background & Blue Bar
    canvas.drawRect(
      Rect.fromLTWH(barLeft, mpTop, barWidth, barHeight - 1),
      Paint()..color = Colors.black87,
    );
    final mpPercent = (currentMp / maxMp).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(barLeft, mpTop, barWidth * mpPercent, barHeight - 1),
      Paint()..color = Colors.lightBlueAccent,
    );

    canvas.restore();
  }
}
