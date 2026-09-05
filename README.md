================================================================================
📖 PROJECT OVERVIEW: Nono Combat Light
================================================================================

Mô tả ngắn:
Game mô phỏng giao tranh/di chuyển RTS/MOBA (phong cách Dota 1) phát triển bằng
Flutter + Flame Engine, tích hợp hệ thống Replay deterministic và điều khiển
đa nền tảng (Touch, Mouse, Joystick).

--------------------------------------------------------------------------------
1. KIẾN TRÚC & CẤU TRÚC THƯ MỤC
--------------------------------------------------------------------------------

lib/
├── config/
│   └── game_config.dart        # Cấu hình chỉ số game (Tile size, speed, HUD, mechanics)
├── enums/
│   └── hero_state.dart         # Các trạng thái FSM của Hero (idle, move, attack, casting, ...)
├── models/
│   └── game_command.dart       # Cấu trúc dữ liệu Command phục vụ điều khiển & Replay
├── systems/
│   └── replay_system.dart      # Quản lý ghi (Record) và chạy lại (Replay) trận đấu
├── components/
│   ├── anime_hero.dart         # Entity Hero (Di chuyển, va chạm, turn rate, FSM)
│   ├── minimap.dart            # MiniMap rendering & kéo thả Camera
│   └── bottom_hud.dart         # Overlay UI chứa MiniMap và Joystick
├── main_game.dart              # Core Game Loop (FlameGame, Pathfinding A*, Camera, Input)
└── main.dart                   # Entry point, thiết lập Fullscreen Landscape

--------------------------------------------------------------------------------
2. DANH SÁCH TÍNH NĂNG HIỆN CÓ (FEATURE LIST)
--------------------------------------------------------------------------------

2.1. Bản đồ & Vật cản (TileMap & Collision)
* TiledMap Integration: Tải map .tmx thông qua FlameTiled (mapComponent).
* Obstacle Grid Builder: Tự động quét Layer 'Obstacles' trong Tiled Map để xây
  dựng tập hợp vật cản (barrierSet & barrierList) dạng tọa độ ô Tile.
* Circle vs AABB Collision: Thuật toán va chạm chính xác theo hình học giữa
  Hero (Hình tròn) và Vật cản ô Tile (Chữ nhật AABB).
* Slide Movement (Trượt vật cản): Khi di chuyển bằng Joystick chạm góc tường,
  Hero tự động trượt theo từng trục X hoặc Y hợp lệ thay vì bị kẹt hoàn toàn.

2.2. Hệ thống Tìm đường (A* Pathfinding & Isolate)
* A* Background Computing: Thực hiện thuật toán tìm đường trên Luồng phụ
  (Flutter compute / Isolate) để không gây giật lag FPS trên Main Thread UI.
* Nearest Walkable Tile Finder: Khi người dùng tap/click vào ô vật cản, hệ
  thống tự động tính điểm (weightTarget, weightHero) để tìm ô trống đi được
  gần nhất thay vì báo lỗi/bỏ qua.

2.3. Cơ chế Di chuyển & Mechanics kiểu Dota
* Turn Rate (Tốc độ quay): Hero phải quay mặt về hướng di chuyển (heroTurnRate)
  trước khi bắt đầu bước đi, áp dụng kẹp góc quay chuẩn xác (-pi đến pi).
* Finite State Machine (FSM): Hero được quản lý trạng thái rõ ràng (idle,
  move, attack, casting, stunned, dead).
* Dual Input Control:
    - Point & Click (Tap / Mouse): Hỗ trợ Tap cảm ứng (Mobile) và Click chuột
      phải SecondaryTap (Desktop - Windows/macOS) để tìm đường.
    - Virtual Joystick: Điều khiển di chuyển trực tiếp qua Cần lái ảo trên HUD.

2.4. Camera & Khóa biên (Camera & Viewport)
* Dynamic Viewport & Resize: Tự động tính toán lại kích thước hiển thị khi
  thay đổi độ phân giải màn hình (onGameResize).
* Camera Bounds: Khóa góc nhìn Camera nằm gói gọn trong phạm vi TileMap (không
  lộ khoảng trắng ngoài map) dựa trên visibleWorldRect.
* Camera Follow & Absolute Move: Camera theo sát Hero khi di chuyển và có khả
  năng ngắt follow để di chuyển tức thời tới vị trí chỉ định từ MiniMap.

2.5. Giao diện HUD & MiniMap
* Responsive Bottom HUD: HUD dạng bán trong suốt chiếm 30% chiều cao màn hình
  (getBottomHudHeight), tự động căn chỉnh khoảng cách an toàn tránh góc màn
  hình bo cong.
* Interactive MiniMap:
    - Vẽ thu nhỏ toàn bộ Map, bao gồm vị trí các ô vật cản (Xám), vị trí Hero
      (Xanh) và khung nhìn Camera (Trắng).
    - Cho phép Tap hoặc Kéo đĩa di chuyển (Drag) trên MiniMap để di chuyển
      Camera trực quan.

2.6. Hệ thống Ghi Replay (Deterministic Command Log)
* GameCommand Model: Đóng gói hành động với thông tin tick, unitId, type
  (move, attack, useSkill, stop, spawnUnit), tọa độ targetX/targetY và
  targetEntityId.
* ReplayManager: Lưu trữ danh sách recordedCommands, hỗ trợ xuất dữ liệu ra
  chuỗi JSON (exportReplayJson) và nạp lại để phát Replay (loadReplayJson).

--------------------------------------------------------------------------------
3. THÔNG SỐ CẤU HÌNH CHÍNH (GameConfig)
--------------------------------------------------------------------------------

- tileSize              : 64.0 (Kích thước 1 ô Tile - px)
- defaultZoom           : 1.2  (Tỷ lệ Zoom mặc định của Camera)
- heroRadius            : 20.0 (Bán kính hitbox của Hero)
- heroMoveSpeed         : 180.0 (Tốc độ di chuyển cơ bản)
- heroTurnRate          : 14.0 (Tốc độ quay mặt - rad/s)
- attackRange           : 120.0 (Tầm đánh cơ bản)
- attackPoint / backswing: 0.3 / 0.4 (Độ trễ trước/sau khi tung đòn đánh - Dota Animation)

--------------------------------------------------------------------------------
4. HƯỚNG NÂNG CẤP TIẾP THEO (TODO LIST)
--------------------------------------------------------------------------------

[ ] 1. Fixed Tick Rate Logic: Chuyển toàn bộ di chuyển từ dt (FPS-dependent)
sang Fixed Update Step (ví dụ: 30 Ticks/giây) để Replay chuẩn xác 100%
giữa các thiết bị khác tần số quét.
[ ] 2. Joystick Command Stream: Đóng gói thao tác Joystick thành chuỗi GameCommand
định kỳ thay vì cập nhật trực tiếp position trong update() để Replay
bắt được chuyển động.
[ ] 3. Combat Mechanics: Cài đặt hệ thống gây sát thương, Animation Attack
Point / Backswing cancel.
================================================================================
