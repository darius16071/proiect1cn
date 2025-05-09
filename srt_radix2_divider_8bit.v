
//-----------------------------------------------------
// Modul SRT Radix-2 Divider (8/8 bit -> 8 bit Q, 8 bit R, Unsigned)
// Implementează împărțirea folosind o logică similară Non-Restoring.
// Folosește Q+/Q- și necesită corecție finală rest + scădere finală Q.
// Multi-ciclu (8 pași + corecție + scădere).
//-----------------------------------------------------
module srt_radix2_divider_8bit (
    input  wire       clk,
    input  wire       reset,
    input  wire       start,          // Semnal de pornire
    input  wire [7:0] dividend,       // Deîmpărțit (A) - unsigned
    input  wire [7:0] divisor,        // Împărțitor (B) - unsigned
    output reg  [7:0] quotient,       // Câtul final (Q) - unsigned
    output reg  [7:0] remainder,      // Restul final (R) - unsigned
    output reg        busy,           // Indicator de ocupat
    output reg        div_by_zero     // Flag eroare împărțire la zero
);

    // State machine states
    parameter IDLE        = 2'b00;
    parameter DIVIDING    = 2'b01;
    parameter CORRECTION  = 2'b10; // Corecție rest + Scădere Q
    parameter FINISHED    = 2'b11; // Stat intermediar pt a seta busy=0

    reg [1:0] current_state, next_state;

    // Registre interne
    reg signed [8:0] p_reg;         // Rest parțial (P), 9 biți pentru 2P+/-B
    reg [7:0]        b_reg;         // Împărțitor (B)
    reg [7:0]        dividend_sreg; // Registru de shift pentru Dividend (A)
    reg [7:0]        q_pos_reg;     // Registru pentru biții q= +1
    reg [7:0]        q_neg_reg;     // Registru pentru biții q= -1
    reg [3:0]        count;         // Numărător pași (de la 8 la 0)
    reg              rem_correction_needed; // Flag: restul final P este negativ
    reg [7:0]        final_rem_buffer; // Buffer pt restul (posibil corectat)

