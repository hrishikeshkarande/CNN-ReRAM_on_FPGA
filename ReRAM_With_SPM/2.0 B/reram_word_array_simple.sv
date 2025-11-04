/*
 * Simple ReRAM Word Array - Memory Only
 * 
 * This module instantiates WORD_WIDTH ReRAM cells to create a single word
 * of memory with standard read/write operations only. No compute functionality.
 * 
 * Features:
 * - Standard memory read/write operations for entire words
 * - Parallel cell coordination for word-level operations
 * - Error aggregation from all cells
 * - Simple, clean interface focused on memory functionality
 * 
 * Removed from enhanced version:
 * - All multiplication/MAC functionality
 * - Bit-serial processing logic
 * - Compute-related state machine complexity
 */

module reram_word_array_simple #(
    parameter int WORD_WIDTH = 32,           // Bits per word (matches system register width)
    parameter int READ_DELAY_CYCLES = 3,     // Cell read delay
    parameter int SET_DELAY_CYCLES = 10,     // Cell SET delay  
    parameter int RESET_DELAY_CYCLES = 10,   // Cell RESET delay
    parameter int MAX_WRITE_CYCLES = 200     // Cell endurance limit (8-bit range)
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // Command-based memory interface
    input  logic [1:0]              command,        // 00=NOP, 01=READ, 10=WRITE
    input  logic                    word_enable,    // Word addressing enable
    input  logic [WORD_WIDTH-1:0]  write_data,     // Word data to write
    output logic [WORD_WIDTH-1:0]  read_data,      // Word data read
    output logic                    operation_complete, // Memory op done
    
    // Status and error reporting
    output logic                    word_busy,       // Any cell is busy
    output logic [WORD_WIDTH-1:0]  cell_error_flags,// Per-cell error flags
    output logic                    word_error,      // Any cell has error
    output logic [7:0]              total_write_cycles // Max of all cell write cycles (8-bit)
);

    // Command definitions (consistent with cell-level interface)
    localparam [1:0] CMD_NOP   = 2'b00;  // No operation
    localparam [1:0] CMD_READ  = 2'b01;  // Read operation
    localparam [1:0] CMD_WRITE = 2'b10;  // Write operation

    // Internal signals for cell array
    logic [1:0] cell_command;
    logic [WORD_WIDTH-1:0] cell_enables;
    logic [WORD_WIDTH-1:0] cell_data_in;
    logic [WORD_WIDTH-1:0] cell_data_out;
    logic [WORD_WIDTH-1:0] cell_read_success;
    logic [WORD_WIDTH-1:0] cell_write_success;
    logic [WORD_WIDTH-1:0] cell_error_flag;
    logic [WORD_WIDTH-1:0] cell_states;
    logic [7:0] cell_write_cycles [WORD_WIDTH-1:0]; // Array to store each cell's write cycles
    logic [1:0] cell_error_codes [WORD_WIDTH-1:0];  // Array to store each cell's error codes
    
    // Simplified word-level operation state machine (memory only)
    typedef enum logic [1:0] {
        WORD_IDLE,
        WORD_READING,
        WORD_WRITING
    } word_state_t;
    
    word_state_t current_word_state, next_word_state;
    
    // Status aggregation  
    logic any_cell_busy;
    logic all_read_complete;
    logic all_write_complete;
    
    // Registered command signals for proper timing
    logic [1:0] cell_command_reg;
    logic [WORD_WIDTH-1:0] cell_enables_reg;

    //==========================================================================
    // ReRAM Cell Array Instantiation
    //==========================================================================
    
    genvar i;
    generate
        for (i = 0; i < WORD_WIDTH; i++) begin : cell_instances
            reram_cell_simple #(
                .READ_DELAY_CYCLES(READ_DELAY_CYCLES),
                .SET_DELAY_CYCLES(SET_DELAY_CYCLES),
                .RESET_DELAY_CYCLES(RESET_DELAY_CYCLES),
                .MAX_WRITE_CYCLES(MAX_WRITE_CYCLES)
            ) cell_inst (
                .clk(clk),
                .rst_n(rst_n),
                
                // Command interface
                .command(cell_command_reg),
                .cell_enable(cell_enables_reg[i]),
                .data_in(cell_data_in[i]),
                
                // Individual cell outputs
                .read_success(cell_read_success[i]),
                .write_success(cell_write_success[i]),
                .data_out(cell_data_out[i]),
                .cell_state(cell_states[i]),
                .write_cycles(cell_write_cycles[i]),
                .error_code(cell_error_codes[i]),
                .error_flag(cell_error_flag[i])
            );
        end
    endgenerate

    //==========================================================================
    // Simplified Word-Level State Machine (Memory Only)
    //==========================================================================
    
    always_comb begin
        next_word_state = current_word_state;
        
        case (current_word_state)
            WORD_IDLE: begin
                if (word_enable && !any_cell_busy) begin
                    case (command)
                        CMD_READ:  next_word_state = WORD_READING;
                        CMD_WRITE: next_word_state = WORD_WRITING;
                        default:   next_word_state = WORD_IDLE;  // CMD_NOP or invalid
                    endcase
                end
            end
            
            WORD_READING: begin
                if (all_read_complete) begin
                    next_word_state = WORD_IDLE;
                end
            end
            
            WORD_WRITING: begin
                if (all_write_complete) begin
                    next_word_state = WORD_IDLE;
                end
            end
            
            default: begin
                next_word_state = WORD_IDLE;
            end
        endcase
    end

    //==========================================================================
    // Simplified Cell Command Generation (Memory Only)
    //==========================================================================
    
    always_comb begin
        // Data assignment for write operations (combinational)
        cell_data_in = write_data;
    end

    //==========================================================================
    // Status Aggregation Logic
    //==========================================================================
    
    always_comb begin
        // The word is busy when not in IDLE state
        any_cell_busy = (current_word_state != WORD_IDLE);
        
        // Check completion of operations - all cells report success
        all_read_complete = &cell_read_success;      // All cells completed read
        all_write_complete = &cell_write_success;    // All cells completed write
        
        // Aggregate error flags
        word_error = |cell_error_flag;               // Any cell has error
    end

    //==========================================================================
    // Sequential Logic (Simplified)
    //==========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_word_state <= WORD_IDLE;
            cell_command_reg <= CMD_NOP;
            cell_enables_reg <= {WORD_WIDTH{1'b0}};
        end else begin
            // Update state
            current_word_state <= next_word_state;
            
            // Generate command pulse on state transitions FROM IDLE
            if (current_word_state == WORD_IDLE && next_word_state != WORD_IDLE) begin
                // State transition from IDLE - send the command pulse
                case (next_word_state)
                    WORD_READING: cell_command_reg <= CMD_READ;
                    WORD_WRITING: cell_command_reg <= CMD_WRITE;
                    default:      cell_command_reg <= CMD_NOP;
                endcase
                
                // Enable all cells for the command pulse
                cell_enables_reg <= {WORD_WIDTH{1'b1}};
            end else begin
                // During operation or when idle - no commands
                cell_command_reg <= CMD_NOP;
                cell_enables_reg <= {WORD_WIDTH{1'b0}};
            end
        end
    end

    //==========================================================================
    // Output Assignments
    //==========================================================================
    
    // Memory interface outputs
    assign read_data = cell_data_out;
    assign operation_complete = (current_word_state == WORD_READING && all_read_complete) ||
                               (current_word_state == WORD_WRITING && all_write_complete);
    
    // Status outputs
    assign word_busy = (current_word_state != WORD_IDLE);
    assign cell_error_flags = cell_error_flag;
    
    // Calculate total write cycles (find maximum among all cells)
    always_comb begin
        total_write_cycles = 8'h00;
        for (int n = 0; n < WORD_WIDTH; n++) begin
            // Find maximum write cycles among all cells
            if (cell_write_cycles[n] > total_write_cycles) begin
                total_write_cycles = cell_write_cycles[n];
            end
        end
    end

endmodule