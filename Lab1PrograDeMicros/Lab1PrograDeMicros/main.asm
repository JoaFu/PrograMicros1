/*
* Contador4Bits.asm
*
* Creado:
* Autor :
* Descripción:
* Contador binario de 4 bits con incremento y decremento
* mediante dos pushbuttons con antirrebote por software
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Definiciones ATmega328P

.def contador = R16
.def temp     = R17

/****************************************/
// Segmento de datos
.dseg
.org SRAM_START
// (No se usan variables en SRAM)

/****************************************/
// Segmento de código
.cseg
.org 0x0000
    RJMP RESET

/****************************************/
// Configuración de la pila
RESET:
    LDI     temp, LOW(RAMEND)
    OUT     SPL, temp
    LDI     temp, HIGH(RAMEND)
    OUT     SPH, temp

/****************************************/
// Configuración MCU
SETUP:
    ; PORTB[3:0] como salida
    LDI     temp, 0x0F
    OUT     DDRB, temp

    ; PORTD como entrada
    CLR     temp
    OUT     DDRD, temp

    ; Pull-up en PD2 y PD3
    LDI     temp, (1<<PD2)|(1<<PD3)
    OUT     PORTD, temp

    ; Inicializar contador
    CLR     contador

/****************************************/
// Loop Infinito
MAIN_LOOP:
    ; Mostrar contador en PORTB
    MOV     temp, contador
    OUT     PORTB, temp

    ; Botón incrementar (PD2)
    SBIS    PIND, PD2
    RCALL   DEBOUNCE_INC

    ; Botón decrementar (PD3)
    SBIS    PIND, PD3
    RCALL   DEBOUNCE_DEC

    RJMP    MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines

; ---- Antirrebote + incremento ----
DEBOUNCE_INC:
    RCALL   DELAY
    SBIS    PIND, PD2
    RCALL   INCREMENTA
WAIT_INC:
    SBIC    PIND, PD2
    RJMP    WAIT_INC
    RET

; ---- Antirrebote + decremento ----
DEBOUNCE_DEC:
    RCALL   DELAY
    SBIS    PIND, PD3
    RCALL   DECREMENTA
WAIT_DEC:
    SBIC    PIND, PD3
    RJMP    WAIT_DEC
    RET

; ---- Incrementar contador ----
INCREMENTA:
    INC     contador
    CPI     contador, 16
    BRLO    INC_OK
    CLR     contador
INC_OK:
    RET

; ---- Decrementar contador ----
DECREMENTA:
    TST     contador
    BRNE    DEC_OK
    LDI     contador, 15
    RET
DEC_OK:
    DEC     contador
    RET

; ---- Retardo (antirrebote) ----
DELAY:
    LDI     R18, 100
D1:
    LDI     R19, 255
D2:
    DEC     R19
    BRNE    D2
    DEC     R18
    BRNE    D1
    RET

/****************************************/
// Interrupt routines
; (No se utilizan interrupciones)
/*****************************
