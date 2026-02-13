/*
* Laboratorio2_PrograMicros.asm
*
* Creado: 12-feb-2026 
* Autor : Joaquín Fuentes
* Descripción: Contador de 4 bits que cambia cada 100ms
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
	; -------- ENTRADAS (BOTONES EN PORTD) --------
	CBI DDRD, DDD2
	CBI DDRD, DDD3
	SBI PORTD, DDD2
	SBI PORTD, DDD3
	; -------- SALIDAS --------

	; CONTADOR 1 (PB0-PB3)
	LDI R16, 0x0F
	OUT DDRB, R16

	;DISPLAY
	LDI R16, 0x3F
	OUT DDRC, R16
	SBI DDRD, DDD4

	;--------TIMER0----------
	LDI R16, 0x00
	OUT TCCR0A, R16 ; MODO NORMAL 
	LDI R16, 0b00000101
	OUT TCCR0B, R16
    
/****************************************/
// Loop Infinito
MAIN:
	
/****************************************/
// NON-Interrupt subroutines
POLLING:
	IN R16, TIFR0
	SBRS R16, TOV0 ; REVISAMOS OVERFLOW
	RJMP POLLING

	LDI R16, (1<<TOV0) ; SÍ HUBO OVERFLOW
	OUT TIFR0, R16
	INC R17 ;¿Cuántos overflows?
	CPI R17, 6
	BRNE MAIN

	CLR R17

	INC R18 ;LEDS AVANZA 1
	ANDI R18, 0x0F
	OUT PORTB, R18

	RJMP MAIN
/****************************************/
// Interrupt routines

/****************************************/