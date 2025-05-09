
// Modul pentru un registru generic D-type
// Parametru: WIDTH - lățimea registrului în biți
// Intrări:
//   clk - semnal de ceas
//   rst - semnal de reset (activ pe LOW în acest exemplu)
//   en  - semnal de enable (registrul se actualizează doar când en este activ)
//   d   - intrarea de date
// Ieșiri:
//   q   - ieșirea de date a registrului

module register #(
    parameter WIDTH = 8 // Valoare default pentru lățime, poate fi suprascrisă la instanțiere
) (
    input                   clk,
    input                   rst, // Reset activ pe LOW
    input                   en,
    input      [WIDTH-1:0]  d,
    output reg [WIDTH-1:0]  q
);

    // Comportamentul registrului:
    // - La reset (rst = 0), ieșirea q devine 0.
    // - La frontul negativ al ceasului (negedge clk):
    //   - Dacă resetul nu este activ (rst = 1) ȘI enable-ul este activ (en = 1),
    //     atunci ieșirea q preia valoarea intrării d.
    //   - Altfel, q își menține valoarea anterioară (dacă nu e reset).
    always @(negedge clk or negedge rst) begin
        if (!rst) begin // Reset asincron, activ pe LOW
            q <= {WIDTH{1'b0}}; // Setează toți biții la 0
        end else if (en) begin // Actualizare sincronă pe frontul negativ al ceasului, dacă enable este activ
            q <= d;
        end
        // Implicit: dacă rst este 1 și en este 0, q își menține valoarea 
    end

endmodule