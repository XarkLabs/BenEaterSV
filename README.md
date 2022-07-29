# Ben Eater inspired SAP-1 computer designed in SystemVerilog

[Project Home](https://github.com/XarkLabs) [#TODO]

###### MIT licensed (See top-level LICENSE file for license information.)

This is a  SystemVerilog project to run a simple 8-bit computer very similar to the one built by Ben Eater (see <https://eater.net>).   My thinking was that since
a lot of people understand how Ben's computer works from his excellent videos, it might be useful to use as an example SystemVerilog FPGA project.  I have tried to stay pretty close to Ben's terminology and design, but I couldn't resist changing a few minor things:

* added ID "instruction done" signal to skip any wasted cycles at the end of instruction microcode (instead of all opcodes using the "worst" case number of cycles).
* used FPGA logic instead of ROM for microcode (looks *similar* to the Arduino code Ben used to generate the microcode ROM with)
* clocked FPGA BRAM on negative clock edge to "simulate" async MEM (data available on next CPU cycle)
* no decimal 7-segment decode for output (although this would be a fun thing to add...*[hint]*)
* zero flag is set whenever A register is set equal to zero (not only on zero output from ALU)
* JC and JZ implemtation differs from Ben's, since on an FPGA it was easier to add a bit more logic and control lines vs quadrupling the "microcode ROM" size (which is typically implemented with LUTs anyways, so this is more efficient - and less typing).

It has been developed using the Icarus Verilog and Verilator simulators (so you don't actually need a physical FPGA to try this design).  It also supports UPduino V3.x and iCEBreaker FPGA boards [#TODO], both using the Lattice iCE40UltraPlus5K FPGA and fully open tools from [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build/releases/latest).

This is a simple educational 8-bit CPU with a 4-bit address bus (so only 16 memory locations for program and data).  Hence the original name "SAP-1" for "Simple As Possible" (and pretty close to that for a "typical" CPU).  It is controlled by "microcode" that asserts the proper control signals, in the proper sequence to make the CPU function (and define the instruction set).

Each instruction takes several cycles to execute (aka T-states).  The first two cycles are the same regardless of the opcode and are always used to put the program counter on the memory bus (PC -> MAR), and then to read the next program opcode from memory (IR <- MEM[MAR]).  Cycles after that are used to perform the specific opcode function (so the "fastest" an opcode can be is 3 cycles).

Here are the instructions currently implemented:

    0000 xxxx   NOP             no-operation                    3 cycles
    0001 mmmm   LDA M           A = MEM[M]                      4 cycles
    0010 mmmm   ADD M           A = A+MEM[M] (updates carry)    5 cycles
    0011 mmmm   SUB M           A = A-MEM[M] (updates carry)    5 cycles
    0100 mmmm   STA M           MEM[M] = A                      4 cycles
    0101 nnnn   LDI N           A = N (4-LSB)                   3 cycles
    0110 mmmm   JMP M           PC = M                          3 cycles
    0111 mmmm   JC  M           if (carry) then PC = M          3 cycles
    1000 mmmm   JZ  M           if (zero) then PC = M           3 cycles
    1001 xxxx   ??? (unused, acts like NOP)
    1010 xxxx   ??? (unused, acts like NOP)
    1011 xxxx   ??? (unused, acts like NOP)
    1100 xxxx   ??? (unused, acts like NOP)
    1101 xxxx   ??? (unused, acts like NOP)
    1110 xxxx   OUT             output A register               3 cycles
    1111 xxxx   HLT             halt CPU clock                  3 cycles

The CPU has 8-bits of binary on GPIO pins 1-8 for the "OUT" opcode and also has one button to halt the clock and one for reset [#TODO].

-Xark (<https://hackaday.io/Xark>)
