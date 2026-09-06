# Hệ thống Tầm nhìn (Vision System) & Thế giới (Grey-boxing)

Phase này tập trung vào việc xây dựng hệ thống **Sương mù chiến tranh (Fog of War)** và **Tầm nhìn (Line of Sight)**, đồng thời mở rộng các loại địa hình bằng hình khối cơ bản (Grey-boxing) để tạo chiều sâu chiến thuật cho gameplay.

## User Review Required

> [!IMPORTANT]
> Hệ thống tầm nhìn sẽ che khuất kẻ địch và một phần bản đồ mà Hero chưa đi tới hoặc bị vật cản che khuất. Điều này sẽ thay đổi hoàn toàn cách chơi, yêu cầu bạn phải di chuyển cẩn thận hơn.

## Proposed Changes

### [Component: Config & Models]

#### [MODIFY] [game_config.dart](file:///Users/nonoka/Documents/dev/nono_combat_light/lib/config/game_config.dart)
- Thêm `heroVisionRadius`: Bán kính tầm nhìn của Hero (ví dụ: 300.0).
- Thêm các hằng số màu sắc cho Fog (Sương mù).

### [Component: Vision System]

#### [NEW] [fog_of_war.dart](file:///Users/nonoka/Documents/dev/nono_combat_light/lib/components/fog_of_war.dart)
- Tạo component quản lý lớp phủ sương mù.
- Hỗ trợ 3 trạng thái: `Unexplored` (Đen đặc), `Explored` (Bán trong suốt), và `Visible` (Trong suốt).
- Render bằng `CustomPainter` để tối ưu hiệu năng.

#### [NEW] [vision_logic.dart](file:///Users/nonoka/Documents/dev/nono_combat_light/lib/managers/vision_manager.dart)
- Quản lý tính toán tầm nhìn dựa trên vị trí Hero.
- Triển khai thuật toán **Line of Sight (LoS)**: Tầm nhìn bị chặn bởi vật cản (Trees, Walls).

### [Component: World Entities]

#### [MODIFY] [main_game.dart](file:///Users/nonoka/Documents/dev/nono_combat_light/lib/main_game.dart)
- Cập nhật `_buildBarrierGrid` để nhận diện thêm các Layer từ Tiled như `Trees` (Vật cản tầm nhìn).
- Tích hợp `VisionManager` vào vòng lặp `onTick`.

#### [MODIFY] [dummy_target.dart](file:///Users/nonoka/Documents/dev/nono_combat_light/lib/components/dummy_target.dart) & [anime_hero.dart](file:///Users/nonoka/Documents/dev/nono_combat_light/lib/components/anime_hero.dart)
- Thêm thuộc tính `isVisibleToPlayer`.
- Chỉ render đơn vị khi `isVisibleToPlayer` là true (đối với kẻ địch).

---

## Verification Plan

### Automated Tests
- Kiểm tra trạng thái `isVisibleToPlayer` của DummyTarget khi Hero di chuyển ra/vào tầm nhìn.

### Manual Verification
- Di chuyển Hero quanh vật cản (Cây) và kiểm tra xem Fog có che khuất vùng phía sau vật cản không.
- Đảm bảo DummyTarget biến mất khi nằm trong vùng Fog.
