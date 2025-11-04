`timescale 1ns/1ps

module tb_axi_reram;

  // ===== Parameters you can tweak =====
  localparam int MEMORY_DEPTH        = 16;     // words
  localparam int DATA_WIDTH          = 32;
  localparam int ADDR_WIDTH_WORDS    = $clog2(MEMORY_DEPTH);
  localparam int C_S_AXI_DATA_WIDTH  = 32;
  localparam int C_S_AXI_ADDR_WIDTH  = 32;

  // ReRAM timing to see latency in sim
  localparam int READ_DELAY_CYCLES   = 3;
  localparam int SET_DELAY_CYCLES    = 5;
  localparam int RESET_DELAY_CYCLES  = 5;
  localparam int MAX_WRITE_CYCLES    = 200;

  // Derived
  localparam int ADDR_LSB            = $clog2(C_S_AXI_DATA_WIDTH/8); // =2 for 32b
  localparam int CLK_PERIOD_NS       = 10;  // 100 MHz

  // ===== AXI signals =====
  logic                          aclk;
  logic                          aresetn;

  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
  logic [2:0]                    s_axi_awprot;
  logic                          s_axi_awvalid;
  logic                          s_axi_awready;

  logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
  logic                          s_axi_wvalid;
  logic                          s_axi_wready;

  logic [1:0]                    s_axi_bresp;
  logic                          s_axi_bvalid;
  logic                          s_axi_bready;

  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
  logic [2:0]                    s_axi_arprot;
  logic                          s_axi_arvalid;
  logic                          s_axi_arready;

  logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
  logic [1:0]                    s_axi_rresp;
  logic                          s_axi_rvalid;
  logic                          s_axi_rready;

  // ===== DUT =====
  axi_reram_memory_controller_lite #(
    .MEMORY_DEPTH       (MEMORY_DEPTH),
    .DATA_WIDTH         (DATA_WIDTH),
    .ADDR_WIDTH         (ADDR_WIDTH_WORDS),
    .READ_DELAY_CYCLES  (READ_DELAY_CYCLES),
    .SET_DELAY_CYCLES   (SET_DELAY_CYCLES),
    .RESET_DELAY_CYCLES (RESET_DELAY_CYCLES),
    .MAX_WRITE_CYCLES   (MAX_WRITE_CYCLES),
    .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH)
  ) dut (
    .S_AXI_ACLK    (aclk),
    .S_AXI_ARESETN (aresetn),

    .S_AXI_AWADDR  (s_axi_awaddr),
    .S_AXI_AWPROT  (s_axi_awprot),
    .S_AXI_AWVALID (s_axi_awvalid),
    .S_AXI_AWREADY (s_axi_awready),

    .S_AXI_WDATA   (s_axi_wdata),
    .S_AXI_WSTRB   (s_axi_wstrb),
    .S_AXI_WVALID  (s_axi_wvalid),
    .S_AXI_WREADY  (s_axi_wready),

    .S_AXI_BRESP   (s_axi_bresp),
    .S_AXI_BVALID  (s_axi_bvalid),
    .S_AXI_BREADY  (s_axi_bready),

    .S_AXI_ARADDR  (s_axi_araddr),
    .S_AXI_ARPROT  (s_axi_arprot),
    .S_AXI_ARVALID (s_axi_arvalid),
    .S_AXI_ARREADY (s_axi_arready),

    .S_AXI_RDATA   (s_axi_rdata),
    .S_AXI_RRESP   (s_axi_rresp),
    .S_AXI_RVALID  (s_axi_rvalid),
    .S_AXI_RREADY  (s_axi_rready)
  );

  // ===== Clock & reset =====
  initial begin
    aclk = 1'b0;
    forever #(CLK_PERIOD_NS/2) aclk = ~aclk;
  end

  initial begin
    aresetn = 1'b0;
    s_axi_awaddr  = '0; s_axi_awprot  = 3'b000; s_axi_awvalid = 1'b0;
    s_axi_wdata   = '0; s_axi_wstrb   = '0;     s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = '0; s_axi_arprot  = 3'b000; s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;

    // VCD
    $dumpfile("tb_axi_reram.vcd");
    $dumpvars(0, tb_axi_reram);

    repeat (5) @(posedge aclk);
    aresetn = 1'b1;
  end

  // ===== AXI-Lite Master BFM tasks =====
  localparam [1:0] RESP_OKAY   = 2'b00;
  localparam [1:0] RESP_SLVERR = 2'b10;

  task automatic axi_write(
      input  logic [C_S_AXI_ADDR_WIDTH-1:0] addr,
      input  logic [C_S_AXI_DATA_WIDTH-1:0] data,
      input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb,
      input  [1:0] exp_bresp,
      input  bit   aw_first  // if 1: AW first then W; else W first then AW (to test ordering)
  );
    begin
      // Deassert BREADY until we expect response
      s_axi_bready <= 1'b0;

      if (aw_first) begin
        // AW first
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        @(posedge aclk);
        while (!s_axi_awready) @(posedge aclk);
        s_axi_awvalid <= 1'b0;

        // Then W
        s_axi_wdata  <= data;
        s_axi_wstrb  <= wstrb;
        s_axi_wvalid <= 1'b1;
        @(posedge aclk);
        while (!s_axi_wready) @(posedge aclk);
        s_axi_wvalid <= 1'b0;
      end else begin
        // W first
        s_axi_wdata  <= data;
        s_axi_wstrb  <= wstrb;
        s_axi_wvalid <= 1'b1;
        @(posedge aclk);
        while (!s_axi_wready) @(posedge aclk);
        s_axi_wvalid <= 1'b0;

        // Then AW
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        @(posedge aclk);
        while (!s_axi_awready) @(posedge aclk);
        s_axi_awvalid <= 1'b0;
      end

      // Get response
      s_axi_bready <= 1'b1;
      @(posedge aclk);
      while (!s_axi_bvalid) @(posedge aclk);
      if (s_axi_bresp !== exp_bresp) begin
        $error("[%0t] WRITE @0x%08h expected BRESP=%0b, got %0b",
               $time, addr, exp_bresp, s_axi_bresp);
        $fatal;
      end
      // consume response
      @(posedge aclk);
      s_axi_bready <= 1'b0;
    end
  endtask

  task automatic axi_read(
      input  logic [C_S_AXI_ADDR_WIDTH-1:0] addr,
      input  [1:0] exp_rresp,
      output logic [C_S_AXI_DATA_WIDTH-1:0] rdata_out
  );
    begin
      // Address
      s_axi_araddr  <= addr;
      s_axi_arvalid <= 1'b1;
      @(posedge aclk);
      while (!s_axi_arready) @(posedge aclk);
      s_axi_arvalid <= 1'b0;

      // Data
      s_axi_rready <= 1'b1;
      @(posedge aclk);
      while (!s_axi_rvalid) @(posedge aclk);
      if (s_axi_rresp !== exp_rresp) begin
        $error("[%0t] READ  @0x%08h expected RRESP=%0b, got %0b",
               $time, addr, exp_rresp, s_axi_rresp);
        $fatal;
      end
      rdata_out = s_axi_rdata;
      @(posedge aclk);
      s_axi_rready <= 1'b0;
    end
  endtask

  // ===== Scoreboard helpers =====
  function automatic [C_S_AXI_ADDR_WIDTH-1:0] word_to_addr(input int unsigned word_index);
    return word_index << ADDR_LSB;
  endfunction

  // ===== Test sequence =====
  initial begin : test_seq
    logic [31:0] rd;
    int unsigned invalid_word = MEMORY_DEPTH; // one past the last valid word

    // Wait for reset deassert
    @(posedge aclk);
    wait (aresetn == 1'b1);

    // 1) Clean aligned write (all WSTRB=1), AW-before-W
    $display("[%0t] T1: write OKAY, AW first", $time);
    axi_write(word_to_addr(0), 32'hDEAD_BEEF, 4'b1111, RESP_OKAY, /*aw_first*/ 1);

    // 2) Read it back (should see same), expect OKAY
    $display("[%0t] T2: read OKAY", $time);
    axi_read(word_to_addr(0), RESP_OKAY, rd);
    if (rd !== 32'hDEAD_BEEF) begin
      $error("Readback mismatch: expected 0xDEADBEEF got 0x%08h", rd);
      $fatal;
    end

    // 3) Try partial write (WSTRB=0011) => wrapper should return SLVERR; W-before-AW path
    $display("[%0t] T3: partial write WSTRB=0011 -> expect SLVERR, W first", $time);
    axi_write(word_to_addr(0), 32'hAAAA_BBBB, 4'b0011, RESP_SLVERR, /*aw_first*/ 0);

    // 4) Verify word unchanged after failed partial write
    $display("[%0t] T4: read after partial write (should be unchanged)", $time);
    axi_read(word_to_addr(0), RESP_OKAY, rd);
    if (rd !== 32'hDEAD_BEEF) begin
      $error("After partial write SLVERR, value changed! got 0x%08h", rd);
      $fatal;
    end

    // 5) Another OKAY write to a different word
    $display("[%0t] T5: write OKAY to word 3", $time);
    axi_write(word_to_addr(3), 32'h1234_5678, 4'b1111, RESP_OKAY, /*aw_first*/ 1);

    // 6) Read it back
    $display("[%0t] T6: read OKAY word 3", $time);
    axi_read(word_to_addr(3), RESP_OKAY, rd);
    if (rd !== 32'h1234_5678) begin
      $error("Readback mismatch word3: expected 0x12345678 got 0x%08h", rd);
      $fatal;
    end

    // 7) Invalid address read -> SLVERR
    $display("[%0t] T7: invalid read -> SLVERR", $time);
    axi_read(word_to_addr(invalid_word), RESP_SLVERR, rd);

    // 8) Invalid address write -> SLVERR
    $display("[%0t] T8: invalid write -> SLVERR", $time);
    axi_write(word_to_addr(invalid_word), 32'hCAFEBABE, 4'b1111, RESP_SLVERR, /*aw_first*/ 1);

    // 9) Back-to-back ops while MC is busy: issue read then immediately another read
    //    The wrapper is single-op; second will be accepted only after first completes.
    $display("[%0t] T9: back-to-back reads", $time);
    fork
      begin
        axi_read(word_to_addr(0), RESP_OKAY, rd);
      end
      begin
        // small delay then do another read
        repeat (1) @(posedge aclk);
        axi_read(word_to_addr(3), RESP_OKAY, rd);
      end
    join

    $display("[%0t] All tests PASSED.", $time);
    repeat (10) @(posedge aclk);
    $finish;
  end

endmodule
