# Project name and path; path to constraints

set PRJ_NAME GameOfLife
set WORKDIR [file dirname [info script]]
set PRJ_PATH $WORKDIR/projects
set SRC_PATH $WORKDIR/src
set XDC_PATH $WORKDIR/constraints/constraints.xdc

# Start GUI and create project based on k26 commercial + kv260 connectinos

start_gui
create_project $PRJ_NAME $PRJ_PATH/$PRJ_NAME -part xck26-sfvc784-2LV-c
set_property board_part xilinx.com:k26c:part0:1.3 [current_project]
set_property board_connections {som240_1_connector xilinx.com:kv260_carrier:som240_1_connector:1.3 som240_2_connector xilinx.com:kv260_carrier:som240_1_connector:1.3} [current_project]
set_property target_language VHDL [current_project]

# Main block design based on ZUS+ MPSoC + Reset

# Create block diagram top
create_bd_design "bd_top"
update_compile_order -fileset sources_1
# Zynq Ultrscale+ MPSoC block
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {0} CONFIG.PSU__USE__M_AXI_GP1 {0}] [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {1}] [get_bd_cells zynq_ultra_ps_e_0]
endgroup
# Reset block
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {Auto}}  [get_bd_pins proc_sys_reset_0/ext_reset_in]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/zynq_ultra_ps_e_0/pl_clk1 (1 MHz)} Freq {1} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}}  [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
endgroup

# Sources files: add to project, to bd and make connections

add_files -norecurse -scan_for_includes $SRC_PATH/game_of_life_top.vhd
add_files -norecurse -scan_for_includes $SRC_PATH/max7219_driver.vhd
add_files -norecurse -scan_for_includes $SRC_PATH/max7219_wrapper.vhd
add_files -norecurse -scan_for_includes $SRC_PATH/utils_pkg.vhd
add_files -norecurse -scan_for_includes $SRC_PATH/board_init.vhd
add_files -norecurse -scan_for_includes $SRC_PATH/button_handler.vhd
add_files -norecurse -scan_for_includes $SRC_PATH/cells.vhd

set_property FILE_TYPE {VHDL 2008} [get_files $SRC_PATH/max7219_driver.vhd]
set_property FILE_TYPE {VHDL 2008} [get_files $SRC_PATH/max7219_wrapper.vhd]
set_property FILE_TYPE {VHDL 2008} [get_files $SRC_PATH/utils_pkg.vhd]
set_property FILE_TYPE {VHDL 2008} [get_files $SRC_PATH/board_init.vhd]
set_property FILE_TYPE {VHDL 2008} [get_files $SRC_PATH/button_handler.vhd]
set_property FILE_TYPE {VHDL 2008} [get_files $SRC_PATH/cells.vhd]

update_compile_order -fileset sources_1

startgroup
create_bd_cell -type module -reference game_of_life_top game_of_life_top_0
create_bd_port -dir I -from 4 -to 0 buttons_i
create_bd_port -dir O max7219_clk_o
create_bd_port -dir O max7219_din_o
create_bd_port -dir O max7219_csn_o
connect_bd_net [get_bd_pins game_of_life_top_0/clk_i] [get_bd_pins zynq_ultra_ps_e_0/pl_clk1]
connect_bd_net [get_bd_pins game_of_life_top_0/rst_i] [get_bd_pins proc_sys_reset_0/peripheral_reset]
connect_bd_net [get_bd_ports buttons_i              ] [get_bd_pins game_of_life_top_0/buttons_i]
connect_bd_net [get_bd_ports max7219_clk_o          ] [get_bd_pins game_of_life_top_0/max7219_clk_o]
connect_bd_net [get_bd_ports max7219_din_o          ] [get_bd_pins game_of_life_top_0/max7219_din_o]
connect_bd_net [get_bd_ports max7219_csn_o          ] [get_bd_pins game_of_life_top_0/max7219_csn_o]
endgroup

# Constraints

add_files -fileset constrs_1 -norecurse $XDC_PATH
import_files -fileset constrs_1 $XDC_PATH

# Last steps

regenerate_bd_layout
update_compile_order -fileset sources_1
validate_bd_design
set_property top bd_top_wrapper [current_fileset]
make_wrapper -files [get_files $PRJ_PATH/$PRJ_NAME/$PRJ_NAME.srcs/sources_1/bd/bd_top/bd_top.bd] -top
add_files -norecurse $PRJ_PATH/$PRJ_NAME/$PRJ_NAME.gen/sources_1/bd/bd_top/hdl/bd_top_wrapper.vhd
generate_target all [get_files  $PRJ_PATH/$PRJ_NAME/$PRJ_NAME.srcs/sources_1/bd/bd_top/bd_top.bd]
catch { config_ip_cache -export [get_ips -all bd_top_zynq_ultra_ps_e_0_0] }
catch { config_ip_cache -export [get_ips -all bd_top_proc_sys_reset_0_0] }
catch { config_ip_cache -export [get_ips -all bd_top_c_counter_binary_0_0] }
catch { config_ip_cache -export [get_ips -all bd_top_system_ila_0_1] }
export_ip_user_files -of_objects [get_files $PRJ_PATH/$PRJ_NAME/$PRJ_NAME.srcs/sources_1/bd/bd_top/bd_top.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] $PRJ_PATH/$PRJ_NAME/$PRJ_NAME.srcs/sources_1/bd/bd_top/bd_top.bd]

# Manually: synthesis, implementation, bitstream generation and xsa generation

launch_runs impl_1 -to_step write_bitstream -jobs 14