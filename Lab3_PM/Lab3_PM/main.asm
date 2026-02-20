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

.org 0x0020     ; TIMER0_OVF
    RJMP TIMER0_ISR
 /****************************************/
RESET:
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
SETUP:

	; Entradas
	CBI DDRB, DDB0
	CBI DDRB, DDB1
	SBI PORTB, PB0
	SBI PORTB, PB1 

	;Leds-Contador
	LDI R16, 0b00111100
	OUT DDRB, R16

	;Displays en PORTD
	LDI R16, 0b01111111
	OUT DDRD, R16

	LDI R16, (1<<PC0|1<<PC1) ; A0, A1 para transistores
	OUT DDRC, R16

	; Activar PCINT0 y PCINT1 (PB0 y PB1)						
	LDI R16, (1<<PCINT0)|(1<<PCINT1)
	STS PCMSK0, R16

	; Habilitar grupo PCINT0
	LDI R16, (1<<PCIE0)
	STS PCICR, R16

	LDI R16, (1<<TOIE0)
	STS TIMSK0, R16

	CLR R20 ; Contador
	CLR R21 ; Bandera de antirebote

	SEI

    
/****************************************/
// Loop Infinito
MAIN_LOOP:
	; Mostrar LEDS

	IN R16, PORTB
	ANDI R16, 0b11000011
	MOV R18, R20 ; R18 toma el valor del contador, pero habrá que moverlo porque es de PB2-PB5
	LSL R18 ;<-
	LSL R18 ;<--
	OR R16, R18 
	OUT PORTB, R16

    RJMP    MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines

/****************************************/
// Interrupt routines
PCINT0_ISR:

	PUSH R16 ; Guardamos

	AND R21, R21; ¿R21=0?
	BRNE EXIT_ISR
	
	LDI R21, 1 ;Bandera forzada

	LDI R16, 0x00
	STS PCICR, R16

	CLR R16
	OUT TCNT0, R16
	;INICIAR Timer0
	LDI R16, (1<<CS02|1<<CS00); Presecaler de 1024
	OUT TCCR0B, R16

EXIT_ISR:
	POP R16
	RETI

TIMER0_ISR:
	PUSH R16

	;Detenemos el timer
	LDI R16, 0x00
	OUT TCCR0B, R16
	CLR R16
	OUT TCNT0, R16

	IN R16, PINB ;Leer estado actual
	ANDI R16, (1<<PB0|1<<PB1)
	MOV R17, R16
	
	EOR R16, R22

	; ¿Cambió PB0?
    SBRS R16, PB0
    RJMP CHECK_PB1
    INC R20

CHECK_PB1:
    SBRS R16, PB1
    RJMP END_ISR
    DEC R20

END_ISR:
    ANDI R20, 0x0F

    ; Guardar nuevo estado
    MOV R22, R17

	;Activamos de nuevo PCINT
	LDI	 R16, (1<<PCIE0)
	STS PCICR, R16
	CLR R21

	POP R16
	RETI
/****************************************/