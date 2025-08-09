// reram_crossbar_emulation_v1_0.v
// This is the top-level AXI-Lite wrapper for your ReRAM IP.

`timescale 1 ns / 1 ps

module reram_crossbar_emulation_v1_0 #
(
    // Users to add parameters here
    parameter integer C_NUM_INPUTS    = 8,   // Number of input activations (vector size)
    parameter integer C_NUM_OUTPUTS   = 4,   // Number of output sums (matrix rows)
    parameter integer C_INPUT_WIDTH   = 8,   // Bit width of input activations
    parameter integer C_WEIGHT_WIDTH  = 8,   // Bit width of weights (from BRAMs)
    parameter integer C_ACC_WIDTH     = 16,  // Bit width for accumulation to avoid overflow
    // User parameters ends
    // Do not modify the parameters beyond this line

    // Parameters of Axi Slave Bus Interface S00_AXI
    parameter integer C_S00_AXI_DATA_WIDTH    = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH    = 4
)
(
    // Users to add ports here
    // Removed input_activations and weight_matrix from top-level ports
    output wire [C_ACC_WIDTH-1:0]  output_sums [C_NUM_OUTPUTS-1:0],      // Outputs from the crossbar

    // User ports ends
    // Do not modify the ports beyond this line

    // Ports of Axi Slave Bus Interface S00_AXI
    input wire  s00_axi_aclk,
    input wire  s00_axi_aresetn,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
    input wire [2 : 0] s00_axi_awprot,
    input wire  s00_axi_awvalid,
    output wire  s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    input wire  s00_axi_wvalid,
    output wire  s00_axi_wready,
    output wire [1 : 0] s00_axi_bresp,
    output wire  s00_axi_bvalid,
    input wire  s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
    input wire [2 : 0] s00_axi_arprot,
    input wire  s00_axi_arvalid,
    output wire  s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
    output wire [1 : 0] s00_axi_rresp,
    output wire  s00_axi_rvalid,
    input wire  s00_axi_rready
);

    // Internal signals for AXI-Lite module's internal registers (from write)
    wire [C_S00_AXI_DATA_WIDTH-1:0] slv_reg0_from_axi;
    wire [C_S00_AXI_DATA_WIDTH-1:0] slv_reg1_from_axi;
    wire [C_S00_AXI_DATA_WIDTH-1:0] slv_reg2_from_axi;
    wire [C_S00_AXI_DATA_WIDTH-1:0] slv_reg3_from_axi;

    // Internal signals for AXI-Lite module's internal registers (to read)
    reg [C_S00_AXI_DATA_WIDTH-1:0] slv_reg0_to_axi;
    reg [C_S00_AXI_DATA_WIDTH-1:0] slv_reg1_to_axi;
    reg [C_S00_AXI_DATA_WIDTH-1:0] slv_reg2_to_axi;
    reg [C_S00_AXI_DATA_WIDTH-1:0] slv_reg3_to_axi;

    // AXI-Lite control and status signals derived from AXI registers
    wire start_emulation_from_ps;
    reg  emulation_done_to_ps; // Needs to be a reg for assignment within always block

    // Connect AXI-Lite signals to internal logic
    assign start_emulation_from_ps = slv_reg0_from_axi[0]; // Example: Bit 0 of slv_reg0 is start signal

    // Update slv_reg1_to_axi with the status of your emulation
    always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
        if (!s00_axi_aresetn) begin
            emulation_done_to_ps <= 1'b0;
            slv_reg1_to_axi <= 0; // Clear read register on reset
        end else begin
            // Update based on your emulation logic's 'emulation_done'
            emulation_done_to_ps <= emulation_done_reg_internal; // Assign internal signal here
            slv_reg1_to_axi[0] <= emulation_done_to_ps; // Bit 0 of slv_reg1 indicates done
            // Other bits of slv_reg1_to_axi could convey more status/results if needed
        end
    end

    // Instantiation of Axi Bus Interface S00_AXI (provided by Vivado template)
    // This module handles the AXI4-Lite protocol and exposes slave registers.
    reram_crossbar_emulation_v1_0_S00_AXI # (
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) reram_crossbar_emulation_v1_0_S00_AXI_inst (
        .S_AXI_ACLK(s00_axi_aclk),
        .S_AXI_ARESETN(s00_axi_aresetn),
        .S_AXI_AWADDR(s00_axi_awaddr),
        .S_AXI_AWPROT(s00_axi_awprot),
        .S_AXI_AWVALID(s00_axi_awvalid),
        .S_AXI_AWREADY(s00_axi_awready),
        .S_AXI_WDATA(s00_axi_wdata),
        .S_AXI_WSTRB(s00_axi_wstrb),
        .S_AXI_WVALID(s00_axi_wvalid),
        .S_AXI_WREADY(s00_axi_wready),
        .S_AXI_BRESP(s00_axi_bresp),
        .S_AXI_BVALID(s00_axi_bvalid),
        .S_AXI_BREADY(s00_axi_bready),
        .S_AXI_ARADDR(s00_axi_araddr),
        .S_AXI_ARPROT(s00_axi_arprot),
        .S_AXI_ARVALID(s00_axi_arvalid),
        .S_AXI_ARREADY(s00_axi_arready),
        .S_AXI_RDATA(s00_axi_rdata),
        .S_AXI_RRESP(s00_axi_rresp),
        .S_AXI_RVALID(s00_axi_rvalid),
        .S_AXI_RREADY(s00_axi_rready),

        // Connect these internal signals directly to the AXI-Lite instance
        // These are typically outputs from the AXI-Lite sub-module
        .slv_reg0_in(slv_reg0_from_axi),
        .slv_reg1_in(slv_reg1_from_axi),
        .slv_reg2_in(slv_reg2_from_axi),
        .slv_reg3_in(slv_reg3_from_axi),

        // These are inputs to the AXI-Lite sub-module from the user logic
        .slv_reg0_out(slv_reg0_to_axi),
        .slv_reg1_out(slv_reg1_to_axi),
        .slv_reg2_out(slv_reg2_to_axi),
        .slv_reg3_out(slv_reg3_to_axi)
    );

    // Internal signal for the emulation done status
    wire emulation_done_reg_internal;

    // Note: The 'rst' for your conceptual module needs to be active high,
    //       while s00_axi_aresetn is active low.
    wire rst_active_high = ~s00_axi_aresetn;

    // Instantiate your conceptual reram_crossbar_emulation module here
    reram_crossbar_emulation #(
        .C_NUM_INPUTS    (C_NUM_INPUTS),
        .C_NUM_OUTPUTS   (C_NUM_OUTPUTS),
        .C_INPUT_WIDTH   (C_INPUT_WIDTH),
        .C_WEIGHT_WIDTH  (C_WEIGHT_WIDTH),
        .C_ACC_WIDTH     (C_ACC_WIDTH)
    ) reram_core_inst (
        .clk             (s00_axi_aclk),            // Use AXI clock for your logic
        .rst             (rst_active_high),         // Active high reset
        .start_emulation (start_emulation_from_ps), // Control via AXI-Lite register
        .emulation_done  (emulation_done_reg_internal), // Status from custom logic

        // Removed .input_activations and .weight_matrix from instantiation
        .output_sums     (output_sums)
    );

endmodule