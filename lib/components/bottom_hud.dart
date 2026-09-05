import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../main_game.dart';
import 'minimap.dart';

/// Overlay HUD cố định dưới đáy màn hình chứa Joystick và MiniMap
class BottomHudComponent extends PositionComponent
    with HasGameReference<NonoCombat> {
  final double hudHeight;
  late final JoystickComponent joystick;
  late final MiniMapComponent miniMap;

  BottomHudComponent({required this.hudHeight}) {
    priority = 100; // Đảm bảo HUD luôn hiển thị đè lên các đối tượng Game World
  }

  @override
  void onLoad() {
    super.onLoad();

    final padding = GameConfig.hudHorizontalPadding;
    final usableHeight = hudHeight - (GameConfig.miniMapMargin * 2);

    // Khởi tạo MiniMap góc dưới bên trái
    miniMap = MiniMapComponent(
      miniMapSize: usableHeight,
      customOffset: Vector2(padding, GameConfig.miniMapMargin),
    );
    add(miniMap);

    // Khởi tạo Joystick góc dưới bên phải
    final knobPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    final backgroundPaint = Paint()..color = Colors.black38;

    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: GameConfig.joystickKnobRadius,
        paint: knobPaint,
      ),
      background: CircleComponent(
        radius: GameConfig.joystickRadius,
        paint: backgroundPaint,
      ),
      margin: EdgeInsets.only(
        right: padding + GameConfig.joystickRadius,
        bottom: (hudHeight / 2) - GameConfig.joystickRadius,
      ),
    );

    add(joystick);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Tự động căn lại vị trí HUD khi thay đổi kích thước màn hình
    position = Vector2(0, game.canvasSize.y - hudHeight);
    this.size = Vector2(game.canvasSize.x, hudHeight);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Vẽ nền HUD mờ 40%
    final hudBgPaint = Paint()
      ..color = const Color(0xFF1E1E1E).withValues(alpha: 0.4);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), hudBgPaint);

    // Đường kẻ phân cách đỉnh HUD
    final borderPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset.zero, Offset(size.x, 0), borderPaint);
  }
}
