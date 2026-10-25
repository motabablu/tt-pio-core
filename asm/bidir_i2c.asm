// ============================================================================
// Bidirectional Protocol Test: Shared-Wire Bus Turnaround (I2C / MDIO Style)
//   Pin 0 (0x0001) : Bidirectional SDA (Output during TX, Input during RX)
//   Pin 1 (0x0002) : Output SCL (Clock driven by ASIC)
// ============================================================================

    // --- 1. Bootstrap Constants (1, 2, 3, 4) ---
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    SMU_CMD LFSR                // R_SMU <= 0xFFFE
    MOV     R_SMU, R_SMU        // Latch 0xFFFE
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 0x0001 (SDA mask / Constant 1)
    ADD     R2, R1, R1          // R2 = 0x0002 (SCL mask / RX-mode DIR mask)
    OR      R3, R1, R2          // R3 = 0x0003 (TX-mode DIR mask: SCL+SDA outputs)
    ADD     R4, R2, R2          // R4 = 4 (4-bit TX counter)

    // --- 2. Bus Idle & START Condition (SDA falls while SCL is High) ---
    MOV     R_PIN_DIR, R3       // DIR <= 0x0003 (Both SCL and SDA are outputs)
    MOV     R_PIN_OUT, R3       // Idle: SCL=1, SDA=1 (0x0003)
    DELAY   2
    MOV     R_PIN_OUT, R2       // START: SCL=1, SDA=0 (0x0002)
    DELAY   2
    MOV     R_PIN_OUT, R0       // Pull SCL=0, SDA=0 (0x0000)

    // --- 3. Transmit 4 Bits on SDA (LSB-First from H2C[0]) ---
    POP     R5                  // Pop H2C[0] (0x6767 -> lower nibble 0b0111)
tx_loop:
    AND     R6, R5, R1          // Isolate LSB onto SDA (Bit 0)
    MOV     R_PIN_OUT, R6       // Drive SDA (SCL=0)
    OR      R7, R6, R2          // Combine SDA with SCL=1
    MOV     R_PIN_OUT, R7       // Rising edge of SCL
    DELAY   2
    MOV     R_PIN_OUT, R6       // Falling edge of SCL
    SRL     R5, R5, R1          // Shift next TX bit
    SUB     R4, R4, R1          // Decrement TX counter
    JNZ     tx_loop

    // --- 4. BUS TURNAROUND: Release SDA (Pin 0 -> Input, Pin 1 -> Output) ---
    MOV     R_PIN_OUT, R0       // Clear output latches
    MOV     R_PIN_DIR, R2       // DIR <= 0x0002 (SCL=Output, SDA=Input!)
    ADD     R4, R2, R2          // R4 = 4 (4-bit RX counter)
    MOV     R8, R0              // R8 = 0 (Clear RX shift register)

    // --- 5. Clock SCL & Sample Incoming Bits on Shared Pin 0 (SDA) ---
rx_loop:
    DELAY   2                   // Slave data setup time
    MOV     R_PIN_OUT, R2       // Drive SCL High (0x0002)
    DELAY   2                   // Allow 2-FF sync / Slave hold time
    MOV     R6, R_PIN_IN        // Sample shared Pin 0 (SDA)
    AND     R6, R6, R1          // Mask Pin 0 (R6 & 1)
    SLL     R8, R8, R1          // Shift RX register left by 1
    OR      R8, R8, R6          // Merge sampled bit
    MOV     R_PIN_OUT, R0       // Drive SCL Low (0x0000)
    SUB     R4, R4, R1          // Decrement RX counter
    JNZ     rx_loop

    PUSH    R8                  // Push received 4-bit nibble to C2H_FIFO[0]

    // --- 6. Reclaim Bus & Issue STOP Condition (SDA rises while SCL High) ---
    MOV     R_PIN_DIR, R3       // DIR <= 0x0003 (Reclaim SDA as Output!)
    MOV     R_PIN_OUT, R2       // Drive SCL=1, SDA=0 (0x0002)
    DELAY   2
    MOV     R_PIN_OUT, R3       // STOP: SCL=1, SDA=1 (0x0003)
    DELAY   2

halt_loop:
    JMP     halt_loop           // Halt