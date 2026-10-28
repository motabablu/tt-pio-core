`timescale 1ns / 1ps
`default_nettype none

module FIFO (
  input   logic                     CLK_i,
  input   logic                     RESET_n_i,
  
  // Write
  input   logic [CORE_PKG::DATA_WIDTH - 1:0]  DATA_i,
  input   logic                     PUSH_i,
  output  logic                     FULL_o,
  
  // Read
  output  logic [CORE_PKG::DATA_WIDTH - 1:0]  DATA_o,
  input   logic                     POP_i,
  output  logic                     EMPTY_o
);

  import CORE_PKG::*;

  // Address width
  localparam int ADDR_WIDTH = $clog2(FIFO_DEPTH);
  
  // Memory array
  logic [DATA_WIDTH - 1:0] mem [0:FIFO_DEPTH - 1];
  
  logic [ADDR_WIDTH:0] write_ptr;
  logic [ADDR_WIDTH:0] read_ptr;
  
  assign EMPTY_o  = (write_ptr == read_ptr);
  assign FULL_o   = (write_ptr[ADDR_WIDTH] != read_ptr[ADDR_WIDTH]) && (write_ptr[ADDR_WIDTH - 1:0] == read_ptr[ADDR_WIDTH - 1:0]);
  
  // Read (combinational)
  assign DATA_o = mem[read_ptr[ADDR_WIDTH - 1:0]];
  
  // Write (sequential)
  always_ff @(posedge CLK_i or negedge RESET_n_i) begin
    if (!RESET_n_i) begin
      write_ptr <= '0;
      read_ptr  <= '0;
    end else begin
      if (PUSH_i && !FULL_o) begin
        mem[write_ptr[ADDR_WIDTH - 1:0]] <= DATA_i;
        write_ptr                         <= write_ptr + 1'b1;
      end // PUSH_i, FULL_o
      if (POP_i && !EMPTY_o) begin
        read_ptr <= read_ptr + 1'b1;
      end // POP_i, EMPTY_o
    end // RESET_n_i
  end // CLK_i

endmodule