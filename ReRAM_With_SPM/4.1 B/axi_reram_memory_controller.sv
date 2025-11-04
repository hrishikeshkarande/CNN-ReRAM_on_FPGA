/*
 * AXI4-Lite ReRAM Memory Controller
 * 
 * This module provides an AXI4-Lite interface to the ReRAM memory controller,
 * allowing it to be easily integrated with ARM processors and AXI interconnects.
 * 
 * Features:
 * - Standard AXI4-Lite slave interface
 * - Memory-mapped access to ReRAM memory
 * - Proper AXI response handling with ReRAM delay support
 * - Address alignment checking
 * - Error reporting through AXI response codes
 * - Auto-calculated address width based on memory depth
 * - Configurable ReRAM timing parameters
 * 
 * Parameters:
 * - MEMORY_DEPTH: Number of 32-bit words in ReRAM memory
 * - MEMORY_BASE_ADDR: Base address for memory region
 * - CTRL_BASE_ADDR: Base address for control registers
 * - READ/SET/RESET_DELAY_CYCLES: ReRAM timing parameters
 * - MAX_WRITE_CYCLES: Endurance limit for ReRAM cells
 * 
 * Memory Map:
 * 0x0000_0000 - 0x0003_FFFF: ReRAM Memory (size depends on MEMORY_DEPTH parameter)
 * 0x0004_0000 - 0x0004_00FF: Control/Status Registers
 *   0x0004_0000: Status Register (RO)
 *     [0]: Busy flag
 *     [1]: Global error flag  
 *     [2]: Endurance error flag
 *     [3]: Memory operation error flag
 *     [7:4]: Reserved
 *     [15:8]: Current operation progress (for long operations)
 *     [31:16]: Active word address during operation
 *   0x0004_0004: Control Register (RW)
 *     [0]: Error clear bit (write 1 to clear errors)
 *     [1]: Debug mode enable
 *     [2]: Endurance monitoring enable
 *     [3]: Auto-refresh enable
 *     [31:4]: Reserved
 *   0x0004_0008: Error Count Register (RO)
 *     [15:0]: Total operation errors
 *     [31:16]: Endurance errors
 *   0x0004_000C: Total Operations (RO)
 *     [15:0]: Total reads
 *     [31:16]: Total writes
 *   0x0004_0010: Last Error Address (RO)
 *   0x0004_0014: Last Error Code (RO)
 *     [7:0]: Error type code
 *     [15:8]: Word array index
 *     [31:16]: Error timestamp
 *   0x0004_0018: Worn Out Cells Bitmap Low (RO) - Words 0-31
 *   0x0004_001C: Worn Out Cells Bitmap High (RO) - Words 32-63
 *   0x0004_0020: ReRAM Configuration (RW)
 *     [7:0]: Read delay cycles
 *     [15:8]: Set delay cycles  
 *     [23:16]: Reset delay cycles
 *     [31:24]: Reserved
 *   0x0004_0024: Endurance Limits (RW)
 *     [7:0]: Max write cycles (read-only copy)
 *     [15:8]: Warning threshold (% of max cycles)
 *     [31:16]: Reserved
 *   0x0004_0040 - 0x0004_007F: Per-Word Write Cycles (RO) - 16 words × 32-bit
 *     0x0004_0040: Word 0 write cycles [7:0], Word 1 [15:8], Word 2 [23:16], Word 3 [31:24]
 *     0x0004_0044: Word 4-7 write cycles (packed)
 *     0x0004_0048: Word 8-11 write cycles (packed)
 *     0x0004_004C: Word 12-15 write cycles (packed)
 *   0x0004_0080 - 0x0004_00BF: Per-Word Cell Error Details (RO) - 16 words × 32-bit
 *     0x0004_0080: Word 0 detailed cell errors (bit per cell)
 *     0x0004_0084: Word 1 detailed cell errors
 *     ... (one register per word)
 *   0x0004_00C0: Health Summary (RO)
 *     [7:0]: Number of healthy words
 *     [15:8]: Number of warning words (>50% cycles)
 *     [23:16]: Number of critical words (>80% cycles)
 *     [31:24]: Number of worn-out words
 */

