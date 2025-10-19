module calc_tb_top;

  import calc_tb_pkg::*;
  import calculator_pkg::*;

  parameter int DataSize = DATA_W;
  parameter int AddrSize = ADDR_W;
  logic clk = 0;
  logic rst;
  state_t state;
  logic [DataSize-1:0] rd_data;

  calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_if(.clk(clk));
  top_lvl my_calc(
    .clk(clk),
    .rst(calc_if.reset),
    `ifdef VCS
    .read_start_addr(calc_if.read_start_addr),
    .read_end_addr(calc_if.read_end_addr),
    .write_start_addr(calc_if.write_start_addr),
    .write_end_addr(calc_if.write_end_addr)
    `endif
    `ifdef CADENCE
    .read_start_addr(calc_if.calc.read_start_addr),
    .read_end_addr(calc_if.calc.read_end_addr),
    .write_start_addr(calc_if.calc.write_start_addr),
    .write_end_addr(calc_if.calc.write_end_addr)
    `endif
  );

  assign rst = calc_if.reset;
assign state = state_t'(my_calc.u_ctrl.state);

`ifdef CADENCE
  assign calc_if.calc.wr_en        = my_calc.u_ctrl.write;
  assign calc_if.calc.rd_en        = my_calc.u_ctrl.read;
  assign calc_if.calc.wr_data      = my_calc.u_ctrl.w_data;
  assign calc_if.calc.rd_data      = my_calc.u_ctrl.r_data;
  assign calc_if.calc.ready        = my_calc.u_ctrl.state == S_END;
  assign calc_if.calc.curr_rd_addr = my_calc.u_ctrl.r_addr;
  assign calc_if.calc.curr_wr_addr = my_calc.u_ctrl.w_addr;
  assign calc_if.calc.loc_sel      = my_calc.u_ctrl.buffer_control;
`endif

