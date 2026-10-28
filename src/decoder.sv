`timescale 1ns / 1ps
`default_nettype none

module DECODER (
  input  logic [15:0] INSTR_i,
  output logic        ALU_EN_o,
  output logic [2:0]  ALU_OP_o,
  output logic        REG_WRITE_EN_o,
  output logic        DELAY_EN_o,
  output logic [7:0]  DELAY_VAL_o,
  output logic        WAIT_EDGE_EN_o,
  output logic [3:0]  EDGE_PIN_o,
  output logic        EDGE_POLARITY_o,
  output logic        JMP_EN_o,
  output logic [1:0]  JMP_COND_o,
  output logic [7:0]  JMP_OFFSET_o,
  output logic        FIFO_PUSH_o,
  output logic        FIFO_POP_o,
  output logic        SMU_CMD_EN_o
);

  logic [3:0] opcode;
  logic [3:0] dest_reg;
  logic [3:0] src1_reg;
  logic [3:0] src2_reg;
  logic [7:0] imm;

  assign opcode   = INSTR_i[15:12];
  assign dest_reg = INSTR_i[11:8];
  assign src1_reg = INSTR_i[7:4];
  assign src2_reg = INSTR_i[3:0];
  assign imm      = INSTR_i[7:0];

  assign ALU_EN_o = ~opcode[3];
  
  always_comb begin
    REG_WRITE_EN_o  = 1'b0;
    ALU_OP_o        = 3'b000;
    DELAY_EN_o      = 1'b0;
    DELAY_VAL_o     = '0;
    WAIT_EDGE_EN_o  = 1'b0;
    EDGE_PIN_o      = '0;
    EDGE_POLARITY_o = 1'b0;
    JMP_EN_o        = 1'b0;
    JMP_COND_o      = 2'b00;
    JMP_OFFSET_o    = '0;
    FIFO_PUSH_o     = 1'b0;
    FIFO_POP_o      = 1'b0;
    SMU_CMD_EN_o    = 1'b0;
    
    if (ALU_EN_o) begin
      REG_WRITE_EN_o  = 1'b1;
      ALU_OP_o        = opcode[2:0];
    end else begin
      case (opcode)
        4'b1000 : begin
          DELAY_EN_o  = 1'b1;
          DELAY_VAL_o = imm;
        end
        4'b1001 : begin
          WAIT_EDGE_EN_o  = 1'b1;
          EDGE_PIN_o      = dest_reg;
          EDGE_POLARITY_o = src2_reg[0];
        end
        4'b1010 : begin
          JMP_EN_o      = 1'b1;
          JMP_COND_o    = 2'b01;
          JMP_OFFSET_o  = imm;
        end
        4'b1011 : begin
          JMP_EN_o      = 1'b1;
          JMP_COND_o    = 2'b10;
          JMP_OFFSET_o  = imm;
        end
        4'b1100 : begin
          JMP_EN_o      = 1'b1;
          JMP_COND_o    = 2'b11;
          JMP_OFFSET_o  = imm;
        end
        4'b1101 : begin
          FIFO_PUSH_o = 1'b1;
        end
        4'b1110 : begin
          FIFO_POP_o      = 1'b1;
          REG_WRITE_EN_o  = 1'b1;
        end
        4'b1111 : begin
          SMU_CMD_EN_o  = 1'b1;
        end
        default : ;
      endcase
    end
  end
endmodule