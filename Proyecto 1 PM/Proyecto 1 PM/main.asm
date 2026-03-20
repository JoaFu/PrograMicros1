/*
* Proyecto 1 Progra Micros
*
* Creado: 27-02-2026
* Autor : Joaquín Fuentes
* Descripción: Reloj digital con alarma, fecha y configuración
*              de hora/fecha/alarma mediante 4 botones.
*
* PINES:
*   PC0 = B1 - Cambiar modo
*   PC1 = B2 - UP  (incrementar)
*   PC2 = B3 - DOWN (decrementar)
*   PC3 = B4 - SELECT (alternar horas<->minutos / día<->mes)
*   PC4 = LED indicador modo configuración
*   PC5 = LED indicador alarma activa
*
* MODOS:
*   MODE 0 = Display Hora  (HH:MM)
*   MODE 1 = Display Fecha (DD/MM)
*   MODE 2 = Config Hora
*   MODE 3 = Config Fecha
*   MODE 4 = Config Alarma
*   MODE 5 = Apagar Alarma -> regresa a MODE 0
*/
/****************************************/
.include "M328PDEF.inc"

.dseg
.org SRAM_START

DIGIT_INDEX:        .byte 1
DIG0:               .byte 1
DIG1:               .byte 1
DIG2:               .byte 1
DIG3:               .byte 1
MILISEC_L:          .byte 1
MILISEC_H:          .byte 1
SECS:               .byte 1
MINS:               .byte 1
HOURS:              .byte 1
DAY:                .byte 1
MONTH:              .byte 1
ALARM_MIN:          .byte 1
ALARM_HOUR:         .byte 1
ALARM_ON:           .byte 1     ; 1 = alarma configurada y activa
BUZZER_ON:          .byte 1     ; 1 = buzzer sonando
FLAG_1S:            .byte 1
FLAG_500MS:         .byte 1
FLAG_BTN_UP:        .byte 1     ; PC1 confirmado
FLAG_BTN_DOWN:      .byte 1     ; PC2 confirmado
FLAG_BTN_SEL:       .byte 1     ; PC3 confirmado
DEBOUNCE_COUNT_0:   .byte 1
DEBOUNCE_COUNT_1:   .byte 1
DEBOUNCE_COUNT_2:   .byte 1
DEBOUNCE_COUNT_3:   .byte 1
FLAG_DEBOUNCE_0:    .byte 1     ; PC0
FLAG_DEBOUNCE_1:    .byte 1     ; PC1
FLAG_DEBOUNCE_2:    .byte 1     ; PC2
FLAG_DEBOUNCE_3:    .byte 1     ; PC3
CONFIG_SUB:         .byte 1     ; 0=horas/día, 1=minutos/mes
BLINK_HIDE:         .byte 1     ; 1=ocultar dígito activo (parpadeo config)

; Días máximos por mes en flash (ver tabla_dias_mes en cseg)

.equ MAX_DIG    = 4
.equ MAX_MODES  = 6

.def MODE       = R23
.def FLAG_PC0   = R21
.def FLAG_PC1   = R22
.def FLAG_PC2   = R20
.def FLAG_PC3   = R19

/****************************************/
.cseg
.org 0x0000
    RJMP RESET

.org PCI1addr
    RJMP PCINT8_ISR

.org OC0Aaddr
    RJMP TIMER_ISR

/****************************************/
RESET:
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