reg signed [8:0] final_p_candidate;

    // Fire interne pentru operații
    wire signed [8:0] b_extended    = {1'b0, b_reg};       // B extins la 9 biți
    wire signed [8:0] neg_b_extended = -b_extended;      // -B pe 9 biți
    wire signed [8:0] p_shifted     = {p_reg[7:0], dividend_sreg[7]}; // P << 1 + bit A
    wire signed [8:0] p_plus_b      = p_shifted + b_extended;
    wire signed [8:0] p_minus_b     = p_shifted - b_extended;

    // Fire pentru noul bit de cât (forma Q+/Q-)
    reg q_pos_next_bit;
    reg q_neg_next_bit;

    // Instanțiere subtractor intern pentru Q = Qpos - Qneg
    wire [7:0] final_quotient_internal;
    wire       q_sub_c_flag, q_sub_v_flag; // Ignorate

    adder_subtractor_8bit q_subtractor (
        .a(q_pos_reg),
        .b(q_neg_reg),
        .subtract(1'b1), // Efectuează scădere
        .result(final_quotient_internal),
        .c_flag(q_sub_c_flag), // Ignorat
        .v_flag(q_sub_v_flag)  // Ignorat
    );

    // State machine logic: Current state register
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic: Next state and output logic
    always @(*) begin
        // Valori implicite (păstrează starea/valorile dacă nu se specifică altfel)
        next_state = current_state;
        busy = (current_state != IDLE); // Busy în toate stările, cu excepția IDLE
        div_by_zero = 1'b0; // Reset implicit

        // Comportament bazat pe starea curentă
        case (current_state)
            IDLE: begin
                busy = 1'b0; // Nu suntem ocupați
                if (start) begin
                    if (divisor == 8'b0) begin
                        div_by_zero = 1'b1; // Eroare, rămânem în IDLE
                        next_state = IDLE;
                        // Opțional: Setează ieșiri la valori de eroare
                        // quotient = 8'hFF;
                        // remainder = 8'hFF;
                    end else begin
                        // Start valid: Inițializează și treci la DIVIDING
                        next_state = DIVIDING;
                    end
                end else begin
                     next_state = IDLE; // Rămânem în IDLE
                end
            end // case IDLE

            DIVIDING: begin
                 // Logica pentru un pas de împărțire (executată combinational)
                 // Decizia se bazează pe p_reg din ciclul *anterior*
                 if (p_reg[8] == 0) begin // P >= 0
                    // Try P' = P_shifted - B
                    q_pos_next_bit = 1'b1; // Presupunem q = +1
                    q_neg_next_bit = 1'b0;
                 end else begin // P < 0
                    // Try P' = P_shifted + B
                    q_pos_next_bit = 1'b0;
                    q_neg_next_bit = 1'b1; // Presupunem q = -1
                 end

                 // Trecere la starea următoare (CORRECTION) după 8 pași
                 if (count == 1'b1) begin // Ultimul pas tocmai se încheie în acest ciclu
                     next_state = CORRECTION;
                 end else begin
                     next_state = DIVIDING; // Continuăm împărțirea
                 end
            end // case DIVIDING

            CORRECTION: begin
                 // Calculul final al câtului (Q = Qpos - Qneg) - combinational
                 // Calculul restului corectat - combinational
                 // Treci la starea FINISHED pentru a actualiza ieșirile
                 next_state = FINISHED;
            end // case CORRECTION

            FINISHED: begin
                 // Stare intermediară pentru a permite asignarea finală
                 // și tranziția înapoi la IDLE
                 next_state = IDLE;
                 busy = 1'b0; // ALU devine liber
            end // case FINISHED

            default: begin
                next_state = IDLE;
                busy = 1'b0;
            end
        endcase
    end // always @(*)


    // Registre și logică de actualizare (secvențială)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            p_reg <= 9'b0; b_reg <= 8'b0; dividend_sreg <= 8'b0;
            q_pos_reg <= 8'b0; q_neg_reg <= 8'b0; count <= 4'b0;
            quotient <= 8'b0; remainder <= 8'b0;
            rem_correction_needed <= 1'b0;
            final_rem_buffer <= 8'b0;
        end else begin
            // Acțiuni bazate pe starea CURENTĂ (tranziția are loc la SFÂRȘITUL ciclului)
            case (current_state)
                IDLE: begin
                    if (start && divisor != 8'b0) begin // Inițializare la start valid
                        p_reg <= 9'b0;
                        b_reg <= divisor;
                        dividend_sreg <= dividend;
                        q_pos_reg <= 8'b0;
                        q_neg_reg <= 8'b0;
                        count <= 4'd8;
                        rem_correction_needed <= 1'b0;
                        final_rem_buffer <= 8'b0;
                    end
                end

                DIVIDING: begin
                    if (count > 0) begin
                        // Logica Non-Restoring/SRT simplificată:
                        if (p_reg[8] == 0) begin // P >= 0
                           p_reg <= p_minus_b; // P_next = P_shifted - B
                        end else begin // P < 0
                           p_reg <= p_plus_b;  // P_next = P_shifted + B
                        end

                        // Shift Q+/Q- (folosind valorile calculate combinational)
                        q_pos_reg <= {q_pos_reg[6:0], q_pos_next_bit};
                        q_neg_reg <= {q_neg_reg[6:0], q_neg_next_bit};
                        // Shift dividend
                        dividend_sreg <= dividend_sreg << 1;
                        // Decrement count
                        count <= count - 1;

                        // Verifică dacă restul final (după ultimul pas) va necesita corecție
                        if (count == 1'b1) begin
                            // Verifică semnul lui P care VA FI încărcat la următorul ceas
                            if (p_reg[8] == 0) begin // Dacă P curent e >=0
                                rem_correction_needed <= p_minus_b[8]; // Corecție dacă P_shifted-B < 0
                            end else begin // Dacă P curent e < 0
                                rem_correction_needed <= p_plus_b[8]; // Corecție dacă P_shifted+B < 0 ? Nu, corecția e necesară doar dacă P final e < 0.
                                // Corecția SRT/Non-Restoring se face dacă P *final* e negativ
                                // Verificăm valoarea care *va fi* în p_reg după acest ultim ciclu.
                                //wire signed [8:0] final_p_candidate = (p_reg[8] == 0) ? p_minus_b : p_plus_b;
				final_p_candidate = (p_reg[8] == 0) ? p_minus_b : p_plus_b;

                                rem_correction_needed <= final_p_candidate[8];
                            end
                        end
                    end
                end // case DIVIDING

                CORRECTION: begin
                    // Calculează și stochează restul final corectat
                    if (rem_correction_needed) begin
                         // Restul final P este negativ, trebuie corectat: R = P + B
                         final_rem_buffer <= p_reg[7:0] + b_reg; // Folosim p_reg calculat în ultimul ciclu DIVIDING
                    end else begin
                         // Restul final P este pozitiv, este corect: R = P
                         final_rem_buffer <= p_reg[7:0];
                    end
                    // Câtul final va fi calculat combinational și asignat în starea FINISHED
                end

                FINISHED: begin
                    // Atribuie valorile finale calculate în starea CORRECTION
                    quotient <= final_quotient_internal; // Rezultatul de la q_subtractor
                    remainder <= final_rem_buffer;    // Restul (posibil corectat)
                end

            endcase // case (current_state)
        end // else !reset
    end // always @(posedge clk or posedge reset)

endmodule