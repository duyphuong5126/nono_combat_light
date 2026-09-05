import 'package:flutter/material.dart';

class GameConfig {
  static const double tileSize = 64.0;
  static const double defaultZoom = 1.2;

  /// Tính chiều cao HUD bằng 2/5 (40%) chiều cao màn hình
  static double getBottomHudHeight(double screenHeight) {
    return screenHeight * 0.3;
  }

  // MiniMap Config
  static const double miniMapMargin = 8.0;
  static const double miniMapBorderWidth = 1.5;
  static const double miniMapHeroRadius = 3.0;

  // Colors
  static const Color hudBgColor = Color(0xFF1E1E1E);
  static const Color heroColor = Colors.lightBlueAccent;

  // Hero Stats & Dota Mechanics
  static const double heroRadius = 20.0;
  static const double heroMoveSpeed = 180.0;
  static const double heroTurnRate = 14.0;
  static const double turnTolerance = 0.2;

  static const double attackRange = 120.0;
  static const double attackPoint = 0.3;
  static const double backswing = 0.4;
}
