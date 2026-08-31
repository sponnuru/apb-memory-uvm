`timescale 1ns/1ps
module apb_memory #(
  parameter int ADDR_WIDTH = 12,
  parameter int DATA_WIDTH = 32,
  parameter int DEPTH = 256,
  parameter int WAIT_CYCLES = 1
) (
  input  logic                  pclk,
  input  logic                  preset_n,
  input  logic                  psel,
  input  logic                  penable,
  input  logic                  pwrite,
  input  logic [ADDR_WIDTH-1:0] paddr,
  input  logic [DATA_WIDTH-1:0] pwdata,
  input  logic [DATA_WIDTH/8-1:0] pstrb,
  output logic [DATA_WIDTH-1:0] prdata,
  output logic                  pready,
  output logic                  pslverr
);
  localparam int BYTE_LANES = DATA_WIDTH / 8;
  localparam int INDEX_WIDTH = $clog2(DEPTH);
  localparam int COUNT_WIDTH = (WAIT_CYCLES > 0) ? $clog2(WAIT_CYCLES + 1) : 1;

  logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];
  logic [ADDR_WIDTH-1:0] addr_q;
  logic [DATA_WIDTH-1:0] wdata_q;
  logic [BYTE_LANES-1:0] strb_q;
  logic write_q;
  logic [COUNT_WIDTH-1:0] wait_count;
  integer i;

  function automatic logic address_valid(input logic [ADDR_WIDTH-1:0] addr);
    return (addr[1:0] == 2'b00) && ((addr >> 2) < DEPTH);
  endfunction

  always_ff @(posedge pclk) begin
    if (!preset_n) begin
      prdata <= '0;
      pready <= 1'b0;
      pslverr <= 1'b0;
      addr_q <= '0;
      wdata_q <= '0;
      strb_q <= '0;
      write_q <= 1'b0;
      wait_count <= '0;
      for (i = 0; i < DEPTH; i++) memory[i] <= '0;
    end else begin
      pready <= 1'b0;
      pslverr <= 1'b0;
      if (psel && !penable) begin
        addr_q <= paddr;
        wdata_q <= pwdata;
        strb_q <= pstrb;
        write_q <= pwrite;
        wait_count <= WAIT_CYCLES[COUNT_WIDTH-1:0];
      end else if (psel && penable) begin
        if (wait_count != 0) begin
          wait_count <= wait_count - 1'b1;
        end else begin
          pready <= 1'b1;
          pslverr <= !address_valid(addr_q);
          if (address_valid(addr_q)) begin
            if (write_q) begin
              for (i = 0; i < BYTE_LANES; i++)
                if (strb_q[i]) memory[addr_q[INDEX_WIDTH+1:2]][8*i +: 8] <= wdata_q[8*i +: 8];
            end else begin
              prdata <= memory[addr_q[INDEX_WIDTH+1:2]];
            end
          end else if (!write_q) begin
            prdata <= '0;
          end
        end
      end
    end
  end
endmodule
