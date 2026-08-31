`timescale 1ns/1ps
package apb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class apb_item extends uvm_sequence_item;
    `uvm_object_utils(apb_item)
    bit is_reset;
    bit write;
    bit [11:0] addr;
    bit [31:0] wdata;
    bit [3:0] strb;
    bit [31:0] rdata;
    bit slverr;
    int unsigned wait_cycles;
    function new(string name = "apb_item"); super.new(name); endfunction
  endclass

  class apb_sequence extends uvm_sequence #(apb_item);
    `uvm_object_utils(apb_sequence)
    function new(string name = "apb_sequence"); super.new(name); endfunction

    task send_reset();
      apb_item t = apb_item::type_id::create("reset");
      start_item(t); t.is_reset = 1; finish_item(t);
    endtask
    task transfer(bit wr, bit [11:0] address, bit [31:0] data = 0, bit [3:0] strobe = 4'hf);
      apb_item t = apb_item::type_id::create("transfer");
      start_item(t);
      t.is_reset = 0; t.write = wr; t.addr = address; t.wdata = data; t.strb = strobe;
      finish_item(t);
    endtask
    task body();
      send_reset();
      // Directed full-word, byte-strobe, boundary, and error-response cases.
      transfer(1, 12'h000, 32'h1122_3344, 4'hf); transfer(0, 12'h000);
      transfer(1, 12'h000, 32'haabb_ccdd, 4'b0101); transfer(0, 12'h000);
      transfer(1, 12'h3fc, 32'hdead_beef, 4'hf); transfer(0, 12'h3fc);
      transfer(1, 12'h002, 32'hffff_ffff, 4'hf); transfer(0, 12'h002);
      transfer(1, 12'h400, 32'hcafe_babe, 4'hf); transfer(0, 12'h400);
      // Seed-controlled traffic: valid words, mixed reads/writes, and all strobes.
      repeat (300) begin
        bit wr = $urandom_range(0, 1);
        bit [11:0] a = $urandom_range(0, 255) << 2;
        bit [31:0] d = $urandom();
        bit [3:0] s = $urandom_range(0, 15);
        transfer(wr, a, d, s);
      end
      // Read every location touched by the directed boundary cases again.
      transfer(0, 12'h000); transfer(0, 12'h3fc);
    endtask
  endclass

  class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)
    virtual apb_if vif;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) `uvm_fatal("NOVIF", "apb_if missing")
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        seq_item_port.get_next_item(req);
        if (req.is_reset) begin
          @(negedge vif.pclk);
          vif.preset_n = 0; vif.psel = 0; vif.penable = 0;
          repeat (3) @(posedge vif.pclk);
          @(negedge vif.pclk); vif.preset_n = 1;
        end else begin
          @(negedge vif.pclk);
          vif.psel = 1; vif.penable = 0; vif.pwrite = req.write;
          vif.paddr = req.addr; vif.pwdata = req.wdata; vif.pstrb = req.strb;
          @(negedge vif.pclk); vif.penable = 1;
          req.wait_cycles = 0;
          do begin
            @(posedge vif.pclk); #1ns;
            if (!vif.pready) req.wait_cycles++;
          end while (!vif.pready);
          req.rdata = vif.prdata; req.slverr = vif.pslverr;
          @(negedge vif.pclk); vif.psel = 0; vif.penable = 0;
        end
        seq_item_port.item_done();
      end
    endtask
  endclass

  class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    virtual apb_if vif;
    uvm_analysis_port #(apb_item) ap;
    bit was_reset;
    int unsigned access_wait;
    function new(string name, uvm_component parent); super.new(name, parent); ap = new("ap", this); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) `uvm_fatal("NOVIF", "apb_if missing")
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        apb_item t;
        @(posedge vif.pclk); #2ns;
        if (!vif.preset_n) begin
          access_wait = 0;
          if (!was_reset) begin
            t = apb_item::type_id::create("observed_reset"); t.is_reset = 1; ap.write(t);
          end
          was_reset = 1;
        end else begin
          was_reset = 0;
          if (vif.psel && vif.penable && !vif.pready) access_wait++;
          if (vif.psel && vif.penable && vif.pready) begin
            t = apb_item::type_id::create("observed_transfer");
            t.write = vif.pwrite; t.addr = vif.paddr; t.wdata = vif.pwdata; t.strb = vif.pstrb;
            t.rdata = vif.prdata; t.slverr = vif.pslverr; t.wait_cycles = access_wait;
            access_wait = 0; ap.write(t);
          end
        end
      end
    endtask
  endclass

  class apb_scoreboard extends uvm_subscriber #(apb_item);
    `uvm_component_utils(apb_scoreboard)
    bit [31:0] model [0:255];
    int unsigned transfers, reads, writes, errors, partial_writes, waited;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void clear_model(); for (int i=0; i<256; i++) model[i] = 0; endfunction
    function void write(apb_item t);
      bit valid;
      int index;
      if (t.is_reset) begin clear_model(); return; end
      valid = (t.addr[1:0] == 0) && ((t.addr >> 2) < 256);
      index = t.addr >> 2;
      transfers++; waited += (t.wait_cycles > 0);
      if (t.slverr !== !valid) `uvm_error("SLVERR", $sformatf("addr=%03h expected_error=%b actual=%b",t.addr,!valid,t.slverr))
      if (!valid) begin errors++; return; end
      if (t.write) begin
        writes++; partial_writes += (t.strb != 4'hf);
        for (int b=0; b<4; b++) if (t.strb[b]) model[index][8*b +: 8] = t.wdata[8*b +: 8];
      end else begin
        reads++;
        if (t.rdata !== model[index]) `uvm_error("READ", $sformatf("addr=%03h expected=%08h actual=%08h",t.addr,model[index],t.rdata))
      end
    endfunction
    function void check_phase(uvm_phase phase);
      if (transfers != 312 || reads == 0 || writes == 0 || errors != 4 || partial_writes == 0 || waited != transfers)
        `uvm_error("COVERAGE", $sformatf("transfers=%0d reads=%0d writes=%0d errors=%0d partial=%0d waited=%0d",transfers,reads,writes,errors,partial_writes,waited))
    endfunction
    function void report_phase(uvm_phase phase);
      `uvm_info("APB_STATS", $sformatf("transfers=%0d reads=%0d writes=%0d errors=%0d partial_writes=%0d waited=%0d",transfers,reads,writes,errors,partial_writes,waited), UVM_LOW)
    endfunction
  endclass

  class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)
    uvm_sequencer #(apb_item) sequencer; apb_driver driver; apb_monitor monitor; apb_scoreboard scoreboard;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      sequencer = new("sequencer",this); driver=apb_driver::type_id::create("driver",this);
      monitor=apb_monitor::type_id::create("monitor",this); scoreboard=apb_scoreboard::type_id::create("scoreboard",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export); monitor.ap.connect(scoreboard.analysis_export);
    endfunction
  endclass

  class apb_test extends uvm_test;
    `uvm_component_utils(apb_test)
    apb_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); env=apb_env::type_id::create("env",this); endfunction
    task run_phase(uvm_phase phase);
      apb_sequence seq=apb_sequence::type_id::create("seq"); phase.raise_objection(this); seq.start(env.sequencer); phase.drop_objection(this);
    endtask
  endclass
endpackage
