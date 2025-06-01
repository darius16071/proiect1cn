
module control_unit_radix2(
  input [1:0] q_pair,     // Perechea de biți Q_temp[1:0] (Q0, Q-1)
  input       is_done,    // Flag care indică dacă s-a terminat deja multiplicarea
  output reg  add_M,      // Semnal pentru adunare M
  output reg  sub_M       // Semnal pentru scădere M
);

  always @ (*) begin
    add_M = 1'b0;
    sub_M = 1'b0;

    if (!is_done) begin // Doar dacă multiplicarea nu s-a încheiat
      case (q_pair)
        2'b00: ; // No operation (00)
        2'b01: add_M = 1'b1; // Add M (01)
        2'b10: sub_M = 1'b1; // Subtract M (10)
        2'b11: ; // No operation (11)
        default: ; // No operation
      endcase
    end
  end
endmodule
