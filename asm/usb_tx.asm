// ============================================================================
// Protocol Test: USB 1.1 NRZI Packet Transmitter (SYNC + Bit-Stuffed Data + CRC16 + EOP)
// Pin Mapping on PAD_OUT_o:
//   Bit 0 (0x0001) : USB D+  (J state = 0x0001)
//   Bit 1 (0x0002) : USB D-  (K state = 0x0002)
//   0x0000         : USB SE0 (Single-Ended Zero for EOP)
// ============================================================================

    // --- 1. Bootstrap Constants (1, 2, 3, 6, 16) ---
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    SMU_CMD LFSR                // R_SMU <= 0xFFFE
    MOV     R_SMU, R_SMU        // Latch 0xFFFE
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 0x0001 (Constant 1 / USB 'J' state)
    ADD     R2, R1, R1          // R2 = 0x0002 (Constant 2 / USB 'K' state)
    OR      R3, R1, R2          // R3 = 0x0003 (J <-> K toggle mask: 1 ^ 3 = 2, 2 ^ 3 = 1)
    ADD     R4, R2, R2          // R4 = 4
    ADD     R6, R4, R2          // R6 = 6 (USB Bit-Stuff threshold = 6 consecutive '1's)
    SLL     R4, R1, R4          // R4 = 16 (16-bit payload counter)

    // --- 2. Configure D+ and D- as Outputs & Drive Bus Idle ('J' = 0x0001) ---
    MOV     R_PIN_DIR, R3       // DIR <= 0x0003 (Pins 0 & 1 = Outputs)
    MOV     R8, R1              // R8 = Current NRZI bus state (starts at 'J' = 0x0001)
    MOV     R_PIN_OUT, R8       // Drive USB Idle ('J')
    DELAY   4                   // Idle hold time

    // --- 3. Pop USB Polynomial & Data Payload, Compute USB CRC-16 ---
    POP     R5                  // Pop H2C[0] (e.g., 0x6767 or 0x8005 USB Poly)
    MOV     R_SMU, R5           // Load custom polynomial into SMU
    SMU_CMD SETPOLY             // poly_reg <= H2C[0]

    POP     R5                  // Pop H2C[1] (16-bit USB Data Payload to transmit)
    SMU_CMD CLR                 // Seed CRC accumulator to 0xFFFF
    MOV     R_SMU, R5           // Load payload into SMU
    SMU_CMD CRC16               // Compute USB CRC-16 over payload
    PUSH    R_SMU               // Push USB CRC-16 to C2H_FIFO[0]

    // --- 4. Transmit USB SYNC Field (K-J-K-J-K-J-K-K) ---
    MOV     R7, R6              // R7 = 6 toggles (K-J-K-J-K-J)
sync_loop:
    XOR     R8, R8, R3          // Toggle NRZI state (J <-> K) for '0' bit
    MOV     R_PIN_OUT, R8       // Drive D+/D-
    DELAY   3                   // 1 USB bit period
    SUB     R7, R7, R1          // Decrement SYNC counter
    JNZ     sync_loop

    XOR     R8, R8, R3          // Final '0' toggle to 'K'
    MOV     R_PIN_OUT, R8       // Drive 'K'
    DELAY   8                   // Hold 'K' for 2 bit times (final '0' + '1' of SYNC)

    // --- 5. Transmit 16-Bit Payload (LSB-First NRZI + Dynamic Bit-Stuffing) ---
    MOV     R9, R0              // R9 = Consecutive '1's counter (starts at 0)
usb_bit_loop:
    AND     R10, R5, R1         // Extract LSB (R5 & 1)
    JZ      nrzi_zero           // If bit == 0, branch to toggle bus

nrzi_one:                       // Bit == 1: Hold current NRZI state, increment 1s counter
    MOV     R_PIN_OUT, R8       // Keep current D+/D- state
    DELAY   3                   // Hold for bit period
    ADD     R9, R9, R1          // R9 <= R9 + 1 (Increment consecutive '1's count)
    SUB     R11, R9, R6         // Check if R9 == 6 (sets q_zero_flag if 6 ones reached!)
    JNZ     next_usb_bit        // If < 6 ones, continue normally

    // --- BIT STUFFING TRIGGERED! Insert forced '0' toggle ---
    XOR     R8, R8, R3          // Toggle bus state (forced '0' bit)
    MOV     R_PIN_OUT, R8       // Drive stuffed transition onto D+/D-
    DELAY   5                   // Hold stuffed bit for 1 USB bit period
    MOV     R9, R0              // Reset consecutive '1's counter to 0
    JMP     next_usb_bit

nrzi_zero:                      // Bit == 0: Toggle NRZI state (J <-> K), reset 1s counter
    XOR     R8, R8, R3          // Toggle J <-> K
    MOV     R_PIN_OUT, R8       // Drive toggled state onto D+/D-
    DELAY   4                   // Hold for bit period
    MOV     R9, R0              // Reset consecutive '1's counter to 0

next_usb_bit:
    SRL     R5, R5, R1          // Shift next payload bit into LSB
    SUB     R4, R4, R1          // Decrement 16-bit counter
    JNZ     usb_bit_loop

    // --- 6. Transmit USB End-of-Packet (EOP: 2-Bit SE0 + 1-Bit J) ---
    MOV     R_PIN_OUT, R0       // Drive SE0 (D+ = 0, D- = 0)
    DELAY   10                  // Hold SE0 for 2 USB bit times
    MOV     R_PIN_OUT, R1       // Drive 'J' (D+ = 1, D- = 0) for 1 bit time
    DELAY   5                   // Hold 'J' idle state

halt_loop:
    JMP     halt_loop           // Halt