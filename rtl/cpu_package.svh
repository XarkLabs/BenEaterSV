// cpu_package.svh - Common definitions for Ben Eater SAP-1 CPU design
//
// vim: set et ts=4 sw=4
//
// SPDX-License-Identifier: MIT
// See top-level LICENSE file for license information.
//

`ifndef VIDEO_PACKAGE_SVH
`define VIDEO_PACKAGE_SVH

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps                  // mandatory to shut up Icarus Verilog

/* verilator lint_off UNUSED */

// Ben Eater SAP inspired CPU instruction set:
typedef enum logic [3:0] {
    NOP     = 4'b0000,      // 0000 xxxx    NOP             no-operation
    LDA     = 4'b0001,      // 0001 mmmm    LDA M           A = RAM[M]
    ADD     = 4'b0010,      // 0010 mmmm    ADD M           A = A+RAM[M]
    SUB     = 4'b0011,      // 0011 mmmm    SUB M           A = A-RAM[M]
    STA     = 4'b0100,      // 0100 mmmm    STA M           RAM[M] = A
    LDI     = 4'b0101,      // 0101 iiii    LDI N           A = N (4-LSB)
    JMP     = 4'b0110,      // 0110 mmmm    JMP M           PC = M
    JC      = 4'b0111,      // 0111 mmmm    JC  M           if (carry) then PC = M
    JZ      = 4'b1000,      // 1000 mmmm    JZ  M           if (zero) then PC = M
    NOP_9   = 4'b1001,      // 1001 xxxx    ??? (unused, acts like NOP)
    NOP_A   = 4'b1010,      // 1010 xxxx    ??? (unused, acts like NOP)
    NOP_B   = 4'b1011,      // 1011 xxxx    ??? (unused, acts like NOP)
    NOP_C   = 4'b1100,      // 1100 xxxx    ??? (unused, acts like NOP)
    NOP_D   = 4'b1101,      // 1101 xxxx    ??? (unused, acts like NOP)
    OUT     = 4'b1110,      // 1110 xxxx    OUT             output A register
    HLT     = 4'b1111       // 1111 xxxx    HLT             halt CPU
} op_t;

// common types (not in package)
typedef logic [3:0] addr_t;
typedef logic [7:0] byte_t;

/* verilator lint_on UNUSED */

`endif      // VIDEO_PACKAGE_SVH
