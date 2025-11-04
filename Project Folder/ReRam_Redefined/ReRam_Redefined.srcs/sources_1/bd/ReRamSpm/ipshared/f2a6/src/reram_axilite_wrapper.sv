// ============================================================================
// ReRAM AXI-Lite Wrapper (Vivado 2018.1 friendly)
//
// CORRECTIONS APPLIED:
// 1. Flattened 2D array ports from DUT to 1D vectors to fix 2018.1 parser bug.
// 2. Fixed "Multiple Driver" error by driving core_addr_i combinationally.
// 3. Fixed "Read Latch" bug by adding axi_rdata_reg.
// ============================================================================
module reram_axilite_wrapper #(
    // ReRAM core
    parameter integer MEMORY_DEPTH       = 16,
    parameter integer DATA_WIDTH         = 32,
    parameter integer CORE_ADDR_WIDTH    = $clog2(MEMORY_DEPTH),

    // AXI-Lite
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 10  // 1024B region
) (
    // AXI-Lite Global
    input  logic                          S_AXI_ACLK,
    input  logic                          S_AXI_ARESETN,

    // AXI-Lite Write Address
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  logic [2:0]                    S_AXI_AWPROT,
    input  logic                          S_AXI_AWVALID,
    output logic                          S_AXI_AWREADY,

    // AXI-Lite Write Data
    input  logic [C_S_AXI_DATA_WIDTH-1:0]   S_AXI_WDATA,
    input  logic [C_S_AXI_DATA_WIDTH/8-1:0] S_AXI_WSTRB,
    input  logic                            S_AXI_WVALID,
    output logic                            S_AXI_WREADY,

    // AXI-Lite Write Response
    output logic [1:0]                      S_AXI_BRESP,
    output logic                            S_AXI_BVALID,
    input  logic                            S_AXI_BREADY,

    // AXI-Lite Read Address
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  logic [2:0]                    S_AXI_ARPROT,
    input  logic                          S_AXI_ARVALID,
    output logic                          S_AXI_ARREADY,

    // AXI-Lite Read Data
    output logic [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output logic [1:0]                    S_AXI_RRESP,
    output logic                          S_AXI_RVALID,
    input  logic                          S_AXI_RREADY
);

    // ------------------------------------------------------------------------
    // Address map (byte addressing)
    // ------------------------------------------------------------------------
    localparam integer ADDR_MEM_BASE  = 10'h000;
    localparam integer ADDR_MEM_END   = ADDR_MEM_BASE + (MEMORY_DEPTH*4) - 1; // 0x03F

    localparam integer ADDR_REG_BASE        = 10'h100;
    localparam integer ADDR_TOTAL_READS     = ADDR_REG_BASE + 10'h00; // 0x100
    localparam integer ADDR_TOTAL_WRITES    = ADDR_REG_BASE + 10'h04; // 0x104
    localparam integer ADDR_WORD_ERRORS     = ADDR_REG_BASE + 10'h08; // 0x108
    localparam integer ADDR_CELL_ERRORS_ANY = ADDR_REG_BASE + 10'h0C; // 0x10C

    localparam integer ADDR_WRITE_CYCLES_BASE  = 10'h120;
    localparam integer ADDR_WRITE_CYCLES_0_3   = ADDR_WRITE_CYCLES_BASE + 10'h00; // 0x120
    localparam integer ADDR_WRITE_CYCLES_4_7   = ADDR_WRITE_CYCLES_BASE + 10'h04; // 0x124
    localparam integer ADDR_WRITE_CYCLES_8_11  = ADDR_WRITE_CYCLES_BASE + 10'h08; // 0x128
    localparam integer ADDR_WRITE_CYCLES_12_15 = ADDR_WRITE_CYCLES_BASE + 10'h0C; // 0x12C

    localparam integer ADDR_CELL_ERRORS_BASE = 10'h200;
    localparam integer ADDR_CELL_ERRORS_END  = ADDR_CELL_ERRORS_BASE + (MEMORY_DEPTH*4) - 1; // 0x23F

    // Pad widths for bitmaps (avoid negative replication counts)
    localparam integer WORD_BITMAP_PAD = (DATA_WIDTH > MEMORY_DEPTH) ? (DATA_WIDTH - MEMORY_DEPTH) : 0;

    // ------------------------------------------------------------------------
    // ReRAM Core Wires (flat monitoring ports)
    // ------------------------------------------------------------------------
    logic [CORE_ADDR_WIDTH-1:0] core_addr_i; // *** NOW A WIRE ***
    logic [DATA_WIDTH-1:0]      core_data_i;
    logic [DATA_WIDTH-1:0]      core_data_o;
    logic                       core_read_i;
    logic                       core_write_i;
    logic                       core_done_o;
    logic                       core_error_o;
    logic                       core_busy_o;
    logic [31:0]                core_total_reads;
    logic [31:0]                core_total_writes;
    logic [MEMORY_DEPTH-1:0]    core_word_errors;

    // Monitoring (flat from core)
    logic [MEMORY_DEPTH*8-1:0]          core_write_cycles_flat;    // 16*8 bits
    logic [MEMORY_DEPTH*DATA_WIDTH-1:0] core_cell_errors_flat;   // 16*32 bits
    logic [MEMORY_DEPTH-1:0]            core_word_cell_errors_any;

    // Unpacked (for easy muxing)
    logic [7:0]                 core_word_write_cycles [0:MEMORY_DEPTH-1];
    logic [DATA_WIDTH-1:0]      core_word_cell_errors [0:MEMORY_DEPTH-1];

    // Core instance (make sure these port names exist in your core!)
    reram_memory_controller_blocking #(
        .MEMORY_DEPTH       (MEMORY_DEPTH),
        .ADDR_WIDTH         (CORE_ADDR_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH)
    ) u_core (
        .clk                (S_AXI_ACLK),
        .rst_n              (S_AXI_ARESETN),

        .addr_i             (core_addr_i),
        .data_i             (core_data_i),
        .data_o             (core_data_o),
        .read_i             (core_read_i),
        .write_i            (core_write_i),
        .done_o             (core_done_o),
        .error_o            (core_error_o),
        .busy_o             (core_busy_o),
        .total_reads        (core_total_reads),
        .total_writes       (core_total_writes),
        .word_errors        (core_word_errors),

        // Monitoring (flat)
        .word_cell_errors_any (core_word_cell_errors_any),
        .word_write_cycles_flat(core_write_cycles_flat),
        .word_cell_errors_flat (core_cell_errors_flat)
    );

    // Unflatten monitoring buses (generate is SV, but Vivado 2018.1 is fine with this)
    genvar g;
    generate
        for (g = 0; g < MEMORY_DEPTH; g = g + 1) begin : G_UNFLAT
            assign core_word_write_cycles[g] = core_write_cycles_flat[ (g*8) +: 8 ];
            assign core_word_cell_errors[g]  = core_cell_errors_flat [ (g*DATA_WIDTH) +: DATA_WIDTH ];
        end
    endgenerate

    // ------------------------------------------------------------------------
    // AXI-lite plumbing
    // ------------------------------------------------------------------------
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr, axi_araddr;
    logic                          axi_awready, axi_wready, axi_bvalid;
    logic                          axi_arready, axi_rvalid;
    
    // *** FIX for Read Latch ***
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_rdata_reg;
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_rdata_mux_out;

    // State machines (use localparams for 2018.1 robustness)
    localparam [1:0] WR_IDLE=2'd0, WR_WAIT_CORE=2'd1, WR_RESP=2'd2;
    localparam [1:0] RD_IDLE=2'd0, RD_WAIT_CORE=2'd1, RD_RESP=2'd2;

    logic [1:0] wr_state, rd_state;

    // *** FIX for Multiple Driver ***
    logic [CORE_ADDR_WIDTH-1:0] write_addr_reg;
    logic [CORE_ADDR_WIDTH-1:0] read_addr_reg;
    
    assign core_addr_i = (wr_state != WR_IDLE) ? write_addr_reg : read_addr_reg;
    // -----------------------------

    // ------------------------------------------------------------------------
    // Write FSM
    // ------------------------------------------------------------------------
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            wr_state       <= WR_IDLE;
            axi_awready    <= 1'b0;
            axi_wready     <= 1'b0;
            axi_bvalid     <= 1'b0;
            core_write_i   <= 1'b0;
            // core_addr_i <= '0; // Removed, now combinational
            write_addr_reg <= '0; // *** NEW ***
            core_data_i    <= '0;
        end else begin
            // Default assignments
            axi_awready  <= 1'b0;
            axi_wready   <= 1'b0;
            axi_bvalid   <= 1'b0;
            core_write_i <= 1'b0;
            
            case (wr_state)
                WR_IDLE: begin
                    if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        axi_awready    <= 1'b1;
                        axi_wready     <= 1'b1;
                        axi_awaddr     <= S_AXI_AWADDR;
                        write_addr_reg <= S_AXI_AWADDR[CORE_ADDR_WIDTH+1 : 2]; // *** NEW ***
                        core_data_i    <= S_AXI_WDATA;
                        wr_state       <= WR_WAIT_CORE;
                        if ((S_AXI_AWADDR >= ADDR_MEM_BASE) && (S_AXI_AWADDR <= ADDR_MEM_END))
                            core_write_i <= 1'b1; // pulse
                    end
                end
                
                WR_WAIT_CORE: begin
                    if ((axi_awaddr >= ADDR_MEM_BASE) && (axi_awaddr <= ADDR_MEM_END)) begin
                        if (core_done_o) begin
                            axi_bvalid <= 1'b1;
                            wr_state   <= WR_RESP;
                        end
                    end else begin
                        axi_bvalid <= 1'b1;
                        wr_state   <= WR_RESP;
                    end
                end
                
                WR_RESP: begin
                    if (S_AXI_BREADY) begin
                        axi_bvalid <= 1'b0;
                        wr_state   <= WR_IDLE;
                    end
                end
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Read FSM
    // ------------------------------------------------------------------------
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            rd_state      <= RD_IDLE;
            axi_arready   <= 1'b0;
            axi_rvalid    <= 1'b0;
            core_read_i   <= 1'b0;
            read_addr_reg <= '0; // *** NEW ***
            axi_rdata_reg <= '0; // Latch fix
        end else begin
            // Default assignments
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            core_read_i <= 1'b0;

            case (rd_state)
                RD_IDLE: begin
                    if (S_AXI_ARVALID) begin
                        axi_arready <= 1'b1;
                        axi_araddr  <= S_AXI_ARADDR;
                        if ((S_AXI_ARADDR >= ADDR_MEM_BASE) && (S_AXI_ARADDR <= ADDR_MEM_END)) begin
                            core_read_i   <= 1'b1; // pulse
                            read_addr_reg <= S_AXI_ARADDR[CORE_ADDR_WIDTH+1 : 2]; // *** NEW ***
                            rd_state      <= RD_WAIT_CORE;
                        end else begin
                            rd_state      <= RD_RESP; // register read is immediate
                            axi_rvalid    <= 1'b1;
                            axi_rdata_reg <= axi_rdata_mux_out; // Latch mux data
                        end
                    end
                end
                
                RD_WAIT_CORE: begin
                    if (core_done_o) begin
                        axi_rvalid    <= 1'b1;
                        rd_state      <= RD_RESP;
                        axi_rdata_reg <= core_data_o; // Latch core data
                    end
                end
                
                RD_RESP: begin
                    if (S_AXI_RREADY) begin
                        axi_rvalid <= 1'b0;
                        rd_state   <= RD_IDLE;
                    end else begin
                        axi_rvalid <= 1'b1; // Hold valid
                    end
                end
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Read Data Mux (combinational, uses latched axi_araddr)
    // ------------------------------------------------------------------------
    always_comb begin
        axi_rdata_mux_out = '0; // Default
        
        // Mux is ONLY for register reads. Memory reads are latched in FSM.
        if ((axi_araddr >= ADDR_CELL_ERRORS_BASE) && (axi_araddr <= ADDR_CELL_ERRORS_END)) begin
            // one 32-bit register per word
            axi_rdata_mux_out = core_word_cell_errors[ axi_araddr[CORE_ADDR_WIDTH+1 : 2] ];
        end
        else begin
            unique case (axi_araddr)
                ADDR_TOTAL_READS:      axi_rdata_mux_out = core_total_reads;
                ADDR_TOTAL_WRITES:     axi_rdata_mux_out = core_total_writes;
                ADDR_WORD_ERRORS:      axi_rdata_mux_out = {{WORD_BITMAP_PAD{1'b0}}, core_word_errors};
                ADDR_CELL_ERRORS_ANY:  axi_rdata_mux_out = {{WORD_BITMAP_PAD{1'b0}}, core_word_cell_errors_any};

                // packed 4x8-bit counters
                ADDR_WRITE_CYCLES_0_3:   axi_rdata_mux_out = { core_word_write_cycles[3],  core_word_write_cycles[2],
                                                               core_word_write_cycles[1],  core_word_write_cycles[0]  };
                ADDR_WRITE_CYCLES_4_7:   axi_rdata_mux_out = { core_word_write_cycles[7],  core_word_write_cycles[6],
                                                               core_word_write_cycles[5],  core_word_write_cycles[4]  };
                ADDR_WRITE_CYCLES_8_11:  axi_rdata_mux_out = { core_word_write_cycles[11], core_word_write_cycles[10],
                                                               core_word_write_cycles[9],  core_word_write_cycles[8]  };
                ADDR_WRITE_CYCLES_12_15: axi_rdata_mux_out = { core_word_write_cycles[15], core_word_write_cycles[14],
                                                               core_word_write_cycles[13], core_word_write_cycles[12] };
                default:                 axi_rdata_mux_out = '0;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // AXI outputs (always OKAY here; add DECERR/SLVERR if you want)
    // ------------------------------------------------------------------------
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_BRESP   = 2'b00; // OKAY

    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RVALID  = axi_rvalid;
    assign S_AXI_RDATA   = axi_rdata_reg; // Assign from the latch
    assign S_AXI_RRESP   = 2'b00; // OKAY

endmodule : reram_axilite_wrapper