`timescale 1ns / 1ps
`default_nettype none

module ALU (
  input  logic [2:0]  ALU_OP_i,
  input  logic [15:0] SRC1_i,
  input  logic [15:0] SRC2_i,
  output logic [15:0] RESULT_o,
  output logic        ZERO_FLAG_o
);

  import CORE_PKG::*;

  always_comb begin
    RESULT_o = '0;
    case (alu_op_e'(ALU_OP_i))
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