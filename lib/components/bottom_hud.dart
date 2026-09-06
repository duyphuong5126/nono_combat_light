import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../main_game.dart';
import '../models/game_command.dart';
import 'minimap.dart';

class BottomHudComponent extends PositionComponent
    with HasGameReference<NonoCombat>, TapCallbacks {
  final double hudHeight;
  final double safeAreaLeft;

  late JoystickComponent joystick;
  late ButtonComponent skill1Button;
  late MiniMapComponent miniMap;

  BottomHudComponent({required this.hudHeight, this.safeAreaLeft = 16.0});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    size = Vector2(game.canvasSize.x, hudHeight);
    position = Vector2(0, game.canvasSize.y - hudHeight);

    final screenWidth = game.canvasSize.x;

    // ==========================================
    // 0. NHÚNG MINIMAP COMPONENT
    // ==========================================
    final miniMapSize = hudHeight - 12.0;
    miniMap = MiniMapComponent(
      miniMapSize: miniMapSize,
      customOffset: Vector2(safeAreaLeft, 6.0),
    );
    add(miniMap);

    // ==========================================
    // 1. JOYSTICK
    // ==========================================
    final joystickRadius = hudHeight * 0.35;
    final knobRadius = joystickRadius * 0.42;

    final rightMargin = hudHeight * 0.1;
    final bottomMargin = hudHeight * 0.08;

    final joystickCenterX = screenWidth - rightMargin - joystickRadius;
    final joystickCenterY = size.y - bottomMargin - joystickRadius;

    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: knobRadius,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.75),
      ),
      background: CircleComponent(
        radius: joystickRadius,
        paint: Paint()..color = Colors.black.withValues(alpha: 0.45),
      ),
      position: Vector2(joystickCenterX, joystickCenterY),
      anchor: Anchor.center,
    );
    add(joystick);

    // ==========================================
    // 2. SKILL GRID 2x2
    // ==========================================
    final skillSize = hudHeight * 0.36;
    final gap = hudHeight * 0.06;

    final gridRightX = joystickCenterX - joystickRadius - (hudHeight * 0.12);
    final gridBottomY = size.y - (hudHeight * 0.1);

    final col1X = gridRightX - (skillSize * 2 + gap);
    final col2X = gridRightX - skillSize;

    final row1Y = gridBottomY - (skillSize * 2 + gap);
    final row2Y = gridBottomY - skillSize;

    skill1Button = ButtonComponent(
      button: RectangleComponent(
        size: Vector2(skillSize, skillSize),
        paint: Paint()..color = Colors.orangeAccent,
      ),
      buttonDown: RectangleComponent(
        size: Vector2(skillSize, skillSize),
        paint: Paint()..color = Colors.deepOrange,
      ),
      position: Vector2(col1X, row2Y),
      onPressed: _onSkill1Pressed,
    );
    add(skill1Button);

    _addDisabledSquareSkill(
      Vector2(col2X, row2Y),
      Vector2(skillSize, skillSize),
      '2',
    );
    _addDisabledSquareSkill(
      Vector2(col1X, row1Y),
      Vector2(skillSize, skillSize),
      '3',
    );
    _addDisabledSquareSkill(
      Vector2(col2X, row1Y),
      Vector2(skillSize, skillSize),
      'R',
    );
  }

  void _addDisabledSquareSkill(Vector2 pos, Vector2 sqSize, String label) {
    final btn = RectangleComponent(
      size: sqSize,
      paint: Paint()..color = Colors.grey.shade800.withValues(alpha: 0.85),
      position: pos,
    );
    add(btn);
  }

  void _onSkill1Pressed() {
    final hero = game.hero;
    final targetPos =
        hero.targetEnemy?.position ??
        (hero.position + Vector2(cos(hero.angle), sin(hero.angle)) * 200);

    final cmd = GameCommand(
      tick: game.currentTick,
      unitId: 'hero_1',
      type: CommandType.useSkill,
      targetX: targetPos.x,
      targetY: targetPos.y,
    );

    game.replayManager.recordCommand(cmd);
    hero.castSkill(targetPos);
  }

  // ==========================================
  // 3. RENDER BỐ CỤC HUD
  // ==========================================
  @override
  void render(Canvas canvas) {
    final screenWidth = size.x;

    // Background HUD
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenWidth, size.y),
      Paint()..color = const Color(0xFF101010).withValues(alpha: 0.88),
    );
    canvas.drawLine(
      Offset.zero,
      Offset(screenWidth, 0),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.0,
    );

    // Tính toán lại khoảng cách offset sau vị trí MiniMap
    final miniMapSize = size.y - 12.0;
    double currentX = safeAreaLeft + miniMapSize + (screenWidth * 0.015);

    // Không gian dành riêng cho Joystick + Skill Grid 2x2
    final rightControlWidth = hudHeight * 2.1;
    final availableWidth = screenWidth - currentX - rightControlWidth;

    // ------------------------------------------
    // A. AVATAR HERO (~16% vùng giữa)
    // ------------------------------------------
    final avatarWidth = availableWidth * 0.16;
    final avatarRect = Rect.fromLTWH(currentX, 8.0, avatarWidth, size.y - 16.0);
    canvas.drawRect(avatarRect, Paint()..color = Colors.blueGrey.shade900);
    canvas.drawRect(
      avatarRect,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(
      Offset(currentX + avatarWidth / 2, size.y * 0.38),
      avatarWidth * 0.3,
      Paint()..color = GameConfig.heroColor,
    );

    final lvlRect = Rect.fromLTWH(
      currentX + avatarWidth * 0.1,
      size.y * 0.72,
      avatarWidth * 0.8,
      size.y * 0.16,
    );
    canvas.drawRect(lvlRect, Paint()..color = Colors.amber.shade800);
    _drawText(
      canvas,
      'Lv.1',
      Offset(currentX + avatarWidth / 2, size.y * 0.80),
      fontSize: size.y * 0.08,
      isCenter: true,
    );

    currentX += avatarWidth + (availableWidth * 0.02);

    // ------------------------------------------
    // B. THÔNG TIN TRẠNG THÁI (~52% vùng giữa)
    // ------------------------------------------
    final statsWidth = availableWidth * 0.52;
    final fontSizeSmall = (size.y * 0.075).clamp(8.0, 11.5);

    _drawText(
      canvas,
      'Nono Hero',
      Offset(currentX, 6),
      fontSize: fontSizeSmall * 1.2,
      fontWeight: FontWeight.bold,
      color: Colors.amber,
    );

    _drawBar(
      canvas,
      Offset(currentX, size.y * 0.20),
      statsWidth,
      size.y * 0.10,
      Colors.green,
      '500 / 500',
    );
    _drawBar(
      canvas,
      Offset(currentX, size.y * 0.33),
      statsWidth,
      size.y * 0.10,
      Colors.blue,
      '200 / 200',
    );

    _drawText(
      canvas,
      'Armor: 3.5',
      Offset(currentX, size.y * 0.48),
      fontSize: fontSizeSmall,
      color: Colors.white70,
    );
    _drawText(
      canvas,
      'STR: 22 +2.1',
      Offset(currentX, size.y * 0.61),
      fontSize: fontSizeSmall,
      color: Colors.redAccent,
    );
    _drawText(
      canvas,
      'AGI: 18 +1.8',
      Offset(currentX + statsWidth * 0.5, size.y * 0.48),
      fontSize: fontSizeSmall,
      color: Colors.greenAccent,
    );
    _drawText(
      canvas,
      'INT: 15 +1.4',
      Offset(currentX + statsWidth * 0.5, size.y * 0.61),
      fontSize: fontSizeSmall,
      color: Colors.cyanAccent,
    );

    // Buffs
    for (int i = 0; i < 4; i++) {
      final buffSize = size.y * 0.12;
      final buffRect = Rect.fromLTWH(
        currentX + (i * (buffSize + 4)),
        size.y * 0.76,
        buffSize,
        buffSize,
      );
      canvas.drawRect(buffRect, Paint()..color = Colors.purple.shade900);
      canvas.drawRect(
        buffRect,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke,
      );
    }

    currentX += statsWidth + (availableWidth * 0.02);

    // ------------------------------------------
    // C. LƯỚI VẬT PHẨM (2x3 INVENTORY)
    // ------------------------------------------
    _drawText(
      canvas,
      'INVENTORY',
      Offset(currentX + (availableWidth * 0.10), 6),
      fontSize: fontSizeSmall * 0.85,
      color: Colors.white54,
    );

    final itemGap = size.y * 0.04;
    final itemSize = ((size.y * 0.68) - itemGap) / 2;

    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 3; col++) {
        final ix = currentX + col * (itemSize + itemGap);
        final iy = (size.y * 0.20) + row * (itemSize + itemGap);

        final itemRect = Rect.fromLTWH(ix, iy, itemSize, itemSize);
        canvas.drawRect(itemRect, Paint()..color = Colors.black54);
        canvas.drawRect(
          itemRect,
          Paint()
            ..color = Colors.white24
            ..style = PaintingStyle.stroke,
        );
      }
    }

    super.render(canvas);
  }

  void _drawBar(
    Canvas canvas,
    Offset pos,
    double width,
    double height,
    Color color,
    String text,
  ) {
    final bgRect = Rect.fromLTWH(pos.dx, pos.dy, width, height);
    canvas.drawRect(bgRect, Paint()..color = Colors.black);
    canvas.drawRect(
      Rect.fromLTWH(pos.dx, pos.dy, width * 0.8, height),
      Paint()..color = color,
    );
    canvas.drawRect(
      bgRect,
      Paint()
        ..color = Colors.white30
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    _drawText(
      canvas,
      text,
      Offset(pos.dx + width / 2, pos.dy + height / 2),
      fontSize: height * 0.7,
      isCenter: true,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.white,
    bool isCenter = false,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final drawPos = isCenter
        ? Offset(
            pos.dx - textPainter.width / 2,
            pos.dy - textPainter.height / 2,
          )
        : pos;
    textPainter.paint(canvas, drawPos);
  }
}
