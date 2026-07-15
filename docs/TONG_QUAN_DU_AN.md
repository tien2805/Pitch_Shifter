tô# Báo Cáo Tổng Quan Dự Án: FPGA Real-Time Pitch Shifter (Điều Chế Cao Độ Âm Thanh)

## 1. Giới Thiệu Tổng Quát
Dự án này là một hệ thống **Xử lý tín hiệu số (DSP) thời gian thực** được triển khai trên nền tảng vi mạch phần cứng FPGA. Mục tiêu của hệ thống là thay đổi cao độ (pitch/tần số) của giọng nói hoặc âm nhạc trực tiếp từ Microphone và phát ngay ra Loa mà không có độ trễ (Zero-latency).

Điểm đột phá kỹ thuật của dự án là việc áp dụng **Thuật toán CORDIC** để thực hiện phép Điều chế Đơn biên (Single Sideband Modulation - SSB). Thay vì sử dụng các bộ tính toán lượng giác (Sine/Cosine) hay bộ nhân (Multipliers) đắt đỏ, hệ thống hoàn toàn chỉ dùng các phép tính cơ bản (Cộng, Trừ, Dịch bit) để xoay vector âm thanh, giúp tiết kiệm tối đa tài nguyên phần cứng.

---

## 2. Các Module Thành Phần (Module Structure)
Dự án bao gồm 8 file Verilog (.v) đảm nhiệm các vai trò riêng biệt, được tổ chức theo chuẩn công nghiệp:

1.  **`pitch_shifter_top.v`**: Module "Trùm" (Top-level) bọc ngoài cùng. Đóng vai trò như một bo mạch chủ kết nối dây điện giữa tất cả các module con lại với nhau.
2.  **`i2s_rx.v`**: Bộ Thu I2S. Giao tiếp với chip Microphone (ADC), dịch các chuỗi bit nối tiếp (Serial) thành dữ liệu song song (Parallel) 24-bit cho kênh Trái và Phải.
3.  **`async_fifo.v`**: Bộ Đệm Bất Đồng Bộ (Asynchronous FIFO). Là "trạm trung chuyển" dữ liệu an toàn giữa hai vùng có tốc độ xung nhịp (Clock) lệch nhau.
4.  **`pitch_shift_ctrl.v`**: Khung sườn của lõi xử lý DSP. Nó điều phối luồng dữ liệu chảy qua các bộ lọc và thuật toán lõi.
5.  **`dc_remover.v`**: Bộ lọc thông cao IIR. Làm sạch âm thanh bằng cách loại bỏ điện áp dư thừa (DC Offset), giúp sóng âm thanh luôn cân bằng ở mốc 0.
6.  **`phase_accumulator.v`**: Bộ Tích Lũy Pha. Đóng vai trò như một bánh răng đồng hồ, liên tục đếm góc xoay dựa trên mức độ "méo tiếng" do người dùng cài đặt.
7.  **`cordic_core.v`**: Trái tim của toàn hệ thống. Một đường ống (Pipeline) 16 tầng thực hiện 16 phép xoay vi phân để trộn (điều chế) âm thanh gốc với góc xoay.
8.  **`i2s_tx.v`**: Bộ Phát I2S. Đóng gói âm thanh 24-bit đã qua xử lý trả lại thành dạng nối tiếp để gửi ra chip Loa (DAC).

---

## 3. Phân Tích Chuyên Sâu 4 Sơ Đồ Kiến Trúc
*(Lưu ý: Mở file `REPORT_DIAGRAMS.md` để xem hình ảnh 4 sơ đồ đối chiếu với phân tích này)*

### Sơ Đồ 1: Kiến Trúc Hệ Thống Tổng Thể (System Architecture)
Sơ đồ này phác họa toàn bộ dòng chảy dữ liệu (Datapath) và chiến lược quản lý xung nhịp (Clocking Strategy) của hệ thống phần cứng.

**Phân tích chi tiết:**
*   **Phân ranh giới Clock Domain (Miền xung nhịp):** Chip FPGA được chia làm hai khu vực hoạt động với 2 nhịp tim khác nhau. Miền 1 chạy ở `3.072 MHz` (BCLK) — tính bằng 48kHz × 2 kênh × 32-bit/kênh. Miền 2 là não bộ DSP chạy ở tốc độ cao `50 MHz` (SYS_CLK) để có đủ thời gian xử lý các phép toán phức tạp giữa các mẫu âm thanh.
*   **Vai trò cốt lõi của Async FIFO:** Khi dữ liệu đi từ miền xung âm thanh sang miền xung nhanh (50 MHz), nếu nối dây trực tiếp sẽ sinh ra hiện tượng Metastability (lỗi trạng thái lửng). Để giải quyết, hệ thống dùng 2 bộ **Async FIFO** làm vùng đệm. Mã Gray (Gray Code) được áp dụng ở các con trỏ đọc/ghi (Read/Write Pointers) của FIFO để đồng bộ hóa tín hiệu an toàn qua lại giữa hai miền clock, đảm bảo không rớt hay méo một mẫu âm thanh nào.
*   **Dòng chảy dữ liệu 48-bit:** Module `i2s_rx` nhận chuỗi bit nối tiếp (Serial) từ Mic, giải mã thành 2 gói dữ liệu 24-bit song song (Kênh Trái/Phải). Chúng được gộp thành bus `48-bit` tống vào FIFO_RX, xử lý tại lõi DSP, xuất ra FIFO_TX và cuối cùng đóng gói lại thành serial qua `i2s_tx`.

