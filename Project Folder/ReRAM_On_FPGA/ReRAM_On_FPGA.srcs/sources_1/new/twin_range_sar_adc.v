`timescale 1ns / 1ps

module twin_range_sar_adc(
    input clk,
    input start,
    input [11:0] analog_input,
    output reg [7:0] digital_out,
    output reg done
);

// Internal registers initialized at declaration (good!)
reg busy = 0;
reg [1:0] phase = 0; // 0=idle, 1=coarse, 2=fine
reg [3:0] bit_count = 0;
reg [11:0] coarse_result = 0;
reg [11:0] fine_result = 0;
reg [11:0] dac_value = 0;

// ******************************************************
// CORRECTED: Declare 'current_bit_weight' at the module level
reg [11:0] current_bit_weight;
// ******************************************************

// Initialize ALL output registers (and any other uninitialized internal regs if applicable)
initial begin
    digital_out = 0;
    done = 0;
    // It's good practice to list all initializations here, even if already done at declaration
    busy = 0;
    phase = 0;
    bit_count = 0;
    coarse_result = 0;
    fine_result = 0;
    dac_value = 0;
    current_bit_weight = 0; // Initialize the new register as well
end

// Threshold for coarse/fine phase (1.0V equivalent)
parameter THRESHOLD = 12'd2048;

// Main state machine
always @(posedge clk) begin
    // Default assignments
    done <= 0; // This will make 'done' go high for only one cycle
    
    if (start && !busy) begin
        // Start new conversion
        busy <= 1;
        bit_count <= 0;
        coarse_result <= 0; // Clear previous result for a new conversion
        fine_result <= 0;   // Clear previous result for a new conversion
        digital_out <= 0;   // Clear output at start of new conversion
        
        // Determine phase
        if (analog_input > THRESHOLD) begin
            phase <= 1; // Coarse phase
            // For coarse phase, we're trying to determine bits 11-4 (8 bits total, where bit 11 is implicit 1)
            // The first trial will be for bit 10 (value 2048).
            dac_value <= 12'b1000_0000_0000; // Start with MSB for coarse search (2048)
        end else begin
            phase <= 2; // Fine phase
            // For fine phase, we're trying to determine bits 11-5 (7 bits from fine, plus 0 as MSB)
            // The first trial will be for bit 10 (value 1024)
            dac_value <= 12'b0100_0000_0000; // Start with MSB for fine search (1024)
        end
    end 
    else if (busy) begin
        if (bit_count < 12) begin // Still converting
            // SAR conversion logic:
            // This is the core of how SAR works:
            // 1. Try to set the current bit (add its weight to dac_value).
            // 2. Compare this new dac_value with analog_input.
            // 3. If trial dac_value is <= analog_input, keep the bit.
            // 4. If trial dac_value is > analog_input, discard the bit (undo the addition).
            
            // Calculate the weight of the current bit we are trying to determine
            // This line is now an assignment, not a declaration, which is allowed.
            if (phase == 1) begin // Coarse phase, starts from 11th bit (MSB) downwards
                current_bit_weight = (12'b1 << (11 - bit_count));
            end else begin // Fine phase, starts from 11th bit (MSB) downwards
                current_bit_weight = (12'b1 << (11 - bit_count));
            end

            // Try adding the current bit weight to the DAC value
            if ((dac_value | current_bit_weight) <= analog_input) begin
                // If adding this bit doesn't exceed analog_input, keep it.
                // This means the current bit is '1'.
                dac_value <= dac_value | current_bit_weight;
            end else begin
                // If adding this bit makes it too high, then this bit is '0'.
                // The dac_value remains unchanged (we don't add this bit).
                dac_value <= dac_value; // Explicitly showing no change
            end
            
            bit_count <= bit_count + 1; // Move to the next bit
        end
        else begin // Conversion for this phase is complete (bit_count is 12)
            busy <= 0; // ADC is no longer busy
            done <= 1; // Signal that conversion is done for one cycle

            // Assign the final digital_out based on the phase and the determined dac_value
            if (phase == 1) begin
                digital_out <= {1'b1, dac_value[10:4]};
            end else begin
                digital_out <= {1'b0, dac_value[10:4]};
            end
        end
    end
end

endmodule