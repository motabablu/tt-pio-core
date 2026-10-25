`timescale 1ns / 1ps

import CORE_PKG::*;

module ASIC_TB ();

  localparam real CLK_PERIOD_NS = 1000.0 / CLK_FREQ_MHZ;
  localparam time SPI_HALF_CLK  = 50ns;                   // 10 MHz SPI clock
  localparam int  MAX_CYCLES    = 50000;                  // Safety watchdog limit
  localparam int  MAX_EXP_ITEMS = 1024;

  // Simulation file paths
  localparam string PROG_HEX_PATH     = "C:/Polito/Stuff/PIO/sim/program.hex";
  localparam string H2C_HEX_PATH      = "C:/Polito/Stuff/PIO/sim/h2c.hex";
  localparam string EXP_PINS_HEX_PATH = "C:/Polito/Stuff/PIO/sim/expected_pins.hex";
  localparam string EXP_C2H_HEX_PATH  = "C:/Polito/Stuff/PIO/sim/expected_c2h.hex";
  localparam string PAD_IN_HEX_PATH   = "C:/Polito/Stuff/PIO/sim/pad_in.hex";

  logic                     clk;
  logic                     reset_n;
  logic                     spi_sck;
  logic                     spi_mosi;
  logic                     spi_miso;
  logic                     spi_cs_n;
  logic [DATA_WIDTH - 1:0]  pad_in;
  logic [DATA_WIDTH - 1:0]  pad_out;
  logic [DATA_WIDTH - 1:0]  pad_dir;

  // Scoreboard queues and counters
  logic [47:0]              exp_pins_mem [0:MAX_EXP_ITEMS - 1];
  logic [DATA_WIDTH - 1:0]  exp_c2h_mem  [0:FIFO_DEPTH - 1];
  int                       num_exp_pins;
  int                       num_exp_c2h;
  int                       pin_check_idx;
  int                       scoreboard_errors;
  logic [31:0]              pad_in_mem [0:MAX_EXP_ITEMS - 1];
  int                       num_pad_in_events;
  int                       pad_in_idx;

  // ASIC top level
  ASIC_TOP dut (
    .CLK_i      (clk),
    .RESET_n_i  (reset_n),
    .SPI_SCK_i  (spi_sck),
    .SPI_MOSI_i (spi_mosi),
    .SPI_MISO_o (spi_miso),
    .SPI_CS_n_i (spi_cs_n),
    .PAD_IN_i   (pad_in),
    .PAD_OUT_o  (pad_out),
    .PAD_DIR_o  (pad_dir)
  );

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS / 2.0) clk = ~clk;
  end

  // SPI MASTER DRIVER
  task automatic spi_transfer (
    input   spi_cmd_e                 cmd,
    input   logic [INSTR_WIDTH - 1:0] addr,
    input   logic [DATA_WIDTH - 1:0]  data_in,
    output  logic [DATA_WIDTH - 1:0]  data_out
  );
    localparam int FRAME_BITS = 8 + INSTR_WIDTH + DATA_WIDTH;
    logic [FRAME_BITS - 1:0] frame_tx;
    logic [DATA_WIDTH - 1:0] miso_capture;

    frame_tx     = {cmd, addr, data_in};
    miso_capture = '0;

    @(posedge clk);
    spi_cs_n = 1'b0;
    #(SPI_HALF_CLK);

    for (int b = FRAME_BITS - 1; b >= 0; b--) begin
      spi_mosi = frame_tx[b];
      #(SPI_HALF_CLK);
      spi_sck = 1'b1;

      if (b < DATA_WIDTH) begin
        miso_capture[b] = spi_miso;
      end

      #(SPI_HALF_CLK);
      spi_sck = 1'b0;
    end

    #(SPI_HALF_CLK);
    spi_cs_n = 1'b1;
    repeat(5) @(posedge clk);

    data_out = miso_capture;
  endtask

  // FILE LOADERS (IMEM, H2C FIFO, AND SCOREBOARD EXPECTATIONS)
  task automatic load_hex_program (input string hex_filename);
    logic [INSTR_WIDTH - 1:0] hex_buffer [0:IMEM_DEPTH - 1];
    logic [DATA_WIDTH - 1:0]  dummy_rx;
    int                       num_words;

    for (int i = 0; i < IMEM_DEPTH; i++) hex_buffer[i] = 'x;
    $readmemh(hex_filename, hex_buffer);

    spi_transfer(SPI_CMD_RESET_HOLD, '0, '0, dummy_rx);

    num_words = 0;
    for (int pc_idx = 0; pc_idx < IMEM_DEPTH; pc_idx++) begin
      if (^hex_buffer[pc_idx] === 1'bx) break;
      spi_transfer(SPI_CMD_WRITE_IMEM, pc_idx[INSTR_WIDTH - 1:0], hex_buffer[pc_idx], dummy_rx);
      num_words++;
    end

    if (num_words == 0) begin
      $display("[ERROR] 0 instructions loaded from %s!", hex_filename);
      $finish;
    end
    $display("[BOOTLOADER] Loaded %0d instructions into IMEM.", num_words);
  endtask

  task automatic load_h2c_fifo (input string hex_filename);
    logic [DATA_WIDTH - 1:0] h2c_buffer [0:FIFO_DEPTH - 1];
    logic [DATA_WIDTH - 1:0] dummy_rx;
    int                      fd, num_words;

    fd = $fopen(hex_filename, "r");
    if (fd == 0) return;
    $fclose(fd);

    for (int i = 0; i < FIFO_DEPTH; i++) h2c_buffer[i] = 'x;
    $readmemh(hex_filename, h2c_buffer);

    num_words = 0;
    for (int i = 0; i < FIFO_DEPTH; i++) begin
      if (^h2c_buffer[i] === 1'bx) break;
      spi_transfer(SPI_CMD_PUSH_H2C, '0, h2c_buffer[i], dummy_rx);
      num_words++;
    end
    $display("[BOOTLOADER] Loaded %0d payload words into H2C FIFO.", num_words);
  endtask

  task automatic load_scoreboard_files ();
    int fd;

    num_exp_pins      = 0;
    num_exp_c2h       = 0;
    pin_check_idx     = 0;
    scoreboard_errors = 0;
    num_pad_in_events = 0;
    pad_in_idx        = 0;

    for (int i = 0; i < MAX_EXP_ITEMS; i++) begin
      exp_pins_mem[i] = 'x;
      pad_in_mem[i]   = 'x;
    end
    for (int i = 0; i < FIFO_DEPTH; i++) exp_c2h_mem[i] = 'x;

    // 1. Load Expected Pin Transitions
    fd = $fopen(EXP_PINS_HEX_PATH, "r");
    if (fd != 0) begin
      $fclose(fd);
      $readmemh(EXP_PINS_HEX_PATH, exp_pins_mem);
      for (int i = 0; i < MAX_EXP_ITEMS; i++) begin
        if (^exp_pins_mem[i] === 1'bx) break;
        num_exp_pins++;
      end
    end

    // 2. Load Pad Input Stimulus Schedule (Independent of exp_pins!)
    fd = $fopen(PAD_IN_HEX_PATH, "r");
    if (fd != 0) begin
      $fclose(fd);
      $readmemh(PAD_IN_HEX_PATH, pad_in_mem);
      for (int i = 0; i < MAX_EXP_ITEMS; i++) begin
        if (^pad_in_mem[i] === 1'bx) break;
        num_pad_in_events++;
      end
    end

    // 3. Load Expected C2H FIFO Words
    fd = $fopen(EXP_C2H_HEX_PATH, "r");
    if (fd != 0) begin
      $fclose(fd);
      $readmemh(EXP_C2H_HEX_PATH, exp_c2h_mem);
      for (int i = 0; i < FIFO_DEPTH; i++) begin
        if (^exp_c2h_mem[i] === 1'bx) break;
        num_exp_c2h++;
      end
    end

    $display("[SCOREBOARD] Expecting %0d pin transitions, %0d C2H words, and %0d PAD_IN events.",
             num_exp_pins, num_exp_c2h, num_pad_in_events);
  endtask

  // REAL-TIME PIN TRANSITION SCOREBOARD
  logic [DATA_WIDTH - 1:0] prev_pad_out;
  logic [DATA_WIDTH - 1:0] prev_pad_dir;
  int                      core_cycle_cnt;
  int                      last_pad_change_cycle;

  always @(posedge clk) begin
    if (!dut.core_reset_n) begin
      prev_pad_out          <= pad_out;
      prev_pad_dir          <= pad_dir;
      core_cycle_cnt        <= 0;
      last_pad_change_cycle <= 0;
      pad_in_idx            <= 0;
      pad_in                <= '0;
      
    end else begin
      int next_cycle;
      next_cycle = core_cycle_cnt + 1;
      core_cycle_cnt <= next_cycle;
      
      // Drive external pad_in at edge (C - 1) so it is active during core cycle C
      if ((pad_in_idx < num_pad_in_events) && ((next_cycle + 1) == int'(pad_in_mem[pad_in_idx][31:16]))) begin
        pad_in     <= pad_in_mem[pad_in_idx][15:0];
        pad_in_idx <= pad_in_idx + 1;
      end

      if ((pad_out !== prev_pad_out) || (pad_dir !== prev_pad_dir)) begin
        int actual_delta;
        actual_delta = core_cycle_cnt - last_pad_change_cycle;

        if (pin_check_idx >= num_exp_pins) begin
          $display("  [FAIL] Unexpected Pin Transition %0d: DIR = 0x%04h, OUT = 0x%04h, Delta = %0d cycles",
                   pin_check_idx, pad_dir, pad_out, actual_delta);
          scoreboard_errors++;
        end else begin
          logic [15:0] exp_dir, exp_out, exp_delta;
          {exp_dir, exp_out, exp_delta} = exp_pins_mem[pin_check_idx];

          if ((pad_dir !== exp_dir) || (pad_out !== exp_out) || (actual_delta != int'(exp_delta))) begin
            $display("  [FAIL] Transition %0d Mismatch! Expected (DIR = 0x%04h, OUT = 0x%04h, Delta = %0d) | Got (DIR = 0x%04h, OUT = 0x%04h, Delta = %0d)",
                     pin_check_idx, exp_dir, exp_out, exp_delta, pad_dir, pad_out, actual_delta);
            scoreboard_errors++;
          end else begin
            $display("  [OK]   Transition %0d Matched: DIR = 0x%04h | OUT = 0x%04h | Delta = %0d cycles",
                     pin_check_idx, pad_dir, pad_out, actual_delta);
          end
        end

        pin_check_idx         <= pin_check_idx + 1;
        prev_pad_out          <= pad_out;
        prev_pad_dir          <= pad_dir;
        last_pad_change_cycle <= core_cycle_cnt;
      end
    end
  end

  // C2H FIFO SCOREBOARD VERIFICATION
  task automatic verify_c2h_fifo ();
    logic [DATA_WIDTH - 1:0] status_word;
    logic [DATA_WIDTH - 1:0] c2h_word;
    int                      idx;

    idx = 0;
    while (1) begin
      spi_transfer(SPI_CMD_READ_STAT, '0, '0, status_word);
      if (status_word[0] == 1'b1) break; // Bit 0 = C2H_EMPTY

      spi_transfer(SPI_CMD_POP_C2H, '0, '0, c2h_word);
      if (idx >= num_exp_c2h) begin
        $display("  [FAIL] Unexpected C2H_FIFO[%0d] word: 0x%04h", idx, c2h_word);
        scoreboard_errors++;
      end else if (c2h_word !== exp_c2h_mem[idx]) begin
        $display("  [FAIL] C2H_FIFO[%0d] Mismatch! Expected 0x%04h | Got 0x%04h",
                 idx, exp_c2h_mem[idx], c2h_word);
        scoreboard_errors++;
      end else begin
        $display("  [OK]   C2H_FIFO[%0d] Matched: 0x%04h", idx, c2h_word);
      end
      idx++;
    end

    if (idx != num_exp_c2h) begin
      $display("  [FAIL] C2H FIFO Count Mismatch! Expected %0d words | Got %0d words", num_exp_c2h, idx);
      scoreboard_errors++;
    end
  endtask

  // MAIN EXECUTION FLOW
  logic [DATA_WIDTH - 1:0] spi_rx_word;

  initial begin
    reset_n  = 1'b0;
    spi_sck  = 1'b0;
    spi_mosi = 1'b0;
    spi_cs_n = 1'b1;
    pad_in   = '0;

    repeat (10) @(posedge clk);
    reset_n = 1'b1;
    repeat (10) @(posedge clk);

    $display("\n----------------------------------------------------------------------");
    load_scoreboard_files();
    load_hex_program(PROG_HEX_PATH);
    load_h2c_fifo(H2C_HEX_PATH);
    $display("----------------------------------------------------------------------");
    $display("[EXECUTING...]");

    fork
      // Thread A: Release reset via SPI
      begin
        spi_transfer(SPI_CMD_RESET_REL, '0, '0, spi_rx_word);
        wait (0);
      end

      // Thread B: Halt Detector
      begin
        wait (dut.core_reset_n == 1'b1);
        @(posedge clk);
        while (1) begin
          @(posedge clk);
          if ((dut.instr === 16'hA000) || (^dut.instr === 1'bx)) begin
            // Wait 1 NBA tick so the posedge monitor finishes logging the final cycle
            #1ps;
            break;
          end
        end
      end

      // Thread C: Watchdog
      begin
        wait (dut.core_reset_n == 1'b1);
        repeat (MAX_CYCLES) @(posedge clk);
        $display("  [FAIL] Simulation timed out after %0d cycles!", MAX_CYCLES);
        scoreboard_errors++;
      end
    join_any
    disable fork;

    // Freeze core and check C2H FIFO contents
    spi_transfer(SPI_CMD_RESET_HOLD, '0, '0, spi_rx_word);
    verify_c2h_fifo();

    if (pin_check_idx != num_exp_pins) begin
      $display("  [FAIL] Pin Transition Count Mismatch! Expected %0d | Got %0d", num_exp_pins, pin_check_idx);
      scoreboard_errors++;
    end

    $display("----------------------------------------------------------------------");
    $display(" [SCOREBOARD SUMMARY]");
    $display("  Pin Transitions Checked : %0d / %0d", pin_check_idx, num_exp_pins);
    $display("  Total Errors            : %0d", scoreboard_errors);
    if (scoreboard_errors == 0) begin
      $display("  FINAL STATUS            : *** PASSED ***");
    end else begin
      $display("  FINAL STATUS            : *** FAILED ***");
    end
    $display("----------------------------------------------------------------------\n");

    repeat (20) @(posedge clk);
    $finish;
  end

endmodule