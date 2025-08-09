// testbench.sv
// Testbench for the reram_cell module

`timescale 1ns / 1ps

module reram_cell_tb;

    // -------------------------------------------------------------------------
    // Parameters for the testbench
    // These should match or be compatible with the DUT's parameters
    // -------------------------------------------------------------------------
    localparam LRS_STATE_TB = 1'b0; // Low Resistance State
    localparam HRS_STATE_TB = 1'b1; // High Resistance State (default)

    localparam SET_DELAY_CYCLES_TB = 5;
    localparam RESET_DELAY_CYCLES_TB = 5;
    localparam ENDURANCE_LIMIT_TB = 8;

    localparam CLOCK_PERIOD = 10; // 10ns clock period (100 MHz clock)

    // -------------------------------------------------------------------------
    // Testbench Signals (wires and regs)
    // Connect these to the DUT's ports
    // -------------------------------------------------------------------------
    reg clk;
    reg rst_n;
    reg write_en;
    reg target_state;
    wire read_data;
    wire busy;
    wire failed;

    // Declare loop variable 'i' here, at the module level
    reg [31:0] i; // <--- ADD THIS LINE (replaces 'integer i;' inside initial block)

    // -------------------------------------------------------------------------
    // Instantiate the Device Under Test (DUT)
    // Connect testbench signals to the DUT's ports
    // -------------------------------------------------------------------------
    reram_cell #(
        .LRS_STATE(LRS_STATE_TB),
        .HRS_STATE(HRS_STATE_TB),
        .SET_DELAY_CYCLES(SET_DELAY_CYCLES_TB),
        .RESET_DELAY_CYCLES(RESET_DELAY_CYCLES_TB),
        .ENDURANCE_LIMIT(ENDURANCE_LIMIT_TB)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .target_state(target_state),
        .read_data(read_data),
        .busy(busy),
        .failed(failed)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // Generates a continuous clock signal
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD / 2) clk = ~clk; // Toggle clock every half period
    end

    // -------------------------------------------------------------------------
    // Test Scenario
    // This initial block contains the sequence of operations for testing
    // -------------------------------------------------------------------------
    initial begin
        $display("-----------------------------------------------------");
        $display("           ReRAM Cell Testbench Started            ");
        $display("-----------------------------------------------------");

        // Initialize signals
        rst_n = 0; // Assert reset
        write_en = 0;
        target_state = HRS_STATE_TB; // Default value, will be set later

        // Apply reset for a few clock cycles
        #(CLOCK_PERIOD * 5); // Hold reset for 5 clock cycles
        rst_n = 1; // De-assert reset
        $display("Time %0t: Reset Released. Initializing test sequence.", $time);

        // --- Test Case 1: Initial State Check ---
        #(CLOCK_PERIOD); // Wait one cycle after reset for signals to settle
        $display("Time %0t: Initial state check. Expected: %b, Actual: %b. Failed: %b",
                 $time, HRS_STATE_TB, read_data, failed);
        if (read_data !== HRS_STATE_TB) begin
            $error("Initial state check FAILED! Expected HRS_STATE.");
        end

        // --- Test Case 2: SET Operation (HRS -> LRS) ---
        $display("Time %0t: Starting SET operation (HRS -> LRS).", $time);
        write_en = 1;
        target_state = LRS_STATE_TB;
        #(CLOCK_PERIOD); // Apply write_en for one cycle

        write_en = 0; // De-assert write_en; DUT should now be busy setting

        // Wait for SET operation to complete
        wait (dut.write_fsm_state == dut.IDLE);
        #(CLOCK_PERIOD); // Give an extra cycle for read_data to update

        $display("Time %0t: SET operation completed. Expected: %b, Actual: %b. Busy: %b, Failed: %b",
                 $time, LRS_STATE_TB, read_data, busy, failed);
        if (read_data !== LRS_STATE_TB || busy !== 0) begin
            $error("SET operation FAILED! State or busy signal incorrect.");
        end

        // --- Test Case 3: RESET Operation (LRS -> HRS) ---
        $display("Time %0t: Starting RESET operation (LRS -> HRS).", $time);
        write_en = 1;
        target_state = HRS_STATE_TB;
        #(CLOCK_PERIOD); // Apply write_en for one cycle

        write_en = 0; // De-assert write_en; DUT should now be busy resetting

        // Wait for RESET operation to complete
        wait (dut.write_fsm_state == dut.IDLE);
        #(CLOCK_PERIOD);

        $display("Time %0t: RESET operation completed. Expected: %b, Actual: %b. Busy: %b, Failed: %b",
                 $time, HRS_STATE_TB, read_data, busy, failed);
        if (read_data !== HRS_STATE_TB || busy !== 0) begin
            $error("RESET operation FAILED! State or busy signal incorrect.");
        end

        // --- Test Case 4: Repeated Writes to hit Endurance Limit ---
        $display("Time %0t: Starting repeated write operations to test endurance limit (%0d).",
                 $time, ENDURANCE_LIMIT_TB);

        // 'i' is now declared at the module level, so no need for declaration here
        for (i = 0; i < ENDURANCE_LIMIT_TB + 5; i++) begin // Go slightly over limit
            if (!failed) begin // Only write if cell hasn't failed
                // Alternate between SET and RESET
                write_en = 1;
                target_state = (read_data == HRS_STATE_TB) ? LRS_STATE_TB : HRS_STATE_TB;
                #(CLOCK_PERIOD); // Assert write_en for one cycle
                write_en = 0;

                wait (dut.write_fsm_state == dut.IDLE);
                #(CLOCK_PERIOD); // Allow internal state and outputs to settle

                $display("Time %0t: Write Cycle %0d. Current State: %b, Busy: %b, Failed: %b",
                         $time, i + 1, read_data, busy, failed);

                // Basic check after each write
                if (!failed && (read_data !== ((target_state == LRS_STATE_TB) ? LRS_STATE_TB : HRS_STATE_TB))) begin
                    $error("Write cycle %0d FAILED! State mismatch.", i + 1);
                end
            end else begin
                $display("Time %0t: Cell FAILED at cycle %0d. Remaining cycles will attempt writes to a failed cell.", $time, i);
                break; // Exit loop once cell fails to speed up simulation
            end
        end

        // --- Test Case 5: Attempt Write to Failed Cell ---
        $display("Time %0t: Attempting write to a FAILED cell.", $time);
        if (failed) begin
            write_en = 1;
            target_state = (read_data == HRS_STATE_TB) ? LRS_STATE_TB : HRS_STATE_TB;
            #(CLOCK_PERIOD * (SET_DELAY_CYCLES_TB + 5)); // Give ample time for "write"
            write_en = 0;
            $display("Time %0t: Write attempt on failed cell completed. Busy: %b, Failed: %b, Read Data: %b",
                     $time, busy, failed, read_data);
            if (busy !== 0) begin
                $error("Failed cell should not be busy after write attempt.");
            end
        end else begin
            $warning("Cell did not fail during endurance test, skipping 'write to failed cell' test.");
        end


        $display("-----------------------------------------------------");
        $display("           ReRAM Cell Testbench Finished           ");
        $display("-----------------------------------------------------");
        $finish; // End simulation
    end

    // -------------------------------------------------------------------------
    // Monitoring and Debugging
    // You can add additional always blocks or initial blocks for more specific
    // monitoring if needed. For now, the DUT's $display statements are sufficient.
    // -------------------------------------------------------------------------
    // initial begin
    //     $dumpfile("reram_cell_tb.vcd"); // For waveform viewing
    //     $dumpvars(0, reram_cell_tb);
    // end

endmodule