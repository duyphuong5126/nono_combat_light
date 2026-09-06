import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;

import '../config/game_config.dart';
import '../main_game.dart';
import '../managers/unit_registry.dart';
import 'dummy_target.dart';

/// Component MiniMap hỗ trợ Render thu nhỏ bản đồ và Kéo/Tap di chuyển Camera
class MiniMapComponent extends PositionComponent
    with HasGameReference<NonoCombat>, TapCallbacks, PointerMoveCallbacks {
  final double miniMapSize;
  bool _isDragging = false;

  MiniMapComponent({required this.miniMapSize, required Vector2 customOffset}) {
    position = customOffset;
    size = Vector2.all(miniMapSize);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _isDragging = true;
    _moveCameraToMinimapPoint(event.localPosition);
  }

  @override
  void onTapUp(TapUpEvent event) => _isDragging = false;

  @override
  void onTapCancel(TapCancelEvent event) => _isDragging = false;

  @override
  void onPointerMove(PointerMoveEvent event) {
    if (_isDragging) {
      _moveCameraToMinimapPoint(event.localPosition);
    }
  }

  /// Chuyển đổi tọa độ trên MiniMap sang tọa độ Thế giới (World Space) và dịch chuyển Camera
  void _moveCameraToMinimapPoint(Vector2 localTouchPos) {
    final mapWidth = game.mapComponent.width;
    final mapHeight = game.mapComponent.height;

    if (mapWidth == 0 || mapHeight == 0) return;

    final normalizedX = (localTouchPos.x / miniMapSize).clamp(0.0, 1.0);
    final normalizedY = (localTouchPos.y / miniMapSize).clamp(0.0, 1.0);

    final targetWorldX = normalizedX * mapWidth;
    final targetWorldY = normalizedY * mapHeight;

    game.moveCameraTo(Vector2(targetWorldX, targetWorldY));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final mapWidth = game.mapComponent.width;
    final mapHeight = game.mapComponent.height;

    if (mapWidth == 0 || mapHeight == 0) return;

    final scaleX = miniMapSize / mapWidth;
    final scaleY = miniMapSize / mapHeight;

    // 1. Vẽ nền MiniMap (Màu đen)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, miniMapSize, miniMapSize),
      Paint()..color = Colors.black,
    );

    // 2. Vẽ các ô vật cản (Màu xám)
    final barrierPaint = Paint()..color = Colors.grey.withValues(alpha: 0.8);
    for (final barrier in game.barrierSet) {
      final bx = barrier.$1 * GameConfig.tileSize * scaleX;
      final by = barrier.$2 * GameConfig.tileSize * scaleY;
      final bw = GameConfig.tileSize * scaleX;
      final bh = GameConfig.tileSize * scaleY;
      canvas.drawRect(Rect.fromLTWH(bx, by, bw, bh), barrierPaint);
    }

    // 3. Vẽ khung nhìn của Camera hiện tại (Hình chữ nhật màu trắng)
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

    // 4. Vẽ các Entity động từ UnitRegistry (Tránh tình trạng Entity đã chết vẫn bị render)
    final activeUnits = UnitRegistry().getAllUnits();
    for (final unit in activeUnits) {
      if (!unit.isMounted) continue; // Bỏ qua nếu đã bị remove khỏi world

      final miniX = unit.position.x * scaleX;
      final miniY = unit.position.y * scaleY;

      if (unit == game.hero) {
        // Chấm xanh lá cho Hero
        canvas.drawCircle(
          Offset(miniX, miniY),
          GameConfig.miniMapHeroRadius,
          Paint()..color = Colors.greenAccent,
        );
      } else if (unit is DummyTarget && !unit.isDead) {
        // Chấm đỏ cho Kẻ địch/Dummy (Chỉ vẽ khi chưa chết)
        canvas.drawCircle(
          Offset(miniX, miniY),
          3.0,
          Paint()..color = Colors.redAccent,
        );
      }
    }

    // 5. Viền ngoài MiniMap
    canvas.drawRect(
      Rect.fromLTWH(0, 0, miniMapSize, miniMapSize),
      Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = GameConfig.miniMapBorderWidth,
    );
  }
}
