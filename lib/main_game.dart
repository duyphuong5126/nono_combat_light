import 'dart:convert';
import 'dart:math';

import 'package:a_star_algorithm/a_star_algorithm.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide PointerMoveEvent;
import 'package:nono_combat_light/replay_system.dart';

import 'components/anime_hero.dart';
import 'components/bottom_hud.dart';
import 'components/dummy_target.dart';
import 'components/projectile.dart';
import 'config/game_config.dart';
import 'managers/unit_registry.dart';
import 'models/game_command.dart';
import 'models/weapon_data.dart';

Iterable<(int, int)> _calculatePathInBackground(Map<String, dynamic> params) {
  final int rows = params['rows'];
  final int columns = params['columns'];
  final (int, int) start = params['start'];
  final (int, int) end = params['end'];
  final List<(int, int)> barriers = params['barriers'];

  final aStar = AStar(
    rows: rows,
    columns: columns,
    start: start,
    end: end,
    barriers: barriers,
  );

  return aStar.findThePath();
}

class NonoCombat extends FlameGame
    with PointerMoveCallbacks, TapCallbacks, SecondaryTapCallbacks {
  late TiledComponent mapComponent;
  late AnimeHero hero;
  late DummyTarget dummy;
  final ReplayManager replayManager = ReplayManager();

  final List<WeaponData> availableWeapons = [];

  Set<(int, int)> barrierSet = {};
  List<(int, int)> barrierList = [];

  bool isCalculatingPath = false;
  bool isPointerDown = false;
  Vector2? lastPointerPosition;
  (int, int)? _lastTargetTile;

  int currentTick = 0;
  double _accumulator = 0.0;
  static const double fixedDeltaTime = 1 / 60; // Tăng lên 60 Ticks để mượt hơn

  Vector2 _activeJoystickDirection = Vector2.zero();

  double _shakeDuration = 0.0;
  double _shakeIntensity = 0.0;
  final Random _random = Random();

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Nạp dữ liệu vũ khí từ JSON
    await _loadWeapons();

    mapComponent = await TiledComponent.load(
      'map.tmx',
      Vector2.all(GameConfig.tileSize),
      prefix: 'assets/tiles/',
    );
    world.add(mapComponent);

    _buildBarrierGrid();

    // 1. Khởi tạo Hero & đăng ký vào UnitRegistry
    hero = AnimeHero(
      radius: GameConfig.heroRadius,
      position: Vector2(GameConfig.tileSize * 1.5, GameConfig.tileSize * 1.5),
    );
    world.add(hero);
    UnitRegistry().registerUnit('hero_1', hero);

    // Trang bị vũ khí mặc định (kiếm gỗ)
    if (availableWeapons.isNotEmpty) {
      hero.equipWeapon(availableWeapons.first);
    }

    // 2. Khởi tạo Target Dummy & đăng ký vào UnitRegistry
    dummy = DummyTarget(
      radius: 18.0,
      position: Vector2(GameConfig.tileSize * 6.5, GameConfig.tileSize * 4.5),
    );
    world.add(dummy);
    UnitRegistry().registerUnit('dummy_1', dummy);

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = GameConfig.defaultZoom;

    _setupCameraViewportAndBounds();
    camera.follow(hero);

    final hudHeight = GameConfig.getBottomHudHeight(canvasSize.y);
    final safeLeft = MediaQuery.of(buildContext!).padding.left;

    final hud = BottomHudComponent(
      hudHeight: hudHeight,
      safeAreaLeft: safeLeft > 0 ? safeLeft : 20.0,
    );
    camera.viewport.add(hud);
  }

  Future<void> _loadWeapons() async {
    try {
      final String response =
          await rootBundle.loadString('assets/data/weapons.json');
      final data = await json.decode(response);
      if (data['weapons'] != null) {
        for (var item in data['weapons']) {
          availableWeapons.add(WeaponData.fromJson(item));
        }
      }
      debugPrint('Loaded ${availableWeapons.length} weapons.');
    } catch (e) {
      debugPrint('Error loading weapons: $e');
    }
  }

  void _setupCameraViewportAndBounds() {
    if (!isLoaded && !mapComponent.isLoaded) return;

    camera.viewport.size = canvasSize;

    final mapWidth = mapComponent.width;
    final mapHeight = mapComponent.height;

    final visibleRect = camera.visibleWorldRect;
    final halfWidth = visibleRect.width / 2;
    final halfHeight = visibleRect.height / 2;

    camera.setBounds(
      Rectangle.fromLTWH(
        halfWidth,
        halfHeight,
        max(0.0, mapWidth - visibleRect.width),
        max(0.0, mapHeight - visibleRect.height),
      ),
    );
  }

  void moveCameraTo(Vector2 targetWorldPos) {
    camera.stop();

    final mapWidth = mapComponent.width;
    final mapHeight = mapComponent.height;

    final visibleRect = camera.visibleWorldRect;
    final halfWidth = visibleRect.width / 2;
    final halfHeight = visibleRect.height / 2;

    final minX = halfWidth;
    final maxX = max(minX, mapWidth - halfWidth);
    final minY = halfHeight;
    final maxY = max(minY, mapHeight - halfHeight);

    final clampedX = targetWorldPos.x.clamp(minX, maxX);
    final clampedY = targetWorldPos.y.clamp(minY, maxY);

    camera.viewfinder.position = Vector2(clampedX, clampedY);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _setupCameraViewportAndBounds();
    }
  }

  void _buildBarrierGrid() {
    final tileMap = mapComponent.tileMap;
    final mapWidth = tileMap.map.width;
    final mapHeight = tileMap.map.height;

    barrierSet.clear();

    final obstacleLayer = tileMap.getLayer<TileLayer>('Obstacles');
    if (obstacleLayer != null) {
      for (var y = 0; y < mapHeight; y++) {
        for (var x = 0; x < mapWidth; x++) {
          final tileGid = obstacleLayer.tileData?[y][x].tile;
          if (tileGid != null && tileGid > 0) {
            barrierSet.add((x, y));
          }
        }
      }
    }
    barrierList = barrierSet.toList();
  }

  void triggerCameraShake({double duration = 0.15, double intensity = 4.0}) {
    _shakeDuration = duration;
    _shakeIntensity = intensity;
  }

  double getInterpolationAlpha() {
    return (_accumulator / fixedDeltaTime).clamp(0.0, 1.0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _accumulator += dt;

    while (_accumulator >= fixedDeltaTime) {
      _onTick(fixedDeltaTime);
      _accumulator -= fixedDeltaTime;
    }

    // Hiệu ứng Visual (như rung camera) vẫn có thể chạy theo FPS để mượt mà
    if (_shakeDuration > 0) {
      _shakeDuration -= dt;
      final offsetX = (_random.nextDouble() * 2 - 1) * _shakeIntensity;
      final offsetY = (_random.nextDouble() * 2 - 1) * _shakeIntensity;
      camera.viewfinder.position += Vector2(offsetX, offsetY);
    }
  }

  /// Vòng lặp Logic cố định (Deterministic Tick)
  void _onTick(double dt) {
    currentTick++;

    // 1. Xử lý Real-time Input nếu không phải Replay
    if (!replayManager.isReplayMode) {
      _handleRealTimeJoystick();
    }

    // 2. Xử lý Commands được lập lịch cho Tick này (Bao gồm cả Replay)
    final tickCommands = replayManager.recordedCommands
        .where((cmd) => cmd.tick == currentTick)
        .toList();
    for (final cmd in tickCommands) {
      _executeCommand(cmd);
    }

    // 3. Thực thi di chuyển Joystick (Deterministic)
    if (!_activeJoystickDirection.isZero()) {
      camera.follow(hero);
      hero.moveWithJoystick(_activeJoystickDirection, dt);
    }

    // 4. Cập nhật Logic của các Unit (Hero, Dummy,...)
    final allUnits = UnitRegistry().getAllUnits();
    for (final unit in allUnits) {
      if (unit is AnimeHero) {
        unit.onTick(dt);
      } else if (unit is DummyTarget) {
        unit.onTick(dt);
      }
    }

    // 5. Cập nhật Logic của Projectiles
    for (final child in world.children) {
      if (child is SkillProjectile) {
        child.onTick(dt);
      }
    }
  }

  void _handleRealTimeJoystick() {
    final hud =
        camera.viewport.children.whereType<BottomHudComponent>().firstOrNull;
    if (hud != null) {
      final joystick = hud.joystick;
      final newDir = joystick.relativeDelta.clone();

      // Throttle: Nhạy hơn một chút (giảm từ 0.05 xuống 0.01)
      final diff = (newDir - _activeJoystickDirection).length;
      if (diff > 0.01 ||
          (newDir.isZero() && !_activeJoystickDirection.isZero())) {
        final cmd = GameCommand(
          tick: currentTick,
          unitId: 'hero_1',
          type: CommandType.joystick,
          targetX: (newDir.x * 1000).roundToDouble() / 1000.0,
          targetY: (newDir.y * 1000).roundToDouble() / 1000.0,
        );
        replayManager.recordCommand(cmd);
        // Trong chế độ Real-time, ta cập nhật ngay để phản hồi tức thì
        _activeJoystickDirection = Vector2(cmd.targetX, cmd.targetY);
      }
    }
  }

  void _executeCommand(GameCommand cmd) {
    final unit = UnitRegistry().getUnit(cmd.unitId);
    if (unit == null) return;

    switch (cmd.type) {
      case CommandType.move:
        if (unit is AnimeHero && replayManager.isReplayMode) {
          // Trong chế độ Replay, ta phải kích hoạt lại tìm đường
          // Chuyển tọa độ thế giới sang tọa độ canvas để dùng lại hàm cũ (hoặc refactor hàm cũ)
          final canvasPos = camera.localToGlobal(Vector2(cmd.targetX, cmd.targetY));
          _requestPathToPosition(canvasPos);
        }
        break;
      case CommandType.attack:
        if (unit is AnimeHero) {
          final target = UnitRegistry().getUnit(cmd.targetEntityId ?? '');
          if (target is DummyTarget) {
            unit.attackTarget(target);
          }
        }
        break;
      case CommandType.joystick:
        _activeJoystickDirection = Vector2(cmd.targetX, cmd.targetY);
        break;
      case CommandType.useSkill:
        if (unit is AnimeHero) {
          unit.castSkill(Vector2(cmd.targetX, cmd.targetY));
        }
        break;
      case CommandType.stop:
        if (unit is AnimeHero) {
          unit.stopMoving();
        }
        break;
      default:
        break;
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final hudHeight = GameConfig.getBottomHudHeight(canvasSize.y);
    if (event.canvasPosition.y >= canvasSize.y - hudHeight) {
      return;
    }

    isPointerDown = true;
    lastPointerPosition = event.canvasPosition;
    _handlePointerTarget(event.canvasPosition, forceUpdate: true);
  }

  @override
  void onTapUp(TapUpEvent event) => _stopHolding();

  @override
  void onTapCancel(TapCancelEvent event) => _stopHolding();

  @override
  void onSecondaryTapDown(SecondaryTapDownEvent event) {
    _handlePointerTarget(event.canvasPosition, forceUpdate: true);
  }

  void _stopHolding() {
    isPointerDown = false;
    lastPointerPosition = null;
    _lastTargetTile = null;
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    if (!isPointerDown) return;
    lastPointerPosition = event.canvasPosition;
    _handlePointerTarget(event.canvasPosition);
  }

  void _handlePointerTarget(Vector2 canvasPos, {bool forceUpdate = false}) {
    final worldTap = camera.globalToLocal(canvasPos);

    final distToDummy = (worldTap - dummy.position).length;
    if (distToDummy <= dummy.radius + 12.0) {
      final cmd = GameCommand(
        tick: currentTick,
        unitId: 'hero_1',
        type: CommandType.attack,
        targetX: dummy.position.x,
        targetY: dummy.position.y,
        targetEntityId: 'dummy_1',
      );
      replayManager.recordCommand(cmd);
      camera.follow(hero);
      // Hero sẽ tự thực thi trong Tick tiếp theo qua _executeCommand
      return;
    }

    final realWidth = mapComponent.tileMap.map.width;
    final realHeight = mapComponent.tileMap.map.height;

    final targetX = (worldTap.x / GameConfig.tileSize).floor().clamp(
      0,
      realWidth - 1,
    );
    final targetY = (worldTap.y / GameConfig.tileSize).floor().clamp(
      0,
      realHeight - 1,
    );

    final currentTargetTile = (targetX, targetY);

    if (forceUpdate || _lastTargetTile != currentTargetTile) {
      _lastTargetTile = currentTargetTile;
      _requestPathToPosition(canvasPos);
    }
  }

  Future<void> _requestPathToPosition(Vector2 canvasPos) async {
    if (isCalculatingPath) return;

    final worldTap = camera.globalToLocal(canvasPos);
    Vector2 startPoint = hero.position;

    final realWidth = mapComponent.tileMap.map.width;
    final realHeight = mapComponent.tileMap.map.height;

    final startX = (startPoint.x / GameConfig.tileSize).floor().clamp(
      0,
      realWidth - 1,
    );
    final startY = (startPoint.y / GameConfig.tileSize).floor().clamp(
      0,
      realWidth - 1,
    );

    final rawEndX = (worldTap.x / GameConfig.tileSize).floor().clamp(
      0,
      realWidth - 1,
    );
    final rawEndY = (worldTap.y / GameConfig.tileSize).floor().clamp(
      0,
      realHeight - 1,
    );

    final validTarget = _findNearestWalkableTile(
      (rawEndX, rawEndY),
      (startX, startY),
      realWidth,
      realHeight,
    );
    if (validTarget == null) return;

    isCalculatingPath = true;

    final result = await compute(_calculatePathInBackground, {
      'rows': realHeight,
      'columns': realWidth,
      'start': (startX, startY),
      'end': validTarget,
      'barriers': barrierList,
    });

    isCalculatingPath = false;

    if (result.isNotEmpty) {
      camera.follow(hero);

      final pathPoints = result.map((point) {
        return Vector2(
          point.$1 * GameConfig.tileSize + (GameConfig.tileSize / 2),
          point.$2 * GameConfig.tileSize + (GameConfig.tileSize / 2),
        );
      }).toList();

      final cmd = GameCommand(
        tick: currentTick,
        unitId: 'hero_1',
        type: CommandType.move,
        targetX: worldTap.x,
        targetY: worldTap.y,
      );

      replayManager.recordCommand(cmd);
      // Hero sẽ tự thực thi trong Tick tiếp theo qua _executeCommand
      // Tuy nhiên, A* Pathfinding cần được gán lại
      hero.moveAlongPath(pathPoints, cmd);
    }
  }

  (int, int)? _findNearestWalkableTile(
    (int, int) target,
    (int, int) heroTile,
    int maxCols,
    int maxRows,
  ) {
    if (!barrierSet.contains(target)) return target;

    (int, int)? bestTile;
    double bestScore = double.infinity;

    const double weightTarget = 1.5;
    const double weightHero = 1.0;
    const int searchRadius = 4;

    for (int dx = -searchRadius; dx <= searchRadius; dx++) {
      for (int dy = -searchRadius; dy <= searchRadius; dy++) {
        final nx = target.$1 + dx;
        final ny = target.$2 + dy;
        final candidate = (nx, ny);

        if (nx < 0 || nx >= maxCols || ny < 0 || ny >= maxRows) continue;
        if (barrierSet.contains(candidate)) continue;

        final distToTarget = sqrt(
          pow(nx - target.$1, 2) + pow(ny - target.$2, 2),
        );
        final distToHero = sqrt(
          pow(nx - heroTile.$1, 2) + pow(ny - heroTile.$2, 2),
        );

        final score = (distToTarget * weightTarget) + (distToHero * weightHero);

        if (score < bestScore) {
          bestScore = score;
          bestTile = candidate;
        }
      }
    }

    return bestTile;
  }
}
