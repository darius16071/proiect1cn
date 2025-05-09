`timescale 1ns / 1ps

module tb_subtracter_8bit;

    // Semnale pentru DUT
    reg  [7:0] a_tb;
    reg  [7:0] b_tb;
    wire [7:0] diff_dut;
    wire       borrow_dut;

    // Instan?iere DUT (Device Under Test)
    subtracter_8bit dut (
        .a     (a_tb),
        .b     (b_tb),
        .diff  (diff_dut),
        .borrow(borrow_dut)
    );

    // Variabile pentru verificare (pot fi globale dac? sunt folosite doar în initial)
    integer errors_count; // Am redenumit pentru a evita conflictul cu un posibil cuvânt cheie 'errors'

    // Task pentru aplicarea unui test ?i verificarea rezultatului
    task run_test;
        input [7:0] val_a;
        input [7:0] val_b;
        input [7:0] exp_diff;
        input       exp_borrow;
        // Am eliminat: input string test_name;
    begin
        // Numele testului este acum afi?at înainte de apelul task-ului
        a_tb = val_a;
        b_tb = val_b;

        #10; // A?teapt? timp pentru propagarea semnalelor

        $display("Ob?inut: Diff=%3d (0x%h), Borrow=%b", $signed(diff_dut), diff_dut, borrow_dut);
        $display("A?teptat: Diff=%3d (0x%h), Borrow=%b", $signed(exp_diff), exp_diff, exp_borrow);

        if (($signed(diff_dut) !== $signed(exp_diff)) || (borrow_dut !== exp_borrow)) begin
            $error("EROARE: Rezultat incorect pentru A=%d (%h), B=%d (%h)", $signed(val_a), val_a, $signed(val_b), val_b);
            errors_count = errors_count + 1;
        end else begin
            $info("SUCCES: Rezultat corect pentru A=%d (%h), B=%d (%h)", $signed(val_a), val_a, $signed(val_b), val_b);
        end
        $display("-----------------------------------------------------");
    end
    endtask

    // Procesul de stimulare
    initial begin
        errors_count = 0; // Ini?ializeaz? contorul de erori

        // Monitorizeaz? semnalele în timp
        $monitor("Timp: %0tns | A: %3d (0x%h) | B: %3d (0x%h) | Diff: %3d (0x%h) | Borrow: %b",
                 $time, $signed(a_tb), a_tb, $signed(b_tb), b_tb,
                 $signed(diff_dut), diff_dut, borrow_dut);
        
        #5; // O mic? pauz? ini?ial?

        // Cazuri de test pentru sc?dere
        $display("-----------------------------------------------------");
        $display("Test: Pozitiv - Pozitiv (Rezultat Pozitiv) (A=%d, B=%d)", $signed(8'd10), $signed(8'd3));
        run_test(8'd10, 8'd3,  8'd7,   1'b1);

        $display("-----------------------------------------------------");
        $display("Test: Pozitiv - Pozitiv (Rezultat Negativ) (A=%d, B=%d)", $signed(8'd3), $signed(8'd10));
        run_test(8'd3,  8'd10, 8'sd249, 1'b0); // -7 este 249 unsigned sau 0xF9

        $display("-----------------------------------------------------");
        $display("Test: Pozitiv - Pozitiv (Rezultat Zero) (A=%d, B=%d)", $signed(8'd5), $signed(8'd5));
        run_test(8'd5,  8'd5,  8'd0,   1'b1);

        $display("-----------------------------------------------------");
        $display("Test: Negativ - Pozitiv (A=%d, B=%d)", $signed(8'sd251), $signed(8'd2)); // -5
        run_test(8'sd251, 8'd2, 8'sd249, 1'b0); // (-5) - 2 = -7 (0xF9)

        $display("-----------------------------------------------------");
        $display("Test: Pozitiv - Negativ (A=%d, B=%d)", $signed(8'd5), $signed(8'sd254)); // -2
        run_test(8'd5,  8'sd254, 8'd7,  1'b1); // 5 - (-2) = 7

        $display("-----------------------------------------------------");
        $display("Test: Negativ - Negativ (Rezultat Negativ) (A=%d, B=%d)", $signed(8'sd251), $signed(8'sd254)); // -5, -2
        run_test(8'sd251, 8'sd254, 8'sd253, 1'b1); // (-5) - (-2) = -3 (0xFD)

        $display("-----------------------------------------------------");
        $display("Test: Negativ - Negativ (Rezultat Pozitiv) (A=%d, B=%d)", $signed(8'sd254), $signed(8'sd251)); // -2, -5
        run_test(8'sd254, 8'sd251, 8'd3,  1'b1); // (-2) - (-5) = 3

        $display("-----------------------------------------------------");
        $display("Test: Valori mari pozitive (A=%d, B=%d)", $signed(8'd127), $signed(8'd1));
        run_test(8'd127, 8'd1, 8'd126, 1'b1);

        $display("-----------------------------------------------------");
        $display("Test: Overflow (127 - 128 = -1) (A=%d, B=%d)", $signed(8'd127), $signed(8'd128));
        run_test(8'd127, 8'd128, 8'sd255, 1'b0); // -1 (0xFF)

        $display("-----------------------------------------------------");
        $display("Test: Overflow (min_val - 1) (A=%d, B=%d)", $signed(8'sd128), $signed(8'd1)); // -128
        run_test(8'sd128, 8'd1, 8'd127, 1'b0); // -128 - 1 = 127 (overflow)


        #20; // Pauz? la final

        if (errors_count == 0) begin
            $info("Toate testele (cu verificare automat?) au trecut!");
        end else begin
            $error("%d erori g?site în timpul verific?rilor automate.", errors_count);
        end

        $display("Simulare finalizat?.");
        $finish;
    end

endmodule