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
SECS:			.byte 1
MINS:			.byte 1
HOURS:			.byte 1
DAY:			.byte 1
MONTH:			.byte 1
ALARM_MIN:		.byte 1
ALARM_HOUR:		.byte 1
ALARM_ON:		.byte 1
FLAG_1S:			.byte 1

.equ MAX_DIG	= 4
.equ MAX_MODES  = 3
.def MODE		= R23
.def FLAG_PC0	= R21
.def COUNTER_S	= R20
.def COUNTER_M  = R22
.def COUNTER_H  = R24

.cseg
.org 0x0000
    RJMP RESET

.org PCI1addr
	RJMP PCINT8_ISR

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

	LDI R16, 0
	STS DIG0, R16
	STS DIG1, R16
	STS DIG2, R16
	STS DIG3, R16
	STS SECS, R16
	STS MINS, R16
	STS HOURS, R16


	; Botones 
	LDI R16, 0x00
	OUT DDRC, R16

	LDI R16, (1<<PC0)|(1<<PC1)|(1<<PC2)|(1<<PC3)
	OUT PORTC, R16

	; Habilitar PCINT grupo 1
	LDI R16, (1<<PCIE1)
	STS PCICR, R16

	; Habilitar PCINT8 (PC0)
	LDI R16, (1<<PCINT8)
	STS PCMSK1, R16

    ; Segmentos salida
    LDI R16, 0b01111111
    OUT DDRD, R16

    ; Dígitos + LEDs salida
    LDI R16, 0b00111111
    OUT DDRB, R16

	; Empezamos apagados
    CLR R16
	CLR FLAG_PC0
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
	LDS R16, FLAG_1S
	CPI R16, 1
	BRNE MAIN_LOOP
	
	CLR R16
	STS FLAG_1S, R16
	RCALL UPDATE_CLOCK
	RCALL UPDATE_DISPLAY
	RJMP MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines
UPDATE_CLOCK:
	PUSH R16
	PUSH R17
	PUSH R18

	; Incrementar segundos
    LDS R16, SECS
    INC R16
    CPI R16, 60
    BRSH SEC_OVERFLOW
    RJMP STORE_SECS
SEC_OVERFLOW:
    CLR R16

    ; Incrementar minutos
    LDS R17, MINS
    INC R17
    CPI R17, 60
    BRSH MIN_OVERFLOW
    RJMP STORE_MINS_SKIP
MIN_OVERFLOW:
    CLR R17

    ; Incrementar horas
    LDS R18, HOURS
    INC R18
    CPI R18, 24
    BRSH HOUR_OVERFLOW
    RJMP STORE_HOURS_SKIP
HOUR_OVERFLOW:
    CLR R18

STORE_HOURS_SKIP:
    STS HOURS, R18

STORE_MINS_SKIP:
    STS MINS, R17

STORE_SECS:
    STS SECS, R16

    POP R18
    POP R17
    POP R16
    RET

UPDATE_DISPLAY:

    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19
/******HOURS******/
    LDS R16, HOURS
    CLR R17          ; decenas

DIV_H:
    CPI R16, 10
    BRLO DIV_H_DONE
    SUBI R16, 10
    INC R17
    RJMP DIV_H

DIV_H_DONE:
    STS DIG0, R17    ; decenas hora
    STS DIG1, R16    ; unidades hora

/******MIN*******/

    LDS R16, MINS
    CLR R17

DIV_M:
    CPI R16, 10
    BRLO DIV_M_DONE
    SUBI R16, 10
    INC R17
    RJMP DIV_M

DIV_M_DONE:
    STS DIG2, R17    ; decenas minuto
    STS DIG3, R16    ; unidades minuto

    POP R19
    POP R18
    POP R17
    POP R16
    RET
/****************************************/
// Interrupt routines

PCINT8_ISR:
	PUSH R16
	AND FLAG_PC0, FLAG_PC0
	BRNE EXIT_PCINT1

	LDI FLAG_PC0, 1

EXIT_PCINT1:
	POP R16
	RETI

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

	NOP
	NOP

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

; Contador de 1s
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
    BRNE END_T0ISR

    ; Reset contador
    CLR R18
    CLR R19
    STS MILISEC_L, R18
    STS MILISEC_H, R19

	; Activar FLAG_1S
    LDI R16, 1
    STS FLAG_1S, R16
END_T0ISR:
	;Restaurar 
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

