/*
* Clase FSM
*
* Creado: 25-02-2026
* Autor : Joaquín Fuentes
* Descripción: 
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.equ T1VALUE	= 0xE17B
.equ MAX_MODES	= 4
.def MODE		= R20
.def COUNTER	= R21
.def ACTION		= R22

.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

.cseg
.org 0x0000
	JMP START

.org PCI2addr
	JMP PCINT2_ISR

.org OVF1addr
	JMP TMR1_ISR
START:
 /****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
SETUP:
	; Disable interruptions
	CLI
	; Configure main clock prescaler
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16
	LDI R16, (1 << CLKPS2)
	STS CLKPR, R16
    
	; Configure outputs e inputs
	SBI DDRB, DDB0
	SBI DDRB, DDB1
	CBI PORTB, PORTB0
	CBI PORTB, PORTB1

	LDI R16, 0XFF
	OUT DDRC, R16
	LDI R16, 0x00
	OUT PORTC, R16
	
	;Entradas PD2 y PD3
	CBI DDRD, DDD2
	CBI DDRD, DDD3
	SBI PORTD, PORTD2
	SBI PORTD, PORTD3
	
	// Configurar TIMER1

	CALL INIT_TMR1

	LDI R16, (1 << TOIE1)
	STS TIMSK1, R16
	LDI R16, (1 << PCIE2)
	STS PCICR, R16
	LDI R16, (1 << PCINT19) | (1 << PCINT18)
	STS PCMSK2, R16

	// Borrar registros
	CLR MODE
	CLR COUNTER
	CLR ACTION

	; Habilitar interrupciones globales
	SEI
/****************************************/
// Loop Infinito
MAIN_LOOP:
	OUT PORTC, COUNTER
	OUT PORTB, MODE

	CPI MODE, 0
	BREQ INC_MODE

	CPI MODE, 1
	BREQ DEC_MODE

	CPI MODE, 2
	BREQ AUTO_INC_MODE

	CPI MODE, 3
	BREQ AUTO_DEC_MODE
	
INC_MODE:
	CPI ACTION, 0X01
	BRNE EXIT_IM
	INC COUNTER
	CLR ACTION
EXIT_IM:
    RJMP    MAIN_LOOP

DEC_MODE:
	CPI ACTION, 0X01
	BRNE EXIT_DM
	DEC COUNTER
	CLR ACTION
EXIT_DM:
    RJMP    MAIN_LOOP

AUTO_INC_MODE:
	CPI ACTION, 0X01
	BRNE EXIT_AIM
	INC COUNTER
	CLR ACTION
EXIT_AIM:
    RJMP    MAIN_LOOP

AUTO_DEC_MODE:
	CPI ACTION, 0X01
	BRNE EXIT_ADM
	DEC COUNTER
	CLR ACTION
EXIT_ADM:
    RJMP    MAIN_LOOP


/****************************************/
// NON-Interrupt subroutines
INIT_TMR1:
	LDI R16, 0x00
	STS TCCR1A, R16
	LDI R16, (1 << CS11) | (1 << CS10)
	STS TCCR1B, R16
	RET
/****************************************/
// Interrupt routines
PCINT2_ISR:
	
	SBIS PIND, PIND2
	INC MODE
	CPI MODE, MAX_MODES
	BRNE CONTINUE
	CLR MODE
CONTINUE:
	CPI MODE, 0
	BREQ PCINT2_ISR_MODE0
	
	CPI MODE, 1
	BREQ PCINT2_ISR_MODE1

	CPI MODE, 2
	BREQ PCINT2_ISR_MODE2

	CPI MODE, 3
	BREQ PCINT2_ISR_MODE3

	SBIS PIND, PIND3
	LDI ACTION, 0X01

PCINT2_ISR_MODE0:
	SBIS PIND, PIND3
	LDI ACTION, 0x01
	RJMP EXIT_PCINT2_ISR

PCINT2_ISR_MODE1:
	SBIS PIND, PIND3
	LDI ACTION, 0x01
	RJMP EXIT_PCINT2_ISR

PCINT2_ISR_MODE2:
	RJMP EXIT_PCINT2_ISR

PCINT2_ISR_MODE3:
	RJMP EXIT_PCINT2_ISR


EXIT_PCINT2_ISR:
	RETI
TMR1_ISR:

	LDI R16, HIGH(T1VALUE)
	STS TCNT1H, R16
	LDI R16, LOW(T1VALUE)
	STS TCNT1L, R16
	
	CPI MODE, 0
	BREQ EXIT_TMR1_ISR

	CPI MODE, 1
	BREQ EXIT_TMR1_ISR

	LDI ACTION, 0x01
EXIT_TMR1_ISR:
	RETI
/****************************************/