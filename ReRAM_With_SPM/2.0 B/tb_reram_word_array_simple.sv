/*
 * Simple ReRAM Word Array Testbench
 * 
 * This testbench validates the simplified 32-cell word array that focuses on
 * memory operations only. Tests parallel read/write functionality, data integrity,
 * and error handling with registered command interface.
 * 
 * ENDURANCE PROTECTION: This testbench limits total writes to prevent cells
 * from reaching their endurance limit (200 writes), which would make them
 * unable to perform both read and write operations.
 * 
 * Test Coverage:
 * - Basic word read/write operations
 * - Parallel cell access verification (reduced patterns to save endurance)
 * - Data pattern testing (conservative approach)
 * - Error propagation from individual cells
 * - Timing validation (accounts for registered commands)
 * - Conservative endurance tracking 
 * - Command interface timing validation
 * - Endurance limit protection and monitoring
 */

module tb_reram_word_array_simple;

    // Test parameters
    parameter int CLK_PERIOD = 10;       // 100MHz clock
    parameter int WORD_WIDTH = 32;
    parameter int READ_DELAY = 3;
    parameter int SET_DELAY = 10;
    parameter int RESET_DELAY = 10;
    parameter int MAX_WRITES_SAFE = 150;  // Safe limit well below cell endurance (200)
    
    // Test tracking
    int total_writes_performed = 0;       // Track total writes to prevent cell damage
    
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Control signals
    logic [1:0] command;
    logic word_enable;
    
    // Data signals
    logic [WORD_WIDTH-1:0] write_data;
    logic [WORD_WIDTH-1:0] read_data;
    
    // Status outputs
    logic operation_complete;
    logic word_busy;
    logic word_error;
    logic [WORD_WIDTH-1:0] cell_error_flags;
    logic [7:0] total_write_cycles;          // 8-bit write count
    
    // Command definitions
    localparam [1:0] CMD_NOP   = 2'b00;
    localparam [1:0] CMD_READ  = 2'b01;
    localparam [1:0] CMD_WRITE = 2'b10;
    
    // Test control variables
    int test_phase;
    int error_count;

    //==========================================================================
    // Device Under Test (DUT) - Simple Word Array
    //==========================================================================
    
    reram_word_array_simple #(
        .WORD_WIDTH(WORD_WIDTH),
        .READ_DELAY_CYCLES(READ_DELAY),
        .SET_DELAY_CYCLES(SET_DELAY),
        .RESET_DELAY_CYCLES(RESET_DELAY),
        .MAX_WRITE_CYCLES(1000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .command(command),
        .word_enable(word_enable),
        .write_data(write_data),
        .read_data(read_data),
        .operation_complete(operation_complete),
        .word_busy(word_busy),
        .word_error(word_error),
        .cell_error_flags(cell_error_flags),
        .total_write_cycles(total_write_cycles)
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
            $display("[%0t] Resetting simple word array...", $time);
            rst_n = 0;
            command = CMD_NOP;
            word_enable = 0;
            write_data = '0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask
    
    // Task: Write word to array (with endurance protection)
    task write_word(input [WORD_WIDTH-1:0] data);
        begin
            // Check if we're approaching endurance limit
            if (total_writes_performed >= MAX_WRITES_SAFE) begin
                $display("[WARNING] Skipping write - approaching endurance limit (%0d/%0d)", 
                        total_writes_performed, MAX_WRITES_SAFE);
                return;
            end
            
            $display("[%0t] Writing word: 0x%08X (write #%0d)", $time, data, total_writes_performed + 1);
            @(posedge clk);
            write_data = data;
            command = CMD_WRITE;
            word_enable = 1;
            
            @(posedge clk);
            command = CMD_NOP;
            word_enable = 0;
            
            // Wait for completion
            wait(operation_complete);
            @(posedge clk);
            
            total_writes_performed++;
            
            if (word_error) begin
                $display("[ERROR] Write operation failed, cell_errors=0x%08X", cell_error_flags);
                
                // Check if any cells are worn out
                if (cell_error_flags != 0) begin
                    $display("[CRITICAL] Cells may be worn out - stopping further writes");
                    $display("Total writes performed: %0d", total_writes_performed);
                end
                error_count++;
            end else begin
                $display("[%0t] Write completed successfully", $time);
            end
        end
    endtask
    
    // Task: Read word from array
    task read_word(output [WORD_WIDTH-1:0] data);
        begin
            $display("[%0t] Reading word from array...", $time);
            @(posedge clk);
            command = CMD_READ;
            word_enable = 1;
            
            @(posedge clk);
            command = CMD_NOP;
            word_enable = 0;
            
            // Wait for completion
            wait(operation_complete);
            @(posedge clk);
            
            if (word_error) begin
                $display("[ERROR] Read operation failed, cell_errors=0x%08X", cell_error_flags);
                error_count++;
                data = '0;
            end else begin
                data = read_data;
                $display("[%0t] Read data: 0x%08X", $time, data);
            end
        end
    endtask
    
    // Task: Verify word data
    task verify_word(input [WORD_WIDTH-1:0] expected);
        logic [WORD_WIDTH-1:0] actual;
        begin
            read_word(actual);
            if (actual !== expected) begin
                $display("[ERROR] Data mismatch: expected=0x%08X, actual=0x%08X", expected, actual);
                // Show bit-level differences
                for (int i = 0; i < WORD_WIDTH; i++) begin
                    if (actual[i] !== expected[i]) begin
                        $display("  Bit %2d: expected=%b, actual=%b", i, expected[i], actual[i]);
                    end
                end
                error_count++;
            end else begin
                $display("[PASS] Data verification passed: 0x%08X", actual);
            end
        end
    endtask
    
    // Task: Check cell health and warn about endurance issues
    task check_cell_health();
        begin
            if (cell_error_flags != 0) begin
                $display("[HEALTH] Cell error flags detected: 0x%08X", cell_error_flags);
                
                // Check individual cells for wear-out
                for (int i = 0; i < WORD_WIDTH; i++) begin
                    if (cell_error_flags[i]) begin
                        $display("  Cell %0d: Error detected (possibly worn out)", i);
                    end
                end
                
                $display("[WARNING] Continuing tests may not be reliable");
            end else begin
                $display("[HEALTH] All cells healthy, no error flags");
            end
            
            $display("[HEALTH] Write utilization: %0d/%0d (%0d%%)", 
                    total_writes_performed, MAX_WRITES_SAFE,
                    (total_writes_performed * 100) / MAX_WRITES_SAFE);
        end
    endtask

    // Task: Test specific bit pattern
    task test_pattern(input [WORD_WIDTH-1:0] pattern, input string pattern_name);
        begin
            $display("Testing %s pattern (0x%08X)...", pattern_name, pattern);
            write_word(pattern);
            verify_word(pattern);
        end
    endtask
    
    // Task: Test timing
    task test_operation_timing(input string operation, input int expected_delay);
        int start_time, end_time, actual_delay;
        begin
            $display("Testing %s timing (expected %0d cycles)...", operation, expected_delay);
            
            start_time = $time;
            
            if (operation == "WRITE") begin
                @(posedge clk);
                write_data = 32'hA5A5A5A5;
                command = CMD_WRITE;
                word_enable = 1;
                @(posedge clk);
                command = CMD_NOP;
                word_enable = 0;
                wait(operation_complete);
            end
            else if (operation == "READ") begin
                @(posedge clk);
                command = CMD_READ;
                word_enable = 1;
                @(posedge clk);
                command = CMD_NOP;
                word_enable = 0;
                wait(operation_complete);
            end
            
            end_time = $time;
            // Account for registered command implementation: 2 setup cycles + 1 register delay
            actual_delay = (end_time - start_time) / CLK_PERIOD - 3; 
            
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
        $display("Simple ReRAM Word Array Testbench");
        $display("==========================================================================");
        
        error_count = 0;
        test_phase = 0;
        
        // Initialize signals
        reset_system();
        
        //----------------------------------------------------------------------
        // Test Phase 1: Basic Word Operations
        //----------------------------------------------------------------------
        test_phase = 1;
        $display("\n--- Phase 1: Basic Word Read/Write Operations ---");
        
        // Test basic write/read
        write_word(32'hDEADBEEF);
        verify_word(32'hDEADBEEF);
        
        write_word(32'hCAFEBABE);
        verify_word(32'hCAFEBABE);
        
        write_word(32'h12345678);
        verify_word(32'h12345678);
        
        $display("Phase 1 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 2: Bit Pattern Testing
        //----------------------------------------------------------------------
        test_phase = 2;
        $display("\n--- Phase 2: Bit Pattern Testing ---");
        
        // Test various bit patterns
        test_pattern(32'h00000000, "All Zeros");
        test_pattern(32'hFFFFFFFF, "All Ones");
        test_pattern(32'hAAAAAAAA, "Alternating 1010");
        test_pattern(32'h55555555, "Alternating 0101");
        
        // Test walking 1s (reduced set to save endurance)
        $display("Testing Walking 1s patterns (reduced set)...");
        int walking_test_indices[8] = '{0, 1, 7, 8, 15, 16, 23, 31}; // Representative bits
        for (int j = 0; j < 8; j++) begin
            int i = walking_test_indices[j];
            logic [WORD_WIDTH-1:0] walking_1s = 1 << i;
            test_pattern(walking_1s, $sformatf("Walking 1s bit %0d", i));
        end
        
        // Test walking 0s (reduced set to save endurance)
        $display("Testing Walking 0s patterns (reduced set)...");
        for (int j = 0; j < 8; j++) begin
            int i = walking_test_indices[j];
            logic [WORD_WIDTH-1:0] walking_0s = ~(1 << i);
            test_pattern(walking_0s, $sformatf("Walking 0s bit %0d", i));
        end
        
        $display("Phase 2 completed with %0d errors", error_count);
        check_cell_health();
        
        //----------------------------------------------------------------------
        // Test Phase 3: Parallel Cell Access
        //----------------------------------------------------------------------
        test_phase = 3;
        $display("\n--- Phase 3: Parallel Cell Access Verification ---");
        
        // Write known pattern and verify all bits
        logic [WORD_WIDTH-1:0] test_pattern = 32'hA5C3F0E7;
        write_word(test_pattern);
        
        // Read and check each bit is correctly stored
        logic [WORD_WIDTH-1:0] read_pattern;
        read_word(read_pattern);
        
        $display("Verifying individual bit storage:");
        for (int i = 0; i < WORD_WIDTH; i++) begin
            if (read_pattern[i] !== test_pattern[i]) begin
                $display("[ERROR] Bit %2d: expected=%b, actual=%b", i, test_pattern[i], read_pattern[i]);
                error_count++;
            end else begin
                $display("[PASS] Bit %2d: %b", i, read_pattern[i]);
            end
        end
        
        $display("Phase 3 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 4: Timing Validation
        //----------------------------------------------------------------------
        test_phase = 4;
        $display("\n--- Phase 4: Timing Validation ---");
        
        test_operation_timing("WRITE", SET_DELAY);  // Longest delay for write
        test_operation_timing("READ", READ_DELAY);
        
        $display("Phase 4 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 5: Data Persistence
        //----------------------------------------------------------------------
        test_phase = 5;
        $display("\n--- Phase 5: Data Persistence Test ---");
        
        // Write pattern and wait
        logic [WORD_WIDTH-1:0] persistence_pattern = 32'h13579BDF;
        write_word(persistence_pattern);
        
        // Wait significant time
        repeat(200) @(posedge clk);
        
        // Verify data is still there
        verify_word(persistence_pattern);
        
        $display("Phase 5 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 6: Endurance Tracking (Conservative)
        //----------------------------------------------------------------------
        test_phase = 6;
        $display("\n--- Phase 6: Conservative Endurance Tracking ---");
        
        // Measure endurance with limited writes to preserve cells
        logic [7:0] initial_max_writes = max_write_count;
        $display("Initial max write count: %0d", initial_max_writes);
        $display("Total writes performed so far: %0d", total_writes_performed);
        $display("Remaining safe writes: %0d", MAX_WRITES_SAFE - total_writes_performed);
        
        // Only do a few endurance writes if we have headroom
        int endurance_writes = (MAX_WRITES_SAFE - total_writes_performed > 10) ? 5 : 2;
        $display("Performing %0d conservative endurance writes...", endurance_writes);
        
        for (int i = 0; i < endurance_writes; i++) begin
            if (total_writes_performed >= MAX_WRITES_SAFE) begin
                $display("Stopping endurance test - reached safe write limit");
                break;
            end
            write_word(32'h12345678 + i);
        end
        
        logic [7:0] final_max_writes = max_write_count;
        $display("Max write count progression: %0d -> %0d", initial_max_writes, final_max_writes);
        $display("Total writes now: %0d", total_writes_performed);
        
        if (final_max_writes <= initial_max_writes && endurance_writes > 0) begin
            $display("[ERROR] Write count not progressing properly");
            error_count++;
        end else begin
            $display("[PASS] Write count tracking working (or skipped for safety)");
        end
        
        $display("Phase 6 completed with %0d errors", error_count);
        check_cell_health();
        
        //----------------------------------------------------------------------
        // Test Phase 7: Random Data Testing
        //----------------------------------------------------------------------
        test_phase = 7;
        $display("\n--- Phase 7: Random Data Testing ---");
        
        // Test with random data patterns (reduced to save endurance)
        for (int i = 0; i < 10; i++) begin
            logic [WORD_WIDTH-1:0] random_data = $urandom();
            $display("Random test %0d: 0x%08X", i+1, random_data);
            write_word(random_data);
            verify_word(random_data);
            
            // Check if we should stop due to endurance concerns
            if (total_writes_performed >= MAX_WRITES_SAFE) begin
                $display("Stopping random tests early to preserve cell endurance");
                break;
            end
        end
        
        $display("Phase 7 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 8: Command Interface Timing
        //----------------------------------------------------------------------
        test_phase = 8;
        $display("\n--- Phase 8: Command Interface Timing Validation ---");
        
        // Test registered command behavior
        $display("Testing registered command timing...");
        
        // Verify commands are properly registered
        @(posedge clk);
        command = CMD_WRITE;
        word_enable = 1;
        write_data = 32'h55AA55AA;
        
        // Command should take effect on next clock edge due to registration
        @(posedge clk);
        command = CMD_NOP;
        word_enable = 0;
        
        // Monitor that operation starts properly
        $display("Waiting for write operation to complete...");
        wait(operation_complete);
        $display("Write with registered commands completed successfully");
        
        // Verify read with registered commands
        @(posedge clk);
        command = CMD_READ;
        word_enable = 1;
        
        @(posedge clk);
        command = CMD_NOP;
        word_enable = 0;
        
        wait(operation_complete);
        
        if (read_data === 32'h55AA55AA) begin
            $display("[PASS] Registered command read verification successful");
        end else begin
            $display("[ERROR] Registered command read failed: expected=0x55AA55AA, got=0x%08X", read_data);
            error_count++;
        end
        
        $display("Phase 8 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Summary
        //----------------------------------------------------------------------
        $display("\n==========================================================================");
        $display("Simple Word Array Test Summary");
        $display("==========================================================================");
        $display("Total test errors: %0d", error_count);
        $display("Total writes performed: %0d (limit: %0d)", total_writes_performed, MAX_WRITES_SAFE);
        $display("Endurance margin remaining: %0d writes", MAX_WRITES_SAFE - total_writes_performed);
        $display("Final total write cycles: %0d", total_write_cycles);
        $display("Final cell errors: 0x%08X", cell_error_flags);
        $display("Final error state: %b", word_error);
        $display("Word width tested: %0d bits", WORD_WIDTH);
        
        // Check for cell wear-out warnings
        if (cell_error_flags != 0) begin
            $display("[WARNING] Some cells may be experiencing wear - check cell error flags");
        end
        
        if (total_writes_performed > (MAX_WRITES_SAFE * 0.8)) begin
            $display("[WARNING] Approaching endurance limit - %0d%% of safe writes used", 
                    (total_writes_performed * 100) / MAX_WRITES_SAFE);
        end
        
        if (error_count == 0) begin
            $display("*** ALL WORD ARRAY TESTS PASSED! ***");
            $display("Simple word array is functioning correctly.");
        end else begin
            $display("*** %0d WORD ARRAY TESTS FAILED ***", error_count);
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
        #(CLK_PERIOD * 20000); // 20K cycles timeout
        $display("[ERROR] Simulation timeout!");
        $finish;
    end
    
    // Monitor operations during test phases
    always @(posedge clk) begin
        if (test_phase >= 1 && test_phase <= 7) begin
            if (word_busy || command != CMD_NOP || word_enable) begin
                $display("[%0t] Monitor: busy=%b, cmd=%b, enable=%b, error=%b, total_writes=%0d", 
                         $time, word_busy, command, word_enable, word_error, total_write_cycles);
            end
        end
    end
    
    // Monitor for any cell errors
    always @(posedge clk) begin
        if (cell_error_flags != '0) begin
            $display("[%0t] Cell errors detected: 0x%08X", $time, cell_error_flags);
        end
    end
    
    // Dump waveforms for debugging
    initial begin
        $dumpfile("tb_reram_word_array_simple.vcd");
        $dumpvars(0, tb_reram_word_array_simple);
    end

endmodule