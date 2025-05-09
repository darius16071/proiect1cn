
module BoothRadix2Multiplier(
    input clk,
    input rst,         // Active low reset
    input [7:0] Q_in,  // Multiplicator (8 biți)
    input [7:0] M_in,  // Deînmulțit (8 biți)
    output [15:0] Product_out // Produsul final (16 biți)
);

    // Semnale pentru starea următoare
    reg [8:0] next_A_reg_d;
    reg [8:0] next_Q_temp_d;
    reg [8:0] next_M_reg_d;     // M_reg este încărcat o dată la reset
    reg [3:0] next_count_d;
    reg [15:0] next_Product_out_d;
    reg next_done_flag_d;

    // Semnale înregistrate (ieșiri din regiștri)
    wire [8:0] A_reg_q;
    wire [8:0] Q_temp_q;
    wire [8:0] M_reg_q;
    wire [3:0] count_q;
    wire done_flag_q; // Indică faptul că multiplicarea este completă

    // Fire de la unitatea de control
    wire add_M_w, sub_M_w;
    
    // Enable pentru registrul de produs
    wire en_Product_out;

    // Instanțiere registri 
    register #(.WIDTH(9)) reg_A (
        .clk(clk), .rst(rst), .en(1'b1), .d(next_A_reg_d), .q(A_reg_q)
    );
    register #(.WIDTH(9)) reg_Q (
        .clk(clk), .rst(rst), .en(1'b1), .d(next_Q_temp_d), .q(Q_temp_q)
    );
    register #(.WIDTH(9)) reg_M (
        .clk(clk), .rst(rst), .en(1'b1), .d(next_M_reg_d), .q(M_reg_q)
    );
    register #(.WIDTH(4)) reg_count (
        .clk(clk), .rst(rst), .en(1'b1), .d(next_count_d), .q(count_q)
    );
    register #(.WIDTH(1)) reg_done_flag (
        .clk(clk), .rst(rst), .en(1'b1), .d(next_done_flag_d), .q(done_flag_q)
    );
    
    assign en_Product_out = ((count_q == 7) && !done_flag_q) || !rst;

    register #(.WIDTH(16)) reg_Product_out (
        .clk(clk), .rst(rst), .en(en_Product_out),
        .d(next_Product_out_d), .q(Product_out)
    );

    control_unit_radix2 ctrl_unit (
      .q_pair(Q_temp_q[1:0]), 
      .is_done(done_flag_q),
      .add_M(add_M_w),
      .sub_M(sub_M_w)
    );

    reg [8:0] A_after_op;

    always @(*) begin
        //reg [8:0] A_after_op; 

        next_A_reg_d = A_reg_q;
        next_Q_temp_d = Q_temp_q;
        next_M_reg_d = M_reg_q; 
        next_count_d = count_q;
        next_Product_out_d = Product_out; 
        next_done_flag_d = done_flag_q;

        if (!rst) begin 
            next_A_reg_d = 9'b0;
            next_Q_temp_d = {Q_in, 1'b0}; 
            next_M_reg_d = {M_in[7], M_in}; 
            next_count_d = 4'b0;
            next_Product_out_d = 16'b0;
            next_done_flag_d = 1'b0;
        end else begin 
            A_after_op = A_reg_q; 

            if (!done_flag_q) begin 
                if (add_M_w) begin
                    A_after_op = A_reg_q + M_reg_q;
                end else if (sub_M_w) begin
                    A_after_op = A_reg_q - M_reg_q; 
                end
                
                next_A_reg_d  = {A_after_op[8], A_after_op[8:1]};
                next_Q_temp_d = {A_after_op[0], Q_temp_q[8:1]};
                next_count_d  = count_q + 1;

                if (count_q == 7) begin 
                    next_done_flag_d = 1'b1; 
                    next_Product_out_d = {next_A_reg_d[7:0], next_Q_temp_d[8:1]};
                end
            end else begin 
                next_A_reg_d = A_reg_q;    
                next_Q_temp_d = Q_temp_q;  
                next_count_d = count_q;     
                next_done_flag_d = 1'b1;    
            end
        end
    end
endmodule