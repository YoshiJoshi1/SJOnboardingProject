class calc_monitor #(int DataSize, int AddrSize);
  logic written = 0;

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;
  mailbox #(calc_seq_item #(DataSize, AddrSize)) mon_box;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif);
    this.calcVif = calcVif;
    this.mon_box = new();
  endfunction

  task main();
    forever begin
      @(calcVif.cb);
      if (calcVif.cb.rd_en && calcVif.cb.wr_en) begin
        $error($stime, " Mon: Error rd_en and wr_en both asserted at the same time\n");
      end
      // Sample the transaction and send to scoreboard
      if (calcVif.cb.wr_en || calcVif.cb.rd_en) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        trans.rdn_wr = calcVif.cb.wr_en;

        if (trans.rdn_wr) // Write
        begin
          // Corrected signal names for Write operation
          trans.curr_wr_addr = calcVif.cb.curr_wr_addr;
          trans.lower_data = calcVif.cb.wr_data[DataSize-1:0];
          trans.upper_data = calcVif.cb.wr_data[DataSize*2-1:DataSize];
          if (!written) begin
            written = 1;
            $display($stime, " Mon: Write to Addr: 0x%0x, Data to SRAM A (lower 32 bits): 0x%0x, Data to SRAM B (upper 32 bits): 0x%0x\n", trans.curr_wr_addr, trans.lower_data, trans.upper_data);
            mon_box.put(trans);
          end
        end
        else if (!trans.rdn_wr) // Read
        begin
          @(calcVif.cb);
          written = 0;
          // Corrected signal names for Read operation
          trans.curr_rd_addr = calcVif.cb.curr_rd_addr;
          trans.lower_data   = calcVif.cb.rd_data[DataSize-1:0];
          trans.upper_data   = calcVif.cb.rd_data[DataSize*2-1:DataSize];
          $display($stime, " Mon: Read from Addr: 0x%0x, Data from SRAM A: 0x%0x, Data from SRAM B: 0x%0x\n", trans.curr_rd_addr, trans.upper_data, trans.lower_data);
          mon_box.put(trans);
        end
      end

      if (calcVif.initialize) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        trans.initialize = 1; // Flagging that this is an initialize transaction
        trans.rdn_wr = 1; 
    
        trans.curr_wr_addr = calcVif.initialize_addr;
        trans.loc_sel      = calcVif.initialize_loc_sel;
    
        if (calcVif.initialize_loc_sel == 0) begin // Write to SRAM A (lower)
            trans.lower_data = calcVif.initialize_data;
            trans.upper_data = '0; // The other half is not being written
        end else begin // Write to SRAM B (upper)
            trans.upper_data = calcVif.initialize_data;
            trans.lower_data = '0; // The other half is not being written
        end

        $display($stime, " Mon: Initialize SRAM; Write to SRAM %s, Addr: 0x%0x, Data: 0x%0x\n", !calcVif.initialize_loc_sel ? "A" : "B", calcVif.initialize_addr, calcVif.initialize_data);
        mon_box.put(trans);
      end
    end
  endtask : main

endclass : calc_monitor