// reram_core.sv
// Controller for a 2D array of ReRAM cells

`timescale 1ns / 1ps

module reram_core #(
    parameter ROWS = 8,
    parameter COLS = 8,
    parameter ADDR_WIDTH = $clog2(ROWS * COLS), // Calculate address width needed
    parameter LRS_VAL = 1'b0,
    parameter HRS_VAL = 1'b1,
    parameter CELL_SET_DELAY_CYCLES = 10,
    parameter CELL_RESET_DELAY_CYCLES = 10,
    parameter CELL_ENDURANCE_LIMIT = 1000
) (
    input wire clk,
    input wire rst_n,
    input wire [ADDR_WIDTH-1:0] addr, // Address of the cell to access
    input wire data_in,      // Data to write (0 or 1)
    input wire write_en,     // Trigger a write (from external controller)
    input wire read_en,      // Trigger a read (from external controller)
    output wire data_out,    // Data read from the selected cell
    output wire busy,        // Core is busy if a write is in progress
    output wire [ROWS*COLS-1:0] all_failed_cells // A bitmask showing which cells have failed
);

    // Internal wires to connect to the ReRAM cells (flattened 2D array into 1D)
    wire [ROWS*COLS-1:0] cell_read_data; // All cells' read outputs
    wire [ROWS*COLS-1:0] cell_busy;      // All cells' busy flags
    wire [ROWS*COLS-1:0] cell_failed;    // All cells' failed flags

    // Registers for the core's internal FSM
    reg selected_cell_write_en;   // Write enable signal to pass to the *selected* cell
    reg selected_cell_target_state; // Target state to pass to the *selected* cell
    reg [ADDR_WIDTH-1:0] current_op_addr; // Stores the address for the current operation

    // Core FSM states
    localparam CORE_IDLE = 2'b00;
    localparam CORE_START_WRITE = 2'b01; // Assert write_en for one cycle
    localparam CORE_WAIT_WRITE_COMPLETE = 2'b11;
    localparam CORE_READING = 2'b10;
    reg [1:0] core_fsm_state;

    // Core is busy if its FSM is not IDLE
    assign busy = (core_fsm_state != CORE_IDLE);

    // The 'all_failed_cells' output directly corresponds to the 'cell_failed' array
    assign all_failed_cells = cell_failed;

    // This block generates the write_en and target_state signals for each cell.
    // By default, no cell receives write_en. Only the currently addressed cell,
    // when 'selected_cell_write_en' from the FSM is high, gets its 'write_en' asserted.
    reg [ROWS*COLS-1:0] cell_write_en_local;       // Local signal for individual cell write_en
    reg [ROWS*COLS-1:0] cell_target_state_local;   // Local signal for individual cell target_state

    // Combinational logic: Updates `cell_write_en_local` and `cell_target_state_local` based on `current_op_addr`
    always_comb begin
        cell_write_en_local = '0; // Default all to 0 (no write)
        cell_target_state_local = '0; // Default all to 0

        // If core controller decides to write and address is valid, activate signals for that specific cell
        if (selected_cell_write_en && current_op_addr < (ROWS * COLS)) begin
            cell_write_en_local[current_op_addr] = 1'b1; // Assert write_en for the selected cell
            cell_target_state_local[current_op_addr] = selected_cell_target_state; // Pass target state
        end
    end

    // This `generate` block instantiates (creates) all the individual ReRAM cells.
    genvar row_idx, col_idx; // Loop variables for generate block (compile-time constants)
    for (row_idx = 0; row_idx < ROWS; row_idx = row_idx + 1) begin : row_inst
        for (col_idx = 0; col_idx < COLS; col_idx = col_idx + 1) begin : col_inst
            localparam CELL_INDEX = row_idx * COLS + col_idx; // Calculate the 1D index for this cell

            // Instantiate a single ReRAM cell
            reram_cell #(
                .LRS_STATE(LRS_VAL),
                .HRS_STATE(HRS_VAL),
                .SET_DELAY_CYCLES(CELL_SET_DELAY_CYCLES),
                .RESET_DELAY_CYCLES(CELL_RESET_DELAY_CYCLES),
                .ENDURANCE_LIMIT(CELL_ENDURANCE_LIMIT)
            ) u_reram_cell ( // Name of this specific cell instance
                .clk(clk),
                .rst_n(rst_n),
                .write_en(cell_write_en_local[CELL_INDEX]),    // Connect to the local write_en signal
                .target_state(cell_target_state_local[CELL_INDEX]), // Connect to the local target_state signal
                .read_data(cell_read_data[CELL_INDEX]),        // Connect to the cell's output
                .busy(cell_busy[CELL_INDEX]),                  // Connect to the cell's busy flag
                .failed(cell_failed[CELL_INDEX])               // Connect to the cell's failed flag
            );
        end
    end

    // Combinational logic for the data_out (read data)
    reg data_out_reg; // Internal register to hold the read data
    assign data_out = data_out_reg; // Connect the register to the output wire

    always_comb begin
        data_out_reg = HRS_VAL; // Default value (e.g., if address invalid or not yet read)
        // If the current operation address is within bounds, read the data from the corresponding cell
        // This is updated continuously, even if core_fsm_state is not CORE_READING
        if (current_op_addr < (ROWS * COLS)) begin
            data_out_reg = cell_read_data[current_op_addr]; // Read from the selected cell
        end
    end

    // Main Controller FSM (Sequential Logic)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin // Reset condition
            core_fsm_state <= CORE_IDLE;
            current_op_addr <= 0;
            selected_cell_write_en <= 1'b0;
            selected_cell_target_state <= 1'b0;
            $display("Time %0t: ReRAM Core RESET.", $time);
        end else begin // Normal operation
            case (core_fsm_state)
                CORE_IDLE: begin // Core is ready for new command
                    selected_cell_write_en <= 1'b0; // Ensure no write is currently active

                    if (write_en) begin // If write command received
                        if (addr >= (ROWS * COLS)) begin // Check for invalid address
                            $display("Time %0t: Core (IDLE): ERROR: Write attempt to invalid address %0d. Ignoring.", $time, addr);
                        end else if (cell_failed[addr]) begin // Check if target cell has failed
                            $display("Time %0t: Core (IDLE): WARNING: Write attempt to FAILED cell at address %0d. Ignoring.", $time, addr);
                            // Stay in IDLE, do not proceed with write
                        end else begin
                            current_op_addr <= addr; // Latch the address
                            selected_cell_target_state <= data_in; // Latch the data to write
                            core_fsm_state <= CORE_START_WRITE; // Move to START_WRITE state
                            $display("Time %0t: Core (IDLE->START_WRITE): Latching write command for Addr %0d, Data %b", $time, addr, data_in);
                        end
                    end else if (read_en) begin // If read command received
                        if (addr >= (ROWS * COLS)) begin // Check for invalid address
                            $display("Time %0t: Core (IDLE): ERROR: Read attempt from invalid address %0d. Ignoring.", $time, addr);
                            // Stay in IDLE, data_out will be default HRS_VAL
                        end else begin
                            current_op_addr <= addr; // Latch the address
                            core_fsm_state <= CORE_READING; // Move to READING state
                            $display("Time %0t: Core (IDLE->READING): Latching read command for Addr %0d", $time, addr);
                        end
                    end
                end
                CORE_START_WRITE: begin // Assert write_en for one cycle to trigger cell's FSM
                    selected_cell_write_en <= 1'b1; // Assert write_en for the selected cell
                    core_fsm_state <= CORE_WAIT_WRITE_COMPLETE; // Transition to wait state
                    $display("Time %0t: Core (START_WRITE->WAIT_WRITE_COMPLETE): Asserting write_en for Addr %0d", $time, current_op_addr);
                end
                CORE_WAIT_WRITE_COMPLETE: begin // Core is waiting for the cell to finish writing
                    // Keep selected_cell_write_en asserted during the wait, in case the cell needs it held
                    selected_cell_write_en <= 1'b1;

                    // Check if the selected cell is no longer busy
                    // This check happens AFTER reram_cell has had a chance to react and go busy
                    if (!cell_busy[current_op_addr]) begin
                        core_fsm_state <= CORE_IDLE; // Cell finished, go back to IDLE
                        selected_cell_write_en <= 1'b0; // De-assert write_en for the cell
                        $display("Time %0t: Core (WAIT_WRITE_COMPLETE->IDLE): Write to Addr %0d completed.", $time, current_op_addr);
                    end else begin
                        $display("Time %0t: Core (WAIT_WRITE_COMPLETE): Waiting for Addr %0d (Cell Busy)", $time, current_op_addr);
                    end
                end
                CORE_READING: begin // Core is performing a read
                    // Read is combinational, data_out is already set by the always_comb block based on current_op_addr
                    core_fsm_state <= CORE_IDLE; // Ready immediately after latching address
                    $display("Time %0t: Core (READING->IDLE): Read from Addr %0d done. Data: %b", $time, current_op_addr, data_out);
                end
                default: begin
                    core_fsm_state <= CORE_IDLE;
                    $display("Time %0t: Core (DEFAULT->IDLE): Invalid state encountered. Resetting FSM.", $time);
                end
            endcase
        end
    end

endmodule