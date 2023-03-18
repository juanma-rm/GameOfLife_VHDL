#################################################################################
# PHYSICAL CONSTRAINTS
#################################################################################

# MAX7219 (PMODs)
set_property PACKAGE_PIN H12 [get_ports max7219_clk_o] ;# PMOD pin 1 - som240_1_a17
set_property PACKAGE_PIN B10 [get_ports max7219_din_o] ;# PMOD pin 2 - som240_1_b20
set_property PACKAGE_PIN E10 [get_ports max7219_csn_o] ;# PMOD pin 3 - som240_1_d20
set_property IOSTANDARD LVCMOS33 [get_ports max7219_*]
set_property SLEW SLOW [get_ports max7219_*]
set_property DRIVE 12 [get_ports max7219_*]

# Buttons (PMODs)
set_property PACKAGE_PIN E12 [get_ports {buttons_i[0]}] ;# PMOD pin 4 - som240_1_b21
set_property PACKAGE_PIN D10 [get_ports {buttons_i[1]}] ;# PMOD pin 5 - som240_1_d21
set_property PACKAGE_PIN D11 [get_ports {buttons_i[2]}] ;# PMOD pin 6 - som240_1_b22
set_property PACKAGE_PIN C11 [get_ports {buttons_i[3]}] ;# PMOD pin 7 - som240_1_d22
set_property PACKAGE_PIN B11 [get_ports {buttons_i[4]}] ;# PMOD pin 8 - som240_1_c22
set_property IOSTANDARD LVCMOS33 [get_ports buttons_i*]
set_property SLEW SLOW [get_ports buttons_i*]
set_property DRIVE 12 [get_ports buttons_i*]

#################################################################################
# TIMING CONSTRAINTS
#################################################################################

# Max7219 (@todo max7219 constraints to be taken from datasheet)
set_false_path -to [get_ports max7219_*]
#set_output_delay -clock [get_clocks clk_pl1] -max 25.000 [get_ports max7219_csn_o]
#create_generated_clock -name max7219_clk_o -source [get_pins bd_top_i/max7219_clk_o] -multiply_by 1 -add -master_clock [get_clocks clk_pl_1] [get_pins bd_top_i/max7219_clk_o]
#set_max_delay -from [get_clocks max7219_clk_o] -rise_to [get_ports max7219_csn_o] 25.000
#set_max_delay -from [get_clocks max7219_clk_o] -rise_to [get_ports max7219_din_o] 25.000

# Buttons (double stage sync)
set_false_path -from [get_ports buttons_i*]


