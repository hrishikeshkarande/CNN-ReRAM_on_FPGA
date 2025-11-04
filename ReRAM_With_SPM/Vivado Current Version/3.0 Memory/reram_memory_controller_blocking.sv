/*
 * Simple Blocking ReRAM Memory Controller
 * 
 * This is a straightforward memory controller that provides a simple blocking
 * interface to ReRAM memory. No queues, no transaction IDs, no complexity.
 * 
 * Features:
 * - Simple blocking memory interface (like traditional SRAM)
 * - Direct address/data/control signals
 * - Operation completes when done_o goes high
 * - Clean error reporting
 * - Built-in memory array (no separate memory array module needed)
 * - Auto-calculated address width based on memory depth
 * 
 * Parameters:
 * - MEMORY_DEPTH: Number of words in memory (e.g., 16 = 16 words = 64B)
 * - DATA_WIDTH: Width of each word in bits (default: 32-bit)
 * - ADDR_WIDTH: Auto-calculated as $clog2(MEMORY_DEPTH)
 * 
 * Examples:
 * - MEMORY_DEPTH=16     → ADDR_WIDTH=4 (64B memory)
 * - MEMORY_DEPTH=64     → ADDR_WIDTH=6 (256B memory)  
 * - MEMORY_DEPTH=256    → ADDR_WIDTH=8 (1KB memory)
 * 
 * Interface:
 * - addr_i[ADDR_WIDTH-1:0]: Address input
 * - data_i[31:0]: Write data
 * - data_o[31:0]: Read data  
 * - read_i: Start read operation
 * - write_i: Start write operation
 * - done_o: Operation complete
 * - error_o: Error occurred
 */

