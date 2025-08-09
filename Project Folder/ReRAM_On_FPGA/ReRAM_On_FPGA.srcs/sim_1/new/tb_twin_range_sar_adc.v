`timescale 1ns / 1ps

module tb_twin_range_sar_adc;

// Parameters
reg clk;
reg start;
reg [11:0] analog_input;
wire [7:0] digital_out;
wire done;

// Instantiate DUT
twin_range_sar_adc uut (
    .clk(clk),
    .start(start),
    .analog_input(analog_input),
    .digital_out(digital_out),
    .done(done)
);

// Clock Generation (100 MHz)
always #5 clk = ~clk;

// Main test sequence
initial begin
    // Initialize all signals driven by the testbench at time 0
    clk = 0;
    start = 0;
    analog_input = 0;
    
    // Give some time for initial conditions to settle
    // This #100 also allows the clock to start toggling for 10 cycles
    #100; 
    
    // Monitoring: Now that signals are initialized, $monitor will show valid values
    $monitor("TIME=%0t: START=%b DONE=%b DOUT=%h (Analog_Input=%d)",  // Added analog_input to monitor
              $time, start, done, digital_out, analog_input);
    
    $display("\n=== Starting Testbench Simulation ===");
    
    // --- Test Case 1: Fine Conversion --- //
    $display("\n=== Starting Fine Conversion Test ===");
    analog_input = 12'd1024;  // Represents an input voltage
    start = 1;
    #10 start = 0;
    
    // Wait for conversion to finish, with a 1us timeout
    fork
        begin
            @(posedge done); // Wait for done to go high
        end
        begin
            #1000; // Timeout delay (1000ns = 1us)
            $display("ERROR: Timeout waiting for fine conversion at TIME=%0t!", $time);
            $finish;
        end
    join
    
    $display("Fine Conversion Complete: Input=%d, Output=%d (0x%h)",
              analog_input, digital_out, digital_out);
    
    #100; // Small delay between test cases
    
    // --- Test Case 2: Coarse Conversion --- //
    $display("\n=== Starting Coarse Conversion Test ===");
    analog_input = 12'd3000;  // Represents a different input voltage
    start = 1;
    #10 start = 0;
    
    // Wait for conversion to finish, with a 1us timeout
    fork
        begin
            @(posedge done); // Wait for done to go high
        end
        begin
            #1000; // Timeout delay
            $display("ERROR: Timeout waiting for coarse conversion at TIME=%0t!", $time);
            $finish;
        end
    join
    
    $display("Coarse Conversion Complete: Input=%d, Output=%d (0x%h)",
              analog_input, digital_out, digital_out);
    
    #100; // Small delay at the end
    $display("\nAll tests completed successfully!");
    $finish;
end

// Waveform dump (for debugging)
initial begin
    $dumpfile("adc_sim.vcd");
    $dumpvars(0, tb_twin_range_sar_adc);
end

endmodule