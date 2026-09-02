module pe_os (
  input  wire        clk,
  input  wire        rst_n,

  input  wire [7:0]  a_in,
  input  wire        a_valid_in,
  output reg  [7:0]  a_out,
  output reg         a_valid_out,

  input  wire [7:0]  b_in,
  input  wire        b_valid_in,
  output reg  [7:0]  b_out,
  output reg         b_valid_out,

  input  wire        acc_clr,
  input  wire        acc_ld,
  input  wire [31:0] acc_wdata,
  output wire [31:0] acc_rdata
);

  reg signed [31:0] acc;

  assign acc_rdata = acc;

  wire signed [7:0]  a_s   = $signed(a_in);
  wire signed [7:0]  b_s   = $signed(b_in);
  wire signed [15:0] prod  = a_s * b_s;
  wire               do_mac = a_valid_in & b_valid_in;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_out       <= 8'h00;
      a_valid_out <= 1'b0;
      b_out       <= 8'h00;
      b_valid_out <= 1'b0;
      acc         <= 32'sd0;
    end else begin
      a_out       <= a_in;
      a_valid_out <= a_valid_in;
      b_out       <= b_in;
      b_valid_out <= b_valid_in;

      if (acc_clr)
        acc <= 32'sd0;
      else if (acc_ld)
        acc <= $signed(acc_wdata);
      else if (do_mac)
        acc <= acc + {{16{prod[15]}}, prod};
    end
  end

endmodule
