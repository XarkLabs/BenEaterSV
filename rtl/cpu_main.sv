// cpu_main.sv - main system module with CPU and memory
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

module cpu_main (
    input wire  logic       clk_en_i,
    input wire  logic       reset_i,
    output      logic       out_strobe_o,
    output      byte_t      out_value_o,
    output      logic       halt_o,
    input wire  logic       clk
);

logic       mem_we;
addr_t      mem_addr;
byte_t      data_mem_to_cpu;
byte_t      data_cpu_to_ram;

// instantiate CPU
cpu_core core (
    .hlt_o(halt_o),
    .mem_write_o(mem_we),
    .mem_addr_o(mem_addr),
    .mem_data_i(data_mem_to_cpu),
    .mem_data_o(data_cpu_to_ram),
    .out_strobe_o(out_strobe_o),
    .out_value_o(out_value_o),
    .reset_i(reset_i),
    .clk_en_i(clk_en_i),
    .clk(clk)
);

// instantiate RAM
// NOTE: FPGA memory is clocked on falling edge (so data will be ready for CPU on next rising edge).
//       In general, this is not a good practice (but it works at low speeds and makes things easier)
cpu_mem #(
    .ADDR_W(4),
    .DATA_W(8)
    ) mem (
    .we_i(mem_we),
    .addr_i(mem_addr),
    .data_in_i(data_cpu_to_ram),
    .data_out_o(data_mem_to_cpu),
    .clk(clk)
);

endmodule
`default_nettype wire               // restore default
