/*
 * ReRAM Cell
 * 
 * This module emulates a ReRAM cell focused purely on memory operations.
 * This does not implement compute functionality
 * 
 * Features:
 * - Command-based interface with cell-level addressing
 * - Read operation with configurable delay
 * - Write operations (SET/RESET) with configurable delays  
 * - Binary resistance states (HRS/LRS)
 * - Error reporting
 * - Write cycle endurance tracking
 * 
 * Interface:
 * - Command input specifies operation type (NOP/READ/WRITE)
 * - Cell enable provides individual cell addressing
 * - Cell state output shows LRS=1, HRS=0 for intuitive logic
 */

module reram_cell_simple #(
    parameter int READ_DELAY_CYCLES = 3,     // Cycles for read operation
    parameter int SET_DELAY_CYCLES = 10,     // Cycles for LRS transition
    parameter int RESET_DELAY_CYCLES = 10,   // Cycles for HRS transition
    parameter int MAX_WRITE_CYCLES = 255,    // Maximum write endurance (8-bit)
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // Command interface
    input  logic [1:0]  command,         // 00=NOP, 01=READ, 10=write
    input  logic        cell_enable,     // Cell addressing enable
    input  logic        data_in,         // 1-bit data input for write
    
    // Memory status outputs
    output logic        read_success,    // Read completed (1 cycle pulse)
    output logic        write_success,   // Write completed (1 cycle pulse)
    output logic        data_out,        // 1-bit data output
    output logic        cell_state,      // Cell state: 1=LRS, 0=HRS
    output logic [7:0]  write_cycles,    // Total write cycles performed (8-bit)
    
    // Error reporting
    output logic [1:0]  error_code,     // 00=no error, 01=busy, 10=worn out
    output logic        error_flag      // Error occurred flag
);

    // Command definitions
    localparam [1:0] CMD_NOP   = 2'b00;  // No operation
    localparam [1:0] CMD_READ  = 2'b01;  // Read operation
    localparam [1:0] CMD_WRITE = 2'b10;  // Write operation

    // Error code definitions
    localparam [1:0] ERR_NONE     = 2'b00;  // No error
    localparam [1:0] ERR_BUSY     = 2'b01;  // Cell busy
    localparam [1:0] ERR_WORN_OUT = 2'b10;  // Cell worn out

    typedef enum logic [1:0] {
        IDLE,
        READING,
        WRITING_SET,      // Transitioning to LRS (lower resistance)
        WRITING_RESET     // Transitioning to HRS (higher resistance)
    } cell_state_t;
    
    // Internal registers
    cell_state_t current_state, next_state;
    logic [31:0] delay_counter;
    logic [7:0]  write_counter;           // 8-bit write counter
    logic        internal_cell_state;     // 1 = LRS, 0 = HRS (same as output)
    logic        internal_data_out;
    
    // Command processing
    logic        active_read_cmd, active_write_cmd;
    
    // Operation tracking
    logic [31:0] target_delay;
    logic operation_complete;
    
    // Success pulse generation
    logic read_success_reg, read_success_next;
    logic write_success_reg, write_success_next;
    
    // Error tracking
    logic [1:0] current_error_code;
    logic current_error_flag;

    //==========================================================================
    // Command Processing
    //==========================================================================
    
    // Only respond to commands when cell is enabled
    always_comb begin
        active_read_cmd  = cell_enable && (command == CMD_READ);
        active_write_cmd = cell_enable && (command == CMD_WRITE);
    end

    //==========================================================================
    // State Machine Logic
    //==========================================================================
    
    always_comb begin
        next_state = current_state;
        operation_complete = 1'b0;
        target_delay = 0;
        current_error_code = ERR_NONE;
        current_error_flag = 1'b0;
        
        case (current_state)
            IDLE: begin
                // Check for worn out condition first
                if (write_counter >= MAX_WRITE_CYCLES) begin
                    current_error_code = ERR_WORN_OUT;
                    current_error_flag = 1'b1;
                end else if (active_read_cmd || active_write_cmd) begin
                    // Check for simultaneous operations (busy condition)
                    if (active_read_cmd && active_write_cmd) begin
                        current_error_code = ERR_BUSY;
                        current_error_flag = 1'b1;
                    end else if (active_read_cmd) begin
                        next_state = READING;
                        target_delay = READ_DELAY_CYCLES;
                    end else if (active_write_cmd && write_counter < MAX_WRITE_CYCLES) begin
                        if (data_in == 1'b1) begin
                            next_state = WRITING_SET;    // Switch to LRS
                            target_delay = SET_DELAY_CYCLES;
                        end else begin
                            next_state = WRITING_RESET;  // Switch to HRS  
                            target_delay = RESET_DELAY_CYCLES;
                        end
                    end
                end
            end
            
            READING, WRITING_SET, WRITING_RESET: begin
                // Cell is busy - check if someone is trying to start new operations
                if (active_read_cmd || active_write_cmd) begin
                    current_error_code = ERR_BUSY;
                    current_error_flag = 1'b1;
                end
                
                // Handle state transitions based on delays
                case (current_state)
                    READING: begin
                        if (delay_counter >= READ_DELAY_CYCLES) begin
                            next_state = IDLE;
                            operation_complete = 1'b1;
                        end
                    end
                    WRITING_SET, WRITING_RESET: begin
                        if (delay_counter >= target_delay) begin
                            next_state = IDLE;
                            operation_complete = 1'b1;
                        end
                    end
                endcase
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    //==========================================================================
    // Sequential Logic
    //==========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            delay_counter <= 0;
            write_counter <= 0;
            internal_cell_state <= 1'b0;     // Start in HRS (cell_state = 0)
            internal_data_out <= 1'b0;
            read_success_reg <= 1'b0;
            write_success_reg <= 1'b0;
        end else begin
            current_state <= next_state;
            read_success_reg <= read_success_next;
            write_success_reg <= write_success_next;
            
            // Delay counter management
            if (current_state == IDLE || (current_state != next_state)) begin
                delay_counter <= 0;
            end else begin
                delay_counter <= delay_counter + 1;
            end
            
            // Handle operation completion
            if (operation_complete) begin
                case (current_state)
                    READING: begin
                        internal_data_out <= internal_cell_state;  // Output cell state directly
                    end
                    WRITING_SET: begin
                        internal_cell_state <= 1'b1;  // Switch to LRS (cell_state = 1)
                        // Increment with overflow protection
                        if (write_counter < 8'hFF) begin
                            write_counter <= write_counter + 1;
                        end
                    end
                    WRITING_RESET: begin
                        internal_cell_state <= 1'b0;  // Switch to HRS (cell_state = 0)
                        // Increment with overflow protection
                        if (write_counter < 8'hFF) begin
                            write_counter <= write_counter + 1;
                        end
                    end
                endcase
            end
        end
    end

    //==========================================================================
    // Success Pulse Generation
    //==========================================================================
    
    always_comb begin
        read_success_next = 1'b0;
        write_success_next = 1'b0;
        
        if (operation_complete) begin
            case (current_state)
                READING: begin
                    read_success_next = 1'b1;
                end
                WRITING_SET, WRITING_RESET: begin
                    write_success_next = 1'b1;
                end
            endcase
        end
    end
    
    //==========================================================================
    // Output Assignments
    //==========================================================================
    
    // Memory operation signals
    assign read_success = read_success_reg;
    assign write_success = write_success_reg;
    
    // Memory data outputs
    assign data_out = internal_data_out;
    assign cell_state = internal_cell_state;
    assign write_cycles = write_counter;
    
    // Error reporting
    assign error_code = current_error_code;
    assign error_flag = current_error_flag;

endmodule