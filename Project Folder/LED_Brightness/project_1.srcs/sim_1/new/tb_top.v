`timescale 1ns / 1ps

module tb_top();
    reg clk = 0;
    reg [7:0] ja = 0;
    wire [3:0] led;
    
    // Instantiate DUT
    top uut (
        .clk(clk),
        .ja(ja),
        .led(led)
    );
    
    // 125MHz clock (8ns period)
    always #4 clk = ~clk;
    
    // Analog input simulation
    real vauxp14 = 0.8;  // 0.8V on AD14
    real vauxp7 = 0.2;    // 0.2V on AD7
    real vauxp15 = 1.0;   // 1.0V on AD15
    real vauxp6 = 0.0;    // 0.0V on AD6
    
    // Convert voltages to digital representation
    wire [11:0] adc14_val = vauxp14 * 4095;
    wire [11:0] adc7_val = vauxp7 * 4095;
    wire [11:0] adc15_val = vauxp15 * 4095;
    wire [11:0] adc6_val = vauxp6 * 4095;
    
    // Display initial configuration
    initial begin
        $display("[%0t] Simulation started", $time);
        $display("[%0t] Analog inputs configured:", $time);
        $display("       AD14: %0.2fV (0x%0h)", vauxp14, adc14_val);
        $display("       AD7:  %0.2fV (0x%0h)", vauxp7, adc7_val);
        $display("       AD15: %0.2fV (0x%0h)", vauxp15, adc15_val);
        $display("       AD6:  %0.2fV (0x%0h)", vauxp6, adc6_val);
    end
    
    // Monitor XADC channel switching
    always @(uut.daddr) begin
        $display("[%0t] XADC switching to channel: 0x%0h", $time, uut.daddr);
        case(uut.daddr)
            7'h1E: begin
                force uut.dout = {adc14_val, 4'b0};
                $display("[%0t]   Reading AD14 (0x%0h)", $time, {adc14_val, 4'b0});
            end
            7'h17: begin
                force uut.dout = {adc7_val, 4'b0};
                $display("[%0t]   Reading AD7 (0x%0h)", $time, {adc7_val, 4'b0});
            end
            7'h1F: begin
                force uut.dout = {adc15_val, 4'b0};
                $display("[%0t]   Reading AD15 (0x%0h)", $time, {adc15_val, 4'b0});
            end
            7'h16: begin
                force uut.dout = {adc6_val, 4'b0};
                $display("[%0t]   Reading AD6 (0x%0h)", $time, {adc6_val, 4'b0});
            end
            default: force uut.dout = 16'h0;
        endcase
    end
    
    // Monitor PWM updates
    always @(posedge uut.pwm_count[7]) begin
        $display("[%0t] PWM duty cycles updated:", $time);
        $display("       LD0: 0x%0h (%0d/255)", uut.pwm_duty0, uut.pwm_duty0);
        $display("       LD1: 0x%0h (%0d/255)", uut.pwm_duty1, uut.pwm_duty1);
        $display("       LD2: 0x%0h (%0d/255)", uut.pwm_duty2, uut.pwm_duty2);
        $display("       LD3: 0x%0h (%0d/255)", uut.pwm_duty3, uut.pwm_duty3);
    end
    
    initial begin
        // Initialize differential inputs
        $display("[%0t] Initializing Pmod JA inputs...", $time);
        ja[0] = 1; ja[4] = 0;  // AD14
        ja[1] = 1; ja[5] = 0;  // AD7
        ja[2] = 1; ja[6] = 0;  // AD15
        ja[3] = 0; ja[7] = 0;  // AD6
        
        // Monitor LED outputs
        $monitor("[%0t] LED outputs: %b (LD0:%b LD1:%b LD2:%b LD3:%b)", 
               $time, led, led[0], led[1], led[2], led[3]);
        
        // Run simulation
        #1000;
        $display("[%0t] Simulation complete", $time);
        $finish;
    end
endmodule