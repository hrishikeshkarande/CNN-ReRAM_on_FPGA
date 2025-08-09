module top (
    input wire clk,           // Connect this to FPGA clock
    input wire vp_in,         // Analog input pin (JXADC)
    input wire vn_in,
    output wire [3:0] leds    // 4-bit LED output for testing
);

  wire [11:0] adc_data;

  // Instantiate the XADC reader
  xadc_reader u_xadc (
    .clk(clk),
    .vp_in(vp_in),
    .vn_in(vn_in),
    .adc_data(adc_data)
  );

  // Light up 4 LEDs based on MSBs of adc_data
  assign leds = adc_data[9:6];

endmodule