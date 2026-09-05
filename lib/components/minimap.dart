// --- MINI MAP COMPONENT ---
// --- MINI MAP COMPONENT (HỖ TRỢ CHẠM & DI CHUYỂN CAMERA) ---

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;

import '../config/game_config.dart';
import '../main_game.dart';

class MiniMapComponent extends PositionComponent
    with HasGameReference<NonoCombat>, TapCallbacks, PointerMoveCallbacks {
  final double miniMapSize;
  bool _isDragging = false;

  MiniMapComponent({required this.miniMapSize}) {
    position = Vector2(GameConfig.miniMapMargin, GameConfig.miniMapMargin);
    size = Vector2.all(miniMapSize);
  }

  // --- XỬ LÝ SỰ KIỆN CHẠM & KÉO TÊN MINIMAP ---
  @override
  void onTapDown(TapDownEvent event) {
    _isDragging = true;
    _moveCameraToMinimapPoint(event.localPosition);
  }

  @override
  void onTapUp(TapUpEvent event) {
    _isDragging = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _isDragging = false;
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    if (_isDragging) {
      _moveCameraToMinimapPoint(event.localPosition);
    }
  }

  // --- CHUYỂN ĐỔI TỌA ĐỘ VÀ DI CHUYỂN CAMERA ---
  void _moveCameraToMinimapPoint(Vector2 localTouchPos) {
    final mapWidth = game.mapComponent.width;
    final mapHeight = game.mapComponent.height;

    if (mapWidth == 0 || mapHeight == 0) return;

    // 1. Chuẩn hóa vị trí chạm trên Minimap về khoảng [0.0, 1.0]
    final normalizedX = (localTouchPos.x / miniMapSize).clamp(0.0, 1.0);
    final normalizedY = (localTouchPos.y / miniMapSize).clamp(0.0, 1.0);

    // 2. Tọa độ tương ứng trong World Space
    final targetWorldX = normalizedX * mapWidth;
    final targetWorldY = normalizedY * mapHeight;

    // 3. Dừng follow Hero để Camera có thể soi góc khác tự do
    game.camera.stop();

    // 4. Di chuyển Camera Viewfinder tới vị trí vừa chạm
    game.camera.viewfinder.position = Vector2(targetWorldX, targetWorldY);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final mapWidth = game.mapComponent.width;
    final mapHeight = game.mapComponent.height;

    if (mapWidth == 0 || mapHeight == 0) return;

    final scaleX = miniMapSize / mapWidth;
    final scaleY = miniMapSize / mapHeight;

    // Nền MiniMap
    canvas.drawRect(
      Rect.fromLTWH(0, 0, miniMapSize, miniMapSize),
      Paint()..color = Colors.black,
    );

    // Vật cản
    final barrierPaint = Paint()..color = Colors.grey.withValues(alpha: 0.8);
    for (final barrier in game.barrierSet) {
      final bx = barrier.$1 * GameConfig.tileSize * scaleX;
      final by = barrier.$2 * GameConfig.tileSize * scaleY;
      final bw = GameConfig.tileSize * scaleX;
      final bh = GameConfig.tileSize * scaleY;
      canvas.drawRect(Rect.fromLTWH(bx, by, bw, bh), barrierPaint);
    }

    // Viền Viewport Camera
    final cameraRect = game.camera.visibleWorldRect;
    final viewPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = GameConfig.miniMapBorderWidth;
    canvas.drawRect(
      Rect.fromLTWH(
        cameraRect.left * scaleX,
        cameraRect.top * scaleY,
        cameraRect.width * scaleX,
        cameraRect.height * scaleY,
      ),
      viewPaint,
    );

    // Hero
    final heroX = game.hero.position.x * scaleX;
    final heroY = game.hero.position.y * scaleY;
    canvas.drawCircle(
      Offset(heroX, heroY),
      GameConfig.miniMapHeroRadius,
      Paint()..color = Colors.greenAccent,
    );

    // Viền khung Minimap
    canvas.drawRect(
      Rect.fromLTWH(0, 0, miniMapSize, miniMapSize),
      Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = GameConfig.miniMapBorderWidth,
    );
  }
}
