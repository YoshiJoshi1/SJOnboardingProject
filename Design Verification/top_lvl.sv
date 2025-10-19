/*
 * This top_level module integrates the controller, memory, adder, and result buffer to form a complete calculator system.
 * It handles memory reads/writes, arithmetic operations, and result buffering.
 */
module top_lvl import calculator_pkg::*; (
    input  logic                   clk,
    input  logic                   rst,

    // Memory Config
    input  logic [ADDR_W-1:0]      read_start_addr,
    input  logic [ADDR_W-1:0]      read_end_addr,
    input  logic [ADDR_W-1:0]      write_start_addr,
    input  logic [ADDR_W-1:0]      write_end_addr
    
);

    // --- Wire Declarations ---

    // Controller <-> SRAM Connections
    logic                    write_wire;
    logic [ADDR_W-1:0]       w_addr_wire;
    logic [MEM_WORD_SIZE-1:0]  w_data_wire;
    logic                    read_wire;
    logic [ADDR_W-1:0]       r_addr_wire;
    logic [MEM_WORD_SIZE-1:0]  r_data_wire;

    // Wires to connect the two SRAM data outputs
    logic [DATA_W-1:0]       r_data_from_sram_A;
    logic [DATA_W-1:0]       r_data_from_sram_B;

    // Controller -> Adder Connections
    logic [DATA_W-1:0]       op_a_wire;
    logic [DATA_W-1:0]       op_b_wire;

    // Adder -> Result Buffer Connection
    logic [DATA_W-1:0]       sum_wire;

    // Controller <-> Result Buffer Connections
    logic                    buffer_control_wire;
    logic [MEM_WORD_SIZE-1:0]  buff_result_wire;

    // Assemble the 64-bit read data from the two 32-bit SRAM outputs.
    // sram_A (lower 32 bits) goes to the right (LSBs).
    // sram_B (upper 32 bits) goes to the left (MSBs).
    assign r_data_wire = {r_data_from_sram_B, r_data_from_sram_A};


    // --- Module Instantiations ---

    controller u_ctrl (
        .clk_i(clk),
        .rst_i(rst),
        .read_start_addr(read_start_addr),
        .read_end_addr(read_end_addr),
        .write_start_addr(write_start_addr),
        .write_end_addr(write_end_addr),
        .write(write_wire),
        .w_addr(w_addr_wire),
        .w_data(w_data_wire),
        .read(read_wire),
        .r_addr(r_addr_wire),
        .r_data(r_data_wire),
        .buffer_control(buffer_control_wire),
        .op_a(op_a_wire),
        .op_b(op_b_wire),
        .buff_result(buff_result_wire)
    );

    // SRAM for the lower 32 bits of memory (sram_A)
    sky130_sram_2kbyte_1rw1r_32x512_8 sram_A (
        .clk0   (clk),
        .csb0   (~write_wire),
        .web0   (~write_wire),
        .wmask0 (4'hF),
        .addr0  (w_addr_wire),
        .din0   (w_data_wire[31:0]),
        .dout0  (),
        .clk1   (clk),
        .csb1   (~read_wire),
        .addr1  (r_addr_wire),
        .dout1  (r_data_from_sram_A)
    );

    // SRAM for the upper 32 bits of memory (sram_B)
    sky130_sram_2kbyte_1rw1r_32x512_8 sram_B (
        .clk0   (clk),
        .csb0   (~write_wire),
        .web0   (~write_wire),
        .wmask0 (4'hF),
        .addr0  (w_addr_wire),
        .din0   (w_data_wire[63:32]),
        .dout0  (),
        .clk1   (clk),
        .csb1   (~read_wire),
        .addr1  (r_addr_wire),
        .dout1  (r_data_from_sram_B)
    );

    adder32 u_adder (
        .a_i   (op_a_wire),
        .b_i   (op_b_wire),
        .sum_o (sum_wire)
    );

    result_buffer u_resbuf (
        .result_i   (sum_wire),
        .loc_sel    (buffer_control_wire),
        .buffer_o   (buff_result_wire),
        .clk_i      (clk),
        .rst_i      (rst)
    );

endmodule

