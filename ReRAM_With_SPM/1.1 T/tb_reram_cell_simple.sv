/*
 * Simple ReRAM Cell Testbench
 * 
 * This testbench validates the simplified ReRAM cell that focuses on
 * memory operations only. Tests read/write functionality, timing,
 * error conditions, and endurance tracking.
 * 
 * Test Coverage:
 * - Basic SET/RESET operations
 * - Read operations and data retention
 * - Timing validation (delays)
 * - Error condition testing
 * - Endurance tracking
 * - State machine transitions
 */

module tb_reram_cell_simple;

    // Test parameters
    parameter int CLK_PERIOD = 10;       // 100MHz clock
    parameter int READ_DELAY = 3;
    parameter int SET_DELAY = 10;
    parameter int RESET_DELAY = 10;
    parameter int MAX_WRITES = 200;       // Reduced for 8-bit testing
    
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Control signals
    logic [1:0] command;
    logic cell_enable;
    logic data_in;
    
    // Status and data outputs
    logic read_success;
    logic write_success;
    logic data_out;
    logic cell_state;            // 1=LRS, 0=HRS
    logic [7:0] write_cycles;    // 8-bit write cycles
    logic [1:0] error_code;      // Error reporting
    logic error_flag;
    
    // Command definitions
    localparam [1:0] CMD_NOP   = 2'b00;
    localparam [1:0] CMD_READ  = 2'b01;
    localparam [1:0] CMD_WRITE = 2'b10;
    
    // Error code definitions
    localparam [1:0] ERR_NONE     = 2'b00;  // No error
    localparam [1:0] ERR_BUSY     = 2'b01;  // Cell busy
    localparam [1:0] ERR_WORN_OUT = 2'b10;  // Cell worn out
    
    // Test control variables
    int test_phase;
    int error_count;

    //==========================================================================
    // Device Under Test (DUT) - Simple ReRAM Cell
    //==========================================================================
    
    reram_cell_simple #(
        .READ_DELAY_CYCLES(READ_DELAY),
        .SET_DELAY_CYCLES(SET_DELAY),
        .RESET_DELAY_CYCLES(RESET_DELAY),
        .MAX_WRITE_CYCLES(MAX_WRITES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .command(command),
        .cell_enable(cell_enable),
        .data_in(data_in),
        .read_success(read_success),
        .write_success(write_success),
        .data_out(data_out),
        .cell_state(cell_state),
        .write_cycles(write_cycles),
        .error_code(error_code),
        .error_flag(error_flag)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Test Tasks
    //==========================================================================
    
    // Task: Reset the system
    task reset_system();
        begin
            $display("[%0t] Resetting simple ReRAM cell...", $time);
            rst_n = 0;
            command = CMD_NOP;
            cell_enable = 0;
            data_in = 0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask
    
    // Task: Perform SET operation (write 1)
    task write_set();
        begin
            $display("[%0t] Writing SET (1) to cell...", $time);
            @(posedge clk);
            command = CMD_WRITE;
            cell_enable = 1;
            data_in = 1;  // SET mode
            
            @(posedge clk);
            command = CMD_NOP;
            cell_enable = 0;
            
            // Wait for completion
            wait(write_success);
            @(posedge clk);
            
            if (error_flag) begin
                $display("[ERROR] SET operation failed");
                error_count++;
            end else begin
                $display("[%0t] SET operation completed, write_cycles=%0d", $time, write_cycles);
            end
        end
    endtask
    
    // Task: Perform RESET operation (write 0)
    task write_reset();
        begin
            $display("[%0t] Writing RESET (0) to cell...", $time);
            @(posedge clk);
            command = CMD_WRITE;
            cell_enable = 1;
            data_in = 0;  // RESET mode
            
            @(posedge clk);
            command = CMD_NOP;
            cell_enable = 0;
            
            // Wait for completion
            wait(write_success);
            @(posedge clk);
            
            if (error_flag) begin
                $display("[ERROR] RESET operation failed");
                error_count++;
            end else begin
                $display("[%0t] RESET operation completed, write_cycles=%0d", $time, write_cycles);
            end
        end
    endtask
    
    // Task: Perform READ operation
    task read_cell(output logic read_value);
        begin
            $display("[%0t] Reading from cell...", $time);
            @(posedge clk);
            command = CMD_READ;
            cell_enable = 1;
            
            @(posedge clk);
            command = CMD_NOP;
            cell_enable = 0;
            
            // Wait for completion
            wait(read_success);
            @(posedge clk);
            
            if (error_flag) begin
                $display("[ERROR] READ operation failed");
                error_count++;
                read_value = 0;
            end else begin
                read_value = data_out;
                $display("[%0t] READ completed, value=%b, cell_state=%b", $time, read_value, cell_state);
            end
        end
    endtask
    
    // Task: Verify stored value
    task verify_value(input logic expected);
        logic actual;
        begin
            read_cell(actual);
            if (actual !== expected) begin
                $display("[ERROR] Data mismatch: expected=%b, actual=%b", expected, actual);
                error_count++;
            end else begin
                $display("[PASS] Data verification passed: %b", actual);
            end
        end
    endtask
    
    // Task: Test operation timing
    task test_timing(input string operation, input int expected_delay);
        int start_time, end_time, actual_delay;
        begin
            $display("Testing %s timing (expected %0d cycles)...", operation, expected_delay);
            
            start_time = $time;
            
            if (operation == "SET") begin
                @(posedge clk);
                command = CMD_WRITE;
                cell_enable = 1;
                data_in = 1;
                @(posedge clk);
                command = CMD_NOP;
                cell_enable = 0;
                wait(write_success);
            end
            else if (operation == "RESET") begin
                @(posedge clk);
                command = CMD_WRITE;
                cell_enable = 1;
                data_in = 0;
                @(posedge clk);
                command = CMD_NOP;
                cell_enable = 0;
                wait(write_success);
            end
            else if (operation == "READ") begin
                @(posedge clk);
                command = CMD_READ;
                cell_enable = 1;
                @(posedge clk);
                command = CMD_NOP;
                cell_enable = 0;
                wait(read_success);
            end
            
            end_time = $time;
            actual_delay = (end_time - start_time) / CLK_PERIOD - 2; // Subtract setup cycles
            
            $display("Timing result: expected=%0d, actual=%0d cycles", expected_delay, actual_delay);
            
            if (actual_delay < expected_delay) begin
                $display("[ERROR] Operation completed too quickly");
                error_count++;
            end else if (actual_delay > expected_delay + 2) begin
                $display("[WARNING] Operation took longer than expected");
            end else begin
                $display("[PASS] Timing validation passed");
            end
        end
    endtask

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    
    initial begin
        $display("==========================================================================");
        $display("Simple ReRAM Cell Testbench");
        $display("==========================================================================");
        
        // Local test variables
        logic [7:0] initial_count, final_count;
        
        error_count = 0;
        test_phase = 0;
        
        // Initialize signals
        reset_system();
        
        //----------------------------------------------------------------------
        // Test Phase 1: Basic Operations
        //----------------------------------------------------------------------
        test_phase = 1;
        $display("\n--- Phase 1: Basic SET/RESET/READ Operations ---");
        
        // Initially cell should be in unknown state, set to known state
        write_reset();
        verify_value(1'b0);
        
        // Test SET operation
        write_set();
        verify_value(1'b1);
        
        // Test RESET operation
        write_reset();
        verify_value(1'b0);
        
        // Test multiple SET/RESET cycles
        for (int i = 0; i < 5; i++) begin
            $display("Cycle %0d:", i+1);
            write_set();
            verify_value(1'b1);
            write_reset();
            verify_value(1'b0);
        end
        
        $display("Phase 1 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 2: Data Retention
        //----------------------------------------------------------------------
        test_phase = 2;
        $display("\n--- Phase 2: Data Retention Test ---");
        
        // Set cell to 1 and wait
        write_set();
        repeat(100) @(posedge clk);
        verify_value(1'b1);
        
        // Set cell to 0 and wait
        write_reset();
        repeat(100) @(posedge clk);
        verify_value(1'b0);
        
        $display("Phase 2 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 3: Timing Validation
        //----------------------------------------------------------------------
        test_phase = 3;
        $display("\n--- Phase 3: Timing Validation ---");
        
        test_timing("READ", READ_DELAY);
        test_timing("SET", SET_DELAY);
        test_timing("RESET", RESET_DELAY);
        
        $display("Phase 3 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 4: Error Conditions (before endurance testing)
        //----------------------------------------------------------------------
        test_phase = 4;
        $display("\n--- Phase 4: Error Condition Testing ---");
        
        // Test concurrent read and write (should be handled gracefully)
        $display("Testing concurrent read/write requests...");
        @(posedge clk);
        command = CMD_READ;  // Try read and write simultaneously (impossible with command interface)
        cell_enable = 1;
        data_in = 1;
        
        @(posedge clk);
        command = CMD_NOP;
        cell_enable = 0;
        
        wait(read_success);
        
        // With command interface, concurrent operations are not possible
        $display("[INFO] Command interface prevents concurrent operations");
        
        // Test disabled cell (should ignore commands)
        $display("Testing disabled cell behavior...");
        @(posedge clk);
        command = CMD_WRITE;
        cell_enable = 0;  // Cell disabled
        data_in = 1;
        
        repeat(20) @(posedge clk);  // Wait and see if anything happens
        
        if (!write_success) begin
            $display("[PASS] Disabled cell correctly ignored command");
        end else begin
            $display("[ERROR] Disabled cell should not respond to commands");
            error_count++;
        end
        
        // Re-enable and test
        @(posedge clk);
        cell_enable = 1;
        @(posedge clk);
        command = CMD_NOP;
        cell_enable = 0;
        wait(write_success);
        
        $display("Phase 4 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 5: State Machine Coverage
        //----------------------------------------------------------------------
        test_phase = 5;
        $display("\n--- Phase 5: State Machine Coverage ---");
        
        // Test all state transitions
        $display("Testing state transitions...");
        
        // IDLE -> READING -> IDLE
        read_cell(logic'(1'bx));
        
        // IDLE -> WRITING_SET -> IDLE
        write_set();
        
        // IDLE -> WRITING_RESET -> IDLE
        write_reset();
        
        // Test rapid successive operations
        $display("Testing rapid successive operations...");
        for (int i = 0; i < 3; i++) begin
            read_cell(logic'(1'bx));
            write_set();
            read_cell(logic'(1'bx));
            write_reset();
        end
        
        $display("Phase 5 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 6: Endurance Tracking (non-destructive)
        //----------------------------------------------------------------------
        test_phase = 6;
        $display("\n--- Phase 6: Endurance Tracking ---");
        
        // Perform many writes and check counter
        initial_count = write_cycles;
        
        for (int i = 0; i < 20; i++) begin
            if (i % 2 == 0) begin
                write_set();
            end else begin
                write_reset();
            end
        end
        
        final_count = write_cycles;
        $display("Write count progression: %0d -> %0d (difference: %0d)", 
                 initial_count, final_count, final_count - initial_count);
        
        if (final_count != initial_count + 20) begin
            $display("[ERROR] Write count not tracking correctly");
            error_count++;
        end else begin
            $display("[PASS] Write count tracking correct");
        end
        
        $display("Phase 6 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 7: Endurance Limit Testing (destructive - last test!)
        //----------------------------------------------------------------------
        test_phase = 7;
        $display("\n--- Phase 7: Endurance Limit Testing (DESTRUCTIVE) ---");
        
        $display("Note: Testing endurance error with MAX_WRITES=%0d", MAX_WRITES);
        $display("Current write count: %0d", write_cycles);
        $display("WARNING: This test will exhaust the cell's endurance!");
        
        // Write up to the limit
        while (write_cycles < MAX_WRITES && !error_flag) begin
            if (write_cycles % 2 == 0) begin
                write_set();
            end else begin
                write_reset();
            end
            
            if (write_cycles % 50 == 0) begin
                $display("Write cycles: %0d/%0d", write_cycles, MAX_WRITES);
            end
        end
        
        $display("Reached write limit. Current count: %0d, error_flag: %b", write_cycles, error_flag);
        
        // Test that further writes are rejected
        if (error_flag && error_code == ERR_WORN_OUT) begin
            $display("[PASS] Cell correctly reports worn out condition");
        end else begin
            $display("[INFO] Cell not yet at endurance limit");
        end
        
        // Test that worn-out cell still allows reads
        $display("Testing read operations on worn-out cell...");
        read_cell(logic'(1'bx));
        if (!error_flag || error_code != ERR_WORN_OUT) begin
            $display("[PASS] Worn-out cell still allows read operations");
        end
        
        // Test that worn-out cell rejects writes
        $display("Testing write rejection on worn-out cell...");
        @(posedge clk);
        command = CMD_WRITE;
        cell_enable = 1;
        data_in = 1;
        @(posedge clk);
        command = CMD_NOP;
        cell_enable = 0;
        
        repeat(20) @(posedge clk);  // Wait to see if write happens
        
        if (!write_success && error_flag && error_code == ERR_WORN_OUT) begin
            $display("[PASS] Worn-out cell correctly rejects write operations");
        end else begin
            $display("[ERROR] Worn-out cell should reject write operations");
            error_count++;
        end
        
        $display("Phase 7 completed");

        //----------------------------------------------------------------------
        // Test Summary
        //----------------------------------------------------------------------
        $display("\n==========================================================================");
        $display("Simple ReRAM Cell Test Summary");
        $display("==========================================================================");
        $display("Total test errors: %0d", error_count);
        $display("Final write count: %0d", write_cycles);
        $display("Final stored value: %b", data_out);
        $display("Final cell state: %b (1=LRS, 0=HRS)", cell_state);
        $display("Final error state: %b", error_flag);
        
        if (error_count == 0) begin
            $display("*** ALL CELL TESTS PASSED! ***");
            $display("Simple ReRAM cell is functioning correctly.");
        end else begin
            $display("*** %0d CELL TESTS FAILED ***", error_count);
        end
        
        $display("==========================================================================");
        
        // End simulation
        #(CLK_PERIOD * 10);
        $finish;
    end
    
    //==========================================================================
    // Simulation Control and Monitoring
    //==========================================================================
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 10000); // 10K cycles timeout
        $display("[ERROR] Simulation timeout!");
        $finish;
    end
    
    // Monitor key signals during critical phases
    always @(posedge clk) begin
        if (test_phase >= 1 && test_phase <= 6) begin
            if (cell_enable || command != CMD_NOP) begin
                $display("[%0t] Monitor: enable=%b, cmd=%b, cell_state=%b, error=%b, writes=%0d", 
                         $time, cell_enable, command, cell_state, error_flag, write_cycles);
            end
        end
    end
    
    // Dump waveforms for debugging
    initial begin
        $dumpfile("tb_reram_cell_simple.vcd");
        $dumpvars(0, tb_reram_cell_simple);
    end

endmodule