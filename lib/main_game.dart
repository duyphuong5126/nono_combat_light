import 'dart:math';

import 'package:a_star_algorithm/a_star_algorithm.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';

import 'components/anime_hero.dart';
import 'components/bottom_hud.dart';
import 'config/game_config.dart';
import 'models/game_command.dart';

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

class NonoCombat extends FlameGame with PointerMoveCallbacks, TapCallbacks {
  late TiledComponent mapComponent;
  late AnimeHero hero;

  Set<(int, int)> barrierSet = {};
  List<(int, int)> barrierList = [];

  bool isCalculatingPath = false;
  bool isPointerDown = false;
  Vector2? lastPointerPosition;
  (int, int)? _lastTargetTile;

  int currentTick = 0;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    mapComponent = await TiledComponent.load(
      'map.tmx',
      Vector2.all(GameConfig.tileSize),
      prefix: 'assets/tiles/',
    );
    world.add(mapComponent);

    _buildBarrierGrid();

    hero = AnimeHero(
      radius: GameConfig.heroRadius,
      position: Vector2(GameConfig.tileSize * 1.5, GameConfig.tileSize * 1.5),
    );
    world.add(hero);

    camera.follow(hero);
    camera.viewfinder.zoom = GameConfig.defaultZoom;

    _setupCameraViewportAndBounds();

    // Khởi tạo HUD với 2/5 chiều cao màn hình
    final hudHeight = GameConfig.getBottomHudHeight(canvasSize.y);
    camera.viewport.add(BottomHudComponent(hudHeight: hudHeight));
  }

  void _setupCameraViewportAndBounds() {
    if (!isLoaded && !mapComponent.isLoaded) return;

    final gameSize = canvasSize;
    final hudHeight = GameConfig.getBottomHudHeight(gameSize.y);

    // Cập nhật Viewport dành cho phần màn hình chơi game (3/5 còn lại ở phía trên)
    camera.viewport.size = Vector2(gameSize.x, gameSize.y - hudHeight);

    final mapWidth = mapComponent.width;
    final mapHeight = mapComponent.height;

    final halfViewport =
        camera.viewport.virtualSize / (2 * GameConfig.defaultZoom);

    camera.setBounds(
      Rectangle.fromLTWH(
        halfViewport.x,
        halfViewport.y,
        max(0.0, mapWidth - (halfViewport.x * 2)),
        max(0.0, mapHeight - (halfViewport.y * 2)),
      ),
    );
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

  @override
  void update(double dt) {
    super.update(dt);
    currentTick++;
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

  void _stopHolding() {
    isPointerDown = false;
    lastPointerPosition = null;
    _lastTargetTile = null;
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    if (!isPointerDown) return;

    final hudHeight = GameConfig.getBottomHudHeight(canvasSize.y);
    if (event.canvasPosition.y >= canvasSize.y - hudHeight) {
      return;
    }
    lastPointerPosition = event.canvasPosition;
    _handlePointerTarget(event.canvasPosition);
  }

  void _handlePointerTarget(Vector2 canvasPos, {bool forceUpdate = false}) {
    final worldTap = camera.globalToLocal(canvasPos);

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
      realHeight - 1,
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

      // Tạo GameCommand chuẩn bị sẵn sàng cho Replay[span_8](start_span)[span_8](end_span)
      final cmd = GameCommand(
        tick: currentTick,
        unitId: 'hero_1',
        type: CommandType.move,
        targetX: worldTap.x,
        targetY: worldTap.y,
      );

      // Gửi nguyên chuỗi đường đi cho AnimeHero xử lý mượt mà[span_9](start_span)[span_9](end_span)
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
