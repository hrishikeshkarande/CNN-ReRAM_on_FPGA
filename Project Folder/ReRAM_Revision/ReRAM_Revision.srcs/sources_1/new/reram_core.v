`timescale 1ns/1ps

module reram_core #(
    parameter int MEM_DEPTH  = 16,
    parameter int ADDR_WIDTH = $clog2(MEM_DEPTH)
)(
    input  wire clk,
    input  wire rst_n,

    input  wire write_en,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire target_state,
    input  wire data_in,

    output wire read_data,
    output wire data_out,
    output wire busy,
    output wire failed
);

    wire [MEM_DEPTH-1:0] cell_busy;
    wire [MEM_DEPTH-1:0] cell_failed;
    wire [MEM_DEPTH-1:0] cell_read_data;
    wire [MEM_DEPTH-1:0] cell_data_out;

    genvar i;
    generate
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin : CELL_ARRAY
            localparam int I = i;
            wire we_i = write_en && (addr == I[ADDR_WIDTH-1:0]);

            reram_cell u_cell (
                .clk(clk),
                .rst_n(rst_n),
                .write_en(we_i),
                .target_state(target_state),
                .data_in(data_in),
                .read_data(cell_read_data[i]),
                .data_out(cell_data_out[i]),
                .busy(cell_busy[i]),
                .failed(cell_failed[i])
            );
        end
    endgenerate

    // Optional: protect non power-of-two depths
    wire addr_in_range = (addr < MEM_DEPTH);

    assign read_data = addr_in_range ? cell_read_data[addr] : 1'b0;
    assign data_out  = addr_in_range ? cell_data_out [addr] : 1'b0;
    assign busy      = addr_in_range ? cell_busy     [addr] : 1'b0;
    assign failed    = addr_in_range ? cell_failed   [addr] : 1'b0;

endmodule
