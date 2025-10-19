class calc_sb #(int DataSize, int AddrSize);

  // Signals needed for the golden model implementation in the scoreboard
  int mem_a [2**AddrSize];
  int mem_b [2**AddrSize];
  logic second_read = 0;
  int golden_lower_data;
  int golden_upper_data;    
  mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box;

  function new(mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box);
    this.sb_box = sb_box;
  endfunction

  task main();
    calc_seq_item #(DataSize, AddrSize) trans;
    forever begin
        sb_box.get(trans);

        // Case 1: Handle SRAM initialization transactions from the driver.
        if (trans.initialize) begin
            $display($stime, " SB: Got an initialization transaction.");
            // Update the scoreboard's local memory to match the DUT.
            if (trans.loc_sel == 0) begin // SRAM A (lower) was written
                mem_a[trans.curr_wr_addr] = trans.lower_data;
            end else begin // SRAM B (upper) was written
                mem_b[trans.curr_wr_addr] = trans.upper_data;
            end
        
        // Case 2: Handle regular operational reads and writes from the DUT.
        end else begin 

            // Subcase 2a: The DUT performed a READ operation.
            if (!trans.rdn_wr) begin
                $display($stime, " SB: Got a READ from Addr: 0x%0h", trans.curr_rd_addr);

                // VERIFY: Check if the data the DUT read matches our local memory.
                if (mem_a[trans.curr_rd_addr] !== trans.lower_data || mem_b[trans.curr_rd_addr] !== trans.upper_data) begin
                    $error($stime, " SB: FATAL MISMATCH on READ from Addr 0x%0h. DUT read {0x%0h, 0x%0h}, expected {0x%0h, 0x%0h}",
                        trans.curr_rd_addr, trans.upper_data, trans.lower_data, mem_b[trans.curr_rd_addr], mem_a[trans.curr_rd_addr]);
                    $finish;
                end

                // STORE: Save the read operands to calculate the golden result later.
                if (!second_read) begin
                    // This is the first 64-bit operand.
                    golden_lower_data = trans.upper_data + trans.lower_data;
                    second_read = 1;
                end else begin
                    // This is the second 64-bit operand.
                    golden_upper_data = trans.upper_data + trans.lower_data;
                    second_read = 0; // Ready for the next pair.
                end
            
            // Subcase 2b: The DUT performed a WRITE operation.
            end else begin
                logic [DataSize*2-1:0] golden_result;
                logic [DataSize*2-1:0] dut_result;

                $display($stime, " SB: Got a WRITE to Addr: 0x%0h", trans.curr_wr_addr);

                // CALCULATE: Compute the golden result using the operands we stored.
                golden_result = golden_upper_data+ golden_lower_data;
                
                // GET DUT RESULT: Combine the data the DUT wrote.
                dut_result = {trans.upper_data, trans.lower_data};

                // COMPARE: Check if the DUT's result matches our golden calculation.
                if (golden_upper_data !== trans.upper_data || golden_lower_data !== trans.lower_data) begin
                    $error($stime, " SB: FATAL MISMATCH on WRITE to Addr 0x%0h. DUT wrote 0x%0h, expected 0x%0h",
                        trans.curr_wr_addr, trans.lower_data, golden_lower_data);
                    $finish;
                end else begin
                    $display($stime, " SB: Successful WRITE to Addr 0x%0h. Data: 0x%0h", trans.curr_wr_addr, dut_result);
                    
                    // UPDATE: If correct, update our local memory with the new value.
                    mem_a[trans.curr_wr_addr] = dut_result[DataSize-1:0];
                    mem_b[trans.curr_wr_addr] = dut_result[DataSize*2-1:DataSize];
                end
            end
        end
    end
endtask

endclass : calc_sb
