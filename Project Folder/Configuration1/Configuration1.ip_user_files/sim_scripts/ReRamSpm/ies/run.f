-makelib ies_lib/xilinx_vip -sv \
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
-makelib ies_lib/xil_defaultlib -sv \
  "C:/Xilinx/Vivado/2018.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
  "C:/Xilinx/Vivado/2018.1/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
  "C:/Xilinx/Vivado/2018.1/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
-endlib
-makelib ies_lib/xpm \
  "C:/Xilinx/Vivado/2018.1/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib ies_lib/axi_infrastructure_v1_1_0 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \
-endlib
-makelib ies_lib/smartconnect_v1_0 -sv \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/02c8/hdl/sc_util_v1_0_vl_rfs.sv" \
-endlib
-makelib ies_lib/axi_protocol_checker_v2_0_2 -sv \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/3755/hdl/axi_protocol_checker_v2_0_vl_rfs.sv" \
-endlib
-makelib ies_lib/axi_vip_v1_1_2 -sv \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/725c/hdl/axi_vip_v1_1_vl_rfs.sv" \
-endlib
-makelib ies_lib/processing_system7_vip_v1_0_4 -sv \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/b193/hdl/processing_system7_vip_v1_0_vl_rfs.sv" \
-endlib
-makelib ies_lib/xil_defaultlib \
  "../../../bd/ReRamSpm/ip/ReRamSpm_processing_system7_0_0/sim/ReRamSpm_processing_system7_0_0.v" \
-endlib
-makelib ies_lib/xil_defaultlib -sv \
  "../../../bd/ReRamSpm/ipshared/6975/sim/reram_cell_simple.sv" \
  "../../../bd/ReRamSpm/ipshared/6975/sim/tb_reram_cell_simple.sv" \
  "../../../bd/ReRamSpm/ipshared/6975/sim/reram_word_array_simple.sv" \
  "../../../bd/ReRamSpm/ipshared/6975/sim/tb_reram_word_array_simple.sv" \
  "../../../bd/ReRamSpm/ipshared/6975/sim/reram_memory_controller_blocking.sv" \
  "../../../bd/ReRamSpm/ipshared/6975/sim/tb_reram_memory_controller_blocking.sv" \
  "../../../bd/ReRamSpm/ipshared/6975/sim/reram_axilite_wrapper.sv" \
  "../../../bd/ReRamSpm/ipshared/6975/sim/tb_reram_axilite_wrapper.sv" \
  "../../../bd/ReRamSpm/ipshared/6975/src/reram_memory_controller_blocking.sv" \
  "../../../bd/ReRamSpm/ipshared/6975/src/reram_axilite_wrapper.sv" \
  "../../../bd/ReRamSpm/ip/ReRamSpm_reram_axilite_wrapper_0_0/sim/ReRamSpm_reram_axilite_wrapper_0_0.sv" \
-endlib
-makelib ies_lib/lib_cdc_v1_0_2 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/ef1e/hdl/lib_cdc_v1_0_rfs.vhd" \
-endlib
-makelib ies_lib/proc_sys_reset_v5_0_12 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/f86a/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \
-endlib
-makelib ies_lib/xil_defaultlib \
  "../../../bd/ReRamSpm/ip/ReRamSpm_rst_ps7_0_50M_0/sim/ReRamSpm_rst_ps7_0_50M_0.vhd" \
-endlib
-makelib ies_lib/generic_baseblocks_v2_1_0 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/b752/hdl/generic_baseblocks_v2_1_vl_rfs.v" \
-endlib
-makelib ies_lib/fifo_generator_v13_2_2 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/7aff/simulation/fifo_generator_vlog_beh.v" \
-endlib
-makelib ies_lib/fifo_generator_v13_2_2 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/7aff/hdl/fifo_generator_v13_2_rfs.vhd" \
-endlib
-makelib ies_lib/fifo_generator_v13_2_2 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/7aff/hdl/fifo_generator_v13_2_rfs.v" \
-endlib
-makelib ies_lib/axi_data_fifo_v2_1_15 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/d114/hdl/axi_data_fifo_v2_1_vl_rfs.v" \
-endlib
-makelib ies_lib/axi_register_slice_v2_1_16 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/0cde/hdl/axi_register_slice_v2_1_vl_rfs.v" \
-endlib
-makelib ies_lib/axi_protocol_converter_v2_1_16 \
  "../../../../Configuration1.srcs/sources_1/bd/ReRamSpm/ipshared/1229/hdl/axi_protocol_converter_v2_1_vl_rfs.v" \
-endlib
-makelib ies_lib/xil_defaultlib \
  "../../../bd/ReRamSpm/ip/ReRamSpm_auto_pc_0/sim/ReRamSpm_auto_pc_0.v" \
  "../../../bd/ReRamSpm/sim/ReRamSpm.v" \
-endlib
-makelib ies_lib/xil_defaultlib \
  glbl.v
-endlib

