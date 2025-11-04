/*
 * Testbench for ReRAM AXI-Lite Wrapper
 *
 * This testbench emulates an AXI Master (like the Zynq PS) to test
 * the 'reram_axilite_wrapper' module.
 *
 * Tests:
 * - Basic AXI reads/writes to the ReRAM memory space.
 * - AXI reads from the status and monitoring register space.
 * - Verifies write-to-read-only registers is safely ignored.
 * - Verifies endurance counters increment.
 *
 * Vivado 2018.1 friendly: all temp vectors hoisted to module scope.
 */
module tb_reram_axilite_wrapper;

    // Test parameters
    parameter int CLK_PERIOD         = 10;
    parameter int MEMORY_DEPTH       = 16;
    parameter int DATA_WIDTH         = 32;
    parameter int AXI_ADDR_WIDTH     = 10;
    parameter int CORE_ADDR_WIDTH    = $clog2(MEMORY_DEPTH);

    // Clock and reset
    logic S_AXI_ACLK;
    logic S_AXI_ARESETN;

    // AXI Interface Signals
    logic [AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR;
    logic [2:0]                S_AXI_AWPROT;
    logic                      S_AXI_AWVALID;
    logic                      S_AXI_AWREADY;
    logic [DATA_WIDTH-1:0]     S_AXI_WDATA;
    logic [DATA_WIDTH/8-1:0]   S_AXI_WSTRB;
    logic                      S_AXI_WVALID;
    logic                      S_AXI_WREADY;
    logic [1:0]                S_AXI_BRESP;
    logic                      S_AXI_BVALID;
    logic                      S_AXI_BREADY;
    logic [AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR;
    logic [2:0]                S_AXI_ARPROT;
    logic                      S_AXI_ARVALID;
    logic                      S_AXI_ARREADY;
    logic [DATA_WIDTH-1:0]     S_AXI_RDATA;
    logic [1:0]                S_AXI_RRESP;
    logic                      S_AXI_RVALID;
    logic                      S_AXI_RREADY;

    // Test control
    int error_count = 0;
    int test_phase  = 0;

    // ===== TB temporaries hoisted to module scope (Vivado 2018.1) =====
    logic [DATA_WIDTH-1:0] tb_rdata;
    logic [DATA_WIDTH-1:0] tb_expected;
    logic [31:0]           tb_reg_val;
    logic [7:0]            tb_cycle_count;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    reram_axilite_wrapper #(
        .MEMORY_DEPTH(MEMORY_DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CORE_ADDR_WIDTH(CORE_ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) dut (
        .S_AXI_ACLK(S_AXI_ACLK),
        .S_AXI_ARESETN(S_AXI_ARESETN),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWPROT(S_AXI_AWPROT),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARPROT(S_AXI_ARPROT),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        S_AXI_ACLK = 0;
        forever #(CLK_PERIOD/2) S_AXI_ACLK = ~S_AXI_ACLK;
    end

    //==========================================================================
    // Test Tasks
    //==========================================================================

    // Task: Reset system
    task automatic reset_system();
    begin
        $display("[%0t] Resetting AXI Wrapper and Core...", $time);
        S_AXI_ARESETN = 0;
        // Set all AXI inputs to idle state
        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_BREADY  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;
        S_AXI_AWADDR  = '0;
        S_AXI_WDATA   = '0;
        S_AXI_WSTRB   = '1;
        S_AXI_ARADDR  = '0;
        S_AXI_AWPROT  = '0;
        S_AXI_ARPROT  = '0;
        
        repeat(5) @(posedge S_AXI_ACLK);
        S_AXI_ARESETN = 1;
        repeat(2) @(posedge S_AXI_ACLK);
        $display("[%0t] Reset complete", $time);
    end
    endtask

    // Task: AXI Write (Blocking)
    task automatic axi_write(input [AXI_ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
    begin
        $display("[%0t] AXI Write: 0x%08X to Addr 0x%03X", $time, data, addr);
        @(posedge S_AXI_ACLK);
        S_AXI_AWVALID <= 1;
        S_AXI_AWADDR  <= addr;
        S_AXI_WVALID  <= 1;
        S_AXI_WDATA   <= data;
        S_AXI_WSTRB   <= 4'hF; // Write all 4 bytes

        // Wait for both AW and W channels to be ready
        wait (S_AXI_AWREADY && S_AXI_WREADY);
        @(posedge S_AXI_ACLK);
        S_AXI_AWVALID <= 0;
        S_AXI_WVALID  <= 0;
        
        // Wait for write response
        S_AXI_BREADY <= 1;
        wait (S_AXI_BVALID);
        @(posedge S_AXI_ACLK);
        S_AXI_BREADY <= 0;
        
        if (S_AXI_BRESP != 2'b00) begin
            $display("[ERROR] AXI Write failed with BRESP = %b", S_AXI_BRESP);
            error_count++;
        end
    end
    endtask

    // Task: AXI Read (Blocking)
    task automatic axi_read(input [AXI_ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
    begin
        $display("[%0t] AXI Read: from Addr 0x%03X", $time, addr);
        @(posedge S_AXI_ACLK);
        S_AXI_ARVALID <= 1;
        S_AXI_ARADDR  <= addr;
        
        wait (S_AXI_ARREADY);
        @(posedge S_AXI_ACLK);
        S_AXI_ARVALID <= 0;
        
        // Wait for read data
        S_AXI_RREADY <= 1;
        wait (S_AXI_RVALID);
        data = S_AXI_RDATA;
        @(posedge S_AXI_ACLK);
        S_AXI_RREADY <= 0;

        $display("[%0t] AXI Read Data: 0x%08X", $time, data);
        if (S_AXI_RRESP != 2'b00) begin
            $display("[ERROR] AXI Read failed with RRESP = %b", S_AXI_RRESP);
            error_count++;
        end
    end
    endtask

    // Task: Verify Read Data
    task automatic verify_read(input [AXI_ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] expected);
    begin
        axi_read(addr, tb_rdata);
        if (tb_rdata !== expected) begin
            $display("[ERROR] Data mismatch at 0x%03X: expected=0x%08X, actual=0x%08X", 
                    addr, expected, tb_rdata);
            error_count++;
        end else begin
            $display("[PASS] Data verification passed at 0x%03X", addr);
        end
    end
    endtask

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        $display("=========================================================================");
        $display("ReRAM AXI-Lite Wrapper Testbench");
        $display("=========================================================================");
        
        reset_system();
        
        // ------------------------- Phase 1 -------------------------
        test_phase = 1;
        $display("\n--- Phase 1: Basic Memory Read/Write Operations (Mem Space 0x000) ---");
        
        axi_write(10'h000, 32'hDEADBEEF); // Write to word 0
        axi_write(10'h004, 32'hCAFEBABE); // Write to word 1
        axi_write(10'h03C, 32'h12345678); // Write to word 15 (last address)
        
        verify_read(10'h000, 32'hDEADBEEF);
        verify_read(10'h004, 32'hCAFEBABE);
        verify_read(10'h03C, 32'h12345678);
        
        $display("Phase 1 completed with %0d errors", error_count);
        
        // ------------------------- Phase 2 -------------------------
        test_phase = 2;
        $display("\n--- Phase 2: Read Status Registers (Reg Space 0x100) ---");

        // After 3 writes and 3 reads:
        verify_read(10'h100, 32'd3); // ADDR_TOTAL_READS
        verify_read(10'h104, 32'd3); // ADDR_TOTAL_WRITES
        verify_read(10'h108, 32'd0); // ADDR_WORD_ERRORS (should be 0)
        verify_read(10'h10C, 32'd0); // ADDR_CELL_ERRORS_ANY (should be 0)

        $display("Phase 2 completed with %0d errors", error_count);

        // ------------------------- Phase 3 -------------------------
        test_phase = 3;
        $display("\n--- Phase 3: Verify Endurance Counter Updates (Reg Space 0x120) ---");
        
        $display("Performing 5 more writes to word 2 (Addr 0x008)...");
        for (int i = 0; i < 5; i++) begin
            axi_write(10'h008, 32'hA5A50000 + i);
        end
        
        $display("Reading packed write cycle counters (Addr 0x120)...");
        // ADDR_WRITE_CYCLES_0_3 (words 3, 2, 1, 0)
        axi_read(10'h120, tb_reg_val); 
        tb_expected = {8'd0, 8'd5, 8'd1, 8'd1}; // {word3, word2, word1, word0}
        
        if (tb_reg_val !== tb_expected) begin
             $display("[ERROR] Write cycle counter mismatch: expected=0x%08X, actual=0x%08X", 
                    tb_expected, tb_reg_val);
            error_count++;
        end else begin
            $display("[PASS] Write cycle counters correct (0x%08X)", tb_reg_val);
        end

        $display("Phase 3 completed with %0d errors", error_count);

        // ------------------------- Phase 4 -------------------------
        test_phase = 4;
        $display("\n--- Phase 4: Test Write to Read-Only Register ---");
        
        $display("Attempting to write 0xBADF00D to TOTAL_READS (0x100)...");
        axi_write(10'h100, 32'hBADF00D);
        
        $display("Reading back TOTAL_READS. Should be unchanged.");
        // We did 3 reads in P1, 4 in P2, 1 in P3. Total = 8
        verify_read(10'h100, 32'd8); 

        $display("Phase 4 completed with %0d errors", error_count);

        // ------------------------- Phase 5 -------------------------
        test_phase = 5;
        $display("\n--- Phase 5: Test Cell Error Array Read (Reg Space 0x200) ---");

        $display("Reading cell error flags for word 0 (Addr 0x200). Should be 0.");
        verify_read(10'h200, 32'd0);
        $display("Reading cell error flags for word 15 (Addr 0x23C). Should be 0.");
        verify_read(10'h23C, 32'd0);

        $display("Phase 5 completed with %0d errors", error_count);

        // ------------------------- Summary -------------------------
        $display("\n=========================================================================");
        $display("AXI Wrapper Test Summary");
        $display("=========================================================================");
        $display("Total test errors: %0d", error_count);

        if (error_count == 0) begin
            $display("*** ALL AXI WRAPPER TESTS PASSED! ***");
        end else begin
            $display("*** %0d AXI WRAPPER TESTS FAILED ***", error_count);
        end
        $display("=========================================================================");

        #(CLK_PERIOD * 10);
        $finish;
    end
    
    // --- Simulation Control ---
    initial begin
        #(CLK_PERIOD * 20000); // 20K cycles timeout
        $display("[ERROR] Simulation timeout!");
        $finish;
    end
    
    initial begin
        $dumpfile("tb_reram_axilite_wrapper.vcd");
        $dumpvars(0, tb_reram_axilite_wrapper);
    end

endmodule