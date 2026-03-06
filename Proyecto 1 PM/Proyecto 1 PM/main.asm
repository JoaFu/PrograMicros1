/*
* Proyecto 1 Progra Micros
*
* Creado: 27-02-2026
* Autor : Joaquín Fuentes
* Descripción: 
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

DIGIT_INDEX:	.byte 1
DIG0:			.byte 1
DIG1:			.byte 1
DIG2:			.byte 1
DIG3:			.byte 1
MILISEC_L:		.byte 1
MILISEC_H:		.byte 1

.equ MAX_DIG = 4
.cseg
.org 0x0000
    RJMP RESET

.org OC0Aaddr
    RJMP TIMER_ISR
	
RESET:
 /****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
SETUP:
    ; Inicializar variables
	CLR R1
    LDI R16, 0
    STS DIGIT_INDEX, R16
	STS MILISEC_L, R16
	STS MILISEC_H, R16

	LDI R16, 8
	STS DIG0, R16
	LDI R16, 6
	STS DIG1, R16
	LDI R16, 9
	STS DIG2, R16
	LDI R16, 7
	STS DIG3, R16


    ; Segmentos salida
    LDI R16, 0b01111111
    OUT DDRD, R16

    ; Dígitos + LEDs salida
    LDI R16, 0b00111111
    OUT DDRB, R16

	; Empezamos apagados
    CLR R16
    OUT PORTD, R16
    OUT PORTB, R16

    ; Timer0 a 1ms utilizando CTC
    LDI R16, (1<<WGM01)
    OUT TCCR0A, R16

    LDI R16, (1<<CS01)|(1<<CS00)
    OUT TCCR0B, R16

    LDI R16, 249
    OUT OCR0A, R16

    LDI R16, (1<<OCIE0A)
    STS TIMSK0, R16

	CLR R17; Indicador de dígito

    SEI
	
/****************************************/
// Loop Infinito
MAIN_LOOP:
	RJMP MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines

/****************************************/
// Interrupt routines
TIMER_ISR:
	PUSH R16
	PUSH R17
	PUSH R18
	PUSH R19
	PUSH ZL
	PUSH ZH

	; Apagar dígitos
	IN   R16, PORTB
	ANDI R16, 0b11110000
	OUT  PORTB, R16

	LDS R17, DIGIT_INDEX

	CPI R17, 0
	BREQ LOAD_DIG0
	CPI R17, 1
	BREQ LOAD_DIG1
	CPI R17, 2
	BREQ LOAD_DIG2
	RJMP LOAD_DIG3

LOAD_DIG0:
	LDS R18, DIG0
	RJMP LOAD_PATTERN
LOAD_DIG1:
	LDS R18, DIG1
	RJMP LOAD_PATTERN
LOAD_DIG2:
	LDS R18, DIG2
	RJMP LOAD_PATTERN
LOAD_DIG3:
	LDS R18, DIG3

LOAD_PATTERN:
	;Apuntamos a la tabla que está en la memoria flash
	LDI ZH, HIGH(tabla_7seg << 1)
	LDI ZL, LOW(tabla_7seg << 1)

	ADD ZL, R18
	ADC ZH, R1

	LPM R16, Z
	OUT PORTD, R16

	MOV R18, R17
	LDI R19, 1

SHIFT:
	CPI R18, 0
	BREQ ACT
	LSL R19 
	DEC R18
	RJMP SHIFT

ACT:
    IN   R16, PORTB
    ANDI R16, 0b11110000
    OR   R16, R19
    OUT  PORTB, R16

    ; Incrementar índice
    LDS  R17, DIGIT_INDEX
    INC  R17
    CPI  R17, MAX_DIG
    BRLO STORE_INDEX
    CLR  R17

STORE_INDEX:
	STS DIGIT_INDEX, R17

; CONTADOR DE 1 SEGUNDO

    LDS R18, MILISEC_L
    LDS R19, MILISEC_H

    INC R18
    BRNE NO_CARRY
    INC R19
NO_CARRY:

    STS MILISEC_L, R18
    STS MILISEC_H, R19

    ; Comparar contra 1000 (0x03E8)
    LDI R16, LOW(1000)
    CP  R18, R16
    LDI R16, HIGH(1000)
    CPC R19, R16
    BRNE END_SECOND

    ; Reset contador
    CLR R18
    CLR R19
    STS MILISEC_L, R18
    STS MILISEC_H, R19

    ; Toggle PB4 y PB5
    IN  R16, PORTB

	SBRS R16, PB4
	RJMP LED_2

	CBI PORTB, PB4
	SBI PORTB, PB5
	RJMP END_SECOND

	LED_2:
	SBI PORTB, PB4
	CBI PORTB, PB5

END_SECOND:


	;Restaurar registros

	POP ZH
	POP ZL
	POP R19
	POP R18
	POP R17
	POP R16

	RETI
/****************************************/
tabla_7seg:
    .db 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F

