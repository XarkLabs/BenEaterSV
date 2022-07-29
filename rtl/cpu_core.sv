// cpu_core.sv - CPU core module for Ben Eater SAP-1 inspired SV design
//
// vim: set et ts=4 sw=4
//
// Based on Ben Eater's build of the SAP breadboard computer and his excellent videos.
// https://eater.net/
//
// SPDX-License-Identifier: MIT
// See top-level LICENSE file for license information.

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps                  // mandatory to shut up Icarus Verilog

`include "cpu_package.svh"

module cpu_core(
    output      logic       hlt_o,              // CPU halted
    output      logic       mem_write_o,        // true if writing to memory
    output      addr_t      mem_addr_o,         // memory address to read or write
    input wire  byte_t      mem_data_i,         // input data from memory to CPU
    output      byte_t      mem_data_o,         // output data from CPU to memory
    output      logic       out_strobe_o,       // strobe when out_value_o has new value
    output      byte_t      out_value_o,        // OUT instruction output value
    input wire  logic       reset_i,            // reset
    input wire  logic       clk_en_i,           // clock enable
    input wire  logic       clk                 // clock
);

// name for T-state numbers
typedef enum logic [2:0] {
    TC0 = 3'b000,
    TC1 = 3'b001,
    TC2 = 3'b010,
    TC3 = 3'b011,
    TC4 = 3'b100,
    TC5 = 3'b101,
    TC6 = 3'b110,
    TC7 = 3'b111
} tcyc_t;

tcyc_t      t_cyc;                              // current ucode step
logic       clk_en;                             // clock enable (taking into account HLT)
op_t        opcode;                             // currently executing opcode (for debug)
logic       o_rdy;                              // new OUT value ready

// CPU registers
addr_t      pc;                                 // program counter value
addr_t      mar;                                // memory address register value
byte_t      ir;                                 // instruction register value
byte_t      a;                                  // A register value
byte_t      b;                                  // B register value
byte_t      o;                                  // OUT value
logic       cf;                                 // carry flag register (set from ec when eo asserted)
logic       zf;                                 // zero flag register (set when cpu_bus==0 when ai asserted)

// CPU control signals
byte_t      cpu_bus;                            // 8-bit CPU internal bus

logic       ce;                                 // program counter increment
logic       id;                                 // instruction done, reset t_cyc
logic       h;                                  // halt clock (for HLT opcode)

logic       co;                                 // output PC on bus
logic       j;                                  // unconditional jump (aka ci, load PC from bus)
logic       jc;                                 // conditional jump carry (load PC from bus if carry flag set)
logic       jz;                                 // conditional jump zero (load PC from bus if zero flag set)

logic       mi;                                 // load MAR from bus
logic       ri;                                 // memory input from bus (write to mem[MAR])
logic       ro;                                 // memory output to bus (read from mem[MAR])

logic       ii;                                 // load IR from bus
logic       io;                                 // output IR on bus (4-LSB)

logic       ai;                                 // load A from bus
logic       ao;                                 // output A on bus

logic       bi;                                 // load B from bus
logic       bo;                                 // output B on bus (not used - yet)

byte_t      e;                                  // ALU result (aka "E" for sum symbol)
logic       su;                                 // ALU subtraction flag (else addition)
logic       ec;                                 // carry bit of ALU result
logic       eo;                                 // output ALU result on bus

logic       oi;                                 // load OUT from bus

// assign internal signals
always_comb clk_en      = clk_en_i && !h;       // force clk_en never enabled if halted
always_comb zf          = (a == 0);             // set z flag if A zero

// assign external signals
always_comb out_strobe_o    = o_rdy;            // OUT value strobe
always_comb out_value_o     = o;                // output OUT value
always_comb mem_addr_o      = mar;              // output MAR for memory
always_comb mem_data_o      = cpu_bus;          // output CPU bus value (for memory write)
always_comb mem_write_o     = (ri && clk_en);   // output memory write signal (when RI set and clock enabled)

// load from cpu_bus (on positive clock edge)
always_ff @(posedge clk) begin : bus_in_block
    if (reset_i) begin
        cf      <= 1'b0;
        pc      <= '0;
        mar     <= '0;
        ir      <= '0;
        a       <= '0;
        b       <= '0;
        o       <= '0;
        o_rdy   <= 1'b0;
    end else if (clk_en) begin
        o_rdy   <= 1'b0;

        if (ce) begin
            pc  <= pc + 1'b1;
        end;
        if (j || (jc && cf) || (jz && zf)) begin
            pc      <= cpu_bus[3:0];
        end
        if (mi) begin
            mar     <= cpu_bus[3:0];
        end
        if (ii) begin
            ir      <= cpu_bus;
        end
        if (ai) begin
            a       <= cpu_bus;
        end
        if (bi) begin
            b       <= cpu_bus;
        end
        if (oi) begin
            o       <= cpu_bus;
            o_rdy   <= 1'b1;
        end
        if (eo) begin
            cf      <= ec;  // save carry when sum output requested
        end
    end
end

// combinatorial bus output
always_comb begin : bus_out_block
    cpu_bus     = '0;
    if (co) begin
        cpu_bus     = { 4'h0, pc };
    end
    if (ro) begin
        cpu_bus     = mem_data_i;
    end
    if (io) begin
        cpu_bus     = { 4'h0, 4'(ir) };
    end
    if (ao) begin
        cpu_bus     = a;
    end
    if (eo) begin
        cpu_bus     = e;
    end
    if (bo) begin
        cpu_bus     = b;
    end
end

// combinatorial ALU
always_comb begin : ALU_block
    if (su) begin
        {ec, e} = {1'b0, a} - {1'b0, b};   // set carry and result
    end else begin
        {ec, e} = {1'b0, a} + {1'b0, b};   // set carry and result
    end
end

// advance T-state cycle (on positive clock edge)
always_ff @(posedge clk) begin
    if (reset_i) begin
        opcode  <= NOP;
        t_cyc   <= TC0;
    end else begin

        if (id) begin
            t_cyc   <= TC0;
            hlt_o   <= h;
        end else if (clk_en) begin
            t_cyc   <= t_cyc + 1'b1;
        end

`ifndef SYNTHESIS
        if (t_cyc >= TC2) begin
            opcode  <= op_t'(ir >> 4);
        end
