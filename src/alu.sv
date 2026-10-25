`timescale 1ns / 1ps
`default_nettype none

// Package
import CORE_PKG::*;

module ALU (
  // Opcode
  input alu_op_e                  ALU_OP_i,
  
  // Operands
  input logic [DATA_WIDTH - 1:0]  SRC1_i,
  input logic [DATA_WIDTH - 1:0]  SRC2_i,
  
  // Outputs
  output logic [DATA_WIDTH - 1:0] RESULT_o,
  output logic                    ZERO_FLAG_o
);

  // ALU (combinational)
  always_comb begin
    // Defaults
    RESULT_o = '0;
  
    case (ALU_OP_i)
      ALU_MOV   : RESULT_o = SRC1_i;
      ALU_AND   : RESULT_o = SRC1_i & SRC2_i;
      ALU_OR    : RESULT_o = SRC1_i | SRC2_i;
      ALU_XOR   : RESULT_o = SRC1_i ^ SRC2_i;
      ALU_SLL   : RESULT_o = SRC1_i << SRC2_i[$clog2(DATA_WIDTH) - 1:0];
      ALU_SRL   : RESULT_o = SRC1_i >> SRC2_i[$clog2(DATA_WIDTH) - 1:0];
      ALU_ADD   : RESULT_o = SRC1_i + SRC2_i;
      ALU_SUB   : RESULT_o = SRC1_i - SRC2_i;
      default   : RESULT_o = '0;
    endcase // ALU_OP_i
  end // always_comb

  // Zero flag (combinational)
  assign ZERO_FLAG_o = (RESULT_o == '0);

endmodule