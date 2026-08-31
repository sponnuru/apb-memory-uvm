#include "Vtb_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <memory>
#include <string>
int main(int argc, char** argv) {
  auto context=std::make_unique<VerilatedContext>(); context->threads(1); context->commandArgs(argc,argv); context->traceEverOn(true);
  auto top=std::make_unique<Vtb_top>(context.get(),"TOP"); auto trace=std::make_unique<VerilatedVcdC>();
  std::string file="build/apb.vcd";
  for(int i=1;i<argc;i++){std::string a(argv[i]); if(a.rfind("+WAVE_FILE=",0)==0) file=a.substr(11);}
  top->trace(trace.get(),99); trace->open(file.c_str());
  while(!context->gotFinish()){top->eval();trace->dump(context->time());if(!top->eventsPending())break;context->time(top->nextTimeSlot());}
  top->final();trace->close();context->statsPrintSummary();return context->gotFinish()?0:1;
}
