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
    input  wire data_in,

    output wire read_data,
    output wire data_out,
    output wire busy,
    output wire failed
);

    reg current_state;
    reg stored_data;

    assign read_data = current_state;
    assign data_out  = (current_state == LRS_STATE) ? stored_data : 1'b0;

    reg [31:0] delay_counter;
    localparam IDLE      = 2'b00;
    localparam SETTING   = 2'b01;
    localparam RESETTING = 2'b10;
    reg [1:0] write_fsm_state;

    reg [31:0] endurance_counter;
    reg cell_failed_flag;

    assign busy   = (write_fsm_state != IDLE);
    assign failed = cell_failed_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state      <= HRS_STATE;
            stored_data        <= 1'b0;
            delay_counter      <= 32'd0;
            write_fsm_state    <= IDLE;
            endurance_counter  <= 32'd0;
            cell_failed_flag   <= 1'b0;
            `ifdef SIM
              $display("Time %0t: Cell RESET!", $time);
            `endif
        end else begin
            if (!cell_failed_flag && endurance_counter >= ENDURANCE_LIMIT) begin
                cell_failed_flag <= 1'b1;
                `ifdef SIM
                  $display("Time %0t: Cell FAILED!", $time);
                `endif
            end

            case (write_fsm_state)
                IDLE: begin
                    if (write_en && !cell_failed_flag) begin
                        if (target_state == LRS_STATE) begin
                            write_fsm_state <= SETTING;
                            delay_counter   <= 32'd0;
                        end else begin
                            write_fsm_state <= RESETTING;
                            delay_counter   <= 32'd0;
                        end
                    end
                end

                SETTING: begin
                    if (delay_counter < SET_DELAY_CYCLES - 1) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        current_state     <= LRS_STATE;
                        stored_data       <= data_in;
                        endurance_counter <= endurance_counter + 1;
                        write_fsm_state   <= IDLE;
                    end
                end

                RESETTING: begin
                    if (delay_counter < RESET_DELAY_CYCLES - 1) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        current_state     <= HRS_STATE;
                        stored_data       <= 1'b0;
                        endurance_counter <= endurance_counter + 1;
                        write_fsm_state   <= IDLE;
                    end
                end

                default: write_fsm_state <= IDLE;
            endcase
        end
    end
endmodule