### Sơ Đồ 2: Khối Lõi Xử Lý DSP (DSP Dataflow)
Sơ đồ này zoom sát vào module `pitch_shift_ctrl` để xem tín hiệu bị thao tác như thế nào.

**Phân tích chi tiết:**
*   **Thiết kế Xử lý Song song (Parallel Processing):** Không giống như vi điều khiển xử lý lần lượt từng kênh, FPGA khởi tạo 2 bản sao phần cứng của `dc_remover` và `cordic_core` để xử lý độc lập Kênh Trái và Kênh Phải tại cùng một thời điểm. Điều này giúp nhân đôi thông lượng (Throughput).
*   **DC Remover (Bộ lọc IIR):** Tín hiệu âm thanh thô thường bị lệch khỏi tọa độ 0 (gọi là DC Offset). Hệ thống sử dụng một bộ lọc IIR thông cao bậc 1 với phương trình $y[n] = x[n] - x[n-1] + R \cdot y[n-1]$ (trong đó $R = 255/256$). Nhờ thao tác này, dòng điện 1 chiều (0Hz) bị cản lại, sóng âm thanh trở nên cân bằng.
*   **Phase Accumulator (NCO):** Đóng vai trò như một bộ tạo dao động (Oscillator). Nó cộng dồn giá trị `phase_step` liên tục. Việc tích lũy này tạo ra một góc xoay $\theta$ tịnh tiến đều đặn, chính là "sóng mang" để nhét âm thanh vào điều chế.
*   **Pre-scaler (Bù trừ hệ số CORDIC Gain):** Mọi thuật toán CORDIC đều có độ lợi nội tại là $\approx 1.64676$. Nếu giữ nguyên, âm thanh đẩy qua CORDIC sẽ bị khuyếch đại gây tràn số 24-bit (Overflow) và rè loa. Hệ thống triệt tiêu nó bằng cách nhân tín hiệu với $K \approx 0.607$. Thay vì tốn bộ nhân, code áp dụng kỹ thuật dịch bit siêu tốc: `(Audio >> 1) + (Audio >> 3) - (Audio >> 6)`, tạo ra con số $0.609$ tiệm cận $0.607$ với chi phí tài nguyên gần như bằng 0.

### Sơ Đồ 3: Lưu Đồ Thuật Toán CORDIC (Algorithm Flowchart)
Sơ đồ này bóc tách thuật toán toán học làm nền tảng cho việc biến đổi nốt nhạc (Single Sideband Modulation).

**Phân tích chi tiết:**
*   **Cơ chế xoay Vector không cần hàm Lượng giác:** CORDIC xoay vector âm thanh theo một góc $\theta$ bằng cách băm nhỏ góc đó thành 16 góc vi phân. Hệ thống sở hữu một bảng tra cứu (Look-up Table - `atan_table`) lưu sẵn giá trị của 16 góc dưới dạng hằng số, không tốn thời gian tính toán.
*   **Điều kiện Rẽ nhánh (Decision Logic):** Ở mỗi bước xoay $i$, thuật toán kiểm tra bit dấu (MSB) của góc dư $z[i-1]$. Nếu góc dư dương ($z \geq 0$), vector sẽ bị bẻ xuống (trừ góc). Nếu góc dư âm ($z < 0$), vector bị bẻ lên (cộng góc). Quá trình rẽ nhánh này liên tục tiệm cận góc xoay mục tiêu.
*   **Kiến trúc Pipeline 16 tầng:** Đây là phần "đắt giá" nhất. Code không dùng vòng lặp `for` chạy tốn 16 nhịp đồng hồ cho một mẫu. Thay vào đó, nó là một đường ống dây chuyền 16 tầng. Tại một thời điểm bất kỳ, tầng 1 đang xử lý mẫu số 16, tầng 2 xử lý mẫu 15,... và tầng 16 đang nhả ra mẫu số 1. Nhờ đó, cứ mỗi 1 xung nhịp (clock), hệ thống lại xuất ra được 1 mẫu âm thanh hoàn chỉnh (Throughput = 1 mẫu/clock).

### Sơ Đồ 4: Cây Phân Cấp Module (RTL Hierarchy)
Đây là bản đồ cấu trúc Source code, chứng minh tính quy củ trong thiết kế.

**Phân tích chi tiết:**
*   **Triết lý Thiết kế Top-Down:** Code được thiết kế như một cái cây. Khung sườn lớn nhất (`pitch_shifter_top`) chỉ làm nhiệm vụ đi dây điện (wiring) giữa các thành phần. Cách thiết kế này giúp dễ dàng cô lập lỗi (Debug), quản lý tài nguyên và đặc biệt là tính Tái sử dụng (Reusability).
*   **Tính Mô-đun hóa cao (Modularity):** Các khối Giao tiếp vật lý (`i2s_rx`, `i2s_tx`), khối Đồng bộ xung nhịp (`async_fifo`) và khối Toán học (`cordic_core`, `dc_remover`) được tách biệt hoàn toàn ranh giới. Nếu sau này muốn đổi sang chip Microphone chuẩn PDM thay vì I2S, ta chỉ cần gỡ bỏ module `i2s_rx` và cắm module `pdm_rx` vào mà không cần chạm đến lõi DSP bên trong. Đây là tiêu chuẩn thiết kế Hệ thống trên Chip (SoC) trong công nghiệp.
