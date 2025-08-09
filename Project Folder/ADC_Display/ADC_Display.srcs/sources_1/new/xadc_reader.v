module xadc_reader (
    input wire clk,             // System clock (e.g., 125MHz)
    input wire vp_in, vn_in,    // Analog inputs (connected to JXADC / VAUXP0/N0)
    output wire [11:0] adc_data // Final 12-bit output
);

    wire [15:0] do_out;         // 16-bit output from XADC
    wire drdy;                  // Data Ready signal from XADC

    // Clock divider for XADC DCLK (max ~2.5MHz - 4MHz for 7-series)
    // Divide 125MHz by 50 to get 2.5MHz
    reg [6:0] dclk_div_count = 7'd0;
    reg xadc_dclk_reg = 1'b0;

    always @(posedge clk) begin
        if (dclk_div_count == 7'd49) begin
            dclk_div_count <= 7'd0;
            xadc_dclk_reg <= ~xadc_dclk_reg; // Toggle every 50 cycles (2.5MHz)
        end else begin
            dclk_div_count <= dclk_div_count + 1;
        end
    end
    wire xadc_dclk = xadc_dclk_reg; // Use the divided clock for DCLK

    // XADC primitive
    XADC #(
        .INIT_40(16'h2100),     // Config 0: Continuous seq mode, calibration enabled
        .INIT_41(16'h0001),     // Config 1: Enable VCCAUX and VAUX0 (JXADC)
                                // If you only want VAUX0: 16'h0001
        .INIT_42(16'h0400)      // Config 2: No averaging (for initial test)
                                // For 16-sample averaging: 16'h0400
    ) xadc_inst (
        .CONVST(1'b0),          // External convert start (not used for continuous mode)
        .CONVSTCLK(1'b0),       // External convert clock (not used for continuous mode)
        .DADDR(7'h10),          // Data Register Address: 0x10 for VAUX0 conversion result
        .DCLK(xadc_dclk),       // Clock for DRP interface (must be slow enough)
        .DEN(1'b1),             // Data Enable: Always read
        .DI(16'b0),             // Data Input: Not used for reading
        .DWE(1'b0),             // Data Write Enable: Not writing to registers
        .RESET(1'b0),           // Reset: Not asserting reset
        .VAUXP({15'b0, vp_in}), // Connect vp_in to VAUXP[0]
        .VAUXN({15'b0, vn_in}), // Connect vn_in to VAUXN[0]
        .VP(1'b0),              // Tie off unused dedicated VP/VN
        .VN(1'b0),              // Tie off unused dedicated VP/VN
        .DO(do_out),            // 16-bit Data Output
        .DRDY(drdy)             // Data Ready signal
    );

    // Capture adc_data when drdy pulses (optional, but good practice for stable reads)
    reg [11:0] adc_data_reg;
    always @(posedge xadc_dclk) begin // Use the XADC DCLK for capturing
        if (drdy) begin
            adc_data_reg <= do_out[15:4];
        end
    end
    assign adc_data = adc_data_reg;

endmodule