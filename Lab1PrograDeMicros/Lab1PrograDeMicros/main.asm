/*
* Sumador de 4 bits
*
* Creado: 11-feb-2026
* Autor : Joaquín Fuentes
* Descripción: Se tienen dos contadores de 4 bits que funcionan por separado, cuyos valores se pueden sumar. Se tiene una led que muestra carry.
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
	CBI DDRD, DDD4
	CBI DDRD, DDD5
	CBI DDRD, DDD6

	LDI R16, (1<<PD2)|(1<<PD3)|(1<<PD4)|(1<<PD5)|(1<<PD6)
	OUT PORTD, R16 ; PULLUPS

	; -------- SALIDAS --------

	; CONTADOR 1 (PB0-PB3)
	LDI R16, 0X0F
	OUT DDRB, R16

	; CONTADOR 2 (PC0-PC3)
	LDI R16, 0X0F
	OUT DDRC, R16

	; RESULTADO PB4-PB5
	SBI DDRB, DDB4
	SBI DDRB, DDB5

	; RESULTADO PC4-PC5
	SBI DDRC, DDC4
	SBI DDRC, DDC5

	; CARRY PD7
	SBI DDRD, DDD7

	; LIMPIAR SOLO SALIDAS (NO TOCAR PULLUPS)
	CLR R16
	OUT PORTB, R16
	OUT PORTC, R16
	CBI PORTD, PD7

	; -------- INICIAL --------
	CLR R20
	CLR R21
	IN  R16, PIND
	ANDI R16, 0b01111100

MAIN:
	;ON/OFF?
	IN  R17, PIND
	ANDI R17, 0b01111100
	CP   R17, R16
	BREQ MAIN


	RCALL DELAY

	IN   R18, PIND
	ANDI R18, 0b01111100
	CP   R18, R17
	BRNE MAIN


	MOV R16, R17

	; ---- CONTADOR 1 ----
	SBRS R17, PD2
	INC R20

	SBRS R17, PD3
	DEC R20

	; ---- CONTADOR 2 ----
	SBRS R17, PD4
	INC R21

	SBRS R17, PD5
	DEC R21
	
	;SOLO 4 BITS
	ANDI R20, 0X0F
	ANDI R21, 0X0F

	; ---- MOSTRAR CONTADORES ----

	; PB0-PB3
	IN R22, PORTB
	ANDI R22, 0b11110000
	OR R22, R20
	OUT PORTB, R22

	; PC0-PC3
	IN R23, PORTC
	ANDI R23, 0b11110000
	OR R23, R21
	OUT PORTC, R23

	; ---- SUMA ----
	SBRS R17, PD6
	RCALL SUMA

	RJMP MAIN


SUMA:

	;SUMA DE REGISTROS
	MOV R24, R20
	ADD R24, R21

	;LÓGICA DEL CARRY
	SBRC R24, 4 ;10000
	SBI PORTD, PD7

	SBRS R24, 4
	CBI PORTD, PD7
	;--------------
	ANDI R24, 0X0F

	; BIT0 -> PB4
	SBRS R24, 0
	CBI PORTB, PB4
	SBRC R24, 0
	SBI PORTB, PB4

	; BIT1 -> PB5
	SBRS R24, 1
	CBI PORTB, PB5
	SBRC R24, 1
	SBI PORTB, PB5

	; BIT2 -> PC4
	SBRS R24, 2
	CBI PORTC, PC4
	SBRC R24, 2
	SBI PORTC, PC4

	; BIT3 -> PC5
	SBRS R24, 3
	CBI PORTC, PC5
	SBRC R24, 3
	SBI PORTC, PC5

	RET


DELAY:
	LDI R19, 200
D1:
	DEC R19
	BRNE D1
	RET
