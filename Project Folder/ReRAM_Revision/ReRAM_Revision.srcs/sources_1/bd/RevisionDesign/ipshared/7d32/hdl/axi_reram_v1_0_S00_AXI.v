`timescale 1 ns / 1 ps

module axi_reram_v1_0_S00_AXI #
(
    // ===== User parameters =====
    parameter int MEM_DEPTH              = 16,
    parameter int ADDR_WIDTH             = (MEM_DEPTH > 1) ? $clog2(MEM_DEPTH) : 1,

    // ===== AXI parameters (wizard) =====
    parameter int C_S_AXI_DATA_WIDTH     = 32,
    parameter int C_S_AXI_ADDR_WIDTH     = 4
)
(
    // ===== AXI4-Lite slave interface =====
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN, // Active LOW
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]   S_AXI_AWADDR,
    input  wire [2 : 0]                      S_AXI_AWPROT,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0]   S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    output wire [1 : 0]                      S_AXI_BRESP,
    output wire                              S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]   S_AXI_ARADDR,
    input  wire [2 : 0]                      S_AXI_ARPROT,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0]   S_AXI_RDATA,
    output wire [1 : 0]                      S_AXI_RRESP,
    output wire                              S_AXI_RVALID,
    input  wire                              S_AXI_RREADY,

    // ===== Pass-through ports to/from IP top (and core) =====
    output wire                              o_write_en_pulse,
    output wire                              o_target_state,
    output wire                              o_data_in,
    output wire [ADDR_WIDTH-1:0]             o_addr,

    input  wire                              i_busy,
    input  wire                              i_failed,
    input  wire                              i_read_data,
    input  wire                              i_data_out
);

    // -----------------------------
    // Local decode constants
    // -----------------------------
    // ADDR_LSB = 2 for 32-bit data (word-aligned)
    localparam int ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1; // 2
    // 2 bits ? 4 word locations (0x00, 0x04, 0x08, 0x0C)
    localparam int OPT_MEM_ADDR_BITS = 1;

    // -----------------------------
    // AXI regs/wires
    // -----------------------------
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_awaddr;
    reg                             axi_awready;
    reg                             axi_wready;
    reg [1 : 0]                     axi_bresp;
    reg                             axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_araddr;
    reg                             axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0]  axi_rdata;
    reg [1 : 0]                     axi_rresp;
    reg                             axi_rvalid;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // -----------------------------
    // Register space
    // -----------------------------
    // 0x00 CONTROL (W): [0]=start (self-clear), [1]=target_state, [2]=data_in
    // 0x04 ADDR    (W): [ADDR_WIDTH-1:0] address
    // 0x08 STATUS  (R): [0]=busy, [1]=failed, [2]=read_data, [3]=data_out (live)
    // 0x0C reserved
    reg  [C_S_AXI_DATA_WIDTH-1:0] slv_reg0; // CONTROL
    reg  [C_S_AXI_DATA_WIDTH-1:0] slv_reg1; // ADDR
    reg  [C_S_AXI_DATA_WIDTH-1:0] slv_reg2; // unused storage (STATUS is live)
    reg  [C_S_AXI_DATA_WIDTH-1:0] slv_reg3; // reserved

    wire                          slv_reg_wren;
    wire                          slv_reg_rden;
    reg  [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
    integer                       byte_index;
    reg                           aw_en;

    // -----------------------------
    // AXI write address handshake
    // -----------------------------
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            aw_en       <= 1'b1;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awready <= 1'b1;
                aw_en       <= 1'b0;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                aw_en       <= 1'b1;
                axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    // Latch AWADDR
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awaddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
            axi_awaddr <= S_AXI_AWADDR;
        end
    end

    // AXI write data handshake
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_wready <= 1'b0;
        end else begin
            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    // -----------------------------
    // Write logic
    // -----------------------------
    wire [1:0] wr_sel = axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS : ADDR_LSB];

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            slv_reg0 <= {C_S_AXI_DATA_WIDTH{1'b0}};
            slv_reg1 <= {C_S_AXI_DATA_WIDTH{1'b0}};
            slv_reg2 <= {C_S_AXI_DATA_WIDTH{1'b0}};
            slv_reg3 <= {C_S_AXI_DATA_WIDTH{1'b0}};
        end else if (slv_reg_wren) begin
            case (wr_sel)
                2'h0: begin
                    // CONTROL write
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                        if (S_AXI_WSTRB[byte_index])
                            slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                    // Self-clear START so SW always reads 0
                    slv_reg0[0] <= 1'b0;
                end
                2'h1: begin
                    // ADDR write
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                        if (S_AXI_WSTRB[byte_index])
                            slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
                2'h2: begin
                    // STATUS is read-only (live) - ignore writes
                end
                2'h3: begin
                    // reserved
                    for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                        if (S_AXI_WSTRB[byte_index])
                            slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
                default: ;
            endcase
        end
    end

    // -----------------------------
    // Write response
    // -----------------------------
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end else begin
            if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00; // OKAY
            end else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // -----------------------------
    // Read address handshake
    // -----------------------------
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    // -----------------------------
    // Read data channel
    // -----------------------------
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b00;
        end else begin
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00; // OKAY
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // -----------------------------
    // Pass-through control to top
    // -----------------------------
    // Decode a CONTROL write with START=1 to create a one-cycle pulse next cycle
    wire [1:0] rd_sel = axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS : ADDR_LSB];
    wire       is_ctrl_write = slv_reg_wren && (wr_sel == 2'h0);
    wire       start_bit_set = is_ctrl_write && S_AXI_WDATA[0];

    reg        write_en_pulse;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            write_en_pulse <= 1'b0;
        else
            write_en_pulse <= start_bit_set; // 1-cycle pulse
    end

    assign o_write_en_pulse = write_en_pulse;
    assign o_target_state   = slv_reg0[1];
    assign o_data_in        = slv_reg0[2];
    assign o_addr           = slv_reg1[ADDR_WIDTH-1:0];

    // -----------------------------
    // Live STATUS word from core
    // -----------------------------
    wire [31:0] status_word = { 28'd0,
                                i_data_out,   // bit3
                                i_read_data,  // bit2
                                i_failed,     // bit1
                                i_busy        // bit0
                              };

    // Read mux
    always @(*) begin
        case (rd_sel)
            2'h0: reg_data_out = slv_reg0;     // CONTROL (start reads as 0)
            2'h1: reg_data_out = slv_reg1;     // ADDR
            2'h2: reg_data_out = status_word;  // STATUS (live)
            2'h3: reg_data_out = slv_reg3;     // reserved
            default: reg_data_out = 32'd0;
        endcase
    end

    // Output read data
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axi_rdata <= 32'd0;
        else if (slv_reg_rden)
            axi_rdata <= reg_data_out;
    end

endmodule
