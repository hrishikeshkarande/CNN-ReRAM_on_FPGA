// twin_range_sar_adc.v
// Your Twin-Range SAR ADC module with added reset.

`timescale 1ns / 1ps

module twin_range_sar_adc(
    input clk,
    input rst,          // Added rst input
    input start,
    input [11:0] analog_input,
    output reg [7:0] digital_out,
    output reg done
);

// Internal registers initialized at declaration (good!)
reg busy = 0;
reg [1:0] phase = 0; // 0=idle, 1=coarse, 2=fine
reg [3:0] bit_count = 0;
reg [11:0] coarse_result = 0; // This seems unused in the current logic, kept for consistency.
reg [11:0] fine_result = 0;   // This seems unused in the current logic, kept for consistency.
reg [11:0] dac_value = 0;

reg [11:0] current_bit_weight;

// Threshold for coarse/fine phase (1.0V equivalent for 12-bit, assuming 0-2V range)
parameter THRESHOLD = 12'd2048; // Corresponds to half of 2^12 (4096 values)

// Main state machine (or sequential logic) with synchronous reset
always @(posedge cllk or posedge rst) begin // Added rst to sensitivity list
    if (rst) begin
        // Reset all registers to their initial state
        digital_out <= 0;
        done <= 0;
        busy <= 0;
        phase <= 0;
        bit_count <= 0;
        coarse_result <= 0;
        fine_result <= 0;
        dac_value <= 0;
        current_bit_weight <= 0;
    end else begin
        // Default assignment for 'done' to be single cycle pulse
        done <= 0;

        if (start && !busy) begin
            // Start new conversion
            busy <= 1;
            bit_count <= 0;
            coarse_result <= 0; // Clear previous result for a new conversion
            fine_result <= 0;    // Clear previous result for a new conversion
            digital_out <= 0;    // Clear output at start of new conversion

            // Determine phase based on input magnitude
            if (analog_input > THRESHOLD) begin
                phase <= 1; // Coarse phase (for inputs > 1.0V)
                // Start with MSB for coarse search (value 2048, which is 1000_0000_0000_bin)
                dac_value <= 12'b1000_0000_0000;
            end else begin
                phase <= 2; // Fine phase (for inputs <= 1.0V)
                // Start with MSB for fine search (value 1024, which is 0100_0000_0000_bin)
                dac_value <= 12'b0100_0000_0000;
            end
        end
        else if (busy) begin
            if (bit_count < 12) begin // Still converting
                // Calculate the weight of the current bit we are trying to determine
                current_bit_weight = (12'b1 << (11 - bit_count));

                // Try adding the current bit weight to the DAC value and compare
                if ((dac_value | current_bit_weight) <= analog_input) begin
                    // If adding this bit doesn't exceed analog_input, keep it.
                    // This means the current bit is '1'.
                    dac_value <= dac_value | current_bit_weight;
                end else begin
                    // If adding this bit makes it too high, then this bit is '0'.
                    // The dac_value remains unchanged (we don't add this bit).
                    dac_value <= dac_value;
                end

                bit_count <= bit_count + 1; // Move to the next bit
            end
            else begin // Conversion for this phase is complete (bit_count is 12)
                busy <= 0; // ADC is no longer busy
                done <= 1; // Signal that conversion is done for one cycle

                // Assign the final digital_out based on the phase and the determined dac_value
                if (phase == 1) begin
                    // For coarse phase, MSB is implicitly 1, and the determined bits are [10:4]
                    digital_out <= {1'b1, dac_value[10:4]};
                end else begin
                    // For fine phase, MSB is implicitly 0, and the determined bits are [10:4]
                    digital_out <= {1'b0, dac_value[10:4]};
                end
                // Optionally reset phase to IDLE if you want it to wait for another 'start'
                // phase <= 0; // Reset phase to IDLE after conversion
            end
        end
    end
end

endmodule