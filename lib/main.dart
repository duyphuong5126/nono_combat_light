import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import 'main_game.dart';

import 'package:flutter/services.dart';

void main() async {
  // 1. Đảm bảo Flutter Binding đã được khởi tạo trước khi gọi SystemChrome
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Ẩn thanh status bar và navigation bar (Chế độ Immersive Fullscreen)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 3. Ép ứng dụng chỉ hoạt động ở chế độ màn hình ngang (Landscape)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(GameWidget(game: NonoCombat()));
}
