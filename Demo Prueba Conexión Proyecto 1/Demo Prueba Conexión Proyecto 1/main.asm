.include "M328PDEF.inc"

.dseg
.org SRAM_START
digit_index:   .byte 1
msL:           .byte 1
msH:           .byte 1

.cseg
.org 0x0000
    RJMP RESET

.org OC0Aaddr
    RJMP TIMER_ISR

RESET:

    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    CLR R1

    ; Inicializar variables
    LDI R16, 0
    STS digit_index, R16
    STS msL, R16
    STS msH, R16

    ; Segmentos salida
    LDI R16, 0b01111111
    OUT DDRD, R16

    ; Dígitos + LEDs salida
    LDI R16, 0b00111111
    OUT DDRB, R16

    CLR R16
    OUT PORTD, R16
    OUT PORTB, R16

    ; Timer0 CTC 1ms
    LDI R16, (1<<WGM01)
    OUT TCCR0A, R16

    LDI R16, (1<<CS01)|(1<<CS00)
    OUT TCCR0B, R16

    LDI R16, 249
    OUT OCR0A, R16

    LDI R16, (1<<OCIE0A)
    STS TIMSK0, R16

    SEI

MAIN:
    RJMP MAIN

;========================
; ISR
;========================
TIMER_ISR:

    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19

    ; Apagar dígitos
    IN R16, PORTB
    ANDI R16, 0b11110000
    OUT PORTB, R16

    ; Cargar índice
    LDS R17, digit_index

    ; Mostrar número fijo según índice
    CPI R17, 0
    BREQ SHOW1
    CPI R17, 1
    BREQ SHOW2
    CPI R17, 2
    BREQ SHOW3
    RJMP SHOW4

SHOW1:
    LDI R16, 0b00000110 ; 1
    RJMP DISPLAY

SHOW2:
    LDI R16, 0b01011011 ; 2
    RJMP DISPLAY

SHOW3:
    LDI R16, 0b01001111 ; 3
    RJMP DISPLAY

SHOW4:
    LDI R16, 0b01100110 ; 4

DISPLAY:
    OUT PORTD, R16

    ; Activar dígito
    LDI R18, 1
SHIFT:
    CPI R17, 0
    BREQ ACT
    LSL R18
    DEC R17
    RJMP SHIFT

ACT:
    IN R16, PORTB
    ANDI R16, 0b11110000
    OR R16, R18
    OUT PORTB, R16

    ; Incrementar índice
    LDS R16, digit_index
    INC R16
    CPI R16, 4
    BRLO SAVE
    CLR R16
SAVE:
    STS digit_index, R16

    ; 500ms LEDs
    LDS R18, msL
    LDS R19, msH

    INC R18
    BRNE NO_C
    INC R19
NO_C:

    STS msL, R18
    STS msH, R19

    LDI R16, LOW(500)
    CP R18, R16
    LDI R16, HIGH(500)
    CPC R19, R16
    BRNE END_ISR

    CLR R18
    CLR R19
    STS msL, R18
    STS msH, R19

    IN R16, PORTB
    LDI R17, (1<<PB4)|(1<<PB5)
    EOR R16, R17
    OUT PORTB, R16

END_ISR:
    POP R19
    POP R18
    POP R17
    POP R16
    RETI