# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

# Port assignments.
SPI_SCK_BIT  = 0
SPI_MOSI_BIT = 1
SPI_CS_N_BIT = 2
SPI_MISO_BIT = 0

def resolve_int(val):
    try:
        return int(val)
    except ValueError:
        # Sanitize high-impedance and unknown states.
        safe_str = str(val).lower().replace('x', '0').replace('z', '0')
        return int(safe_str, 2)

def get_pad_out(dut):
    # Map output vectors.
    uio_out = resolve_int(dut.uio_out.value)
    uo_out  = resolve_int(dut.uo_out.value)
    return (uio_out & 0xFF) | ((uo_out >> 1) << 8)

def get_pad_dir(dut):
    # Map direction vectors.
    uio_oe = resolve_int(dut.uio_oe.value)
    return (uio_oe & 0xFF) | 0x7F00

def set_pad_in(dut, val):
    # Map input vectors.
    dut.uio_in.value = val & 0xFF
    current_ui = resolve_int(dut.ui_in.value)
    new_ui = (current_ui & 0x07) | (((val >> 8) & 0x1F) << 3)
    dut.ui_in.value = new_ui

# File parsing subroutines.
def get_sim_path(filename):
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "sim", filename))

def load_hex_words(filename):
    words = []
    path = get_sim_path(filename)
    if not os.path.exists(path):
        return words
    with open(path, "r") as f:
        for line in f:
            clean = line.split("//")[0].strip()
            if clean and "x" not in clean.lower():
                words.append(int(clean.replace("_", ""), 16))
    return words

def load_expected_pins(filename):
    pins = []
    path = get_sim_path(filename)
    if not os.path.exists(path):
        return pins
    with open(path, "r") as f:
        for line in f:
            clean = line.split("//")[0].strip()
            if clean and "x" not in clean.lower():
                chunks = clean.split("_")
                if len(chunks) == 3:
                    pins.append((int(chunks[0], 16), int(chunks[1], 16), int(chunks[2], 16)))
    return pins

def load_pad_in_schedule(filename):
    schedule = {}
    path = get_sim_path(filename)
    if not os.path.exists(path):
        return schedule
    with open(path, "r") as f:
        for line in f:
            clean = line.split("//")[0].strip()
            if clean and "x" not in clean.lower():
                val32 = int(clean.replace("_", ""), 16)
                schedule[(val32 >> 16) & 0xFFFF] = val32 & 0xFFFF
    return schedule

# SPI master interface.
async def spi_transfer(dut, cmd, addr, data_in):
    frame = (cmd << 32) | (addr << 16) | data_in
    miso_capture = 0

    await RisingEdge(dut.clk)
    
    # Delta cycle state tracking.
    ui_shadow = resolve_int(dut.ui_in.value)
    
    ui_shadow &= ~(1 << SPI_CS_N_BIT)
    dut.ui_in.value = ui_shadow
    await Timer(50, units="ns")

    for b in range(39, -1, -1):
        if (frame >> b) & 1:
            ui_shadow |= (1 << SPI_MOSI_BIT)
        else:
            ui_shadow &= ~(1 << SPI_MOSI_BIT)
        
        dut.ui_in.value = ui_shadow
        await Timer(50, units="ns")
        
        ui_shadow |= (1 << SPI_SCK_BIT)
        dut.ui_in.value = ui_shadow

        if b < 16:
            miso_bit = (resolve_int(dut.uo_out.value) >> SPI_MISO_BIT) & 1
            miso_capture |= (miso_bit << b)

        await Timer(50, units="ns")
        
        ui_shadow &= ~(1 << SPI_SCK_BIT)
        dut.ui_in.value = ui_shadow

    await Timer(50, units="ns")
    ui_shadow |= (1 << SPI_CS_N_BIT)
    dut.ui_in.value = ui_shadow
    
    for _ in range(5):
        await RisingEdge(dut.clk)

    return miso_capture

