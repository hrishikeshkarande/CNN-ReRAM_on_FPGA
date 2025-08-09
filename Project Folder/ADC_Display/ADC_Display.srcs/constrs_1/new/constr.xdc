# Connect analog input (VP/VN from JXADC)
set_property PACKAGE_PIN N15 [get_ports vp_in]
set_property IOSTANDARD LVCMOS33 [get_ports vp_in]

set_property PACKAGE_PIN N16 [get_ports vn_in]
set_property IOSTANDARD LVCMOS33 [get_ports vn_in]

# Connect onboard LEDs (assuming LD0-LD3)
set_property PACKAGE_PIN M14 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]

set_property PACKAGE_PIN M15 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]

set_property PACKAGE_PIN G14 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[2]}]

set_property PACKAGE_PIN D18 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[3]}]

# Clock input (e.g., 125MHz on Zybo Z7)
set_property PACKAGE_PIN K17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];
