import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import 'main_game.dart';

import 'package:flutter/services.dart';

void main() async {
  // 1. Đảm bảo Flutter Binding được khởi tạo trước khi can thiệp vào cấu hình hệ thống
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Kích hoạt chế độ Immersive Sticky (Ẩn hoàn toàn thanh điều hướng & Status bar)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 3. Ép ứng dụng chỉ hiển thị ở màn hình ngang (Landscape)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 4. Khởi chạy Flame Engine thông qua GameWidget
  runApp(GameWidget(game: NonoCombat()));
}
