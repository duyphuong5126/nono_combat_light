import 'dart:math';

class CombatMath {
  /// Tính sát thương thực nhận sau khi giảm trừ bởi Armor (Công thức chuẩn Dota 1 / Warcraft 3)
  static double calculateDamage(double rawDamage, double armor) {
    if (armor >= 0) {
      final damageReduction = (0.06 * armor) / (1 + 0.06 * armor);
      return rawDamage * (1 - damageReduction);
    } else {
      // Armor âm (nhận thêm sát thương)
      final damageIncrease = 1 - pow(0.94, -armor).toDouble();
      return rawDamage * (1 + damageIncrease);
    }
  }
}