SETUP:
    CLR R1

    LDI R16, 0
    STS DIGIT_INDEX,     R16
    STS MILISEC_L,       R16
    STS MILISEC_H,       R16
    STS DIG0,            R16
    STS DIG1,            R16
    STS DIG2,            R16
    STS DIG3,            R16
    STS SECS,            R16
    STS MINS,            R16
    STS HOURS,           R16
    STS ALARM_MIN,       R16
    STS ALARM_HOUR,      R16
    STS ALARM_ON,        R16
    STS BUZZER_ON,       R16
    STS FLAG_BTN_UP,     R16
    STS FLAG_BTN_DOWN,   R16
    STS FLAG_BTN_SEL,    R16
    STS FLAG_DEBOUNCE_0, R16
    STS FLAG_DEBOUNCE_1, R16
    STS FLAG_DEBOUNCE_2, R16
    STS FLAG_DEBOUNCE_3, R16
    STS DEBOUNCE_COUNT_0,R16
    STS DEBOUNCE_COUNT_1,R16
    STS DEBOUNCE_COUNT_2,R16
    STS DEBOUNCE_COUNT_3,R16
    STS CONFIG_SUB,      R16
    STS BLINK_HIDE,      R16

    ; Fecha inicial 01/01
    LDI R16, 1
    STS DAY,   R16
    STS MONTH, R16

    ; PC0-PC3 entradas, PC4-PC5 salidas (LEDs)
    LDI R16, (1<<PC4)|(1<<PC5)
    OUT DDRC, R16

    ; Pull-ups en PC0-PC3
    LDI R16, (1<<PC0)|(1<<PC1)|(1<<PC2)|(1<<PC3)
    OUT PORTC, R16

    ; Habilitar PCINT grupo 1
    LDI R16, (1<<PCIE1)
    STS PCICR, R16

    ; Habilitar PCINT8-PCINT11 (PC0-PC3)
    LDI R16, (1<<PCINT8)|(1<<PCINT9)|(1<<PCINT10)|(1<<PCINT11)
    STS PCMSK1, R16

    ; PORTD = segmentos salida
    LDI R16, 0b11111111
    OUT DDRD, R16

    ; PORTB bits 0-3 = transistores dígitos, bits 4-5 = LEDs segundos
    LDI R16, 0b00111111
    OUT DDRB, R16

    CLR R16
    OUT PORTD, R16
    OUT PORTB, R16

    ; Timer0 CTC 1ms (16MHz, prescaler 64, OCR0A=249)
    LDI R16, (1<<WGM01)
    OUT TCCR0A, R16
    LDI R16, (1<<CS01)|(1<<CS00)
    OUT TCCR0B, R16
    LDI R16, 249
    OUT OCR0A, R16
    LDI R16, (1<<OCIE0A)
    STS TIMSK0, R16

    CLR MODE

    ; Leer estado inicial de botones tras activar pull-ups
    IN  R16, PINC
    MOV R18, R16
    ANDI R18, (1<<PC0)
    MOV  FLAG_PC0, R18
    MOV  R18, R16
    ANDI R18, (1<<PC1)
    MOV  FLAG_PC1, R18
    MOV  R18, R16
    ANDI R18, (1<<PC2)
    MOV  FLAG_PC2, R18
    MOV  R18, R16
    ANDI R18, (1<<PC3)
    MOV  FLAG_PC3, R18

    SEI

/****************************************/
MAIN_LOOP:
    RCALL LOGIC_500MS
    RCALL LOGIC_1S
    ; Solo verificar alarma en modos de display
    CPI MODE, 0
    BREQ DO_CHECK_ALARM
    CPI MODE, 2
    BRNE SKIP_CHECK_ALARM
DO_CHECK_ALARM:
    RCALL CHECK_ALARM
SKIP_CHECK_ALARM:
    RJMP  FSM

/****************************************/
LOGIC_500MS:
    PUSH R16
    PUSH R17

    LDS R16, FLAG_500MS
    CPI R16, 1
    BRNE EXIT_500MS

    CLR R16
    STS FLAG_500MS, R16

    ; Parpadeo LEDs de segundos (PB4, PB5)
    IN  R16, PORTB
    LDI R17, (1<<PB4)|(1<<PB5)
    EOR R16, R17
    OUT PORTB, R16

    ; Toggle BLINK_HIDE para parpadeo de dígito activo en config
    LDS R16, BLINK_HIDE
    LDI R17, 1
    EOR R16, R17
    STS BLINK_HIDE, R16

EXIT_500MS:
    POP R17
    POP R16
    RET

/****************************************/
LOGIC_1S:
    PUSH R16

    LDS R16, FLAG_1S
    CPI R16, 1
    BRNE EXIT_1S

    CLR R16
    STS FLAG_1S, R16

    ; Reloj avanza en MODE 0 (hora) y MODE 2 (fecha)
    CPI MODE, 0
    BREQ DO_UPDATE
    CPI MODE, 2
    BREQ DO_UPDATE
    RJMP EXIT_1S

DO_UPDATE:
    RCALL UPDATE_CLOCK

EXIT_1S:
    POP R16
    RET

/****************************************/
CHECK_ALARM:
    PUSH R16
    PUSH R17

    LDS R16, ALARM_ON
    CPI R16, 1
    BRNE EXIT_CHECK_ALARM

    LDS R16, HOURS
    LDS R17, ALARM_HOUR
    CP  R16, R17
    BRNE EXIT_CHECK_ALARM

    LDS R16, MINS
    LDS R17, ALARM_MIN
    CP  R16, R17
    BRNE EXIT_CHECK_ALARM

    ; Hora coincide: activar buzzer y ir a MODE 5
    LDI R16, 1
    STS BUZZER_ON, R16
    LDI MODE, 5

EXIT_CHECK_ALARM:
    POP R17
    POP R16
    RET

/****************************************/
UPDATE_CLOCK:
    PUSH R16
    PUSH R17
    PUSH R18

    LDS R16, SECS
    INC R16
    CPI R16, 60
    BRSH SEC_OVF
    RJMP STORE_SECS

SEC_OVF:
    CLR R16
    LDS R17, MINS
    INC R17
    CPI R17, 60
    BRSH MIN_OVF
    RJMP STORE_MINS

MIN_OVF:
    CLR R17
    LDS R18, HOURS
    INC R18
    CPI R18, 24
    BRSH HOUR_OVF
    RJMP STORE_HOURS

