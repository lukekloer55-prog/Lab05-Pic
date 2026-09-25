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
    PortBLast EQU 0x22
    PortBChange EQU 0x23
        
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
    BANKSEL ANSEL          ;Select the bank containing ANSEL.
    CLRF ANSEL             ;Disable the analog inputs controlled by ANSEL.
    BANKSEL TRISA          ;Select the bank containing TRISA.
    CLRF TRISA             ;Set all TRISA direction bits for output.

    ;Setup PORTC for output.
    BANKSEL TRISC          ;Select the bank containing TRISC.
    CLRF TRISC             ;Set all PORTC pins as outputs.

    ;Set the PORTB output latch and disable CCP1.
    BCF 0x03,5             ;Select Bank 0 with the following instruction.
    BCF 0x03,6
    MOVLW 0xFF             ;Load W with all bits high.
    MOVWF 0x06             ;Set all PORTB output latch bits high.
    CLRF 0x17              ;Clear CCP1CON to disable CCP1.

    ;Setup PORTB for input.
    BSF 0x03,5             ;Select Bank 1 with the following instruction.
    BCF 0x03,6
    MOVLW 0xFF             ;Load W with all bits high.
    MOVWF 0x86             ;Set all PORTB pins as inputs.

    ;Set the specified register bit in Bank 2.
    BCF 0x03,5             ;Select Bank 2 with the following instruction.
    BSF 0x03,6
    BSF 0x09,1             ;Set bit 1 of register 0x09 in Bank 2.

    ;Disable the remaining analog inputs.
    BSF 0x03,5             ;Select Bank 3 with the following instruction.
    BSF 0x03,6
    CLRF 0x89              ;Clear ANSELH to enable digital input on these pins.

    ;Clear the PORTB output latch.
    Banksel PORTB          ;Select Bank 0 to access PORTB.
    CLRF PORTB             ;Clear all PORTB output latch bits.

    ;Enable interrupt-on-change for all PORTB pins.
    Banksel IOCB           ;Select the bank containing IOCB.
    MOVLW 0xFF             ;Load W with all bits high.
    MOVWF IOCB             ;Enable interrupt-on-change on RB0 through RB7.

    ;Enable PORTB-change interrupts and global interrupts.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BSF INTCON,3           ;Enable the PORTB-change interrupt.
    BSF INTCON,7           ;Enable global interrupts.
    GOTO Main              ;Jump to the main program.

Main:
    ;Continuously toggle RC0.
    MOVLW 0x01             ;Load W with the mask for bit 0.
    XORWF PORTC, 1         ;Toggle bit 0 and store the result in PORTC.
    GOTO Main              ;Repeat the main loop.

ISRHandler:
    ;Save W and STATUS before handling the interrupt.
    MOVWF W_temp           ;Save the current value of W.
    SWAPF STATUS,W         ;Copy STATUS into W with its nibbles swapped.
    MOVWF Status_temp      ;Save the swapped STATUS value.

    ;Find which PORTB pins have changed.
    BANKSEL PORTB          ;Select Bank 0 to access PORTB.
    MOVF PortBLast,0        ;Load the previous PORTB reading into W.
    XORWF PORTB,0          ;Set a bit in W for each changed PORTB pin.
    MOVWF PortBChange      ;Save the changed-pin flags.

    ;Check the PORTB-change interrupt flag.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BTFSC INTCON,0         ;Skip the next instruction if the flag is clear.
    GOTO InteruptPORTBChanged ;Jump to the changed-pin checks.

LeaveISR:
    ;Save the latest PORTB reading.
    BANKSEL PORTB          ;Select Bank 0 to access PORTB.
    MOVF PORTB, 0          ;Read PORTB into W to end the current mismatch.
    MOVWF PortBLast        ;Save the reading for the next comparison.

    ;Restore STATUS and W before returning.
    SWAPF Status_temp,W    ;Swap the saved STATUS value back into W.
    MOVWF STATUS           ;Restore STATUS.
    SWAPF W_temp,F         ;Swap the nibbles of the saved W value.
    SWAPF W_temp,W         ;Restore W without changing STATUS flags.
    RETFIE                 ;Return from the interrupt and enable global interrupts.

