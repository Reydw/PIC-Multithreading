#include "p18f4550.inc"
    
; CONFIG1L
  CONFIG  PLLDIV = 1            ; PLL Prescaler Selection bits (No prescale (4 MHz oscillator input drives PLL directly))
  CONFIG  CPUDIV = OSC1_PLL2    ; System Clock Postscaler Selection bits ([Primary Oscillator Src: /1][96 MHz PLL Src: /2])
  CONFIG  USBDIV = 1            ; USB Clock Selection bit (used in Full-Speed USB mode only; UCFG:FSEN = 1) (USB clock source comes directly from the primary oscillator block with no postscale)

; CONFIG1H
  CONFIG  FOSC = INTOSCIO_EC    ; Oscillator Selection bits (Internal oscillator, port function on RA6, EC used by USB (INTIO))
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enable bit (Fail-Safe Clock Monitor disabled)
  CONFIG  IESO = OFF            ; Internal/External Oscillator Switchover bit (Oscillator Switchover mode disabled)

; CONFIG2L
  CONFIG  PWRT = OFF            ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  BOR = OFF             ; Brown-out Reset Enable bits (Brown-out Reset disabled in hardware and software)
  CONFIG  BORV = 3              ; Brown-out Reset Voltage bits (Minimum setting 2.05V)
  CONFIG  VREGEN = OFF          ; USB Voltage Regulator Enable bit (USB voltage regulator disabled)

; CONFIG2H
  CONFIG  WDT = OFF             ; Watchdog Timer Enable bit (WDT disabled (control is placed on the SWDTEN bit))
  CONFIG  WDTPS = 32768         ; Watchdog Timer Postscale Select bits (1:32768)

; CONFIG3H
  CONFIG  CCP2MX = ON           ; CCP2 MUX bit (CCP2 input/output is multiplexed with RC1)
  CONFIG  PBADEN = OFF          ; PORTB A/D Enable bit (PORTB<4:0> pins are configured as digital I/O on Reset)
  CONFIG  LPT1OSC = ON          ; Low-Power Timer 1 Oscillator Enable bit (Timer1 configured for low-power operation)
  CONFIG  MCLRE = OFF           ; MCLR Pin Enable bit (RE3 input pin enabled; MCLR pin disabled)

; CONFIG4L
  CONFIG  STVREN = OFF          ; Stack Full/Underflow Reset Enable bit (Stack full/underflow will not cause Reset)
  CONFIG  LVP = ON              ; Single-Supply ICSP Enable bit (Single-Supply ICSP enabled)
  CONFIG  ICPRT = OFF           ; Dedicated In-Circuit Debug/Programming Port (ICPORT) Enable bit (ICPORT disabled)
  CONFIG  XINST = OFF           ; Extended Instruction Set Enable bit (Instruction set extension and Indexed Addressing mode disabled (Legacy mode))

; CONFIG5L
  CONFIG  CP0 = OFF             ; Code Protection bit (Block 0 (000800-001FFFh) is not code-protected)
  CONFIG  CP1 = OFF             ; Code Protection bit (Block 1 (002000-003FFFh) is not code-protected)
  CONFIG  CP2 = OFF             ; Code Protection bit (Block 2 (004000-005FFFh) is not code-protected)
  CONFIG  CP3 = OFF             ; Code Protection bit (Block 3 (006000-007FFFh) is not code-protected)

; CONFIG5H
  CONFIG  CPB = OFF             ; Boot Block Code Protection bit (Boot block (000000-0007FFh) is not code-protected)
  CONFIG  CPD = OFF             ; Data EEPROM Code Protection bit (Data EEPROM is not code-protected)

; CONFIG6L
  CONFIG  WRT0 = OFF            ; Write Protection bit (Block 0 (000800-001FFFh) is not write-protected)
  CONFIG  WRT1 = OFF            ; Write Protection bit (Block 1 (002000-003FFFh) is not write-protected)
  CONFIG  WRT2 = OFF            ; Write Protection bit (Block 2 (004000-005FFFh) is not write-protected)
  CONFIG  WRT3 = OFF            ; Write Protection bit (Block 3 (006000-007FFFh) is not write-protected)