HOUR_OVF:
    CLR R18
    RCALL INC_DAY

STORE_HOURS:
    STS HOURS, R18
STORE_MINS:
    STS MINS, R17
STORE_SECS:
    STS SECS, R16

    POP R18
    POP R17
    POP R16
    RET

/****************************************/
INC_DAY:
    PUSH R16
    PUSH R17
    PUSH ZL
    PUSH ZH

    LDS R16, DAY
    INC R16
    RCALL GET_MAX_DAY       ; R17 = días máximos del mes actual
    CP   R16, R17
    BRLO STORE_INC_DAY
    BREQ STORE_INC_DAY      ; último día válido
    ; excedió el mes
    LDI  R16, 1
    LDS  R17, MONTH
    INC  R17
    CPI  R17, 13
    BRLO STORE_INC_MONTH
    LDI  R17, 1
STORE_INC_MONTH:
    STS  MONTH, R17
STORE_INC_DAY:
    STS  DAY, R16

    POP ZH
    POP ZL
    POP R17
    POP R16
    RET

/****************************************/
; GET_MAX_DAY: devuelve en R17 los días máximos del mes actual
GET_MAX_DAY:
    PUSH ZL
    PUSH ZH
    LDS  R17, MONTH
    LDI  ZH, HIGH(tabla_dias_mes << 1)
    LDI  ZL, LOW(tabla_dias_mes << 1)
    ADD  ZL, R17
    ADC  ZH, R1
    LPM  R17, Z
    POP  ZH
    POP  ZL
    RET

/****************************************/
FSM:
    CPI  MODE, 0
    BRNE FSM_NOT0
    RJMP MODE_HORA
FSM_NOT0:
    CPI  MODE, 1
    BRNE FSM_NOT1
    RJMP MODE_CONFIG_HORA
FSM_NOT1:
    CPI  MODE, 2
    BRNE FSM_NOT2
    RJMP MODE_FECHA
FSM_NOT2:
    CPI  MODE, 3
    BRNE FSM_NOT3
    RJMP MODE_CONFIG_FECHA
FSM_NOT3:
    CPI  MODE, 4
    BRNE FSM_NOT4
    RJMP MODE_CONFIG_ALARMA
FSM_NOT4:
    CPI  MODE, 5
    BRNE FSM_NOT5
    RJMP MODE_APAGAR_ALARMA
FSM_NOT5:
    RJMP MAIN_LOOP

MODE_HORA:
    RCALL LED_CONFIG_OFF
    RCALL UPDATE_LED_ALARMA
    RCALL DISPLAY_HORA
    RJMP MAIN_LOOP

MODE_FECHA:
    RCALL LED_CONFIG_OFF
    RCALL UPDATE_LED_ALARMA
    RCALL DISPLAY_FECHA
    RJMP MAIN_LOOP

MODE_CONFIG_HORA:
    RCALL LED_CONFIG_ON
    LDS R16, FLAG_BTN_UP
    CPI R16, 1
    BRNE CH_DOWN_HORA
    CLR R16
    STS FLAG_BTN_UP, R16
    LDS R16, CONFIG_SUB
    CPI R16, 0
    BREQ CH_UP_HOURS
    RCALL UP_MINS
    RJMP SHOW_CH
CH_UP_HOURS:
    RCALL UP_HOURS
    RJMP SHOW_CH
CH_DOWN_HORA:
    LDS R16, FLAG_BTN_DOWN
    CPI R16, 1
    BRNE CH_SEL_HORA
    CLR R16
    STS FLAG_BTN_DOWN, R16
    LDS R16, CONFIG_SUB
    CPI R16, 0
    BREQ CH_DOWN_HOURS
    RCALL DOWN_MINS
    RJMP SHOW_CH
CH_DOWN_HOURS:
    RCALL DOWN_HOURS
    RJMP SHOW_CH
CH_SEL_HORA:
    LDS R16, FLAG_BTN_SEL
    CPI R16, 1
    BRNE SHOW_CH
    CLR R16
    STS FLAG_BTN_SEL, R16
    LDS R16, CONFIG_SUB
    LDI R17, 1
    EOR R16, R17
    STS CONFIG_SUB, R16
SHOW_CH:
    RCALL DISPLAY_CONFIG_HORA
    RJMP MAIN_LOOP

MODE_CONFIG_FECHA:
    RCALL LED_CONFIG_ON
    LDS R16, FLAG_BTN_UP
    CPI R16, 1
    BRNE CF_DOWN_FECHA
    CLR R16
    STS FLAG_BTN_UP, R16
    LDS R16, CONFIG_SUB
    CPI R16, 0
    BREQ CF_UP_DAY
    RCALL UP_MONTH
    RJMP SHOW_CF
CF_UP_DAY:
    RCALL UP_DAY
    RJMP SHOW_CF
