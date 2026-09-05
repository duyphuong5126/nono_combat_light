/// Quản lý Máy trạng thái hữu hạn (FSM) của Hero
enum HeroState {
  idle, // Đứng yên
  move, // Đang di chuyển
  attack, // Đang tung đòn đánh
  casting, // Đang thi triển kỹ năng
  stunned, // Bị khống chế / Choáng
  dead, // Đã gục ngã
}
