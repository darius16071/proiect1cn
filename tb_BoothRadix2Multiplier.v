`timescale 1ns / 1ps

module tb_BoothRadix2Multiplier;

    // Semnale pentru a interacționa cu DUT (Device Under Test)
    reg clk;
    reg rst_n; // Am redenumit în rst_n pentru a indica activ pe LOW
    reg [7:0] Q_in_tb;
    reg [7:0] M_in_tb;
    wire [15:0] Product_out_tb;

    // Instanțiază DUT
    BoothRadix2Multiplier dut (
        .clk(clk),
        .rst(rst_n), // Conectează la rst_n
        .Q_in(Q_in_tb),
        .M_in(M_in_tb),
        .Product_out(Product_out_tb)
    );

    // Generare ceas
    localparam CLK_PERIOD = 10; // Perioada ceasului de 10 ns
    always begin
        clk = 1'b0;
        #(CLK_PERIOD/2);
        clk = 1'b1;
        #(CLK_PERIOD/2);
    end

    // Task pentru a aplica valori și a aștepta
    task apply_and_wait;
        input [7:0] q_val;
        input [7:0] m_val;
    begin
        // Aplică un scurt reset pentru a reinițializa starea internă a DUT
        rst_n = 1'b0; // Activează reset
        Q_in_tb = q_val; // Setează intrările în timpul resetului
        M_in_tb = m_val;
        #(CLK_PERIOD); // Menține reset pentru 1 ciclu
        rst_n = 1'b1; // Eliberează reset
        // DUT va începe procesarea noilor valori Q_in și M_in
        // Acestea sunt deja în Q_temp și M_reg din blocul `if (!rst)`
        
        // Așteaptă suficient pentru calcul (8 cicluri pentru operații + 1 pentru încărcare produs + buffer)
        // Să zicem 10 cicluri în total de la eliberarea resetului.
        #(10 * CLK_PERIOD); 
    end
    endtask

    // Procesul de stimulare
    initial begin
        $display("Timp\t Q_in\t M_in\t Produs\t\t (Decimal Q*M = P)");
        $monitor("%3dns\t %b\t %b\t %b\t (%d * %d = %d)",
                 $time, $signed(Q_in_tb), $signed(M_in_tb), $signed(Product_out_tb), // Afișează Q și M ca signed
                 $signed(Q_in_tb), $signed(M_in_tb), $signed(Product_out_tb));

        // 1. Reset inițial (nu mai este strict necesar aici dacă task-ul resetează oricum)
        rst_n = 1'b0;
        Q_in_tb = 8'd0;
        M_in_tb = 8'd0;
        #(2 * CLK_PERIOD);
        rst_n = 1'b1;
        #(CLK_PERIOD);


        // Caz de test 1: 7 * 5 = 35
        apply_and_wait(8'd7, 8'd5);

        // Caz de test 2: -3 * 6 = -18
        apply_and_wait(8'sd253, 8'd6); // 253 este -3 în 8 biți C2

        // Caz de test 3: 4 * -7 = -28
        apply_and_wait(8'd4, 8'sd249); // 249 este -7

        // Caz de test 4: -2 * -5 = 10
        apply_and_wait(8'sd254, 8'sd251); // 254 (-2), 251 (-5)

        // Caz de test 5: 0 * 10 = 0
        apply_and_wait(8'd0, 8'd10);

        // Caz de test 6: 127 * 1 = 127
        apply_and_wait(8'd127, 8'd1);
        
        // Caz de test 7: -128 * 1 = -128
        apply_and_wait(8'sd128, 8'd1); // 128 este -128

        $display("Simulare finalizată.");
        $finish;
    end

endmodule