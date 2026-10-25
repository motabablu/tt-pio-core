`timescale 1ns / 1ps
`default_nettype none

// Package
import CORE_PKG::*;

module DECODER (
  input instr_t  INSTR_i,
 
  // Control
  output logic     ALU_EN_o,
  output alu_op_e  ALU_OP_o,
  output logic     REG_WRITE_EN_o,
 
  // Timing
  output logic                        DELAY_EN_o,
  output logic [IMM_WIDTH - 1:0]      DELAY_VAL_o,
  output logic                        WAIT_EDGE_EN_o,
  output logic [REG_ADDR_WIDTH - 1:0] EDGE_PIN_o,
  output logic                        EDGE_POLARITY_o,
  
  // Jump
  output logic                    JMP_EN_o,
  output jmp_cond_e               JMP_COND_o,
  output logic [IMM_WIDTH - 1:0]  JMP_OFFSET_o,
  
  // FIFO
  output logic FIFO_PUSH_o,
  output logic FIFO_POP_o,
  output logic SMU_CMD_EN_o
);
  
  logic [IMM_WIDTH - 1:0] imm;
  
  assign imm      = {INSTR_i.src1_reg, INSTR_i.src2_reg};
  assign ALU_EN_o = ~INSTR_i.opcode[OPCODE_WIDTH - 1];
  
  // MAPPING (combinational)
  always_comb begin
    // Defaults
    REG_WRITE_EN_o  = 1'b0;
    ALU_OP_o        = ALU_MOV;
    DELAY_EN_o      = 1'b0;
    DELAY_VAL_o     = '0;
    WAIT_EDGE_EN_o  = 1'b0;
    EDGE_PIN_o      = '0;
    EDGE_POLARITY_o = 1'b0;
    JMP_EN_o        = 1'b0;
    JMP_COND_o      = JMP_NONE;
    JMP_OFFSET_o    = '0;
    FIFO_PUSH_o     = 1'b0;
    FIFO_POP_o      = 1'b0;
    SMU_CMD_EN_o    = 1'b0;
    
    // Decoding
    if (ALU_EN_o) begin
      REG_WRITE_EN_o  = 1'b1;
      ALU_OP_o        = alu_op_e'(INSTR_i.opcode[OPCODE_WIDTH - 2:0]);
    end else begin
      case (INSTR_i.opcode)
      
        // DELAY
        4'b1000 : begin
          DELAY_EN_o  = 1'b1;
          DELAY_VAL_o = imm;
        end // 4'b1000
        
        // WEDGE (not potato)
        4'b1001 : begin
          WAIT_EDGE_EN_o  = 1'b1;
          EDGE_PIN_o      = INSTR_i.dest_reg;
          EDGE_POLARITY_o = INSTR_i.src2_reg[0];
        end // 4'b1001
        
        // JMP
        4'b1010 : begin
          JMP_EN_o      = 1'b1;
          JMP_COND_o    = JMP_UNCOND;
          JMP_OFFSET_o  = imm;
        end // 4'b1010
          
        // JNZ
        4'b1011 : begin
          JMP_EN_o      = 1'b1;
          JMP_COND_o    = JMP_NZ;
          JMP_OFFSET_o  = imm;
        end // 4'b1011
        
        // JZ
        4'b1100 : begin
          JMP_EN_o      = 1'b1;
          JMP_COND_o    = JMP_Z;
          JMP_OFFSET_o  = imm;
        end // 4'b1100
        
        // PUSH
        4'b1101 : begin
          FIFO_PUSH_o = 1'b1;
        end // 4'b1101
        
        // POP
        4'b1110 : begin
          FIFO_POP_o      = 1'b1;
          REG_WRITE_EN_o  = 1'b1;
        end // 4'b1110
        
        // SMU_CMD
        4'b1111 : begin
          SMU_CMD_EN_o  = 1'b1;
        end // 4'b1111
        
        default : ;
        
      endcase // INSTR_i.opcode
    end // ALU_EN_o
  end // always_comb
        
endmodule // DECODER