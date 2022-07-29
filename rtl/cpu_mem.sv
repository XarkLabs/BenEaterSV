// cpu_mem.sv - memory for Ben Eater SAP-1 inspired CPU design
//
// vim: set et ts=4 sw=4
//
// Based on Ben Eater's build of the SAP breadboard computer and his excellent videos.
// https://eater.net/
//
// Copyright 2022 Xark
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps                  // mandatory to shut up Icarus Verilog

`include "cpu_package.svh"

module cpu_mem #(
    parameter   ADDR_W      =   4,
    parameter	DATA_W      =   8
) (
    input wire  logic                   we_i,
    input wire  logic [ADDR_W-1:0]      addr_i,
    input wire  logic [DATA_W-1:0]      data_in_i,
    output      logic [DATA_W-1:0]      data_out_o,
    input wire  logic                   clk
);

// infer memory
byte_t memory[0:2**ADDR_W-1];

// Instruction set:
// 0000 xxxx    NOP             no-operation
// 0001 mmmm    LDA M           A = RAM[M]
// 0010 mmmm    ADD M           A = A+RAM[M]
// 0011 mmmm    SUB M           A = A-RAM[M]
// 0100 mmmm    STA M           RAM[M] = A
// 0101 iiii    LDI N           A = N (4-LSB)
// 0110 mmmm    JMP M           PC = M
// 0111 mmmm    JC  M           if (carry) then PC = M
// 1000 mmmm    JZ  M           if (zero) then PC = M
// 1001 xxxx    ??? (unused, acts like NOP)
// 1010 xxxx    ??? (unused, acts like NOP)
// 1011 xxxx    ??? (unused, acts like NOP)
// 1100 xxxx    ??? (unused, acts like NOP)
// 1101 xxxx    ??? (unused, acts like NOP)
// 1110 xxxx    OUT             output A register
// 1111 xxxx    HLT             halt CPU

initial begin
    memory[ 0] = 8'h1E;        // LDA	14
    memory[ 1] = 8'h2F;        // ADD	15
    memory[ 2] = 8'hE0;        // OUT
    memory[ 3] = 8'h2D;        // ADD	13
    memory[ 4] = 8'hE0;        // OUT
    memory[ 5] = 8'h77;        // JC	7
    memory[ 6] = 8'h63;        // JMP	3
    memory[ 7] = 8'h51;        // LDI	1
    memory[ 8] = 8'h3D;        // SUB   13
    memory[ 9] = 8'h79;        // JC	9
    memory[10] = 8'h4E;        // STA   14
    memory[11] = 8'hF0;        // HALT
    memory[12] = 8'hF0;        // HALT
    memory[13] = 8'h01;        // increment
    memory[14] = 8'hEA;        // initial value
    memory[15] = 8'h04;        // initial add
end

// NOTE: FPGA memory is clocked on falling edge (so data will be ready for CPU on next rising edge).
//       In general, this is not a good practice (but it works at low speeds and makes things easier)

// infer memory block
always_ff @(negedge clk) begin
    if (we_i) begin
        memory[addr_i] <= data_in_i;
    end
end

always_ff @(negedge clk) begin
    data_out_o <= memory[addr_i];
end

endmodule
`default_nettype wire               // restore default
