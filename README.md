# 🎙️ FPGA Real-time Pitch Shifter — CORDIC DSP Engine

> Hệ thống biến đổi tần số giọng nói/âm thanh thời gian thực trên FPGA, sử dụng thuật toán CORDIC pipeline 16 tầng — không cần bộ nhân phần cứng (Zero DSP48 Multipliers).

![Verilog](https://img.shields.io/badge/Language-Verilog-blue?style=flat-square)
![FPGA](https://img.shields.io/badge/Platform-FPGA%20Artix--7-green?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)
![Status](https://img.shields.io/badge/Status-Simulation%20Verified-brightgreen?style=flat-square)

---

## 📋 Mục lục

- [Tổng quan](#-tổng-quan)
- [Kiến trúc hệ thống](#-kiến-trúc-hệ-thống)
- [Cấu trúc thư mục](#-cấu-trúc-thư-mục)
- [Điểm nổi bật](#-điểm-nổi-bật)
- [Yêu cầu phần mềm](#-yêu-cầu-phần-mềm)
- [Hướng dẫn mô phỏng](#-hướng-dẫn-mô-phỏng)
- [Kết quả mô phỏng](#-kết-quả-mô-phỏng)
- [Tác giả](#-tác-giả)
- [Giấy phép](#-giấy-phép)

---

## 🎯 Tổng quan

Dự án thiết kế một lõi DSP (Digital Signal Processing) chạy hoàn toàn trên phần cứng FPGA, có khả năng **dịch chuyển tần số âm thanh trong thời gian thực** với độ trễ cực thấp (Ultra-low latency ~ 42 µs).

**Nguyên lý hoạt động:** Âm thanh 24-bit từ Microphone I2S đi vào → Lọc DC Offset → Nhân với sóng mang Cosine do CORDIC tạo ra → Xuất ra DAC/Loa qua I2S. Phép nhân `Audio × cos(θ)` tạo ra hiệu ứng dịch tần (Frequency Shifting), biến giọng nói bình thường thành giọng robot, chipmunk, hoặc trầm hùng.

---

## 🏗️ Kiến trúc hệ thống

```
┌─────────┐    ┌──────────┐    ┌────────────────────────────────────────┐    ┌──────────┐    ┌─────────┐
│  MIC    │───▶│  I2S RX  │───▶│           DSP CORE (sys_clk)           │───▶│  I2S TX  │───▶│  DAC/   │
│ (I2S)   │    │ (bclk)   │    │                                        │    │ (bclk)   │    │  Speaker│
└─────────┘    └────┬─────┘    │  ┌───────────┐  ┌──────────────────┐  │    └──────────┘    └─────────┘
                    │          │  │DC Remover  │  │  CORDIC Core     │  │
               ┌────▼─────┐   │  │(IIR HPF)   │─▶│  (16-stage pipe) │  │
               │Async FIFO│──▶│  └───────────┘  └──────────────────┘  │───▶┌──────────┐
               │(Gray CDC)│   │  ┌───────────────────┐                │    │Async FIFO│
               └──────────┘   │  │Phase Accumulator   │                │    │(Gray CDC)│
                              │  │(DDS Oscillator)    │                │    └──────────┘
                              │  └───────────────────┘                │
                              └────────────────────────────────────────┘
```

### Dual Clock Domain

| Miền xung nhịp | Tần số | Chức năng |
|---|---|---|
| `bclk` (I2S) | 12.288 MHz | Giao tiếp serial với Mic/DAC |
| `sys_clk` (System) | 50 MHz | Xử lý DSP lõi CORDIC |

Hai miền được cách ly hoàn toàn bởi **Async FIFO** sử dụng mã Gray + 2-FF Synchronizer để chống Metastability.

---

## 📁 Cấu trúc thư mục

```
fpga-pitch-shifter/
├── rtl/                          # Mã nguồn Verilog (RTL)
│   ├── pitch_shifter_top.v       #   Top-level wrapper
│   ├── i2s_rx.v                  #   I2S Receiver (24-bit)
│   ├── i2s_tx.v                  #   I2S Transmitter (24-bit)
│   ├── async_fifo.v              #   Async FIFO (Gray Code CDC)
│   ├── dc_remover.v              #   DC Offset Remover (IIR HPF)
│   ├── phase_accumulator.v       #   DDS Phase Accumulator
│   ├── cordic_core.v             #   CORDIC 16-stage Pipeline
│   └── pitch_shift_ctrl.v        #   DSP Controller (K-scaling + CORDIC)
│
├── sim/                          # Mô phỏng & Testbench
│   ├── tb_demo.v                 #   Testbench chính (bypass I2S)
│   ├── tb_audio_loopback.v       #   Testbench loopback I2S
│   ├── tb_system_wav.v           #   Testbench xử lý file WAV
│   ├── tb_bug_regression.v       #   Testbench kiểm tra hồi quy lỗi
│   ├── demo_run.do               #   Script tự động chạy ModelSim
│   ├── plot_demo.py              #   Vẽ đồ thị phân tích (Matplotlib)
│   ├── wav_processor.py          #   Công cụ xử lý file WAV
│   └── cordic_golden_ref.py      #   Mô hình tham chiếu CORDIC (Python)
│
├── syn/                          # Tổng hợp (Synthesis)
│   └── timing_constraints.xdc    #   Ràng buộc thời gian Xilinx
│
├── docs/                         # Tài liệu báo cáo
│   ├── TONG_QUAN_DU_AN.md        #   Phân tích tổng quan dự án
│   ├── REPORT_DIAGRAMS.md        #   4 sơ đồ kiến trúc (Mermaid)
│   ├── Q_AND_A_BAO_VE.md         #   Ngân hàng câu hỏi phản biện
│   └── HUONG_DAN_DEMO.md         #   Hướng dẫn chạy demo
│
├── music_pitch_tool.py           # Ứng dụng GUI demo âm thanh
├── .gitignore
├── LICENSE
└── README.md                     # ← Bạn đang đọc file này
```

---

## ✨ Điểm nổi bật

| Đặc điểm | Chi tiết |
|---|---|
| **Zero DSP48** | Toàn bộ phép tính Sin/Cos bằng shift-and-add (CORDIC), không dùng bộ nhân cứng |
| **Ultra-low Latency** | Pipeline 16 tầng + 2 tầng I/O = ~18 clock cycles ≈ **42 µs** |
| **Quadrant Mapping** | Xử lý đúng toàn bộ 360° bằng ánh xạ góc phần tư trước khi đưa vào CORDIC |
| **CORDIC Gain Compensation** | Bù hệ số K ≈ 0.60725 bằng phép dịch bit: `(x>>>1)+(x>>>3)-(x>>>6)-(x>>>9)` — sai số < 0.03% |
| **Dual Clock Domain** | Async FIFO với Gray Code CDC chống Metastability giữa I2S và System clock |
| **Stereo Processing** | Xử lý song song 2 kênh (L/R) với 2 instance CORDIC độc lập |

---

## 🔧 Yêu cầu phần mềm

| Phần mềm | Phiên bản khuyến nghị | Mục đích |
|---|---|---|
| **ModelSim** | Intel FPGA Edition 2020.1+ | Mô phỏng RTL |
| **Python** | 3.8+ | Sinh dữ liệu test & vẽ đồ thị |
| **NumPy** | 1.20+ | Xử lý mảng số |
| **Matplotlib** | 3.4+ | Vẽ biểu đồ phân tích |
| **Quartus Prime** | 20.1+ *(tùy chọn)* | Tổng hợp lên FPGA thực |

---

## 🚀 Hướng dẫn mô phỏng

### Bước 1: Sinh dữ liệu đầu vào
```bash
cd sim
python plot_demo.py generate
```
> Lệnh này tạo file `demo_input.hex` chứa sóng sin kép 500 Hz + 1200 Hz (2048 mẫu, 48 kHz).

### Bước 2: Chạy mô phỏng trên ModelSim
```tcl
# Trong cửa sổ ModelSim Transcript:
cd <đường_dẫn_tới_thư_mục>/sim
do demo_run.do
```
> Script tự động compile RTL → Load testbench → Chạy mô phỏng → Hiển thị sóng Analog trên cửa sổ Wave.

### Bước 3: Vẽ đồ thị phân tích
```bash
python plot_demo.py plot
```
> Xuất ra 3 đồ thị: Sóng đầu vào (Time Domain) → Sóng đầu ra với đường bao Envelope → Phổ tần số FFT.

### Thay đổi mức dịch tần (Pitch Shift Amount)
Mở file `sim/tb_demo.v`, sửa dòng `parameter PHASE_STEP`:

| Giá trị Hex | Tần số dịch | Hiệu ứng |
|---|---|---|
| `24'h02AAAB` | ~500 Hz | Méo giọng nhẹ |
| `24'h055555` | ~1000 Hz | Giọng robot (mặc định) |
| `24'h0AAAAB` | ~2000 Hz | Giọng chipmunk cực mạnh |

---

## 📊 Kết quả mô phỏng

Sau khi chạy `plot_demo.py plot`, biểu đồ xuất ra sẽ hiển thị:

1. **Time Domain — Input**: Sóng sin gốc 500 Hz + 1200 Hz.
2. **Time Domain — Output**: Sóng đã qua CORDIC, nằm gọn trong đường bao Envelope của sóng gốc (chứng minh phép AM đúng chuẩn).
3. **FFT Spectrum**: Phổ tần số cho thấy các đỉnh sideband xuất hiện đúng vị trí lý thuyết, không có rác tần số (Harmonic Distortion).

---

## 👤 Tác giả

**Nguyễn Việt Tiến**

Đồ án Thiết kế Hệ thống số trên FPGA.

---

## 📄 Giấy phép

Dự án được phân phối theo giấy phép [MIT License](LICENSE).
