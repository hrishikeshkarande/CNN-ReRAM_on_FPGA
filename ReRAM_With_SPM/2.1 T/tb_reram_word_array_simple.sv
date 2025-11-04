/*
 * Simple ReRAM Word Array Testbench
 *
 * Validates a simplified 32-cell word array (reads/writes, integrity, timing).
 * Vivado 2018.1 friendly: all temp vectors hoisted to module scope.
 */

module tb_reram_word_array_simple;

    // Test parameters
    parameter int CLK_PERIOD   = 10;   // 100MHz clock
    parameter int WORD_WIDTH   = 32;
    parameter int READ_DELAY   = 3;
    parameter int SET_DELAY    = 10;
    parameter int RESET_DELAY  = 10;
    parameter int MAX_WRITES_SAFE = 150;  // keep well below cell endurance

    // Test tracking
    int total_writes_performed = 0;

    // Clock and reset
    logic clk;
    logic rst_n;

    // Control signals
    logic [1:0] command;
    logic       word_enable;

    // Data signals
    logic [WORD_WIDTH-1:0] write_data;
    logic [WORD_WIDTH-1:0] read_data;

    // Status outputs
    logic                  operation_complete;
    logic                  word_busy;
    logic                  word_error;
    logic [WORD_WIDTH-1:0] cell_error_flags;
    logic [7:0]            total_write_cycles;

    // Command definitions
    localparam [1:0] CMD_NOP   = 2'b00;
    localparam [1:0] CMD_READ  = 2'b01;
    localparam [1:0] CMD_WRITE = 2'b10;

    // Test control variables
    int test_phase;
    int error_count;

    // Representative indices for walking tests (module-scope for Vivado 2018.1)
    int walking_test_indices [0:7];

    // ===== TB temporaries hoisted to module scope (avoid block-scoped packed decls) =====
    logic [WORD_WIDTH-1:0] parallel_pattern;
    logic [WORD_WIDTH-1:0] read_back_pattern;
    logic [WORD_WIDTH-1:0] persistence_pattern;
    logic [WORD_WIDTH-1:0] temp_pattern;     // reused for walking 1s/0s and Phase 9
    logic [WORD_WIDTH-1:0] random_data_vec;  // reused in random tests

    logic [7:0] writes_before;
    logic [7:0] writes_after;
    int         endurance_writes;            // small count of extra writes in Phase 6/9
    int         remaining;                   // Phase 9: remaining safe writes

    // Phase 9 variables (module-scope for Vivado 2018.1)
    int target_total_writes;
    int additional_writes_needed;
    int endurance_errors_detected;
    int writes_completed;
    int error_cell_count;
    logic [WORD_WIDTH-1:0] readback_data;
    logic [WORD_WIDTH-1:0] diff_bits;
    int wear_percentage;
    int worn_cell_count;

    //==========================================================================
    // Device Under Test (DUT) - Simple Word Array
    //==========================================================================
    reram_word_array_simple #(
        .WORD_WIDTH         (WORD_WIDTH),
        .READ_DELAY_CYCLES  (READ_DELAY),
        .SET_DELAY_CYCLES   (SET_DELAY),
        .RESET_DELAY_CYCLES (RESET_DELAY),
        .MAX_WRITE_CYCLES   (255)  // Match 8-bit counter limit
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .command            (command),
        .word_enable        (word_enable),
        .write_data         (write_data),
        .read_data          (read_data),
        .operation_complete (operation_complete),
        .word_busy          (word_busy),
        .word_error         (word_error),
        .cell_error_flags   (cell_error_flags),
        .total_write_cycles (total_write_cycles)
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
    task automatic reset_system();
        begin
            $display("[%0t] Resetting simple word array...", $time);
            rst_n       = 0;
            command     = CMD_NOP;
            word_enable = 0;
            write_data  = '0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask

    // Write word (with endurance protection)
    task automatic write_word(input [WORD_WIDTH-1:0] data);
        begin
            if (total_writes_performed >= MAX_WRITES_SAFE) begin
                $display("[WARNING] Skipping write - approaching endurance limit (%0d/%0d)",
                         total_writes_performed, MAX_WRITES_SAFE);
                return;
            end

            $display("[%0t] Writing word: 0x%08X (write #%0d)", $time, data, total_writes_performed + 1);
            @(posedge clk);
            write_data  = data;
            command     = CMD_WRITE;
            word_enable = 1;

            @(posedge clk);
            command     = CMD_NOP;
            word_enable = 0;

            wait(operation_complete);
            @(posedge clk);

            total_writes_performed++;

            if (word_error) begin
                $display("[ERROR] Write failed, cell_errors=0x%08X", cell_error_flags);
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

    // Read word
    task automatic read_word(output [WORD_WIDTH-1:0] data);
        begin
            $display("[%0t] Reading word from array...", $time);
            @(posedge clk);
            command     = CMD_READ;
            word_enable = 1;

            @(posedge clk);
            command     = CMD_NOP;
            word_enable = 0;

            wait(operation_complete);
            @(posedge clk);

            if (word_error) begin
                $display("[ERROR] Read failed, cell_errors=0x%08X", cell_error_flags);
                error_count++;
                data = '0;
            end else begin
                data = read_data;
                $display("[%0t] Read data: 0x%08X", $time, data);
            end
        end
    endtask

    // Verify data matches
    task automatic verify_word(input [WORD_WIDTH-1:0] expected);
        logic [WORD_WIDTH-1:0] actual;
        begin
            read_word(actual);
            if (actual !== expected) begin
                $display("[ERROR] Data mismatch: expected=0x%08X, actual=0x%08X", expected, actual);
                for (int k = 0; k < WORD_WIDTH; k++) begin
                    if (actual[k] !== expected[k]) begin
                        $display("  Bit %2d: expected=%b, actual=%b", k, expected[k], actual[k]);
                    end
                end
                error_count++;
            end else begin
                $display("[PASS] Data verification passed: 0x%08X", actual);
            end
        end
    endtask

    // Health check
    task automatic check_cell_health();
        begin
            if (cell_error_flags != 0) begin
                $display("[HEALTH] Cell error flags: 0x%08X", cell_error_flags);
                for (int c = 0; c < WORD_WIDTH; c++) begin
                    if (cell_error_flags[c]) $display("  Cell %0d: error flagged", c);
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

    // Pattern helper
    task automatic test_pattern(input [WORD_WIDTH-1:0] pattern, input string pattern_name);
        begin
            $display("Testing %s pattern (0x%08X)...", pattern_name, pattern);
            write_word(pattern);
            verify_word(pattern);
        end
    endtask

    // Timing helper
    task automatic test_operation_timing(input string operation, input int expected_delay);
        int start_time, end_time, actual_delay;
        begin
            $display("Testing %s timing (expected %0d cycles)...", operation, expected_delay);
            start_time = $time;

            if (operation == "WRITE") begin
                @(posedge clk);
                write_data  = 32'hA5A5A5A5;
                command     = CMD_WRITE;
                word_enable = 1;
                @(posedge clk);
                command     = CMD_NOP;
                word_enable = 0;
                wait(operation_complete);
            end
            else if (operation == "READ") begin
                @(posedge clk);
                command     = CMD_READ;
                word_enable = 1;
                @(posedge clk);
                command     = CMD_NOP;
                word_enable = 0;
                wait(operation_complete);
            end

            end_time     = $time;
            actual_delay = (end_time - start_time)/CLK_PERIOD - 3; // 2 setup + 1 reg delay

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
        test_phase  = 0;

        // Initialize signals
        reset_system();

        // Initialize representative bit indices (Vivado 2018.1-safe)
        walking_test_indices[0] = 0;
        walking_test_indices[1] = 1;
        walking_test_indices[2] = 7;
        walking_test_indices[3] = 8;
        walking_test_indices[4] = 15;
        walking_test_indices[5] = 16;
        walking_test_indices[6] = 23;
        walking_test_indices[7] = 31;

        // ------------------------- Phase 1 -------------------------
        test_phase = 1;
        $display("\n--- Phase 1: Basic Word Read/Write Operations ---");
        write_word(32'hDEADBEEF); verify_word(32'hDEADBEEF);
        write_word(32'hCAFEBABE); verify_word(32'hCAFEBABE);
        write_word(32'h12345678); verify_word(32'h12345678);
        $display("Phase 1 completed with %0d errors", error_count);

        // ------------------------- Phase 2 -------------------------
        test_phase = 2;
        $display("\n--- Phase 2: Bit Pattern Testing ---");
        test_pattern(32'h00000000, "All Zeros");
        test_pattern(32'hFFFFFFFF, "All Ones");
        test_pattern(32'hAAAAAAAA, "Alternating 1010");
        test_pattern(32'h55555555, "Alternating 0101");

        // Walking 1s (reduced set)
        $display("Testing Walking 1s patterns (reduced set)...");
        for (int j = 0; j < 8; j++) begin
            int i = walking_test_indices[j];
            temp_pattern = '0;
            temp_pattern[i] = 1'b1;
            test_pattern(temp_pattern, $sformatf("Walking 1s bit %0d", i));
        end

        // Walking 0s (reduced set)
        $display("Testing Walking 0s patterns (reduced set)...");
        for (int j = 0; j < 8; j++) begin
            int i = walking_test_indices[j];
            temp_pattern = '1;
            temp_pattern[i] = 1'b0;
            test_pattern(temp_pattern, $sformatf("Walking 0s bit %0d", i));
        end
        $display("Phase 2 completed with %0d errors", error_count);
        check_cell_health();

        // ------------------------- Phase 3 -------------------------
        test_phase = 3;
        $display("\n--- Phase 3: Parallel Cell Access Verification ---");
        parallel_pattern = 32'hA5C3F0E7;
        write_word(parallel_pattern);
        read_word(read_back_pattern);

        $display("Verifying individual bit storage:");
        for (int b = 0; b < WORD_WIDTH; b++) begin
            if (read_back_pattern[b] !== parallel_pattern[b]) begin
                $display("[ERROR] Bit %2d: expected=%b, actual=%b", b, parallel_pattern[b], read_back_pattern[b]);
                error_count++;
            end else begin
                $display("[PASS] Bit %2d: %b", b, read_back_pattern[b]);
            end
        end
        $display("Phase 3 completed with %0d errors", error_count);

        // ------------------------- Phase 4 -------------------------
        test_phase = 4;
        $display("\n--- Phase 4: Timing Validation ---");
        test_operation_timing("WRITE", SET_DELAY);
        test_operation_timing("READ",  READ_DELAY);
        $display("Phase 4 completed with %0d errors", error_count);

        // ------------------------- Phase 5 -------------------------
        test_phase = 5;
        $display("\n--- Phase 5: Data Persistence Test ---");
        persistence_pattern = 32'h13579BDF;
        write_word(persistence_pattern);
        repeat(200) @(posedge clk);
        verify_word(persistence_pattern);
        $display("Phase 5 completed with %0d errors", error_count);

        // ------------------------- Phase 6 -------------------------
        test_phase = 6;
        $display("\n--- Phase 6: Conservative Endurance Tracking ---");
        writes_before = total_write_cycles;
        $display("Total write cycles before: %0d", writes_before);
        $display("TB total writes so far: %0d", total_writes_performed);
        $display("Remaining safe writes: %0d", MAX_WRITES_SAFE - total_writes_performed);

        endurance_writes = (MAX_WRITES_SAFE - total_writes_performed > 10) ? 5 : 2;
        $display("Performing %0d conservative endurance writes...", endurance_writes);
        for (int e = 0; e < endurance_writes; e++) begin
            if (total_writes_performed >= MAX_WRITES_SAFE) begin
                $display("Stopping endurance test - reached safe write limit");
                break;
            end
            write_word(32'h12345678 + e);
        end

        writes_after = total_write_cycles;
        $display("Total write cycles progression: %0d -> %0d (?=%0d)",
                 writes_before, writes_after, writes_after - writes_before);

        if (writes_after < writes_before) begin
            $display("[ERROR] DUT write cycle counter regressed");
            error_count++;
        end else if ((writes_after == writes_before) && (endurance_writes > 0)) begin
            $display("[ERROR] DUT write cycle counter did not advance");
            error_count++;
        end else begin
            $display("[PASS] DUT write cycle counter advanced as expected (or safely skipped)");
        end
        $display("Phase 6 completed with %0d errors", error_count);
        check_cell_health();

        // ------------------------- Phase 7 -------------------------
        test_phase = 7;
        $display("\n--- Phase 7: Random Data Testing ---");
        for (int r = 0; r < 10; r++) begin
            random_data_vec = $urandom();
            $display("Random test %0d: 0x%08X", r+1, random_data_vec);
            write_word(random_data_vec);
            verify_word(random_data_vec);
            if (total_writes_performed >= MAX_WRITES_SAFE) begin
                $display("Stopping random tests early to preserve cell endurance");
                break;
            end
        end
        $display("Phase 7 completed with %0d errors", error_count);

        // ------------------------- Phase 8 -------------------------
        test_phase = 8;
        $display("\n--- Phase 8: Command Interface Timing Validation ---");
        @(posedge clk);
        command     = CMD_WRITE;
        word_enable = 1;
        write_data  = 32'h55AA55AA;
        @(posedge clk);
        command     = CMD_NOP;
        word_enable = 0;
        $display("Waiting for write operation to complete...");
        wait(operation_complete);
        $display("Write with registered commands completed successfully");

        @(posedge clk);
        command     = CMD_READ;
        word_enable = 1;
        @(posedge clk);
        command     = CMD_NOP;
        word_enable = 0;
        wait(operation_complete);

        if (read_data === 32'h55AA55AA) begin
            $display("[PASS] Registered command read verification successful");
        end else begin
            $display("[ERROR] Registered command read failed: expected=0x55AA55AA, got=0x%08X", read_data);
            error_count++;
        end
        $display("Phase 8 completed with %0d errors", error_count);

        // ------------------------- Phase 9 -------------------------
        // Endurance Limit Testing (push toward actual limit)
        test_phase = 9;
        $display("\n--- Phase 9: Endurance Limit Testing (Aggressive) ---");

        // Snapshot write counter
        writes_before = total_write_cycles;
        
        $display("Current state: total_writes_performed=%0d, total_write_cycles=%0d", 
                 total_writes_performed, total_write_cycles);
        $display("DUT configured with MAX_WRITE_CYCLES=255 (8-bit counter limit)");
        $display("Previous phases used conservative limit of %0d", MAX_WRITES_SAFE);
        
        // Calculate how many more writes we can do to approach the real limit
        // Target getting close to 255 but leave some margin for safety
        target_total_writes = 240;  // Aggressive but not quite at 8-bit limit
        additional_writes_needed = target_total_writes - total_writes_performed;
        
        if (additional_writes_needed <= 0) begin
            $display("Already performed %0d writes, close to endurance limit", total_writes_performed);
            additional_writes_needed = 10;  // Just do a few more to see what happens
        end
        
        // Cap to reasonable number for simulation time
        endurance_writes = (additional_writes_needed > 100) ? 100 : additional_writes_needed;
        
        $display("Planning to perform %0d additional writes to approach endurance limit", endurance_writes);
        $display("Expected total writes after Phase 9: %0d", total_writes_performed + endurance_writes);

        // Focus writes on a single cell to maximize endurance stress
        // Use alternating pattern to exercise both SET and RESET operations
        endurance_errors_detected = 0;
        writes_completed = 0;
        
        for (int n = 0; n < endurance_writes; n++) begin
            // Alternate between complementary patterns to stress both SET/RESET
            temp_pattern = (n % 2 == 0) ? 32'hAAAAAAAA : 32'h55555555;
            
            $display("Endurance write %0d/%0d: pattern=0x%08X (total_performed=%0d)", 
                     n+1, endurance_writes, temp_pattern, total_writes_performed + 1);
            
            write_word(temp_pattern);
            writes_completed = n + 1;

            // Check for endurance failures after each write
            if (word_error) begin
                $display("[ENDURANCE] Word error detected at write %0d!", writes_completed);
                endurance_errors_detected++;
            end
            
            if (cell_error_flags != '0) begin
                $display("[ENDURANCE] Cell error flags detected: 0x%08X", cell_error_flags);
                
                // Count how many cells have errors
                error_cell_count = 0;
                for (int c = 0; c < WORD_WIDTH; c++) begin
                    if (cell_error_flags[c]) error_cell_count++;
                end
                $display("  %0d out of %0d cells showing errors", error_cell_count, WORD_WIDTH);
                endurance_errors_detected++;
            end
            
            // If we're getting close to problems, slow down and monitor more carefully
            if (endurance_errors_detected > 0 || total_writes_performed > 200) begin
                $display("  Current write count: %0d, monitoring closely...", total_write_cycles);
                
                // Try to read back what we just wrote
                read_word(readback_data);
                
                if (readback_data !== temp_pattern) begin
                    $display("  [WARNING] Readback mismatch! Expected=0x%08X, Got=0x%08X", 
                             temp_pattern, readback_data);
                    $display("  This may indicate endurance-related data corruption");
                    
                    // Show bit-level differences
                    diff_bits = readback_data ^ temp_pattern;
                    if (diff_bits != '0) begin
                        $display("  Corrupted bits: 0x%08X", diff_bits);
                    end
                end else begin
                    $display("  [OK] Readback successful");
                end
            end
            
            // Stop if we detect multiple errors or severe degradation
            if (endurance_errors_detected >= 3) begin
                $display("[STOP] Multiple endurance errors detected (%0d), stopping Phase 9 early", 
                         endurance_errors_detected);
                break;
            end
            
            // Also check if we're hitting the actual DUT limit
            if (total_write_cycles >= 250) begin
                $display("[STOP] Approaching DUT write cycle limit (%0d), stopping for safety", 
                         total_write_cycles);
                break;
            end
        end

        writes_after = total_write_cycles;
        $display("\nPhase 9 Endurance Results:");
        $display("  Writes completed: %0d/%0d planned", writes_completed, endurance_writes);
        $display("  Write cycles progression: %0d -> %0d (+%0d)",
                 writes_before, writes_after, writes_after - writes_before);
        $display("  Endurance errors detected: %0d", endurance_errors_detected);
        $display("  Final cell error flags: 0x%08X", cell_error_flags);

        // Analyze results
        if (endurance_errors_detected > 0) begin
            $display("[SUCCESS] Phase 9 successfully detected endurance limits!");
            $display("  This demonstrates proper endurance error reporting");
        end else if (writes_after >= 200) begin
            $display("[INFO] Phase 9 pushed close to endurance limit without errors");
            $display("  This suggests good endurance margin or conservative DUT limits");
        end else begin
            $display("[INFO] Phase 9 completed without hitting endurance issues");
        end

        // Final verification attempt
        if (!word_error && endurance_errors_detected == 0) begin
            $display("Attempting final verification of last pattern...");
            verify_word(temp_pattern);
        end else begin
            $display("Skipping final verification due to detected endurance issues");
        end

        $display("Phase 9 completed with %0d errors", error_count);

        // ------------------------- Summary -------------------------
        $display("\n==========================================================================");
        $display("Simple Word Array Test Summary");
        $display("==========================================================================");
        $display("Total test errors: %0d", error_count);
        $display("Total writes performed: %0d", total_writes_performed);
        $display("Conservative limit was: %0d (early phases)", MAX_WRITES_SAFE);
        $display("DUT endurance limit: 255 cycles (8-bit counter)");
        $display("Endurance margin remaining: %0d writes", 255 - total_writes_performed);
        $display("Final total write cycles: %0d", total_write_cycles);
        $display("Final cell errors: 0x%08X", cell_error_flags);
        $display("Final error state: %b", word_error);
        $display("Word width tested: %0d bits", WORD_WIDTH);

        // Enhanced endurance analysis
        if (cell_error_flags != 0) begin
            worn_cell_count = 0;
            for (int i = 0; i < WORD_WIDTH; i++) begin
                if (cell_error_flags[i]) worn_cell_count++;
            end
            $display("WARNING: %0d out of %0d cells showing endurance issues", worn_cell_count, WORD_WIDTH);
            $display("         Worn cell pattern: 0x%08X", cell_error_flags);
        end else begin
            $display("All cells remain functional - no endurance issues detected");
        end

        // Calculate wear percentage based on actual DUT limit
        if (total_writes_performed > 0) begin
            wear_percentage = (total_writes_performed * 100) / 255;
            $display("Estimated wear level: %0d%% of DUT endurance limit", wear_percentage);
            
            if (wear_percentage > 90) begin
                $display("CRITICAL: Very high wear level - approaching endurance limit!");
            end else if (wear_percentage > 75) begin
                $display("WARNING: High wear level detected");
            end else if (wear_percentage > 50) begin
                $display("INFO: Moderate wear level");
            end else begin
                $display("INFO: Low wear level - plenty of endurance remaining");
            end
        end

        if (error_count == 0) begin
            $display("*** ALL WORD ARRAY TESTS PASSED! ***");
            $display("Simple word array is functioning correctly.");
        end else begin
            $display("*** %0d WORD ARRAY TESTS FAILED ***", error_count);
        end

        $display("==========================================================================");

        #(CLK_PERIOD * 10);
        $finish;
    end

    //==========================================================================
    // Simulation Control and Monitoring
    //==========================================================================
    initial begin
        #(CLK_PERIOD * 20000); // 20K cycles timeout
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

    always @(posedge clk) begin
        if (test_phase >= 1 && test_phase <= 9) begin
            if (word_busy || command != CMD_NOP || word_enable) begin
                $display("[%0t] Monitor: busy=%b, cmd=%b, enable=%b, error=%b, total_writes=%0d",
                         $time, word_busy, command, word_enable, word_error, total_write_cycles);
            end
        end
    end

    always @(posedge clk) begin
        if (cell_error_flags != '0)
            $display("[%0t] Cell errors detected: 0x%08X", $time, cell_error_flags);
    end

    initial begin
        $dumpfile("tb_reram_word_array_simple.vcd");
        $dumpvars(0, tb_reram_word_array_simple);
    end

endmodule
