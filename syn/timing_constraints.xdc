# Vivado Timing Constraints File (.xdc)
# ----------------------------------------------------

# Define Clocks
# 50 MHz System Clock (20 ns)
create_clock -period 20.000 -name sys_clk [get_ports sys_clk]

# 3.072 MHz Audio I2S BCLK (48 kHz * 2 channels * 32 bits = 325.52 ns)
create_clock -period 325.520 -name i2s_bclk [get_ports bclk]

# ----------------------------------------------------
# Clock Domain Crossing (CDC) Rules
# Declare that the sys_clk and i2s_bclk domains are completely asynchronous.
# Vivado will not attempt to optimize paths crossing these boundaries.
# (The async_fifo module handles this safely with Gray codes).
set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks i2s_bclk]

# ----------------------------------------------------
# Pin Assignments (Example mappings, replace with actual board pins)
# set_property PACKAGE_PIN E3 [get_ports sys_clk]
# set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]

# set_property PACKAGE_PIN C2 [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