InteruptPORTBChanged:
    ;Check changed pins from RB7 down to RB0.
    BANKSEL PORTB          ;Select Bank 0 to access the saved change flags.
    BTFSC PortBChange,7    ;Skip the next instruction if RB7 has not changed.
    GOTO InteruptRB7       ;Handle the change on RB7.
    BTFSC PortBChange,6    ;Skip the next instruction if RB6 has not changed.
    GOTO InteruptRB6       ;Handle the change on RB6.
    BTFSC PortBChange,5    ;Skip the next instruction if RB5 has not changed.
    GOTO InteruptRB5       ;Handle the change on RB5.
    BTFSC PortBChange,4    ;Skip the next instruction if RB4 has not changed.
    GOTO InteruptRB4       ;Handle the change on RB4.
    BTFSC PortBChange,3    ;Skip the next instruction if RB3 has not changed.
    GOTO InteruptRB3       ;Handle the change on RB3.
    BTFSC PortBChange,2    ;Skip the next instruction if RB2 has not changed.
    GOTO InteruptRB2       ;Handle the change on RB2.
    BTFSC PortBChange,1    ;Skip the next instruction if RB1 has not changed.
    GOTO InteruptRB1       ;Handle the change on RB1.
    BTFSC PortBChange,0    ;Skip the next instruction if RB0 has not changed.
    GOTO InteruptRB0       ;Handle the change on RB0.
    GOTO LeaveISR          ;Leave the interrupt if no change was found.

InteruptRB0:
    ;Write 0 to PORTA when RB0 changes.
    BANKSEL PORTA          ;Select Bank 0 to access PORTA.
    MOVLW 0x00             ;Load W with 0.
    MOVWF PORTA            ;Write the value to PORTA.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BCF INTCON,0           ;Clear the PORTB-change interrupt flag.
    GOTO LeaveISR          ;Jump to the register restoration code.

InteruptRB1:
    ;Write 1 to PORTA when RB1 changes.
    BANKSEL PORTA          ;Select Bank 0 to access PORTA.
    MOVLW 0x01             ;Load W with 1.
    MOVWF PORTA            ;Write the value to PORTA.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BCF INTCON,0           ;Clear the PORTB-change interrupt flag.
    GOTO LeaveISR          ;Jump to the register restoration code.

InteruptRB2:
    ;Write 2 to PORTA when RB2 changes.
    BANKSEL PORTA          ;Select Bank 0 to access PORTA.
    MOVLW 0x02             ;Load W with 2.
    MOVWF PORTA            ;Write the value to PORTA.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BCF INTCON,0           ;Clear the PORTB-change interrupt flag.
    GOTO LeaveISR          ;Jump to the register restoration code.

InteruptRB3:
    ;Write 3 to PORTA when RB3 changes.
    BANKSEL PORTA          ;Select Bank 0 to access PORTA.
    MOVLW 0x03             ;Load W with 3.
    MOVWF PORTA            ;Write the value to PORTA.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BCF INTCON,0           ;Clear the PORTB-change interrupt flag.
    GOTO LeaveISR          ;Jump to the register restoration code.

InteruptRB4:
    ;Write 4 to PORTA when RB4 changes.
    BANKSEL PORTA          ;Select Bank 0 to access PORTA.
    MOVLW 0x04             ;Load W with 4.
    MOVWF PORTA            ;Write the value to PORTA.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BCF INTCON,0           ;Clear the PORTB-change interrupt flag.
    GOTO LeaveISR          ;Jump to the register restoration code.

InteruptRB5:
    ;Write 5 to PORTA when RB5 changes.
    BANKSEL PORTA          ;Select Bank 0 to access PORTA.
    MOVLW 0x05             ;Load W with 5.
    MOVWF PORTA            ;Write the value to PORTA.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BCF INTCON,0           ;Clear the PORTB-change interrupt flag.
    GOTO LeaveISR          ;Jump to the register restoration code.

InteruptRB6:
    ;Write 6 to PORTA when RB6 changes.
    BANKSEL PORTA          ;Select Bank 0 to access PORTA.
    MOVLW 0x06             ;Load W with 6.
    MOVWF PORTA            ;Write the value to PORTA.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BCF INTCON,0           ;Clear the PORTB-change interrupt flag.
    GOTO LeaveISR          ;Jump to the register restoration code.

InteruptRB7:
    ;Write 7 to PORTA when RB7 changes.
    BANKSEL PORTA          ;Select Bank 0 to access PORTA.
    MOVLW 0x07             ;Load W with 7.
    MOVWF PORTA            ;Write the value to PORTA.
    BANKSEL INTCON         ;Select Bank 0 to access INTCON.
    BCF INTCON,0           ;Clear the PORTB-change interrupt flag.
    GOTO LeaveISR          ;Jump to the register restoration code.