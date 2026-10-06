# Standalone AXI-Lite-only KV260 project. No DMA, HP port or board programming.
if {$argc!=1} {error "Usage: build_pio.tcl OUTPUT_DIRECTORY"}
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file normalize [lindex $argv 0]]
set board [get_board_parts xilinx.com:kv260_som:part0:1.4]
if {[llength $board]!=1} {error "VERIFIED_KV260_PRESET_NOT_INSTALLED"}
set part [get_property PART_NAME $board]
create_project frodokem_pio $out -part $part
set_property board_part $board [current_project]
set_property target_language Verilog [current_project]
set_property include_dirs [list [file join $root rtl core]] [current_fileset]
set_property verilog_define FULL50_DISABLE_OLD_TRACE [current_fileset]
set headers [glob [file join $root rtl core *.v]]
add_files $headers
set_property file_type {Verilog Header} [get_files $headers]
add_files [glob [file join $root rtl matrix *.sv]]
add_files [glob [file join $root rtl helpers *.sv]]
foreach name {frodokem_word_fifo frodokem_axil_regs frodokem_axi_shell frodokem_pio_top} {
    add_files [file join $root rtl axi ${name}.sv]
}
add_files [file join $root rtl axi frodokem_pio_bd_bridge.v]
update_compile_order -fileset sources_1
create_bd_design system
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 ps]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} $ps
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__S_AXI_GP2 {0} CONFIG.PSU__USE__IRQ0 {0} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {55}] $ps
set ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 control]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $ctrl
set reset [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset]
set ip [create_bd_cell -type module -reference frodokem_pio_bd_bridge accelerator]
if {[llength [get_bd_intf_pins accelerator/s_axi]]!=1} {error "PIO_INTERFACE_INFERENCE_FAILED"}
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] [get_bd_intf_pins control/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins control/M00_AXI] [get_bd_intf_pins accelerator/s_axi]
connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins accelerator/clk] \
    [get_bd_pins control/aclk] [get_bd_pins reset/slowest_sync_clk] [get_bd_pins ps/maxihpm0_fpd_aclk]
connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins reset/ext_reset_in]
connect_bd_net [get_bd_pins reset/peripheral_aresetn] [get_bd_pins accelerator/aresetn] [get_bd_pins control/aresetn]
set one [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 clock_locked]
set_property CONFIG.CONST_VAL 1 $one
connect_bd_net [get_bd_pins clock_locked/dout] [get_bd_pins reset/dcm_locked]
assign_bd_address
set segment [get_bd_addr_segs -of_objects [get_bd_addr_spaces ps/Data] -filter {NAME =~ *accelerator*}]
if {[llength $segment]!=1} {error "PIO_ADDRESS_SEGMENT_NOT_UNIQUE"}
set_property offset 0xA0000000 $segment
validate_bd_design
save_bd_design
generate_target all [get_files system.bd]
add_files [make_wrapper -files [get_files system.bd] -top]
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1
write_bd_tcl [file join $out recreate_bd.tcl]
set manifest [open [file join $out PLATFORM_MANIFEST.txt] w]
puts $manifest "BOARD_PART=$board\nPART=$part\nTOOL=[version -short]\nTRANSPORT=AXI_LITE_PIO\nBASE=0xA0000000"
puts $manifest "REQUESTED_PL_CLOCK_MHZ=55\nACTUAL_PL_CLOCK_HZ=[get_property CONFIG.FREQ_HZ [get_bd_pins ps/pl_clk0]]"
close $manifest
set_param general.maxThreads 4
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match {*Complete*} [get_property STATUS [get_runs synth_1]]]} {error "PIO_SYNTH_FAILED"}
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {![string match {*Complete*} [get_property STATUS [get_runs impl_1]]]} {error "PIO_ROUTE_FAILED"}
open_run impl_1
report_utilization -hierarchical -file [file join $out utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing.rpt]
report_route_status -file [file join $out route_status.rpt]
report_drc -file [file join $out drc.rpt]
write_checkpoint -force [file join $out post_route.dcp]
foreach type {max min} {
    set paths [get_timing_paths -delay_type $type -max_paths 1]
    if {[llength $paths]!=1} {error "PIO_NO_TIMING_PATH_$type"}
    set slack [get_property SLACK [lindex $paths 0]]
    puts "PIO_TIMING_$type=$slack"
    if {$slack<0} {error "PIO_TIMING_FAILED_$type"}
}
foreach v [get_drc_violations] {
    if {[get_property SEVERITY $v] in {Error {Critical Warning}}} {error "PIO_DRC_FAILED_$v"}
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match {*Complete*} [get_property STATUS [get_runs impl_1]]]} {error "PIO_BITSTREAM_FAILED"}
open_run impl_1
write_hw_platform -fixed -include_bit -force -file [file join $out frodokem_pio_kv260.xsa]
puts "PIO_BOARD_ARTIFACTS_READY=$out"
