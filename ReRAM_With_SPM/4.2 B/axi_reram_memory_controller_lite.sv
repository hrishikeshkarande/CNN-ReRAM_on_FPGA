`timescale 1 ns / 1 ps

module axi_reram_memory_controller_lite #(
    // ===== ReRAM memory parameters =====
    parameter int MEMORY_DEPTH       = 16,
    parameter int DATA_WIDTH         = 32,
    parameter int ADDR_WIDTH         = $clog2(MEMORY_DEPTH),
    parameter int READ_DELAY_CYCLES  = 3,
    parameter int SET_DELAY_CYCLES   = 10,
    parameter int RESET_DELAY_CYCLES = 10,
    parameter int MAX_WRITE_CYCLES   = 200,

    // ===== AXI4-Lite parameters (fixed for Zynq GP ports) =====
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 32
)(
    // AXI4-Lite slave I/F
    input  wire                          S_AXI_ACLK,
    input  wire                          S_AXI_ARESETN,

    // Write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [2:0]                    S_AXI_AWPROT,
    input  wire                          S_AXI_AWVALID,
    output wire                          S_AXI_AWREADY,

    // Write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                          S_AXI_WVALID,
    output wire                          S_AXI_WREADY,

    // Write response channel
    output wire [1:0]                    S_AXI_BRESP,
    output wire                          S_AXI_BVALID,
    input  wire                          S_AXI_BREADY,

    // Read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [2:0]                    S_AXI_ARPROT,
    input  wire                          S_AXI_ARVALID,
    output wire                          S_AXI_ARREADY,

    // Read data channel
    output wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [1:0]                    S_AXI_RRESP,
    output wire                          S_AXI_RVALID,
    input  wire                          S_AXI_RREADY
);

    // ---------------------------------------------
    // Local constants
    // ---------------------------------------------
    localparam int ADDR_LSB = $clog2(C_S_AXI_DATA_WIDTH/8); // 2 for 32-bit data
    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    // ---------------------------------------------
    // Internal ReRAM controller instance and signals
    // ---------------------------------------------
    wire                         clk   = S_AXI_ACLK;
    wire                         rst_n = S_AXI_ARESETN;

    // Controller I/F
    logic [ADDR_WIDTH-1:0]       mc_addr;
    logic [DATA_WIDTH-1:0]       mc_wdata;
    logic [DATA_WIDTH-1:0]       mc_rdata;
    logic                        mc_read_i;
    logic                        mc_write_i;
    logic                        mc_done_o;
    logic                        mc_error_o;
    logic                        mc_busy_o;

    // Optional monitoring (unused externally here, but wired for debug/ILA)
    logic [31:0]                 mc_total_reads, mc_total_writes;
    logic [MEMORY_DEPTH-1:0]     mc_word_errors;
    logic [7:0]                  mc_word_write_cycles [MEMORY_DEPTH-1:0];
    logic [MEMORY_DEPTH-1:0]     mc_word_cell_errors_any;
    logic [DATA_WIDTH-1:0]       mc_word_cell_errors [MEMORY_DEPTH-1:0];

    // Instantiate your blocking memory controller
    reram_memory_controller_blocking #(
        .MEMORY_DEPTH       (MEMORY_DEPTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .ADDR_WIDTH         (ADDR_WIDTH),
        .READ_DELAY_CYCLES  (READ_DELAY_CYCLES),
        .SET_DELAY_CYCLES   (SET_DELAY_CYCLES),
        .RESET_DELAY_CYCLES (RESET_DELAY_CYCLES),
        .MAX_WRITE_CYCLES   (MAX_WRITE_CYCLES)
    ) u_mc (
        .clk                     (clk),
        .rst_n                   (rst_n),

        .addr_i                  (mc_addr),
        .data_i                  (mc_wdata),
        .data_o                  (mc_rdata),
        .read_i                  (mc_read_i),
        .write_i                 (mc_write_i),
        .done_o                  (mc_done_o),
        .error_o                 (mc_error_o),
        .busy_o                  (mc_busy_o),

        .total_reads             (mc_total_reads),
        .total_writes            (mc_total_writes),
        .word_errors             (mc_word_errors),
        .word_write_cycles       (mc_word_write_cycles),
        .word_cell_errors_any    (mc_word_cell_errors_any),
        .word_cell_errors        (mc_word_cell_errors)
    );

    // ---------------------------------------------
    // AXI-lite transaction handling
    // Single-op at a time; stall while MC busy.
    // ---------------------------------------------

    // Latches for incoming requests
    logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr_latched;
    logic                          aw_hs, w_hs, ar_hs;

    // Ready signals (combinational)
    // We only accept a new transaction when we are IDLE and the controller is not in the middle of another op.
    // Also, for writes we require both AW and W to be accepted; we implement ready gating accordingly.
    logic axi_awready, axi_wready, axi_arready;

    // Response/data channel regs
    logic [1:0]                  axi_bresp;
    logic                        axi_bvalid;
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    logic [1:0]                  axi_rresp;
    logic                        axi_rvalid;

    // Assign AXI outputs
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;

    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // Handshake helpers
    assign aw_hs = S_AXI_AWVALID & axi_awready;
    assign w_hs  = S_AXI_WVALID  & axi_wready;
    assign ar_hs = S_AXI_ARVALID & axi_arready;

    // ---------------------------------------------
    // Simple arb + state machine
    // ---------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE        = 3'd0,
        S_W_WAIT_DATA = 3'd1,  // got AW, wait W
        S_W_START     = 3'd2,
        S_W_WAIT_DONE = 3'd3,
        S_W_RESP      = 3'd4,
        S_R_START     = 3'd5,
        S_R_WAIT_DONE = 3'd6,
        S_R_RESP      = 3'd7
    } axi_state_e;

    axi_state_e state, nstate;

    // Latches for write path
    logic [C_S_AXI_ADDR_WIDTH-1:0] waddr;
    logic [C_S_AXI_DATA_WIDTH-1:0] wdata;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb;
    // Latch for read path
    logic [C_S_AXI_ADDR_WIDTH-1:0] raddr;

    // Derived word index & validity
    logic [ADDR_WIDTH-1:0] word_index_w;
    logic [ADDR_WIDTH-1:0] word_index_r;
    logic                   addr_ok_w;
    logic                   addr_ok_r;

    // Decode helpers (aligned 32-bit accesses only)
    assign word_index_w = waddr[ADDR_LSB + ADDR_WIDTH - 1 : ADDR_LSB];
    assign word_index_r = raddr[ADDR_LSB + ADDR_WIDTH - 1 : ADDR_LSB];
    assign addr_ok_w    = (word_index_w < MEMORY_DEPTH);
    assign addr_ok_r    = (word_index_r < MEMORY_DEPTH);

    // Default controller inputs
    always_comb begin
        mc_addr    = '0;
        mc_wdata   = '0;
        mc_read_i  = 1'b0;
        mc_write_i = 1'b0;

        // Drive from current state
        case (state)
            S_W_START: begin
                mc_addr    = word_index_w;
                mc_wdata   = wdata;
                mc_write_i = 1'b1;  // pulse for one cycle
            end
            S_W_WAIT_DONE: begin
                mc_addr    = word_index_w; // keep stable (not necessary but clean)
                mc_wdata   = wdata;
            end
            S_R_START: begin
                mc_addr    = word_index_r;
                mc_read_i  = 1'b1;  // pulse for one cycle
            end
            S_R_WAIT_DONE: begin
                mc_addr    = word_index_r;
            end
            default: begin end
        endcase
    end

    // Ready/valid defaults
    always_comb begin
        // Defaults
        axi_awready = 1'b0;
        axi_wready  = 1'b0;
        axi_arready = 1'b0;

        // Accept one transaction at a time when idle (and controller not busy)
        case (state)
            S_IDLE: begin
                // Prioritize reads vs writes? Choose fair approach: accept whatever comes, but if both valid, prefer write AW then gather W next cycle.
                // Accept AW if W not yet and controller free
                if (!mc_busy_o) begin
                    axi_awready = S_AXI_AWVALID; // ready when presented
                    axi_wready  = (S_AXI_WVALID && S_AXI_AWVALID) ? 1'b1 : 1'b0; // accept together if both
                    axi_arready = (!S_AXI_AWVALID) ? S_AXI_ARVALID : 1'b0; // if AW present, focus on write first
                end
            end
            S_W_WAIT_DATA: begin
                axi_wready = S_AXI_WVALID; // wait for W
            end
            default: begin
                // No new addresses accepted until current op completes
            end
        endcase
    end

    // Next-state logic
    always_comb begin
        nstate = state;

        case (state)
            S_IDLE: begin
                if (aw_hs && w_hs) begin
                    nstate = S_W_START;
                end else if (aw_hs && !w_hs) begin
                    nstate = S_W_WAIT_DATA;
                end else if (ar_hs) begin
                    nstate = S_R_START;
                end
            end

            S_W_WAIT_DATA: begin
                if (w_hs) nstate = S_W_START;
            end

            S_W_START: begin
                nstate = S_W_WAIT_DONE; // issue write pulse one cycle
            end
            S_W_WAIT_DONE: begin
                // If address invalid or WSTRB bad, we don't start MC; we jump to RESP with error (handled in seq logic)
                // Otherwise, wait mc_done_o
                if (mc_done_o || !addr_ok_w || (wstrb != {C_S_AXI_DATA_WIDTH/8{1'b1}})) begin
                    nstate = S_W_RESP;
                end
            end
            S_W_RESP: begin
                if (S_AXI_BREADY && axi_bvalid) nstate = S_IDLE;
            end

            S_R_START: begin
                nstate = S_R_WAIT_DONE; // issue read pulse one cycle
            end
            S_R_WAIT_DONE: begin
                if (mc_done_o || !addr_ok_r) begin
                    nstate = S_R_RESP;
                end
            end
            S_R_RESP: begin
                if (S_AXI_RREADY && axi_rvalid) nstate = S_IDLE;
            end

            default: nstate = S_IDLE;
        endcase
    end

    // Sequential: latching, responses, and data path
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;

            waddr       <= '0;
            wdata       <= '0;
            wstrb       <= '0;
            raddr       <= '0;

            axi_bvalid  <= 1'b0;
            axi_bresp   <= RESP_OKAY;

            axi_rvalid  <= 1'b0;
            axi_rresp   <= RESP_OKAY;
            axi_rdata   <= '0;
        end else begin
            state <= nstate;

            // Capture incoming addresses/data on handshake
            if (aw_hs) waddr <= S_AXI_AWADDR;
            if (w_hs)  begin
                wdata <= S_AXI_WDATA;
                wstrb <= S_AXI_WSTRB;
            end
            if (ar_hs) raddr <= S_AXI_ARADDR;

            // Default: deassert valid when accepted
            if (axi_bvalid && S_AXI_BREADY) axi_bvalid <= 1'b0;
            if (axi_rvalid && S_AXI_RREADY) axi_rvalid <= 1'b0;

            case (state)
                S_W_START: begin
                    // fire write_i this cycle (combinational) and wait in next state
                end
                S_W_WAIT_DONE: begin
                    // If invalid addr or bad WSTRB, skip MC result and return SLVERR
                    if (!addr_ok_w) begin
                        axi_bresp  <= RESP_SLVERR;
                        axi_bvalid <= 1'b1;
                    end else if (wstrb != {C_S_AXI_DATA_WIDTH/8{1'b1}}) begin
                        axi_bresp  <= RESP_SLVERR;
                        axi_bvalid <= 1'b1;
                    end else if (mc_done_o) begin
                        axi_bresp  <= mc_error_o ? RESP_SLVERR : RESP_OKAY;
                        axi_bvalid <= 1'b1;
                    end
                end

                S_R_START: begin
                    // fire read_i this cycle (combinational)
                end
                S_R_WAIT_DONE: begin
                    if (!addr_ok_r) begin
                        axi_rresp <= RESP_SLVERR;
                        axi_rdata <= '0;
                        axi_rvalid<= 1'b1;
                    end else if (mc_done_o) begin
                        axi_rresp <= mc_error_o ? RESP_SLVERR : RESP_OKAY;
                        axi_rdata <= mc_rdata;
                        axi_rvalid<= 1'b1;
                    end
                end

                default: begin end
            endcase
        end
    end

endmodule