CF_DOWN_FECHA:
    LDS R16, FLAG_BTN_DOWN
    CPI R16, 1
    BRNE CF_SEL_FECHA
    CLR R16
    STS FLAG_BTN_DOWN, R16
    LDS R16, CONFIG_SUB
    CPI R16, 0
    BREQ CF_DOWN_DAY
    RCALL DOWN_MONTH
    RJMP SHOW_CF
CF_DOWN_DAY:
    RCALL DOWN_DAY
    RJMP SHOW_CF
CF_SEL_FECHA:
    LDS R16, FLAG_BTN_SEL
    CPI R16, 1
    BRNE SHOW_CF
    CLR R16
    STS FLAG_BTN_SEL, R16
    LDS R16, CONFIG_SUB
    LDI R17, 1
    EOR R16, R17
    STS CONFIG_SUB, R16
SHOW_CF:
    RCALL DISPLAY_CONFIG_FECHA
    RJMP MAIN_LOOP

MODE_CONFIG_ALARMA:
    RCALL LED_CONFIG_ON
    LDS R16, FLAG_BTN_UP
    CPI R16, 1
    BRNE CA_DOWN_ALARMA
    CLR R16
    STS FLAG_BTN_UP, R16
    LDS R16, CONFIG_SUB
    CPI R16, 0
    BREQ CA_UP_AHOUR
    RCALL UP_ALARM_MINS
    RJMP SHOW_CA
CA_UP_AHOUR:
    RCALL UP_ALARM_HOURS
    RJMP SHOW_CA
CA_DOWN_ALARMA:
    LDS R16, FLAG_BTN_DOWN
    CPI R16, 1
    BRNE CA_SEL_ALARMA
    CLR R16
    STS FLAG_BTN_DOWN, R16
    LDS R16, CONFIG_SUB
    CPI R16, 0
    BREQ CA_DOWN_AHOUR
    RCALL DOWN_ALARM_MINS
    RJMP SHOW_CA
CA_DOWN_AHOUR:
    RCALL DOWN_ALARM_HOURS
    RJMP SHOW_CA
CA_SEL_ALARMA:
    LDS R16, FLAG_BTN_SEL
    CPI R16, 1
    BRNE SHOW_CA
    CLR R16
    STS FLAG_BTN_SEL, R16
    LDS R16, CONFIG_SUB
    LDI R17, 1
    EOR R16, R17
    STS CONFIG_SUB, R16
SHOW_CA:
    RCALL DISPLAY_CONFIG_ALARMA
    RJMP MAIN_LOOP

MODE_APAGAR_ALARMA:
    RCALL LED_CONFIG_ON
    ; UP = activar alarma
    LDS R16, FLAG_BTN_UP
    CPI R16, 1
    BRNE MA_CHECK_DOWN
    CLR R16
    STS FLAG_BTN_UP, R16
    LDI R16, 1
    STS ALARM_ON, R16
    RCALL UPDATE_LED_ALARMA
    CLR MODE
    RJMP MAIN_LOOP
MA_CHECK_DOWN:
    ; DOWN = desactivar alarma y buzzer
    LDS R16, FLAG_BTN_DOWN
    CPI R16, 1
    BRNE MA_DISPLAY
    CLR R16
    STS FLAG_BTN_DOWN, R16
    CLR R16
    STS ALARM_ON, R16
    STS BUZZER_ON, R16
    RCALL UPDATE_LED_ALARMA
    CLR MODE
    RJMP MAIN_LOOP
MA_DISPLAY:
    ; Mostrar hora de alarma mientras espera
    RCALL DISPLAY_CONFIG_ALARMA
    RJMP MAIN_LOOP

/****************************************/
; ---- Subrutinas de display ----

DISPLAY_HORA:
    PUSH R16
    PUSH R17
    LDS  R16, HOURS
    RCALL SPLIT_DIGITS
    STS  DIG0, R16      ; unidades -> PB0
    STS  DIG1, R17      ; decenas  -> PB1
    LDS  R16, MINS
    RCALL SPLIT_DIGITS
    STS  DIG2, R17      ; decenas  -> PB2
    STS  DIG3, R16      ; unidades -> PB3
    POP  R17
    POP  R16
    RET

DISPLAY_FECHA:
    PUSH R16
    PUSH R17
    LDS  R16, DAY
    RCALL SPLIT_DIGITS
    STS  DIG0, R16      ; unidades -> PB0
    STS  DIG1, R17      ; decenas  -> PB1
    LDS  R16, MONTH
    RCALL SPLIT_DIGITS
    STS  DIG2, R17      ; decenas  -> PB2
    STS  DIG3, R16      ; unidades -> PB3
    POP  R17
    POP  R16
    RET

