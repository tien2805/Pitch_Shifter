# Hướng Dẫn Chạy Demo Dự Án (CORDIC Voice/Frequency Transformer)

Dự án này sử dụng thuật toán CORDIC để dịch pha và thay đổi tần số âm thanh. Để phục vụ việc báo cáo/demo trên máy tính một cách nhanh chóng và trực quan nhất, dự án sử dụng testbench `tb_demo.v` để bơm dữ liệu song song (parallel) trực tiếp vào bộ xử lý, thay vì chờ giao thức I2S chạy thực tế.

Dưới đây là các bước chi tiết. Bạn có thể copy (Ctrl+C) và dán (Ctrl+V) các lệnh trong các khung đen để chạy.

---

## 1. Chuẩn Bị Tín Hiệu Đầu Vào
Trước khi mô phỏng, bạn cần tạo một sóng âm thanh chuẩn (tín hiệu 500 Hz + 1200 Hz) để làm tín hiệu đầu vào.

1. Mở **Terminal** (hoặc Command Prompt / PowerShell) trên máy tính của bạn.
2. Copy lệnh sau (chuột phải để dán vào terminal) và ấn Enter để chuyển hướng vào thư mục `sim`:
   ```bash
   cd C:\Users\nguye\.gemini\antigravity-ide\scratch\fpga-pitch-shifter\sim
   ```
3. Chạy lệnh sau để tạo sóng âm:
   ```bash
   python plot_demo.py generate
   ```
   *(Lệnh này sẽ tự động tạo ra file `demo_input.hex` chứa hàng ngàn mẫu dữ liệu của sóng âm).*

---

## 2. Chạy Mô Phỏng trên ModelSim
Quy trình mô phỏng đã được tự động hóa hoàn toàn bằng một script tên là `demo_run.do`.

1. Mở phần mềm **ModelSim**.
2. Tìm đến cửa sổ dòng lệnh **Transcript** (nằm ở viền dưới cùng của màn hình ModelSim).
3. Copy lệnh sau và ấn Enter để trỏ ModelSim vào đúng thư mục `sim` (Lưu ý: ModelSim dùng gạch chéo `/`):
   ```tcl
   cd C:/Users/nguye/.gemini/antigravity-ide/scratch/fpga-pitch-shifter/sim
   ```
4. Gõ lệnh chạy tự động:
   ```tcl
   do demo_run.do
   ```
5. Đợi khoảng vài giây, ModelSim sẽ tự động dịch code, chạy mô phỏng xong. Nếu bạn không thấy hình ảnh các đường sóng xanh/đỏ, hãy đảm bảo bạn **đã click vào tab `Wave`** (nằm ở góc dưới bên phải màn hình hiển thị code).
6. Để sóng giãn ra vừa màn hình, gõ lệnh:
   ```tcl
   wave zoomfull
   ```

---

## 3. Xem Đồ Thị Phổ Tần Số (FFT) bằng Python
Sau khi ModelSim chạy xong, nó sẽ tạo ra file kết quả là `demo_output.txt`. Chúng ta sẽ dùng Python để vẽ biểu đồ chứng minh phần cứng của bạn đã hoạt động đúng.

1. Quay lại cửa sổ **Terminal** (bạn vẫn đang ở thư mục `sim`).
2. Gõ lệnh vẽ đồ thị:
   ```bash
   python plot_demo.py plot
   ```
3. Một cửa sổ hình ảnh sẽ bật lên gồm 3 biểu đồ cực kỳ chuyên nghiệp:
   - Sóng đầu vào (Input)
   - Sóng đầu ra đã bị thay đổi (Output)
   - Phổ tần số FFT (chứng minh các tone đầu vào tạo ra các sideband mới quanh tần số điều chế).

---

## 4. Cách Điều Chỉnh Tần Số (Tăng/Giảm mức độ méo)
Bạn có thể tự do thay đổi mức độ méo giọng (khoảng cách dịch tần số) bằng cách thay đổi tham số trong code Testbench. Bước này rất hữu ích để demo nghiệm thu cho Giảng viên xem sự thay đổi trực tiếp.

1. Mở file `C:\Users\nguye\.gemini\antigravity-ide\scratch\fpga-pitch-shifter\sim\tb_demo.v` bằng bất kỳ trình soạn thảo code nào (VS Code, Notepad, hoặc mở ngay trong ModelSim).
2. Tìm đến **dòng số 15**:
   ```verilog
   parameter PHASE_STEP  = 24'h055555;  // ~1000 Hz shift
   ```
3. Chỉnh sửa dãy số Hex `24'h...` thành một trong các giá trị sau:
   - Sideband cách ít (~200 Hz): `24'h011111`
   - Sideband cách vừa (~500 Hz): `24'h02AAAB`
   - Sideband cách nhiều (~1000 Hz): `24'h055555`
   - Sideband cách cực đại (~2000 Hz): `24'h0AAAAB`
4. Ấn **Ctrl + S** để lưu file lại.
5. **Chạy lại quy trình:** 
   - Vào ModelSim gõ lại lệnh `do demo_run.do` 
   - Xong qua Terminal gõ lại lệnh `python plot_demo.py plot` để ngắm đồ thị mới! Chúc bạn đạt điểm A+!
