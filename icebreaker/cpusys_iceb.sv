// cpu_upd.sv -
//
// vim: set et ts=4 sw=4
//
// "Top" of the CPU example design for iCEBreaker FPGA (above this is the FPGA hardware)
//
// * setup clock
// * setup inputs
// * setup outputs
// * instantiate main module
//
// See top-level LICENSE file for license information. (Hint: MIT)
//

`default_nettype none             // mandatory for Verilog sanity
`timescale 1ns/1ps

`include "cpu_package.svh"

module cpusys_iceb (
    // output gpio
    input wire  logic   CLK,            // 12M clock
    input wire  logic   BTN_N,          // UBUTTON for reset
    output      logic   LEDR_N,         // red LED for halt
    output      logic   LEDG_N,         // green LED for clock
    output      logic   P1A1,
    output      logic   P1A2,
    output      logic   P1A3,
    output      logic   P1A4,
    output      logic   P1A7,
    output      logic   P1A8,
    output      logic   P1A9,
    output      logic   P1A10,
    output      logic   P1B1,
    output      logic   P1B2,
    output      logic   P1B3,
    output      logic   P1B4,
    output      logic   P1B7,
    output      logic   P1B8,
    output      logic   P1B9,
    output      logic   P1B10
);

// assign output signals to FPGA pins
logic       clk;
logic       halt;
logic       out_strobe;
byte_t      out_value;   // output byte from OUT opcode
always_comb { P1B1, P1B2, P1B3, P1B4, P1B7, P1B8, P1B9, P1B10 } = out_value;

logic unused_strobe = out_strobe;       // quiet unused warning

// reset
logic               reset_ff0, reset_ff1, reset;

// === clock setup
always_comb         clk = CLK;
logic               clk_en;
logic [18:0]        slow_clk;

// reset button synchronizer
always_ff @(posedge clk) begin
    reset       <= !reset_ff1;
    reset_ff1   <= reset_ff0;
    reset_ff0   <= BTN_N;
end

always_ff @(posedge clk) begin
    if (reset) begin
        clk_en      <= 1'b0;
        slow_clk    <= '0;
    end else begin
        slow_clk    <= slow_clk + 1'b1;
        if (slow_clk == '0) begin
            clk_en      <= 1'b1;
        end else begin
            clk_en      <= 1'b0;
        end
    end
end

// NOTE: LEDs are inverse logic (so LED 0=on, 1=off)
assign LEDR_N       = (slow_clk[7:0] == '0) ? !halt : 1'b1;     // red when halted
assign LEDG_N       = (slow_clk[18:15] == '0) ? halt : 1'b1;    // green clock pulse

// === instantiate main module
cpu_main main(
    .clk_en_i(clk_en),
    .reset_i(reset),
    .out_strobe_o(out_strobe),
    .out_value_o(out_value),
    .halt_o(halt),
    .clk(clk)
);

iceb_pmod_7seg hexout(
    .clk(clk),
    .value_i(out_value),
    .ledA_o(P1A1),
    .ledB_o(P1A2),
    .ledC_o(P1A3),
    .ledD_o(P1A4),
    .ledE_o(P1A7),
    .ledF_o(P1A8),
    .ledG_o(P1A9),
    .ledCA_o(P1A10)
);

endmodule
`default_nettype wire               // restore default
