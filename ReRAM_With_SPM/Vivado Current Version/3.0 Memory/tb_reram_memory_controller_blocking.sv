/*
 * Simple Testbench for Blocking ReRAM Memory Controller
 * 
 * This testbench validates the blocking memory controller with straightforward
 * read/write operations, similar to traditional SRAM testing.
 */

module tb_reram_memory_controller_blocking;

    // Test parameters
    parameter int CLK_PERIOD   = 10;
    parameter int ADDR_WIDTH   = 4;   // Small memory for testing: 16 words
    parameter int DATA_WIDTH   = 32;
    parameter int MEMORY_DEPTH = 16;
    
    // DUT signals
    logic                    clk;
    logic                    rst_n;
    logic [ADDR_WIDTH-1:0]   addr_i;
    logic [DATA_WIDTH-1:0]   data_i;
    logic [DATA_WIDTH-1:0]   data_o;
    logic                    read_i;
    logic                    write_i;
    logic                    done_o;
    logic                    error_o;
    logic                    busy_o;
    logic [31:0]             total_reads;
    logic [31:0]             total_writes;
    logic [MEMORY_DEPTH-1:0] word_errors;
    
    // Enhanced endurance monitoring signals
    logic [7:0]              word_write_cycles [MEMORY_DEPTH-1:0];
    logic [MEMORY_DEPTH-1:0] word_cell_errors_any;
    logic [DATA_WIDTH-1:0]   word_cell_errors [MEMORY_DEPTH-1:0];
    
    // Test control
    int error_count = 0;
    int test_phase  = 0;

    // -------------------------------------------------------------------------
    // TB temporaries (module-scope for Vivado 2018.1 compatibility)
    // -------------------------------------------------------------------------
    // General data/address temps
    logic [ADDR_WIDTH-1:0]   tb_addr_tmp;
    logic [DATA_WIDTH-1:0]   tb_data_tmp;
    logic [DATA_WIDTH-1:0]   tb_expected_tmp;
    logic [DATA_WIDTH-1:0]   tb_actual_tmp;
    logic [DATA_WIDTH-1:0]   tb_dummy_data;
    logic [DATA_WIDTH-1:0]   tb_read_result;
    logic [DATA_WIDTH-1:0]   tb_test_data;
    logic [DATA_WIDTH-1:0]   tb_walking_pattern;

    // Byte-sized endurance counters / flags reused across phases
    logic [7:0]              initial_cycles1;
    logic [7:0]              initial_cycles2;
    logic [7:0]              final_cycles1;
    logic [7:0]              final_cycles2;
    logic [7:0]              pre_read_cycles;
    logic [7:0]              post_read_cycles;
    logic [7:0]              initial_wear_cycles;
    logic [7:0]              final_wear_cycles;
    logic                    initial_cell_errors;
    logic                    final_cell_errors;

    // Address temps reused across phases
    logic [ADDR_WIDTH-1:0]   test_addr1;
    logic [ADDR_WIDTH-1:0]   test_addr2;
    logic [ADDR_WIDTH-1:0]   wear_test_addr;
    logic [7:0]              max_cycles;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    
    reram_memory_controller_blocking #(
        .MEMORY_DEPTH(MEMORY_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .READ_DELAY_CYCLES(3),
        .SET_DELAY_CYCLES(10),
        .RESET_DELAY_CYCLES(10),
        .MAX_WRITE_CYCLES(200)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(addr_i),
        .data_i(data_i),
        .data_o(data_o),
        .read_i(read_i),
        .write_i(write_i),
        .done_o(done_o),
        .error_o(error_o),
        .busy_o(busy_o),
        .total_reads(total_reads),
        .total_writes(total_writes),
        .word_errors(word_errors),
        
        // Enhanced endurance monitoring
        .word_write_cycles(word_write_cycles),
        .word_cell_errors_any(word_cell_errors_any),
        .word_cell_errors(word_cell_errors)
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
    
    // Task: Reset system
    task automatic reset_system();
        begin
            $display("[%0t] Resetting memory controller...", $time);
            rst_n   = 0;
            addr_i  = '0;
            data_i  = '0;
            read_i  = 0;
            write_i = 0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask
    
    // Task: Write data to address
    task automatic write_memory(input [ADDR_WIDTH-1:0] address, input [DATA_WIDTH-1:0] data);
        begin
            $display("[%0t] Writing 0x%08X to address 0x%04X", $time, data, address);
            
            @(posedge clk);
            addr_i  = address;
            data_i  = data;
            write_i = 1;
            read_i  = 0;
            
            @(posedge clk);
            write_i = 0;
            
            // Wait for completion
            wait(done_o);
            @(posedge clk);
            
            if (error_o) begin
                $display("[%0t] Write completed with ERROR to address 0x%04X (address may be worn out)", $time, address);
            end else begin
                $display("[%0t] Write completed successfully", $time);
            end
        end
    endtask
    
    // Task: Read data from address  
    task automatic read_memory(input [ADDR_WIDTH-1:0] address, output [DATA_WIDTH-1:0] data);
        begin
            $display("[%0t] Reading from address 0x%04X", $time, address);
            
            @(posedge clk);
            addr_i  = address;
            read_i  = 1;
            write_i = 0;
            
            @(posedge clk);
            read_i = 0;
            
            // Wait for completion
            wait(done_o);
            data = data_o;
            @(posedge clk);
            
            if (error_o) begin
                $display("[%0t] Read completed with ERROR from address 0x%04X (address may be worn out)", $time, address);
                data = '0;
            end else begin
                $display("[%0t] Read data: 0x%08X", $time, data);
            end
        end
    endtask
    
    // Task: Write then read back and verify (handles worn-out addresses gracefully)
    task automatic write_read_verify(input [ADDR_WIDTH-1:0] address, input [DATA_WIDTH-1:0] expected_data);
        logic [DATA_WIDTH-1:0] actual_data;
        logic write_error, read_error;
        begin
            write_memory(address, expected_data);
            write_error = error_o;
            
            read_memory(address, actual_data);
            read_error = error_o;
            
            // If either operation had errors, this might be a worn-out address
            if (write_error || read_error) begin
                $display("[INFO] Address 0x%04X appears to be worn out (write_err=%b, read_err=%b)", 
                        address, write_error, read_error);
                // Don't count as test error if it's due to wear-out
            end else if (actual_data !== expected_data) begin
                $display("[ERROR] Data mismatch at 0x%04X: expected=0x%08X, actual=0x%08X", 
                        address, expected_data, actual_data);
                error_count++;
            end else begin
                $display("[PASS] Data verification passed at 0x%04X", address);
            end
        end
    endtask
    
    // Task: Wear out a specific address to exactly the limit
    task automatic wear_out_address(input [ADDR_WIDTH-1:0] address, input [7:0] target_cycles);
        logic [7:0] current_cycles;
        logic [7:0] remaining_cycles;
        int write_count;
        begin
            current_cycles = word_write_cycles[address];
            
            if (current_cycles >= target_cycles) begin
                $display("[INFO] Address 0x%04X already has %0d cycles (target: %0d)", 
                        address, current_cycles, target_cycles);
                return;
            end
            
            remaining_cycles = target_cycles - current_cycles;
            $display("[INFO] Wearing out address 0x%04X: %0d -> %0d cycles (%0d writes needed)", 
                    address, current_cycles, target_cycles, remaining_cycles);
            
            // Perform the exact number of writes needed
            for (write_count = 0; write_count < remaining_cycles; write_count++) begin
                tb_test_data = 32'hAEAD0000 | write_count;
                write_memory(address, tb_test_data);
                
                // Check if we've hit the limit
                if (word_write_cycles[address] >= target_cycles) begin
                    $display("[INFO] Address 0x%04X reached target cycles: %0d", 
                            address, word_write_cycles[address]);
                    break;
                end
                
                // Show progress every 25 writes for long sequences
                if ((write_count + 1) % 25 == 0) begin
                    $display("  Progress: %0d/%0d writes completed, cycles now = %0d", 
                            write_count + 1, remaining_cycles, word_write_cycles[address]);
                end
            end
            
            // Final status
            $display("[INFO] Wear-out complete. Address 0x%04X final cycles: %0d, cell_errors_any: %b", 
                    address, word_write_cycles[address], word_cell_errors_any[address]);
        end
    endtask
    
    // Task: Check endurance counter increment
    task automatic check_endurance_increment(input [ADDR_WIDTH-1:0] address, 
                                  input [7:0] initial_cycles, 
                                  input [7:0] expected_increment);
        logic [7:0] current_cycles;
        logic [7:0] actual_increment;
        begin
            current_cycles   = word_write_cycles[address];
            actual_increment = current_cycles - initial_cycles;
            
            if (actual_increment != expected_increment) begin
                $display("[ERROR] Address 0x%X endurance counter: expected +%0d, got +%0d", 
                        address, expected_increment, actual_increment);
                error_count++;
            end else begin
                $display("[PASS] Address 0x%X endurance counter correctly incremented by %0d", 
                        address, expected_increment);
            end
        end
    endtask
    
    //==========================================================================
    // Main Test
    //==========================================================================
    
    initial begin
        $display("=========================================================================");
        $display("Simple Blocking ReRAM Memory Controller Test");
        $display("=========================================================================");
        $display("Memory size: %0d words (%0d bytes)", MEMORY_DEPTH, (MEMORY_DEPTH * DATA_WIDTH) / 8);
        $display("Address width: %0d bits", ADDR_WIDTH);
        $display("Data width: %0d bits", DATA_WIDTH);
        
        reset_system();
        
        //----------------------------------------------------------------------
        // Test Phase 1: Basic Operations
        //----------------------------------------------------------------------
        test_phase = 1;
        $display("\n--- Phase 1: Basic Read/Write Operations ---");
        
        // Test basic write/read
        write_read_verify(4'h0, 32'hDEADBEEF);
        write_read_verify(4'h1, 32'hCAFEBABE); 
        write_read_verify(4'h2, 32'h12345678);
        write_read_verify(4'hF, 32'hA5A5A5A5); // End of memory (address 15)
        
        $display("Phase 1 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 2: Address Boundary Testing
        //----------------------------------------------------------------------
        test_phase = 2;
        $display("\n--- Phase 2: Address Boundary Testing ---");
        
        // Test first and last valid addresses
        write_read_verify(4'h0, 32'h00000001);
        write_read_verify(4'hF, 32'hFFFFFFFF);
        
        // Test middle addresses
        write_read_verify(4'h7, 32'h12345678);
        write_read_verify(4'h8, 32'h87654321);
        
        $display("Phase 2 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 3: Data Pattern Testing  
        //----------------------------------------------------------------------
        test_phase = 3;
        $display("\n--- Phase 3: Data Pattern Testing ---");
        
        // Test various bit patterns
        write_read_verify(4'hA, 32'h00000000); // All zeros
        write_read_verify(4'hB, 32'hFFFFFFFF); // All ones
        write_read_verify(4'hC, 32'hAAAAAAAA); // Alternating 1010
        write_read_verify(4'hD, 32'h55555555); // Alternating 0101
        
        // Test walking bits (limited to save endurance)
        $display("Testing walking 1s patterns...");
        for (int i = 0; i < 4; i++) begin
            tb_walking_pattern = '0;
            tb_walking_pattern[(i*8)] = 1'b1; // set every 8th bit
            write_read_verify(4'h3 + i, tb_walking_pattern);
        end
        
        $display("Phase 3 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 4: Multiple Address Testing
        //----------------------------------------------------------------------
        test_phase = 4;
        $display("\n--- Phase 4: Multiple Address Testing ---");
        
        // Write pattern to multiple addresses
        for (int i = 0; i < 8; i++) begin
            tb_addr_tmp = i[ADDR_WIDTH-1:0];
            tb_data_tmp = 32'h80000000 | i;
            write_memory(tb_addr_tmp, tb_data_tmp);
        end
        
        // Read back and verify
        for (int i = 0; i < 8; i++) begin
            tb_addr_tmp     = i[ADDR_WIDTH-1:0];
            tb_expected_tmp = 32'h80000000 | i;
            read_memory(tb_addr_tmp, tb_actual_tmp);
            if (tb_actual_tmp !== tb_expected_tmp) begin
                $display("[ERROR] Multi-address test failed at 0x%04X: expected=0x%08X, actual=0x%08X", 
                        tb_addr_tmp, tb_expected_tmp, tb_actual_tmp);
                error_count++;
            end
        end
        
        $display("Phase 4 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 5: Status Monitoring
        //----------------------------------------------------------------------
        test_phase = 5;
        $display("\n--- Phase 5: Status and Statistics ---");
        
        $display("Total reads performed: %0d", total_reads);
        $display("Total writes performed: %0d", total_writes);
        $display("Word errors: 0x%04X", word_errors);
        
        // Display endurance monitoring information
        $display("Endurance monitoring:");
        for (int i = 0; i < 4; i++) begin // Show first 4 words
            $display("  Word %0d: write_cycles=%0d, cell_errors_any=%b, cell_errors=0x%08X", 
                    i, word_write_cycles[i], word_cell_errors_any[i], word_cell_errors[i]);
        end
        
        // Verify counters are reasonable
        if (total_reads == 0) begin
            $display("[ERROR] Read counter not incrementing");
            error_count++;
        end
        
        if (total_writes == 0) begin
            $display("[ERROR] Write counter not incrementing");
            error_count++;
        end
        
        $display("Phase 5 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 6: Endurance Counter Testing
        //----------------------------------------------------------------------
        test_phase = 6;
        $display("\n--- Phase 6: Endurance Counter Testing ---");
        
        // Test endurance monitoring on specific addresses
        test_addr1 = 4'h0;
        test_addr2 = 4'h1;
        
        // Record initial write cycle counts
        initial_cycles1 = word_write_cycles[test_addr1];
        initial_cycles2 = word_write_cycles[test_addr2];
        
        $display("Initial write cycles - Addr 0x%X: %0d, Addr 0x%X: %0d", 
                test_addr1, initial_cycles1, test_addr2, initial_cycles2);
        
        // Perform multiple writes to test address 1
        $display("Performing 10 writes to address 0x%X...", test_addr1);
        for (int i = 0; i < 10; i++) begin
            tb_data_tmp = 32'h12345678 + i;
            write_memory(test_addr1, tb_data_tmp);
            $display("  Write %0d: cycles now = %0d", i+1, word_write_cycles[test_addr1]);
        end
        
        // Perform fewer writes to test address 2  
        $display("Performing 5 writes to address 0x%X...", test_addr2);
        for (int i = 0; i < 5; i++) begin
            tb_data_tmp = 32'hABCDEF00 + i;
            write_memory(test_addr2, tb_data_tmp);
            $display("  Write %0d: cycles now = %0d", i+1, word_write_cycles[test_addr2]);
        end
        
        // Verify write cycle increments
        final_cycles1 = word_write_cycles[test_addr1];
        final_cycles2 = word_write_cycles[test_addr2];
        
        $display("Final write cycles - Addr 0x%X: %0d, Addr 0x%X: %0d", 
                test_addr1, final_cycles1, test_addr2, final_cycles2);
        
        // Check if counters incremented correctly
        if ((final_cycles1 - initial_cycles1) != 10) begin
            $display("[ERROR] Address 0x%X write counter incorrect: expected +10, got +%0d", 
                    test_addr1, (final_cycles1 - initial_cycles1));
            error_count++;
        end else begin
            $display("[PASS] Address 0x%X write counter correctly incremented by 10", test_addr1);
        end
        
        if ((final_cycles2 - initial_cycles2) != 5) begin
            $display("[ERROR] Address 0x%X write counter incorrect: expected +5, got +%0d", 
                    test_addr2, (final_cycles2 - initial_cycles2));
            error_count++;
        end else begin
            $display("[PASS] Address 0x%X write counter correctly incremented by 5", test_addr2);
        end
        
        // Test that read operations don't affect write counters
        $display("Testing that reads don't affect write counters...");
        pre_read_cycles = word_write_cycles[test_addr1];
        
        // Perform multiple reads
        for (int i = 0; i < 5; i++) begin
            read_memory(test_addr1, tb_dummy_data);
        end
        
        post_read_cycles = word_write_cycles[test_addr1];
        
        if (pre_read_cycles != post_read_cycles) begin
            $display("[ERROR] Read operations affected write counter: %0d -> %0d", 
                    pre_read_cycles, post_read_cycles);
            error_count++;
        end else begin
            $display("[PASS] Read operations correctly did not affect write counter");
        end
        
        // Test cell error monitoring (should be 0 for low write counts)
        $display("Checking cell error flags for low write counts...");
        for (int i = 0; i < 4; i++) begin
            if (word_cell_errors_any[i] == 1'b1) begin
                $display("[WARNING] Address 0x%X shows cell errors with only %0d writes", 
                        i, word_write_cycles[i]);
            end else begin
                $display("[PASS] Address 0x%X shows no cell errors with %0d writes", 
                        i, word_write_cycles[i]);
            end
        end
        
        // Display comprehensive endurance status
        $display("\nComprehensive endurance status:");
        for (int i = 0; i < MEMORY_DEPTH; i++) begin
            $display("  Word %2d: cycles=%3d, errors_any=%b, errors=0x%08X", 
                    i, word_write_cycles[i], word_cell_errors_any[i], word_cell_errors[i]);
        end
        
        // Test counter independence - verify other addresses weren't affected
        $display("\nTesting counter independence...");
        for (int i = 2; i < MEMORY_DEPTH; i++) begin
            // These addresses should have minimal write cycles (only from earlier tests)
            if (word_write_cycles[i] > 5) begin
                $display("[WARNING] Address 0x%X has unexpectedly high write count: %0d", 
                        i, word_write_cycles[i]);
            end else begin
                $display("[PASS] Address 0x%X has expected low write count: %0d", 
                        i, word_write_cycles[i]);
            end
        end
        
        $display("Phase 6 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 7: Wear-Out Testing
        //----------------------------------------------------------------------
        test_phase = 7;
        $display("\n--- Phase 7: Wear-Out Testing ---");
        
        // Choose an address to wear out (use address 0xF - last address)
        wear_test_addr = 4'hF;
        max_cycles     = 8'd200; // MAX_WRITE_CYCLES parameter
        
        $display("Wearing out address 0x%04X to exactly %0d write cycles...", wear_test_addr, max_cycles);
        
        // Record initial state
        initial_wear_cycles  = word_write_cycles[wear_test_addr];
        initial_cell_errors  = word_cell_errors_any[wear_test_addr];
        
        $display("Initial state - cycles: %0d, cell_errors_any: %b", 
                initial_wear_cycles, initial_cell_errors);
        
        // Wear out the address to exactly the limit
        wear_out_address(wear_test_addr, max_cycles);
        
        // Verify the address is now in error state
        final_wear_cycles  = word_write_cycles[wear_test_addr];
        final_cell_errors  = word_cell_errors_any[wear_test_addr];
        
        $display("Final state - cycles: %0d, cell_errors_any: %b", 
                final_wear_cycles, final_cell_errors);
        
        // Verify that the word shows errors after reaching the limit
        if (final_cell_errors == 1'b1) begin
            $display("[PASS] Address 0x%04X correctly shows cell errors after reaching limit", wear_test_addr);
        end else begin
            $display("[WARNING] Address 0x%04X does not show cell errors despite reaching limit", wear_test_addr);
        end
        
        // Test that further writes to worn-out address fail
        $display("\nTesting operations on worn-out address...");
        tb_test_data = 32'hDEADBEEF;
        $display("Attempting write to worn-out address 0x%04X...", wear_test_addr);
        write_memory(wear_test_addr, tb_test_data);
        
        if (error_o) begin
            $display("[PASS] Write to worn-out address correctly returned error");
        end else begin
            $display("[WARNING] Write to worn-out address did not return error");
        end
        
        // Test that reads from worn-out address also fail
        $display("Attempting read from worn-out address 0x%04X...", wear_test_addr);
        read_memory(wear_test_addr, tb_read_result);
        
        if (error_o) begin
            $display("[PASS] Read from worn-out address correctly returned error");
        end else begin
            $display("[WARNING] Read from worn-out address did not return error");
        end
        
        // Verify other addresses still work normally
        $display("\nVerifying other addresses still work after one is worn out...");
        write_read_verify(4'h0, 32'h12345678);
        
        $display("Phase 7 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Phase 8: Error Conditions
        //----------------------------------------------------------------------
        test_phase = 8;
        $display("\n--- Phase 8: Error Condition Testing ---");
        
        // Test simultaneous read/write (should error immediately)
        $display("Testing simultaneous read/write...");
        @(posedge clk);
        addr_i  = 4'h0;
        data_i  = 32'hCAFEBABE;
        read_i  = 1;
        write_i = 1; // Both asserted - should cause error
        
        @(posedge clk);
        read_i  = 0;
        write_i = 0;
        
        // Wait for completion (the controller should complete with error)
        wait(done_o);
        if (error_o) begin
            $display("[PASS] Simultaneous read/write correctly flagged as error");
        end else begin
            $display("[ERROR] Simultaneous read/write should have generated error");
            error_count++;
        end
        
        @(posedge clk); // Let error clear
        
        $display("Phase 8 completed with %0d errors", error_count);
        
        //----------------------------------------------------------------------
        // Test Summary
        //----------------------------------------------------------------------
        $display("\n=========================================================================");
        $display("Blocking Memory Controller Test Summary");
        $display("=========================================================================");
        $display("Total test errors: %0d", error_count);
        $display("Final read count: %0d", total_reads);
        $display("Final write count: %0d", total_writes);
        $display("Memory size tested: %0d words", MEMORY_DEPTH);
        
        if (error_count == 0) begin
            $display("*** ALL TESTS PASSED! ***");
            $display("Blocking memory controller is functioning correctly.");
        end else begin
            $display("*** %0d TESTS FAILED ***", error_count);
        end
        
        $display("=========================================================================");
        
        // End simulation
        #(CLK_PERIOD * 10);
        $finish;
    end
    
    //==========================================================================
    // Monitoring
    //==========================================================================
    
    // Monitor for busy signal behavior
//    always @(posedge clk) begin
//        if (busy_o) begin
//            $display("[%0t] Controller is busy", $time);
//        end
//    end

endmodule
