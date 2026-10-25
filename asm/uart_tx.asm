// ============================================================================
// Outbound Protocol Test: Asynchronous UART 8E1 Transmitter (Start + 8 Data + Parity + Stop)
// Pin Mapping on PAD_OUT_o:
//   Bit 0 (0x0001) : UART_TX (Idle High)
// ============================================================================

    // Configure Pin Direction & Bootstrap Constants
    SMU_CMD CLR                 // R_SMU <= 0xFFFF
    MOV     R_PIN_DIR, R_SMU    // Set all pins as outputs (0xFFFF)

    SMU_CMD LFSR                // R_SMU <= 0xFFFE (odd parity)
    MOV     R_SMU, R_SMU        // Latch 0xFFFE into SMU input
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 1 (Constant 1 / Bit mask)
    ADD     R2, R1, R1          // R2 = 2
    ADD     R2, R2, R1          // R2 = 3
    SLL     R3, R1, R2          // R3 = 1 << 3 = 8 (8 data bits per UART frame)

    SLL     R6, R1, R3          // R6 = 1 << 8 = 0x0100
    SUB     R6, R6, R1          // R6 = 0x00FF (8-bit byte mask)

    // UART Idle State (TX High = 0x0001)
    MOV     R_PIN_OUT, R1       // UART_TX <= 1 (Idle)
    DELAY   8                   // Hold idle state before frame

    // Pop Payload Word & Compute 8-Bit Hardware Parity
    POP     R4                  // R4 <= Payload word from H2C FIFO (e.g., 0x6767)
    AND     R5, R4, R6          // R5 <= Lower byte (R4 & 0x00FF = 0x0067)
    MOV     R_SMU, R5           // Load lower byte into SMU
    SMU_CMD PARITY              // R_SMU <= Even parity bit of lower byte
    MOV     R7, R_SMU           // R7 <= Saved parity bit for end of frame
    PUSH    R7                  // Push parity bit to C2H FIFO for verification

    // Transmit Start Bit (TX Low = 0x0000)
    MOV     R_PIN_OUT, R0       // UART_TX <= 0 (Start Bit)
    DELAY   5                   // Hold for 1 baud period

    // Transmit 8 Data Bits (LSB First)
uart_bit_loop:
    AND     R8, R5, R1          // R8 = Current LSB (R5 & 1)
    MOV     R_PIN_OUT, R8       // Drive data bit onto UART_TX
    DELAY   4                   // Baud delay (tuned so loop overhead + delay = constant bit period)
    SRL     R5, R5, R1          // Shift next bit into LSB (R5 >>= 1)
    SUB     R3, R3, R1          // Decrement bit counter (R3 -= 1)
    JNZ     uart_bit_loop       // Loop for all 8 bits

    // Transmit Parity Bit
    MOV     R_PIN_OUT, R7       // Drive hardware parity bit onto UART_TX
    DELAY   7                   // Hold for 1 baud period

    // Transmit Stop Bit (TX High = 0x0001)
    MOV     R_PIN_OUT, R1       // UART_TX <= 1 (Stop Bit / Return to Idle)
    DELAY   8                   // Hold stop bit

halt_loop:
    JMP     halt_loop           // Halt