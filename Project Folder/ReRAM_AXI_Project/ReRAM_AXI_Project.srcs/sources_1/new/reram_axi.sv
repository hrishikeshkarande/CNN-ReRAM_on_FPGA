// Verilog-2001 refactor of reram_axi (no SystemVerilog features)
// - No declarations inside procedural blocks
// - No $clog2 usage
// - No indexing of function return values
// - Portable to Vivado as Verilog-2001

`timescale 1ns/1ps

module reram_axi #(
    parameter integer MEM_DEPTH             = 16,
    // Keep a simple explicit default for address width to avoid $clog2
    parameter integer ADDR_WIDTH            = 4,

    // Pass-through cell parameters
    parameter LRS_STATE                     = 1'b0,
    parameter HRS_STATE                     = 1'b1,
    parameter integer SET_DELAY_CYCLES      = 10,
    parameter integer RESET_DELAY_CYCLES    = 10,
    parameter integer ENDURANCE_LIMIT       = 1000
)(
    input  wire              s_axi_aclk,
    input  wire              s_axi_aresetn,

    // AXI4-Lite Slave
    input  wire [31:0]       s_axi_awaddr,
    input  wire              s_axi_awvalid,
    output reg               s_axi_awready,

    input  wire [31:0]       s_axi_wdata,
    input  wire [3:0]        s_axi_wstrb,
    input  wire              s_axi_wvalid,
    output reg               s_axi_wready,

    output reg  [1:0]        s_axi_bresp,
    output reg               s_axi_bvalid,
    input  wire              s_axi_bready,

    input  wire [31:0]       s_axi_araddr,
    input  wire              s_axi_arvalid,
    output reg               s_axi_arready,

    output reg  [31:0]       s_axi_rdata,
    output reg  [1:0]        s_axi_rresp,
    output reg               s_axi_rvalid,
    input  wire              s_axi_rready
);

    // -----------------------------
    // Local parameters / constants
    // -----------------------------
    localparam integer ADDR_LSB      = 2;   // word aligned
    // decode on bits [5:2] -> 0..7 = 8 registers
    localparam integer REG_SEL_MSB   = 5;

    localparam [2:0] REG_CONTROL     = 3'd0; // 0x00
    localparam [2:0] REG_ADDR        = 3'd1; // 0x04
    localparam [2:0] REG_DATA_IN     = 3'd2; // 0x08
    localparam [2:0] REG_STATUS      = 3'd3; // 0x0C
    localparam [2:0] REG_DATA_OUT    = 3'd4; // 0x10
    localparam [2:0] REG_READSTATE   = 3'd5; // 0x14
    localparam [2:0] REG_VERSION     = 3'd6; // 0x18

    localparam [31:0] VERSION_WORD   = 32'h0001_0000;

    // -----------------------------
    // Internal registers / wires
    // -----------------------------
    reg  [ADDR_WIDTH-1:0]   addr_reg;
    reg                     data_in_reg;
    reg                     target_state_reg;

    // Command queueing
    reg                     pending_cmd;           // a command has been requested
    reg                     pending_target_state;
    reg  [ADDR_WIDTH-1:0]   pending_addr;
    reg                     pending_data_in;

    // Pulse into core
    reg                     core_write_pulse;      // one-cycle when issuing
    wire                    core_busy, core_failed;
    wire                    core_read_state, core_data_out;

    // Optional soft reset (sync to aclk)
    reg                     soft_reset_req;

    // -----------------------------
    // Core instance
    // -----------------------------
    reram_core #(
        .MEM_DEPTH(MEM_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LRS_STATE(LRS_STATE),
        .HRS_STATE(HRS_STATE),
        .SET_DELAY_CYCLES(SET_DELAY_CYCLES),
        .RESET_DELAY_CYCLES(RESET_DELAY_CYCLES),
        .ENDURANCE_LIMIT(ENDURANCE_LIMIT)
    ) u_core (
        .clk          (s_axi_aclk),
        .rst_n        (s_axi_aresetn & ~soft_reset_req),
        .write_en     (core_write_pulse),
        .addr         (addr_reg),
        .target_state (target_state_reg),
        .data_in      (data_in_reg),
        .read_data    (core_read_state),
        .data_out     (core_data_out),
        .busy         (core_busy),
        .failed       (core_failed)
    );

    // =========================================================================
    // AXI4-Lite WRITE CHANNEL
    // =========================================================================
    wire aw_hs, w_hs;
    reg  [2:0] wr_sel;  // decoded register index

    assign aw_hs = s_axi_awvalid & s_axi_awready;
    assign w_hs  = s_axi_wvalid  & s_axi_wready;

    // Simple ready handshake (independent channels)
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
        end else begin
            s_axi_awready <= (~s_axi_awready) & s_axi_awvalid;
            s_axi_wready  <= (~s_axi_wready)  & s_axi_wvalid;
        end
    end

    // Latch write address selection when AW handshakes
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            wr_sel <= 3'd0;
        end else if (aw_hs) begin
            wr_sel <= s_axi_awaddr[REG_SEL_MSB:ADDR_LSB];
        end
    end

    // Generate B channel response when both AW and W completed
    wire wr_done;
    assign wr_done = aw_hs & w_hs;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00; // OKAY
        end else begin
            if (wr_done)
                s_axi_bvalid <= 1'b1;
            else if (s_axi_bvalid & s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // Byte write helper (Verilog-2001 function)
    function [31:0] apply_wstrb;
        input [31:0] oldv, newv;
        input [3:0]  wstrb;
        begin
            apply_wstrb = oldv;
            if (wstrb[0]) apply_wstrb[ 7: 0] = newv[ 7: 0];
            if (wstrb[1]) apply_wstrb[15: 8] = newv[15: 8];
            if (wstrb[2]) apply_wstrb[23:16] = newv[23:16];
            if (wstrb[3]) apply_wstrb[31:24] = newv[31:24];
        end
    endfunction

    // Shadowed CONTROL for read-back (optional)
    reg [31:0] control_shadow;

    // Temporary variables moved to module scope (no block-scoped decls)
    reg [31:0] newv;
    reg [31:0] tmp_addr;
    reg [31:0] tmp_din;

    // Register writes
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            addr_reg             <= {ADDR_WIDTH{1'b0}};
            data_in_reg          <= 1'b0;
            target_state_reg     <= 1'b0;
            soft_reset_req       <= 1'b0;
            pending_cmd          <= 1'b0;
            pending_target_state <= 1'b0;
            pending_addr         <= {ADDR_WIDTH{1'b0}};
            pending_data_in      <= 1'b0;
            control_shadow       <= 32'd0;
        end else begin
            // clear soft reset after one cycle
            soft_reset_req <= 1'b0;

            if (wr_done) begin
                case (wr_sel)
                    REG_CONTROL: begin
                        // decode with byte lanes
                        newv = apply_wstrb(control_shadow, s_axi_wdata, s_axi_wstrb);
                        control_shadow   <= newv;

                        // Bits: [0]=launch, [1]=target_state, [2]=soft_reset
                        target_state_reg <= newv[1];
                        if (newv[2]) begin
                            soft_reset_req <= 1'b1; // synchronous one-cycle
                        end

                        if (newv[0]) begin
                            // Queue command (addr/data captured from current regs)
                            pending_cmd          <= 1'b1;
                            pending_target_state <= newv[1];
                            pending_addr         <= addr_reg;
                            pending_data_in      <= data_in_reg;
                        end
                    end

                    REG_ADDR: begin
                        tmp_addr = apply_wstrb({{(32-ADDR_WIDTH){1'b0}}, addr_reg},
                                               s_axi_wdata, s_axi_wstrb);
                        addr_reg <= tmp_addr[ADDR_WIDTH-1:0];
                    end

                    REG_DATA_IN: begin
                        tmp_din = apply_wstrb({31'd0, data_in_reg},
                                              s_axi_wdata, s_axi_wstrb);
                        data_in_reg <= tmp_din[0];
                    end

                    default: begin
                        // no-op
                    end
                endcase
            end

            // If a command is pending and the selected cell is idle, arm issue
            // (re-point core registers to the pending snapshot at issue time)
            if (pending_cmd && !core_busy) begin
                target_state_reg <= pending_target_state;
                addr_reg         <= pending_addr;
                data_in_reg      <= pending_data_in;
            end
        end
    end

    // Small issue FSM: generate a single-cycle pulse after busy==0
    reg [1:0] cstate, cstate_n;

    localparam [1:0] C_IDLE      = 2'b00;
    localparam [1:0] C_WAIT_IDLE = 2'b01;
    localparam [1:0] C_PULSE     = 2'b10;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) cstate <= C_IDLE;
        else                cstate <= cstate_n;
    end

    always @(*) begin
        core_write_pulse = 1'b0;
        cstate_n = cstate;
        case (cstate)
            C_IDLE: begin
                if (pending_cmd) cstate_n = C_WAIT_IDLE;
            end
            C_WAIT_IDLE: begin
                if (!core_busy) cstate_n = C_PULSE;
            end
            C_PULSE: begin
                core_write_pulse = 1'b1; // one cycle
                cstate_n = C_IDLE;
            end
            default: begin
                cstate_n = C_IDLE;
            end
        endcase
    end

    // Clear pending after pulse
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            pending_cmd <= 1'b0;
        end else if (cstate == C_PULSE) begin
            pending_cmd <= 1'b0;
        end
    end

    // =========================================================================
    // AXI4-Lite READ CHANNEL
    // =========================================================================
    reg [2:0] rd_sel;
    wire      ar_hs;

    assign ar_hs = s_axi_arvalid & s_axi_arready;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
        end else begin
            s_axi_arready <= (~s_axi_arready) & s_axi_arvalid;
        end
    end

    // Latch which register to read
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            rd_sel <= 3'd0;
        end else if (ar_hs) begin
            rd_sel <= s_axi_araddr[REG_SEL_MSB:ADDR_LSB];
        end
    end

    // RVALID/RRESP
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
        end else begin
            if (ar_hs) begin
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid & s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    // Read MUX
    always @(*) begin
        case (rd_sel)
            REG_CONTROL:   s_axi_rdata = control_shadow;
            REG_ADDR:      s_axi_rdata = {{(32-ADDR_WIDTH){1'b0}}, addr_reg};
            REG_DATA_IN:   s_axi_rdata = {31'd0, data_in_reg};
            REG_STATUS:    s_axi_rdata = {30'd0, core_failed, core_busy};
            REG_DATA_OUT:  s_axi_rdata = {31'd0, core_data_out};
            REG_READSTATE: s_axi_rdata = {31'd0, core_read_state};
            REG_VERSION:   s_axi_rdata = VERSION_WORD;
            default:       s_axi_rdata = 32'hDEAD_BEEF;
        endcase
    end

endmodule
