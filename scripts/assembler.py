#!/usr/bin/env python3
# Assembler + Cycle-Accurate Golden Reference Model for Protocol Emulator

import sys
import re
from pathlib import Path

# Directory structure (relative to this script)
SCRIPT_DIR       = Path(__file__).resolve().parent
ROOT_DIR         = SCRIPT_DIR.parent
ASM_DIR          = ROOT_DIR / "asm"
SIM_DIR          = ROOT_DIR / "sim"

DEFAULT_PROG_OUT = SIM_DIR / "program.hex"
DEFAULT_H2C_IN   = SIM_DIR / "h2c.hex"
DEFAULT_PIN_IN   = SIM_DIR / "pad_in.hex"
DEFAULT_EXP_PINS = SIM_DIR / "expected_pins.hex"
DEFAULT_EXP_C2H  = SIM_DIR / "expected_c2h.hex"

# Register map
REG_MAP = {f"R{i}": i for i in range(16)}
REG_MAP.update({
    "R_PIN_IN"  : 12,
    "R_PIN_OUT" : 13,
    "R_PIN_DIR" : 14,
    "R_SMU"     : 15
})

# SMU operation map
SMU_OPS = {
    "CLR"       : 0x0,
    "CRC16"     : 0x1,
    "BITREV"    : 0x2,
    "BYTESWAP"  : 0x3,
    "LFSR"      : 0x4,
    "PARITY"    : 0x5,
    "SETPOLY"   : 0x6,
    "SETSEED"   : 0x7
}

# ALU operation map
ALU_OPS = {
    "MOV"   : 0b0000,
    "AND"   : 0b0001,
    "OR"    : 0b0010,
    "XOR"   : 0b0011,
    "SLL"   : 0b0100,
    "SRL"   : 0b0101,
    "ADD"   : 0b0110,
    "SUB"   : 0b0111
}

# Jump operation map
JUMP_OPS = {
    "JMP"   : 0b1010,
    "JNZ"   : 0b1011,
    "JZ"    : 0b1100
}

# Parse registers
def parse_reg(token, line_num):
    t = token.upper()
    if t not in REG_MAP:
        raise ValueError(f"Line {line_num}: Invalid register '{token}'")
    return REG_MAP[t]

# Parse immediates
def parse_int(token, line_num):
    try:
        return int(token, 0)
    except ValueError:
        raise ValueError(f"Line {line_num}: Invalid immediate '{token}'")


# ASSEMBLER
def assemble(asm_lines):
    labels = {}
    cleaned_instrs = []

    pc = 0
    for line_num, raw_line in enumerate(asm_lines, 1):
        line = re.split(r'[;]|//', raw_line)[0].strip()
        if not line:
            continue

        if ':' in line:
            parts               = line.split(':', 1)
            label_name          = parts[0].strip()
            labels[label_name]  = pc
            line                = parts[1].strip()
            if not line:
                continue

        cleaned_instrs.append((pc, line_num, line))
        pc += 1

    machine_code = []
    for pc, line_num, line in cleaned_instrs:
        tokens = [t for t in re.split(r'[,\s]+', line) if t]
        mnem = tokens[0].upper()

        opcode = 0
        dest   = 0
        src1   = 0
        src2   = 0

        if mnem in ALU_OPS:
            opcode = ALU_OPS[mnem]
            dest   = parse_reg(tokens[1], line_num)
            src1   = parse_reg(tokens[2], line_num)
            src2   = parse_reg(tokens[3], line_num) if mnem != "MOV" else 0

        elif mnem == "DELAY":
            opcode = 0b1000
            imm    = parse_int(tokens[1], line_num) & 0xFF
            src1   = (imm >> 4) & 0xF
            src2   = imm & 0xF

        elif mnem == "WEDGE":
            opcode = 0b1001
            dest   = REG_MAP[tokens[1].upper()] if tokens[1].upper() in REG_MAP else parse_int(tokens[1], line_num) & 0xF
            src2   = parse_int(tokens[2], line_num) & 0x1

        elif mnem in JUMP_OPS:
            opcode = JUMP_OPS[mnem]
            target = tokens[1]
            if target in labels:
                offset = labels[target] - pc
            else:
                offset = parse_int(target, line_num)
            if not (-128 <= offset <= 127):
                raise ValueError(f"Line {line_num}: Jump offset {offset} out of 8-bit signed range")
            imm    = offset & 0xFF
            src1   = (imm >> 4) & 0xF
            src2   = imm & 0xF

        elif mnem == "PUSH":
            opcode = 0b1101
            src1   = parse_reg(tokens[1], line_num)

        elif mnem == "POP":
            opcode = 0b1110
            dest   = parse_reg(tokens[1], line_num)

        elif mnem == "SMU_CMD":
            opcode = 0b1111
            op_tok = tokens[1].upper()
            dest   = SMU_OPS[op_tok] if op_tok in SMU_OPS else (parse_int(op_tok, line_num) & 0xF)

        else:
            raise ValueError(f"Line {line_num}: Invalid instruction '{mnem}'")

        word = ((opcode & 0xF) << 12) | ((dest & 0xF) << 8) | ((src1 & 0xF) << 4) | (src2 & 0xF)
        machine_code.append((pc, word, line))

    return machine_code


