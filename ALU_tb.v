`timescale 1ns / 1ps

module ALU_tb;

    // Parametri pentru ceas ?i reset
    localparam CLK_PERIOD = 10;
    localparam RST_INIT_DURATION = (2 * CLK_PERIOD); // Durata resetului initial
    localparam RST_PULSE_DURATION = CLK_PERIOD;     // Durata unui puls de reset pentru multiplicator

    // Semnale comune
    reg clk = 1'b0;     // Ini?ializare clk
    reg rst_n_mult;     // Reset activ pe LOW pentru multiplicator
    reg rst_div;        // Reset activ pe HIGH pentru împăr?itor

    // --- Semnale pentru Adunare (cu ripple_carry_adder_8bit) ---
    reg  [7:0] adder_A_in;
    reg  [7:0] adder_B_in;
    reg        adder_Cin_in;
    wire [7:0] adder_Sum_out;
    wire       adder_Cout_out;
    wire       adder_cin_msb_dummy;

    // --- Semnale pentru Scădere (cu subtracter_8bit) ---
    reg  [7:0] sub_A_in;
    reg  [7:0] sub_B_in;
    wire [7:0] sub_Diff_out;
    wire       sub_Bout_out;   // Borrow-out (este cout-ul sumatorului intern)

    // --- Semnale pentru Înmul?ire (BoothRadix2Multiplier) ---
    reg  [7:0] mult_Q_in; // Multiplicator
    reg  [7:0] mult_M_in; // Deînmul?it
    wire [15:0] mult_Product_out;

    // --- Semnale pentru Împăr?ire (srt_radix2_divider_8bit) ---
    reg        div_start;
    reg  [7:0] div_dividend_in;
    reg  [7:0] div_divisor_in;
    wire [7:0] div_quotient_out;
    wire [7:0] div_remainder_out;
    wire       div_busy_out;
    wire       div_div_by_zero_flag_out; // Nume actualizat


    // Instan?iere module ALU
    // 1. Sumatorul (ripple_carry_adder_8bit) - presupunem că există ?i e corect
    ripple_carry_adder_8bit adder_unit (
        .a(adder_A_in),
        .b(adder_B_in),
        .cin(adder_Cin_in),
        .sum(adder_Sum_out),
        .cout(adder_Cout_out),
        .cin_msb(adder_cin_msb_dummy)
    );

    // 2. Scăzătorul (subtracter_8bit, care folose?te RCA intern) - presupunem că există ?i e corect
    subtracter_8bit subtractor_unit (
        .a(sub_A_in),
        .b(sub_B_in),
        .diff(sub_Diff_out),
        .borrow(sub_Bout_out)
    );

    // 3. Multiplicatorul Booth Radix-2
    BoothRadix2Multiplier multiplier_unit (
        .clk(clk),
        .rst(rst_n_mult), // Folose?te rst_n_mult (activ LOW)
        .Q_in(mult_Q_in),
        .M_in(mult_M_in),
        .Product_out(mult_Product_out)
    );

    // 4. Împăr?itorul SRT Radix-2 / Non-Restoring
    srt_radix2_divider_8bit divider_unit (
        .clk(clk),
        .reset(rst_div), // Folose?te rst_div (activ pe HIGH)
        .start(div_start),
        .dividend(div_dividend_in),
        .divisor(div_divisor_in),
        .quotient(div_quotient_out),
        .remainder(div_remainder_out),
        .busy(div_busy_out),
        .div_by_zero_flag(div_div_by_zero_flag_out) // Nume port actualizat
    );

    // Generare Ceas
    always # (CLK_PERIOD/2) clk = ~clk;

    // Generare Reset Ini?ial
    initial begin
        rst_n_mult = 1'b0; // Activăm reset multiplicator (LOW)
        rst_div = 1'b1;    // Activăm reset împăr?itor (HIGH)
        #RST_INIT_DURATION;
        rst_n_mult = 1'b1; // Eliberăm reset multiplicator
        rst_div = 1'b0;    // Eliberăm reset împăr?itor
    end

    // Proces de stimulare ?i afi?are
    initial begin
        // Ini?ializări pentru semnalele de control
        div_start = 1'b0;

        // A?teaptă ca resetul ini?ial global să se termine
        wait (rst_n_mult == 1'b1 && rst_div == 1'b0);
        #(CLK_PERIOD);    // O mică întârziere după reset

        $display("Timp(ns)| Opera?ie   | A_in/Div   | B_in/Dvs | Cin/Ext| Rezultat Ob?inut                  | Rezultat A?teptat");
        $display("---------|------------|------------|----------|--------|-----------------------------------|--------------------");

        // --- Test Adunare ---
        adder_A_in   = 8'd100;
        adder_B_in   = 8'd24;
        adder_Cin_in = 1'b0;
        #1; // Permite propagarea valorilor combina?ionale
        $display("%8d| Adunare    | %10d | %8d | %6b | Sum=%3d (0x%h), Cout=%b        | Sum=124, Cout=0",
                 $time, $signed(adder_A_in), $signed(adder_B_in), adder_Cin_in,
                 $signed(adder_Sum_out), adder_Sum_out, adder_Cout_out);

        adder_A_in   = 8'd200;
        adder_B_in   = 8'd100;
        adder_Cin_in = 1'b1;
        #1;
        $display("%8d| Adunare    | %10d | %8d | %6b | Sum=%3d (0x%h), Cout=%b        | Sum=45, Cout=1",
                 $time, $signed(adder_A_in), $signed(adder_B_in), adder_Cin_in,
                 $signed(adder_Sum_out), adder_Sum_out, adder_Cout_out);

        #(CLK_PERIOD);

        // --- Test Scădere ---
        sub_A_in   = 8'd100;
        sub_B_in   = 8'd24;
        #1;
        $display("%8d| Scadere    | %10d | %8d |   -    | Diff=%3d (0x%h), Bout=%b       | Diff=76, Bout=1",
                 $time, $signed(sub_A_in), $signed(sub_B_in),
                 $signed(sub_Diff_out), sub_Diff_out, sub_Bout_out);

        sub_A_in   = 8'd50;
        sub_B_in   = 8'd70;
        #1;
        $display("%8d| Scadere    | %10d | %8d |   -    | Diff=%3d (0x%h), Bout=%b       | Diff=-20, Bout=0",
                 $time, $signed(sub_A_in), $signed(sub_B_in),
                 $signed(sub_Diff_out), sub_Diff_out, sub_Bout_out);

        #(CLK_PERIOD);

        // --- Test Înmul?ire (Booth Radix-2) ---
        $display("---------|------------|------------|----------|--------|-----------------------------------|--------------------");
        $display("--- Test Înmul?ire (Booth Radix-2) ---");

        // Test 1: 10 * 7 = 70
        mult_Q_in = 8'd10;
        mult_M_in = 8'd7;
        $display("%8d| Inmultire  | Q=%9d | M=%8d |   -    | Initiating 10 * 7...            | Produs=70", $time, $signed(mult_Q_in), $signed(mult_M_in));
        rst_n_mult = 1'b0; #(RST_PULSE_DURATION); rst_n_mult = 1'b1; #(CLK_PERIOD / 2);
        #(CLK_PERIOD * 11);
        $display("%8d| Inmultire  | Q=%9d | M=%8d |   -    | Produs=%3d (0x%h)            | Produs=70",
                 $time, $signed(mult_Q_in), $signed(mult_M_in),
                 $signed(mult_Product_out), mult_Product_out);
        if ($signed(mult_Product_out) !== 70) $error("Eroare Test 1 Inmultire: 10 * 7 != %d", $signed(mult_Product_out));

        // Test 2: -3 * 6 = -18
        mult_Q_in = 8'sd253; 
        mult_M_in = 8'd6;
        $display("%8d| Inmultire  | Q=%9d | M=%8d |   -    | Initiating -3 * 6...           | Produs=-18", $time, $signed(mult_Q_in), $signed(mult_M_in));
        rst_n_mult = 1'b0; #(RST_PULSE_DURATION); rst_n_mult = 1'b1; #(CLK_PERIOD / 2);
        #(CLK_PERIOD * 11);
        $display("%8d| Inmultire  | Q=%9d | M=%8d |   -    | Produs=%3d (0x%h)            | Produs=-18",
                 $time, $signed(mult_Q_in), $signed(mult_M_in),
                 $signed(mult_Product_out), mult_Product_out);
        if ($signed(mult_Product_out) !== -18) $error("Eroare Test 2 Inmultire: -3 * 6 != %d", $signed(mult_Product_out));

        // Test 3: 5 * -4 = -20
        mult_Q_in = 8'd5;
        mult_M_in = 8'sd252; 
        $display("%8d| Inmultire  | Q=%9d | M=%8d |   -    | Initiating 5 * -4...           | Produs=-20", $time, $signed(mult_Q_in), $signed(mult_M_in));
        rst_n_mult = 1'b0; #(RST_PULSE_DURATION); rst_n_mult = 1'b1; #(CLK_PERIOD / 2);
        #(CLK_PERIOD * 11);
        $display("%8d| Inmultire  | Q=%9d | M=%8d |   -    | Produs=%3d (0x%h)            | Produs=-20",
                 $time, $signed(mult_Q_in), $signed(mult_M_in),
                 $signed(mult_Product_out), mult_Product_out);
        if ($signed(mult_Product_out) !== -20) $error("Eroare Test 3 Inmultire: 5 * -4 != %d", $signed(mult_Product_out));

        // Test 4: -2 * -7 = 14
        mult_Q_in = 8'sd254; 
        mult_M_in = 8'sd249; 
        $display("%8d| Inmultire  | Q=%9d | M=%8d |   -    | Initiating -2 * -7...          | Produs=14", $time, $signed(mult_Q_in), $signed(mult_M_in));
        rst_n_mult = 1'b0; #(RST_PULSE_DURATION); rst_n_mult = 1'b1; #(CLK_PERIOD / 2);
        #(CLK_PERIOD * 11);
        $display("%8d| Inmultire  | Q=%9d | M=%8d |   -    | Produs=%3d (0x%h)            | Produs=14",
                 $time, $signed(mult_Q_in), $signed(mult_M_in),
                 $signed(mult_Product_out), mult_Product_out);
        if ($signed(mult_Product_out) !== 14) $error("Eroare Test 4 Inmultire: -2 * -7 != %d", $signed(mult_Product_out));

        #(CLK_PERIOD);

        // --- Test Împăr?ire (SRT Radix-2 / Non-Restoring) ---
        $display("---------|------------|------------|----------|--------|-----------------------------------|--------------------");
        $display("--- Test Împăr?ire (SRT Radix-2 / Non-Restoring) ---");

        // Test Div 1: 27 / 5 => Q=5, R=2
        div_dividend_in = 8'd27;
        div_divisor_in  = 8'd5;
        $display("%8d| Impartire  | Divd=%7d | Divs=%6d | Start  | Initiating 27 / 5...            | Q=5, R=2", $time, div_dividend_in, div_divisor_in);
        div_start = 1'b1; @(posedge clk); div_start = 1'b0; 
        wait (div_busy_out == 1'b0); #(CLK_PERIOD); 
        $display("%8d| Impartire  | Divd=%7d | Divs=%6d | Done   | Q=%3d (0x%h), R=%3d (0x%h)   | Q=5, R=2",
                 $time, div_dividend_in, div_divisor_in,
                 div_quotient_out, div_quotient_out, div_remainder_out, div_remainder_out);
        if (div_quotient_out !== 5 || div_remainder_out !== 2) $error("Eroare Test Div 1: 27/5. Q=%d (exp 5), R=%d (exp 2)", div_quotient_out, div_remainder_out);
        if (div_div_by_zero_flag_out) $error("Eroare Test Div 1: Semnalat div_by_zero eronat.");

        // Test Div 2: 100 / 10 => Q=10, R=0
        div_dividend_in = 8'd100;
        div_divisor_in  = 8'd10;
        $display("%8d| Impartire  | Divd=%7d | Divs=%6d | Start  | Initiating 100 / 10...          | Q=10, R=0", $time, div_dividend_in, div_divisor_in);
        div_start = 1'b1; @(posedge clk); div_start = 1'b0;
        wait (div_busy_out == 1'b0); #(CLK_PERIOD);
        $display("%8d| Impartire  | Divd=%7d | Divs=%6d | Done   | Q=%3d (0x%h), R=%3d (0x%h)   | Q=10, R=0",
                 $time, div_dividend_in, div_divisor_in,
                 div_quotient_out, div_quotient_out, div_remainder_out, div_remainder_out);
        if (div_quotient_out !== 10 || div_remainder_out !== 0) $error("Eroare Test Div 2: 100/10. Q=%d (exp 10), R=%d (exp 0)", div_quotient_out, div_remainder_out);
        if (div_div_by_zero_flag_out) $error("Eroare Test Div 2: Semnalat div_by_zero eronat.");

        // Test Div 3: 7 / 8 => Q=0, R=7
        div_dividend_in = 8'd7;
        div_divisor_in  = 8'd8;
        $display("%8d| Impartire  | Divd=%7d | Divs=%6d | Start  | Initiating 7 / 8...             | Q=0, R=7", $time, div_dividend_in, div_divisor_in);
        div_start = 1'b1; @(posedge clk); div_start = 1'b0;
        wait (div_busy_out == 1'b0); #(CLK_PERIOD);
        $display("%8d| Impartire  | Divd=%7d | Divs=%6d | Done   | Q=%3d (0x%h), R=%3d (0x%h)   | Q=0, R=7",
                 $time, div_dividend_in, div_divisor_in,
                 div_quotient_out, div_quotient_out, div_remainder_out, div_remainder_out);
        if (div_quotient_out !== 0 || div_remainder_out !== 7) $error("Eroare Test Div 3: 7/8. Q=%d (exp 0), R=%d (exp 7)", div_quotient_out, div_remainder_out);
        if (div_div_by_zero_flag_out) $error("Eroare Test Div 3: Semnalat div_by_zero eronat.");

        // Test Div 4: Împăr?ire la zero
        div_dividend_in = 8'd42;
        div_divisor_in  = 8'd0;
        rst_div = 1'b1; @(posedge clk); rst_div = 1'b0; @(posedge clk); 

        $display("%8d| Impartire  | Divd=%7d | Divs=%6d | Start  | Initiating 42 / 0...            | DIV_BY_ZERO", $time, div_dividend_in, div_divisor_in);
        div_start = 1'b1; @(posedge clk); div_start = 1'b0;
        #(CLK_PERIOD * 3); 
        $display("%8d| Impartire  | Divd=%7d | Divs=%6d | Flag   | Q=%3d, R=%3d, ZeroFlag=%b    | DIV_BY_ZERO",
                 $time, div_dividend_in, div_divisor_in,
                 div_quotient_out, div_quotient_out, div_remainder_out, div_div_by_zero_flag_out);
        if (!div_div_by_zero_flag_out) $error("Eroare Test Div 4: Nu s-a semnalat div_by_zero pentru 42 / 0.");
        if (div_busy_out) $error("Eroare Test Div 4: Busy încă activ după div_by_zero (%b).", div_busy_out);


        #(CLK_PERIOD * 2); 
        $display("---------|------------|------------|----------|--------|-----------------------------------|--------------------");
        $display("Simulare ALU (Adunare, Scadere, Inmultire, Impartire) finalizată.");
        $finish;
    end

endmodule
