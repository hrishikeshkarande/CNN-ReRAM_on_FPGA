/*
 * ReRAM AXI-Lite Wrapper
 *
 * This module wraps the 'reram_memory_controller_blocking' core and
 * exposes it to the Zynq PS via an AXI4-Lite interface.
 *
 * It maps the 16-word ReRAM memory and all status/monitoring
 * registers to a specific AXI address space.
 *
 * Vivado 2018.1 Friendly
 */
module reram_axilite_wrapper #(
    // Parameters for the ReRAM Core
    parameter int MEMORY_DEPTH = 16,
    parameter int DATA_WIDTH   = 32,
    parameter int CORE_ADDR_WIDTH = $clog2(MEMORY_DEPTH),

    // Parameters for AXI-Lite Interface
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 10  // 10 bits = 1024 addresses (bytes)
) (
    // AXI-Lite Global Signals
    input  logic S_AXI_ACLK,
    input  logic S_AXI_ARESETN,

    // AXI-Lite Write Address Channel
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  logic [2:0]                    S_AXI_AWPROT,
    input  logic                          S_AXI_AWVALID,
    output logic                          S_AXI_AWREADY,

    // AXI-Lite Write Data Channel
    input  logic [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  logic [C_S_AXI_DATA_WIDTH/8-1:0] S_AXI_WSTRB,
    input  logic                          S_AXI_WVALID,
    output logic                          S_AXI_WREADY,

    // AXI-Lite Write Response Channel
    output logic [1:0]                    S_AXI_BRESP,
    output logic                          S_AXI_BVALID,
    input  logic                          S_AXI_BREADY,

    // AXI-Lite Read Address Channel
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  logic [2:0]                    S_AXI_ARPROT,
    input  logic                          S_AXI_ARVALID,
    output logic                          S_AXI_ARREADY,

    // AXI-Lite Read Data Channel
    output logic [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output logic [1:0]                    S_AXI_RRESP,
    output logic                          S_AXI_RVALID,
    input  logic                          S_AXI_RREADY
);

    //==========================================================================
    // Local Parameters - AXI Address Map
    //==========================================================================
    // AXI addresses are byte-based. Our memory is 32-bit (4-byte) word-based.
    
    // Memory Space: 0x000 - 0x03F (16 words * 4 bytes/word = 64 bytes)
    localparam int ADDR_MEM_BASE  = 10'h000;
    localparam int ADDR_MEM_END   = ADDR_MEM_BASE + (MEMORY_DEPTH * 4) - 1; // 0x03F

    // Register Space: 0x100 onwards
    localparam int ADDR_REG_BASE        = 10'h100;
    localparam int ADDR_TOTAL_READS     = ADDR_REG_BASE + 10'h00; // 0x100
    localparam int ADDR_TOTAL_WRITES    = ADDR_REG_BASE + 10'h04; // 0x104
    localparam int ADDR_WORD_ERRORS     = ADDR_REG_BASE + 10'h08; // 0x108
    localparam int ADDR_CELL_ERRORS_ANY = ADDR_REG_BASE + 10'h0C; // 0x10C

    // Register Space for Word Write Cycle Arrays (16 words * 8-bits = 16 bytes)
    // We pack four 8-bit counters into one 32-bit register.
    localparam int ADDR_WRITE_CYCLES_BASE = 10'h120;
    localparam int ADDR_WRITE_CYCLES_0_3  = ADDR_WRITE_CYCLES_BASE + 10'h00; // 0x120
    localparam int ADDR_WRITE_CYCLES_4_7  = ADDR_WRITE_CYCLES_BASE + 10'h04; // 0x124
    localparam int ADDR_WRITE_CYCLES_8_11 = ADDR_WRITE_CYCLES_BASE + 10'h08; // 0x128
    localparam int ADDR_WRITE_CYCLES_12_15= ADDR_WRITE_CYCLES_BASE + 10'h0C; // 0x12C

    // Register Space for Detailed Cell Error Flags (16 words * 32-bits)
    localparam int ADDR_CELL_ERRORS_BASE = 10'h200;
    localparam int ADDR_CELL_ERRORS_END  = ADDR_CELL_ERRORS_BASE + (MEMORY_DEPTH * 4) - 1; // 0x23F

    //==========================================================================
    // Core Instantiation
    //==========================================================================
    
    // Wires to connect wrapper logic to the ReRAM core
    logic [CORE_ADDR_WIDTH-1:0] core_addr_i;
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
    logic [7:0]                 core_word_write_cycles [MEMORY_DEPTH-1:0];
    logic [MEMORY_DEPTH-1:0]    core_word_cell_errors_any;
    logic [DATA_WIDTH-1:0]      core_word_cell_errors [MEMORY_DEPTH-1:0];

    reram_memory_controller_blocking #(
        .MEMORY_DEPTH(MEMORY_DEPTH),
        .ADDR_WIDTH(CORE_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(S_AXI_ACLK),
        .rst_n(S_AXI_ARESETN),
   
        .addr_i(core_addr_i),
        .data_i(core_data_i),
        .data_o(core_data_o),
        .read_i(core_read_i),
        .write_i(core_write_i),
        .done_o(core_done_o),
        .error_o(core_error_o),
        .busy_o(core_busy_o),
        .total_reads(core_total_reads),
        .total_writes(core_total_writes),
        .word_errors(core_word_errors),
        
        .word_write_cycles(core_word_write_cycles),
        .word_cell_errors_any(core_word_cell_errors_any),
        .word_cell_errors(core_word_cell_errors)
    );

    //==========================================================================
    // AXI Interface Logic
    //==========================================================================
    
    // AXI-Lite internal registers
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    logic                          axi_awready;
    logic                          axi_wready;
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    logic                          axi_arready;
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    logic                          axi_rvalid;
    logic                          axi_bvalid;

    // FSM for Write Operations
    typedef enum logic [1:0] { WR_IDLE, WR_WAIT_CORE, WR_RESP } wr_state_t;
    wr_state_t wr_state;
    
    // FSM for Read Operations
    typedef enum logic [1:0] { RD_IDLE, RD_WAIT_CORE, RD_RESP } rd_state_t;
    rd_state_t rd_state;

    // Internal flags to decode address
    logic is_mem_access;
    logic is_reg_access;
    logic is_write;
    logic is_read;

    //==========================================================================
    // Write Logic FSM
    //==========================================================================
    
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            wr_state    <= WR_IDLE;
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            core_write_i <= 1'b0;
            core_addr_i <= '0;
            core_data_i <= '0;
        end else begin
            
            case (wr_state)
                WR_IDLE: begin
                    // Wait for both address and data to be valid
                    if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        axi_awready <= 1'b1;
                        axi_wready  <= 1'b1;
                        wr_state    <= WR_WAIT_CORE;
                        
                        // Latch address and data
                        axi_awaddr  <= S_AXI_AWADDR;
                        core_addr_i <= S_AXI_AWADDR[CORE_ADDR_WIDTH+1:2]; // Convert byte addr to word addr
                        core_data_i <= S_AXI_WDATA;
                        
                        // Check if this is a write to the memory region
                        if (S_AXI_AWADDR >= ADDR_MEM_BASE && S_AXI_AWADDR <= ADDR_MEM_END) begin
                            core_write_i <= 1'b1; // Start the core's write operation
                        end else begin
                            core_write_i <= 1'b0; // Not writing to memory, just complete
                        end
                    end else begin
                        axi_awready <= 1'b0;
                        axi_wready  <= 1'b0;
                    end
                end 
                
                WR_WAIT_CORE: begin
                    axi_awready <= 1'b0;
                    axi_wready  <= 1'b0;
                    core_write_i <= 1'b0; // Pulse was 1 cycle

                    // Check if this was a memory write
                    if (axi_awaddr >= ADDR_MEM_BASE && axi_awaddr <= ADDR_MEM_END) begin
                        // Wait for the blocking core to finish
                        if (core_done_o) begin
                            wr_state   <= WR_RESP;
                            axi_bvalid <= 1'b1;
                        end
                    end else begin
                        // Not a memory write (e.g., to a RO register)
                        // Operation is "done" immediately
                        wr_state   <= WR_RESP;
                        axi_bvalid <= 1'b1;
                    end
                end
                
                WR_RESP: begin
                    if (S_AXI_BREADY) begin
                        wr_state   <= WR_IDLE;
                        axi_bvalid <= 1'b0;
                    end
                end
                
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    //==========================================================================
    // Read Logic FSM
    //==========================================================================
    
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            rd_state    <= RD_IDLE;
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            core_read_i <= 1'b0;
        end else begin
            
            case (rd_state)
                RD_IDLE: begin
                    if (S_AXI_ARVALID) begin
                        axi_arready <= 1'b1;
                        axi_araddr  <= S_AXI_ARADDR; // Latch read address
                        
                        // Check if this is a read from the memory region
                        if (S_AXI_ARADDR >= ADDR_MEM_BASE && S_AXI_ARADDR <= ADDR_MEM_END) begin
                            rd_state    <= RD_WAIT_CORE;
                            core_read_i <= 1'b1; // Start core's read op
                            core_addr_i <= S_AXI_ARADDR[CORE_ADDR_WIDTH+1:2];
                        end else begin
                            // This is a register read, it's not blocking
                            rd_state   <= RD_RESP;
                            axi_rvalid <= 1'b1; // Data will be valid next cycle
                        end
                    end else begin
                        axi_arready <= 1'b0;
                    end
                end
                
                RD_WAIT_CORE: begin
                    axi_arready <= 1'b0;
                    core_read_i <= 1'b0; // Pulse was 1 cycle

                    // Wait for the blocking core to finish
                    if (core_done_o) begin
                        rd_state   <= RD_RESP;
                        axi_rvalid <= 1'b1;
                    end
                end
                
                RD_RESP: begin
                    axi_arready <= 1'b0;
                    if (S_AXI_RREADY) begin
                        rd_state   <= RD_IDLE;
                        axi_rvalid <= 1'b0;
                    end
                end
                
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    //==========================================================================
    // Read Data Mux (Combinational)
    //==========================================================================
    
    always_comb begin
        // Default to 0
        axi_rdata = '0;
        
        // This is a combinational read mux.
        // It provides the data based on the LATCHED read address (axi_araddr).
        if (axi_araddr >= ADDR_MEM_BASE && axi_araddr <= ADDR_MEM_END) begin
            // Read from ReRAM Memory Core
            axi_rdata = core_data_o;
        } 
        else if (axi_araddr >= ADDR_CELL_ERRORS_BASE && axi_araddr <= ADDR_CELL_ERRORS_END) begin
            // Read from Cell Error Flags Array
            axi_rdata = core_word_cell_errors[axi_araddr[CORE_ADDR_WIDTH+1:2]];
        }
        else begin
            // Read from Status Registers
            case (axi_araddr)
                ADDR_TOTAL_READS:     axi_rdata = core_total_reads;
                ADDR_TOTAL_WRITES:    axi_rdata = core_total_writes;
                ADDR_WORD_ERRORS:     axi_rdata = {{(DATA_WIDTH-MEMORY_DEPTH){1'b0}}, core_word_errors};
                ADDR_CELL_ERRORS_ANY: axi_rdata = {{(DATA_WIDTH-MEMORY_DEPTH){1'b0}}, core_word_cell_errors_any};
                
                // Packed 8-bit write cycle counters
                ADDR_WRITE_CYCLES_0_3:   axi_rdata = {core_word_write_cycles[3], core_word_write_cycles[2], core_word_write_cycles[1], core_word_write_cycles[0]};
                ADDR_WRITE_CYCLES_4_7:   axi_rdata = {core_word_write_cycles[7], core_word_write_cycles[6], core_word_write_cycles[5], core_word_write_cycles[4]};
                ADDR_WRITE_CYCLES_8_11:  axi_rdata = {core_word_write_cycles[11], core_word_write_cycles[10], core_word_write_cycles[9], core_word_write_cycles[8]};
                ADDR_WRITE_CYCLES_12_15: axi_rdata = {core_word_write_cycles[15], core_word_write_cycles[14], core_word_write_cycles[13], core_word_write_cycles[12]};
                
                default: axi_rdata = '0; // Invalid address
            endcase
        end
    end

    //==========================================================================
    // AXI Output Assignments
    //==========================================================================
    
    // Assign internal registers to AXI outputs
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_BRESP   = 2'b00; // 'OKAY'

    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RVALID  = axi_rvalid;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = 2'b00; // 'OKAY'

endmodule