; CONFIG6H
  CONFIG  WRTC = OFF            ; Configuration Register Write Protection bit (Configuration registers (300000-3000FFh) are not write-protected)
  CONFIG  WRTB = OFF            ; Boot Block Write Protection bit (Boot block (000000-0007FFh) is not write-protected)
  CONFIG  WRTD = OFF            ; Data EEPROM Write Protection bit (Data EEPROM is not write-protected)

; CONFIG7L
  CONFIG  EBTR0 = OFF           ; Table Read Protection bit (Block 0 (000800-001FFFh) is not protected from table reads executed in other blocks)
  CONFIG  EBTR1 = OFF           ; Table Read Protection bit (Block 1 (002000-003FFFh) is not protected from table reads executed in other blocks)
  CONFIG  EBTR2 = OFF           ; Table Read Protection bit (Block 2 (004000-005FFFh) is not protected from table reads executed in other blocks)
  CONFIG  EBTR3 = OFF           ; Table Read Protection bit (Block 3 (006000-007FFFh) is not protected from table reads executed in other blocks)

; CONFIG7H
  CONFIG  EBTRB = OFF           ; Boot Block Table Read Protection bit (Boot block (000000-0007FFh) is not protected from table reads executed in other blocks)

GPR_VAR		UDATA
TEMP_SHADOW	RES	3
CURRENT_THREAD	RES	1
THREAD0_REG	RES	6	; THREAD0_REG(0) = TOSL ; THREAD0_REG(1) = TOSH ; THREAD0_REG(2) = TOSU ; THREAD0_REG(3) = W ; THREAD0_REG(4) = STATUS ; THREAD0_REG(5) = BSR
THREAD1_REG	RES	6
THREAD2_REG	RES	6

RES_VECT  CODE    0x0000
    goto    START
    
ISRHV     CODE    0x0008
    goto    context_switching

MAIN_PROG CODE

START
    ; Oscillator setup
    movlw   b'01110000'		; W = 01110000
    movwf   OSCCON		; OSCCON = W
    clrf    CURRENT_THREAD
    
    ; Timer3 setup
    movlw   b'10000001'		; W = 10000001
    movwf   T3CON		; T3CON = W
    bsf	    PIE2, TMR3IE	; PIE2<TMR3IE> = 1
    
    ; Start interrupt and Timer3
    movlw   b'11000000'
    movwf   INTCON
    ; Timer3 overflow after 50 microseconds
    setf    TMR3H
    movlw   .196
    movwf   TMR3L
    
    ; Prepare next thread
    movlw   thread1
    movwf   THREAD1_REG

thread0
    goto    thread0

thread1
    goto    thread1

thread2
    goto    thread1
    
context_switching
    ; Timer overflow (check for other interrupts)
    bcf	    PIR2, TMR3IF		    ; clear Timer3 overflow
    movwf   TEMP_SHADOW			    ; save W
    movff   STATUS, TEMP_SHADOW+1	    ; save STATUS
    movff   BSR, TEMP_SHADOW+2		    ; save BSR
    
    ; Save TOS
    ; Thread 0
    movlw   .0				    ; W = 0
    cpfseq  CURRENT_THREAD		    ; if( W == CURRENT_THREAD ) skip
    goto    context_switching_el11	    ; if( W != CURRENT_THREAD ) goto context_switching_el1
    movff   TOSL, THREAD0_REG		    ; save TOSL
    movff   TOSH, THREAD0_REG+1		    ; save TOSH
    movff   TOSU, THREAD0_REG+2		    ; save TOSU
    movff   TEMP_SHADOW, THREAD0_REG+3	    ; save W
    movff   TEMP_SHADOW+1, THREAD0_REG+4    ; save STATUS
    movff   TEMP_SHADOW+2, THREAD0_REG+5    ; save BSR
    goto    context_switching_fi1
context_switching_el11
    
    ; Thread 1
    movlw   .1				    ; W = 1
    cpfseq  CURRENT_THREAD		    ; if( W == CURRENT_THREAD ) skip
    goto    context_switching_el12	    ; if( W != CURRENT_THREAD ) goto context_switching_el2
    movff   TOSL, THREAD1_REG		    ; save TOSL
    movff   TOSH, THREAD1_REG+1		    ; save TOSH
    movff   TOSU, THREAD1_REG+2		    ; save TOSU
    movff   TEMP_SHADOW, THREAD1_REG+3	    ; save W
    movff   TEMP_SHADOW+1, THREAD1_REG+4    ; save STATUS
    movff   TEMP_SHADOW+2, THREAD1_REG+5    ; save BSR
    goto    context_switching_fi1
