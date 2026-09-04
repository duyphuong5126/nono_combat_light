import 'package:a_star_algorithm/a_star_algorithm.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game_config.dart';

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

class DotaGame extends FlameGame with TapCallbacks {
  late TiledComponent mapComponent;
  late CircleComponent hero;

  Set<(int, int)> barrierSet = {};
  List<(int, int)> barrierList = [];
  List<Vector2> currentPath = [];
  bool isCalculatingPath = false;

  // Khai báo chiều cao của Thanh HUD phía dưới
  static const double bottomHudHeight = 160.0;

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

    hero = CircleComponent(
      radius: GameConfig.heroRadius,
      paint: Paint()..color = Colors.blue,
      anchor: Anchor.center,
      position: Vector2(GameConfig.tileSize * 1.5, GameConfig.tileSize * 1.5),
    );
    world.add(hero);

    camera.follow(hero);
    camera.viewfinder.zoom = GameConfig.defaultZoom;

    // 1. Giới hạn Viewport của Camera để không đè lên thanh HUD bên dưới
    _setupCameraViewportAndBounds();

    // 2. Thêm Bottom HUD Panel chứa Mini Map vào Viewport
    camera.viewport.add(BottomHudComponent(hudHeight: bottomHudHeight));
  }

  void _setupCameraViewportAndBounds() {
    // Thu hẹp vùng hiển thị Camera theo chiều cao trừ đi thanh HUD
    final gameSize = canvasSize;
    camera.viewport.size = Vector2(gameSize.x, gameSize.y - bottomHudHeight);

    final mapWidth = mapComponent.width;
    final mapHeight = mapComponent.height;
    final halfViewport = camera.viewport.virtualSize / (2 * GameConfig.defaultZoom);

    camera.setBounds(
      Rectangle.fromLTWH(
        halfViewport.x,
        halfViewport.y,
        mapWidth - (halfViewport.x * 2),
        mapHeight - (halfViewport.y * 2),
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
  Future<void> onTapDown(TapDownEvent event) async {
    // Bỏ qua nếu chạm vào vùng Bottom HUD
    if (event.canvasPosition.y >= canvasSize.y - bottomHudHeight) {
      return;
    }

    if (isCalculatingPath) return;

    final worldTap = camera.globalToLocal(event.canvasPosition);

    Vector2 startPoint = hero.position;
    if (currentPath.isNotEmpty) {
      startPoint = currentPath.first;
    }

    final realWidth = mapComponent.tileMap.map.width;
    final realHeight = mapComponent.tileMap.map.height;

    final startX = (startPoint.x / GameConfig.tileSize).floor().clamp(0, realWidth - 1);
    final startY = (startPoint.y / GameConfig.tileSize).floor().clamp(0, realHeight - 1);

    final endX = (worldTap.x / GameConfig.tileSize).floor().clamp(0, realWidth - 1);
    final endY = (worldTap.y / GameConfig.tileSize).floor().clamp(0, realHeight - 1);

    if (barrierSet.contains((endX, endY))) return;

    isCalculatingPath = true;

    final result = await compute(_calculatePathInBackground, {
      'rows': realHeight,
      'columns': realWidth,
      'start': (startX, startY),
      'end': (endX, endY),
      'barriers': barrierList,
    });

    isCalculatingPath = false;

    if (result.isNotEmpty) {
      currentPath = result.map((point) {
        return Vector2(
          point.$1 * GameConfig.tileSize + (GameConfig.tileSize / 2),
          point.$2 * GameConfig.tileSize + (GameConfig.tileSize / 2),
        );
      }).toList();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (currentPath.isNotEmpty) {
      final target = currentPath.first;
      final distance = target - hero.position;

      if (distance.length < 5) {
        hero.position = target.clone();
        currentPath.removeAt(0);
      } else {
        hero.position += distance.normalized() * (GameConfig.heroMoveSpeed * dt);
      }
    }
  }
}

// Component quản lý toàn bộ thanh HUD phía dưới
class BottomHudComponent extends PositionComponent with HasGameReference<DotaGame> {
  final double hudHeight;

  BottomHudComponent({required this.hudHeight}) {
    priority = 100;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Cố định thanh HUD nằm ở đáy màn hình
    position = Vector2(0, game.canvasSize.y - hudHeight);
    this.size = Vector2(game.canvasSize.x, hudHeight);
  }

  @override
  void onLoad() {
    super.onLoad();
    // Gắn Mini Map vào góc dưới bên trái của thanh HUD
    add(MiniMapComponent(miniMapSize: hudHeight - 16));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Vẽ nền thanh HUD màu tối bên dưới
    final hudBgPaint = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), hudBgPaint);

    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset.zero, Offset(size.x, 0), borderPaint);
  }
}

// Mini Map nằm gọn trong 1 ô vuông của HUD
class MiniMapComponent extends PositionComponent with HasGameReference<DotaGame> {
  final double miniMapSize;

  MiniMapComponent({required this.miniMapSize}) {
    // Đặt lề 8px so với khung HUD
    position = Vector2(8, 8);
    size = Vector2.all(miniMapSize);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final mapWidth = game.mapComponent.width;
    final mapHeight = game.mapComponent.height;

    if (mapWidth == 0 || mapHeight == 0) return;

    final scaleX = miniMapSize / mapWidth;
    final scaleY = miniMapSize / mapHeight;

    // 1. Nền Mini Map
    final bgPaint = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, miniMapSize, miniMapSize), bgPaint);

    // 2. Vật cản
    final barrierPaint = Paint()..color = Colors.grey.withValues(alpha: 0.8);
    for (final barrier in game.barrierSet) {
      final bx = barrier.$1 * GameConfig.tileSize * scaleX;
      final by = barrier.$2 * GameConfig.tileSize * scaleY;
      final bw = GameConfig.tileSize * scaleX;
      final bh = GameConfig.tileSize * scaleY;
      canvas.drawRect(Rect.fromLTWH(bx, by, bw, bh), barrierPaint);
    }

    // 3. Khung Camera Viewport
    final cameraRect = game.camera.visibleWorldRect;
    final camX = cameraRect.left * scaleX;
    final camY = cameraRect.top * scaleY;
    final camW = cameraRect.width * scaleX;
    final camH = cameraRect.height * scaleY;

    final viewPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(camX, camY, camW, camH), viewPaint);

    // 4. Vị trí Hero
    final heroX = game.hero.position.x * scaleX;
    final heroY = game.hero.position.y * scaleY;

    final heroPaint = Paint()..color = Colors.greenAccent;
    canvas.drawCircle(Offset(heroX, heroY), 3.0, heroPaint);

    // 5. Viền Mini Map
    final borderPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(0, 0, miniMapSize, miniMapSize), borderPaint);
  }
}
