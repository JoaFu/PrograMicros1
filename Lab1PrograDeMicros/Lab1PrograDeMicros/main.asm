/*
* Contador4Bits.asm
*
* Creado: 6 de febrero del 2026
* Autor : Joaquín Fuentes
* Descripción:
* Contador binario de 4 bits con incremento y decremento
* mediante dos pushbuttons con antirrebote por software
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
SETUP:
    ; -------- ENTRADAS --------
    ; PD2–PD5 entradas
    CBI DDRD, DDD2
    CBI DDRD, DDD3
    CBI DDRD, DDD4
    CBI DDRD, DDD5

    ; Pull-ups
    LDI R16, (1<<PD2)|(1<<PD3)|(1<<PD4)|(1<<PD5)
    OUT PORTD, R16

    ; -------- SALIDAS --------
    ; PORTB completo
    LDI R16, 0xFF
    OUT DDRB, R16
    CLR R16
    OUT PORTB, R16

    ; -------- INICIAL --------
    CLR R20        ; contador 1
    CLR R21        ; contador 2
    IN  R16, PIND  ; estado previo

MAIN:
    IN  R17, PIND
    CP  R17, R16
    BREQ MAIN

    RCALL DELAY

    IN  R18, PIND
    CP  R18, R17
    BRNE MAIN

    MOV R16, R17

    ; ---- CONTADOR 1 ----
    ; PD2 suma
    SBRS R17, PD2
    INC R20

    ; PD3 resta
    SBRS R17, PD3
    DEC R20

    ; ---- CONTADOR 2 ----
    ; PD4 suma
    SBRS R17, PD4
    INC R21

    ; PD5 resta
    SBRS R17, PD5
    DEC R21

    ; limitar a 4 bits
    ANDI R20, 0x0F
    ANDI R21, 0x0F

    ; ---- SALIDA ----
    MOV R22, R21
    SWAP R22
    ANDI R22, 0xF0
    OR   R22, R20
    OUT  PORTB, R22

    RJMP MAIN

; --------------------------
DELAY:
    LDI R19, 255
D1:
    DEC R19
    BRNE D1
    RET