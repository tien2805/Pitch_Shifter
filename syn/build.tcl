# ==============================================================
#  Vivado Build Script (Tcl) - FPGA Pitch Shifter
# ==============================================================
# Usage: vivado -mode batch -source build.tcl

# 1. Create Project
create_project pitch_shifter ./vivado_project -part xc7a35tcpg236-1 -force

# 2. Add RTL Sources
add_files ../rtl/async_fifo.v
add_files ../rtl/cordic_core.v
add_files ../rtl/dc_remover.v
add_files ../rtl/i2s_rx.v
add_files ../rtl/i2s_tx.v
add_files ../rtl/phase_accumulator.v
add_files ../rtl/pitch_shift_ctrl.v
add_files ../rtl/pitch_shifter_top.v

# 3. Set Top Module
set_property top pitch_shifter_top [current_fileset]
update_compile_order -fileset sources_1

# 4. Add Constraints
add_files -fileset constrs_1 -norecurse timing_constraints.xdc

# 5. Run Synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 6. Report Utilization & Timing
open_run synth_1 -name synth_1
report_utilization -file utilization_report.txt
report_timing_summary -file timing_report.txt

puts "Synthesis completed successfully!"
