/// Danh sách các loại lệnh giao cho đơn vị
enum CommandType { move, attack, useSkill, stop, spawnUnit }

/// Model lưu trữ chi tiết từng thao tác người dùng theo Tick thời gian (dùng cho Replay / Network)
class GameCommand {
  final int tick; // Mốc thời gian thực thi (Game Tick)
  final String unitId; // ID đơn vị thực thi
  final CommandType type; // Loại lệnh
  final double targetX; // Tọa độ X mục tiêu
  final double targetY; // Tọa độ Y mục tiêu
  final String?
  targetEntityId; // ID đối tượng mục tiêu (nếu có - dùng cho Đánh/Skill chỉ định)

  GameCommand({
    required this.tick,
    required this.unitId,
    required this.type,
    required this.targetX,
    required this.targetY,
    this.targetEntityId,
  });

  /// Chuyển đổi thành JSON phục vụ lưu trữ Replay file
  Map<String, dynamic> toJson() => {
    'tick': tick,
    'unitId': unitId,
    'type': type.name,
    'x': targetX,
    'y': targetY,
    'targetEntityId': targetEntityId,
  };

  /// Khôi phục đối tượng Command từ dữ liệu JSON
  factory GameCommand.fromJson(Map<String, dynamic> json) => GameCommand(
    tick: json['tick'],
    unitId: json['unitId'],
    type: CommandType.values.byName(json['type']),
    targetX: (json['x'] as num).toDouble(),
    targetY: (json['y'] as num).toDouble(),
    targetEntityId: json['targetEntityId'],
  );
}
