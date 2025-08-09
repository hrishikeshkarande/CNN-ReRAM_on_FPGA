`timescale 1ns / 1ps

module trq_adc_top(
    input wire clk,           // Clock from Zybo
    input wire rst,           // Reset button
    input wire [11:0] analog_input, // Analog input (approximated in digital domain!)
    output wire [7:0] adc_output,  // 8-bit ADC output
    output wire done_led      // Done status (tied to an LED)
);

// --- Internal wires and registers --- //
reg start_adc;
wire done_adc;

// --- Instantiation of the TRQ ADC --- //
twin_range_sar_adc adc_inst (
    .clk(clk),
    .start(start_adc),
    .analog_input(analog_input),
    .digital_out(adc_output),
    .done(done_adc)
);

// --- Control FSM or simple logic (simplified) --- //
always @(posedge clk or posedge rst) begin
    if (rst)
        start_adc <= 0;
    else
        start_adc <= 1; // continuous conversions for now
end

// --- Connect done to LED --- //
assign done_led = done_adc;

endmodule
