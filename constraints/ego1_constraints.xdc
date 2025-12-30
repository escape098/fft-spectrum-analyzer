
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports clk_100m]
create_clock -name clk_100m -period 10.000 [get_ports clk_100m]


   
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports reset_btn]


set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports pcm_sdata]

set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports pcm_mclk]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports pcm_bck]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports pcm_lrck]



set_property -dict { PACKAGE_PIN B4 IOSTANDARD LVCMOS33 } [get_ports {seg0_data[0]}]
set_property -dict { PACKAGE_PIN A4 IOSTANDARD LVCMOS33 } [get_ports {seg0_data[1]}]
set_property -dict { PACKAGE_PIN A3 IOSTANDARD LVCMOS33 } [get_ports {seg0_data[2]}]
set_property -dict { PACKAGE_PIN B1 IOSTANDARD LVCMOS33 } [get_ports {seg0_data[3]}]
set_property -dict { PACKAGE_PIN A1 IOSTANDARD LVCMOS33 } [get_ports {seg0_data[4]}]
set_property -dict { PACKAGE_PIN B3 IOSTANDARD LVCMOS33 } [get_ports {seg0_data[5]}]
set_property -dict { PACKAGE_PIN B2 IOSTANDARD LVCMOS33 } [get_ports {seg0_data[6]}]
set_property -dict { PACKAGE_PIN D5 IOSTANDARD LVCMOS33 } [get_ports {seg0_data[7]}]

set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports {seg1_data[0]}]
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {seg1_data[1]}]
set_property -dict { PACKAGE_PIN D3 IOSTANDARD LVCMOS33 } [get_ports {seg1_data[2]}]
set_property -dict { PACKAGE_PIN F4 IOSTANDARD LVCMOS33 } [get_ports {seg1_data[3]}]
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 } [get_ports {seg1_data[4]}]
set_property -dict { PACKAGE_PIN E2 IOSTANDARD LVCMOS33 } [get_ports {seg1_data[5]}]
set_property -dict { PACKAGE_PIN D2 IOSTANDARD LVCMOS33 } [get_ports {seg1_data[6]}]
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 } [get_ports {seg1_data[7]}]

set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports {seg_en[7]}]
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports {seg_en[6]}]
set_property -dict { PACKAGE_PIN C1 IOSTANDARD LVCMOS33 } [get_ports {seg_en[5]}]
set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 } [get_ports {seg_en[4]}]
set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 } [get_ports {seg_en[3]}]
set_property -dict { PACKAGE_PIN F1 IOSTANDARD LVCMOS33 } [get_ports {seg_en[2]}]
set_property -dict { PACKAGE_PIN E1 IOSTANDARD LVCMOS33 } [get_ports {seg_en[1]}]
set_property -dict { PACKAGE_PIN G6 IOSTANDARD LVCMOS33 } [get_ports {seg_en[0]}]



set_property -dict { PACKAGE_PIN F5 IOSTANDARD LVCMOS33 } [get_ports vga_r[0]]
set_property -dict { PACKAGE_PIN C6 IOSTANDARD LVCMOS33 } [get_ports vga_r[1]]
set_property -dict { PACKAGE_PIN C5 IOSTANDARD LVCMOS33 } [get_ports vga_r[2]]
set_property -dict { PACKAGE_PIN B7 IOSTANDARD LVCMOS33 } [get_ports vga_r[3]]

set_property -dict { PACKAGE_PIN B6 IOSTANDARD LVCMOS33 } [get_ports vga_g[0]]
set_property -dict { PACKAGE_PIN A6 IOSTANDARD LVCMOS33 } [get_ports vga_g[1]]
set_property -dict { PACKAGE_PIN A5 IOSTANDARD LVCMOS33 } [get_ports vga_g[2]]
set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS33 } [get_ports vga_g[3]]

set_property -dict { PACKAGE_PIN C7 IOSTANDARD LVCMOS33 } [get_ports vga_b[0]]
set_property -dict { PACKAGE_PIN E6 IOSTANDARD LVCMOS33 } [get_ports vga_b[1]]
set_property -dict { PACKAGE_PIN E5 IOSTANDARD LVCMOS33 } [get_ports vga_b[2]]
set_property -dict { PACKAGE_PIN E7 IOSTANDARD LVCMOS33 } [get_ports vga_b[3]]

set_property -dict { PACKAGE_PIN D7 IOSTANDARD LVCMOS33 } [get_ports hsync_n]
set_property -dict { PACKAGE_PIN C4 IOSTANDARD LVCMOS33 } [get_ports vsync_n]

set_property -dict { PACKAGE_PIN R11 IOSTANDARD LVCMOS33 } [get_ports key0]
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports key1]
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports key2]
set_property -dict { PACKAGE_PIN V1 IOSTANDARD LVCMOS33 } [get_ports key3]
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } [get_ports key4]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

