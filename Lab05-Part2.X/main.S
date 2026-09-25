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
    Portbsnapshot EQU 0x22
        
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
    ;Setup PORTA and disable its analog input functions.
    BANKSEL ANSEL           ;Select the bank containing ANSEL.
    CLRF ANSEL              ;Disable analog input functions controlled by ANSEL.
    BANKSEL TRISA           ;Select Bank 1 to access TRISA.
    CLRF TRISA              ;Clear TRISA to configure available PORTA pins as outputs.
    BANKSEL PORTA           ;Select Bank 0 to access PORTA.
    CLRF PORTA              ;Clear the PORTA output latch to drive its outputs low.

    ;Setup PORTB and disable CCP1.
    BCF 0x03,5              ;Select Bank 0 with the following instruction.
    BCF 0x03,6
    MOVLW 0xFF              ;Load the working register with all bits high.
    MOVWF 0x06              ;Write 0xFF to the PORTB output latch; this does not set pin direction.
    CLRF 0x17               ;Clear CCP1CON to disable the CCP1 module.

    ;Configure PORTB pins as inputs.
    BSF 0x03,5              ;Select Bank 1 with the following instruction.
    BCF 0x03,6
    MOVLW 0xFF              ;Load the working register with all bits high.
    MOVWF 0x86              ;Write 0xFF to TRISB to configure all PORTB pins as inputs.

    ;Set the Timer1 gate source selection bit.
    BCF 0x03,5              ;Select Bank 2 with the following instruction.
    BSF 0x03,6
    BSF 0x09,1              ;Set T1GSS in CM2CON1; this is not a PORTB interrupt-enable bit.

    ;Disable PORTB analog input functions.
    BSF 0x03,5              ;Select Bank 3 with the following instruction.
    BSF 0x03,6
    CLRF 0x89               ;Clear ANSELH to enable digital input functions on PORTB analog pins.

    ;Select the active edge for the RB0 external interrupt.
    BANKSEL OPTION_REG      ;Select the bank containing OPTION_REG.
    BCF OPTION_REG,6        ;Clear INTEDG to trigger the RB0 interrupt on a falling edge.

    ;Clear the RB0 and RB4 output-latch bits.
    Banksel PORTB           ;Select Bank 0 to access PORTB.
    BCF PORTB,0             ;Clear the RB0 latch bit, RB0 remains configured as an input.
    BCF PORTB,4             ;Clear the RB4 latch bit, RB4 remains configured as an input.

    ;Enable interrupt-on-change detection for RB4.
    Banksel IOCB            ;Select the bank containing IOCB.
    BSF IOCB,4              ;Set bit 4 to enable interrupt-on-change detection on RB4.

    ;Setup PORTC as outputs and clear its output latch.
    BANKSEL TRISC           ;Select Bank 1 to access TRISC.
    CLRF TRISC              ;Clear TRISC to configure all PORTC pins as outputs.
    Banksel PORTC           ;Select Bank 0 to access PORTC.
    CLRF PORTC              ;Clear the PORTC output latch to drive its outputs low.

    ;Enable the required interrupt controls.
    Banksel INTCON          ;Select a bank for INTCON, which is accessible in every bank.
    BSF INTCON, 6           ;Enable individually enabled peripheral interrupts.
    BSF INTCON, 4           ;Enable the RB0 external interrupt.
    BSF INTCON, 3           ;Enable PORTB interrupt-on-change interrupts.
    BSF INTCON, 7           ;Enable global interrupt handling.

    GOTO Main               ;Jump to the main program loop.

Main:
    ;Toggle PORTA bit 0 continuously as a diagnostic output.
    MOVLW 0x01              ;Load the working register with a mask for bit 0.
    XORWF PORTA, 1          ;Toggle PORTA bit 0 and store the result back in PORTA.
    GOTO Main               ;Repeat the main program loop.

ISRHandler:
    ;Save the interrupted program's working register and STATUS.
    MOVWF W_temp            ;Save the working register before using it in the interrupt handler.
    SWAPF STATUS,W          ;Copy STATUS into W with its nibbles swapped without changing STATUS flags.
    MOVWF Status_temp       ;Save the swapped STATUS value for restoration before returning.

    ;Read PORTB to acknowledge the mismatch and save the pin states.
    BANKSEL PORTB           ;Select Bank 0 to access PORTB.
    MOVF PORTB,0            ;Read PORTB into W to end the interrupt-on-change mismatch condition.
    MOVWF Portbsnapshot     ;Save the PORTB reading in Portbsnapshot.

    ;Check the interrupt flags, checking RB0 first.
    BANKSEL INTCON          ;Select a bank for the interrupt control register.
    BTFSC INTCON,1          ;Check bit 1, skip the next instruction if the RB0 interrupt flag is clear.
    GOTO InteruptRB0        ;Jump to the RB0 handler when its interrupt flag is set.
    BTFSC INTCON,0          ;Check bit 0, skip the next instruction if the PORTB-change flag is clear.
    GOTO InteruptRB4        ;Jump to the RB4 handler when the PORTB-change flag is set.

LeaveISR:
    ;Restore the interrupted program's STATUS and working register.
    SWAPF Status_temp,W     ;Swap the saved STATUS nibbles back into their original order in W.
    MOVWF STATUS            ;Restore the saved STATUS flags and bank-selection bits.
    SWAPF W_temp,F          ;Swap the saved W nibbles in place without changing STATUS flags.
    SWAPF W_temp,W          ;Swap again to restore the original W value without changing STATUS flags.
    RETFIE                  ;Return to the interrupted program and re-enable global interrupts.

InteruptRB0:
    ;Handle the RB0 external interrupt by clearing PORTC.
    BANKSEL PORTC           ;Select Bank 0 to access PORTC.
    CLRF PORTC              ;Clear PORTC to reset the displayed output value to zero.
    BCF INTCON,1            ;Clear the RB0 external interrupt flag.
    GOTO LeaveISR           ;Jump to the register restoration code before returning.

InteruptRB4:
    ;Handle the PORTB-change interrupt by incrementing PORTC.
    BANKSEL PORTC           ;Select Bank 0 to access PORTC.
    INCF PORTC              ;Increment PORTC 
    BCF INTCON,0            ;Clear the PORTB-change flag after the PORTB read at interrupt entry.
    GOTO LeaveISR           ;Jump to the register restoration code before returning.