import 'package:flame/components.dart';

/// Quản lý tập trung toàn bộ Entity trên bản đồ theo ID duy nhất
class UnitRegistry {
  static final UnitRegistry _instance = UnitRegistry._internal();

  factory UnitRegistry() => _instance;

  UnitRegistry._internal();

  final Map<String, PositionComponent> _units = {};

  /// Đăng ký đơn vị mới vào hệ thống
  void registerUnit(String id, PositionComponent unit) {
    _units[id] = unit;
  }

  /// Hủy đăng ký đơn vị (khi quái/hero chết hoặc bị xóa)
  void unregisterUnit(String id) {
    _units.remove(id);
  }

  /// Tìm đơn vị theo ID
  PositionComponent? getUnit(String id) {
    return _units[id];
  }

  /// Lấy danh sách tất cả đơn vị hiện có
  List<PositionComponent> getAllUnits() {
    return _units.values.toList();
  }

  /// Xóa sạch dữ liệu (dùng khi reset game hoặc load map mới)
  void clear() {
    _units.clear();
  }
}
