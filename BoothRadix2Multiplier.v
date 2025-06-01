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
    reg [8:0] next_M_reg_d;
    reg [3:0] next_count_d;
    reg [15:0] next_Product_out_d;
    reg next_done_flag_d;

    // Semnale înregistrate (ieșiri din regiștri)
    wire [8:0] A_reg_q;
    wire [8:0] Q_temp_q;
    wire [8:0] M_reg_q;
    wire [3:0] count_q;
    wire done_flag_q;

    // Fire de la unitatea de control
    wire add_M_w, sub_M_w;
    
    // Enable pentru registrul de produs
    wire en_Product_out;

    // Flag pentru primul ciclu de ceas după reset, pentru încărcarea operanzilor
    reg initial_load_cycle_q;
    reg next_initial_load_cycle_d;

    // Registru pentru initial_load_cycle_q
    // Acesta este un registru simplu, poate fi implementat și direct
    // sau folosind instanța de 'register' dacă se dorește consistență.
    // Pentru simplitate, îl facem direct aici.
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            initial_load_cycle_q <= 1'b1; // Se activează la reset
        end else begin
            initial_load_cycle_q <= next_initial_load_cycle_d; // Controlat de logica combinațională
        end
    end

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
    
    assign en_Product_out = ((count_q == 7) && !done_flag_q && !initial_load_cycle_q) || !rst;

    register #(.WIDTH(16)) reg_Product_out (
        .clk(clk), .rst(rst), .en(en_Product_out),
        .d(next_Product_out_d), .q(Product_out)
    );

    control_unit_radix2 ctrl_unit (
      .q_pair(Q_temp_q[1:0]), 
      .is_done(done_flag_q || initial_load_cycle_q), // Oprește operațiile Booth în timpul încărcării
      .add_M(add_M_w),
      .sub_M(sub_M_w)
    );

    reg [8:0] A_after_op;

    always @(*) begin
        // Valori implicite
        next_A_reg_d = A_reg_q;
        next_Q_temp_d = Q_temp_q;
        next_M_reg_d = M_reg_q; 
        next_count_d = count_q;
        next_Product_out_d = Product_out; 
        next_done_flag_d = done_flag_q;
        A_after_op = A_reg_q; // Valoare implicită pentru A_after_op
        next_initial_load_cycle_d = initial_load_cycle_q; // Implicit, menține starea

        if (!rst) begin 
            // Acest bloc definește ce se întâmplă cu SEMNALELE next_... CÂND rst ESTE LOW.
            // Rețineți că registrele A,Q,M,count,done se vor reseta la 0 din cauza logicii lor interne.
            // Product_out se resetează la 0 pentru că en_Product_out va fi true și next_Product_out_d e 0.
            next_A_reg_d = 9'b0;
            next_Q_temp_d = {Q_in, 1'b0}; // Pregătit pentru 'd', dar reg_Q se va reseta la 0
            next_M_reg_d = {M_in[7], M_in}; // Pregătit pentru 'd', dar reg_M se va reseta la 0
            next_count_d = 4'b0;
            next_Product_out_d = 16'b0;
            next_done_flag_d = 1'b0;
            next_initial_load_cycle_d = 1'b1; // Setează flag-ul pentru următorul ciclu
        end else begin // rst este HIGH
            next_initial_load_cycle_d = 1'b0; // Se curăță după primul ciclu post-reset

            if (initial_load_cycle_q) begin // Primul ciclu de ceas după ce rst a devenit HIGH
                next_A_reg_d = 9'b0;
                next_Q_temp_d = {Q_in, 1'b0}; // ÎNCARCĂ Q_in
                next_M_reg_d = {M_in[7], M_in}; // ÎNCARCĂ M_in
                next_count_d = 4'b0;          // Inițializează count
                next_done_flag_d = 1'b0;      // Asigură că done este 0
                // Product_out și A_after_op își păstrează valorile implicite (0 de la reset)
            end else if (!done_flag_q) begin // Operație normală Booth (după încărcare)
                // A_after_op este A_reg_q implicit
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
            end else begin // done_flag_q este true și nu e ciclul de încărcare
                // Menține starea după finalizare
                next_A_reg_d = A_reg_q;    
                next_Q_temp_d = Q_temp_q;  
                next_count_d = count_q; // Va fi 8 sau valoarea finală     
                next_done_flag_d = 1'b1; // Menține done_flag ridicat   
                // next_Product_out_d păstrează valoarea calculată
            end
        end
    end
endmodule
