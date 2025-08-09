// system_top.v
// This module integrates the ReRAM IP and the TRQ ADC.

`timescale 1ns / 1ps

module system_top (
    input wire           clk,             // System Clock (e.g., from Zynq PS FCLK_CLK0)
    input wire           rst,             // System Reset (e.g., from Zynq PS Processor System Reset)
    input wire [1:0] sel_crossbar_out, // Selector for which crossbar output to measure (0 to C_NUM_OUTPUTS-1)

    // For debugging/status on Zybo LEDs
    output wire          adc_done_led,
    output wire [7:0] final_digital_out, // Output from the TRQ ADC

    // Example signals for ReRAM emulation control and status
    input wire           start_reram_emulation, // Signal to start a new ReRAM emulation cycle
    output wire          reram_emulation_done   // Status from ReRAM emulation
);

// --- Parameters for ReRAM Crossbar Emulation ---
// These should match the parameters used in your reram_crossbar_emulation module
parameter RERAM_C_NUM_INPUTS    = 8;  // Number of input activations
parameter RERAM_C_NUM_OUTPUTS   = 4;  // Number of output sums (4 in this example, feeding a single ADC)
parameter RERAM_C_INPUT_WIDTH   = 8;  // Bit width of input activations
parameter RERAM_C_WEIGHT_WIDTH  = 8;  // Bit width of weights
parameter RERAM_C_ACC_WIDTH     = 16; // Bit width for accumulation (crossbar output)

// --- Internal Wires ---
wire [RERAM_C_ACC_WIDTH-1:0] reram_output_sums [RERAM_C_NUM_OUTPUTS-1:0]; // Array of outputs from ReRAM emulation
wire [11:0]                  selected_reram_output;                       // 12-bit selected output for ADC
wire                         start_trq_adc;                             // Control signal for TRQ ADC
wire                         done_trq_adc;                              // Done signal from TRQ ADC (connected below)

// --- Instantiation of ReRAM Crossbar Emulation IP ---
// input_activations and weight_matrix are now handled internally within the IP (reram_crossbar_emulation)
// and would typically be loaded via AXI registers or BRAMs in a real system.
reram_crossbar_emulation #(
    .C_NUM_INPUTS    (RERAM_C_NUM_INPUTS),
    .C_NUM_OUTPUTS   (RERAM_C_NUM_OUTPUTS),
    .C_INPUT_WIDTH   (RERAM_C_INPUT_WIDTH),
    .C_WEIGHT_WIDTH  (RERAM_C_WEIGHT_WIDTH),
    .C_ACC_WIDTH     (RERAM_C_ACC_WIDTH)
) reram_emu_inst (
    .clk             (clk),
    .rst             (rst),
    .start_emulation (start_reram_emulation),
    .emulation_done  (reram_emulation_done),
    // Removed .input_activations and .weight_matrix connections here
    .output_sums     (reram_output_sums)
);

// --- Multiplexer to select one output from the ReRAM Emulation ---
// This selects which of the RERAM_C_NUM_OUTPUTS gets fed to the single ADC.
// We are truncating the RERAM_C_ACC_WIDTH (16-bit) to 12-bit for the ADC input.
// This truncation assumes the most significant 12 bits are sufficient or desired.
always @(*) begin
    case (sel_crossbar_out)
        2'b00: selected_reram_output = reram_output_sums[0][11:0]; // Take MSB 12 bits
        2'b01: selected_reram_output = reram_output_sums[1][11:0];
        2'b10: selected_reram_output = reram_output_sums[2][11:0];
        2'b11: selected_reram_output = reram_output_sums[3][11:0];
        default: selected_reram_output = reram_output_sums[0][11:0]; // Default to first output
    endcase
end

// --- Basic Control Logic for the TRQ ADC ---
// You would typically have a more sophisticated FSM here to manage
// when to start the ADC based on ReRAM emulation completion and
// which output to select, then wait for ADC done.
reg start_adc_reg = 0;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        start_adc_reg <= 0;
    end else begin
        // Example: Start ADC when ReRAM emulation is done and we haven't started yet
        // You'd add logic here to iterate through sel_crossbar_out if needed
        if (reram_emulation_done && !start_adc_reg) begin
            start_adc_reg <= 1; // Start ADC for the selected output
        end else if (done_trq_adc) begin // Use the corrected 'done_trq_adc'
            start_adc_reg <= 0; // Stop ADC once conversion is done
        end
    end
end
assign start_trq_adc = start_adc_reg;

// --- Instantiation of the TRQ ADC Top Module ---
trq_adc_top adc_top_inst (
    .clk           (clk),
    .rst           (rst),              // Pass system reset to ADC top
    .analog_input  (selected_reram_output), // Connect the selected and truncated ReRAM output
    .start_conversion (start_trq_adc), // Pass the start signal to ADC
    .adc_output    (final_digital_out),
    .done_led      (adc_done_led)
);

// Connect the done signal from the ADC top module
assign done_trq_adc = adc_top_inst.done_led; // Correctly drive this wire

endmodule