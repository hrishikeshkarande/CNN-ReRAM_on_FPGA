`timescale 1 ns / 1 ps

module reram_axi_ip_v1_0_S00_AXI #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6, // enough bits for 8 registers (word aligned)
    parameter integer MEM_DEPTH          = 16
)
(
    // AXI4-Lite Slave Interface
    input  wire                           S_AXI_ACLK,
    input  wire                           S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]  S_AXI_AWADDR,
    input  wire                           S_AXI_AWVALID,
    output reg                            S_AXI_AWREADY,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]  S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                           S_AXI_WVALID,
    output reg                            S_AXI_WREADY,

    output reg  [1:0]                     S_AXI_BRESP,
    output reg                            S_AXI_BVALID,
    input  wire                           S_AXI_BREADY,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]  S_AXI_ARADDR,
    input  wire                           S_AXI_ARVALID,
    output reg                            S_AXI_ARREADY,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]  S_AXI_RDATA,
    output reg  [1:0]                     S_AXI_RRESP,
    output reg                            S_AXI_RVALID,
    input  wire                           S_AXI_RREADY
);

    // =========================================================================
    // Local parameters
    // =========================================================================
    localparam integer ADDR_LSB    = 2;   // word aligned
    localparam integer REG_SEL_MSB = 5;   // decode [5:2] for up to 8 regs

    localparam [2:0] REG_CONTROL   = 3'd0; // 0x00
    localparam [2:0] REG_ADDR      = 3'd1; // 0x04
    localparam [2:0] REG_DATA_IN   = 3'd2; // 0x08
    localparam [2:0] REG_STATUS    = 3'd3; // 0x0C
    localparam [2:0] REG_DATA_OUT  = 3'd4; // 0x10
    localparam [2:0] REG_READSTATE = 3'd5; // 0x14
    localparam [2:0] REG_VERSION   = 3'd6; // 0x18

    localparam [31:0] VERSION_WORD = 32'h0001_0000;

    // =========================================================================
    // Internal registers for ReRAM control
    // =========================================================================
    reg [3:0]             wr_sel, rd_sel;
    reg [31:0]            control_shadow;
    reg [C_S_AXI_ADDR_WIDTH-1:0] addr_reg;
    reg                   data_in_reg, target_state_reg;
    reg                   soft_reset_req;
    reg                   pending_cmd;
    reg                   pending_target_state;
    reg [C_S_AXI_ADDR_WIDTH-1:0] pending_addr;
    reg                   pending_data_in;

    // =========================================================================
    // Wires from core
    // =========================================================================
    wire core_read_state, core_data_out;
    wire busy_w, failed_w;
    reg  core_write_pulse;

    // =========================================================================
    // AXI WRITE CHANNEL
    // =========================================================================
    wire aw_hs = S_AXI_AWVALID & S_AXI_AWREADY;
    wire w_hs  = S_AXI_WVALID  & S_AXI_WREADY;
    wire wr_done = aw_hs & w_hs;

    // AWREADY/WREADY
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
        end else begin
            S_AXI_AWREADY <= (~S_AXI_AWREADY) & S_AXI_AWVALID;
            S_AXI_WREADY  <= (~S_AXI_WREADY)  & S_AXI_WVALID;
        end
    end

    // Write address latch
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            wr_sel <= 3'd0;
        else if (aw_hs)
            wr_sel <= S_AXI_AWADDR[REG_SEL_MSB:ADDR_LSB];
    end

    // BRESP
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= 2'b00;
        end else begin
            if (wr_done)
                S_AXI_BVALID <= 1'b1;
            else if (S_AXI_BVALID & S_AXI_BREADY)
                S_AXI_BVALID <= 1'b0;
        end
    end

    // Write data decode
    function [31:0] apply_wstrb;
        input [31:0] oldv, newv;
        input [3:0]  wstrb;
        begin
            apply_wstrb = oldv;
            if (wstrb[0]) apply_wstrb[7:0]   = newv[7:0];
            if (wstrb[1]) apply_wstrb[15:8]  = newv[15:8];
            if (wstrb[2]) apply_wstrb[23:16] = newv[23:16];
            if (wstrb[3]) apply_wstrb[31:24] = newv[31:24];
        end
    endfunction

    reg [31:0] newv, tmp_addr, tmp_din;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            addr_reg             <= 0;
            data_in_reg          <= 0;
            target_state_reg     <= 0;
            soft_reset_req       <= 0;
            pending_cmd          <= 0;
            pending_target_state <= 0;
            pending_addr         <= 0;
            pending_data_in      <= 0;
            control_shadow       <= 0;
        end else begin
            soft_reset_req <= 0; // clear each cycle

            if (wr_done) begin
                case (wr_sel)
                    REG_CONTROL: begin
                        newv = apply_wstrb(control_shadow, S_AXI_WDATA, S_AXI_WSTRB);
                        control_shadow   <= newv;
                        target_state_reg <= newv[1];
                        if (newv[2]) soft_reset_req <= 1'b1;
                        if (newv[0]) begin
                            pending_cmd          <= 1'b1;
                            pending_target_state <= newv[1];
                            pending_addr         <= addr_reg;
                            pending_data_in      <= data_in_reg;
                        end
                    end
                    REG_ADDR: begin
                        tmp_addr = apply_wstrb({{(32-C_S_AXI_ADDR_WIDTH){1'b0}}, addr_reg},
                                               S_AXI_WDATA, S_AXI_WSTRB);
                        addr_reg <= tmp_addr[C_S_AXI_ADDR_WIDTH-1:0];
                    end
                    REG_DATA_IN: begin
                        tmp_din = apply_wstrb({31'd0, data_in_reg},
                                              S_AXI_WDATA, S_AXI_WSTRB);
                        data_in_reg <= tmp_din[0];
                    end
                endcase
            end

            if (pending_cmd && !busy_w) begin
                target_state_reg <= pending_target_state;
                addr_reg         <= pending_addr;
                data_in_reg      <= pending_data_in;
            end
        end
    end

    // Small FSM for write pulse
    reg [1:0] cstate;
    localparam C_IDLE=0, C_WAIT=1, C_PULSE=2;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) cstate <= C_IDLE;
        else case(cstate)
            C_IDLE: if(pending_cmd) cstate <= C_WAIT;
            C_WAIT: if(!busy_w)     cstate <= C_PULSE;
            C_PULSE: cstate <= C_IDLE;
        endcase
    end

    always @(*) begin
        core_write_pulse = (cstate==C_PULSE);
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) pending_cmd <= 1'b0;
        else if (cstate==C_PULSE) pending_cmd <= 1'b0;
    end

    // =========================================================================
    // AXI READ CHANNEL
    // =========================================================================
    wire ar_hs = S_AXI_ARVALID & S_AXI_ARREADY;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            S_AXI_ARREADY <= 1'b0;
        else
            S_AXI_ARREADY <= (~S_AXI_ARREADY) & S_AXI_ARVALID;
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            rd_sel <= 3'd0;
        else if (ar_hs)
            rd_sel <= S_AXI_ARADDR[REG_SEL_MSB:ADDR_LSB];
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RRESP  <= 2'b00;
        end else begin
            if (ar_hs) S_AXI_RVALID <= 1'b1;
            else if (S_AXI_RVALID & S_AXI_RREADY) S_AXI_RVALID <= 1'b0;
        end
    end

    always @(*) begin
        case (rd_sel)
            REG_CONTROL:   S_AXI_RDATA = control_shadow;
            REG_ADDR:      S_AXI_RDATA = {{(32-C_S_AXI_ADDR_WIDTH){1'b0}}, addr_reg};
            REG_DATA_IN:   S_AXI_RDATA = {31'd0, data_in_reg};
            REG_STATUS:    S_AXI_RDATA = {30'd0, failed_w, busy_w};
            REG_DATA_OUT:  S_AXI_RDATA = {31'd0, core_data_out};
            REG_READSTATE: S_AXI_RDATA = {31'd0, core_read_state};
            REG_VERSION:   S_AXI_RDATA = VERSION_WORD;
            default:       S_AXI_RDATA = 32'hDEAD_BEEF;
        endcase
    end

    // =========================================================================
    // RERAM CORE INSTANTIATION
    // =========================================================================
    reram_core #(.MEM_DEPTH(16)) u_core (
        .clk          (S_AXI_ACLK),
        .rst_n        (S_AXI_ARESETN & ~soft_reset_req),
        .write_en     (core_write_pulse),
        .addr         (addr_reg),
        .target_state (target_state_reg),
        .data_in      (data_in_reg),
        .read_data    (core_read_state),
        .data_out     (core_data_out),
        .busy         (busy_w),
        .failed       (failed_w)
    );

endmodule


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

