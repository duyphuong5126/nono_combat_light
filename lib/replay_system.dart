import 'dart:convert';
import '../models/game_command.dart';

class ReplayManager {
  final List<GameCommand> recordedCommands = [];
  bool isReplayMode = false;

  void recordCommand(GameCommand cmd) {
    if (!isReplayMode) {
      recordedCommands.add(cmd);
    }
  }

  String exportReplayJson() {
    return jsonEncode(recordedCommands.map((e) => e.toJson()).toList());
  }

  void loadReplayJson(String jsonStr) {
    recordedCommands.clear();
    final List<dynamic> list = jsonDecode(jsonStr);
    recordedCommands.addAll(list.map((e) => GameCommand.fromJson(e)));
    isReplayMode = true;
  }
}
