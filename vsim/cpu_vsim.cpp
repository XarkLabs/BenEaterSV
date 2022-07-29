// C++ "driver" for Ben Eater SAP-1 CPU design
//
// vim: set et ts=4 sw=4
//
// See top-level LICENSE file for license information. (Hint: MIT)
//

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "verilated.h"

#include "Vcpu_main.h"

#define MAX_SIM_CYCLES 12000

// 1 to save FST waveform trace file
#define VM_TRACE 1

#include "verilated_fst_c.h" // for VM_TRACE

#define LOGDIR "logs/"

// Current simulation time (64-bit unsigned)
vluint64_t main_time = 0;

volatile bool done;

static FILE *logfile;
static char log_buff[16384];

static void log_printf(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(log_buff, sizeof(log_buff), fmt, args);
    fputs(log_buff, stdout);
    fputs(log_buff, logfile);
    va_end(args);
}

static void logonly_printf(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(log_buff, sizeof(log_buff), fmt, args);
    fputs(log_buff, logfile);
    va_end(args);
}

void ctrl_c(int s)
{
    (void)s;
    done = true;
}

// Called by $time in Verilog
double sc_time_stamp()
{
    return main_time;
}

int main(int argc, char **argv)
{
    struct sigaction sigIntHandler;

    sigIntHandler.sa_handler = ctrl_c;
    sigemptyset(&sigIntHandler.sa_mask);
    sigIntHandler.sa_flags = 0;

    sigaction(SIGINT, &sigIntHandler, NULL);

    if ((logfile = fopen(LOGDIR "cpu_vsim.log", "w")) == NULL)
    {
        printf("can't create " LOGDIR "cpu_vsim.log\n");
        exit(EXIT_FAILURE);
    }

    log_printf("\nSimulation started\n");

    Verilated::commandArgs(argc, argv);

#if VM_TRACE
    Verilated::traceEverOn(true);
#endif

    Vcpu_main *top = new Vcpu_main;

#if VM_TRACE
    const auto trace_path = LOGDIR "cpu_vsim.fst";
    logonly_printf("Writing FST waveform file to \"%s\"...\n", trace_path);
    VerilatedFstC *tfp = new VerilatedFstC;

    top->trace(tfp, 99); // trace to heirarchal depth of 99
    tfp->open(trace_path);
#endif

    top->reset_i = 1;
    top->clk_en_i = 1;
    top->clk = 0;

    int cycle = 0;

    while (!done && !Verilated::gotFinish())
    {
        top->clk = 1; // clock rising
        top->eval();

#if VM_TRACE
        tfp->dump(main_time);
#endif
        main_time++;

        top->clk = 0; // clock falling
        top->eval();

#if VM_TRACE
        tfp->dump(main_time);
#endif

        if (top->reset_i)
        {
            printf("%5d: <reset>\n", cycle);
        }

        main_time++;

        cycle = (int)(main_time / 2);

        if (top->halt_o)
        {
            printf("%5d: === HLT: CPU halted.\n", cycle);

            done = true;
        }

        if (top->out_strobe_o)
        {
            printf("%5d: === OUT: 0x%02x (%d)\n", cycle, top->out_value_o, top->out_value_o);
        }

        // failsafe exit
        if ((main_time / 2) >= (uint64_t)MAX_SIM_CYCLES)
        {
            printf("Maximum simulation time, quitting.\n");

            done = true;
        }

        if (main_time >= 2)
        {
            top->reset_i = 0;
        }
    }

    top->final();

#if VM_TRACE
    tfp->close();
#endif

    log_printf("Simulation ended after %lu clock ticks\n",
               (main_time / 2));

    return EXIT_SUCCESS;
}
