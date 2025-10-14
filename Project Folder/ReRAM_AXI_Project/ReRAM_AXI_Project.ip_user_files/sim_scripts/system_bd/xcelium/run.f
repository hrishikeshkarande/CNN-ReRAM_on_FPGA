-makelib xcelium_lib/xilinx_vip -sv \
  "C:/Xilinx/Vivado/2018.1/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
  "C:/Xilinx/Vivado/2018.1/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
  "C:/Xilinx/Vivado/2018.1/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
  "C:/Xilinx/Vivado/2018.1/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
  "C:/Xilinx/Vivado/2018.1/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
  "C:/Xilinx/Vivado/2018.1/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
  "C:/Xilinx/Vivado/2018.1/data/xilinx_vip/hdl/axi_vip_if.sv" \
  "C:/Xilinx/Vivado/2018.1/data/xilinx_vip/hdl/clk_vip_if.sv" \
  "C:/Xilinx/Vivado/2018.1/data/xilinx_vip/hdl/rst_vip_if.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "C:/Xilinx/Vivado/2018.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
  "C:/Xilinx/Vivado/2018.1/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
  "C:/Xilinx/Vivado/2018.1/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
-endlib
-makelib xcelium_lib/xpm \
  "C:/Xilinx/Vivado/2018.1/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib xcelium_lib/lib_cdc_v1_0_2 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/ef1e/hdl/lib_cdc_v1_0_rfs.vhd" \
-endlib
-makelib xcelium_lib/proc_sys_reset_v5_0_12 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/f86a/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/system_bd/ip/system_bd_rst_ps7_0_50M_1/sim/system_bd_rst_ps7_0_50M_1.vhd" \
-endlib
-makelib xcelium_lib/axi_infrastructure_v1_1_0 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/smartconnect_v1_0 -sv \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/02c8/hdl/sc_util_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/axi_protocol_checker_v2_0_2 -sv \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/3755/hdl/axi_protocol_checker_v2_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/axi_vip_v1_1_2 -sv \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/725c/hdl/axi_vip_v1_1_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/processing_system7_vip_v1_0_4 -sv \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/b193/hdl/processing_system7_vip_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/system_bd/ip/system_bd_processing_system7_0_2/sim/system_bd_processing_system7_0_2.v" \
  "../../../bd/system_bd/ip/system_bd_ila_0_0/sim/system_bd_ila_0_0.v" \
  "../../../bd/system_bd/ip/system_bd_ila_1_0/sim/system_bd_ila_1_0.v" \
-endlib
-makelib xcelium_lib/blk_mem_gen_v8_3_6 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/2751/simulation/blk_mem_gen_v8_3.v" \
-endlib
-makelib xcelium_lib/axi_bram_ctrl_v4_0_14 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/6db1/hdl/axi_bram_ctrl_v4_0_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/system_bd/ip/system_bd_axi_bram_ctrl_0_0/sim/system_bd_axi_bram_ctrl_0_0.vhd" \
-endlib
-makelib xcelium_lib/blk_mem_gen_v8_4_1 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/67d8/simulation/blk_mem_gen_v8_4.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/system_bd/ip/system_bd_axi_bram_ctrl_0_bram_1/sim/system_bd_axi_bram_ctrl_0_bram_1.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "../../../bd/system_bd/ipshared/984e/hdl/reram_axi_ip_v1_0_S00_AXI.v" \
  "../../../bd/system_bd/ipshared/984e/hdl/reram_axi_ip_v1_0.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/system_bd/ip/system_bd_reram_axi_ip_0_0/sim/system_bd_reram_axi_ip_0_0.v" \
-endlib
-makelib xcelium_lib/generic_baseblocks_v2_1_0 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/b752/hdl/generic_baseblocks_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/axi_register_slice_v2_1_16 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/0cde/hdl/axi_register_slice_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/fifo_generator_v13_2_2 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/7aff/simulation/fifo_generator_vlog_beh.v" \
-endlib
-makelib xcelium_lib/fifo_generator_v13_2_2 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/7aff/hdl/fifo_generator_v13_2_rfs.vhd" \
-endlib
-makelib xcelium_lib/fifo_generator_v13_2_2 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/7aff/hdl/fifo_generator_v13_2_rfs.v" \
-endlib
-makelib xcelium_lib/axi_data_fifo_v2_1_15 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/d114/hdl/axi_data_fifo_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/axi_crossbar_v2_1_17 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/d293/hdl/axi_crossbar_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/system_bd/ip/system_bd_xbar_0/sim/system_bd_xbar_0.v" \
-endlib
-makelib xcelium_lib/axi_protocol_converter_v2_1_16 \
  "../../../../ReRAM_AXI_Project.srcs/sources_1/bd/system_bd/ipshared/1229/hdl/axi_protocol_converter_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/system_bd/ip/system_bd_auto_pc_0/sim/system_bd_auto_pc_0.v" \
  "../../../bd/system_bd/ip/system_bd_auto_pc_1/sim/system_bd_auto_pc_1.v" \
  "../../../bd/system_bd/sim/system_bd.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  glbl.v
-endlib