; Muestra HH:MM con parpadeo del campo activo (CONFIG_SUB)
DISPLAY_CONFIG_HORA:
    PUSH R16
    PUSH R17
    PUSH R18

    LDS R18, BLINK_HIDE

    ; Horas (DIG0:DIG1) — parpadea si CONFIG_SUB=0 y BLINK_HIDE=1
    LDS R16, CONFIG_SUB
    CPI R16, 0
    BRNE DCH_SHOW_H
    CPI R18, 1
    BRNE DCH_SHOW_H
    LDI R16, 10
    STS DIG0, R16
    STS DIG1, R16
    RJMP DCH_MINS
DCH_SHOW_H:
    LDS  R16, HOURS
    RCALL SPLIT_DIGITS
    STS  DIG0, R16
    STS  DIG1, R17

DCH_MINS:
    ; Minutos (DIG2:DIG3) — parpadea si CONFIG_SUB=1 y BLINK_HIDE=1
    LDS R16, CONFIG_SUB
    CPI R16, 1
    BRNE DCH_SHOW_M
    CPI R18, 1
    BRNE DCH_SHOW_M
    LDI R16, 10
    STS DIG2, R16
    STS DIG3, R16
    RJMP DCH_EXIT
DCH_SHOW_M:
    LDS  R16, MINS
    RCALL SPLIT_DIGITS
    STS  DIG2, R17
    STS  DIG3, R16

DCH_EXIT:
    POP R18
    POP R17
    POP R16
    RET

; Muestra DD/MM con parpadeo del campo activo
DISPLAY_CONFIG_FECHA:
    PUSH R16
    PUSH R17
    PUSH R18

    LDS R18, BLINK_HIDE

    LDS R16, CONFIG_SUB
    CPI R16, 0
    BRNE DCF_SHOW_D
    CPI R18, 1
    BRNE DCF_SHOW_D
    LDI R16, 10
    STS DIG0, R16
    STS DIG1, R16
    RJMP DCF_MES
DCF_SHOW_D:
    LDS  R16, DAY
    RCALL SPLIT_DIGITS
    STS  DIG0, R16
    STS  DIG1, R17

DCF_MES:
    LDS R16, CONFIG_SUB
    CPI R16, 1
    BRNE DCF_SHOW_M
    CPI R18, 1
    BRNE DCF_SHOW_M
    LDI R16, 10
    STS DIG2, R16
    STS DIG3, R16
    RJMP DCF_EXIT
DCF_SHOW_M:
    LDS  R16, MONTH
    RCALL SPLIT_DIGITS
    STS  DIG2, R17
    STS  DIG3, R16

DCF_EXIT:
    POP R18
    POP R17
    POP R16
    RET

; Muestra alarma HH:MM con parpadeo del campo activo
DISPLAY_CONFIG_ALARMA:
    PUSH R16
    PUSH R17
    PUSH R18

    LDS R18, BLINK_HIDE

    LDS R16, CONFIG_SUB
    CPI R16, 0
    BRNE DCA_SHOW_H
    CPI R18, 1
    BRNE DCA_SHOW_H
    LDI R16, 10
    STS DIG0, R16
    STS DIG1, R16
    RJMP DCA_MINS
DCA_SHOW_H:
    LDS  R16, ALARM_HOUR
    RCALL SPLIT_DIGITS
    STS  DIG0, R16
    STS  DIG1, R17

DCA_MINS:
    LDS R16, CONFIG_SUB
    CPI R16, 1
    BRNE DCA_SHOW_M
    CPI R18, 1
    BRNE DCA_SHOW_M
    LDI R16, 10
    STS DIG2, R16
    STS DIG3, R16
    RJMP DCA_EXIT
DCA_SHOW_M:
    LDS  R16, ALARM_MIN
    RCALL SPLIT_DIGITS
    STS  DIG2, R17
    STS  DIG3, R16

DCA_EXIT:
    POP R18
    POP R17
    POP R16
    RET

/****************************************/
; SPLIT_DIGITS: R16 -> decenas en R17, unidades en R16
SPLIT_DIGITS:
    CLR R17
SD_LOOP:
    CPI  R16, 10
    BRLO SD_DONE
    SUBI R16, 10
    INC  R17
    RJMP SD_LOOP
SD_DONE:
    RET

/****************************************/
; ---- UP / DOWN con overflow y underflow ----

UP_HOURS:
    PUSH R16
    LDS  R16, HOURS
    INC  R16
    CPI  R16, 24
    BRLO UH_STORE
    CLR  R16
UH_STORE:
    STS  HOURS, R16
    POP  R16
    RET

DOWN_HOURS:
    PUSH R16
    LDS  R16, HOURS
    CPI  R16, 0
    BREQ DH_UNDER
    DEC  R16
    RJMP DH_STORE
DH_UNDER:
    LDI  R16, 23
DH_STORE:
    STS  HOURS, R16
    POP  R16
    RET

UP_MINS:
    PUSH R16
    LDS  R16, MINS
    INC  R16
    CPI  R16, 60
    BRLO UM_STORE
    CLR  R16
