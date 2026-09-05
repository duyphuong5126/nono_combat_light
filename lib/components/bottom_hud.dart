// --- BOTTOM HUD COMPONENT ---

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../main_game.dart';
import 'minimap.dart';

class BottomHudComponent extends PositionComponent
    with HasGameReference<NonoCombat> {
  final double hudHeight;

  BottomHudComponent({required this.hudHeight}) {
    priority = 100;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(0, game.canvasSize.y - hudHeight);
    this.size = Vector2(game.canvasSize.x, hudHeight);
  }

  @override
  void onLoad() {
    super.onLoad();
    add(
      MiniMapComponent(miniMapSize: hudHeight - (GameConfig.miniMapMargin * 2)),
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final hudBgPaint = Paint()..color = GameConfig.hudBgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), hudBgPaint);

    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset.zero, Offset(size.x, 0), borderPaint);
  }
}