`endif
    end
end

// CPU control logic (on negative clock edge)
always_ff @(negedge clk) begin : control_block
    if (reset_i) begin
        ii <= 1'b0; io <= 1'b0;
        ce <= 1'b0; co <= 1'b0;
        mi <= 1'b0; id <= 1'b0;
        ri <= 1'b0; ro <= 1'b0;
        ai <= 1'b0; ao <= 1'b0;
        bi <= 1'b0; bo <= 1'b0;
        oi <= 1'b0; h  <= 1'b0;
        su <= 1'b0; eo <= 1'b0;
        j  <= 1'b0; jc <= 1'b0; jz <= 1'b0;
    end else if (clk_en) begin
        ii <= 1'b0; io <= 1'b0;
        ce <= 1'b0; co <= 1'b0;
        mi <= 1'b0; id <= 1'b0;
        ri <= 1'b0; ro <= 1'b0;
        ai <= 1'b0; ao <= 1'b0;
        bi <= 1'b0; bo <= 1'b0;
        oi <= 1'b0; h  <= 1'b0;
        su <= 1'b0; eo <= 1'b0;
        j  <= 1'b0; jc <= 1'b0; jz <= 1'b0;

        case (t_cyc)
            // first two T-cycles are the same for all opcodes
            TC0: begin  co <= 1'b1; mi <= 1'b1;                         end     // move PC to M
            TC1: begin  ro <= 1'b1; ii <= 1'b1; ce <= 1'b1;             end     // move MEM[M] to IR, increment PC
            default:    begin
            // "micro-code" to execute depending on opcode in IR register (4-MSB) for other T-cycles
            case (4'(ir >> 4))
                NOP:        // 0000 xxxx    NOP                no-operation
                    case (t_cyc)
                        TC2: begin  id <= 1'b1;                                     end     // instruction done
                        default:    ;
                    endcase
                LDA:        // 0001 mmmm    LDA M           A <= MEM[M]
                    case (t_cyc)
                        TC2: begin  io <= 1'b1; mi <= 1'b1;                         end     // move IR (4-LSB) to M
                        TC3: begin  ro <= 1'b1; ai <= 1'b1; id <= 1'b1;             end     // move MEM[M] to A, instruction done
                        default:    ;
                    endcase
                ADD:        // 0010 mmmm    ADD M           A <= A+MEM[M]
                    case (t_cyc)
                        TC2: begin  io <= 1'b1; mi <= 1'b1;                         end     // move IR (4-LSB) to M
                        TC3: begin  ro <= 1'b1; bi <= 1'b1;                         end     // move MEM[M] to B
                        TC4: begin  eo <= 1'b1; ai <= 1'b1; su <= 1'b0; id <= 1'b1; end     // move E to A, adding, instruction done
                        default:    ;
                    endcase
                SUB:        // 0011 mmmm    SUB M           A <= A-MEM[M]
                    case (t_cyc)
                        TC2: begin  io <= 1'b1; mi <= 1'b1;                         end     // move IR (4-LSB) to M
                        TC3: begin  ro <= 1'b1; bi <= 1'b1;                         end     // move MEM[M] to B,
                        TC4: begin  eo <= 1'b1; ai <= 1'b1; su <= 1'b1; id <= 1'b1; end     // move E to A, subtracting, instruction done
                        default:    ;
                    endcase
                STA:        // 0100 mmmm    STA M           MEM[M] <= A
                    case (t_cyc)
                        TC2: begin  io <= 1'b1; mi <= 1'b1;                         end     // move IR (4-LSB) to M
                        TC3: begin  ao <= 1'b1; ri <= 1'b1; id <= 1'b1;             end     // move A to MEM[M], instruction done
                        default:    ;
                    endcase
                LDI:        // 0101 nnnn    LDI #N          A <= N (4-LSB)
                    case (t_cyc)
                        TC2: begin  io <= 1'b1; ai <= 1'b1; id <= 1'b1;             end     // move IR (4-LSB) to A, instruction done
                        default:    ;
                    endcase
                JMP:        // 0110 mmmm    JMP M           PC <= M
                    case (t_cyc)
                        TC2: begin  io <= 1'b1; j  <= 1'b1; id <= 1'b1;             end     // move IR (4-LSB) to PC, instruction done
                        default:    ;
                    endcase
                JC:         // 0111 mmmm    JC  M           if (carry) then PC <= M
                    case (t_cyc)
                        TC2: begin  io <= 1'b1; jc <= 1'b1; id <= 1'b1;             end     // move IR (4-LSB) to PC if carry set, instruction done
                        default:    ;
                    endcase
                JZ:         // 0111 mmmm    JZ  M           if (zero) then PC <= M
                    case (t_cyc)
                        TC2: begin  io <= 1'b1; jz <= 1'b1; id <= 1'b1;             end     // move IR (4-LSB) to PC if zero set, instruction done
                        default:    ;
                    endcase
                NOP_9:      // 0000 xxxx    NOP                no-operation
                    case (t_cyc)
                        TC2: begin  id <= 1'b1;                                     end     // instruction done
                        default:    ;
                    endcase
                NOP_A:      // 0000 xxxx    NOP                no-operation
                    case (t_cyc)
                        TC2: begin  id <= 1'b1;                                     end     // instruction done
                        default:    ;
                    endcase
                NOP_B:      // 0000 xxxx    NOP                no-operation
                    case (t_cyc)
                        TC2: begin  id <= 1'b1;                                     end     // instruction done
                        default:    ;
                    endcase
                NOP_C:      // 0000 xxxx    NOP                no-operation
                    case (t_cyc)
                        TC2: begin  id <= 1'b1;                                     end     // instruction done
                        default:    ;
                    endcase
                NOP_D:      // 0000 xxxx    NOP                no-operation
                    case (t_cyc)
                        TC2: begin  id <= 1'b1;                                     end     // instruction done
                        default:    ;
                    endcase
                OUT:        // 1110 xxxx    OUT             output A register
                    case (t_cyc)
                        TC2: begin  ao <= 1'b1; oi <= 1'b1; id <= 1'b1;             end     // move A to O, instruction done
                        default:    ;
                    endcase
                HLT:        // 1111 xxxx    HLT             halt CPU clock
                    case (t_cyc)
                        TC2: begin  h  <= 1'b1; id <= 1'b1;                         end     // halt
                        default:    ;
                    endcase
                default:        ;
            endcase
        end
        endcase
    end
end

logic unused_signals = &{ 1'b0, opcode };           // quiet warnings about unused debug signals

endmodule
`default_nettype wire               // restore default
