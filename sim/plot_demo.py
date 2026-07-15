#!/usr/bin/env python3
"""
plot_demo.py â€” Script táº¡o tÃ­n hiá»‡u Ä‘áº§u vÃ o vÃ  váº½ Ä‘á»“ thá»‹ káº¿t quáº£ demo 
(Scientific / MATLAB Style).
"""

import sys
import os
import math

SAMPLE_RATE  = 48000
NUM_SAMPLES  = 2048
# Táº¡o Ã¢m thanh phá»©c táº¡p gá»“m 2 táº§n sá»‘ trá»™n vÃ o nhau
FREQ_1       = 500
FREQ_2       = 1200
AMPLITUDE    = 0x300000

def generate():
    filename = "demo_input.hex"
    with open(filename, "w") as f:
        for i in range(NUM_SAMPLES):
            # Trá»™n 2 sÃ³ng sin
            s1 = math.sin(2.0 * math.pi * FREQ_1 * i / SAMPLE_RATE)
            s2 = math.sin(2.0 * math.pi * FREQ_2 * i / SAMPLE_RATE)
            val = int((AMPLITUDE / 2.0) * (s1 + s2))
            
            if val < 0:
                val += (1 << 24)
            f.write(f"{val:06X}\n")

    print(f"=== Da tao {filename} ===")
    print(f"  Tin hieu: {FREQ_1}Hz + {FREQ_2}Hz")

