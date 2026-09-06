/// Danh sách các loại lệnh giao cho đơn vị
enum CommandType { move, attack, useSkill, stop, spawnUnit, joystick }

/// Model lưu trữ chi tiết từng thao tác người dùng theo Tick thời gian
class GameCommand {
  final int tick; // Mốc thời gian thực thi (Game Tick)
  final String unitId; // ID đơn vị thực thi
  final CommandType type; // Loại lệnh
  final double targetX; // Tọa độ X mục tiêu
  final double targetY; // Tọa độ Y mục tiêu
  final String? targetEntityId; // ID đối tượng mục tiêu (nếu có)

  GameCommand({
    required this.tick,
    required this.unitId,
    required this.type,
    required this.targetX,
    required this.targetY,
    this.targetEntityId,
  });

  /// Chuyển đổi thành Map phục vụ lưu trữ (dùng index thay vì string name để tối ưu dung lượng)
  Map<String, dynamic> toJson() => {
    't': tick,
    'u': unitId,
    'c': type.index, // Lưu index thay vì type.name
    'x': targetX,
    'y': targetY,
    if (targetEntityId != null) 'tid': targetEntityId,
  };

  /// Khôi phục đối tượng Command từ dữ liệu JSON
  factory GameCommand.fromJson(Map<String, dynamic> json) => GameCommand(
    tick: json['t'] as int,
    unitId: json['u'] as String,
    type: CommandType.values[json['c'] as int],
    targetX: (json['x'] as num).toDouble(),
    targetY: (json['y'] as num).toDouble(),
    targetEntityId: json['tid'] as String?,
  );
}
