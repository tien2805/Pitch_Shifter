# Tài Liệu Phản Biện (Q&A) - Bảo Vệ Đồ Án FPGA Voice/Frequency Transformer

Tài liệu này cung cấp các luận điểm "sắc bén" nhất để bạn trả lời các câu hỏi hóc búa từ Hội đồng Giám khảo, đặc biệt về thuật toán CORDIC và tính mới của dự án.

---

## 1. Dự án sử dụng cụ thể phần nào của thuật toán CORDIC?

Thuật toán CORDIC rất rộng (có 3 hệ tọa độ và 2 chế độ hoạt động). Nếu Giảng viên hỏi: *"Dự án của em dùng cấu hình CORDIC nào?"*, bạn phải trả lời chính xác từ khóa sau:

> **"Dạ thưa thầy/cô, hệ thống của em sử dụng thuật toán CORDIC trong Hệ tọa độ Tròn (Circular Coordinate System) và hoạt động ở Chế độ Xoay (Rotation Mode)."**

**Giải thích chi tiết để bảo vệ luận điểm:**
- **Tại sao lại là Hệ tọa độ Tròn?** Vì âm thanh bản chất là các sóng hình sin và hình cos (đặc trưng của đường tròn lượng giác).
- **Tại sao lại là Chế độ Xoay (Rotation Mode)?** Vì đầu vào của em đã có sẵn Biên độ âm thanh (Trục X) và Góc dịch tần mong muốn (Góc $\theta$). Em cần **xoay** biên độ âm thanh đó đi một góc $\theta$ để ép tín hiệu sinh ra các tần số mới (Kỹ thuật điều chế biên độ/DSB trong phiên bản hiện tại).
- **Công thức cốt lõi:** Trong chế độ Circular Rotation với $Y_{in} = 0$, CORDIC sẽ tự động nhả ra kết quả ở trục X là: $X_{out} = Gain \times X_{in} \times \cos(\theta)$. Đây chính là phương trình Toán học hoàn hảo để điều chế/frequency transformer tạo hiệu ứng robot voice mà không cần gọi hàm lượng giác.

---

## 2. Dự án của bạn có gì TỐT HƠN / ĐỘT PHÁ HƠN những dự án của người khác?

Khi làm về Pitch Shifting (Đổi giọng) trên FPGA, 90% sinh viên trên mạng hoặc các khóa luận khác thường dùng 1 trong 2 phương pháp: **Dùng RAM (Delay-line)** hoặc **Dùng biến đổi Fourier (FFT)**. Dự án của bạn đi theo một hướng hoàn toàn khác biệt và vượt trội hơn ở 4 điểm cốt lõi sau:

### Ưu điểm 1: Độ trễ siêu thấp (Ultra-Low Latency ~ 0.32 µs)
- **Dự án của người khác (Dùng FFT):** Để biến đổi Fourier, phần cứng phải chờ "gom đủ" một cục dữ liệu (buffer) từ 1024 đến 2048 mẫu âm thanh rồi mới xử lý. Điều này tạo ra độ trễ cực lớn (từ 20 mili-giây đến 50 mili-giây), hát vào mic phải mất một lúc loa mới phát ra.
- **Dự án của bạn:** Xử lý trực tiếp từng mẫu âm thanh (Sample-by-sample). Âm thanh đi vào ống CORDIC và đi ra chỉ trong vỏn vẹn **16 chu kỳ xung nhịp (0.32 micro-giây)**. Nhanh gấp hàng ngàn lần!

### Ưu điểm 2: Không cần dùng Bộ nhân (Multiplier-less Architecture)
- **Dự án của người khác:** Khi điều chế âm thanh, họ phải dùng các bộ nhân cứng (Hardware Multipliers / DSP Slices) bên trong FPGA để nhân tín hiệu với hàm Sine/Cosine. Bộ nhân rất đắt đỏ và tốn diện tích chip.
- **Dự án của bạn:** Thay thế hoàn toàn bộ nhân bằng thuật toán CORDIC. Bạn chỉ dùng **Phép Cộng, Phép Trừ và Phép Dịch Bit (Shift)**. Tính năng này giúp dự án của bạn có thể nạp và chạy ngon lành trên những con chip FPGA cực kỳ rẻ tiền và yếu nhất.

### Ưu điểm 3: Bộ nhớ rất nhỏ
- **Dự án của người khác (Dùng Delay-line/Buffer):** Đọc ghi liên tục vào bộ nhớ Block RAM (BRAM). Khi con trỏ đọc đuổi kịp con trỏ ghi, âm thanh sẽ bị vỡ tiếng hoặc nổ lụp bụp (Glitches).
- **Dự án của bạn:** Kiến trúc dòng chảy dữ liệu (Dataflow). Tín hiệu chảy thẳng tuột từ Mic qua lõi CORDIC ra Loa, chỉ dùng FIFO CDC nhỏ và pipeline CORDIC, không cần buffer khối lớn như FFT/OLA.

### Ưu điểm 4: Khắc phục triệt để lỗi CORDIC cơ bản
- **Dự án CORDIC nghiệp dư trên mạng:** Mọi người thường nối thẳng âm thanh thô vào CORDIC. Nếu âm thanh thô có nhiễu dòng điện 1 chiều (DC Offset), khi CORDIC xoay, nhiễu 0Hz này sẽ biến thành nhiễu băng tần cao gây điếc tai.
- **Dự án của bạn:** Bạn đã chủ động tự thiết kế một bộ **IIR High-pass Filter (DC Remover)** chắn ngay cửa ngõ trước khi vào CORDIC để gọt sạch điện áp nền, và một bộ **Pre-scaler (0.607)** để chặn đứng lỗi vỡ tiếng do CORDIC Gain. Đây là sự tinh tế của một kỹ sư hiểu rất sâu về xử lý tín hiệu.
