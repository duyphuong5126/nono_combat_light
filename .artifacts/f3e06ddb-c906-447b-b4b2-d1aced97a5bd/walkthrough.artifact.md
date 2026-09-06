# Walkthrough - Hệ thống Tầm nhìn & Sương mù chiến tranh

Mình đã hoàn thành việc tích hợp hệ thống tầm nhìn chuyên nghiệp cho game. Bây giờ thế giới trong "nono combat" đã trở nên bí ẩn và chiến thuật hơn.

## Các thay đổi chính

### 1. Fog of War (Sương mù chiến tranh)
- **Ba trạng thái:**
    - **Chưa khám phá (Đen):** Vùng Hero chưa từng đi qua.
    - **Đã khám phá (Mờ):** Vùng đã đi qua nhưng hiện tại không có tầm nhìn (kẻ địch sẽ bị ẩn đi).
    - **Đang nhìn thấy (Sáng):** Vùng xung quanh Hero trong bán kính 280px.
- **Tối ưu hóa:** Lớp sương mù được vẽ tile-by-tile và chỉ vẽ những ô nằm trong khung hình camera để đảm bảo mượt mà 60fps.

### 2. Line of Sight (Tầm nhìn theo đường thẳng)
- **Chặn tầm nhìn:** Sử dụng thuật toán Bresenham để kiểm tra xem có vật cản (tường, cây) giữa Hero và một ô tile hay không.
- **Tương tác thực tế:** Bạn không thể nhìn thấy kẻ địch nếu chúng trốn sau một cái cây hoặc bức tường.

### 3. Logic Entity Deterministic
- **Ẩn/Hiện Kẻ địch:** `DummyTarget` sẽ tự động ẩn đi nếu không nằm trong tầm nhìn của Hero.
- **Auto-Scan & Attack:** Hero sẽ không tự động tấn công kẻ địch nếu không nhìn thấy chúng.

## Hướng dẫn cho bạn (Tài nguyên Map)

Để hệ thống tầm nhìn hoạt động tốt nhất, bạn có thể cập nhật file map `.tmx` của mình:
- **Tạo Layer tên là `Trees` hoặc `VisionBlockers`**: Đặt các ô vật thể vào đây. Code của mình sẽ tự động nhận diện và biến chúng thành vật cản tầm nhìn.
- Hiện tại, mọi ô trong Layer `Obstacles` cũng đã được mặc định là vật cản tầm nhìn.

## Hình ảnh minh họa (Placeholder)
![Minh họa Fog of War](file:///Users/nonoka/Documents/dev/nono_combat_light/assets/images/fog_placeholder.png)
*(Lưu ý: Bạn hãy chạy thử game để thấy hiệu ứng thực tế trên thiết bị nhé!)*

---
Bạn có thể tiếp tục với việc thiết kế các loại địa hình mới như bụi cỏ (để tàng hình) hoặc các công trình bảo vệ. Bạn thấy hệ thống tầm nhìn này hoạt động như mong đợi chưa?