UM_STORE:
    STS  MINS, R16
    POP  R16
    RET

DOWN_MINS:
    PUSH R16
    LDS  R16, MINS
    CPI  R16, 0
    BREQ DM_UNDER
    DEC  R16
    RJMP DM_STORE
DM_UNDER:
    LDI  R16, 59
DM_STORE:
    STS  MINS, R16
    POP  R16
    RET

UP_DAY:
    PUSH R16
    PUSH R17
    LDS  R16, DAY
    INC  R16
    RCALL GET_MAX_DAY       ; R17 = max días del mes
    CP   R16, R17
    BRLO UD_STORE
    BREQ UD_STORE           ; último día es válido
    LDI  R16, 1             ; overflow -> día 1
UD_STORE:
    STS  DAY, R16
    POP  R17
    POP  R16
    RET

DOWN_DAY:
    PUSH R16
    PUSH R17
    LDS  R16, DAY
    CPI  R16, 1
    BREQ DD_UNDER
    DEC  R16
    RJMP DD_STORE
DD_UNDER:
    RCALL GET_MAX_DAY
    MOV  R16, R17
DD_STORE:
    STS  DAY, R16
    POP  R17
    POP  R16
    RET

UP_MONTH:
    PUSH R16
    PUSH R17
    LDS  R16, MONTH
    INC  R16
    CPI  R16, 13
    BRLO UMON_CLIP
    LDI  R16, 1
UMON_CLIP:
    STS  MONTH, R16
    ; Recortar día si excede el nuevo mes
    RCALL GET_MAX_DAY
    LDS  R16, DAY
    CP   R16, R17
    BRLO UMON_EXIT
    BREQ UMON_EXIT
    STS  DAY, R17
UMON_EXIT:
    POP  R17
    POP  R16
    RET

DOWN_MONTH:
    PUSH R16
    PUSH R17
    LDS  R16, MONTH
    CPI  R16, 1
    BREQ DMON_UNDER
    DEC  R16
    RJMP DMON_CLIP
DMON_UNDER:
    LDI  R16, 12
DMON_CLIP:
    STS  MONTH, R16
    RCALL GET_MAX_DAY
    LDS  R16, DAY
    CP   R16, R17
    BRLO DMON_EXIT
    BREQ DMON_EXIT
    STS  DAY, R17
DMON_EXIT:
    POP  R17
    POP  R16
    RET

UP_ALARM_HOURS:
    PUSH R16
    LDS  R16, ALARM_HOUR
    INC  R16
    CPI  R16, 24
    BRLO UAH_STORE
    CLR  R16
UAH_STORE:
    STS  ALARM_HOUR, R16
    POP  R16
    RET

DOWN_ALARM_HOURS:
    PUSH R16
    LDS  R16, ALARM_HOUR
    CPI  R16, 0
    BREQ DAH_UNDER
    DEC  R16
    RJMP DAH_STORE
DAH_UNDER:
    LDI  R16, 23
DAH_STORE:
    STS  ALARM_HOUR, R16
    POP  R16
    RET

UP_ALARM_MINS:
    PUSH R16
    LDS  R16, ALARM_MIN
    INC  R16
    CPI  R16, 60
    BRLO UAM_STORE
    CLR  R16
UAM_STORE:
    STS  ALARM_MIN, R16
    POP  R16
    RET

DOWN_ALARM_MINS:
    PUSH R16
    LDS  R16, ALARM_MIN
    CPI  R16, 0
    BREQ DAM_UNDER
    DEC  R16
    RJMP DAM_STORE
DAM_UNDER:
    LDI  R16, 59
DAM_STORE:
    STS  ALARM_MIN, R16
    POP  R16
    RET

/****************************************/
; ---- LEDs indicadores ----

LED_CONFIG_ON:
    PUSH R16
    IN   R16, PORTC
    ORI  R16, (1<<PC4)
    OUT  PORTC, R16
    POP  R16
    RET

LED_CONFIG_OFF:
    PUSH R16
    IN   R16, PORTC
    ANDI R16, 0xEF
    OUT  PORTC, R16
    POP  R16
    RET

UPDATE_LED_ALARMA:
    PUSH R16
    PUSH R17
    LDS  R16, ALARM_ON
    IN   R17, PORTC
    CPI  R16, 1
    BRNE ALA_LED_OFF
    ORI  R17, (1<<PC5)
    RJMP ALA_LED_STORE
ALA_LED_OFF:
    ANDI R17, 0xDF
ALA_LED_STORE:
    OUT  PORTC, R17
    POP  R17
    POP  R16
    RET

/****************************************/
; ---- Timer0 ISR (1ms) ----

