`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*; import apb_pkg::*;
  bit pclk = 0; always #5ns pclk = ~pclk;
  apb_if vif(pclk);
  apb_memory #(.WAIT_CYCLES(1)) dut(
    .pclk, .preset_n(vif.preset_n), .psel(vif.psel), .penable(vif.penable), .pwrite(vif.pwrite),
    .paddr(vif.paddr), .pwdata(vif.pwdata), .pstrb(vif.pstrb), .prdata(vif.prdata),
    .pready(vif.pready), .pslverr(vif.pslverr));
  initial begin
    uvm_config_db#(virtual apb_if)::set(null,"uvm_test_top.env.*","vif",vif);
    run_test("apb_test");
  end
  initial begin #200us; $fatal(1,"Simulation watchdog expired"); end
endmodule
