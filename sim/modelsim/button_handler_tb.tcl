# Open (manually) modelsim from workspace with simulations

# --------------------------------------------------------------------------
# Create project folder, project and add sources
# --------------------------------------------------------------------------

if {[file exist button_handler_tb]} {
    if {[file isdirectory button_handler_tb]} {
        file delete -force button_handler_tb
    }
}
file mkdir button_handler_tb
cd ./button_handler_tb

# Create project
project new ./ button_handler_tb work ../modelsim_vhdl2008.ini
project open button_handler_tb

# Add source files
set sim_list [glob -directory "../../../sim/tb/" -- "*.vhd"]
foreach file $sim_list {
	project addfile $file
}
set sources_list [glob -directory "../../../src/" -- "*.vhd"]
foreach file $sources_list {
	project addfile $file
}

# --------------------------------------------------------------------------
# Compile
# --------------------------------------------------------------------------

project calculateorder
#project compileorder
set compcmd [project compileall -n]
# project compileall

# --------------------------------------------------------------------------
# Simulate
# --------------------------------------------------------------------------

vsim work.button_handler_tb -do "
	add wave -position end  sim:/button_handler_tb/button_handler_inst/clk_i
	add wave -position end  sim:/button_handler_tb/button_handler_inst/rst_i
	add wave -position end  sim:/button_handler_tb/button_handler_inst/buttons_raw_i(0)
    add wave -position end  sim:/button_handler_tb/button_handler_inst/buttons_sync_s(0)
    add wave -position end  sim:/button_handler_tb/button_handler_inst/buttons_sync_last_s(0)
    add wave -position end  sim:/button_handler_tb/button_handler_inst/counter_pressed_s(0)
	add wave -position end  sim:/button_handler_tb/button_handler_inst/released_s(0)
	add wave -position end  sim:/button_handler_tb/button_handler_inst/event_read_i(0)
    add wave -position end  sim:/button_handler_tb/button_handler_inst/buttons_evnts_o(0)
	
	run 400 ms
"
