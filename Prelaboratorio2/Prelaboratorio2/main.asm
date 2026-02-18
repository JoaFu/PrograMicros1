/*
* Laboratorio2_PrograMicros.asm
*
* Creado: 17-feb-2026 
* Autor : Joaquín Fuentes 24830
* Descripción: Genera una base de tiempo 100ms con Timer0, usa botones con detección de flanco para seleccionar un valor hexadecimal mostrado en el display.
				Dicho valor controla cada cuantos segundos cambia el estado de una led en D12.
*/
/****************************************/
/// Encabezado (Definición de Registros, Variables y Constantes)
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
    ; ---- Botones PD2 (INC) y PD3 (DEC) ----
    CBI DDRD, DDD2
    CBI DDRD, DDD3
    SBI PORTD, PORTD2
    SBI PORTD, PORTD3
	; ---- LEDs binarios PB0–PB3 ----
	LDI R16, 0x0F
	OUT DDRB, R16

	; ---- LED alarma en PB4 ----
	SBI DDRB, DDB4

    ; ---- Display PC0–PC5 ----
    LDI R16, 0x3F
    OUT DDRC, R16

    ; ---- Segmento g en PD4 ----
    SBI DDRD, DDD4

    ; ---- Timer0 modo normal ----
    LDI R16, 0x00
    OUT TCCR0A, R16
    LDI R16, (1<<CS02)|(1<<CS00)   ; prescaler 1024
    OUT TCCR0B, R16

    CLR R17		; contador de overflows
    CLR R18		; contador automático
    CLR R20     ; contador manual
	CLR R19     ; contador de décimas
	CLR R21     ; contador de segundos

    ; guardar estado inicial botones
    IN R22, PIND
    ANDI R22, 0b00001100

MAIN:
    RCALL CONTADOR_MANUAL
    RCALL MOSTRAR_DIS
    RCALL CONTADOR_AUTO
    RJMP MAIN

CONTADOR_MANUAL:

    IN R26, PIND
    ANDI R26, 0b00001100
    CP R26, R22
    BREQ CM_FIN

    RCALL DELAY_10MS

    IN R26, PIND
    ANDI R26, 0b00001100
    CP R26, R22
    BREQ CM_FIN

	; === PD2 incremento ===
    SBRS R22, PD2      ; si antes NO era 1 ? saltar
    RJMP CHECK_PD3
    SBRS R26, PD2      ; si ahora es 1 ? saltar
    RJMP INC_MANUAL    ; si ahora es 0 ? flanco descendente

CHECK_PD3:
	; === PD3 decremento ===
    SBRS R22, PD3
    RJMP UPDATE_STATE
    SBRS R26, PD3
    RJMP DEC_MANUAL

UPDATE_STATE:
    MOV R22, R26
    RET

INC_MANUAL:
    INC R20
    ANDI R20, 0x0F
    MOV R22, R26
    RET

DEC_MANUAL:
    DEC R20
    ANDI R20, 0x0F
    MOV R22, R26
    RET

CM_FIN:			;Contador Manual Final
    RET

CONTADOR_AUTO:

    IN R16, TIFR0
    SBRS R16, TOV0
    RET

    SBI TIFR0, TOV0

    INC R17
    CPI R17, 6
    BRNE CA_FIN

    CLR R17

   

    ; ---- contar décimas ----
    INC R19
    CPI R19, 10
    BRNE CA_FIN

    CLR R19

    ; ---- contar segundos ----
    INC R21
    ANDI R21, 0x0F

	IN R16, PORTB
    ANDI R16, 0b11110000
    OR R16, R21
    OUT PORTB, R16

    CP R21, R20
    BRNE CA_FIN

    CLR R21
    SBI PINB, PINB4

CA_FIN:			;Contador Automático Final
    RET


MOSTRAR_DIS:
	; Lista de casos con comparaciones. Si R20=N => SHOWN.
    ANDI R20, 0x0F

    CPI R20, 0
    BREQ SHOW0
    CPI R20, 1
    BREQ SHOW1
    CPI R20, 2
    BREQ SHOW2
    CPI R20, 3
    BREQ SHOW3
    CPI R20, 4
    BREQ SHOW4
    CPI R20, 5
    BREQ SHOW5
    CPI R20, 6
    BREQ SHOW6
    CPI R20, 7
    BREQ SHOW7
    CPI R20, 8
    BREQ SHOW8
    CPI R20, 9
    BREQ SHOW9
    CPI R20, 10
    BREQ SHOWA
    CPI R20, 11
    BREQ SHOWb
    CPI R20, 12
    BREQ SHOWC
    CPI R20, 13
    BREQ SHOWd
    CPI R20, 14
    BREQ SHOWE
    CPI R20, 15
    BREQ SHOWF

    RET

SHOW0: LDI R23, 0b00111111 ;0
       RJMP SHOWN
SHOW1: LDI R23, 0b00000110 ;1
       RJMP SHOWN
SHOW2: LDI R23, 0b01011011 ;2
       RJMP SHOWN
SHOW3: LDI R23, 0b01001111 ;3
       RJMP SHOWN
SHOW4: LDI R23, 0b01100110 ;4
       RJMP SHOWN
SHOW5: LDI R23, 0b01101101 ;5
       RJMP SHOWN
SHOW6: LDI R23, 0b01111101 ;6
       RJMP SHOWN
SHOW7: LDI R23, 0b00000111 ;7
       RJMP SHOWN
SHOW8: LDI R23, 0b01111111 ;8
       RJMP SHOWN
SHOW9: LDI R23, 0b01101111 ;9
       RJMP SHOWN
SHOWA: LDI R23, 0b01110111 ;A
       RJMP SHOWN
SHOWb: LDI R23, 0b01111100 ;b
       RJMP SHOWN
SHOWC: LDI R23, 0b00111001 ;C
       RJMP SHOWN
SHOWd: LDI R23, 0b01011110 ;d
       RJMP SHOWN
SHOWE: LDI R23, 0b01111001 ;E
       RJMP SHOWN
SHOWF: LDI R23, 0b01110001 ;F
       RJMP SHOWN

SHOWN:

    ; segmento g (bit 6)
    SBRS R23, 6
    CBI PORTD, PORTD4
    SBRC R23, 6
    SBI PORTD, PORTD4

    ; a–f
    ANDI R23, 0b00111111
    OUT PORTC, R23

    RET

DELAY_10MS:
    LDI R24, 200
D1:
    LDI R25, 200
D2:
    DEC R25
    BRNE D2
    DEC R24
    BRNE D1
    RET