module reram_memory_controller_blocking #(
    parameter int MEMORY_DEPTH = 16,        // Number of words (default: 16 words = 64B) - Conservative for Z7-20
    parameter int DATA_WIDTH = 32,           // 32-bit data
    parameter int ADDR_WIDTH = $clog2(MEMORY_DEPTH), // Auto-calculated from memory depth
    parameter int READ_DELAY_CYCLES = 3,     
    parameter int SET_DELAY_CYCLES = 10,     
    parameter int RESET_DELAY_CYCLES = 10,   
    parameter int MAX_WRITE_CYCLES = 200
) (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Simple Memory Interface
    input  logic [ADDR_WIDTH-1:0]  addr_i,      // Address
    input  logic [DATA_WIDTH-1:0]  data_i,      // Write data
    output logic [DATA_WIDTH-1:0]  data_o,      // Read data
    input  logic                   read_i,      // Start read
    input  logic                   write_i,     // Start write
    output logic                   done_o,      // Operation complete
    output logic                   error_o,     // Error occurred
    output logic                   busy_o,      // Controller busy
    
    // Status (optional monitoring)
    output logic [31:0]            total_reads,     // Total reads performed
    output logic [31:0]            total_writes,    // Total writes performed
    output logic [MEMORY_DEPTH-1:0] word_errors,    // Per-word error flags
    
    // Enhanced endurance monitoring outputs
    output logic [7:0]             word_write_cycles [MEMORY_DEPTH-1:0], // Write cycles per word
    output logic [MEMORY_DEPTH-1:0] word_cell_errors_any,  // Any cell errors per word
    output logic [DATA_WIDTH-1:0]  word_cell_errors [MEMORY_DEPTH-1:0]   // Detailed cell error flags per word
);

    // Command encoding for word arrays
    localparam [1:0] CMD_NOP   = 2'b00;
    localparam [1:0] CMD_READ  = 2'b01;  
    localparam [1:0] CMD_WRITE = 2'b10;

    // Controller state machine
    typedef enum logic [2:0] {
        IDLE,           // Waiting for operation
        READING,        // Read in progress
        WRITING,        // Write in progress
        ERROR_STATE     // Invalid command combination
    } controller_state_t;
    
    controller_state_t state, next_state;
    
    // Word array interface signals
    logic [MEMORY_DEPTH-1:0]        word_enables;
    logic [1:0]                     word_command_reg;        // Registered command signal
    logic [DATA_WIDTH-1:0]          word_write_data;
    logic [MEMORY_DEPTH-1:0]        word_operation_complete;
    logic [MEMORY_DEPTH-1:0]        word_busy;
    logic [MEMORY_DEPTH-1:0]        word_error;
    
    // Multi-dimensional array for read data
    logic [DATA_WIDTH-1:0] word_read_data [MEMORY_DEPTH-1:0];
    
    // Enhanced endurance monitoring signals
    logic [7:0] word_total_write_cycles [MEMORY_DEPTH-1:0];
    logic [DATA_WIDTH-1:0] word_cell_error_flags [MEMORY_DEPTH-1:0];
    
    // Address decoding
    logic [ADDR_WIDTH-1:0] current_addr;
    logic valid_address;
    
    // Operation tracking
    logic operation_in_progress;
    logic [31:0] read_counter, write_counter;
    
    //==========================================================================
    // Word Array Instantiation
    //==========================================================================
    
    genvar i;
    generate
        for (i = 0; i < MEMORY_DEPTH; i++) begin : word_arrays
            reram_word_array_simple #(
                .WORD_WIDTH(DATA_WIDTH),
                .READ_DELAY_CYCLES(READ_DELAY_CYCLES),
                .SET_DELAY_CYCLES(SET_DELAY_CYCLES),
                .RESET_DELAY_CYCLES(RESET_DELAY_CYCLES),
                .MAX_WRITE_CYCLES(MAX_WRITE_CYCLES)
            ) word_array_inst (
                .clk(clk),
                .rst_n(rst_n),
                
                // Command interface
                .command(word_command_reg),
                .word_enable(word_enables[i]),
                .write_data(word_write_data),
                .read_data(word_read_data[i]),
                .operation_complete(word_operation_complete[i]),
                
                // Status
                .word_busy(word_busy[i]),
                .word_error(word_error[i]),
                .cell_error_flags(word_cell_error_flags[i]),    // Now monitored for endurance tracking
                .total_write_cycles(word_total_write_cycles[i]) // Now monitored for endurance tracking
            );
        end
    endgenerate
    
    //==========================================================================
    // Address Decoding
    //==========================================================================
    
    always_comb begin
        valid_address = (current_addr < MEMORY_DEPTH);
        
        // Generate word enables only when actively sending a command
        word_enables = '0;
        if (valid_address && operation_in_progress && (word_command_reg != CMD_NOP)) begin
            word_enables[current_addr] = 1'b1;
        end
    end
    
    //==========================================================================
    // State Machine
    //==========================================================================
    
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (read_i && !write_i) begin
                    next_state = READING;
                end else if (write_i && !read_i) begin
                    next_state = WRITING;
                end else if (read_i && write_i) begin
                    next_state = ERROR_STATE;  // Both asserted - invalid command
                end
                // If neither asserted, stay in IDLE
            end
            
            READING: begin
                if (valid_address && word_operation_complete[current_addr]) begin
                    next_state = IDLE;
                end else if (!valid_address) begin
                    next_state = IDLE;  // Invalid address, return to idle
                end
            end
            
            WRITING: begin
                if (valid_address && word_operation_complete[current_addr]) begin
                    next_state = IDLE;
                end else if (!valid_address) begin
                    next_state = IDLE;  // Invalid address, return to idle
                end
            end
            
            ERROR_STATE: begin
                // Return to IDLE after one cycle (immediate error completion)
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    //==========================================================================
    // Control Logic 
    //==========================================================================
    
    always_comb begin
        // operation_in_progress is combinational for enable generation
        operation_in_progress = (word_command_reg != CMD_NOP);
    end
    
    //==========================================================================
    // Output Logic
    //==========================================================================
    
    always_comb begin
        // Busy when not in IDLE state
        busy_o = (state != IDLE);
        
        // Done when operation completes, invalid address, or command error
        if (state == READING || state == WRITING) begin
            if (valid_address) begin
                done_o = word_operation_complete[current_addr];
            end else begin
                done_o = 1'b1;  // Invalid address completes immediately
            end
        end else if (state == ERROR_STATE) begin
            done_o = 1'b1;  // Invalid command completes immediately with error
        end else begin
            done_o = 1'b0;
        end
        
        // Error when invalid address, word error, or invalid command
        if (state == ERROR_STATE) begin
            error_o = 1'b1;  // Invalid command combination
        end else if (!valid_address && (state == READING || state == WRITING)) begin
            error_o = 1'b1;  // Invalid address
        end else if (valid_address && (state == READING || state == WRITING)) begin
            error_o = word_error[current_addr];  // Word-level error
        end else begin
            error_o = 1'b0;
        end
        
        // Output read data
        if (state == READING && valid_address) begin
            data_o = word_read_data[current_addr];
        end else begin
            data_o = '0;
        end
        
        // Status outputs
        word_errors = word_error;
        total_reads = read_counter;
        total_writes = write_counter;
        
        // Enhanced endurance monitoring outputs
        word_write_cycles = word_total_write_cycles;
        word_cell_errors = word_cell_error_flags;
        
        // Generate summary flags for any cell errors per word
        for (int w = 0; w < MEMORY_DEPTH; w++) begin
            word_cell_errors_any[w] = (word_cell_error_flags[w] != '0);
        end
    end
    
    //==========================================================================
    // Sequential Logic
    //==========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_addr <= '0;
            word_write_data <= '0;
            read_counter <= '0;
            write_counter <= '0;
            word_command_reg <= CMD_NOP;
        end else begin
            state <= next_state;
            
            // Latch address and data when starting operation
            if (state == IDLE) begin
                if (read_i || write_i) begin
                    current_addr <= addr_i;
                    word_write_data <= data_i;
                end
            end
            
            // Generate synchronous command pulses based on state transitions
            case (state)
                IDLE: begin
                    if (read_i && !write_i) begin
                        word_command_reg <= CMD_READ;   // Send READ command
                    end else if (write_i && !read_i) begin
                        word_command_reg <= CMD_WRITE;  // Send WRITE command
                    end else begin
                        word_command_reg <= CMD_NOP;    // No valid command
                    end
                end
                
                READING, WRITING: begin
                    // Clear command after one cycle - word array will handle the operation
                    word_command_reg <= CMD_NOP;
                end
                
                ERROR_STATE: begin
                    // No command for error state
                    word_command_reg <= CMD_NOP;
                end
                
                default: begin
                    word_command_reg <= CMD_NOP;
                end
            endcase
            
            // Update counters when operations complete
            if (done_o && !error_o) begin
                if (state == READING) begin
                    read_counter <= read_counter + 1;
                end else if (state == WRITING) begin
                    write_counter <= write_counter + 1;
                end
            end
        end
    end

endmodule