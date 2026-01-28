/*
* EjemploBotón
*
* Creado: 28/01/2026
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
    // Configurar entradas y salidas
	//Input --> PD5
	CBI	DDRD, DDD5 // O sea 5 = DDD5 es posible poner solo 5 pero es más fácil de releer si existe DDD5
	CBI	PORTD, PORTD5 // Esto desactiva el pull-up
	//Output --> PD0
	SBI	DDRB, DDB0
	CBI	PORTB, PORTB0
/****************************************/
// Loop Infinito
MAIN_LOOP:
    IN	R17, PIND //Leer PIND
	ANDI R17, 0b0010000
	BRNE MAIN_LOOP
	CALL DELAY
	IN R18, PIND
	CP R18, R17
	BRNE MAIN_LOOP
	SBI PINB, PINB0 //Toggle
	RJMP    MAIN_LOOP

DELAY:
	LDI R19, 255
LOOP_DELAY:
	DEC R19
	BRNE LOOP_DELAY
	RET

/****************************************/
// NON-Interrupt subroutines

/****************************************/
// Interrupt routines

/****************************************/