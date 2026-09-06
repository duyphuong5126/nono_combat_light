import 'dart:convert';
import '../models/game_command.dart';

/// Lớp quản lý ghi log và phát lại trận đấu (Replay Engine)
class ReplayManager {
  final List<GameCommand> recordedCommands = [];
  bool isReplayMode = false;

  // Metadata bắt buộc để Replay chính xác
  int initialSeed = 0;
  List<String> selectedHeroes = [];

  /// Khởi tạo một phiên ghi Replay mới
  void startNewSession({required int seed, required List<String> heroes}) {
    recordedCommands.clear();
    isReplayMode = false;
    initialSeed = seed;
    selectedHeroes = heroes;
  }

  /// Ghi lại lệnh nếu đang trong trận đấu thực
  void recordCommand(GameCommand cmd) {
    if (!isReplayMode) {
      recordedCommands.add(cmd);
    }
  }

  /// Xuất toàn bộ dữ liệu trận đấu bao gồm Header + Commands ra JSON
  String exportReplayJson() {
    final Map<String, dynamic> fullData = {
      'seed': initialSeed,
      'heroes': selectedHeroes,
      'commands': recordedCommands.map((e) => e.toJson()).toList(),
    };
    return jsonEncode(fullData);
  }

  /// Nạp chuỗi JSON Replay và khôi phục trạng thái ban đầu
  void loadReplayJson(String jsonStr) {
    recordedCommands.clear();
    final Map<String, dynamic> data = jsonDecode(jsonStr);

    initialSeed = data['seed'] as int;
    selectedHeroes = List<String>.from(data['heroes']);

    final List<dynamic> cmdList = data['commands'];
    recordedCommands.addAll(cmdList.map((e) => GameCommand.fromJson(e)));

    isReplayMode = true;
  }
}
