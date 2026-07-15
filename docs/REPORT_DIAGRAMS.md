# Sơ Đồ Kỹ Thuật — Dự Án FPGA Voice/Frequency Transformer
> Tất cả sơ đồ dưới đây phản ánh chính xác code Verilog trong thư mục `rtl/`.
> Copy mã Mermaid vào **[mermaid.live](https://mermaid.live/)** → Bấm nút tải ảnh PNG → Dán vào Word/PowerPoint.

---

## 1. Block Diagram — Kiến Trúc Hệ Thống Tổng Thể (pitch_shifter_top.v)

Sơ đồ này cho thấy toàn bộ đường đi của tín hiệu âm thanh từ lúc đi vào chip FPGA đến lúc đi ra loa, trải qua 5 tầng xử lý. Hai miền xung nhịp (Clock Domain) được phân tách rõ ràng bằng cặp FIFO bất đồng bộ.

```mermaid
graph LR
    subgraph "Phần Cứng Bên Ngoài"
        MIC["🎤 Microphone<br/>(ADC → I2S)"]
        DAC["🔊 Loa<br/>(DAC ← I2S)"]
        SW["🎛️ Switches<br/>(switch_in[23:0])"]
    end

    subgraph FPGA["CHIP FPGA"]
        direction LR

        subgraph BCLK_IN["Miền Clock BCLK (3.072 MHz)"]
            direction TB
            RX["<b>i2s_rx</b><br/>Giải mã I2S Serial → Parallel<br/>sdata → left_data[23:0], right_data[23:0]"]
        end

        subgraph CDC_RX["Đồng Bộ Xung Nhịp"]
            FIFO_RX["<b>async_fifo</b> (RX)<br/>DATA_WIDTH=48, DEPTH=32<br/>Gray Code Pointer Sync<br/>BCLK → SYS_CLK"]
        end

        subgraph SYS["Miền Clock SYS_CLK (50 MHz)"]
            CTRL["<b>pitch_shift_ctrl</b><br/>Lõi Xử Lý DSP<br/>(xem Block Diagram #2)"]
        end

        subgraph CDC_TX["Đồng Bộ Xung Nhịp"]
            FIFO_TX["<b>async_fifo</b> (TX)<br/>DATA_WIDTH=48, DEPTH=32<br/>Gray Code Pointer Sync<br/>SYS_CLK → BCLK"]
        end

        subgraph BCLK_OUT["Miền Clock BCLK (3.072 MHz)"]
            direction TB
            TX["<b>i2s_tx</b><br/>Đóng gói Parallel → I2S Serial<br/>left_data[23:0], right_data[23:0] → sdata"]
        end
    end

    MIC -->|"sdata_in<br/>(serial)"| RX
    RX -->|"{rx_left, rx_right}<br/>48-bit"| FIFO_RX
    FIFO_RX -->|"fifo_rx_data_out<br/>48-bit"| CTRL
    SW -->|"phase_step<br/>24-bit"| CTRL
    CTRL -->|"{audio_out_l, audio_out_r}<br/>48-bit"| FIFO_TX
    FIFO_TX -->|"fifo_tx_data_out<br/>48-bit"| TX
    TX -->|"sdata_out<br/>(serial)"| DAC
```

---

## 2. Block Diagram — Lõi Xử Lý DSP (pitch_shift_ctrl.v)

Sơ đồ này zoom vào bên trong module `pitch_shift_ctrl`, thể hiện chính xác cách tín hiệu âm thanh Stereo (2 kênh Trái/Phải) được xử lý song song qua 4 tầng pipeline.

```mermaid
graph TD
    subgraph "pitch_shift_ctrl — Lõi DSP"
        direction TB

        IN_L["audio_in_l[23:0]<br/>(Kênh Trái)"]
        IN_R["audio_in_r[23:0]<br/>(Kênh Phải)"]
        PS["phase_step[23:0]<br/>(Mức dịch tần)"]

        subgraph "Tầng 1: Tiền Xử Lý (Loại bỏ DC Offset)"
            DC_L["<b>dc_remover</b> (u_dc_rem_l)<br/>Bộ lọc IIR thông cao bậc 1<br/>y[n] = x[n] - x[n-1] + R·y[n-1]<br/>R = 255/256"]
            DC_R["<b>dc_remover</b> (u_dc_rem_r)<br/>Bộ lọc IIR thông cao bậc 1<br/>y[n] = x[n] - x[n-1] + R·y[n-1]<br/>R = 255/256"]
        end

        subgraph "Tầng 1b: Tạo Góc Xoay"
            PHACC["<b>phase_accumulator</b> (u_phase_acc)<br/>phase_out += phase_step<br/>(mỗi khi có mẫu mới)"]
        end

        subgraph "Tầng 2: Bù Hệ Số CORDIC Gain"
            SCALE_L["<b>Pre-Scaler Kênh Trái</b><br/>scaled = (dc_clean >>> 1)<br/>+ (dc_clean >>> 3)<br/>- (dc_clean >>> 6)<br/>≈ K × 0.607"]
            SCALE_R["<b>Pre-Scaler Kênh Phải</b><br/>scaled = (dc_clean >>> 1)<br/>+ (dc_clean >>> 3)<br/>- (dc_clean >>> 6)<br/>≈ K × 0.607"]
        end

        subgraph "Tầng 3: Xoay Vector CORDIC (16 Pipeline Stages)"
            CORDIC_L["<b>cordic_core</b> (u_cordic_l)<br/>x_in = scaled_audio_l<br/>y_in = 0<br/>phase_in = current_phase<br/>→ x_out = x·cos(θ) - y·sin(θ)"]
            CORDIC_R["<b>cordic_core</b> (u_cordic_r)<br/>x_in = scaled_audio_r<br/>y_in = 0<br/>phase_in = current_phase<br/>→ x_out = x·cos(θ) - y·sin(θ)"]
        end

        OUT_L["audio_out_l = cordic_x_out_l"]
        OUT_R["audio_out_r = cordic_x_out_r"]

        IN_L --> DC_L
        IN_R --> DC_R
        PS --> PHACC

        DC_L --> SCALE_L
        DC_R --> SCALE_R

        SCALE_L --> CORDIC_L
        SCALE_R --> CORDIC_R
        PHACC -->|"current_phase[23:0]"| CORDIC_L
        PHACC -->|"current_phase[23:0]"| CORDIC_R

        CORDIC_L --> OUT_L
        CORDIC_R --> OUT_R
    end
```

---

## 3. Flowchart — Thuật Toán CORDIC Rotation (cordic_core.v)

Lưu đồ này mô tả chính xác 16 bước xoay vector bên trong module `cordic_core`. Mỗi bước chỉ sử dụng phép Cộng, Trừ và Dịch bit (Shift) — hoàn toàn không cần bộ nhân phần cứng (DSP Multiplier).

```mermaid
flowchart TD
    A([Bắt đầu: Nhận dữ liệu đầu vào]) --> B["<b>Stage 0: Nạp dữ liệu</b><br/>x[0] ← x_in (audio đã scale)<br/>y[0] ← y_in (= 0)<br/>z[0] ← phase_in (góc xoay)"]

    B --> C{"Lặp i = 1 → 16<br/>(16 Pipeline Stages)"}

    C --> D{"Kiểm tra dấu của z[i-1]<br/>(bit MSB z[i-1][23])"}

    D -->|"z[i-1] ≥ 0<br/>(Góc dư dương → Xoay ngược chiều KĐH)"| E["x[i] = x[i-1] - (y[i-1] >>> i-1)<br/>y[i] = y[i-1] + (x[i-1] >>> i-1)<br/>z[i] = z[i-1] - atan_table[i-1]"]

    D -->|"z[i-1] < 0<br/>(Góc dư âm → Xoay theo chiều KĐH)"| F["x[i] = x[i-1] + (y[i-1] >>> i-1)<br/>y[i] = y[i-1] - (x[i-1] >>> i-1)<br/>z[i] = z[i-1] + atan_table[i-1]"]

    E --> G{"i < 16?"}
    F --> G

    G -->|"Có → Tiếp tục<br/>vòng lặp tiếp theo"| C
    G -->|"Không → Hoàn tất<br/>16 bước xoay"| H["<b>Stage 17: Xuất kết quả</b><br/>x_out ← x[16]<br/>y_out ← y[16]<br/>valid_out ← v[16]"]

    H --> I(["Kết thúc: Audio đã được dịch tần"])
```

---

## 4. Module Hierarchy — Cấu Trúc Phân Cấp File RTL

Sơ đồ cây (tree) thể hiện quan hệ cha-con giữa các module Verilog. Dấu `×2` nghĩa là module đó được gọi (instantiate) 2 lần.

```mermaid
graph TD
    TOP["<b>pitch_shifter_top</b><br/>(Top-level Module)<br/>File: pitch_shifter_top.v"]

    TOP --> I2S_RX["<b>i2s_rx</b> (u_i2s_rx)<br/>File: i2s_rx.v"]
    TOP --> FIFO1["<b>async_fifo</b> (u_fifo_rx)<br/>48-bit, Depth 32<br/>File: async_fifo.v"]
    TOP --> PSC["<b>pitch_shift_ctrl</b> (u_pitch_ctrl)<br/>File: pitch_shift_ctrl.v"]
    TOP --> FIFO2["<b>async_fifo</b> (u_fifo_tx)<br/>48-bit, Depth 32<br/>File: async_fifo.v"]
    TOP --> I2S_TX["<b>i2s_tx</b> (u_i2s_tx)<br/>File: i2s_tx.v"]

    PSC --> DC1["<b>dc_remover</b> (u_dc_rem_l)<br/>Kênh Trái<br/>File: dc_remover.v"]
    PSC --> DC2["<b>dc_remover</b> (u_dc_rem_r)<br/>Kênh Phải<br/>File: dc_remover.v"]
    PSC --> PA["<b>phase_accumulator</b> (u_phase_acc)<br/>File: phase_accumulator.v"]
    PSC --> C1["<b>cordic_core</b> (u_cordic_l)<br/>Kênh Trái — 16 stages<br/>File: cordic_core.v"]
    PSC --> C2["<b>cordic_core</b> (u_cordic_r)<br/>Kênh Phải — 16 stages<br/>File: cordic_core.v"]

    style TOP fill:#0072BD,stroke:#333,stroke-width:2px,color:#fff
    style PSC fill:#D95319,stroke:#333,stroke-width:2px,color:#fff
    style C1 fill:#77AC30,stroke:#333,stroke-width:2px,color:#fff
    style C2 fill:#77AC30,stroke:#333,stroke-width:2px,color:#fff
    style PA fill:#EDB120,stroke:#333,stroke-width:2px,color:#000
```

---

## Bảng Tổng Hợp Module

| # | Module | File | Chức năng | Miền Clock | Số Instance |
|---|--------|------|-----------|------------|-------------|
| 1 | `pitch_shifter_top` | pitch_shifter_top.v | Khung chính kết nối toàn bộ hệ thống | — | 1 |
| 2 | `i2s_rx` | i2s_rx.v | Giải mã tín hiệu I2S Serial → 24-bit Parallel | BCLK | 1 |
| 3 | `async_fifo` | async_fifo.v | Bộ đệm FIFO bất đồng bộ (Gray Code Sync) | BCLK ↔ SYS | 2 |
| 4 | `pitch_shift_ctrl` | pitch_shift_ctrl.v | Điều phối lõi DSP: DC Remove → Scale → CORDIC | SYS_CLK | 1 |
| 5 | `dc_remover` | dc_remover.v | Bộ lọc thông cao IIR bậc 1 (R = 255/256) | SYS_CLK | 2 |
| 6 | `phase_accumulator` | phase_accumulator.v | Tích lũy pha tuyến tính (NCO) | SYS_CLK | 1 |
| 7 | `cordic_core` | cordic_core.v | Xoay vector 16-stage pipeline (Rotation Mode) | SYS_CLK | 2 |
| 8 | `i2s_tx` | i2s_tx.v | Đóng gói 24-bit Parallel → I2S Serial | BCLK | 1 |
| | | | | **Tổng Instances** | **10** |
