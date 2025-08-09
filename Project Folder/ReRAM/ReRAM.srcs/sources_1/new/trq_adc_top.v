// trq_adc_top.v
// Top module for the TRQ ADC, providing an interface for system_top.

`timescale 1ns / 1ps

module trq_adc_top(
    input wire clk,             // Clock from Zybo
    input wire rst,             // Reset button
    input wire [11:0] analog_input, // Analog input (approximated in digital domain!)
    input wire start_conversion, // New input to trigger ADC conversion
    output wire [7:0] adc_output,   // 8-bit ADC output
    output wire done_led        // Done status (tied to an LED)
);

// --- Internal wires and registers --- //
wire done_adc; // Internal done signal from twin_range_sar_adc

// --- Instantiation of the TRQ ADC --- //
twin_range_sar_adc adc_inst (
    .clk(clk),
    .rst(rst),                // Pass reset to the SAR ADC
    .start(start_conversion), // Connect new start input
    .analog_input(analog_input),
    .digital_out(adc_output),
    .done(done_adc)
);

// --- Connect done to LED --- //
assign done_led = done_adc;

endmodule