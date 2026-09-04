import 'dart:convert';

// Định nghĩa loại hành động trong game
enum CommandType { move, useSkill, spawnUnit }

// Mỗi hành động chứa thông tin cần thiết và mốc thời gian (Tick)
class GameCommand {
  final int tick;
  final String unitId;
  final CommandType type;
  final double targetX;
  final double targetY;

  GameCommand({
    required this.tick,
    required this.unitId,
    required this.type,
    required this.targetX,
    required this.targetY,
  });

  Map<String, dynamic> toJson() => {
    'tick': tick,
    'unitId': unitId,
    'type': type.name,
    'x': targetX,
    'y': targetY,
  };

  factory GameCommand.fromJson(Map<String, dynamic> json) => GameCommand(
    tick: json['tick'],
    unitId: json['unitId'],
    type: CommandType.values.byName(json['type']),
    targetX: json['x'],
    targetY: json['y'],
  );
}

// Trình quản lý ghi/đọc Replay
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