`ifdef VCS
  assign calc_if.wr_en        = my_calc.u_ctrl.write;
  assign calc_if.rd_en        = my_calc.u_ctrl.read;
  assign calc_if.wr_data      = my_calc.u_ctrl.w_data;
  assign calc_if.rd_data      = my_calc.u_ctrl.r_data;
  assign calc_if.ready        = my_calc.u_ctrl.state == S_END;
  assign calc_if.curr_rd_addr = my_calc.u_ctrl.r_addr;
  assign calc_if.curr_wr_addr = my_calc.u_ctrl.w_addr;
  assign calc_if.loc_sel      = my_calc.u_ctrl.buffer_control;
`endif


  calc_tb_pkg::calc_driver #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_driver_h;
  calc_tb_pkg::calc_sequencer #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sequencer_h;
  calc_tb_pkg::calc_monitor #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_monitor_h;
  calc_tb_pkg::calc_sb #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sb_h;

  always #5 clk = ~clk;

  task write_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    @(posedge clk);
    if (!block_sel) begin
      my_calc.sram_A.mem[addr] = data;
    end
    else begin
      my_calc.sram_B.mem[addr] = data;
    end
    calc_driver_h.initialize_sram(addr, data, block_sel);
  endtask

  initial begin
    `ifdef VCS
    $fsdbDumpon;
    $fsdbDumpfile("simulation.fsdb");
    $fsdbDumpvars(0, calc_tb_top, "+mda", "+all", "+trace_process");
    $fsdbDumpMDA;
    `endif
    `ifdef CADENCE
    $shm_open("waves.shm");
    $shm_probe("AC");
    `endif

    calc_monitor_h = new(calc_if);
    calc_sb_h = new(calc_monitor_h.mon_box);
    calc_sequencer_h = new();
    calc_driver_h = new(calc_if, calc_sequencer_h.calc_box);
    fork
      calc_monitor_h.main();
      calc_sb_h.main();
    join_none
    calc_if.reset <= 1;
    for (int i = 0; i < 2 ** AddrSize; i++) begin
      write_sram(i, $random, 0);
      write_sram(i, $random, 1);
    end

    repeat (100) @(posedge clk);

    // Directed part
    $display("Directed Testing");
    
    // Test case 1 - normal addition
    $display("Test case 1 - normal addition");
    // TODO: Finish test case 1
    write_sram(0, 32'h0000_0001, 0); // Lower half in SRAM A
    write_sram(0, 32'h0000_0002, 1); // Upper half in SRAM B

    write_sram(1, 32'h0000_0003, 0); // Lower half in SRAM A
    write_sram(1, 32'h0000_0004, 1); // Upper half in SRAM B
    calc_driver_h.start_calc(.read_start_addr(0), .read_end_addr(1), .write_start_addr(0), .write_end_addr(0));
    repeat (500) @(posedge clk);
    // Test case 2 - addition with overflow
    $display("Test case 2 - addition with overflow");
    // TODO: Finish test case 2
    write_sram(2, 32'hFFFF_FFFF, 0); // Lower half in SRAM A
    write_sram(2, 32'hFFFF_FFFF, 1); // Upper half in SRAM B

    write_sram(3, 32'h0000_0001, 0); // Lower half in SRAM A
    write_sram(3, 32'h0000_0000, 1); // Upper half in SRAM B
    calc_driver_h.start_calc(.read_start_addr(2), .read_end_addr(3), .write_start_addr(1), .write_end_addr(1));
    repeat (500) @(posedge clk);
    // TODO: Add test cases according to your test plan. If you need additional test cases to reach
    // 96% coverage, make sure to add them to your test plan
    $display("NewTest");
    write_sram(4, 32'hFFFF_FFFF, 0); // Lower half in SRAM A
    write_sram(4, 32'hFFFF_FFFF, 1); // Upper half in SRAM B

    write_sram(5, 32'hFFFF_FFFF, 0); // Lower half in SRAM A
    write_sram(5, 32'hFFFF_FFFF, 1); // Upper half in SRAM B
    calc_driver_h.start_calc(.read_start_addr(2), .read_end_addr(3), .write_start_addr(1), .write_end_addr(1));
    repeat (500) @(posedge clk);
    // Test case 3 - Maximum value + Minimum value (Zero)
$display("Test case 3 - Max + Min");
// --- SETUP ---
// Operand 1 (Max): 64'hFFFFFFFF_FFFFFFFF
write_sram(4, 32'hFFFFFFFF, 0); // Lower half
write_sram(4, 32'hFFFFFFFF, 1); // Upper half
// Operand 2 (Min): 64'h00000000_00000000
write_sram(5, 32'h00000000, 0); // Lower half
write_sram(5, 32'h00000000, 1); // Upper half
// --- EXECUTE ---
// Tell the DUT to read from addresses 4-5 and write the result to address 2
calc_driver_h.start_calc(.read_start_addr(4), .read_end_addr(5), .write_start_addr(2), .write_end_addr(2));
// --- WAIT ---
repeat (500) @(posedge clk);


// Test case 4 - Maximum value + Maximum value (forces overflow)
$display("Test case 4 - Max + Max");
// --- SETUP ---
// Operand 1 (Max): 64'hFFFFFFFF_FFFFFFFF
write_sram(6, 32'hFFFFFFFF, 0); // Lower half
write_sram(6, 32'hFFFFFFFF, 1); // Upper half
// Operand 2 (Max): 64'hFFFFFFFF_FFFFFFFF
write_sram(7, 32'hFFFFFFFF, 0); // Lower half
write_sram(7, 32'hFFFFFFFF, 1); // Upper half
// --- EXECUTE ---
// Tell the DUT to read from addresses 6-7 and write the result to address 3
calc_driver_h.start_calc(.read_start_addr(6), .read_end_addr(7), .write_start_addr(3), .write_end_addr(3));
// --- WAIT ---
repeat (500) @(posedge clk);


// Test case 5 - Minimum value + Minimum value
$display("Test case 5 - Min + Min");
// --- SETUP ---
// Operand 1 (Min): 64'h00000000_00000000
write_sram(8, 32'h00000000, 0); // Lower half
write_sram(8, 32'h00000000, 1); // Upper half
// Operand 2 (Min): 64'h00000000_00000000
write_sram(9, 32'h00000000, 0); // Lower half
write_sram(9, 32'h00000000, 1); // Upper half
// --- EXECUTE ---
// Tell the DUT to read from addresses 8-9 and write the result to address 4
calc_driver_h.start_calc(.read_start_addr(8), .read_end_addr(9), .write_start_addr(4), .write_end_addr(4));


// --- WAIT ---
repeat (500) @(posedge clk);
    // Random part
    $display("Randomized Testing");
    // TODO: Finish randomized testing
    // HINT: The sequencer is responsible for generating random input sequences. How can the
    // sequencer and driver be combined to generate multiple randomized test cases?
    fork
    // 1. Tell the sequencer to create and send 10 random transactions.
        calc_sequencer_h.gen(10);
    // 2. Tell the driver to start pulling those transactions from the mailbox.
        calc_driver_h.drive();
    join
    repeat (100) @(posedge clk);
$display("Test case add");
repeat (10) @(posedge clk);
fork
   calc_driver_h.start_calc(.read_start_addr(8), .read_end_addr(9), .write_start_addr(4), .write_end_addr(4)); 
   wait (state == S_ADD);
join_any
calc_if.reset <= 1;
repeat (100) @(posedge clk);
$display("Test case read1");
repeat (10) @(posedge clk);
fork
   calc_driver_h.start_calc(.read_start_addr(8), .read_end_addr(9), .write_start_addr(4), .write_end_addr(4)); 
   wait (state == S_READ_1);
join_any
calc_if.reset <= 1;
repeat (100) @(posedge clk);
$display("Test case read2");
repeat (10) @(posedge clk);
fork
   calc_driver_h.start_calc(.read_start_addr(8), .read_end_addr(9), .write_start_addr(4), .write_end_addr(4)); 
   wait (state == S_READ_2);
join_any
calc_if.reset <= 1;
$display("Test case wait");
repeat (10) @(posedge clk);
fork
   calc_driver_h.start_calc(.read_start_addr(8), .read_end_addr(9), .write_start_addr(4), .write_end_addr(4)); 
   wait (state == S_WAIT);
join_any
calc_if.reset <= 1;
repeat (100) @(posedge clk);
$display("Test case write");
repeat (10) @(posedge clk);
fork
   calc_driver_h.start_calc(.read_start_addr(8), .read_end_addr(9), .write_start_addr(4), .write_end_addr(4)); 
   wait (state == S_WRITE);
join_any
calc_if.reset <= 1;
repeat (100) @(posedge clk);
$display("Test case writewait");
repeat (10) @(posedge clk);
fork
   calc_driver_h.start_calc(.read_start_addr(8), .read_end_addr(9), .write_start_addr(4), .write_end_addr(4)); 
   wait (state == S_WRITE_WAIT);
join_any
calc_if.reset <= 1;
repeat (100) @(posedge clk);
repeat (100) @(posedge clk);
    $display("TEST PASSED");
    $finish;
  end

  // TODO: Add Assertions
  /********************
     ASSERTIONS
*********************/

// This assertion is correct as is.
RESET: assert property (@(posedge clk) (rst |=> state == S_IDLE));

// Asserts that read/write addresses are within the valid ranges.
VALID_READ_ADDRESS: assert property (@(posedge clk)(calc_if.rd_en |-> (my_calc.u_ctrl.r_addr >= my_calc.read_start_addr && my_calc.u_ctrl.r_addr <= my_calc.read_end_addr)));

VALID_WRITE_ADDRESS: assert property (@(posedge clk) (calc_if.wr_en |-> (my_calc.u_ctrl.r_addr >= my_calc.write_start_addr && my_calc.u_ctrl.r_addr <= my_calc.write_end_addr)));

// Asserts that when in the S_ADD state, the buffer location select signal is correct.
BUFFER_LOC_TOGGLES: assert property (@(posedge clk) (state == S_ADD |-> my_calc.u_ctrl.need_sec == my_calc.u_ctrl.buffer_control));
endmodule
