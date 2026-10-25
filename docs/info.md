## How it works

The 16-bit RISC Protocol Emulator is a custom I/O co-processor designed for deterministic, cycle-accurate bit-banging and multi-protocol emulation (SPI, I2C, USB 1.1, CAN, UART, Ethernet PHY). 

It uses a single-cycle Harvard architecture, allowing every instruction—including branches—to execute in exactly one clock cycle. To support physical on-chip SRAM without stalling, it implements a fetch-ahead Program Counter that seamlessly hides the 1-cycle synchronous read latency of the integrated IHP 130nm dual-port SRAM macro (1024x16).

Key architectural features include:
- **Custom State Machine Unit (SMU):** Offloads complex dynamic protocol tasks like USB bit-stuffing or CRC calculation.
- **Stream Interfaces:** H2C (Host-to-Core) and C2H (Core-to-Host) FIFOs for seamless data streaming.
- **Hardware Synchronization:** A dedicated `WEDGE` instruction with 2-FF Clock Domain Crossing (CDC) synchronizers enables cycle-accurate polling of external pin transitions without software loops.
- **Dynamic Bus Turnaround:** Bidirectional pad support mapped to the TinyTapeout `uio` pins for protocols like I2C.

## Instruction Set Architecture (ISA)

The ISA is strictly 16-bit. Every instruction executes in exactly one clock cycle. 

### Register Map
- `R0` - `R7`: General Purpose Registers
- `R_PIN_IN` : Read-only. State of the physical input pins.
- `R_PIN_OUT`: Read/Write. Drives the output pins.
- `R_PIN_DIR`: Read/Write. Direction control (1 = Output, 0 = Input).
- `R_FIFO`   : Read/Write. Data streaming interface.
- `R_SMU`    : Read/Write. SMU co-processor interface.

### ALU Operations
ALU instructions update the Zero Flag (Z), which is registered and used for conditional branching in subsequent cycles.
- `ADD`, `SUB`: Arithmetic operations.
- `AND`, `OR`, `XOR`, `SHL`, `SHR`: Bitwise operations.
- `MOV`: Load immediate or move between registers.

### Control Flow
Branches use the registered Zero Flag from the previous ALU operation.
- `JMP`: Unconditional relative jump.
- `JZ`: Jump if Zero flag is SET.
- `JNZ`: Jump if Zero flag is NOT SET.

### Deterministic Timing and I/O
- `DELAY #cycles`: Stall the CPU for an exact number of clock cycles.
- `WEDGE pin_idx, polarity`: Wait for a synchronized rising (1) or falling (0) edge on a specific pin.

### Co-Processor Instructions
- `PUSH Rs`: Push data into the C2H FIFO.
- `POP Rd`: Pop data from the H2C FIFO into a register.
- `SMU_CMD cmd_id`: Send an execution token to the State Machine Unit.

## How to test

The project includes a custom software toolchain and verification environment. To run a full simulation, you must generate or provide a specific set of `.hex` files in the `/sim` directory.

1. **Assembler:** Use the custom Python assembler located at `scripts/assembler.py` to compile assembly (`.asm`) files into machine-code hex files.
   ```bash
   python scripts/assembler.py [file_name]