context_switching_el12

    ; Thread 2
    movlw   .2				    ; W = 2
    cpfseq  CURRENT_THREAD		    ; if( W == CURRENT_THREAD ) skip
    goto    context_switching_el13	    ; if( W != CURRENT_THREAD ) goto context_switching_el2
    movff   TOSL, THREAD2_REG		    ; save TOSL
    movff   TOSH, THREAD2_REG+1		    ; save TOSH
    movff   TOSU, THREAD2_REG+2		    ; save TOSU
    movff   TEMP_SHADOW, THREAD2_REG+3	    ; save W
    movff   TEMP_SHADOW+1, THREAD2_REG+4    ; save STATUS
    movff   TEMP_SHADOW+2, THREAD2_REG+5    ; save BSR
    goto    context_switching_fi1
context_switching_el13
    
context_switching_fi1

    ; Restore TOS
    ; Thread 0
    movlw   .0				    ; W = 0
    cpfseq  CURRENT_THREAD		    ; if( W == CURRENT_THREAD ) skip
    goto    context_switching_el21	    ; if( W != CURRENT_THREAD ) goto context_switching_el3
    movf    THREAD1_REG, 0		    ; W = TOSL
    movwf   TOSL			    ; restore TOSL
    movf    THREAD1_REG+1, 0		    ; W = TOSH
    movwf   TOSH			    ; restore TOSH
    movf    THREAD1_REG+2, 0		    ; W = TOSU
    movwf   TOSU			    ; restore TOSU
    movf    THREAD1_REG+3, 0		    ; restore W
    movff   THREAD1_REG+4, STATUS	    ; restore STATUS
    movff   THREAD1_REG+5, BSR		    ; restore BSR
    movlw   .1				    ; W = 1
    movwf   CURRENT_THREAD		    ; change next thread
    goto    context_switching_fi2
context_switching_e21
    
    ; Thread 1
    movlw   .1				    ; W = 1
    cpfseq  CURRENT_THREAD		    ; if( W == CURRENT_THREAD ) skip
    goto    context_switching_el22	    ; if( W != CURRENT_THREAD ) goto context_switching_el4
    movf    THREAD2_REG, 0		    ; W = TOSL
    movwf   TOSL			    ; restore TOSL
    movf    THREAD2_REG+1, 0		    ; W = TOSH
    movwf   TOSH			    ; restore TOSH
    movf    THREAD2_REG+2, 0		    ; W = TOSU
    movwf   TOSU			    ; restore TOSU
    movf    THREAD2_REG+3, 0		    ; restore W
    movff   THREAD2_REG+4, STATUS	    ; restore STATUS
    movff   THREAD2_REG+5, BSR		    ; restore BSR
    movlw   .2				    ; W = 2
    movwf   CURRENT_THREAD		    ; change next thread
    goto    context_switching_fi2
context_switching_el22

    ; Thread 2
    movlw   .2				    ; W = 2
    cpfseq  CURRENT_THREAD		    ; if( W == CURRENT_THREAD ) skip
    goto    context_switching_el23	    ; if( W != CURRENT_THREAD ) goto context_switching_el4
    movf    THREAD0_REG, 0		    ; W = TOSL
    movwf   TOSL			    ; restore TOSL
    movf    THREAD0_REG+1, 0		    ; W = TOSH
    movwf   TOSH			    ; restore TOSH
    movf    THREAD0_REG+2, 0		    ; W = TOSU
    movwf   TOSU			    ; restore TOSU
    movf    THREAD0_REG+3, 0		    ; restore W
    movff   THREAD0_REG+4, STATUS	    ; restore STATUS
    movff   THREAD0_REG+5, BSR		    ; restore BSR
    movlw   .0				    ; W = 0
    movwf   CURRENT_THREAD		    ; change next thread
    goto    context_switching_fi2
context_switching_el23

context_switching_fi2
    
    movlw   .196
    movwf   TMR3L
    retfie
    END