TIMER_ISR:
    PUSH R16
    IN   R16, SREG
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19
    PUSH ZL
    PUSH ZH

    ; --- Multiplexado ---
    IN   R16, PORTB
    ANDI R16, 0b11110000
    OUT  PORTB, R16

    LDS  R17, DIGIT_INDEX
    CPI  R17, 0
    BREQ T_LOAD0
    CPI  R17, 1
    BREQ T_LOAD1
    CPI  R17, 2
    BREQ T_LOAD2
    RJMP T_LOAD3

T_LOAD0: LDS R18, DIG0
    RJMP T_PATTERN
T_LOAD1: LDS R18, DIG1
    RJMP T_PATTERN
T_LOAD2: LDS R18, DIG2
    RJMP T_PATTERN
T_LOAD3: LDS R18, DIG3

T_PATTERN:
    LDI ZH, HIGH(tabla_7seg << 1)
    LDI ZL, LOW(tabla_7seg << 1)
    ADD ZL, R18
    ADC ZH, R1
    LPM R16, Z
    ; Preservar PD7 (buzzer) al escribir segmentos
    ; Preservar PD7 según BUZZER_ON
    LDS R19, BUZZER_ON
    CPI R19, 1
    BRNE T_BUZZER_OFF
    ORI R16, (1<<PD7)
    RJMP T_PORTD_OUT
T_BUZZER_OFF:
    ANDI R16, 0x7F
T_PORTD_OUT:
    OUT PORTD, R16

    MOV  R18, R17
    LDI  R19, 1
T_SHIFT:
    CPI  R18, 0
    BREQ T_ACT
    LSL  R19
    DEC  R18
    RJMP T_SHIFT
T_ACT:
    IN   R16, PORTB
    ANDI R16, 0b11110000
    OR   R16, R19
    OUT  PORTB, R16

    LDS  R17, DIGIT_INDEX
    INC  R17
    CPI  R17, MAX_DIG
    BRLO T_STORE_IDX
    CLR  R17
T_STORE_IDX:
    STS  DIGIT_INDEX, R17

    ; --- Contador ms ---
    LDS R18, MILISEC_L
    LDS R19, MILISEC_H
    INC R18
    BRNE T_NO_CARRY
    INC R19
T_NO_CARRY:
    STS MILISEC_L, R18
    STS MILISEC_H, R19

    ; --- Debounce PC0 (modo) ---
T_DEB0:
    LDS  R16, FLAG_DEBOUNCE_0
    CPI  R16, 1
    BRNE T_DEB1
    LDS  R16, DEBOUNCE_COUNT_0
    INC  R16
    STS  DEBOUNCE_COUNT_0, R16
    CPI  R16, 20
    BRSH T_DEB0_CONFIRM
    RJMP T_CHECK_MS
T_DEB0_CONFIRM:
    IN   R16, PINC
    ANDI R16, (1<<PC0)
    CPI  R16, 0
    BRNE T_CANCEL0
    ; Confirmar modo
    INC  MODE
    CPI  MODE, MAX_MODES
    BRNE T_RESET_SUB
    CLR  MODE
T_RESET_SUB:
    LDI  R16, 0
    STS  CONFIG_SUB, R16
    STS  BLINK_HIDE, R16
T_CANCEL0:
    LDI  R16, 0
    STS  FLAG_DEBOUNCE_0, R16
    IN   R16, PINC
    ANDI R16, (1<<PC0)
    MOV  FLAG_PC0, R16

    ; --- Debounce PC1 (UP) ---
T_DEB1:
    LDS  R16, FLAG_DEBOUNCE_1
    CPI  R16, 1
    BRNE T_DEB2
    LDS  R16, DEBOUNCE_COUNT_1
    INC  R16
    STS  DEBOUNCE_COUNT_1, R16
    CPI  R16, 20
    BRSH T_DEB1_CONFIRM
    RJMP T_DEB2
T_DEB1_CONFIRM:
    IN   R16, PINC
    ANDI R16, (1<<PC1)
    CPI  R16, 0
    BRNE T_CANCEL1
    LDI  R16, 1
    STS  FLAG_BTN_UP, R16
T_CANCEL1:
    LDI  R16, 0
    STS  FLAG_DEBOUNCE_1, R16
    IN   R16, PINC
    ANDI R16, (1<<PC1)
    MOV  FLAG_PC1, R16

    ; --- Debounce PC2 (DOWN) ---
T_DEB2:
    LDS  R16, FLAG_DEBOUNCE_2
    CPI  R16, 1
    BRNE T_DEB3
    LDS  R16, DEBOUNCE_COUNT_2
    INC  R16
    STS  DEBOUNCE_COUNT_2, R16
    CPI  R16, 20
    BRSH T_DEB2_CONFIRM
    RJMP T_DEB3
T_DEB2_CONFIRM:
    IN   R16, PINC
    ANDI R16, (1<<PC2)
    CPI  R16, 0
    BRNE T_CANCEL2
    LDI  R16, 1
    STS  FLAG_BTN_DOWN, R16
