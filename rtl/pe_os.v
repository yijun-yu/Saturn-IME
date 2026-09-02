module pe_os (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        en,
  input  wire        acc_clr,
  input  wire        a_valid_in,
  input  wire signed [7:0] a_in,
  input  wire        b_valid_in,
  input  wire signed [7:0] b_in,
  output reg         a_valid_out,
  output reg  signed [7:0] a_out,
  output reg         b_valid_out,
  output reg  signed [7:0] b_out,
  output reg  signed [31:0] acc
);
  wire signed [15:0] prod = $signed(a_in) * $signed(b_in);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_out <= 8'sd0; a_valid_out <= 1'b0;
      b_out <= 8'sd0; b_valid_out <= 1'b0;
      acc   <= 32'sd0;
    end else if (acc_clr) begin
      acc <= 32'sd0;
    end else if (en) begin
      a_out <= a_in; a_valid_out <= a_valid_in;
      b_out <= b_in; b_valid_out <= b_valid_in;
      if (a_valid_in && b_valid_in)
        acc <= acc + {{16{prod[15]}}, prod};
    end
  end
endmodule