# ISA EMULATOR
def load_hex_words(filepath: Path):
    if not filepath.is_file():
        return []
    words = []
    with open(filepath, "r") as f:
        for raw in f:
            clean = re.split(r'[;]|//', raw)[0].strip()
            if clean:
                words.append(int(clean.replace("_", ""), 16))
    return words

# Input pad file
def load_pad_in_schedule(filepath: Path, max_cycles=50000):
    """Reads CCCC_VVVV lines from pad_in.hex and builds a cycle-by-cycle dict."""
    words = load_hex_words(filepath)
    if not words:
        return None
    events = {}
    for w in words:
        cyc         = (w >> 16) & 0xFFFF
        val         = w & 0xFFFF
        events[cyc] = val

    schedule = {}
    curr_val = 0x0000
    for c in range(1, max_cycles + 1):
        if c in events:
            curr_val = events[c]
        schedule[c] = curr_val
    return schedule

# Build model
def run_golden_model(machine_code, h2c_words, pad_in_schedule=None, max_cycles=50000):
    imem = {pc: word for pc, word, _ in machine_code}
    h2c_fifo = list(h2c_words)
    c2h_fifo = []

    # Architectural State (matches RTL reset values)
    gpr         = [0x0000] * 12
    pin_out     = 0x0000
    pin_dir     = 0x0000
    smu_data_o  = 0x0000
    smu_acc     = 0x6767  # Default SMU_SEED
    smu_poly    = 0x6767  # Default CRC_POLY
    smu_seed    = 0x6767  # Default SMU_SEED

    pc              = 0
    q_zero_flag     = False
    active_delay    = False
    delay_counter   = 0
    pin_in_prev     = 0x0000
    pin_in_meta     = 0x0000
    pin_in_sync     = 0x0000

    # Pin transition tracking: list of (pad_dir, pad_out, duration_cycles)
    pin_transitions    = []
    prev_logged_dir    = 0x0000
    prev_logged_out    = 0x0000
    last_change_cycle  = 1          # IMPORTANT : IT TAKES 1 CYCLE TO CHANGE STATE IN SIMULATION. IF THIS STARTS AT 0, THE FIRST TEST WILL ALWAYS FAIL WITH A DELTA = 1 CYCLE

    def read_reg(addr, current_pin_in):
        if addr == 0:
            return 0x0000
        elif 1 <= addr <= 11:
            return gpr[addr]
        elif addr == 12:
            return current_pin_in
        elif addr == 13:
            return pin_out
        elif addr == 14:
            return pin_dir
        elif addr == 15:
            return smu_acc
        return 0x0000

    for cycle in range(1, max_cycles + 1):
        # Sample external pad_in for this cycle, while core sees 2-FF synchronized pin_in_sync
        raw_pad_in = pad_in_schedule.get(cycle, 0x0000) if pad_in_schedule else 0x0000
        pin_in     = pin_in_sync

        # Check if PC reached uninitialized IMEM or self-loop Halt (0xA000)
        if pc not in imem:
            break
        instr = imem[pc]
        if instr == 0xA000:
            # In RTL, the testbench checks dut.instr === 16'hA000 on the posedge where PC lands on 0xA000 (alongside any pin change from the previous cycle)
            if (pin_out != prev_logged_out) or (pin_dir != prev_logged_dir):
                pin_transitions.append((pin_dir, pin_out, cycle - last_change_cycle))
            break

        # Decode instruction fields
        opcode   = (instr >> 12) & 0xF
        dest_reg = (instr >> 8)  & 0xF
        src1_reg = (instr >> 4)  & 0xF
        src2_reg = instr & 0xF
        imm8     = instr & 0xFF
        signed_imm8 = imm8 - 256 if (imm8 & 0x80) else imm8

        alu_en        = (opcode & 0b1000) == 0
        alu_op        = opcode & 0b0111
        reg_write_en  = alu_en or (opcode == 0b1110)
        delay_en      = (opcode == 0b1000)
        wait_edge_en  = (opcode == 0b1001)
        jmp_en        = opcode in (0b1010, 0b1011, 0b1100)
        fifo_push     = (opcode == 0b1101)
        fifo_pop      = (opcode == 0b1110)
        smu_cmd_en    = (opcode == 0b1111)

        # Combinational Read & ALU Execution
        rd1 = read_reg(src1_reg, pin_in)
        rd2 = read_reg(src2_reg, pin_in)

        if alu_op == 0b000:   alu_res = rd1
        elif alu_op == 0b001: alu_res = rd1 & rd2
        elif alu_op == 0b010: alu_res = rd1 | rd2
        elif alu_op == 0b011: alu_res = rd1 ^ rd2
        elif alu_op == 0b100: alu_res = (rd1 << (rd2 & 0xF)) & 0xFFFF
        elif alu_op == 0b101: alu_res = (rd1 >> (rd2 & 0xF)) & 0xFFFF
        elif alu_op == 0b110: alu_res = (rd1 + rd2) & 0xFFFF
        elif alu_op == 0b111: alu_res = (rd1 - rd2) & 0xFFFF
        else:                 alu_res = 0x0000

        zero_flag = (alu_res == 0)

        # Combinational Timing Controller (STALL_o)
        if src2_reg & 0x1:
            edge_detected = (((~pin_in_prev) >> dest_reg) & (pin_in >> dest_reg)) & 0x1
        else:
            edge_detected = ((pin_in_prev >> dest_reg) & ((~pin_in) >> dest_reg)) & 0x1

        stall = False
        if delay_en and (imm8 > 0):
            stall = (imm8 > 1) if not active_delay else (delay_counter > 1)
        elif wait_edge_en:
            stall = not bool(edge_detected)

        # Monitor Check (Happens at posedge clk before sequential state updates)
        if (pin_out != prev_logged_out) or (pin_dir != prev_logged_dir):
            pin_transitions.append((pin_dir, pin_out, cycle - last_change_cycle))
            prev_logged_out   = pin_out
            prev_logged_dir   = pin_dir
            last_change_cycle = cycle

        # Sequential State Updates (At posedge clk)
        # Write-back MUX
        fifo_head = h2c_fifo[0] if h2c_fifo else 0x0000
        reg_write_data = fifo_head if fifo_pop else alu_res

        # FIFO Push / Pop
        if fifo_push:
            c2h_fifo.append(rd1)
        if fifo_pop and h2c_fifo:
            h2c_fifo.pop(0)

        # SMU Sequential Update (Uses current cycle's smu_data_o register)
        next_smu_acc  = smu_acc
        next_smu_poly = smu_poly
        next_smu_seed = smu_seed
        if smu_cmd_en:
            if dest_reg == 0x0:   # CLR
                next_smu_acc = 0xFFFF
            elif dest_reg == 0x1: # CRC16
                c = smu_acc ^ smu_data_o
                for _ in range(16):
                    c = ((c << 1) ^ smu_poly) & 0xFFFF if (c & 0x8000) else (c << 1) & 0xFFFF
                next_smu_acc = c
            elif dest_reg == 0x2: # BITREV
                b = 0
                for i in range(16):
                    if (smu_data_o >> i) & 1:
                        b |= (1 << (15 - i))
                next_smu_acc = b
            elif dest_reg == 0x3: # BYTESWAP
                next_smu_acc = ((smu_data_o & 0xFF) << 8) | ((smu_data_o >> 8) & 0xFF)
            elif dest_reg == 0x4: # LFSR
                fb = bin(smu_acc & smu_poly).count("1") & 1
                next_smu_acc = ((smu_acc << 1) | fb) & 0xFFFF
            elif dest_reg == 0x5: # PARITY
                next_smu_acc = bin(smu_data_o).count("1") & 1
            elif dest_reg == 0x6: # SETPOLY
                next_smu_poly = smu_data_o
            elif dest_reg == 0x7: # SETSEED
                next_smu_seed = smu_data_o
                next_smu_acc  = smu_data_o

        # Register File Sequential Update
        if reg_write_en:
            if 1 <= dest_reg <= 11:
                gpr[dest_reg] = reg_write_data
            elif dest_reg == 13:
                pin_out = reg_write_data
            elif dest_reg == 14:
                pin_dir = reg_write_data
            elif dest_reg == 15:
                smu_data_o = reg_write_data

        smu_acc  = next_smu_acc
        smu_poly = next_smu_poly
        smu_seed = next_smu_seed

        # Timing Controller Sequential Update
        # Timing Controller & 2-FF Synchronizer Sequential Update
        pin_in_prev = pin_in_sync
        pin_in_sync = pin_in_meta
        pin_in_meta = raw_pad_in        
        
        if delay_en and (imm8 > 1):
            if not active_delay:
                active_delay  = True
                delay_counter = imm8 - 1
            elif delay_counter > 1:
                delay_counter -= 1
            else:
                active_delay  = False
                delay_counter = 0
        else:
            active_delay  = False
            delay_counter = 0

        # Program Counter & Flags Sequential Update
        if not stall:
            branch_taken = False
            if jmp_en:
                if opcode == 0b1010:   branch_taken = True
                elif opcode == 0b1011: branch_taken = not q_zero_flag
                elif opcode == 0b1100: branch_taken = q_zero_flag
            pc = (pc + signed_imm8) & 0xFFFF if branch_taken else (pc + 1) & 0xFFFF

            if alu_en:
                q_zero_flag = zero_flag

    return pin_transitions, c2h_fifo

