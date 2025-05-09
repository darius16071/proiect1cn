
//-----------------------------------------------------
// Modul Sc?z?tor pe 8 bi?i (folosind Ripple Carry Adder)
// Calculeaz? A - B
//-----------------------------------------------------
module subtracter_8bit (
    input  wire [7:0] a,
    input  wire [7:0] b,
    
    output wire [7:0] diff, // Rezultatul a - b
    output wire       borrow // Carry-out/Borrow indicator
);

    wire [7:0] not_b; // Inversiunea pe bi?i a lui B
    wire       cin_for_adder; // Carry-in ini?ial pentru sumator

    // Calculeaz? inversiunea pe bi?i a lui B
    assign not_b = ~b;

    // Pentru a efectua A - B, calcul?m A + (~B) + 1
    // Semnalul 'cin' al sumatorului este 1 pentru opera?ia de sc?dere
    assign cin_for_adder = 1'b1;

	wire dummy;

    // Instan?iem Ripple Carry Adder-ul existent
    ripple_carry_adder_8bit rca_unit (
        .a    (a),
        .b    (not_b), // Intr? (~B)
        .cin  (cin_for_adder), // Intr? 1 pentru a ad?uga 1 la (~B)
        .sum  (diff),  // Ie?irea sumei este diferen?a
        .cout (borrow) // Carry-out-ul devine "borrow" indicator
                       // Pentru opera?ia A - B, dac? borrow este 1, nu a existat borrow (rezultatul este pozitiv sau 0)
                       // Dac? borrow este 0, a existat borrow (rezultatul este negativ ?i trebuie interpretat în C2)
	,.cin_msb(dummy)
    );

    // Not? despre 'borrow':
    // În aritmetica în complement fa?? de doi pe N bi?i:
    // Rezultatul A - B este corect dac? nu exist? overflow.
    // Bitul 'cout' (borrow în acest context) al sumatorului pentru A + (~B) + 1
    //   - Dac? cout este 1, înseamn? c? rezultatul este pozitiv (sau zero) ?i c? opera?ia nu a necesitat un "împrumut" (borrow).
    //   - Dac? cout este 0, înseamn? c? rezultatul este negativ ?i c? a existat un "împrumut" (borrow).
    //     Valoarea 'diff' va fi negativ? (reprezentat? în complement fa?? de doi).

endmodule