// top.v (modified)

`timescale 1ns / 1ps

module top(
    input clk,
    input [7:0] ja,
    output [3:0] led // Keep LEDs for now, but they will be off if not driven
);
    reg [6:0] daddr = 0; // address of channel to be read
    reg [1:0] ledidx = 0; // index of the led to capture data for (now for ADC channel)

    wire eoc; // xadc end of conversion flag
    wire [15:0] dout; // xadc data out bus
    wire drdy;

    reg [1:0] _drdy = 0; // delayed data ready signal for edge detection

    reg [7:0] data0 = 0, // stored XADC data, only the uppermost byte
              data1 = 0,
              data2 = 0,
              data3 = 0;

    // --- TM1637 related signals ---
    wire tm1637_clk;
    wire tm1637_dio;
    // --- End TM1637 related signals ---

    xadc_wiz_0 myxadc (
        .dclk_in         (clk),
        .den_in          (eoc), // drp enable, start a new conversion whenever the last one has ended
        .dwe_in          (0),
        .daddr_in        (daddr), // channel address
        .di_in           (0),
        .do_out          (dout), // data out
        .drdy_out        (drdy), // data ready
        .eoc_out         (eoc), // end of conversion

        .vauxn6          (ja[7]),
        .vauxp6          (ja[3]),

        .vauxn7          (ja[5]),
        .vauxp7          (ja[1]),

        .vauxn14         (ja[4]),
        .vauxp14         (ja[0]),

        .vauxn15         (ja[6]),
        .vauxp15         (ja[2])
    );

    always@(posedge clk)
        _drdy <= {_drdy[0], drdy};

    always@(*)
        case (ledidx) // Cycle through XADC channels
        0: daddr = 7'h1E; // Corresponds to vauxp14/vauxn14 (JA0/JA4)
        1: daddr = 7'h17; // Corresponds to vauxp7/vauxn7 (JA1/JA5)
        2: daddr = 7'h1F; // Corresponds to vauxp15/vauxn15 (JA2/JA6)
        3: daddr = 7'h16; // Corresponds to vauxp6/vauxn6 (JA3/JA7)
        default: daddr = 7'h1E;
        endcase

    always@(posedge clk) begin
        if (_drdy == 2'b10) begin // on negative edge of drdy
            ledidx <= ledidx + 1;
            case (ledidx)
            0: data0 <= dout[15:8]; // Capture upper 8 bits for each channel
            1: data1 <= dout[15:8];
            2: data2 <= dout[15:8];
            3: data3 <= dout[15:8];
            endcase
        end
    end

    // --- Instantiate TM1637 Driver ---
    // You might want to display one of the `dataX` values.
    // For example, display `data0`.
    tm1637_driver my_tm1637_driver (
        .clk        (clk),
        .reset_n    (1'b1), // Assuming no explicit reset for now, tie to high
        .data_in    (data0), // Send the 8-bit ADC value
        .tm_clk     (tm1637_clk),
        .tm_dio     (tm1637_dio)
    );
    // --- End TM1637 Driver Instantiation ---

    // The onboard LEDs will no longer be driven by ADC values directly.
    // You can repurpose them or leave them off.
    assign led[0] = 0;
    assign led[1] = 0;
    assign led[2] = 0;
    assign led[3] = 0; // Turn off the onboard LEDs
endmodule