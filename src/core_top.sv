`timescale 1ns / 1ps
`default_nettype none

module CORE_TOP(
  input  logic                    CLK_i,
  input  logic                    RESET_n_i,

  // Instruction memory
  output logic [CORE_PKG::PC_WIDTH - 1:0]   PC_o,
  input  CORE_PKG::instr_t                  INSTR_i,
  
  // Physical I/O
  input  logic [CORE_PKG::DATA_WIDTH - 1:0] PIN_IN_i,
  output logic [CORE_PKG::DATA_WIDTH - 1:0] PIN_OUT_o,
  output logic [CORE_PKG::DATA_WIDTH - 1:0] PIN_DIR_o,
  
  // SMU
  input  logic [CORE_PKG::DATA_WIDTH - 1:0] SMU_DATA_i,
  output logic [CORE_PKG::DATA_WIDTH - 1:0] SMU_DATA_o,
  output logic                    SMU_CMD_EN_o,
  
  // FIFO
  input  logic [CORE_PKG::DATA_WIDTH - 1:0] FIFO_DATA_i,
  output logic [CORE_PKG::DATA_WIDTH - 1:0] FIFO_DATA_o,
  output logic                    FIFO_PUSH_o,
  output logic                    FIFO_POP_o
);

  import CORE_PKG::*;

  // Decoder
  logic                         alu_en;
  alu_op_e                      alu_op;
  logic                         reg_write_en;
  logic                         delay_en;
  logic [IMM_WIDTH - 1:0]       delay_val;
  logic                         wait_edge_en;
  logic [REG_ADDR_WIDTH - 1:0]  edge_pin;
  logic                         edge_polarity;
  logic                         jmp_en;
  jmp_cond_e                    jmp_cond;
  logic [IMM_WIDTH - 1:0]       jmp_offset;
  logic                         dec_fifo_push;
  logic                         dec_fifo_pop;
  logic                         dec_smu_cmd_en;
  
  // Register File
  logic [DATA_WIDTH - 1:0] read_data1;
  logic [DATA_WIDTH - 1:0] read_data2;
  
  // ALU
  logic [DATA_WIDTH - 1:0]  alu_result;
  logic                     zero_flag;
  logic                     q_zero_flag;
  
  // Timing controller
  logic stall;
  
  // Internal
  logic                     branch_taken;
  logic [DATA_WIDTH - 1:0]  reg_write_data;
  logic signed [PC_WIDTH - 1:0] signed_jmp_offset;
  
  // Decoder
  DECODER u_decoder (
    .INSTR_i          (INSTR_i),
    .ALU_EN_o         (alu_en),
    .ALU_OP_o         (alu_op),
    .REG_WRITE_EN_o   (reg_write_en),
    .DELAY_EN_o       (delay_en),
    .DELAY_VAL_o      (delay_val),
    .WAIT_EDGE_EN_o   (wait_edge_en),
    .EDGE_PIN_o       (edge_pin),
    .EDGE_POLARITY_o  (edge_polarity),
    .JMP_EN_o         (jmp_en),
    .JMP_COND_o       (jmp_cond),
    .JMP_OFFSET_o     (jmp_offset),
    .FIFO_PUSH_o      (dec_fifo_push),
    .FIFO_POP_o       (dec_fifo_pop),
    .SMU_CMD_EN_o     (dec_smu_cmd_en)
  );
  
  // Register File
  REG_FILE u_reg_file (
    .CLK_i          (CLK_i),
    .RESET_n_i      (RESET_n_i),
    .WRITE_EN_i     (reg_write_en),
    .WRITE_ADDR_i   (INSTR_i.dest_reg),
    .WRITE_DATA_i   (reg_write_data),
    .READ_ADDR1_i   (INSTR_i.src1_reg),
    .READ_ADDR2_i   (INSTR_i.src2_reg),
    .READ_DATA1_o   (read_data1),
    .READ_DATA2_o   (read_data2),
    .PIN_IN_i       (PIN_IN_i),
    .PIN_OUT_o      (PIN_OUT_o),
    .PIN_DIR_o      (PIN_DIR_o),
    .SMU_DATA_i     (SMU_DATA_i),
    .SMU_DATA_o     (SMU_DATA_o)
  );
  
  // ALU
  ALU u_alu (
    .ALU_OP_i     (alu_op),
    .SRC1_i       (read_data1),
    .SRC2_i       (read_data2),
    .RESULT_o     (alu_result),
    .ZERO_FLAG_o  (zero_flag)
  );
  
  // Timing controller
  TIMING_CTRL u_timing_ctrl (
    .CLK_i            (CLK_i),
    .RESET_n_i        (RESET_n_i),
    .DELAY_EN_i       (delay_en),
    .DELAY_VAL_i      (delay_val),
    .WAIT_EDGE_EN_i   (wait_edge_en),
    .EDGE_PIN_i       (edge_pin),
    .EDGE_POLARITY_i  (edge_polarity),
    .PIN_IN_i         (PIN_IN_i),
    .STALL_o          (stall)
  );
  
  // Ouput mapping (combinational)
  assign FIFO_DATA_o    = read_data1;
  assign FIFO_PUSH_o    = RESET_n_i ? dec_fifo_push   : 1'b0;
  assign FIFO_POP_o     = RESET_n_i ? dec_fifo_pop    : 1'b0;
  assign SMU_CMD_EN_o   = RESET_n_i ? dec_smu_cmd_en  : 1'b0;
  
  // Write back MUX (combinational)
  assign reg_write_data = FIFO_POP_o ? FIFO_DATA_i : alu_result;
  
  // Branch evaluator (combinational)
  always_comb begin
    // Defaults
    branch_taken = 1'b0;
    if (jmp_en) begin
      case (jmp_cond)
        JMP_UNCOND  : branch_taken = 1'b1;
        JMP_NZ      : branch_taken = ~q_zero_flag;
        JMP_Z       : branch_taken = q_zero_flag;
        default     : branch_taken = 1'b0;
      endcase // jmp_cond
    end // jmp_en
  end // always_comb
  
  // Sign extend (combinational)
  assign signed_jmp_offset = {{(PC_WIDTH - IMM_WIDTH){jmp_offset[IMM_WIDTH - 1]}}, jmp_offset};
    
  // Program Counter & Fetch-Ahead
  logic [PC_WIDTH - 1:0] pc_reg;
  logic [PC_WIDTH - 1:0] next_pc;

  // Next PC calculation (combinational)
  always_comb begin
    if (stall) begin
      next_pc = pc_reg;                       // Hold PC on stall (re-fetches same instruction)
    end else if (branch_taken) begin
      next_pc = pc_reg + signed_jmp_offset;   // Jump to target
    end else begin
      next_pc = pc_reg + 1'b1;                // Sequential execution
    end
  end

  // PC state update (sequential)
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      pc_reg <= '0;
    end else begin
      pc_reg <= next_pc;
    end
  end
  
  assign PC_o = (!RESET_n_i) ? '0 : next_pc;
  
  // Zero flag register (sequential)
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      q_zero_flag <= 1'b0;
    end // RESET_n_i 
    else if (alu_en && !stall) begin
      q_zero_flag <= zero_flag;
    end // alu_en, stall
  end // CLK_i, RESET_n_i  
  
endmodule