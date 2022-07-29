// cpu_upd.sv -
//
// vim: set et ts=4 sw=4
//
// "Top" of the CPU example design for UPduino FPGA (above this is the FPGA hardware)
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

// If UPduino OSC jumper is shorted or a wire connects 12M to gpio_20 then you
// can un-comment the following `define for an accurate 12MHz clock (otherwise
// the approximate ~48 Mhz internal FPGA oscillator / 4 will be used for ~12MHz)

//`define EXT_CLK       // un-comment if using external 12MHz clock

//
//             PCF   Pin#  _____  Pin#   PCF
//                  /-----| USB |-----\
//            <GND> |  1   \___/   48 | spi_ssn   (16)
//            <VIO> |  2           47 | spi_sck   (15)
//            <RST> |  3           46 | spi_mosi  (17)
//           <DONE> |  4           45 | spi_miso  (14)
// <RGB2>   led_red |  5           44 | gpio_20   <----+ (optional) short OSC
// <RGB0> led_green |  6     U     43 | gpio_10        | jumper or use a
// <RGB1>  led_blue |  7     P     42 | <GND>          | wire from 12M pin
//       <+5V/VUSB> |  8     d     41 | <12M>     >----+ for 12 MHz clock
//          <+3.3V> |  9     u     40 | gpio_12
//            <GND> | 10     i     39 | gpio_21
//          gpio_23 | 11     n     38 | gpio_13
//          gpio_25 | 12     o     37 | gpio_19
//          gpio_26 | 13           36 | gpio_18
//          gpio_27 | 14     V     35 | gpio_11
//          gpio_32 | 15     3     34 | gpio_9
// <G0>     gpio_35 | 16     .     33 | gpio_6
//          gpio_31 | 17     x     32 | gpio_44   >---- Out D7 <G6>
// <G1>     gpio_37 | 18           31 | gpio_4    >---- Out D6
//          gpio_34 | 19           30 | gpio_3    >---- Out D5
//          gpio_43 | 20           29 | gpio_48   >---- Out D4
//          gpio_36 | 21           28 | gpio_45   >---- Out D3
//          gpio_42 | 22           27 | gpio_47   >---- Out D2
//          gpio_38 | 23           26 | gpio_46   >---- Out D1
//          gpio_28 | 24           25 | gpio_2    >---- Out D0
//                  \-----------------/

module cpusys_upd (
    // output gpio
    output      logic   spi_ssn,        // SPI flash CS, hold high to prevent UART conflict
    output      logic   led_green,
    output      logic   led_red,
    output      logic   led_blue,
    input wire  logic   gpio_20,        // optional 12M EXT_CLK (OSC jumper or wire from 12M pin)
    output      logic   gpio_44,
    output      logic   gpio_4,
    output      logic   gpio_3,
    output      logic   gpio_48,
    output      logic   gpio_45,
    output      logic   gpio_47,
    output      logic   gpio_46,
    output      logic   gpio_2
);

// assign output signals to FPGA pins
assign      spi_ssn     = 1'b1;         // deselect SPI flash (pins shared with UART)

logic       clk;
logic       halt;
logic       out_strobe;
byte_t      out_value;   // output byte from OUT opcode
always_comb { gpio_44, gpio_4, gpio_3, gpio_48, gpio_45, gpio_47, gpio_46, gpio_2 } = out_value;

logic unused_strobe = out_strobe;       // quiet unused warning

// === clock setup
`ifdef EXT_CLK      // if EXT_CLK (12M connected to gpio_20 or OSC jumper shorted)
always_comb     clk = gpio_20;
`else              // else !EXT_CLK
logic           unused_clk = gpio_20;   // quiet unused warning
// Lattice documentation for iCE40UP5K oscillators:
// https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/iCE40OscillatorUsageGuide.ashx?document_id=50670
/* verilator lint_off PINMISSING */ // suppress warnings about "missing pin" (default okay here)
SB_HFOSC  #(
    .CLKHF_DIV("0b10")  // 12 MHz = ~48 MHz / 4 (0b00=1, 0b01=2, 0b10=4, 0b11=8)
    ) hf_osc (
    .CLKHFPU(1'b1),
    .CLKHFEN(1'b1),
    .CLKHF(clk)
);
/* verilator lint_on PINMISSING */  // restore warnings about "missing pin"
`endif              // end !EXT_CLK

logic               clk_en;
logic [18:0]        slow_clk;

initial begin
    slow_clk    = '0;
end

always_ff @(posedge clk) begin
    slow_clk    <= slow_clk + 1'b1;
    if (slow_clk == '0) begin
        clk_en      <= 1'b1;
    end else begin
        clk_en      <= 1'b0;
    end
end

// NOTE: LEDs are inverse logic (so LED 0=on, 1=off)
assign led_red      = (slow_clk[7:0] == '0) ? !halt : 1'b1;   // red when halted
assign led_green    = 1'b1;        // green off
assign led_blue     = (slow_clk[18:15] == '0) ? halt : 1'b1;    // blue clock pulse

// === instantiate main module
cpu_main main(
    .clk_en_i(clk_en),
    .reset_i(1'b0),
    .out_strobe_o(out_strobe),
    .out_value_o(out_value),
    .halt_o(halt),
    .clk(clk)
);

endmodule
`default_nettype wire               // restore default
