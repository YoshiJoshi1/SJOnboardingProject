module controller import calculator_pkg::*;(
    input  logic              clk_i,
    input  logic              rst_i,
 
    // Memory Access
    input  logic [ADDR_W-1:0] read_start_addr,
    input  logic [ADDR_W-1:0] read_end_addr,
    input  logic [ADDR_W-1:0] write_start_addr,
    input  logic [ADDR_W-1:0] write_end_addr,
 
    // Control
    output logic write,
    output logic [ADDR_W-1:0] w_addr,
    output logic [MEM_WORD_SIZE-1:0] w_data,

    output logic read,
    output logic [ADDR_W-1:0] r_addr,
    input  logic [MEM_WORD_SIZE-1:0] r_data,

    // Buffer Control (1 = upper, 0, = lower)
    output logic              buffer_control,
 
    // These go into adder
        output logic [DATA_W-1:0]       op_a,
    output logic [DATA_W-1:0]       op_b,

    input  logic [MEM_WORD_SIZE-1:0]       buff_result
 
);
    //TODO: Write your controller state machine as you see fit.
    //HINT: See "6.2 Two Always BLock FSM coding style" from refmaterials/1_fsm_in_systemVerilog.pdf
    // This serves as a good starting point, but you might find it more intuitive to add more than two always blocks.

    typedef enum logic [2:0] {S_IDLE,S_READ_1,S_READ_2,S_ADD,S_WRITE,S_END,S_WAIT, S_WRITE_WAIT} state_t;
    state_t state, next;
   
    //State reg, other registers as needed
    logic [ADDR_W-1:0] r_addr_register;
    logic [ADDR_W-1:0] w_addr_register;
    logic [MEM_WORD_SIZE-1:0] w_data_register;
    logic [DATA_W-1:0] op_a_reg;
    logic [DATA_W-1:0] op_b_reg;

    logic need_sec;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state <= S_IDLE;
            r_addr_register <= 1'b0;
            w_addr_register <= 1'b0;
            need_sec <= 1'b0;
            op_a_reg <= '0;
            op_b_reg <= '0;
            w_data_register <= '0;

        end else begin
            state <= next;

            r_addr_register <= r_addr;
            w_addr_register <= w_addr;

            if (state == S_WRITE && w_addr_register != write_end_addr) begin
        w_addr_register <= w_addr_register + 1;
        r_addr_register <= r_addr_register + 1;
            end

        if (state == S_WAIT) begin
            op_a_reg <= r_data[31:0];
            op_b_reg <= r_data[63:32];
        end

        if (state == S_ADD && ~need_sec) begin
            need_sec <= 1'b1;
        end else if (state == S_WRITE) begin
            need_sec <= 1'b0;
        end

        if (state == S_WRITE_WAIT) begin
            w_data_register <= buff_result;
        end

    end
    end
   
    //Next state logic, outputs
    always_comb begin

        r_addr = r_addr_register;
        w_addr = w_addr_register;
        read = 1'b0;
        write = 1'b0;
        op_a = op_a_reg;
        op_b = op_b_reg;
        w_data = buff_result;
        buffer_control = need_sec;

        case (state)
        // idle state
            S_IDLE: begin
                r_addr = read_start_addr;
                w_addr = write_start_addr;
                next = S_READ_1;
            end
           
            S_READ_1: begin
                read = 1'b1;
                next = S_WAIT;
            end

            S_WAIT: begin
                next = S_ADD;
            end

            S_ADD: begin
                if (~need_sec) begin
                    next = S_READ_2;
                end else begin
                    next = S_WRITE_WAIT;
                end
            end
           
            S_WRITE_WAIT: begin
                next = S_WRITE;
            end

            // second read
            S_READ_2: begin
                read = 1'b1;
                next = S_WAIT;
                r_addr = r_addr_register + 1;
            end

            // write block
            S_WRITE: begin
                write = 1'b1;

                w_data = w_data_register;

                w_addr = w_addr_register;

                if (w_addr_register == write_end_addr) begin
                    next = S_END;
                end else begin
                    next = S_READ_1;
                end
            end
            // end block
            S_END: begin
                next = S_END;
            end
        endcase
    end

endmodule