def resolve_input_file(arg_path: str) -> Path:
    cand = Path(arg_path)
    if cand.is_file():
        return cand.resolve()
    in_asm = ASM_DIR / cand
    if in_asm.is_file():
        return in_asm.resolve()
    if cand.suffix == "":
        with_ext = ASM_DIR / f"{cand.name}.asm"
        if with_ext.is_file():
            return with_ext.resolve()
    raise FileNotFoundError(f"Could not find assembly file '{arg_path}' (searched current dir and {ASM_DIR})")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/assembler.py <asm_file>")
        sys.exit(1)

    in_path = resolve_input_file(sys.argv[1])
    SIM_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Assembling : {in_path}")
    with open(in_path, "r") as f:
        code = assemble(f.readlines())

    with open(DEFAULT_PROG_OUT, "w") as f:
        for pc, word, src in code:
            f.write(f"{word:04X} // PC={pc:04d}: {src}\n")
            print(f"    [0x{pc:04X}] 0x{word:04X} : {src}")

    # Run Golden Reference Model to generate Scoreboard expectation files
    h2c_words           = load_hex_words(DEFAULT_H2C_IN)
    pad_schedule        = load_pad_in_schedule(DEFAULT_PIN_IN)
    exp_pins, exp_c2h   = run_golden_model(code, h2c_words, pad_schedule)

    with open(DEFAULT_EXP_PINS, "w") as f:
        for idx, (p_dir, p_out, cyc) in enumerate(exp_pins):
            # 48-bit hex format: DDDD_OOOO_CCCC (DIR, OUT, CYCLES)
            f.write(f"{p_dir:04X}_{p_out:04X}_{cyc:04X} // Transition {idx}: DIR = 0x{p_dir:04X}, OUT = 0x{p_out:04X}, DeltaCycles = {cyc}\n")

    with open(DEFAULT_EXP_C2H, "w") as f:
        for idx, val in enumerate(exp_c2h):
            f.write(f"{val:04X} // C2H[{idx}]\n")

    print(f"\nGenerating expected files (using {len(h2c_words)} H2C input word(s)):")
    print(f"    Wrote {len(exp_pins)} pin transitions to {DEFAULT_EXP_PINS.name}")
    for idx, (p_dir, p_out, cyc) in enumerate(exp_pins):
        print(f"        #{idx}: PAD_DIR = 0x{p_dir:04X} | PAD_OUT = 0x{p_out:04X} | Delta = {cyc} cycles")
    print(f"    Wrote {len(exp_c2h)} C2H FIFO words to {DEFAULT_EXP_C2H.name}")