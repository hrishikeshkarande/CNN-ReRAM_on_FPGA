// reram_core_tb.sv
// Testbench for the reram_core module

`timescale 1ns / 1ps

module reram_core_tb; // No inputs/outputs, it's a self-contained test environment

    // Testbench specific parameters (can be adjusted for faster/slower tests)
    localparam TB_ROWS = 4;
    localparam TB_COLS = 4;
    localparam TB_ADDR_WIDTH = $clog2(TB_ROWS * TB_COLS);
    localparam TB_LRS_VAL = 1'b0;
    localparam TB_HRS_VAL = 1'b1;
    localparam TB_CELL_SET_DELAY_CYCLES = 5;
    localparam TB_CELL_RESET_DELAY_CYCLES = 5;
    localparam TB_CELL_ENDURANCE_LIMIT = 10;

    // Testbench internal signals (registers for inputs, wires for outputs)
    reg clk;
    reg rst_n;
    localparam CLK_PERIOD = 10000; // 10,000 ps = 10 ns clock period (100 MHz)

    reg [TB_ADDR_WIDTH-1:0] tb_addr;
    reg tb_data_in;
    reg tb_write_en;
    reg tb_read_en;

    wire tb_data_out;
    wire tb_busy;
    wire [TB_ROWS*TB_COLS-1:0] tb_all_failed_cells;

    // Instantiate the Unit Under Test (UUT) - our reram_core
    reram_core #(
        .ROWS(TB_ROWS),
        .COLS(TB_COLS),
        .ADDR_WIDTH(TB_ADDR_WIDTH),
        .LRS_VAL(TB_LRS_VAL),
        .HRS_VAL(TB_HRS_VAL),
        .CELL_SET_DELAY_CYCLES(TB_CELL_SET_DELAY_CYCLES),
        .CELL_RESET_DELAY_CYCLES(TB_CELL_RESET_DELAY_CYCLES),
        .CELL_ENDURANCE_LIMIT(TB_CELL_ENDURANCE_LIMIT)
    ) u_reram_core (
        .clk(clk),
        .rst_n(rst_n),
        .addr(tb_addr),
        .data_in(tb_data_in),
        .write_en(tb_write_en),
        .read_en(tb_read_en),
        .data_out(tb_data_out),
        .busy(tb_busy),
        .all_failed_cells(tb_all_failed_cells)
    );

    // Clock generation (runs concurrently with all other initial/always blocks)
    initial begin
        clk = 0; // Initialize clock to 0
        forever #((CLK_PERIOD / 2)) clk = ~clk; // Toggle clock every half period
    end

    // Waveform dumping for debugging with GTKWave (or similar)
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, reram_core_tb); // Dump all signals in this module and its hierarchy
    end

    // Test stimulus (sequential actions within this initial block)
    initial begin
        // 1. Initial Reset sequence
        rst_n = 1'b0; // Assert reset (active low)
        tb_write_en = 1'b0; // No write
        tb_read_en = 1'b0;  // No read
        tb_addr = 0;        // Default address
        tb_data_in = TB_HRS_VAL; // Default data (High Resistance State)
        #(CLK_PERIOD * 2);  // Hold reset for 2 clock cycles
        rst_n = 1'b1;       // De-assert reset
        #(CLK_PERIOD * 2);  // Wait a few cycles after reset for stability

        $display("--- Starting ReRAM Core Test ---"); // Print message to console

        // 2. Write to Address 0 (Set to LRS = 0)
        $display("Time %0t: TB: Requesting Write LRS to Address 0 (Target: %b)...", $time, TB_LRS_VAL);
        tb_addr = 0;          // Set address
        tb_data_in = TB_LRS_VAL; // Set data to LRS (0)
        tb_write_en = 1'b1;   // Assert write enable
        @(posedge clk);       // Core FSM reacts (IDLE -> START_WRITE)
        @(posedge clk);       // Core FSM reacts (START_WRITE -> WAIT_WRITE_COMPLETE), Cell FSM starts, busy goes high
        tb_write_en = 1'b0;   // De-assert write enable (core keeps selected_cell_write_en active until done)
        while (tb_busy) @(posedge clk); // Wait until the core (and thus the cell) is no longer busy

        @(posedge clk); // IMPORTANT: Wait one more clock cycle for data_out_reg to update after core FSM goes IDLE
        $display("Time %0t: TB: Write LRS to Addr 0 completed. Data_out (should be target state): %b (Expected: %b)", $time, tb_data_out, TB_LRS_VAL);
        #(CLK_PERIOD); // Add a small delay for print clarity

        // 3. Read from Address 0 (explicitly)
        $display("Time %0t: TB: Explicitly Reading from Address 0...", $time);
        tb_addr = 0;          // Ensure address is 0
        tb_read_en = 1'b1;    // Assert read enable
        @(posedge clk);       // Core FSM reacts (IDLE -> READING). data_out updates combinationaly.
        tb_read_en = 1'b0;    // De-assert read enable (core FSM is already back to IDLE)
        $display("Time %0t: TB: Read data from Addr 0: %b (Expected: %b)", $time, tb_data_out, TB_LRS_VAL);
        #(CLK_PERIOD);        // Wait for a full clock period

        // 4. Write to Address 1 (Set to LRS = 0)
        $display("Time %0t: TB: Requesting Write LRS to Address 1 (Target: %b)...", $time, TB_LRS_VAL);
        tb_addr = 1;
        tb_data_in = TB_LRS_VAL;
        tb_write_en = 1'b1;
        @(posedge clk);
        @(posedge clk);
        tb_write_en = 1'b0;
        while (tb_busy) @(posedge clk);
        @(posedge clk); // Wait one more cycle
        $display("Time %0t: TB: Write LRS to Addr 1 completed. Data_out (should be target state): %b (Expected: %b)", $time, tb_data_out, TB_LRS_VAL);
        #(CLK_PERIOD);

        // 5. Read from Address 1 (to confirm)
        $display("Time %0t: TB: Reading from Address 1...", $time);
        tb_addr = 1;
        tb_read_en = 1'b1;
        @(posedge clk);
        tb_read_en = 1'b0;
        $display("Time %0t: TB: Read data from Addr 1: %b (Expected: %b)", $time, tb_data_out, TB_LRS_VAL);
        #(CLK_PERIOD);

        // 6. Write to Address 0 (Reset to HRS = 1)
        $display("Time %0t: TB: Requesting Write HRS to Address 0 (Target: %b)...", $time, TB_HRS_VAL);
        tb_addr = 0;
        tb_data_in = TB_HRS_VAL;
        tb_write_en = 1'b1;
        @(posedge clk);
        @(posedge clk);
        tb_write_en = 1'b0;
        while (tb_busy) @(posedge clk);
        @(posedge clk); // Wait one more cycle
        $display("Time %0t: TB: Write HRS to Addr 0 completed. Data_out (should be target state): %b (Expected: %b)", $time, tb_data_out, TB_HRS_VAL);
        #(CLK_PERIOD);

        // 7. Read from Address 0 (to confirm)
        $display("Time %0t: TB: Reading from Address 0...", $time);
        tb_addr = 0;
        tb_read_en = 1'b1;
        @(posedge clk);
        tb_read_en = 1'b0;
        $display("Time %0t: TB: Read data from Addr 0: %b (Expected: %b)", $time, tb_data_out, TB_HRS_VAL);
        #(CLK_PERIOD);

        // 8. Test Endurance on Address 0
        $display("Time %0t: TB: Starting endurance test on Address 0 (Limit: %0d)...", $time, TB_CELL_ENDURANCE_LIMIT);
        tb_addr = 0;
        for (integer i = 0; i < TB_CELL_ENDURANCE_LIMIT + 5; i = i + 1) begin // Loop beyond limit
            tb_data_in = (i % 2 == 0) ? TB_LRS_VAL : TB_HRS_VAL; // Alternate LRS/HRS writes
            tb_write_en = 1'b1;
            @(posedge clk); // Core FSM reacts (IDLE -> START_WRITE)
            @(posedge clk); // Core FSM reacts (START_WRITE -> WAIT_WRITE_COMPLETE), Cell FSM starts, busy goes high
            tb_write_en = 1'b0;
            while (tb_busy) @(posedge clk); // Wait for the cell to finish its operation via core busy signal

            @(posedge clk); // IMPORTANT: Wait one more cycle for data_out_reg to update after the core goes IDLE

            $display("Time %0t: TB: Write %0d to Addr %0d (Target: %b), Read: %b, Cell 0 Failed: %b",
                        $time, i+1, tb_addr, tb_data_in, tb_data_out, tb_all_failed_cells[0]);
            #(CLK_PERIOD); // Keep this for timing between loop iterations
        end

        // 9. Check final status of Address 0
        $display("Time %0t: TB: Final check on Address 0 - Failed status: %b", $time, tb_all_failed_cells[0]);

        $display("--- ReRAM Core Test Complete ---");
        $finish; // End simulation
    end

endmodule