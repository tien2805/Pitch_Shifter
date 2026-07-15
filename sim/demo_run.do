# ==============================================================
#  demo_run.do — Script ModelSim tu dong hoa quy trinh demo
#  Cach dung: Trong ModelSim, go: do demo_run.do
# ==============================================================

# 1. Tao thu muc work (neu chua co)
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

# 2. Compile cac module RTL can thiet (chi can DSP core, khong can I2S/FIFO)
vlog ../rtl/dc_remover.v
vlog ../rtl/phase_accumulator.v
vlog ../rtl/cordic_core.v
vlog ../rtl/pitch_shift_ctrl.v

# 3. Compile testbench demo
vlog tb_demo.v

# 4. Load simulation
vsim -voptargs="+acc" work.tb_demo

# 5. Thiet lap cua so Wave voi format dep
# --- Control Signals ---
add wave -divider "========== CONTROL =========="
add wave -label "clk (50MHz)"   /tb_demo/clk
add wave -label "rst_n"         /tb_demo/rst_n
add wave -label "valid_in"      /tb_demo/valid_in
add wave -label "valid_out"     /tb_demo/valid_out

# --- Audio Data (Analog Waveform Display) ---
add wave -divider "========== AUDIO DATA (ANALOG) =========="
add wave -label "INPUT: audio_in_l" \
    -format Analog-Step -height 80 -min -4194304 -max 4194304 \
    -color "#2196F3" \
    /tb_demo/audio_in_l

add wave -label "OUTPUT: audio_out_l" \
    -format Analog-Step -height 80 -min -4194304 -max 4194304 \
    -color "#F44336" \
    /tb_demo/audio_out_l

# --- Hex/Decimal view of same data ---
add wave -divider "========== AUDIO DATA (HEX) =========="
add wave -label "audio_in_l (hex)"  -radix hexadecimal /tb_demo/audio_in_l
add wave -label "audio_out_l (hex)" -radix hexadecimal /tb_demo/audio_out_l

# --- CORDIC Phase ---
add wave -divider "========== CORDIC PHASE =========="
add wave -label "phase_step" -radix hexadecimal /tb_demo/phase_step
add wave -label "current_phase" \
    -format Analog-Step -height 60 \
    -color "#4CAF50" \
    /tb_demo/u_dsp/current_phase

# --- DC Remover Output ---
add wave -divider "========== DC REMOVER =========="
add wave -label "dc_clean_l" \
    -format Analog-Step -height 60 \
    -color "#9C27B0" \
    /tb_demo/u_dsp/dc_clean_l

# 6. Chay mo phong
run -all

# 7. Zoom vua cua so
wave zoomfull

# 8. Thong bao hoan thanh
echo ""
echo "=============================================="
echo "  WAVE DISPLAY READY!"
echo "  Zoom vao doan giua de xem chi tiet song."
echo "  Buoc tiep: python plot_demo.py plot"
echo "=============================================="
