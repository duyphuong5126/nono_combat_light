enum WeaponType { melee, ranged }

class WeaponData {
  final String id;
  final String name;
  final String description;
  final WeaponType type;
  final double damage;
  final double range;
  final double attackPoint;
  final double backswing;
  final double projectileSpeed;
  final String spriteAsset;
  final String? projectileAsset;

  WeaponData({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.damage,
    required this.range,
    required this.attackPoint,
    required this.backswing,
    required this.projectileSpeed,
    required this.spriteAsset,
    this.projectileAsset,
  });

  factory WeaponData.fromJson(Map<String, dynamic> json) {
    return WeaponData(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'] == 'melee' ? WeaponType.melee : WeaponType.ranged,
      damage: (json['damage'] as num).toDouble(),
      range: (json['range'] as num).toDouble(),
      attackPoint: (json['attackPoint'] as num).toDouble(),
      backswing: (json['backswing'] as num).toDouble(),
      projectileSpeed: (json['projectileSpeed'] as num).toDouble(),
      spriteAsset: json['spriteAsset'],
      projectileAsset: json['projectileAsset'],
    );
  }

  double get totalAttackCycle => attackPoint + backswing;
}
