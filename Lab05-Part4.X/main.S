// Luke Kloer
// RCET 3373
// Lab 5 Interrupt Service Routines
// git url is : https://github.com/lukekloer55-prog/Lab05-Pic

; CONFIG1
CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

; Config statements should precede project file includes.
#include <xc.inc>
    
    W_temp EQU 0x20
    Status_temp EQU 0x21
    SixCountLast EQU 0x22
    TwoSecDelaySevenValue EQU 0x23
    SixCountValue EQU 0x25
    InnerCountSix EQU 0x26
    OuterCountSix EQU 0x27
    TwoSecDelaySixValue EQU 0x28
    InnerCountSeven EQU 0x30
    OuterCountSeven EQU 0x31
    W_temp2 EQU 0x32
    Status_temp2 EQU 0x33
    
    
        
; Reset Vector at 0000h. Execution starts here after reset.
 PSECT resetVect,class=CODE,delta=2
 ResetVector:
    GOTO Setup
    
; --- Interrupt Vector --- at addess 0004h so add -pisrVect=04h to assembler options
PSECT isrVect,class=CODE,delta=2
    GOTO ISRHandler
    

    
; Main Code section starts at 0008h. User code goes here.
PSECT code,class=CODE,delta=2

; Add device setup here
Setup:
    ;Setup PORTA for digital output.
    BANKSEL ANSEL              ;Select the bank containing ANSEL.
    CLRF ANSEL                 ;Disable the analog inputs controlled by ANSEL.
    BANKSEL TRISA              ;Select the bank containing TRISA.
    CLRF TRISA                 ;Set all TRISA direction bits for output.
    BANKSEL PORTA              ;Select Bank 0 to access PORTA.
    CLRF PORTA                 ;Clear the PORTA output latch.

    ;Set the PORTB output latch and disable CCP1.
    BCF 0x03,5                 ;Select Bank 0 with the following instruction.
    BCF 0x03,6
    MOVLW 0xFF                 ;Load W with all bits high.
    MOVWF 0x06                 ;Set all PORTB output latch bits high.
    CLRF 0x17                  ;Clear CCP1CON to disable CCP1.

    ;Setup PORTB for input.
    BSF 0x03,5                 ;Select Bank 1 with the following instruction.
    BCF 0x03,6
    MOVLW 0xFF                 ;Load W with all bits high.
    MOVWF 0x86                 ;Set all PORTB pins as inputs.

    ;Set the specified register bit in Bank 2.
    BCF 0x03,5                 ;Select Bank 2 with the following instruction.
    BSF 0x03,6
    BSF 0x09,1                 ;Set bit 1 of register 0x09 in Bank 2.

    ;Disable the remaining analog inputs.
    BSF 0x03,5                 ;Select Bank 3 with the following instruction.
    BSF 0x03,6
    CLRF 0x89                  ;Clear ANSELH to enable digital input on these pins.

    ;Select the falling edge for the RB0 external interrupt.
    BANKSEL OPTION_REG        ;Select the bank containing OPTION_REG.
    BCF OPTION_REG,6           ;Trigger the RB0 interrupt on a falling edge.

    ;Clear the output latch bits for RB0 and RB1.
    Banksel PORTB              ;Select Bank 0 to access PORTB.
    BCF PORTB,0                ;Clear the RB0 output latch bit.
    BCF PORTB,1                ;Clear the RB1 output latch bit.

    ;Enable interrupt-on-change for RB1.
    Banksel IOCB               ;Select the bank containing IOCB.
    BSF IOCB,1                 ;Enable interrupt-on-change on RB1.

    ;Setup PORTC for output and clear its output latch.
    BANKSEL TRISC              ;Select the bank containing TRISC.
    CLRF TRISC                 ;Set all PORTC pins as outputs.
    Banksel PORTC              ;Select Bank 0 to access PORTC.
    CLRF PORTC                 ;Clear the PORTC output latch.

    ;Enable the required interrupts.
    Banksel INTCON             ;Select Bank 0 to access INTCON.
    BSF INTCON, 6              ;Enable peripheral interrupts.
    BSF INTCON, 4              ;Enable the RB0 external interrupt.
    BSF INTCON, 3              ;Enable the PORTB-change interrupt.
    BSF INTCON, 7              ;Enable global interrupts.
    GOTO Main                  ;Jump to the main program.

Main:
    ;Continuously write 0x31 to PORTC.
    BANKSEL PORTC              ;Select Bank 0 to access PORTC.
    MOVLW 0x31                 ;Load W with 0x31.
    MOVWF PORTC                ;Write the value to PORTC.
    GOTO Main                  ;Repeat the main loop.

ISRHandler:
    ;Save W and STATUS before checking the interrupt flags.
    MOVWF W_temp               ;Save the current value of W.
    SWAPF STATUS,W             ;Copy STATUS into W with its nibbles swapped.
    MOVWF Status_temp          ;Save the swapped STATUS value.
    BANKSEL PORTB              ;Select Bank 0 to access PORTB.

CheckFlags:
    ;Check the PORTB-change flag before the RB0 external interrupt flag.
    BANKSEL INTCON             ;Select Bank 0 to access INTCON.
    BTFSC INTCON,0             ;Skip the next instruction if the PORTB-change flag is clear.
    GOTO InteruptRB1           ;Jump to the RB1 interrupt code.
    BTFSC INTCON,1             ;Skip the next instruction if the RB0 interrupt flag is clear.
    GOTO InteruptRB0           ;Jump to the RB0 interrupt code.

