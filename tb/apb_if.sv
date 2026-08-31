`timescale 1ns/1ps
interface apb_if(input logic pclk);
  logic preset_n = 0;
  logic psel = 0;
  logic penable = 0;
  logic pwrite = 0;
  logic [11:0] paddr = 0;
  logic [31:0] pwdata = 0;
  logic [3:0] pstrb = 0;
  logic [31:0] prdata;
  logic pready;
  logic pslverr;
endinterface
