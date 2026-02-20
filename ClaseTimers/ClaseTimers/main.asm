/*
* NombreProgra.asm
*
* Creado: 
* Autor : 
* Descripción: 
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

.cseg
.org 0x0000
.equ TCNT1_value=0x08BDC
 /****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
SETUP:
	CLI
    LDI R16, (1 << CLKPCE)
	STS CLKPR, R16
	LDI R16, 0b000010
	STS CLKPR, R16
	SBI DDRB, DDB0
	SBI DDRB, DDB5
	CBI PORTB, PORTB0
	CBI PORTB, PORTB5


	CALL INIT_TMR1
/****************************************/
// Loop Infinito
MAIN_LOOP:
    RJMP    MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines
INIT_TMR1:
	LDI R16, 0x00
	STS TCCR1A, R16
	LDI R16, (1 << CS11)
	STS TCCR1B, R16
	LDI R16, HIGH(TCNT1_value)
	STS TCNT1H, R16
	LDI R16, LOW(TCNT1_value)
	STS TCNT1H, R16
	RET
/****************************************/
// Interrupt routines

/****************************************/