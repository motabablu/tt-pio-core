`timescale 1ns / 1ps
`default_nettype none

package CORE_PKG;

  // Global parameters
  localparam int INSTR_WIDTH    = 16;
  localparam int PC_WIDTH 		  = 16;
  localparam int DATA_WIDTH     = 16;
  localparam int CLK_FREQ_MHZ   = 100;
  localparam int OPCODE_WIDTH   = 4;
  localparam int REG_ADDR_WIDTH = 4;
  localparam int IMM_WIDTH      = 8;
  localparam int REG_COUNT      = 16;
  localparam int GPR_COUNT      = 12;
  localparam int FIFO_DEPTH     = 256;
  localparam int IMEM_DEPTH 	  = 1024;
  
  localparam logic [REG_ADDR_WIDTH - 1:0] PIN_IN_ADDR   = 4'd12;
  localparam logic [REG_ADDR_WIDTH - 1:0] PIN_OUT_ADDR  = 4'd13;
  localparam logic [REG_ADDR_WIDTH - 1:0] PIN_DIR_ADDR  = 4'd14;
  localparam logic [REG_ADDR_WIDTH - 1:0] SMU_DATA_ADDR = 4'd15;
  
  // SPI Command Protocol
  typedef enum logic [7:0] {
    SPI_CMD_RESET_HOLD = 8'h00, 	// Freeze CPU Core in reset
    SPI_CMD_RESET_REL  = 8'h01, 	// Release CPU Core reset
    SPI_CMD_WRITE_IMEM = 8'h02, 	// Write 16-bit instruction to IMEM [Addr + Data]
    SPI_CMD_PUSH_H2C   = 8'h03, 	// Push 16-bit payload word into H2C FIFO
    SPI_CMD_POP_C2H    = 8'h04, 	// Pop 16-bit captured word from C2H FIFO
    SPI_CMD_READ_STAT  = 8'h05  	// Read FIFO status flags (Full/Empty)
  } spi_cmd_e;

	// SMU Operations
  typedef enum logic [REG_ADDR_WIDTH - 1:0] {
    SMU_OP_CLR      = 4'b0000, 	// Clear accumulator to 0x0000
    SMU_OP_CRC16    = 4'b0001,	// Compute 1-step CRC-16-CCITT
    SMU_OP_BITREV   = 4'b0010,	// Bit-reverse 16-bit word
    SMU_OP_BYTESWAP = 4'b0011, 	// Swap upper and lower bytes
    SMU_OP_LFSR     = 4'b0100, 	// Advance 16-bit Fibonacci LFSR
    SMU_OP_PARITY   = 4'b0101, 	// Compute even parity bit
	SMU_OP_SETPOLY 	= 4'b0110, 	// Load CRC polynomial
	SMU_OP_SETSEED 	= 4'b0111	// Load CRC seed
  } smu_op_e;

  // Instruction Format
  typedef struct packed {
    logic [OPCODE_WIDTH - 1:0] opcode;
    logic [REG_ADDR_WIDTH - 1:0] dest_reg;
    logic [REG_ADDR_WIDTH - 1:0] src1_reg;
    logic [REG_ADDR_WIDTH - 1:0] src2_reg;
  } instr_t;
  
  // ALU
  typedef enum logic [OPCODE_WIDTH - 2:0] {
    ALU_MOV = 3'b000,
    ALU_AND = 3'b001,
    ALU_OR  = 3'b010,
    ALU_XOR = 3'b011,
    ALU_SLL = 3'b100,
    ALU_SRL = 3'b101,
    ALU_ADD = 3'b110,
    ALU_SUB = 3'b111
  } alu_op_e;
  
  // Jump condiitons
  typedef enum logic [1:0] {
    JMP_NONE    = 2'b00,
    JMP_UNCOND  = 2'b01,
    JMP_NZ      = 2'b10,
    JMP_Z       = 2'b11
  } jmp_cond_e;
  
endpackage : CORE_PKG