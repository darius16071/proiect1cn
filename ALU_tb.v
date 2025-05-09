
`timescale 1ns / 1ps

module ALU_tb;

    // Parametri pentru ceas și reset
    localparam CLK_PERIOD = 10;
    localparam RST_DURATION = (2 * CLK_PERIOD);

    // Semnale comune
    reg clk;
    reg rst_n; // Reset activ pe LOW

    // --- Semnale pentru Adunare (cu ripple_carry_adder_8bit) ---
    reg  [7:0] adder_A_in;
    reg  [7:0] adder_B_in;
    reg        adder_Cin_in;
    wire [7:0] adder_Sum_out;
    wire       adder_Cout_out;
     wire    adder_cin_msb_dummy; 

    // --- Semnale pentru Scădere (cu subtracter_8bit) ---
    reg  [7:0] sub_A_in;
    reg  [7:0] sub_B_in;
   
    wire [7:0] sub_Diff_out;
    wire       sub_Bout_out;   // Borrow-out (este cout-ul sumatorului intern)

    // --- Semnale pentru Înmulțire (BoothRadix2Multiplier) ---
    reg  [7:0] mult_Q_in; // Multiplicator
    reg  [7:0] mult_M_in; // Deînmulțit
    wire [15:0] mult_Product_out;


    // Instanțiere module ALU
    // 1. Sumatorul (ripple_carry_adder_8bit)
    ripple_carry_adder_8bit adder_unit (
        .a(adder_A_in),
        .b(adder_B_in),
        .cin(adder_Cin_in),
        .sum(adder_Sum_out),
        .cout(adder_Cout_out)
        
         ,.cin_msb(adder_cin_msb_dummy) 
    );
    
    // 2. Scăzătorul (subtracter_8bit, care folosește RCA intern)
    subtracter_8bit subtractor_unit (
        .a(sub_A_in),
        .b(sub_B_in),
        .diff(sub_Diff_out),
        .borrow(sub_Bout_out)
    );
    
    // 3. Multiplicatorul Booth Radix-2
    BoothRadix2Multiplier multiplier_unit (
        .clk(clk),
        .rst(rst_n),
        .Q_in(mult_Q_in),
        .M_in(mult_M_in),
        .Product_out(mult_Product_out)
    );
    
  
    // Generare Ceas
    always begin
        clk = 1'b0;
        #(CLK_PERIOD/2);
        clk = 1'b1;
        #(CLK_PERIOD/2);
    end
  
    // Generare Reset
    initial begin
        rst_n = 1'b0; // Activăm reset (LOW)
        #RST_DURATION;
        rst_n = 1'b1; // Eliberăm reset
    end 
    
    // Proces de stimulare și afișare
    initial begin
        // Așteaptă ca resetul să se termine
        @(posedge rst_n); 
        #(CLK_PERIOD);    // O mică întârziere după reset

        $display("Timp(ns)| Operație   | A_in   | B_in   | Cin    | Rezultat Obținut                  | Rezultat Așteptat");
        $display("---------|------------|--------|--------|--------|-----------------------------------|--------------------");

        // --- Test Adunare ---
        adder_A_in   = 8'd100;
        adder_B_in   = 8'd24;
        adder_Cin_in = 1'b0;
        #1; // Permite propagarea valorilor combinaționale
        $display("%8d| Adunare    | %6d | %6d | %6b | Sum=%3d (0x%h), Cout=%b        | Sum=124, Cout=0",
                 $time, $signed(adder_A_in), $signed(adder_B_in), adder_Cin_in,
                 $signed(adder_Sum_out), adder_Sum_out, adder_Cout_out);
        
        adder_A_in   = 8'd200;
        adder_B_in   = 8'd100;
        adder_Cin_in = 1'b1;
        #1;
        // 200+100+1 = 301. Pe 8 biți: 301 - 256 = 45. Cout = 1.
        $display("%8d| Adunare    | %6d | %6d | %6b | Sum=%3d (0x%h), Cout=%b        | Sum=45, Cout=1",
                 $time, $signed(adder_A_in), $signed(adder_B_in), adder_Cin_in,
                 $signed(adder_Sum_out), adder_Sum_out, adder_Cout_out);

        #(CLK_PERIOD);

        // --- Test Scădere ---
        // Modulul subtracter_8bit face A + ~B + 1 intern, deci nu are Bin explicit.
        sub_A_in   = 8'd100;
        sub_B_in   = 8'd24;
        #1;
        // 100 - 24 = 76. Bout (cout-ul intern) ar trebui să fie 1 (no borrow)
        $display("%8d| Scadere    | %6d | %6d |   -    | Diff=%3d (0x%h), Bout=%b       | Diff=76, Bout=1",
                 $time, $signed(sub_A_in), $signed(sub_B_in),
                 $signed(sub_Diff_out), sub_Diff_out, sub_Bout_out);

        sub_A_in   = 8'd50;
        sub_B_in   = 8'd70;
        #1;
        // 50 - 70 = -20. In C2 pe 8 biți: 236 (0xEC). Bout ar trebui să fie 0 (borrow)
        $display("%8d| Scadere    | %6d | %6d |   -    | Diff=%3d (0x%h), Bout=%b       | Diff=-20, Bout=0",
                 $time, $signed(sub_A_in), $signed(sub_B_in),
                 $signed(sub_Diff_out), sub_Diff_out, sub_Bout_out);
        
        #(CLK_PERIOD);

        // --- Test Înmulțire (Booth Radix-2) ---
        mult_Q_in = 8'd10; // Multiplicator
        mult_M_in = 8'd7;  // Deînmulțit
        $display("%8d| Inmultire  | Q=%5d | M=%5d |   -    | Asteptam produsul...              | Produs=70", $time, $signed(mult_Q_in), $signed(mult_M_in));
        #(CLK_PERIOD * 10); // Așteaptă suficient pentru Booth Radix-2 (N/2 iterații + overhead)
                           // Am mărit puțin timpul de așteptare pentru siguranță
        $display("%8d| Inmultire  | Q=%5d | M=%5d |   -    | Produs=%3d (0x%h)            | Produs=70",
                 $time, $signed(mult_Q_in), $signed(mult_M_in),
                 $signed(mult_Product_out), mult_Product_out);

        // Pentru a testa o nouă înmulțire, ideal ar fi un semnal de start/reset pentru multiplicator.
        // Aici, vom schimba doar intrările și vom aștepta. Multiplicatorul tău ar trebui să preia noile valori
        // după ce resetul inițial global s-a încheiat.
        mult_Q_in = 8'sd253; // -3 (multiplicator)
        mult_M_in = 8'd6;   // 6 (deînmulțit)
        $display("%8d| Inmultire  | Q=%5d | M=%5d |   -    | Asteptam produsul...              | Produs=-18", $time, $signed(mult_Q_in), $signed(mult_M_in));
        #(CLK_PERIOD * 10); 
        $display("%8d| Inmultire  | Q=%5d | M=%5d |   -    | Produs=%3d (0x%h)            | Produs=-18",
                 $time, $signed(mult_Q_in), $signed(mult_M_in),
                 $signed(mult_Product_out), mult_Product_out);


        #(CLK_PERIOD * 2); // Pauză la final

        $display("---------|------------|--------|--------|--------|-----------------------------------|--------------------");
        $display("Simulare ALU (Adunare, Scadere, Inmultire) finalizată.");
        $finish;
    end
    
endmodule
