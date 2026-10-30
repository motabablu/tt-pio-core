## How it works

The 16-bit RISC Protocol Emulator is a custom I/O co-processor engineered for deterministic, cycle-accurate bit-banging and multi-protocol hardware emulation (supporting SPI, I2C, USB 1.1, CAN, UART, and Ethernet PHY layers)[cite: 33]. 

Built around a single-cycle Harvard architecture, the processor core executes every standard instruction—including arithmetic, logical, and relative branch operations—in precisely one clock cycle[cite: 35, 38]. To eliminate pipeline stalls and memory access penalties while interfacing with physical on-chip memory, the core incorporates a fetch-ahead Program Counter (PC) update scheme. This design hides the 1-cycle synchronous read latency of the integrated IHP 130nm dual-port SRAM macro (`RM_IHPSG13_2P_512x16_c2_bm_bist`)[cite: 35, 40].

### 1. Core Subsystems:
* **Instruction Memory (IMEM):** 1 KiB of dedicated onboard dual-port SRAM ($512 \text{ words} \times 16 \text{ bits}$) initialized asynchronously or out-of-band via an external SPI controller interface[cite: 33, 40].
* **State Machine Unit (SMU):** A dedicated hardware co-processor block designed to accelerate complex protocol processing tasks such as CRC-16 polynomial checks, bit reversals, byte-swapping, pseudo-random bit generation (LFSR), and parity calculations[cite: 43].
* **Stream Interfaces (FIFOs):** Dual independent 16-word deep hardware FIFO queues for Host-to-Core (H2C) and Core-to-Host (C2H) data streaming[cite: 33, 41].
* **Hardware Synchronization (`WEDGE`):** Features a 2-Flip-Flop Clock Domain Crossing (CDC) synchronizer chain to poll external pin edges with cycle-accuracy, eliminating resource-intensive software polling loops[cite: 33, 35, 38].
* **Dynamic Bus Turnaround:** Tri-state pad direction control registers mapped directly to core data paths for half-duplex serial protocols like I2C[cite: 33, 35, 42].

---

## 2. Top-Level Pinout & Interface Definition

The top-level wrapper module (`ASIC_TOP`) exposes synchronous clock, reset, serial programming, and parallel I/O interfaces[cite: 33]. Additionally, the TinyTapeout top-level pad frame adapter (`tt_um_pio_core`) maps these internal lines to physical bidirectional `uio` pins and dedicated `ui_in`/`uo_out` lines[cite: 46]:

| Signal Name (ASIC_TOP) | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `CLK_i` | Input | 1 | Master system clock[cite: 33] |
| `RESET_n_i` | Input | 1 | Asynchronous active-low system reset[cite: 33] |
| `SPI_SCK_i` | Input | 1 | SPI serial clock (`ui_in[0]`) for IMEM programming and host gateway[cite: 33, 46] |
| `SPI_MOSI_i` | Input | 1 | SPI Master-Out Slave-In data line (`ui_in[1]`)[cite: 33, 46] |
| `SPI_MISO_o` | Output | 1 | SPI Master-In Slave-Out data line (`uo_out[0]`)[cite: 33, 46] |
| `SPI_CS_n_i` | Input | 1 | SPI active-low chip select (`ui_in[2]`)[cite: 33, 46] |
| `PAD_IN_i` | Input | 16 | Synchronized parallel input pad bus (`uio_in[7:0]` mapped to lower byte; `ui_in[7:3]` mapped to upper byte)[cite: 33, 46] |
| `PAD_OUT_o` | Output | 16 | Parallel output pad bus driven by core registers (`uio_out` and `uo_out[7:1]`)[cite: 33, 42, 46] |
| `PAD_DIR_o` | Output | 16 | Bidirectional pad direction control vector (`uio_oe` enable path: `1` = Output, `0` = Input)[cite: 33, 42, 46] |

---

## 3. On-Chip SRAM Subsystem (`DP_SRAM`)

