`timescale 1ns / 1ps
`default_nettype none

module ALU (
  input  logic [2:0]  ALU_OP_i,
  input  logic [15:0] SRC1_i,
  input  logic [15:0] SRC2_i,
  output logic [15:0] RESULT_o,
  output logic        ZERO_FLAG_o
);

  localparam logic [2:0] ALU_MOV = 3'b000;
  localparam logic [2:0] ALU_AND = 3'b001;
  localparam logic [2:0] ALU_OR  = 3'b010;
  localparam logic [2:0] ALU_XOR = 3'b011;
  localparam logic [2:0] ALU_SLL = 3'b100;
  localparam logic [2:0] ALU_SRL = 3'b101;
  localparam logic [2:0] ALU_ADD = 3'b110;
  localparam logic [2:0] ALU_SUB = 3'b111;

  always_comb begin
    RESULT_o = '0;
    case (ALU_OP_i)
      ALU_MOV   : RESULT_o = SRC1_i;
      ALU_AND   : RESULT_o = SRC1_i & SRC2_i;
      ALU_OR    : RESULT_o = SRC1_i | SRC2_i;
      ALU_XOR   : RESULT_o = SRC1_i ^ SRC2_i;
      ALU_SLL   : RESULT_o = SRC1_i << SRC2_i[3:0];
      ALU_SRL   : RESULT_o = SRC1_i >> SRC2_i[3:0];
      ALU_ADD   : RESULT_o = SRC1_i + SRC2_i;
      ALU_SUB   : RESULT_o = SRC1_i - SRC2_i;
      default   : RESULT_o = '0;
    endcase
  end

  assign ZERO_FLAG_o = (RESULT_o == '0);
endmodule