# Event monitoring.
async def pin_transition_monitor(dut, exp_pins, pad_schedule, stats):
    cycle = 0
    last_change = 0
    
    await Timer(1, units="ns")
    prev_out = get_pad_out(dut)
    prev_dir = get_pad_dir(dut)

    while True:
        await RisingEdge(dut.clk)
        cycle += 1

        if cycle in pad_schedule:
            set_pad_in(dut, pad_schedule[cycle])

        cur_out = get_pad_out(dut)
        cur_dir = get_pad_dir(dut)

        if cur_out != prev_out or cur_dir != prev_dir:
            delta = cycle - last_change
            
            if stats["pin_check_idx"] >= len(exp_pins):
                dut._log.error(f"Unexpected transition. DIR: 0x{cur_dir:04X}, OUT: 0x{cur_out:04X}, Delta: {delta}.")
                stats["errors"] += 1
            else:
                exp_dir, exp_out, exp_delta = exp_pins[stats["pin_check_idx"]]
                if cur_dir != exp_dir or cur_out != exp_out or delta != exp_delta:
                    dut._log.error(f"Transition {stats['pin_check_idx']} mismatch. Expected: (DIR: 0x{exp_dir:04X}, OUT: 0x{exp_out:04X}, Delta: {exp_delta}), Detected: (DIR: 0x{cur_dir:04X}, OUT: 0x{cur_out:04X}, Delta: {delta}).")
                    stats["errors"] += 1
                else:
                    dut._log.info(f"Transition {stats['pin_check_idx']} verified. DIR: 0x{cur_dir:04X}, OUT: 0x{cur_out:04X}, Delta: {delta}.")

            stats["pin_check_idx"] += 1
            prev_out = cur_out
            prev_dir = cur_dir
            last_change = cycle

# Execution framework.
@cocotb.test()
async def test_project(dut):
    dut._log.info("Initialization sequence started.")

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ui_in.value = resolve_int(dut.ui_in.value) | (1 << SPI_CS_N_BIT)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    prog_words   = load_hex_words("program.hex")
    h2c_words    = load_hex_words("h2c.hex")
    exp_pins     = load_expected_pins("expected_pins.hex")
    exp_c2h      = load_hex_words("expected_c2h.hex")
    pad_schedule = load_pad_in_schedule("pad_in.hex")
    
    dut._log.info(f"Loaded {len(prog_words)} instructions, {len(exp_pins)} transitions.")

    await spi_transfer(dut, 0x00, 0, 0)
    for pc_idx, instr in enumerate(prog_words):
        await spi_transfer(dut, 0x02, pc_idx, instr)

    for word in h2c_words:
        await spi_transfer(dut, 0x03, 0, word)

    stats = {"pin_check_idx": 0, "errors": 0}
    cocotb.start_soon(pin_transition_monitor(dut, exp_pins, pad_schedule, stats))

    dut._log.info("Execution sequence started.")
    await spi_transfer(dut, 0x01, 0, 0)

    MAX_CYCLES = 50000
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if len(exp_pins) > 0 and stats["pin_check_idx"] >= len(exp_pins):
            break
            
    await ClockCycles(dut.clk, 100)
    
    if stats["pin_check_idx"] < len(exp_pins):
        dut._log.error(f"Timeout detected. Transitions completed: {stats['pin_check_idx']}/{len(exp_pins)}.")
        stats["errors"] += 1

    await spi_transfer(dut, 0x00, 0, 0)
    
    dut._log.info("C2H FIFO verification sequence.")
    idx = 0
    safety_limit = len(exp_c2h) + 10 # Infinite loop mitigation.
    
    while True:
        status_word = await spi_transfer(dut, 0x05, 0, 0)
        if status_word & 1:
            break

        c2h_word = await spi_transfer(dut, 0x04, 0, 0)
        if idx >= len(exp_c2h):
            dut._log.error(f"C2H[{idx}] anomaly: 0x{c2h_word:04X}.")
            stats["errors"] += 1
            break # Halt on anomaly.
            
        elif c2h_word != exp_c2h[idx]:
            dut._log.error(f"C2H[{idx}] mismatch. Expected: 0x{exp_c2h[idx]:04X}, Detected: 0x{c2h_word:04X}.")
            stats["errors"] += 1
        else:
            dut._log.info(f"C2H[{idx}] verified: 0x{c2h_word:04X}.")
        
        idx += 1
        
        if idx > safety_limit:
            dut._log.error("Safety limit exceeded. FIFO not empty.")
            stats["errors"] += 1
            break

    if idx != len(exp_c2h):
        dut._log.error(f"C2H length mismatch. Expected: {len(exp_c2h)}, Detected: {idx}.")
        stats["errors"] += 1

    assert stats["errors"] == 0, f"Verification failed. Errors detected: {stats['errors']}."
    dut._log.info("Verification successful.")