The memory subsystem uses the IHP dual-port SRAM macro (`RM_IHPSG13_2P_512x16_c2_bm_bist`) configured as Instruction Memory (IMEM)[cite: 33, 40]:
* **Capacity:** 512 addressable 16-bit words ($1024 \text{ bytes} = 1 \text{ KiB}$).
* **Dual-Port Architecture:**
  * **Port A (Write / Programming Port):** Controlled exclusively by the external SPI controller (`WE_i`, `ADDR_WR_i`, `DATA_WR_i`), permitting out-of-band firmware downloads and memory initialization while the core is held in reset (`CORE_RELEASE_o = 0`)[cite: 33, 40].
  * **Port B (Read / Instruction Fetch Port):** Driven synchronously by the core’s execution engine (`ADDR_RD_i` connected to `PC_o`, `DATA_RD_o` supplying `INSTR_i`)[cite: 33, 40].

---

## 4. Hardware FIFO Stream Subsystems (`FIFO`)

Data exchange between the external host interface and the core execution unit is handled via two independent hardware FIFO instances (`u_h2c_fifo` and `u_c2h_fifo`)[cite: 33, 41]:
* **Structural Parameters:** Depth = 16 words, Data Width = 16 bits, Address Pointer Width = 4 bits (with full/empty detection flags)[cite: 41].
* **H2C (Host-to-Core) FIFO:** Buffers data pushed by the external SPI controller (`SPI_MOSI`) and popped by the core execution unit during `POP` instructions[cite: 33, 39, 41].
* **C2H (Core-to-Host) FIFO:** Buffers data pushed by the core via `PUSH` instructions and popped by the SPI controller for host egress (`SPI_MISO`)[cite: 33, 39, 41].

---

## 5. State Machine Unit (SMU) Co-Processor (`SMU`)

The SMU offloads protocol processing overhead from the main RISC core[cite: 33, 43]. It operates on an internal accumulator register (`acc_reg`), a polynomial configuration register (`poly_reg`), and receives 16-bit input values (`SMU_DATA_i`) when enabled by `SMU_CMD_EN_i`[cite: 43].

Supported SMU operations (`SMU_OP_i`)[cite: 43]:
* `4'b0000` (`CLR`): Clears accumulator (`acc_reg <= '1`)[cite: 43].
* `4'b0001` (`CRC16`): Computes a 16-bit CRC cycle using the active polynomial (`poly_reg`)[cite: 43].
* `4'b0010` (`BITREV`): Bit-reverses the 16-bit input word[cite: 43].
* `4'b0011` (`BYTESWAP`): Swaps upper and lower bytes (`{SMU_DATA_i[7:0], SMU_DATA_i[15:8]}`)[cite: 43].
* `4'b0100` (`LFSR`): Advances Linear Feedback Shift Register state based on accumulator and polynomial bits[cite: 43].
* `4'b0101` (`PARITY`): Computes odd/even bit reduction parity (`^SMU_DATA_i`)[cite: 43].
* `4'b0110` (`SETPOLY`): Loads custom polynomial value into `poly_reg`[cite: 43].
* `4'b0111` (`SETSEED`): Loads seed value into `acc_reg`[cite: 43].

---

## 6. Instruction Set Architecture (ISA) Reference

The instruction word is structured into 16 bits, utilizing fixed field definitions depending on instruction classification[cite: 35, 39]:
* **ALU Formats:** `[15:12] Opcode`, `[11:8] Dest Reg`, `[7:4] Src1 Reg`, `[3:0] Src2 Reg`[cite: 35, 39].
* **Immediate / Branch Formats:** `[15:12] Opcode`, `[11:8] Dest Reg / Flags`, `[7:0] Immediate / Offset`[cite: 35, 39].

### 6.1 Register & Memory-Mapped Address Map
The register file (`REG_FILE.sv`) supports general-purpose storage and memory-mapped I/O endpoints[cite: 42]:
* `R0` – `R11`: General-purpose working registers (`gpr[0:11]`)[cite: 42].
* `12` (`R_PIN_IN`): Read-only register reflecting synchronized external input pad states (`PIN_IN_i`)[cite: 35, 42].
* `13` (`R_PIN_OUT`): Read/Write register driving output pads (`PIN_OUT_o`)[cite: 35, 42].
* `14` (`R_PIN_DIR`): Read/Write register controlling pad direction (`PIN_DIR_o`)[cite: 35, 42].
* `15` (`R_SMU`): Read/Write co-processor data interface register (`SMU_DATA_o` / `SMU_DATA_i`)[cite: 35, 42].

