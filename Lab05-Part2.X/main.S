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
    ;Setup PORTA and disable unnecessary features.
    BANKSEL ANSEL
    CLRF ANSEL				;Clear ANSEL to set all pins to digital I/O
    BANKSEL TRISA			;Move the value into the working register ready to be moved into the register.
    CLRF TRISA				;Move the value into TRISA, to enable all pins as outputs.
    BANKSEL PORTA   
    CLRF PORTA				;Clear PORTA to set the I/0 pins to read vin low.
    
    ;Setup PORTB and disable unnecessary features.
    BCF 0x03,5				;Set Bank 0
    BCF 0x03,6				;Set Bank 0
    MOVLW 0xFF				;Set all bits in PORTB high, to enable inputs. This is not needed as the bits will be changed later, but just in there for setup.
    MOVWF 0x06				;Move it from the work register to the actual PortB register
    CLRF 0x17				;Set all low for ccp to be disabled.
    
    BSF 0x03,5				;Set Bank 1
    BCF 0x03,6				;Set Bank 1
    MOVLW 0xFF				;Set the working register as a 0F to be moved into the TRISB to make all the top 4 bits low to enable outputs on the top 4 pins, and high on the bottom 4 bits to enable inputs on those pins.
    MOVWF 0x86				;Move all the bits into the register to enable and disable the wanted states for outputs and inputs.
    
    BCF 0x03,5				;Set Bank 2
    BSF 0x03,6				;Set Bank 2
    BSF 0x09,1				;Set Bit 1 High for original state to be enabled.
    
    BSF 0x03,5				;Set Bank 3
    BSF 0x03,6				;Set Bank 3
    CLRF 0x89				;Set all low for digital I/O Enabled.
    
    Banksel PORTB
    BCF PORTB,0
    BCF PORTB,4
    
    Banksel IOCB
    BSF IOCB,4				;Set bit 4 high to enable Interupt on change for RB4
    
    ;PORT C Setup
    BANKSEL TRISC
    CLRF TRISC
    Banksel PORTC
    CLRF PORTC
    
    Banksel INTCON 
    BSF INTCON, 6
    BSF INTCON, 4
    BSF INTCON, 3
    BSF INTCON, 7
GOTO Main

Main:
MOVLW 0x01
XORWF PORTA, 1
GOTO Main
    
ISRHandler:
    MOVWF W_temp
    SWAPF STATUS,W
    MOVWF Status_temp
    BANKSEL PORTB
    MOVF PORTB,0
    MOVWF Portbsnapshot
    BANKSEL INTCON
    BTFSC INTCON,1
    GOTO InteruptRB0
    BTFSC INTCON,0
    GOTO InteruptRB4
LeaveISR:
    SWAPF Status_temp,W
    MOVWF STATUS
    SWAPF W_temp,F
    SWAPF W_temp,W
    RETFIE

InteruptRB0:
    BANKSEL PORTC
    CLRF PORTC
    BCF INTCON,1
    GOTO LeaveISR
    
InteruptRB4:
    BANKSEL PORTC
    INCF PORTC
    BCF INTCON,0
    GOTO LeaveISR
