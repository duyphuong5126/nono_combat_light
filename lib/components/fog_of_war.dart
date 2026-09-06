import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../config/game_config.dart';
import '../main_game.dart';
import '../managers/vision_manager.dart';

class FogOfWarComponent extends PositionComponent with HasGameReference<NonoCombat> {
  FogOfWarComponent() : super(priority: 10); // Đảm bảo nằm trên Map nhưng dưới HUD

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final vision = VisionManager();
    if (vision.mapWidth == 0) return;

    final cameraRect = game.camera.visibleWorldRect;
    final tileSize = GameConfig.tileSize;

    // Chỉ vẽ các ô tile nằm trong tầm nhìn của Camera để tối ưu hiệu năng
    final startX = (cameraRect.left / tileSize).floor().clamp(0, vision.mapWidth - 1);
    final endX = (cameraRect.right / tileSize).ceil().clamp(0, vision.mapWidth - 1);
    final startY = (cameraRect.top / tileSize).floor().clamp(0, vision.mapHeight - 1);
    final endY = (cameraRect.bottom / tileSize).ceil().clamp(0, vision.mapHeight - 1);

    final unexploredPaint = Paint()..color = GameConfig.fogColorUnexplored;
    final exploredPaint = Paint()..color = GameConfig.fogColorExplored;

    for (int ty = startY; ty <= endY; ty++) {
      for (int tx = startX; tx <= endX; tx++) {
        final isVisible = vision.isVisible(tx, ty);
        final isExplored = vision.isExplored(tx, ty);

        if (!isVisible) {
          final rect = Rect.fromLTWH(
            tx * tileSize,
            ty * tileSize,
            tileSize + 0.5, // Thêm 0.5 để tránh khoảng hở giữa các ô do render
            tileSize + 0.5,
          );

          if (isExplored) {
            canvas.drawRect(rect, exploredPaint);
          } else {
            canvas.drawRect(rect, unexploredPaint);
          }
        }
      }
    }
  }
}
