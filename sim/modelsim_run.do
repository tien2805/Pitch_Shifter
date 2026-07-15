# ModelSim Run Script for Audio Loopback
# Run this inside the sim directory

# Create and map work library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile RTL and Testbench
vlog -work work ../rtl/i2s_rx.v
vlog -work work ../rtl/i2s_tx.v
vlog -work work ../rtl/async_fifo.v
vlog -work work tb_audio_loopback.v

# Start Simulation with full access for waveform viewing
vsim -voptargs="+acc" work.tb_audio_loopback

# Add waves
add wave -position insertpoint sim:/tb_audio_loopback/bclk
add wave -position insertpoint sim:/tb_audio_loopback/sys_clk
add wave -position insertpoint sim:/tb_audio_loopback/lrclk
add wave -position insertpoint sim:/tb_audio_loopback/sdata_in
add wave -position insertpoint sim:/tb_audio_loopback/sdata_out

add wave -divider "I2S RX"
add wave -position insertpoint sim:/tb_audio_loopback/rx_left_data
add wave -position insertpoint sim:/tb_audio_loopback/rx_right_data
add wave -position insertpoint sim:/tb_audio_loopback/rx_valid

add wave -divider "FIFO RX (BCLK -> SYS)"
add wave -position insertpoint sim:/tb_audio_loopback/u_fifo_rx/*

add wave -divider "FIFO TX (SYS -> BCLK)"
add wave -position insertpoint sim:/tb_audio_loopback/u_fifo_tx/*

# Run long enough for several 48 kHz I2S frames at 3.072 MHz BCLK
run 300 us

# Zoom full
wave zoom full
