/*
* LED_Titilando.asm
*
* Creado: 23/01/2026
* Autor : Joaquín Fuentes
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
 /****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
SETUP:
	LDI R16, 0x00
	OUT DDRD, R16
	OUT PORTD, R16
	LDI R20, 0x00
/****************************************/
// Loop Infinito
MAIN_LOOP:
	LDI	R16, 0x10
	OUT DDRD, R16
	OUT PORTD, R16
	LDI R20, 0X10
	CALL DELAY


    RJMP    MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines
DELAY:
	DEC R20
	BRNE DELAY
	RET

/****************************************/
// Interrupt routines


