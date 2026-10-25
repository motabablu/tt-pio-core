// ============================================================================
// Protocol Test: JTAG TAP Master Controller (Shift-IR sequence)
// ============================================================================

    // Bootstrap Constants
    SMU_CMD CLR
    SMU_CMD LFSR
    MOV     R_SMU, R_SMU
    SMU_CMD PARITY              // R_SMU <= 0x0001
    MOV     R1, R_SMU           // R1 = 0x0001 (TCK)
    ADD     R2, R1, R1          // R2 = 0x0002 (TMS)
    ADD     R3, R2, R2          // R3 = 0x0004 (TDI)
    ADD     R4, R3, R3          // R4 = 0x0008 (TDO mask)
    
    OR      R5, R1, R2          
    OR      R5, R5, R3          // R5 = 0x0007 (Outputs: TCK, TMS, TDI)
    MOV     R_PIN_DIR, R5       // Set Pins 0, 1, 2 as outputs, Pin 3 as input

    // TAP Reset Sequence (5 consecutive TMS = 1) 
    // Drive TM S= 1 (0x0002), TCK = 0
    MOV     R_PIN_OUT, R2       // TMS = 1, TCK = 0
    
    // Cycle 1 to 5: TCK High then Low while holding TMS = 1
    OR      R6, R2, R1          // R6 = 0x0003 (TMS = 1, TCK = 1)
    
    // Unrolled TAP Reset for deterministic execution
    MOV     R_PIN_OUT, R6       // TCK = 1 (1)
    MOV     R_PIN_OUT, R2       // TCK = 0
    MOV     R_PIN_OUT, R6       // TCK = 1 (2)
    MOV     R_PIN_OUT, R2       // TCK = 0
    MOV     R_PIN_OUT, R6       // TCK = 1 (3)
    MOV     R_PIN_OUT, R2       // TCK = 0
    MOV     R_PIN_OUT, R6       // TCK = 1 (4)
    MOV     R_PIN_OUT, R2       // TCK = 0
    MOV     R_PIN_OUT, R6       // TCK = 1 (5)
    MOV     R_PIN_OUT, R2       // TCK = 0 - TAP is now in Test-Logic-Reset

    // Navigate to Shift-IR (TMS sequence: 0, 1, 1, 0, 0)
    MOV     R_PIN_OUT, R0       // TMS = 0, TCK = 0 (Run-Test/Idle)
    MOV     R_PIN_OUT, R1       // TCK = 1
    MOV     R_PIN_OUT, R2       // TMS = 1, TCK = 0 (Select-DR-Scan)
    MOV     R_PIN_OUT, R6       // TCK = 1
    MOV     R_PIN_OUT, R2       // TMS = 1, TCK = 0 (Select-IR-Scan)
    MOV     R_PIN_OUT, R6       // TCK = 1
    MOV     R_PIN_OUT, R0       // TMS = 0, TCK = 0 (Capture-IR)
    MOV     R_PIN_OUT, R1       // TCK = 1
    MOV     R_PIN_OUT, R0       // TMS = 0, TCK = 0 (Shift-IR)
    MOV     R_PIN_OUT, R1       // TCK = 1
    
    // 4. Shift 4-bit Instruction (Pop from H2C)
    POP     R7                  // H2C[0] contains 4-bit instruction
    MOV     R_PIN_OUT, R0       // TCK = 0
    
    // R8 = 4 (Loop Counter)
    MOV     R8, R3

jtag_shift_loop:
    AND     R9, R7, R1          // Isolate LSB (TDI data)
    // Shift TDI bit into correct position (Pin 2 = R3 = 4)
    SLL     R9, R9, R2          // Shift left by 2 to align with TDI (0x0004)
    
    // Check if final bit to drive TMS=1 to exit shift state
    SUB     R10, R8, R1         // If counter == 1, set zero flag
    JNZ     drive_tdi
    OR      R9, R9, R2          // Final bit: assert TMS=1 (0x0002) to enter Exit1-IR
    
drive_tdi:
    MOV     R_PIN_OUT, R9       // Drive TDI (and TMS if last bit), TCK=0
    OR      R10, R9, R1         // TCK=1
    MOV     R_PIN_OUT, R10      // Assert TCK
    
    // Sample TDO on rising edge
    MOV     R11, R_PIN_IN       
    
    MOV     R_PIN_OUT, R9       // Deassert TCK
    SRL     R7, R7, R1          // Shift next instruction bit
    SUB     R8, R8, R1          // Decrement counter
    JNZ     jtag_shift_loop

halt_loop:
    JMP     halt_loop