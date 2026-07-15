if {[file exists work]} {
    vdel -lib work -all
}
vlib work

vlog ../rtl/dc_remover.v
vlog ../rtl/cordic_core.v
vlog tb_bug_regression.v

vsim -c work.tb_bug_regression
run -all
