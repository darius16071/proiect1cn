//-----------------------------------------------------
// Modul SRT Radix-2 Divider (8/8 bit -> 8 bit Q, 8 bit R, Unsigned)
// Implementare Non-Restoring.
// Autor: [Numele Tau/AI]
// Data: [Data Curenta]
//-----------------------------------------------------
module srt_radix2_divider_8bit (
    input  wire       clk,
    input  wire       reset,          // Reset activ pe HIGH
    input  wire       start,          // Semnal de pornire
    input  wire [7:0] dividend,       // Deîmpărțit (A) - unsigned
    input  wire [7:0] divisor,        // Împărțitor (B) - unsigned
    output reg  [7:0] quotient,       // Câtul final (Q) - unsigned
    output reg  [7:0] remainder,      // Restul final (R) - unsigned
    output reg        busy,           // Indicator de ocupat
    output wire       div_by_zero_flag // Flag eroare împărțire la zero
);

    // Parametri pentru stările mașinii de stări
    parameter IDLE        = 2'b00;
    parameter INIT        = 2'b01;
    parameter DIVIDING    = 2'b10;
    parameter CORRECTION  = 2'b11;

    // Registre pentru mașina de stări
    reg [1:0] current_state;
    reg [1:0] next_state;

    // Registre interne pentru algoritmul de împărțire
    reg signed [8:0] p_reg;          // Restul parțial P (N+1 biți)
    reg [7:0]        b_reg;          // Împărțitorul B (N biți)
    reg [7:0]        q_temp_reg;     // Registru temporar pentru construirea câtului Q
    reg [3:0]        count;          // Contor pentru numărul de iterații (N iterații)

    // Registru intern pentru flag-ul de împărțire la zero
    reg internal_div_by_zero_reg;

    // Împărțitorul B extins la N+1 biți, cu semn (dar va fi mereu pozitiv aici)
    // {1'b0, b_reg} asigură că este tratat ca pozitiv dacă b_reg este unsigned.
    wire signed [8:0] b_extended_signed = {1'b0, b_reg};

    // Variabile intermediare (registre pentru logica combinationala)
    // Acestea vor fi conduse de logica combinatională în blocul `always @(*)`
    // și folosite ca intrări pentru actualizarea registrelor secvențiale.
    reg signed [8:0] p_next_val;     // Valoarea viitoare a lui p_reg
    reg              q_bit_next_val; // Următorul bit al câtului

    // Fire intermediare pentru calculul pe 10 biți (N+2 biți) al lui 2P +/- B
    // Acest lucru previne overflow-ul la dublarea lui p_reg.
    wire signed [9:0] p_current_extended_10b; // p_reg extins la 10 biți
    wire signed [9:0] p_doubled_10b;          // 2 * p_reg (pe 10 biți)
    wire signed [9:0] b_for_calc_10b;         // b_extended_signed extins la 10 biți
    
    // Registru intermediar pentru rezultatul operației 2P +/- B pe 10 biți.
    // Acest registru este condus de logica combinatională.
    reg signed [9:0] op_result_10b;


    // --- Asignări Continue ---
    assign div_by_zero_flag       = internal_div_by_zero_reg;
    assign p_current_extended_10b = p_reg; // Extensie cu semn de la 9 la 10 biți
    assign p_doubled_10b          = p_current_extended_10b << 1; // Calculează 2*P pe 10 biți
    assign b_for_calc_10b         = b_extended_signed; // Extensie cu semn de la 9 la 10 biți

    // --- Mașina de Stări - Registrul de Stare (Secvențial) ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // --- Mașina de Stări - Logica Stării Următoare și Ieșirea 'busy' (Combinational) ---
    always @(*) begin
        // Valori implicite pentru a evita latch-uri și a defini comportamentul standard
        next_state = current_state; 
        busy       = (current_state != IDLE); // Ocupat în orice stare, cu excepția IDLE

        case (current_state)
            IDLE: begin
                // busy este setat la 0 automat de condiția de mai sus
                if (start) begin
                    if (divisor == 8'b0) begin
                        next_state = IDLE; // Rămâne în IDLE în caz de împărțire la zero
                    end else begin
                        next_state = INIT; // Pornește procesul de împărțire
                    end
                end
                // else: dacă nu este 'start', rămâne în IDLE (next_state = current_state)
            end
            INIT: begin
                next_state = DIVIDING; // Treci la starea de împărțire
            end
            DIVIDING: begin
                // 'count' este decrementat în blocul secvențial.
                // Dacă 'count' curent este 1, aceasta este ultima iterație de divizare.
                // După această iterație, 'count' va deveni 0.
                if (count == 4'd1) begin       // Ultima iterație de împărțire
                    next_state = CORRECTION;
                end else if (count == 4'd0) begin // Caz de siguranță (nu ar trebui atins dacă count inițial > 0)
                    next_state = CORRECTION; 
                end else begin
                    next_state = DIVIDING;   // Continuă împărțirea
                end
            end
            CORRECTION: begin
                next_state = IDLE; // După corecție, revine la starea IDLE
            end
            default: begin // Stare necunoscută, revine la IDLE ca măsură de siguranță
                next_state = IDLE;
            end
        endcase
    end

    // --- Calculul Valorilor Intermediare pentru p_reg și q_temp_reg (Combinational) ---
    // Acest bloc determină valorile care vor fi încărcate în p_reg și q_temp_reg la următorul front de ceas.
    always @(*) begin
        // Valori implicite pentru a evita latch-uri în cazul în care condițiile nu sunt îndeplinite
        op_result_10b  = 10'sb0; // Rezultatul operației 2P +/- B
        p_next_val     = p_reg;      // Implicit, p_reg își păstrează valoarea
        q_bit_next_val = 1'b0;      // Implicit, noul bit de cât este 0

        // Calculele se fac doar în starea DIVIDING și cât timp mai sunt iterații
        if (current_state == DIVIDING && count > 0) begin
            if (p_reg[8] == 0) begin 
                // P curent (p_reg) este pozitiv sau zero: P_next = 2*P - B
                op_result_10b = p_doubled_10b - b_for_calc_10b;
            end else begin 
                // P curent (p_reg) este negativ: P_next = 2*P + B
                op_result_10b = p_doubled_10b + b_for_calc_10b;
            end
            
            // Extrage valoarea pentru p_reg (primii N+1 biți ai rezultatului)
            p_next_val = op_result_10b[8:0]; 
            
            // Determină noul bit al câtului pe baza semnului rezultatului operației (op_result_10b)
            // q_i+1 = 1 dacă op_result_10b >= 0, altfel q_i+1 = 0.
            // Semnul este dat de bitul MSB (op_result_10b[9]). Dacă MSB este 0, numărul e pozitiv.
            q_bit_next_val = !op_result_10b[9]; 
        end
    end

    // --- Actualizarea Registrelor Interne și a Ieșirilor (Secvențial) ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Resetarea tuturor registrelor la valori inițiale definite
            p_reg        <= 9'sb0; // Restul parțial inițializat la 0
            b_reg        <= 8'b0;
            q_temp_reg   <= 8'b0;
            count        <= 4'd0;
            quotient     <= 8'b0;
            remainder    <= 8'b0;
            internal_div_by_zero_reg <= 1'b0;
        end else begin
            // Actualizări bazate pe starea curentă și tranzițiile definite
            case (current_state)
                IDLE: begin
                    if (start) begin // Acționează doar la pulsul 'start'
                        if (divisor == 8'b0) begin
                            internal_div_by_zero_reg <= 1'b1;
                            quotient     <= 8'hFF; // Indică eroare pentru cât
                            remainder    <= 8'hFF; // Indică eroare pentru rest
                            // p_reg, b_reg, q_temp_reg, count își mențin valorile (sau cele de la reset)
                        end else begin
                            internal_div_by_zero_reg <= 1'b0;
                            // Inițializare pentru o nouă operație de împărțire
                            p_reg        <= {1'b0, dividend}; // P0 = Deîmpărțitul (A), extins la N+1 biți
                            b_reg        <= divisor;          // Încarcă împărțitorul
                            q_temp_reg   <= 8'b0;            // Resetează registrul temporar al câtului
                            count        <= 4'd8;            // Setează numărul de iterații (N=8)
                            // quotient și remainder își mențin valorile până la starea CORRECTION
                        end
                    end
                    // else: dacă nu este 'start', registrele își mențin valorile (cu excepția 'busy' și 'next_state' gestionate de FSM)
                end

                INIT: begin
                    // Această stare este pentru sincronizare sau stabilizarea semnalelor.
                    // Registrele de date (p_reg, b_reg, q_temp_reg, count) au fost setate la tranziția din IDLE.
                    // Nu se modifică registrele de date aici.
                end

                DIVIDING: begin
                    if (count > 0) begin // Se execută doar dacă mai sunt pași de împărțire
                        p_reg      <= p_next_val;     // Actualizează restul parțial
                        q_temp_reg <= {q_temp_reg[6:0], q_bit_next_val}; // Shiftează noul bit de cât în q_temp_reg
                        count      <= count - 1;       // Decrementează contorul de iterații
                    end
                end

                CORRECTION: begin
                    // Corecția finală pentru rest în algoritmul non-restoring
                    if (p_reg[8] == 1) begin // Dacă ultimul rest parțial (p_reg) este negativ
                        remainder <= p_reg[7:0] + b_reg; // Rest final R = P + B
                    end else begin // Dacă ultimul rest parțial (p_reg) este pozitiv sau zero
                        remainder <= p_reg[7:0];         // Rest final R = P
                    end
                    // Pentru împărțirea non-restoring fără semn cu biți de cât {0,1},
                    // q_temp_reg conține direct câtul final.
                    quotient  <= q_temp_reg; 
                end
            endcase
        end
    end
endmodule
