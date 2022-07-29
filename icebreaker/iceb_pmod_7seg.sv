// iceb_pmod_7seg.sv -
//
// vim: set et ts=4 sw=4
//

// See top-level LICENSE file for license information. (Hint: MIT)
//

`default_nettype none             // mandatory for Verilog sanity
`timescale 1ns/1ps

`include "cpu_package.svh"

module iceb_pmod_7seg (
    // output gpio
    input wire  logic   clk,            // 12M clock
    input wire  byte_t  value_i,
    output      logic   ledA_o,
    output      logic   ledB_o,
    output      logic   ledC_o,
    output      logic   ledD_o,
    output      logic   ledE_o,
    output      logic   ledF_o,
    output      logic   ledG_o,
    output      logic   ledCA_o
);

logic           digit;                  // bit to indicate which LED to activtate (0=seg1, 1=seg2)
logic [6:0]     segments;               // 7-segment segments (a, b, c, d, e, f, g)
logic [7:0]     counter;                // enough to slow down 12Mhz clock (~21 usec)

assign  ledA_o    = ~segments[6];
assign  ledB_o    = ~segments[5];
assign  ledC_o    = ~segments[4];
assign  ledD_o    = ~segments[3];
assign  ledE_o    = ~segments[2];
assign  ledF_o    = ~segments[1];
assign  ledG_o    = ~segments[0];
assign  ledCA_o   = ~digit;

always_ff @(posedge clk) begin
    counter <= counter + 1;
    if (counter == 0) begin
        digit <= !digit;
    end

    case (digit ? value_i[7:4] : value_i[3:0])
        4'b0000:    segments    <= 7'b1111110;    // 0
        4'b0001:    segments    <= 7'b0110000;    // 1
        4'b0010:    segments    <= 7'b1101101;    // 2
        4'b0011:    segments    <= 7'b1111001;    // 3
        4'b0100:    segments    <= 7'b0110011;    // 4
        4'b0101:    segments    <= 7'b1011011;    // 5
        4'b0110:    segments    <= 7'b1011111;    // 6
        4'b0111:    segments    <= 7'b1110000;    // 7
        4'b1000:    segments    <= 7'b1111111;    // 8
        4'b1001:    segments    <= 7'b1111011;    // 9
        4'b1010:    segments    <= 7'b1110111;    // A
        4'b1011:    segments    <= 7'b0011111;    // b
        4'b1100:    segments    <= 7'b1001110;    // C
        4'b1101:    segments    <= 7'b0111101;    // d
        4'b1110:    segments    <= 7'b1001111;    // E
        4'b1111:    segments    <= 7'b1000111;    // F
        default:    segments    <= '0;
    endcase
    if (counter < 2) begin          // blank a bit before digit transition to avoid ghosting
        segments    <= '0;
    end
end

endmodule
`default_nettype wire               // restore default