def plot():
    try:
        import numpy as np
        import matplotlib
        matplotlib.use('TkAgg')
        import matplotlib.pyplot as plt
    except ImportError:
        print("Loi: Can cai dat numpy va matplotlib.")
        sys.exit(1)

    output_file = "demo_output.txt"
    if not os.path.exists(output_file):
        print("Loi: Khong tim thay demo_output.txt")
        sys.exit(1)

    # --- Táº¡o láº¡i Input lÃ½ thuyáº¿t ---
    t_in = np.arange(NUM_SAMPLES) / SAMPLE_RATE
    s1 = np.sin(2.0 * np.pi * FREQ_1 * t_in)
    s2 = np.sin(2.0 * np.pi * FREQ_2 * t_in)
    input_signal = (AMPLITUDE / 2.0) * (s1 + s2)

    # --- Äá»c Output thá»±c táº¿ tá»« pháº§n cá»©ng (ModelSim) ---
    output_samples = []
    with open(output_file, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.replace('\x00', '').strip()
            if not line: continue
            try:
                val = int(line, 16)
                if val >= 0x800000: val -= 0x1000000
                output_samples.append(val)
            except ValueError:
                continue

    output_signal = np.array(output_samples, dtype=float)
    t_out = np.arange(len(output_signal)) / SAMPLE_RATE
    num_out = len(output_signal)

    # Chuáº©n hÃ³a vá» [-1, 1]
    input_norm  = input_signal / (2**23)
    output_norm = output_signal / (2**23)

    show_n = min(250, NUM_SAMPLES, num_out)

    # === STYLE: SCIENTIFIC / MATLAB ===
    plt.style.use('default')
    
    # Báº£ng mÃ u chuáº©n cá»§a pháº§n má»m MATLAB (ChuyÃªn ngÃ nh ká»¹ thuáº­t)
    c_blue = '#0072BD'
    c_orange = '#D95319'

    fig, axes = plt.subplots(3, 1, figsize=(12, 10))
    fig.patch.set_facecolor('white')

    fig.suptitle("FPGA CORDIC Voice/Frequency Transformer - Signal Analysis",
                 fontsize=15, fontweight='bold', fontfamily='sans-serif', y=0.96)

    # Cáº¥u hÃ¬nh chung cho cÃ¡c trá»¥c
    for ax in axes:
        ax.grid(True, which='both', linestyle='--', linewidth=0.5, color='#B0B0B0')
        ax.set_facecolor('#F8F9FA')  # XÃ¡m cá»±c nháº¡t lÃ m ná»n
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.spines['left'].set_linewidth(1.2)
        ax.spines['bottom'].set_linewidth(1.2)

    # Äá»“ thá»‹ 1: Input Wave
    axes[0].plot(t_in[:show_n] * 1000, input_norm[:show_n], color=c_blue, linewidth=1.5, label=f'Input Signal ({FREQ_1}Hz + {FREQ_2}Hz)')
    axes[0].set_title('Time Domain - Original Input', fontsize=12, fontweight='bold', loc='left')
    axes[0].set_ylabel('Amplitude (Normalized)', fontsize=11)
    axes[0].set_xlabel('Time (ms)', fontsize=11)
    axes[0].legend(loc='upper right', framealpha=1, edgecolor='#CCCCCC')

    # Äá»“ thá»‹ 2: Output Wave (Cháº­p 2 sÃ³ng Ä‘á»ƒ tháº¥y ÄÆ°á»ng bao Envelope)
    axes[1].plot(t_in[:show_n] * 1000, input_norm[:show_n], color=c_blue, linestyle='--', linewidth=1.5, alpha=0.5, label='Input Envelope (+)')
    axes[1].plot(t_in[:show_n] * 1000, -input_norm[:show_n], color=c_blue, linestyle='--', linewidth=1.5, alpha=0.5, label='Input Envelope (-)')
    axes[1].plot(t_out[:show_n] * 1000, output_norm[:show_n], color=c_orange, linewidth=1.5, label='Output Signal (CORDIC Processed)')
    axes[1].set_title('Time Domain - Frequency-Transformed Output', fontsize=12, fontweight='bold', loc='left')
    axes[1].set_ylabel('Amplitude (Normalized)', fontsize=11)
    axes[1].set_xlabel('Time (ms)', fontsize=11)
    axes[1].legend(loc='upper right', framealpha=1, edgecolor='#CCCCCC', ncol=3)

    # Äá»“ thá»‹ 3: FFT
    skip = min(50, num_out // 4)
    in_fft_data  = input_norm[skip:NUM_SAMPLES]
    out_fft_data = output_norm[skip:num_out]

    win_in  = np.hanning(len(in_fft_data))
    win_out = np.hanning(len(out_fft_data))

    fft_in  = np.abs(np.fft.rfft(in_fft_data * win_in))  / len(in_fft_data)
    fft_out = np.abs(np.fft.rfft(out_fft_data * win_out)) / len(out_fft_data)

    freqs_in  = np.fft.rfftfreq(len(in_fft_data),  1.0 / SAMPLE_RATE)
    freqs_out = np.fft.rfftfreq(len(out_fft_data), 1.0 / SAMPLE_RATE)

    fft_in_db  = 20 * np.log10(fft_in  + 1e-12)
    fft_out_db = 20 * np.log10(fft_out + 1e-12)

    # Plot FFT Input
    axes[2].plot(freqs_in / 1000, fft_in_db, color=c_blue, linewidth=1.5, alpha=0.9, label='Spectrum - Input')
    axes[2].fill_between(freqs_in / 1000, fft_in_db, -100, color=c_blue, alpha=0.08)
    
    # Plot FFT Output
    axes[2].plot(freqs_out / 1000, fft_out_db, color=c_orange, linewidth=1.5, alpha=0.9, label='Spectrum - Output')
    axes[2].fill_between(freqs_out / 1000, fft_out_db, -100, color=c_orange, alpha=0.08)
    
    axes[2].set_title('Frequency Domain Analysis (FFT Spectrum)', fontsize=12, fontweight='bold', loc='left')
    axes[2].set_xlabel('Frequency (kHz)', fontsize=11)
    axes[2].set_ylabel('Magnitude (dB)', fontsize=11)
    axes[2].set_xlim(0, 4)
    axes[2].set_ylim(-80, 0)
    axes[2].legend(loc='upper right', framealpha=1, edgecolor='#CCCCCC')

    plt.tight_layout(rect=[0, 0, 1, 0.95])
    
    # Save & Show
    plt.savefig("demo_results_scientific.png", dpi=200, facecolor='white')
    print("Da luu anh: demo_results_scientific.png")
    plt.show()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Dung: python plot_demo.py generate | plot")
        sys.exit(0)
    if sys.argv[1].lower() == 'generate':
        generate()
    elif sys.argv[1].lower() == 'plot':
        plot()
