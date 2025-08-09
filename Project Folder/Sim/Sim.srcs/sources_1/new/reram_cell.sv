//reram_cell.sv
//Basic behavioral model for a single ReRAM Cell

`timescale 1ns / 1ps

module reram_cell #( /*Parameters*/
    parameter LRS_STATE = 1'b0,
    parameter HRS_STATE = 1'b1,             //This is out default state
    parameter SET_DELAY_CYCLES = 10,        //Requires 10 clock cyles for SET operation // SET is changing to LRS
    parameter RESET_DELAY_CYCLES = 10,      //Requires 10 clock cyles for RESET operation //RESET is changing to HRS
    parameter ENDURANCE_LIMIT = 1000        //Can work for 1000 write cycles
) ( /*Port Defs*/
    input wire clk,
    input wire rst_n,                       //Active low reset
    
    input wire write_en,                    //Asserts to initiate a write opeartion
    input wire target_state,                //We tell the cell the state that we have to change to i.e (LRS_STATE or HRS_STATE)
    output wire read_data,                  //Tells us the current state of the cell 
    
    output wire busy,                       //Tells us that the cell is undergoing a write operation                       
    output wire failed                      //Tells us that the cell has reached the endurance limit
);
    
    /*Internal Signals*/
    //Internal state of the ReRAM cell (LRS_STATE or HRS_STATE)
    reg current_state;
    
    //Assignment from  internel state to output, This is combinational assignment
    assign read_data = current_state;
    
    //Counter for SET/RESET delays
    reg [31:0] delay_counter;
    
    //State machine for write operations (IDLE, SETTING, RESETTING)
    localparam IDLE = 2'b00;
    localparam SETTING = 2'b01;
    localparam RESETTING = 2'b10;
    reg [1:0] write_fsm_state;
    
    //Endurance Counter
    reg [31:0] endurance_counter;
    reg cell_failed_flag;
    
    assign busy = (write_fsm_state != IDLE);
    assign failed = cell_failed_flag;
        
    /*Behavior Modelling*/
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= HRS_STATE; //These are all non blocking assignments so they will execute in parallel inside this always block, sequential elements
            delay_counter <= 0;
            write_fsm_state <= IDLE;
            endurance_counter <= 0;
            cell_failed_flag <= 1'b0;
            
            $display("Time %0t: Cell RESET! Initial State: %b, Endurance: %0d", $time, HRS_STATE, 0);
        end else begin
                // Check for cell failure due to endurance. This check happens every cycle.
                // If already failed, remain failed. If not failed and limit reached, set flag.
            if (!cell_failed_flag && endurance_counter >= ENDURANCE_LIMIT) begin
                cell_failed_flag <= 1'b1;
                $display("Time %0t: Cell FAILED! Endurance Limit (%0d) reached. Current endurance: %0d", $time, ENDURANCE_LIMIT, endurance_counter);
            end
            
            //Main Write FSM
                    case (write_fsm_state)
                        IDLE: begin
                            // Only start a write if write_en is asserted AND cell has not failed
                            if (write_en && !cell_failed_flag) begin
                                if (target_state == LRS_STATE) begin
                                    write_fsm_state <= SETTING;
                                    delay_counter <= 0;
                                    $display("Time %0t: Cell (IDLE->SETTING) for target %b. Current: %b", $time, target_state, current_state);
                                 end else if (target_state == HRS_STATE) begin
                                                write_fsm_state <= RESETTING;
                                                delay_counter <= 0;
                                                $display("Time %0t: Cell (IDLE->RESETTING) for target %b. Current: %b", $time, target_state, current_state);
                                           end
                            end else if (write_en && cell_failed_flag) begin
                                       $display("Time %0t: Cell (IDLE) Write attempt to FAILED cell. Current: %b, Endurance: %0d", $time, current_state, endurance_counter);
                                      // Cell remains in IDLE, state does not change, endurance_counter does not increment.
                            end
                        end
                        SETTING: begin
                            if (delay_counter < SET_DELAY_CYCLES - 1) begin
                                delay_counter <= delay_counter + 1;
                                $display("Time %0t: Cell (SETTING) Delay: %0d/%0d. Current State: %b", $time, delay_counter, SET_DELAY_CYCLES, current_state);
                            end else begin
                                current_state <= LRS_STATE; //State change happens here
                                //There should be some writing logic here 
                                endurance_counter <= endurance_counter + 1; //Increment on successful write opeartion
                                write_fsm_state <= IDLE; //Changing state back to IDLE
                                $display("Time %0t: Cell (SETTING->IDLE) COMPLETE. New State: %b, Endurance: %0d", $time, LRS_STATE, endurance_counter + 1);
                            end
                       end
                       RESETTING: begin
                            if (delay_counter < RESET_DELAY_CYCLES - 1) begin
                                delay_counter <= delay_counter + 1;
                                $display("Time %0t: Cell (RESETTING) Delay: %0d/%0d. Current State: %b", $time, delay_counter, RESET_DELAY_CYCLES, current_state);
                            end else begin
                                current_state <= HRS_STATE; //State change happens here
                                //There should be some writing logic here
                                endurance_counter <= endurance_counter + 1; //Increment on successful write opeartion
                                write_fsm_state <= IDLE; //Changing state back to IDLE
                                $display("Time %0t: Cell (RESETTING->IDLE) COMPLETE. New State: %b, Endurance: %0d", $time, HRS_STATE, endurance_counter + 1);
                            end
                       end
                       default: begin //This state should never be reached, if ever reached then take the machine to IDLE
                            write_fsm_state <= IDLE;
                       end
                   endcase
          end
   end
   endmodule