class calc_driver #(int DataSize, int AddrSize);

  mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box;

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif,
               mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box);
    this.calcVif = calcVif;
    this.drv_box = drv_box;
  endfunction

  task reset_task();
    // Use the 'reset' signal from the interface via the clocking block
    calcVif.cb.reset <= 1'b1;
    repeat (5) @(calcVif.cb);
    calcVif.cb.reset <= 1'b0;
    @(calcVif.cb);
  endtask

  virtual task initialize_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    // Use the specific 'initialize' signals from the interface
    $display("SRAM %s", block_sel ? "B" : "A");
    calcVif.initialize         <= 1'b1;
    calcVif.initialize_addr    <= addr;
    calcVif.initialize_data    <= data;
    calcVif.initialize_loc_sel <= block_sel;
    @(calcVif.cb); 
    
    // De-assert the initialize signal after one cycle
    calcVif.initialize <= 1'b0;
    @(calcVif.cb); 
  endtask : initialize_sram

  virtual task start_calc(input logic [AddrSize-1:0] read_start_addr, input logic [AddrSize-1:0] read_end_addr,
                          input logic [AddrSize-1:0] write_start_addr, input logic [AddrSize-1:0] write_end_addr,
                          input bit direct = 1);
    int delay;
    calc_seq_item #(DataSize, AddrSize) trans;
    
    // Use the correct DUT configuration signal names via the clocking block
    calcVif.cb.read_start_addr  <= read_start_addr;
    calcVif.cb.read_end_addr    <= read_end_addr;
    calcVif.cb.write_start_addr <= write_start_addr;
    calcVif.cb.write_end_addr   <= write_end_addr;

    @(calcVif.cb);
    $display("START");

    reset_task();
    // This line should wait on the 'ready' signal from the interface
    @(calcVif.cb iff calcVif.cb.ready);

    if (!direct) begin // Random Mode
      if (drv_box.try_peek(trans)) begin
        delay = $urandom_range(0, 5); // Add a Random delay before the next transaction
        repeat (delay) begin
          @(calcVif.cb);
        end
      end
    end
    calcVif.cb.reset <= 1;
  endtask : start_calc

  virtual task drive();
    calc_seq_item #(DataSize, AddrSize) trans;
    while (drv_box.try_get(trans)) begin
      start_calc(trans.read_start_addr, trans.read_end_addr, trans.write_start_addr, trans.write_end_addr, 0);
    end
  endtask : drive

endclass : calc_driver