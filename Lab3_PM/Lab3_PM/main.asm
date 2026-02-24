/*
* Lab3_PM.asm
*
* Creado: 19-02-2026
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
    RJMP RESET

.org 0x0006
    RJMP PCINT0_ISR

.org 0x0020
    RJMP TIMER0_ISR

/****************************************/
// Configuración de la pila
RESET:
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R16, HIGH(RAMEND)
OUT SPH, R16

/****************************************/
// Configuracion MCU
SETUP:

    ; Botones PB0 PB1
    CBI DDRB, DDB0
    CBI DDRB, DDB1
    SBI PORTB, PB0
    SBI PORTB, PB1

    ; LEDs PB2–PB5
    LDI R16, 0b00111100
    OUT DDRB, R16

    ; Display PORTD
    LDI R16, 0x7F
    OUT DDRD, R16

    ; PCINT botones
    LDI R16, (1<<PCINT0)|(1<<PCINT1)
    STS PCMSK0, R16

    LDI R16, (1<<PCIE0)
    STS PCICR, R16

    ; Timer0 overflow interrupt
    LDI R16, (1<<TOIE0)
    STS TIMSK0, R16

    ; Prescaler 1024
    LDI R16, (1<<CS02)|(1<<CS00)
    OUT TCCR0B, R16

    ; Recarga ~10 ms
    LDI R16, 100
    OUT TCNT0, R16

	; A0 y A1 como salida (control transistores displays)
	SBI DDRC, DDC0
	SBI DDRC, DDC1

    ; Registros
    CLR R20	; contador LEDs
    CLR R21 ; bandera debounce
    CLR R22 ; acumulador 10 ms
    CLR R23 ; contador 1000 ms
    CLR R24 ; contador hexadecimal tiempo
	CLR R25 ; contador de decenas
	CLR R19 ; bandera multiplexado (0=unidades,1=decenas)
    SEI

/****************************************/
MAIN_LOOP:

    ; LEDs PB2–PB5 (solo botones)
    IN R16, PORTB
    ANDI R16, 0b11000011

    MOV R18, R20 ; Guardamos el contador
    LSL R18	;<-
    LSL R18 ;<--

    OR R16, R18
    OUT PORTB, R16

	CPI R19, 0
	BREQ SHOW_UNITS

	MOV R16, R25    ; mostrar decenas
	RJMP SHOW_NUMBER

	SHOW_UNITS:
	MOV R16, R24    ; mostrar unidades

	SHOW_NUMBER:

    CPI R16, 0x00
    BREQ SHOW0
    CPI R16, 0x01
    BREQ SHOW1
    CPI R16, 0x02
    BREQ SHOW2
    CPI R16, 0x03
    BREQ SHOW3
    CPI R16, 0x04
    BREQ SHOW4
    CPI R16, 0x05
    BREQ SHOW5
    CPI R16, 0x06
    BREQ SHOW6
    CPI R16, 0x07
    BREQ SHOW7
    CPI R16, 0x08
    BREQ SHOW8
    CPI R16, 0x09
    BREQ SHOW9
    CPI R16, 0x0A
    BREQ SHOWA
    CPI R16, 0x0B
    BREQ SHOWB
    CPI R16, 0x0C
    BREQ SHOWC
    CPI R16, 0x0D
    BREQ SHOWD
    CPI R16, 0x0E
    BREQ SHOWE
    RJMP SHOWF

//	Display

SHOW0: 
	LDI R26, 0b00111111 
    RJMP SHOWN
SHOW1: 
	LDI R26, 0b00000110 
    RJMP SHOWN
SHOW2: 
	LDI R26, 0b01011011 
    RJMP SHOWN
SHOW3: 
	LDI R26, 0b01001111 
    RJMP SHOWN
SHOW4: 
	LDI R26, 0b01100110 
    RJMP SHOWN
SHOW5: 
	LDI R26, 0b01101101 
    RJMP SHOWN
SHOW6: 
	LDI R26, 0b01111101 
    RJMP SHOWN
SHOW7: 
	LDI R26, 0b00000111 
    RJMP SHOWN
SHOW8: 
	LDI R26, 0b01111111 
    RJMP SHOWN
SHOW9: 
	LDI R26, 0b01101111 
	RJMP SHOWN
SHOWA: 
	LDI R26, 0b01110111 
    RJMP SHOWN
SHOWB: 
	LDI R26, 0b01111100 
    RJMP SHOWN
SHOWC: 
	LDI R26, 0b00111001 
    RJMP SHOWN
SHOWD: 
	LDI R26, 0b01011110 
	RJMP SHOWN
SHOWE: 
	LDI R26, 0b01111001 
    RJMP SHOWN
SHOWF: 
	LDI R26, 0b01110001

SHOWN:
    ; 1. Apagar ambos displays
    CBI PORTC, PC0
    CBI PORTC, PC1

    ; 2. Pequeño delay para que el TIP se apague
    NOP
    NOP
    NOP
    NOP

    ; 3. Cargar segmentos
    OUT PORTD, R26

    ; 4. Activar display correcto
    CPI R19, 0
    BREQ ENABLE_UNITS

    SBI PORTC, PC1     ; decenas
    RJMP END_ENABLE

ENABLE_UNITS:
    SBI PORTC, PC0     ; unidades

END_ENABLE:
    RJMP MAIN_LOOP

// Interrupt routines
PCINT0_ISR:
    PUSH R16

    AND R21, R21 ; ¿R21=0?
    BRNE EXIT_PCINT

    LDI R21, 1 ;Bandera Forzada Debounce
    CLR R23

EXIT_PCINT:
    POP R16
    RETI

TIMER0_ISR:
    PUSH R16

	;Alternar displays
	INC R19
    ANDI R19, 0x01

    ; Recarga 10 ms
    LDI R16, 100
    OUT TCNT0, R16

	; Contamos el tiempo (timer)
    INC R22
    CPI R22,  100
    BRNE SECOND_GOT

    CLR R22
    
	;Cuenta decimal
	INC R24            ; incrementa unidades

	CPI R24, 10        ; ¿llegó a 10?
	BRNE CHECK_60

	CLR R24            ; reset unidades
	INC R25            ; incrementa decenas

	CHECK_60:
	CPI R25, 6         ; ¿llegó a 6 decenas? (60s)
	BRNE CONTINUE_TIMER

	CLR R25
	CLR R24            ; reset total

CONTINUE_TIMER:

SECOND_GOT:
    AND R21, R21
    BREQ END_TIMER

    INC R23
    CPI R23, 2
    BRNE END_TIMER

    CLR R21

    IN R16, PINB
    ANDI R16, (1<<PB0)|(1<<PB1)

    SBRS R16, PB0
    INC R20

    SBRS R16, PB1
    DEC R20

    ANDI R20, 0x0F

END_TIMER:
    POP R16
    RETI
/****************************************/