module axi_reram_memory_controller #(
    parameter int AXI_ADDR_WIDTH = 32,       // AXI address width
    parameter int AXI_DATA_WIDTH = 32,       // AXI data width
    parameter int MEMORY_DEPTH = 16,         // ReRAM memory depth in words (default: 16 words = 64B)
    parameter int MEMORY_BASE_ADDR = 32'h0000_0000,  // Memory base address
    parameter int CTRL_BASE_ADDR = 32'h0004_0000,    // Control register base
    parameter int READ_DELAY_CYCLES = 3,     // ReRAM timing parameters
    parameter int SET_DELAY_CYCLES = 10,     
    parameter int RESET_DELAY_CYCLES = 10,   
    parameter int MAX_WRITE_CYCLES = 200
) (
    input  logic                        aclk,
    input  logic                        aresetn,
    
    // AXI4-Lite Write Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  logic                        s_axi_awvalid,
    output logic                        s_axi_awready,
    input  logic [2:0]                  s_axi_awprot,   // Protection (usually ignored)
    
    // AXI4-Lite Write Data Channel  
    input  logic [AXI_DATA_WIDTH-1:0]  s_axi_wdata,
    input  logic [3:0]                  s_axi_wstrb,    // Write strobes (byte enables)
    input  logic                        s_axi_wvalid,
    output logic                        s_axi_wready,
    
    // AXI4-Lite Write Response Channel
    output logic [1:0]                  s_axi_bresp,
    output logic                        s_axi_bvalid,
    input  logic                        s_axi_bready,
    
    // AXI4-Lite Read Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0]  s_axi_araddr,
    input  logic                        s_axi_arvalid,
    output logic                        s_axi_arready,
    input  logic [2:0]                  s_axi_arprot,   // Protection (usually ignored)
    
    // AXI4-Lite Read Data Channel
    output logic [AXI_DATA_WIDTH-1:0]  s_axi_rdata,
    output logic [1:0]                  s_axi_rresp,
    output logic                        s_axi_rvalid,
    input  logic                        s_axi_rready
);

    // AXI Response codes
    localparam [1:0] AXI_RESP_OKAY   = 2'b00;  // Normal access success
    localparam [1:0] AXI_RESP_EXOKAY = 2'b01;  // Exclusive access okay
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;  // Slave error
    localparam [1:0] AXI_RESP_DECERR = 2'b11;  // Decode error
    
    // Address decode parameters
    localparam int MEMORY_SIZE_BYTES = MEMORY_DEPTH * 4;  // Convert words to bytes
    localparam int MEMORY_ADDR_WIDTH = $clog2(MEMORY_DEPTH); // Auto-calculated address width
    localparam logic [AXI_ADDR_WIDTH-1:0] MEMORY_END_ADDR = MEMORY_BASE_ADDR + MEMORY_SIZE_BYTES - 1;
    localparam logic [AXI_ADDR_WIDTH-1:0] CTRL_END_ADDR = CTRL_BASE_ADDR + 32'h00FF;  // Extended to 0xFF for full register set
    
    // Error type codes
    localparam [7:0] ERR_NONE           = 8'h00;  // No error
    localparam [7:0] ERR_ENDURANCE      = 8'h01;  // Cell worn out
    localparam [7:0] ERR_OPERATION      = 8'h02;  // Operation failed
    localparam [7:0] ERR_ADDRESS        = 8'h03;  // Address out of range
    localparam [7:0] ERR_ALIGNMENT      = 8'h04;  // Misaligned access
    localparam [7:0] ERR_BUSY           = 8'h05;  // Controller busy
    localparam [7:0] ERR_WORN_OUT       = 8'h06;  // Word is worn out
    
    // AXI State Machines
    typedef enum logic [2:0] {
        AXI_WRITE_IDLE,
        AXI_WRITE_ADDR,  
        AXI_WRITE_DATA,
        AXI_WRITE_MEM,      // New state: waiting for memory operation
        AXI_WRITE_RESP
    } axi_write_state_t;
    
    typedef enum logic [2:0] {
        AXI_READ_IDLE,
        AXI_READ_ADDR,
        AXI_READ_MEM,       // New state: waiting for memory operation  
        AXI_READ_DATA
    } axi_read_state_t;
    
    axi_write_state_t write_state, write_state_next;
    axi_read_state_t read_state, read_state_next;
    
    // Internal registers
    logic [AXI_ADDR_WIDTH-1:0] write_addr_reg, read_addr_reg;
    logic [AXI_DATA_WIDTH-1:0] write_data_reg;
    logic [3:0] write_strb_reg;
    
    // Memory controller interface
    logic [MEMORY_ADDR_WIDTH-1:0] mem_addr;
    logic [AXI_DATA_WIDTH-1:0]    mem_data_in;
    logic [AXI_DATA_WIDTH-1:0]    mem_data_out;
    logic                         mem_read;
    logic                         mem_write;
    logic                         mem_done;
    logic                         mem_error;
    logic                         mem_busy;
    logic [31:0]                  total_reads;
    logic [31:0]                  total_writes; 
    logic [MEMORY_DEPTH-1:0]      word_errors;      // Per-word error flags
    
    // Enhanced endurance monitoring
    logic [7:0]                   word_write_cycles [MEMORY_DEPTH-1:0];
    logic [MEMORY_DEPTH-1:0]      word_cell_errors_any;
    logic [AXI_DATA_WIDTH-1:0]    word_cell_errors [MEMORY_DEPTH-1:0];
    
    // Enhanced Control/Status registers
    logic [31:0] status_reg;
    logic [31:0] control_reg;
    logic [31:0] error_count_reg;
    logic [31:0] total_ops_reg;
    logic [31:0] last_error_addr_reg;
    logic [31:0] last_error_code_reg;
    logic [31:0] worn_cells_low_reg;
    logic [31:0] worn_cells_high_reg;
    
    // New enhanced registers
    logic [31:0] reram_config_reg;
    logic [31:0] endurance_limits_reg;
    logic [31:0] health_summary_reg;
    
    // Per-word monitoring registers (packed for efficient access)
    logic [31:0] word_cycles_packed [3:0];     // 4 registers for 16 words (4 words per register)
    logic [31:0] word_cell_errors_regs [MEMORY_DEPTH-1:0]; // Individual cell error registers
    
    // Register address decode variables
    logic [7:0] reg_addr;
    logic [5:0] word_index;
    int word_idx;  // For word indexing in loops
    int i, j;      // For loop variables (Vivado 2018.1 compatibility)
    
    // Health summary calculation variables  
    logic [7:0] healthy_count, warning_count, critical_count, worn_count;
    
    // Error tracking
    logic [15:0] operation_error_count;
    logic [15:0] endurance_error_count;
    logic [15:0] error_timestamp;
    logic error_occurred;
    logic endurance_error_flag;
    logic operation_error_flag;
    
    // Address decode signals
    logic write_addr_is_memory, write_addr_is_ctrl;
    logic read_addr_is_memory, read_addr_is_ctrl;
    logic addr_aligned;
    logic write_addr_valid, read_addr_valid;  // Add address validity checks
    
    //==========================================================================
    // ReRAM Memory Controller Instance
    //==========================================================================
    
    reram_memory_controller_blocking #(
        .MEMORY_DEPTH(MEMORY_DEPTH),
        .DATA_WIDTH(AXI_DATA_WIDTH),  // Use AXI_DATA_WIDTH parameter instead of hardcoded 32
        .READ_DELAY_CYCLES(READ_DELAY_CYCLES),
        .SET_DELAY_CYCLES(SET_DELAY_CYCLES),
        .RESET_DELAY_CYCLES(RESET_DELAY_CYCLES),
        .MAX_WRITE_CYCLES(MAX_WRITE_CYCLES)
    ) reram_controller (
        .clk(aclk),
        .rst_n(aresetn),
        .addr_i(mem_addr),
        .data_i(mem_data_in),
        .data_o(mem_data_out),
        .read_i(mem_read),
        .write_i(mem_write),
        .done_o(mem_done),
        .error_o(mem_error),
        .busy_o(mem_busy),
        .total_reads(total_reads),
        .total_writes(total_writes),
        .word_errors(word_errors),
        
        // Enhanced endurance monitoring
        .word_write_cycles(word_write_cycles),
        .word_cell_errors_any(word_cell_errors_any),
        .word_cell_errors(word_cell_errors)
    );
    
    //==========================================================================
    // Address Decoding
    //==========================================================================
    
    always_comb begin
        // For address decode, use the current address inputs when not latched yet
        logic [AXI_ADDR_WIDTH-1:0] current_write_addr, current_read_addr;
        logic [MEMORY_ADDR_WIDTH-1:0] calculated_write_addr, calculated_read_addr;
        
        // Select address source based on state
        if (write_state == AXI_WRITE_IDLE) begin
            current_write_addr = s_axi_awaddr;
        end else begin
            current_write_addr = write_addr_reg;
        end
        
        if (read_state == AXI_READ_IDLE) begin
            current_read_addr = s_axi_araddr;
        end else begin
            current_read_addr = read_addr_reg;
        end
        
        // Write address decode
        write_addr_is_memory = (current_write_addr >= MEMORY_BASE_ADDR) && 
                              (current_write_addr <= MEMORY_END_ADDR);
        write_addr_is_ctrl = (current_write_addr >= CTRL_BASE_ADDR) && 
                            (current_write_addr <= CTRL_END_ADDR);
        
        // Read address decode  
        read_addr_is_memory = (current_read_addr >= MEMORY_BASE_ADDR) && 
                             (current_read_addr <= MEMORY_END_ADDR);
        read_addr_is_ctrl = (current_read_addr >= CTRL_BASE_ADDR) && 
                           (current_read_addr <= CTRL_END_ADDR);
        
        // Check 32-bit alignment
        addr_aligned = (current_write_addr[1:0] == 2'b00) && (current_read_addr[1:0] == 2'b00);
        
        // Calculate word addresses and validate bounds
        calculated_write_addr = (current_write_addr - MEMORY_BASE_ADDR) >> 2;
        calculated_read_addr = (current_read_addr - MEMORY_BASE_ADDR) >> 2;
        
        // Address validity checks - ensure calculated address fits in memory controller width
        write_addr_valid = write_addr_is_memory && (calculated_write_addr < MEMORY_DEPTH);
        read_addr_valid = read_addr_is_memory && (calculated_read_addr < MEMORY_DEPTH);
        
        // Generate memory address (word address from byte address)
        if (write_state != AXI_WRITE_IDLE && write_addr_valid) begin
            mem_addr = calculated_write_addr;
        end else if (read_state != AXI_READ_IDLE && read_addr_valid) begin
            mem_addr = calculated_read_addr;
        end else begin
            mem_addr = '0;
        end
    end
    
    //==========================================================================
    // AXI Write State Machine
    //==========================================================================
    
    always_comb begin
        write_state_next = write_state;
        
        case (write_state)
            AXI_WRITE_IDLE: begin
                if (s_axi_awvalid && s_axi_wvalid) begin
                    // Both address and data available simultaneously
                    if (write_addr_valid && addr_aligned) begin
                        write_state_next = AXI_WRITE_MEM;  // Start memory operation
                    end else begin
                        write_state_next = AXI_WRITE_RESP; // Control reg or error
                    end
                end else if (s_axi_awvalid) begin
                    // Address available first
                    write_state_next = AXI_WRITE_ADDR;
                end else if (s_axi_wvalid) begin
                    // Data available first  
                    write_state_next = AXI_WRITE_DATA;
                end
            end
            
            AXI_WRITE_ADDR: begin
                if (s_axi_wvalid) begin
                    if (write_addr_valid && addr_aligned) begin
                        write_state_next = AXI_WRITE_MEM;  // Start memory operation
                    end else begin
                        write_state_next = AXI_WRITE_RESP; // Control reg or error
                    end
                end
            end
            
            AXI_WRITE_DATA: begin
                if (s_axi_awvalid) begin
                    if (write_addr_valid && addr_aligned) begin
                        write_state_next = AXI_WRITE_MEM;  // Start memory operation
                    end else begin
                        write_state_next = AXI_WRITE_RESP; // Control reg or error
                    end
                end
            end
            
            AXI_WRITE_MEM: begin
                // Wait for ReRAM memory operation to complete
                if (mem_done) begin
                    write_state_next = AXI_WRITE_RESP;
                end
            end
            
            AXI_WRITE_RESP: begin
                if (s_axi_bready && s_axi_bvalid) begin
                    write_state_next = AXI_WRITE_IDLE;
                end
            end
        endcase
    end
    
    //==========================================================================
    // AXI Read State Machine  
    //==========================================================================
    
    always_comb begin
        read_state_next = read_state;
        
        case (read_state)
            AXI_READ_IDLE: begin
                if (s_axi_arvalid) begin
                    read_state_next = AXI_READ_ADDR;
                end
            end
            
            AXI_READ_ADDR: begin
                if (read_addr_valid && addr_aligned) begin
                    read_state_next = AXI_READ_MEM;  // Start memory operation
                end else begin
                    read_state_next = AXI_READ_DATA; // Control reg or error
                end
            end
            
            AXI_READ_MEM: begin
                // Wait for ReRAM memory operation to complete
                if (mem_done) begin
                    read_state_next = AXI_READ_DATA;
                end
            end
            
            AXI_READ_DATA: begin
                if (s_axi_rready && s_axi_rvalid) begin
                    read_state_next = AXI_READ_IDLE;
                end
            end
        endcase
    end
    
    //==========================================================================
    // AXI Interface Logic
    //==========================================================================
    
    // Write channel outputs
    always_comb begin
        s_axi_awready = (write_state == AXI_WRITE_IDLE) || (write_state == AXI_WRITE_DATA);
        s_axi_wready = (write_state == AXI_WRITE_IDLE) || (write_state == AXI_WRITE_ADDR);
        
        s_axi_bvalid = (write_state == AXI_WRITE_RESP);
        
        // Write response - check for errors
        if (write_state == AXI_WRITE_RESP) begin
            if (!write_addr_is_memory && !write_addr_is_ctrl) begin
                s_axi_bresp = AXI_RESP_DECERR;  // Address decode error
            end else if (write_addr_is_memory && !write_addr_valid) begin
                s_axi_bresp = AXI_RESP_DECERR;  // Memory address out of bounds
            end else if (!addr_aligned) begin
                s_axi_bresp = AXI_RESP_SLVERR;  // Alignment error
            end else if (write_addr_valid && mem_error) begin
                s_axi_bresp = AXI_RESP_SLVERR;  // Memory controller error (busy/worn-out/operation)
            end else begin
                s_axi_bresp = AXI_RESP_OKAY;    // Success
            end
        end else begin
            s_axi_bresp = AXI_RESP_OKAY;
        end
    end
    
    // Read channel outputs
    always_comb begin
        s_axi_arready = (read_state == AXI_READ_IDLE);
        s_axi_rvalid = (read_state == AXI_READ_DATA);
        
        // Read response - check for errors
        if (read_state == AXI_READ_DATA) begin
            if (!read_addr_is_memory && !read_addr_is_ctrl) begin
                s_axi_rresp = AXI_RESP_DECERR;  // Address decode error
                s_axi_rdata = 32'hDEADBEEF;     // Error pattern
            end else if (read_addr_is_memory && !read_addr_valid) begin
                s_axi_rresp = AXI_RESP_DECERR;  // Memory address out of bounds
                s_axi_rdata = 32'hBAD0BAAD;     // Error pattern (valid hex)
            end else if (!addr_aligned) begin
                s_axi_rresp = AXI_RESP_SLVERR;  // Alignment error  
                s_axi_rdata = 32'hBAD00BAD;     // Error pattern
            end else if (read_addr_valid && mem_error) begin
                s_axi_rresp = AXI_RESP_SLVERR;  // Memory controller error (busy/worn-out/operation)
                s_axi_rdata = 32'hDEAD0000;     // Error pattern (valid hex)
            end else if (read_addr_valid) begin
                s_axi_rresp = AXI_RESP_OKAY;    // Memory read success
                s_axi_rdata = mem_data_out;
            end else begin  // Control register read
                s_axi_rresp = AXI_RESP_OKAY;    // Control read success
                
                // Decode register address
                reg_addr = read_addr_reg[7:0];
                
                case (reg_addr[7:2])  // Use upper 6 bits for word addressing
                    // Basic control/status registers (0x00-0x1F)
                    6'h00: s_axi_rdata = status_reg;           // 0x00
                    6'h01: s_axi_rdata = control_reg;          // 0x04
                    6'h02: s_axi_rdata = error_count_reg;      // 0x08
                    6'h03: s_axi_rdata = total_ops_reg;        // 0x0C
                    6'h04: s_axi_rdata = last_error_addr_reg;  // 0x10
                    6'h05: s_axi_rdata = last_error_code_reg;  // 0x14
                    6'h06: s_axi_rdata = worn_cells_low_reg;   // 0x18
                    6'h07: s_axi_rdata = worn_cells_high_reg;  // 0x1C
                    
                    // Extended configuration registers (0x20-0x3F)
                    6'h08: s_axi_rdata = reram_config_reg;     // 0x20
                    6'h09: s_axi_rdata = endurance_limits_reg; // 0x24
                    
                    // Per-word write cycles (0x40-0x4F) - packed format
                    6'h10: s_axi_rdata = word_cycles_packed[0]; // 0x40 - Words 0-3
                    6'h11: s_axi_rdata = word_cycles_packed[1]; // 0x44 - Words 4-7
                    6'h12: s_axi_rdata = word_cycles_packed[2]; // 0x48 - Words 8-11
                    6'h13: s_axi_rdata = word_cycles_packed[3]; // 0x4C - Words 12-15
                    
                    // Per-word cell error details (0x80-0xBF)
                    default: begin
                        if (reg_addr >= 8'h80 && reg_addr <= 8'hBF) begin
                            // Cell error registers: 0x80, 0x84, 0x88, ... 0xBC
                            word_index = (reg_addr - 8'h80) >> 2;
                            if (word_index < MEMORY_DEPTH) begin
                                s_axi_rdata = word_cell_errors_regs[word_index];
                            end else begin
                                s_axi_rdata = 32'h0;
                            end
                        end else if (reg_addr == 8'hC0) begin
                            s_axi_rdata = health_summary_reg; // 0xC0
                        end else begin
                            s_axi_rdata = 32'h0; // Unimplemented register
                        end
                    end
                endcase
            end
        end else begin
            s_axi_rresp = AXI_RESP_OKAY;
            s_axi_rdata = 32'h0;
        end
    end
    
    //==========================================================================
    // Memory Controller Interface
    //==========================================================================
    
    always_comb begin
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_data_in = write_data_reg;
        
        // Memory read operation - start when entering MEM state
        if (read_state == AXI_READ_MEM) begin
            mem_read = 1'b1;
        end
        
        // Memory write operation - start when entering MEM state
        if (write_state == AXI_WRITE_MEM) begin
            mem_write = 1'b1;
        end
    end
    
    //==========================================================================
    // Enhanced Control/Status Registers
    //==========================================================================
    
    always_comb begin
        // Enhanced Status Register (0x0000)
        status_reg[0] = mem_busy;                    // Busy flag
        status_reg[1] = mem_error || error_occurred; // Global error flag
        status_reg[2] = endurance_error_flag;        // Endurance error flag
        status_reg[3] = operation_error_flag;        // Operation error flag
        status_reg[7:4] = '0;                        // Reserved
        status_reg[15:8] = mem_busy ? 8'hFF : 8'h00; // Operation progress (simplified)
        // Current active word address during operation
        if (mem_busy) begin
            status_reg[31:16] = {12'h0, mem_addr[MEMORY_ADDR_WIDTH-1:0]};
        end else begin
            status_reg[31:16] = 16'h0;
        end
        
        // Error Count Register (0x0008)
        error_count_reg[15:0] = operation_error_count;  // Operation errors
        error_count_reg[31:16] = endurance_error_count; // Endurance errors
        
        // Total Operations Register (0x000C)
        total_ops_reg[15:0] = total_reads[15:0];    // Total reads
        total_ops_reg[31:16] = total_writes[15:0];  // Total writes
        
        // ReRAM Configuration Register (0x0020) - Read-only copy of timing
        reram_config_reg[7:0] = READ_DELAY_CYCLES[7:0];
        reram_config_reg[15:8] = SET_DELAY_CYCLES[7:0];
        reram_config_reg[23:16] = RESET_DELAY_CYCLES[7:0];
        reram_config_reg[31:24] = 8'h0;
        
        // Endurance Limits Register (0x0024)
        endurance_limits_reg[7:0] = MAX_WRITE_CYCLES[7:0];  // Max cycles (read-only)
        endurance_limits_reg[15:8] = 8'd160;  // Warning threshold (80% of 200)
        endurance_limits_reg[31:16] = 16'h0;
        
        // Pack per-word write cycles into 32-bit registers (4 bytes per register)
        for (i = 0; i < 4; i++) begin
            for (j = 0; j < 4; j++) begin
                word_idx = i * 4 + j;
                if (word_idx < MEMORY_DEPTH) begin
                    word_cycles_packed[i][(j*8)+:8] = word_write_cycles[word_idx];
                end else begin
                    word_cycles_packed[i][(j*8)+:8] = 8'h0;
                end
            end
        end
        
        // Copy cell error details to individual registers
        for (i = 0; i < MEMORY_DEPTH; i++) begin
            word_cell_errors_regs[i] = word_cell_errors[i];
        end
        
        // Health Summary Register (0x00C0)
        healthy_count = 8'h0;
        warning_count = 8'h0;
        critical_count = 8'h0;
        worn_count = 8'h0;
        
        for (i = 0; i < MEMORY_DEPTH; i++) begin
            if (word_cell_errors_any[i]) begin
                worn_count = worn_count + 1;
            end else if (word_write_cycles[i] >= 8'd160) begin  // >80% of 200
                critical_count = critical_count + 1;
            end else if (word_write_cycles[i] >= 8'd100) begin  // >50% of 200
                warning_count = warning_count + 1;
            end else begin
                healthy_count = healthy_count + 1;
            end
        end
        
        health_summary_reg[7:0] = healthy_count;
        health_summary_reg[15:8] = warning_count;
        health_summary_reg[23:16] = critical_count;
        health_summary_reg[31:24] = worn_count;
        
        // Worn Out Cells Bitmap (0x0018, 0x001C)
        if (MEMORY_DEPTH <= 32) begin
            worn_cells_low_reg[MEMORY_DEPTH-1:0] = word_cell_errors_any[MEMORY_DEPTH-1:0];
            worn_cells_low_reg[31:MEMORY_DEPTH] = '0;
            worn_cells_high_reg = '0;
        end else if (MEMORY_DEPTH <= 64) begin
            worn_cells_low_reg = word_cell_errors_any[31:0];
            worn_cells_high_reg[MEMORY_DEPTH-33:0] = word_cell_errors_any[MEMORY_DEPTH-1:32];
            worn_cells_high_reg[31:MEMORY_DEPTH-32] = '0;
        end else begin
            // For larger memories, show first 64 words
            worn_cells_high_reg = word_cell_errors_any[63:32];
        end
    end
    
    // Error detection and logging
    always_comb begin
        error_occurred = 1'b0;
        endurance_error_flag = 1'b0;
        operation_error_flag = 1'b0;
        
        // Check for endurance errors (worn out cells using detailed monitoring)
        if (word_cell_errors_any != '0) begin
            endurance_error_flag = 1'b1;
            error_occurred = 1'b1;
        end
        
        // Check for operation errors
        if (mem_error) begin
            operation_error_flag = 1'b1;
            error_occurred = 1'b1;
        end
    end
    
    //==========================================================================
    // Sequential Logic
    //==========================================================================
    
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            write_state <= AXI_WRITE_IDLE;
            read_state <= AXI_READ_IDLE;
            write_addr_reg <= '0;
            read_addr_reg <= '0;
            write_data_reg <= '0;
            write_strb_reg <= '0;
            control_reg <= '0;
            
            // Error tracking registers
            operation_error_count <= '0;
            endurance_error_count <= '0;
            error_timestamp <= '0;
            last_error_addr_reg <= '0;
            last_error_code_reg <= '0;
        end else begin
            write_state <= write_state_next;
            read_state <= read_state_next;
            
            // Increment timestamp counter
            error_timestamp <= error_timestamp + 1;
            
            // Latch write address
            if (s_axi_awvalid && s_axi_awready) begin
                write_addr_reg <= s_axi_awaddr;
            end
            
            // Latch write data
            if (s_axi_wvalid && s_axi_wready) begin
                write_data_reg <= s_axi_wdata;
                write_strb_reg <= s_axi_wstrb;
            end
            
            // Latch read address
            if (s_axi_arvalid && s_axi_arready) begin
                read_addr_reg <= s_axi_araddr;
            end
            
            // Error logging and counting - Let memory controller handle busy/worn-out rejections
            if (mem_done && mem_error) begin
                operation_error_count <= operation_error_count + 1;
                
                // Log error details
                if (write_state == AXI_WRITE_MEM) begin
                    last_error_addr_reg <= write_addr_reg;
                    last_error_code_reg <= {error_timestamp, mem_addr[7:0], ERR_OPERATION};
                end else if (read_state == AXI_READ_MEM) begin
                    last_error_addr_reg <= read_addr_reg;
                    last_error_code_reg <= {error_timestamp, mem_addr[7:0], ERR_OPERATION};
                end
            end
            
            // Check for new endurance errors
            if (word_errors != '0) begin
                // Count number of new endurance errors
                logic [31:0] new_errors;
                static logic [MEMORY_DEPTH-1:0] prev_word_errors = '0;
                
                new_errors = word_errors & ~prev_word_errors;
                if (new_errors != '0) begin
                    endurance_error_count <= endurance_error_count + $countones(new_errors);
                    
                    // Log first endurance error found
                    for (i = 0; i < MEMORY_DEPTH; i++) begin
                        if (new_errors[i]) begin
                            last_error_addr_reg <= MEMORY_BASE_ADDR + (i * 4);
                            last_error_code_reg <= {error_timestamp, i[7:0], ERR_ENDURANCE};
                            break;
                        end
                    end
                end
                prev_word_errors = word_errors;
            end
            
            // Control register writes
            if (write_state == AXI_WRITE_RESP && write_addr_is_ctrl && addr_aligned) begin
                logic [7:0] write_reg_addr = write_addr_reg[7:0];
                
                case (write_reg_addr[7:2])
                    6'h01: begin  // Control Register (0x04)
                        control_reg <= write_data_reg;
                        
                        // Error clear functionality
                        if (write_data_reg[0]) begin  // Clear errors bit
                            operation_error_count <= '0;
                            endurance_error_count <= '0;
                            last_error_addr_reg <= '0;
                            last_error_code_reg <= '0;
                        end
                    end
                    
                    6'h09: begin  // Endurance Limits Register (0x24) - Only warning threshold writable
                        // Only allow writing to warning threshold field [15:8]
                        // Keep max_cycles read-only as it's a hardware parameter
                        endurance_limits_reg[15:8] <= write_data_reg[15:8];
                    end
                    
                    default: begin
                        // Other registers are read-only or not implemented
                        // Could add debug functionality here if needed
                    end
                endcase
            end
        end
    end

endmodule