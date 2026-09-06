# Chuẩn hóa Replay (Deterministic) & Nội suy Hình ảnh (Smoothing)

Phase này đã hoàn thành việc xây dựng "động cơ" lõi cho game, đảm bảo logic chạy chuẩn xác theo Tick để phục vụ Replay, đồng thời tối ưu hóa hiển thị để đạt độ mượt mà cao nhất.

## Thành tựu đã đạt được

### [Core Engine]
- **Fixed Tick Rate (60 Ticks/s):** Logic di chuyển và chiến đấu được khóa chặt ở 60Hz, đảm bảo tính đồng nhất giữa các thiết bị.
- **Visual Interpolation:** Triển khai nội suy vị trí (`prevPosition` -> `renderPosition`) giúp nhân vật di chuyển mượt mà ở mọi tốc độ khung hình (FPS).
- **Accumulator Loop:** Tách biệt hoàn toàn thời gian render và thời gian xử lý logic.

### [Input System]
- **Joystick Command Stream:** Chuyển đổi thao tác điều khiển trực tiếp sang hệ thống lệnh (`GameCommand`).
- **Input Optimization:** Áp dụng làm tròn tọa độ và lọc tín hiệu (Throttle) để tối ưu hóa dung lượng file Replay và tính chính xác.

### [Entity Logic]
- **Deterministic Units:** Hero, Dummy và Projectile đã được chuyển sang hệ thống `onTick`.
- **Unit Collision:** Hoàn thiện va chạm hình tròn giữa các Unit, không còn tình trạng đi xuyên qua nhau.

## Hướng phát triển tiếp theo (Đề xuất)
- **Hệ thống Tầm nhìn (Fog of War):** Thiết lập tầm nhìn của Hero, vùng tối và các vật thể che khuất.
- **Địa hình & Công trình:** Thêm cây cối (che tầm nhìn), nhà cửa, và địa hình cao/thấp (High ground).
