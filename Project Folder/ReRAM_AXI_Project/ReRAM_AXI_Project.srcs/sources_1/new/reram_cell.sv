`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: elab
// Engineer: Hrishikesh Karande
// 
// Create Date: 08/18/2025 07:17:40 PM
// Design Name: 
// Module Name: reram_cell
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


module reram_cell #(
    parameter LRS_STATE = 1'b0,
    parameter HRS_STATE = 1'b1,
    parameter SET_DELAY_CYCLES = 10,
    parameter RESET_DELAY_CYCLES = 10,
    parameter ENDURANCE_LIMIT = 1000
)(
    input  wire clk,
    input  wire rst_n,

    input  wire write_en,
    input  wire target_state,
    input  wire data_in,          // << NEW - data bit to store

    output wire read_data,        // Current resistive state (LRS/HRS)
    output wire data_out,         // << NEW - stored data when in LRS
    output wire busy,
    output wire failed
);

    reg current_state;
    reg stored_data;              // << NEW - holds data_in when in LRS

    assign read_data = current_state;
    assign data_out  = (current_state == LRS_STATE) ? stored_data : 1'b0;

    reg [31:0] delay_counter;
    localparam IDLE = 2'b00;
    localparam SETTING = 2'b01;
    localparam RESETTING = 2'b10;
    reg [1:0] write_fsm_state;

    reg [31:0] endurance_counter;
    reg cell_failed_flag;

    assign busy   = (write_fsm_state != IDLE);
    assign failed = cell_failed_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state      <= HRS_STATE;
            stored_data        <= 1'b0;        // << reset stored data
            delay_counter      <= 0;
            write_fsm_state    <= IDLE;
            endurance_counter  <= 0;
            cell_failed_flag   <= 1'b0;
            $display("Time %0t: Cell RESET!", $time);
        end else begin
            if (!cell_failed_flag && endurance_counter >= ENDURANCE_LIMIT) begin
                cell_failed_flag <= 1'b1;
                $display("Time %0t: Cell FAILED!", $time);
            end

            case (write_fsm_state)
                IDLE: begin
                    if (write_en && !cell_failed_flag) begin
                        if (target_state == LRS_STATE) begin
                            write_fsm_state <= SETTING;
                            delay_counter   <= 0;
                        end else if (target_state == HRS_STATE) begin
                            write_fsm_state <= RESETTING;
                            delay_counter   <= 0;
                        end
                    end
                end

                SETTING: begin
                    if (delay_counter < SET_DELAY_CYCLES - 1) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        current_state     <= LRS_STATE;
                        stored_data       <= data_in; // << capture new data
                        endurance_counter <= endurance_counter + 1;
                        write_fsm_state   <= IDLE;
                    end
                end

                RESETTING: begin
                    if (delay_counter < RESET_DELAY_CYCLES - 1) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        current_state     <= HRS_STATE;
                        stored_data       <= 1'b0; // << clear data
                        endurance_counter <= endurance_counter + 1;
                        write_fsm_state   <= IDLE;
                    end
                end

                default: write_fsm_state <= IDLE;
            endcase
        end
    end
endmodule
