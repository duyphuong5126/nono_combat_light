import 'dart:math';
import 'package:flame/components.dart';
import '../config/game_config.dart';
import '../main_game.dart';

class VisionManager {
  static final VisionManager _instance = VisionManager._internal();
  factory VisionManager() => _instance;
  VisionManager._internal();

  late int mapWidth;
  late int mapHeight;
  
  // Trạng thái khám phá của từng ô tile (true = đã từng đi qua)
  late List<List<bool>> exploredGrid;
  // Trạng thái nhìn thấy hiện tại (true = đang trong tầm mắt)
  late List<List<bool>> visibleGrid;

  // Tập hợp các ô chặn tầm nhìn (Cây, Tường cao...)
  final Set<(int, int)> visionBlockingSet = {};

  void init(int width, int height) {
    mapWidth = width;
    mapHeight = height;
    exploredGrid = List.generate(height, (_) => List.filled(width, false));
    visibleGrid = List.generate(height, (_) => List.filled(width, false));
    visionBlockingSet.clear();
  }

  void addVisionBlocker(int x, int y) {
    visionBlockingSet.add((x, y));
  }

  /// Cập nhật tầm nhìn dựa trên vị trí của Hero
  void updateVision(Vector2 heroPos) {
    final heroTileX = (heroPos.x / GameConfig.tileSize).floor();
    final heroTileY = (heroPos.y / GameConfig.tileSize).floor();

    // Reset visible grid
    for (var y = 0; y < mapHeight; y++) {
      for (var x = 0; x < mapWidth; x++) {
        visibleGrid[y][x] = false;
      }
    }

    final radiusInTiles = (GameConfig.heroVisionRadius / GameConfig.tileSize).ceil();

    // Thuật toán quét tầm nhìn đơn giản (Radius check)
    // TODO: Nâng cấp lên Ray-casting để hỗ trợ chặn tầm nhìn bởi vật cản
    for (int dy = -radiusInTiles; dy <= radiusInTiles; dy++) {
      for (int dx = -radiusInTiles; dx <= radiusInTiles; dx++) {
        final tx = heroTileX + dx;
        final ty = heroTileY + dy;

        if (tx >= 0 && tx < mapWidth && ty >= 0 && ty < mapHeight) {
          final dist = sqrt(dx * dx + dy * dy) * GameConfig.tileSize;
          if (dist <= GameConfig.heroVisionRadius) {
            // Kiểm tra LoS cơ bản (Đường thẳng từ Hero đến Tile)
            if (_hasLineOfSight(heroTileX, heroTileY, tx, ty)) {
              visibleGrid[ty][tx] = true;
              exploredGrid[ty][tx] = true;
            }
          }
        }
      }
    }
  }

  /// Thuật toán Bresenham cơ bản để kiểm tra vật cản trên đường thẳng
  bool _hasLineOfSight(int x0, int y0, int x1, int y1) {
    if (x0 == x1 && y0 == y1) return true;

    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    int curX = x0;
    int curY = y0;

    while (curX != x1 || curY != y1) {
      if (visionBlockingSet.contains((curX, curY))) {
        // Nếu ô hiện tại (trừ ô đích) là vật cản thì bị chặn
        // Chúng ta cho phép nhìn thấy chính ô vật cản đó nhưng không nhìn xuyên qua được
        return false;
      }
      
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        curX += sx;
      }
      if (e2 < dx) {
        err += dx;
        curY += sy;
      }
    }
    return true;
  }

  bool isVisible(int x, int y) {
    if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) return false;
    return visibleGrid[y][x];
  }

  bool isExplored(int x, int y) {
    if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) return false;
    return exploredGrid[y][x];
  }
}
