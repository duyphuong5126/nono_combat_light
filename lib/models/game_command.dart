enum CommandType { move, attack, useSkill, stop }

class GameCommand {
  final int tick;
  final String unitId;
  final CommandType type;
  final double targetX;
  final double targetY;
  final String? targetEntityId;

  GameCommand({
    required this.tick,
    required this.unitId,
    required this.type,
    required this.targetX,
    required this.targetY,
    this.targetEntityId,
  });

  Map<String, dynamic> toJson() => {
    'tick': tick,
    'unitId': unitId,
    'type': type.name,
    'x': targetX,
    'y': targetY,
    'targetEntityId': targetEntityId,
  };

  factory GameCommand.fromJson(Map<String, dynamic> json) => GameCommand(
    tick: json['tick'],
    unitId: json['unitId'],
    type: CommandType.values.byName(json['type']),
    targetX: json['x'],
    targetY: json['y'],
    targetEntityId: json['targetEntityId'],
  );
}
