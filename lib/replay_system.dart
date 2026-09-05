import 'dart:convert';
import '../models/game_command.dart';

/// Lớp quản lý ghi log và phát lại trận đấu (Replay Engine)
class ReplayManager {
  final List<GameCommand> recordedCommands = []; // Danh sách các lệnh đã thu
  bool isReplayMode = false; // Cờ đánh dấu trạng thái phát lại

  /// Ghi lại lệnh nếu đang trong trận đấu thực
  void recordCommand(GameCommand cmd) {
    if (!isReplayMode) {
      recordedCommands.add(cmd);
    }
  }

  /// Xuất toàn bộ dữ liệu trận đấu ra chuỗi JSON
  String exportReplayJson() {
    return jsonEncode(recordedCommands.map((e) => e.toJson()).toList());
  }

  /// Nạp chuỗi JSON Replay để chuẩn bị phát lại
  void loadReplayJson(String jsonStr) {
    recordedCommands.clear();
    final List<dynamic> list = jsonDecode(jsonStr);
    recordedCommands.addAll(list.map((e) => GameCommand.fromJson(e)));
    isReplayMode = true;
  }
}
