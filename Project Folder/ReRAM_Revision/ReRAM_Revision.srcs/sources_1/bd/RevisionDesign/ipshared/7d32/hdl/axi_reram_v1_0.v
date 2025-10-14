`timescale 1 ns / 1 ps

module axi_reram_v1_0 #(
    // ===== User params =====
    parameter int MEM_DEPTH        = 16,
    parameter int ADDR_WIDTH       = (MEM_DEPTH > 1) ? $clog2(MEM_DEPTH) : 1,

    // ===== AXI wizard params =====
    parameter int C_S00_AXI_DATA_WIDTH = 32,
    parameter int C_S00_AXI_ADDR_WIDTH = 4,

    // ===== BRAM Port-B address width (match BMG Port-B width in BD; e.g., 12 for 4KB) =====
    parameter int BRAM_ADDR_WIDTH  = 12
)(
    // ===== AXI4-Lite slave interface =====
    input  wire                             s00_axi_aclk,
    input  wire                             s00_axi_aresetn, // active-low
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]  s00_axi_awaddr,
    input  wire [2:0]                       s00_axi_awprot,
    input  wire                             s00_axi_awvalid,
    output wire                             s00_axi_awready,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0]  s00_axi_wdata,
    input  wire [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb,
    input  wire                             s00_axi_wvalid,
    output wire                             s00_axi_wready,
    output wire [1:0]                       s00_axi_bresp,
    output wire                             s00_axi_bvalid,
    input  wire                             s00_axi_bready,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]  s00_axi_araddr,
    input  wire [2:0]                       s00_axi_arprot,
    input  wire                             s00_axi_arvalid,
    output wire                             s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1:0]  s00_axi_rdata,
    output wire [1:0]                       s00_axi_rresp,
    output wire                             s00_axi_rvalid,
    input  wire                             s00_axi_rready,
    
    // ===== BRAM Port-B (native) to mirror the ReRAM states =====
    output wire                      bram_clkb,
    output wire                      bram_rstb,    // active-high
    output wire                      bram_enb,
    output wire [3:0]                bram_web,     // byte-enables
    output wire [BRAM_ADDR_WIDTH-1:0] bram_addrb,  // word address (zero-extended)
    output wire [31:0]               bram_dinb,
    input  wire [31:0]               bram_doutb    // (unused)
);

    // ----------------------------
    // Wires between S00_AXI and core
    // ----------------------------
    wire                      write_en_pulse;
    wire                      target_state;
    wire                      data_in_bit;
    wire [ADDR_WIDTH-1:0]     addr_field;

    wire                      core_busy;
    wire                      core_failed;
    wire                      core_read_data;
    wire                      core_data_out;

    // ----------------------------
    // AXI slave instance
    // ----------------------------
    axi_reram_v1_0_S00_AXI #(
        .MEM_DEPTH            (MEM_DEPTH),
        .ADDR_WIDTH           (ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH   (C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH   (C_S00_AXI_ADDR_WIDTH)
    ) S00_AXI_inst (
        // AXI ports
        .S_AXI_ACLK    (s00_axi_aclk),
        .S_AXI_ARESETN (s00_axi_aresetn),
        .S_AXI_AWADDR  (s00_axi_awaddr),
        .S_AXI_AWPROT  (s00_axi_awprot),
        .S_AXI_AWVALID (s00_axi_awvalid),
        .S_AXI_AWREADY (s00_axi_awready),
        .S_AXI_WDATA   (s00_axi_wdata),
        .S_AXI_WSTRB   (s00_axi_wstrb),
        .S_AXI_WVALID  (s00_axi_wvalid),
        .S_AXI_WREADY  (s00_axi_wready),
        .S_AXI_BRESP   (s00_axi_bresp),
        .S_AXI_BVALID  (s00_axi_bvalid),
        .S_AXI_BREADY  (s00_axi_bready),
        .S_AXI_ARADDR  (s00_axi_araddr),
        .S_AXI_ARPROT  (s00_axi_arprot),
        .S_AXI_ARVALID (s00_axi_arvalid),
        .S_AXI_ARREADY (s00_axi_arready),
        .S_AXI_RDATA   (s00_axi_rdata),
        .S_AXI_RRESP   (s00_axi_rresp),
        .S_AXI_RVALID  (s00_axi_rvalid),
        .S_AXI_RREADY  (s00_axi_rready),

        // === User ports (to/from core) ===
        .o_write_en_pulse (write_en_pulse),
        .o_target_state   (target_state),
        .o_data_in        (data_in_bit),
        .o_addr           (addr_field),

        .i_busy           (core_busy),
        .i_failed         (core_failed),
        .i_read_data      (core_read_data),
        .i_data_out       (core_data_out)
    );

    // ----------------------------
    // ReRAM core instance (exports cell-wide mirrors)
    // ----------------------------
    wire [MEM_DEPTH-1:0] cells_busy, cells_failed, cells_read, cells_data_out;

    reram_core #(
        .MEM_DEPTH  (MEM_DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_core (
        .clk          (s00_axi_aclk),
        .rst_n        (s00_axi_aresetn),   // active-low reset matches your RTL
        .write_en     (write_en_pulse),
        .addr         (addr_field),
        .target_state (target_state),
        .data_in      (data_in_bit),
        .read_data    (core_read_data),
        .data_out     (core_data_out),
        .busy         (core_busy),
        .failed       (core_failed),

        // Mirror buses (must exist in reram_core.sv)
        .cells_busy     (cells_busy),
        .cells_failed   (cells_failed),
        .cells_read     (cells_read),
        .cells_data_out (cells_data_out)
    );
    
    // ----------------------------
    // BRAM mirror writer (Port-B)
    // ----------------------------
    reg [ADDR_WIDTH-1:0] mirror_idx;
    always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
      if (!s00_axi_aresetn)
        mirror_idx <= {ADDR_WIDTH{1'b0}};
      else
        mirror_idx <= mirror_idx + 1'b1; // continuous sweep
    end
    
    // Pack one 32-bit status word per cell: [3:0] = {data_out, read, failed, busy}
    wire [31:0] mirror_word = {
      28'd0,
      cells_data_out[mirror_idx],
      cells_read     [mirror_idx],
      cells_failed   [mirror_idx],
      cells_busy     [mirror_idx]
    };
    
    // Drive BRAM Port-B
    assign bram_clkb  = s00_axi_aclk;
    assign bram_rstb  = ~s00_axi_aresetn;   // BMG expects active-high reset
    assign bram_enb   = 1'b1;               // always enabled
    assign bram_web   = 4'b1111;            // write full 32-bit word

    // Zero-extend 4-bit mirror_idx to the BRAM Port-B width
    assign bram_addrb = {{(BRAM_ADDR_WIDTH-ADDR_WIDTH){1'b0}}, mirror_idx};

    assign bram_dinb  = mirror_word;
    // bram_doutb unused

endmodule