### 6.2 Instruction Opcodes & Decoding

| Mnemonic | Opcode (`[15:12]`) | Description / Behavior |
| :--- | :---: | :--- |
| `MOV` | `4'b0000` | Register move / load (`RESULT_o = SRC1_i`)[cite: 35, 36] |
| `AND` | `4'b0001` | Bitwise AND (`RESULT_o = SRC1_i & SRC2_i`)[cite: 35, 36] |
| `OR` | `4'b0010` | Bitwise OR (`RESULT_o = SRC1_i \| SRC2_i`)[cite: 35, 36] |
| `XOR` | `4'b0011` | Bitwise XOR (`RESULT_o = SRC1_i ^ SRC2_i`)[cite: 35, 36] |
| `SLL` | `4'b0100` | Shift Left Logical (`RESULT_o = SRC1_i << SRC2_i[3:0]`)[cite: 35, 36] |
| `SRL` | `4'b0101` | Shift Right Logical (`RESULT_o = SRC1_i >> SRC2_i[3:0]`)[cite: 35, 36] |
| `ADD` | `4'b0110` | Addition (`RESULT_o = SRC1_i + SRC2_i`)[cite: 35, 36] |
| `SUB` | `4'b0111` | Subtraction (`RESULT_o = SRC1_i - SRC2_i`)[cite: 35, 36] |
| `DELAY` | `4'b1000` | Stall execution for `imm[7:0]` clock cycles[cite: 35, 39] |
| `WEDGE` | `4'b1001` | Wait for target signal edge on specified pin index[cite: 35, 39] |
| `JMP` | `4'b1010` | Unconditional relative branch by signed 8-bit offset[cite: 35, 39] |
| `JNZ` | `4'b1011` | Branch relative if Zero flag is NOT set (`!q_zero_flag`)[cite: 35, 38, 39] |
| `JZ` | `4'b1100` | Branch relative if Zero flag IS set (`q_zero_flag`)[cite: 35, 38, 39] |
| `PUSH` | `4'b1101` | Push `Src1` register value into C2H FIFO queue[cite: 35, 39] |
| `POP` | `4'b1110` | Pop data from H2C FIFO into destination register[cite: 35, 39] |
| `SMU_CMD` | `4'b1111` | Trigger SMU co-processor action via opcode selector[cite: 35, 39] |

---

## 7. Software Toolchain & Verification Workflow

The verification framework uses a custom Python assembler and cycle-accurate golden reference model (`assembler.py`) combined with HDL simulation scoreboards (`ASIC_TB` and `cocotb`)[cite: 35, 47, 50].

### 7.1 Compilation Instructions
1. Author protocol routines in assembly format (`.asm`) inside the `/asm` directory[cite: 35].
2. Compile source files into hex instruction images (`program.hex`) using the assembler script[cite: 35]:
   ```bash
   python scripts/assembler.py <asm_file_name>

### 7.2 Running Simulation
Use (`/tb/asic_tb.sv`) or
   ```bash
   make test
   ```

### Repository Structure
- **asm/**: Example Assembly files for test.
- **macro/**: IHP dual-port SRAM macros (`RM_IHPSG13_2P_512x16_c2_bm_bist`).
- **scripts/**: Python script (`assembler.py`) to compile assembly programs from (..`/asm`), ingest input vectors from (`../sim/h2c.hex`) and build (`../sim/program.hex`), (`../sim/expected_c2h.hex`), (`../sim/expected_pins.hex`), (`../sim/pad_in.hex`).
- **sim/**: Simulation stimulus hex files, test vectors, pad schedules and scoreboard transition outputs.
- **src/**: Core SystemVerilog RTL, blackbox IHP SRAM, Tiny Tapeout physical wrapper, GDS configuration (`config.json`) and PDN setup (`pdn_cfg.tcl`).
- **tb/**: Systemverilog testbench harness (`asic_tb.sv`).
- **test/**: cocotb Python verification drivers (`test.py`), Verilog wrappers (`tb.v`), behavioral SRAM models, and project Makefile configured for the Tiny Tapeout pipeline.