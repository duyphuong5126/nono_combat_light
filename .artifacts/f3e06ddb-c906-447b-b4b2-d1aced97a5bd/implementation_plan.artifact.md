# Hệ thống Vũ khí Tách biệt & Cơ chế Tấn công Nâng cao

Kế hoạch này tập trung vào việc tách logic tấn công ra khỏi Hero, chuyển sang mô hình Data-Driven (dựa trên dữ liệu JSON) và cải thiện trí tuệ nhân tạo (AI) cơ bản cho việc tự động tấn công (Auto-Attack/Chase). Điều này chuẩn bị nền tảng vững chắc cho việc tích hợp đồ họa Anime HD trong tương lai.

## User Review Required

> [!IMPORTANT]
> Việc tách biệt vũ khí sẽ làm thay đổi cách Hero tương tác với mục tiêu. Các chỉ số như `attackRange`, `attackPoint` sẽ không còn lấy từ `GameConfig` chung mà lấy từ đối tượng `Weapon` được trang bị.

## Proposed Changes

### [Component: Data & Models]

#### [NEW] [weapons.json](file:///Users/nonoka/Documents/dev/nono_combat_light/assets/data/weapons.json)
Định nghĩa danh sách các loại vũ khí với các chỉ số: sát thương, tầm đánh, tốc độ tấn công, loại đạn bay.

#### [NEW] [weapon_model.dart](file:///Users/nonoka/Documents/dev/nono_combat_light/lib/models/weapon_data.dart)
Data class để parse dữ liệu từ JSON và cung cấp các phương thức tiện ích.

### [Component: Core Logic]

#### [MODIFY] [pubspec.yaml](file:///Users/nonoka/Documents/dev/nono_combat_light/pubspec.yaml)
Đăng ký thư mục `assets/data/` để Flutter có thể truy cập các file cấu hình.

#### [MODIFY] [anime_hero.dart](file:///Users/nonoka/Documents/dev/nono_combat_light/lib/components/anime_hero.dart)
- Xóa các thuộc tính tấn công cứng (`attackDamage`, `attackRange`...).
- Thêm thuộc tính `equippedWeapon`.
- Cập nhật logic `_handleAttackState` để sử dụng chỉ số từ vũ khí.
- Triển khai logic **Auto-Chase**: Nếu mục tiêu ngoài tầm đánh nhưng trong tầm quan sát, Hero sẽ tự đuổi theo.

### [Component: Rendering & Feedback]

#### [MODIFY] [projectile.dart](file:///Users/nonoka/Documents/dev/nono_combat_light/lib/components/projectile.dart)
Cập nhật để có thể thay đổi hình ảnh (sprite) dựa trên cấu hình vũ khí.

---

## Verification Plan

### Automated Tests
- Chạy ứng dụng và kiểm tra Logcat để đảm bảo JSON được nạp thành công.

### Manual Verification
- Kiểm tra Hero có tự động xoay mặt và đánh khi kẻ địch vào tầm không.
- Kiểm tra Hero có đuổi theo khi kẻ địch di chuyển ra xa không.
- Thử nghiệm thay đổi chỉ số trong JSON và quan sát sự thay đổi trong game mà không cần sửa code Hero.
