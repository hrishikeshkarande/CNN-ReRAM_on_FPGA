//////////////////////////////////////////////////////////////////////////////////
// Company: elab
// Engineer: Hrishikesh Karande
// 
// Create Date: 08/18/2025 07:17:40 PM
// Design Name: 
// Module Name: reram_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: CPT ReRAM Where At
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns/1ps



module reram_core #(
    parameter integer MEM_DEPTH   = 16,
    parameter integer ADDR_WIDTH  = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH),

    // Optional pass-through parameterization for each cell
    parameter logic LRS_STATE           = 1'b0,
    parameter logic HRS_STATE           = 1'b1,
    parameter integer SET_DELAY_CYCLES    = 10,
    parameter integer RESET_DELAY_CYCLES  = 10,
    parameter integer ENDURANCE_LIMIT     = 1000
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // Single-port access (word/bit-level)
    input  wire                     write_en,      // one-cycle pulse to launch an op on selected cell
    input  wire [ADDR_WIDTH-1:0]    addr,          // selects cell
    input  wire                     target_state,  // 0 = LRS (SET), 1 = HRS (RESET)
    input  wire                     data_in,       // bit to store when SET/LRS

    // "Selected cell" outputs (multiplexed by addr)
    output wire                     read_data,     // resistive state of selected cell
    output wire                     data_out,      // stored bit of selected cell (only valid in LRS)
    output wire                     busy,          // busy of selected cell
    output wire                     failed         // endurance failure of selected cell
);

    // Per-cell signals
    wire [MEM_DEPTH-1:0] cell_busy;
    wire [MEM_DEPTH-1:0] cell_failed;
    wire [MEM_DEPTH-1:0] cell_read_state;
    wire [MEM_DEPTH-1:0] cell_data_out;

    genvar i;
    generate
        for (i = 0; i < MEM_DEPTH; i++) begin : GEN_CELLS
            reram_cell #(
                .LRS_STATE(LRS_STATE),
                .HRS_STATE(HRS_STATE),
                .SET_DELAY_CYCLES(SET_DELAY_CYCLES),
                .RESET_DELAY_CYCLES(RESET_DELAY_CYCLES),
                .ENDURANCE_LIMIT(ENDURANCE_LIMIT)
            ) u_cell (
                .clk        (clk),
                .rst_n      (rst_n),
                .write_en   (write_en && (addr == i)),
                .target_state(target_state),
                .data_in    (data_in),
                .read_data  (cell_read_state[i]),
                .data_out   (cell_data_out[i]),
                .busy       (cell_busy[i]),
                .failed     (cell_failed[i])
            );
        end
    endgenerate

    // Multiplex the selected cell's outputs
    assign read_data = cell_read_state[addr];
    assign data_out  = cell_data_out[addr];
    assign busy      = cell_busy[addr];
    assign failed    = cell_failed[addr];

endmodule