T_CANCEL2:
    LDI  R16, 0
    STS  FLAG_DEBOUNCE_2, R16
    IN   R16, PINC
    ANDI R16, (1<<PC2)
    MOV  FLAG_PC2, R16

    ; --- Debounce PC3 (SELECT) ---
T_DEB3:
    LDS  R16, FLAG_DEBOUNCE_3
    CPI  R16, 1
    BRNE T_CHECK_MS
    LDS  R16, DEBOUNCE_COUNT_3
    INC  R16
    STS  DEBOUNCE_COUNT_3, R16
    CPI  R16, 20
    BRSH T_DEB3_CONFIRM
    RJMP T_CHECK_MS
T_DEB3_CONFIRM:
    IN   R16, PINC
    ANDI R16, (1<<PC3)
    CPI  R16, 0
    BRNE T_CANCEL3
    LDI  R16, 1
    STS  FLAG_BTN_SEL, R16
T_CANCEL3:
    LDI  R16, 0
    STS  FLAG_DEBOUNCE_3, R16
    IN   R16, PINC
    ANDI R16, (1<<PC3)
    MOV  FLAG_PC3, R16

    ; --- Flags de tiempo ---
T_CHECK_MS:
    LDI R16, LOW(500)
    CP  R18, R16
    LDI R16, HIGH(500)
    CPC R19, R16
    BRNE T_CHECK_1S
    LDI R16, 1
    STS FLAG_500MS, R16

T_CHECK_1S:
    LDI R16, LOW(1000)
    CP  R18, R16
    LDI R16, HIGH(1000)
    CPC R19, R16
    BRNE T_END
    ; Activar FLAG_500MS también aquí (segundo toggle)
    LDI R16, 1
    STS FLAG_500MS, R16
    CLR R18
    CLR R19
    STS MILISEC_L, R18
    STS MILISEC_H, R19
    LDI R16, 1
    STS FLAG_1S, R16

T_END:
    POP ZH
    POP ZL
    POP R19
    POP R18
    POP R17
    POP R16
    OUT SREG, R16
    POP R16
    RETI

/****************************************/
; ---- PCINT ISR (PC0-PC3) ----

PCINT8_ISR:
    IN   R17, SREG
    PUSH R17
    PUSH R16
    PUSH R18

    IN   R18, PINC          ; snapshot único de PINC

    ; PC0
    MOV  R16, R18
    ANDI R16, (1<<PC0)
    CP   R16, FLAG_PC0
    BREQ P_CHK1
    MOV  FLAG_PC0, R16
    CPI  R16, 0
    BRNE P_CHK1
    LDI  R16, 1
    STS  FLAG_DEBOUNCE_0, R16
    LDI  R16, 0
    STS  DEBOUNCE_COUNT_0, R16

P_CHK1:
    ; PC1
    MOV  R16, R18
    ANDI R16, (1<<PC1)
    CP   R16, FLAG_PC1
    BREQ P_CHK2
    MOV  FLAG_PC1, R16
    CPI  R16, 0
    BRNE P_CHK2
    ; No reiniciar si el flag ya está pendiente
    LDS  R16, FLAG_BTN_UP
    CPI  R16, 1
    BREQ P_CHK2
    LDI  R16, 1
    STS  FLAG_DEBOUNCE_1, R16
    LDI  R16, 0
    STS  DEBOUNCE_COUNT_1, R16

P_CHK2:
    ; PC2
    MOV  R16, R18
    ANDI R16, (1<<PC2)
    CP   R16, FLAG_PC2
    BREQ P_CHK3
    MOV  FLAG_PC2, R16
    CPI  R16, 0
    BRNE P_CHK3
    ; No reiniciar si el flag ya está pendiente
    LDS  R16, FLAG_BTN_DOWN
    CPI  R16, 1
    BREQ P_CHK3
    LDI  R16, 1
    STS  FLAG_DEBOUNCE_2, R16
    LDI  R16, 0
    STS  DEBOUNCE_COUNT_2, R16

P_CHK3:
    ; PC3
    MOV  R16, R18
    ANDI R16, (1<<PC3)
    CP   R16, FLAG_PC3
    BREQ P_EXIT
    MOV  FLAG_PC3, R16
    CPI  R16, 0
    BRNE P_EXIT
    ; No reiniciar si el flag ya está pendiente
    LDS  R16, FLAG_BTN_SEL
    CPI  R16, 1
    BREQ P_EXIT
    LDI  R16, 1
    STS  FLAG_DEBOUNCE_3, R16
    LDI  R16, 0
    STS  DEBOUNCE_COUNT_3, R16

P_EXIT:
    POP  R18
    POP  R16
    POP  R17
    OUT  SREG, R17
    RETI

/****************************************/
; tabla_7seg: 0-9 = dígitos, 10 = apagado
tabla_7seg:
    .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x00

; tabla_dias_mes: índice 1-12 (índice 0 no usado)
tabla_dias_mes:
    .db 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31