LeaveISR:
    ;Restore STATUS and W before returning.
    SWAPF Status_temp,W        ;Swap the saved STATUS value back into W.
    MOVWF STATUS               ;Restore STATUS.
    SWAPF W_temp,F             ;Swap the nibbles of the saved W value.
    SWAPF W_temp,W             ;Restore W without changing STATUS flags.
    RETFIE                     ;Return from the interrupt and enable global interrupts.

InteruptRB0:
    ;Disable RB0 interrupts and save values before allowing another interrupt.
    BANKSEL PORTC              ;Select Bank 0 to access PORTC.
    BCF INTCON, 4              ;Disable the RB0 external interrupt.
    MOVWF W_temp2              ;Save the current value of W in W_temp2.
    SWAPF Status_temp,W        ;Copy the saved STATUS value into W with its nibbles swapped.
    MOVWF Status_temp2         ;Save this value in Status_temp2.
    BSF INTCON, 7              ;Enable global interrupts to allow another interrupt.

    ;Write 0x36 to PORTC and run the delay.
    MOVLW 0x36                 ;Load W with 0x36.
    MOVWF PORTC                ;Write the value to PORTC.
    MOVLW 0x1F                 ;Load W with the delay repeat count.
    MOVWF TwoSecDelaySixValue  ;Save the repeat count for the six delay.
    Call TwoSecDelaySix        ;Run the six delay.

    ;Disable interrupts while updating the saved values.
    BCF INTCON, 7              ;Disable global interrupts.
    SWAPF Status_temp2         ;Swap the nibbles in Status_temp2.
    MOVWF Status_temp          ;Copy the current W value into Status_temp.
    SWAPF W_temp2,F            ;Swap the nibbles in W_temp2.
    SWAPF W_temp,W             ;Copy W_temp into W with its nibbles swapped.
    BCF INTCON, 1              ;Clear the RB0 external interrupt flag.
    BSF INTCON, 4              ;Enable the RB0 external interrupt.
    GOTO LeaveISR              ;Jump to the register restoration code.

InteruptRB1:
    ;Write 0x37 to PORTC and run the delay.
    BANKSEL PORTC              ;Select Bank 0 to access PORTC.
    MOVLW 0x37                 ;Load W with 0x37.
    MOVWF PORTC                ;Write the value to PORTC.
    MOVLW 0x1F                 ;Load W with the delay repeat count.
    MOVWF TwoSecDelaySevenValue ;Save the repeat count for the seven delay.
    Call TwoSecDelaySeven      ;Run the seven delay.
    BCF INTCON,0               ;Clear the PORTB-change interrupt flag.
    GOTO LeaveISR              ;Jump to the register restoration code.

TwoSecDelaySix:
    ;Load the outer count and write 0x36 to PORTC.
    MOVLW 0x7E                 ;Load W with the outer loop count.
    MOVWF OuterCountSix        ;Set the outer loop count.
    MOVLW 0x36                 ;Load W with 0x36.
    MOVWF PORTC                ;Write the value to PORTC.

OuterDelayLoopSix:
    ;Load the inner count for this outer loop.
    MOVLW 0xA8                 ;Load W with the inner loop count.
    MOVWF InnerCountSix        ;Set the inner loop count.
    GOTO InnerDelayLoopSix     ;Start the inner delay loop.

DecrementOuterDelaySix:
    ;Update the outer count and the delay repeat count.
    DECFSZ OuterCountSix,1     ;Decrement the outer count, skip the next instruction if zero.
    GOTO OuterDelayLoopSix     ;Run another inner delay loop.
    DECFSZ TwoSecDelaySixValue,1 ;Decrement the repeat count, skip the next instruction if zero.
    GOTO TwoSecDelaySix        ;Run another complete delay block.
    Return                     ;Return when the delay is complete.

InnerDelayLoopSix:
    ;Count down the inner loop.
    DECFSZ InnerCountSix,1     ;Decrement the inner count, skip the next instruction if zero.
    GOTO InnerDelayLoopSix     ;Repeat the inner delay loop.
    GOTO DecrementOuterDelaySix ;Update the outer count.

TwoSecDelaySeven:
    ;Load the outer count for the seven delay.
    MOVLW 0x7E                 ;Load W with the outer loop count.
    MOVWF OuterCountSeven      ;Set the outer loop count.

OuterDelayLoopSeven:
    ;Load the inner count for this outer loop.
    MOVLW 0xA8                 ;Load W with the inner loop count.
    MOVWF InnerCountSeven      ;Set the inner loop count.
    GOTO InnerDelayLoopSeven   ;Start the inner delay loop.

DecrementOuterDelaySeven:
    ;Update the outer count and the delay repeat count.
    DECFSZ OuterCountSeven,1   ;Decrement the outer count, skip the next instruction if zero.
    GOTO OuterDelayLoopSeven   ;Run another inner delay loop.
    DECFSZ TwoSecDelaySevenValue,1 ;Decrement the repeat count, skip the next instruction if zero.
    GOTO TwoSecDelaySeven      ;Run another complete delay block.
    Return                     ;Return when the delay is complete.

InnerDelayLoopSeven:
    ;Count down the inner loop.
    DECFSZ InnerCountSeven,1   ;Decrement the inner count, skip the next instruction if zero.
    GOTO InnerDelayLoopSeven   ;Repeat the inner delay loop.
    GOTO DecrementOuterDelaySeven ;Update the outer count.