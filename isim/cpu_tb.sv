// system_tb.sv - testbench for Ben Eater SAP-1 inspired CPU design
//
// vim: set et ts=4 sw=4
//
// Based on Ben Eater's build of the SAP breadboard computer and his excellent videos.
// https://eater.net/
//
// SPDX-License-Identifier: MIT
// See top-level LICENSE file for license information.

`include "cpu_package.svh"

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps

module cpu_tb();                // module definition

/* verilator lint_off UNUSED */

logic       clk;                  // simulated "external clock" for design
logic       reset;
logic       halt;
logic       out_strobe;
byte_t      out_value;

// === instantiate main module (unit-under-test)
cpu_main main(
    .clk_en_i(1'b1),
    .reset_i(reset),
    .out_strobe_o(out_strobe),
    .out_value_o(out_value),
    .halt_o(halt),
    .clk(clk)
);

integer cycle;
initial begin
    $timeformat(-9, 0, " ns", 9);
    $dumpfile("logs/cpu_tb.fst");
    $dumpvars(0, main);
    $display("=== Control Signal Legend:");
    $display("Bus out: ro=RAM, co=PC,  io=IR, ao=A, bo=B, eo=SUM");
    $display("Bus in : ri=RAM, mi=MAR, ii=IR, ai=A, bi=B, oi=OUT");
    $display("Branch : j =JMP, jc=JC (jump carry), jz=JZ (jump zero)");
    $display("Misc   : ce=PC++, su=subtract, id=instuction done, h=halted");

    $display("=== Simulation started:");

    cycle = 0;
    clk = 1'b0;     // set initial value for clk
    reset = 1'b1;   // set initial reset

    #(2*(1_000_000_000/12_000_000)) reset = 1'b0;

    #1ms;

    $display("=== Ending simulation at %0t", $realtime);
    $finish;
end

always @(posedge clk) begin
    cycle <= cycle + 1;
end

logic [16*3*8-1:0] ops = "NOPLDAADDSUBSTALDIJMPJC JZ 9??A??B??C??D??OUTHLT";    // used to show opcode mnemonic

// print debug info and toggle clock
always begin

    #(1_000_000_000/12_000_000) clk = !clk;

    if (clk) begin
        if (reset) begin
            $display("%5d: <reset>", cycle);
        end else begin
            if (out_strobe) begin
                $display("%5d: === OUT: 0x%02x (%d)", cycle, out_value, out_value);
            end

            $display("%5d: PC=%x A=%02x B=%02x E=%02x CF=%x ZF=%x OUT=%02x MAR=%x T=%1d IR=%02x %s [ %s %s %s %s %s %s | %s %s %s %s %s %s | %s %s %s | %s %s %s %s ]", cycle,
            main.core.pc, main.core.a, main.core.b, main.core.e, main.core.cf, main.core.zf, main.core.o, main.core.mar,
            main.core.t_cyc, main.core.ir, main.core.t_cyc == 0 ? " > " : main.core.t_cyc == 1 ? " < " : ops[(15-(main.core.ir>>4))*24+:24],
            main.core.ro ? "ro" : "--", main.core.co ? "co" : "--", main.core.io ? "io" : "--", main.core.ao ? "ao" : "--", main.core.bo ? "bo" : "--", main.core.eo ? "eo" : "--",
            main.core.ri ? "ri" : "--", main.core.mi ? "mi" : "--", main.core.ii ? "ii" : "--", main.core.ai ? "ai" : "--", main.core.bi ? "bi" : "--", main.core.oi ? "oi" : "--",
            main.core.j  ? "j " : "--", main.core.jc ? "jc" : "--", main.core.jz ? "jz" : "--",
            main.core.ce ? "ce" : "--", main.core.su ? "su" : "--", main.core.id ? "id" : "--", main.core.h  ? "h " : "--");

            if (main.core.h) begin
                $display("%5d: === HLT (time: %0t)", cycle, $realtime);
                $finish;
            end
        end
    end
end

endmodule

`default_nettype wire               // restore default
