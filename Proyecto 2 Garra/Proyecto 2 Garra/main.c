/*
 * Proyecto2_main.c
 *
 * Created: 5-05-2026
 * Author: Joaquin Fuentes
 *
 * Control por botones manuales (PC4 = cambiar modo, PC5 = ejecutar acción):
 *   MODE_ADC      -> A0=S1 A1=S2 A2=S3 A3=S4  | LED: PD2
 *   MODE_SERIAL   -> Comandos S1:90 por UART    | LED: PB4
 *   MODE_RECORD   -> Graba keyframes en EEPROM  | LED: PB5
 *   MODE_PLAYBACK -> Reproduce keyframes        | LED: PD2+PB4
 *
 * Mapa de pines PWM:
 *   Servo 1 (hombro) -> TIMER1 OC1A -> PB1   | 0-180 grados
 *   Servo 2 (base)   -> TIMER1 OC1B -> PB2   | 110-180 grados
 *   Servo 3 (codo)   -> TIMER2 OC2B -> PD3   | 95-160 grados
 *   Servo 4 (garra)  -> TIMER0 OC0B -> PD5   | 0-10 grados
 *
 * LEDs de modo: PD2, PB4, PB5
 *
 * EEPROM — formato keyframe (4 bytes por pose):
 *   [0] servo1_angle  [1] servo2_angle
 *   [2] servo3_angle  [3] servo4_angle
 *
 *   Maximo 4 keyframes (16 bytes totales)
 *   Direcciones EEPROM:
 *     Keyframe 0: 0x00-0x03
 *     Keyframe 1: 0x04-0x07
 *     Keyframe 2: 0x08-0x0B
 *     Keyframe 3: 0x0C-0x0F
 *
 *   Marcador de keyframe vacio: primer byte = 0xFF
 *
 * Feedback UART -> Python -> Adafruit IO:
 *   Formato: FB1:90\r\n
 */

/****************************************/
#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <string.h>
#include <stdlib.h>
#include "UART.h"
#include "PWMservo.h"
#include "PWMservo_T2.h"
#include "PWMservo_T0.h"
#include "eeprom.h"

/****************************************/
// Modos
typedef enum {
    MODE_ADC      = 0,
    MODE_SERIAL   = 1,
    MODE_RECORD   = 2,
    MODE_PLAYBACK = 3
} app_mode_t;

/****************************************/
// Limites mecanicos — aplicados en main, NO en librerias
#define SERVO1_MIN_ANGLE     0U
#define SERVO1_MAX_ANGLE   180U

#define SERVO2_MIN_ANGLE   110U
#define SERVO2_MAX_ANGLE   180U

#define SERVO3_MIN_ANGLE    95U
#define SERVO3_MAX_ANGLE   160U

#define SERVO4_MIN_ANGLE     0U
#define SERVO4_MAX_ANGLE    10U

/****************************************/
// Home position — posicion segura de arranque y retorno
#define SERVO1_HOME_ANGLE    0U
#define SERVO2_HOME_ANGLE  165U
#define SERVO3_HOME_ANGLE  150U
#define SERVO4_HOME_ANGLE    5U

/****************************************/
// EEPROM — Keyframes
#define KEYFRAME_SIZE         4U    // bytes por keyframe (s1,s2,s3,s4)
#define MAX_KEYFRAMES         4U    // 4 poses clave, 16 bytes totales
#define KEYFRAME_BASE_ADDR    0U    // direccion base en EEPROM
#define EEPROM_EMPTY_MARKER 0xFFU   // byte sin escribir = keyframe vacio

// Delay entre pasos durante interpolacion playback (ms)
#define PLAYBACK_STEP_DELAY_MS  10U

/****************************************/
// ADC feedback
#define ADC_FB_INTERVAL   25U

/****************************************/
// Botones
#define BTN_CHANGE_PIN    PC4    // Cambiar modo / Cancelar / Salir
#define BTN_ACTION_PIN    PC5    // Ejecutar accion / Guardar keyframe
#define DEBOUNCE_MS       30

/****************************************/
// Prototipos
static void     adc_init(void);
static uint16_t adc_read(uint8_t channel);
static int32_t  map_value(int32_t val, int32_t in_min, int32_t in_max,
                           int32_t out_min, int32_t out_max);
static void     buttons_init(void);
static uint8_t  button_pressed(uint8_t pin);
static void     set_mode_leds(app_mode_t mode);
static void     enviar_feedback(uint8_t servo_id, uint8_t angulo);
static void     print_mode_name(app_mode_t mode);

static void     move_to_home(servo_t *s1, servo_t *s2,
                              servo_t2_t *s3, servo_t0_t *s4);
static void     run_mode_adc(servo_t *s1, servo_t *s2,
                              servo_t2_t *s3, servo_t0_t *s4);
static void     run_mode_serial(servo_t *s1, servo_t *s2,
                                 servo_t2_t *s3, servo_t0_t *s4);
static void     run_mode_record(servo_t *s1, servo_t *s2,
                                 servo_t2_t *s3, servo_t0_t *s4);
static void     run_mode_playback(servo_t *s1, servo_t *s2,
                                   servo_t2_t *s3, servo_t0_t *s4);
static void     procesar_comando_directo(char *cmd,
                                          servo_t *s1, servo_t *s2,
                                          servo_t2_t *s3, servo_t0_t *s4);

/****************************************/
// Variables globales
volatile uint8_t datoRX     = 0;
volatile uint8_t ExisteDato = 0;

app_mode_t current_mode = MODE_ADC;

/****************************************/
// Main
int main(void)
{
    cli();

    servo_t    servo1, servo2;
    servo_t2_t servo3;
    servo_t0_t servo4;

    adc_init();

    // Inicializar todos los servos en HOME directamente
    pwm_servo_init(&servo1, PWM_CHANNEL_A);
    pwm_servo_init(&servo2, PWM_CHANNEL_B);
    pwm_servo_t2_init_at(&servo3, SERVO3_HOME_ANGLE);
    pwm_servo_t0_init_at(&servo4, SERVO4_HOME_ANGLE);

    // Mover s1 y s2 a home explicitamente
    pwm_servo_set_angle(&servo1, SERVO1_HOME_ANGLE);
    pwm_servo_set_angle(&servo2, SERVO2_HOME_ANGLE);

    initUART();
    buttons_init();

    // LEDs: PD2, PB4, PB5
    DDRD  |=  (1 << PD2);
    PORTD &= ~(1 << PD2);
    DDRB  |=  (1 << PB4) | (1 << PB5);
    PORTB &= ~((1 << PB4) | (1 << PB5));

    sei();

    set_mode_leds(current_mode);
    writeString("\r\n=== Brazo robotico iniciado ===\r\n");
    writeString("S1:0-180  S2:110-180  S3:95-160  S4:0-10\r\n");
    writeString("BTN PC4 = modo  |  BTN PC5 = ejecutar\r\n");
    print_mode_name(current_mode);

    while (1)
    {
        if (button_pressed(BTN_CHANGE_PIN))
        {
            current_mode = (app_mode_t)((current_mode + 1) % 4);
            set_mode_leds(current_mode);
            print_mode_name(current_mode);
        }

        if (button_pressed(BTN_ACTION_PIN))
        {
            switch (current_mode)
            {
                case MODE_ADC:
                    run_mode_adc(&servo1, &servo2, &servo3, &servo4);
                    break;
                case MODE_SERIAL:
                    run_mode_serial(&servo1, &servo2, &servo3, &servo4);
                    break;
                case MODE_RECORD:
                    run_mode_record(&servo1, &servo2, &servo3, &servo4);
                    break;
                case MODE_PLAYBACK:
                    run_mode_playback(&servo1, &servo2, &servo3, &servo4);
                    break;
            }
            set_mode_leds(current_mode);
            print_mode_name(current_mode);
        }
    }

    return 0;
}

/****************************************/
// Botones
static void buttons_init(void)
{
    DDRC  &= ~((1 << BTN_CHANGE_PIN) | (1 << BTN_ACTION_PIN));
    PORTC |=  (1 << BTN_CHANGE_PIN)  | (1 << BTN_ACTION_PIN);
}

static uint8_t button_pressed(uint8_t pin)
{
    if (!(PINC & (1 << pin)))
    {
        _delay_ms(DEBOUNCE_MS);
        if (!(PINC & (1 << pin)))
        {
            while (!(PINC & (1 << pin)));
            _delay_ms(DEBOUNCE_MS);
            return 1;
        }
    }
    return 0;
}

/****************************************/
// LEDs
static void set_mode_leds(app_mode_t mode)
{
    PORTD &= ~(1 << PD2);
    PORTB &= ~((1 << PB4) | (1 << PB5));

    switch (mode)
    {
        case MODE_ADC:      PORTD |= (1 << PD2);                    break;
        case MODE_SERIAL:   PORTB |= (1 << PB4);                    break;
        case MODE_RECORD:   PORTB |= (1 << PB5);                    break;
        case MODE_PLAYBACK: PORTD |= (1 << PD2); PORTB |= (1<<PB4); break;
    }
}

/****************************************/
// Nombre del modo
static void print_mode_name(app_mode_t mode)
{
    writeString("\r\n> Modo: ");
    switch (mode)
    {
        case MODE_ADC:      writeString("ADC\r\n");      break;
        case MODE_SERIAL:   writeString("SERIAL\r\n");   break;
        case MODE_RECORD:   writeString("RECORD\r\n");   break;
        case MODE_PLAYBACK: writeString("PLAYBACK\r\n"); break;
    }
    writeString("  PC5=ejecutar  PC4=cambiar\r\n");
}

/****************************************/
// Feedback UART
// Formato: FB1:90\r\n
static void enviar_feedback(uint8_t servo_id, uint8_t angulo)
{
    char    buf[12];
    uint8_t i = 0;

    buf[i++] = 'F';
    buf[i++] = 'B';
    buf[i++] = '0' + servo_id;
    buf[i++] = ':';

    if (angulo == 0)
    {
        buf[i++] = '0';
    }
    else
    {
        char    tmp[4];
        uint8_t n = 0;
        uint8_t a = angulo;
        while (a > 0) { tmp[n++] = '0' + (a % 10); a /= 10; }
        while (n > 0) { buf[i++] = tmp[--n]; }
    }

    buf[i++] = '\r';
    buf[i++] = '\n';
    buf[i]   = '\0';

    writeString(buf);
}

/****************************************/
/*
 * move_to_home
 *
 * Mueve todos los servos a la posicion segura HOME de forma suave
 * (paso a paso) para evitar saltos bruscos al arrancar o al
 * finalizar RECORD/PLAYBACK.
 */
static void move_to_home(servo_t *s1, servo_t *s2,
                          servo_t2_t *s3, servo_t0_t *s4)
{
    writeString("\r\n[HOME] Moviendo a posicion segura...\r\n");

    uint8_t a1 = pwm_servo_get_angle(s1);
    uint8_t a2 = pwm_servo_get_angle(s2);
    uint8_t a3 = pwm_servo_t2_get_angle(s3);
    uint8_t a4 = pwm_servo_t0_get_angle(s4);

    uint8_t done = 0;

    while (!done)
    {
        done = 1;

        if (a1 < SERVO1_HOME_ANGLE)      { a1++; done = 0; }
        else if (a1 > SERVO1_HOME_ANGLE) { a1--; done = 0; }

        if (a2 < SERVO2_HOME_ANGLE)      { a2++; done = 0; }
        else if (a2 > SERVO2_HOME_ANGLE) { a2--; done = 0; }

        if (a3 < SERVO3_HOME_ANGLE)      { a3++; done = 0; }
        else if (a3 > SERVO3_HOME_ANGLE) { a3--; done = 0; }

        if (a4 < SERVO4_HOME_ANGLE)      { a4++; done = 0; }
        else if (a4 > SERVO4_HOME_ANGLE) { a4--; done = 0; }

        pwm_servo_set_angle(s1, a1);
        pwm_servo_set_angle(s2, a2);
        pwm_servo_t2_set_angle(s3, a3);
        pwm_servo_t0_set_angle(s4, a4);

        _delay_ms(PLAYBACK_STEP_DELAY_MS);
    }

    writeString("[HOME] OK\r\n");
}

/****************************************/
// MODE_ADC
static void run_mode_adc(servo_t *s1, servo_t *s2,
                          servo_t2_t *s3, servo_t0_t *s4)
{
    uint8_t fb_counter = 0;

    writeString("\r\n[ADC] Activo. PC4 para salir.\r\n");

    while (1)
    {
        if (button_pressed(BTN_CHANGE_PIN))
        {
            writeString("[ADC] Saliendo...\r\n");
            break;
        }

        uint16_t adc0 = adc_read(0);
        pwm_servo_set_angle(s1, (uint8_t)map_value(
            (int32_t)adc0, 0, 1023,
            SERVO1_MIN_ANGLE, SERVO1_MAX_ANGLE));

        uint16_t adc1 = adc_read(1);
        pwm_servo_set_angle(s2, (uint8_t)map_value(
            (int32_t)adc1, 0, 1023,
            SERVO2_MIN_ANGLE, SERVO2_MAX_ANGLE));

        uint16_t adc2 = adc_read(2);
        pwm_servo_t2_set_angle(s3, (uint8_t)map_value(
            (int32_t)adc2, 0, 1023,
            SERVO3_MIN_ANGLE, SERVO3_MAX_ANGLE));

        uint16_t adc3 = adc_read(3);
        pwm_servo_t0_set_angle(s4, (uint8_t)map_value(
            (int32_t)adc3, 0, 1023,
            SERVO4_MIN_ANGLE, SERVO4_MAX_ANGLE));

        _delay_ms(20);

        fb_counter++;
        if (fb_counter >= ADC_FB_INTERVAL)
        {
            fb_counter = 0;
            enviar_feedback(1, pwm_servo_get_angle(s1));
            enviar_feedback(2, pwm_servo_get_angle(s2));
            enviar_feedback(3, pwm_servo_t2_get_angle(s3));
            enviar_feedback(4, pwm_servo_t0_get_angle(s4));
        }
    }
}

/****************************************/
// MODE_SERIAL
static void run_mode_serial(servo_t *s1, servo_t *s2,
                              servo_t2_t *s3, servo_t0_t *s4)
{
    char    buffer[20];
    uint8_t index = 0;

    writeString("\r\n[SERIAL] S1:0-180 S2:110-180 S3:95-160 S4:0-10\r\n");
    writeString("         'q' o PC4 para salir.\r\n");

    while (1)
    {
        if (button_pressed(BTN_CHANGE_PIN))
        {
            writeString("\r\n[SERIAL] Saliendo...\r\n");
            break;
        }

        if (ExisteDato)
        {
            char c = (char)datoRX;
            ExisteDato = 0;
            writeChar(c);

            if (c == '\r')
            {
                buffer[index] = '\0';

                if (strcmp(buffer, "q") == 0 || strcmp(buffer, "Q") == 0)
                {
                    writeString("\r\n[SERIAL] Saliendo...\r\n");
                    break;
                }

                procesar_comando_directo(buffer, s1, s2, s3, s4);
                index = 0;
            }
            else if (index < sizeof(buffer) - 1)
            {
                buffer[index++] = c;
            }
        }
    }
}

/****************************************/
/*
 * MODE_RECORD — Keyframes
 *
 * El usuario mueve los potenciometros en tiempo real para posicionar
 * el brazo. Cuando encuentra una pose deseada, presiona PC5 para
 * guardarla como keyframe en EEPROM.
 *
 * Maximo 4 keyframes (16 bytes totales).
 * Cada keyframe se guarda secuencialmente.
 * LED PB5 parpadea al guardar un keyframe.
 * PC4 sale del modo.
 *
 * Si se alcanzan 4 keyframes, se informa y se sale.
 */
static void run_mode_record(servo_t *s1, servo_t *s2,
                             servo_t2_t *s3, servo_t0_t *s4)
{
    writeString("\r\n[RECORD] Mueve pots. PC5=guardar pose. PC4=salir.\r\n");
    writeString("[RECORD] Max 4 keyframes. LED PB5 parpadea al guardar.\r\n");

    uint8_t keyframe_count = 0;

    while (1)
    {
        // --- LECTURA ADC EN TIEMPO REAL ---
        // El usuario mueve los potenciometros y ve el brazo moverse
        uint8_t angle1 = (uint8_t)map_value(
            (int32_t)adc_read(0), 0, 1023,
            SERVO1_MIN_ANGLE, SERVO1_MAX_ANGLE);
        pwm_servo_set_angle(s1, angle1);

        uint8_t angle2 = (uint8_t)map_value(
            (int32_t)adc_read(1), 0, 1023,
            SERVO2_MIN_ANGLE, SERVO2_MAX_ANGLE);
        pwm_servo_set_angle(s2, angle2);

        uint8_t angle3 = (uint8_t)map_value(
            (int32_t)adc_read(2), 0, 1023,
            SERVO3_MIN_ANGLE, SERVO3_MAX_ANGLE);
        pwm_servo_t2_set_angle(s3, angle3);

        uint8_t angle4 = (uint8_t)map_value(
            (int32_t)adc_read(3), 0, 1023,
            SERVO4_MIN_ANGLE, SERVO4_MAX_ANGLE);
        pwm_servo_t0_set_angle(s4, angle4);

        _delay_ms(20);

        // --- SALIR CON PC4 ---
        if (button_pressed(BTN_CHANGE_PIN))
        {
            writeString("\r\n[RECORD] Saliendo...\r\n");
            break;
        }

        // --- GUARDAR KEYFRAME CON PC5 ---
        if (button_pressed(BTN_ACTION_PIN))
        {
            if (keyframe_count >= MAX_KEYFRAMES)
            {
                writeString("[RECORD] Ya hay 4 keyframes. Borra EEPROM para grabar mas.\r\n");
                continue;
            }

            uint16_t addr = KEYFRAME_BASE_ADDR + ((uint16_t)keyframe_count * KEYFRAME_SIZE);

            eepromWrite(addr + 0, angle1);
            eepromWrite(addr + 1, angle2);
            eepromWrite(addr + 2, angle3);
            eepromWrite(addr + 3, angle4);

            // Parpadeo LED
            PORTB |=  (1 << PB5);
            _delay_ms(100);
            PORTB &= ~(1 << PB5);

            // Reportar keyframe guardado
            writeString("[RECORD] Keyframe ");
            char kf[4];
            kf[0] = '0' + (keyframe_count + 1);
            kf[1] = '\r';
            kf[2] = '\n';
            kf[3] = '\0';
            writeString(kf);

            writeString("  S1=");
            enviar_feedback(1, angle1);
            writeString("  S2=");
            enviar_feedback(2, angle2);
            writeString("  S3=");
            enviar_feedback(3, angle3);
            writeString("  S4=");
            enviar_feedback(4, angle4);

            keyframe_count++;

            if (keyframe_count >= MAX_KEYFRAMES)
            {
                writeString("[RECORD] 4/4 keyframes guardados.\r\n");
            }
        }
    }

    // Reporte final
    writeString("[RECORD] Total keyframes guardados: ");
    char total[4];
    total[0] = '0' + keyframe_count;
    total[1] = '\r';
    total[2] = '\n';
    total[3] = '\0';
    writeString(total);
    writeString("[RECORD] Listo.\r\n");
}

/****************************************/
/*
 * MODE_PLAYBACK — Keyframes
 *
 * Reproduce secuencialmente los keyframes guardados en EEPROM
 * con interpolacion suave entre cada pose.
 *
 * Flujo:
 *   1. Mover a HOME
 *   2. Para cada keyframe, interpolar desde posicion actual
 *      hasta el angulo destino, grado a grado con delay
 *   3. Permitir cancelacion con PC4
 *
 * Se detiene al encontrar el marcador 0xFF (keyframe vacio)
 * o al alcanzar MAX_KEYFRAMES.
 */
static void run_mode_playback(servo_t *s1, servo_t *s2,
                               servo_t2_t *s3, servo_t0_t *s4)
{
    writeString("\r\n[PLAYBACK] Iniciando reproduccion...\r\n");
    writeString("[PLAYBACK] PC4 para cancelar.\r\n");

    // 1. Volver a HOME
    move_to_home(s1, s2, s3, s4);

    uint8_t current_a1 = SERVO1_HOME_ANGLE;
    uint8_t current_a2 = SERVO2_HOME_ANGLE;
    uint8_t current_a3 = SERVO3_HOME_ANGLE;
    uint8_t current_a4 = SERVO4_HOME_ANGLE;

    uint8_t keyframe_index = 0;

    while (keyframe_index < MAX_KEYFRAMES)
    {
        // Permitir cancelacion
        if (button_pressed(BTN_CHANGE_PIN))
        {
            writeString("\r\n[PLAYBACK] Cancelado por usuario.\r\n");
            break;
        }

        // Leer keyframe de EEPROM
        uint16_t addr = KEYFRAME_BASE_ADDR + ((uint16_t)keyframe_index * KEYFRAME_SIZE);
        uint8_t  marker = eepromRead(addr);

        // Keyframe vacio = fin de secuencia
        if (marker == EEPROM_EMPTY_MARKER)
        {
            writeString("[PLAYBACK] Fin de keyframes grabados.\r\n");
            break;
        }

        uint8_t target_a1 = eepromRead(addr + 0);
        uint8_t target_a2 = eepromRead(addr + 1);
        uint8_t target_a3 = eepromRead(addr + 2);
        uint8_t target_a4 = eepromRead(addr + 3);

        // Mostrar keyframe actual
        writeString("[PLAYBACK] Keyframe ");
        char kf[4];
        kf[0] = '0' + (keyframe_index + 1);
        kf[1] = '/';
        kf[2] = '4';
        kf[3] = '\0';
        writeString(kf);

        writeString("  S1=");
        enviar_feedback(1, target_a1);
        writeString("  S2=");
        enviar_feedback(2, target_a2);
        writeString("  S3=");
        enviar_feedback(3, target_a3);
        writeString("  S4=");
        enviar_feedback(4, target_a4);

        // --- INTERPOLACION PASO A PASO ---
        uint8_t arrived = 0;
        while (!arrived)
        {
            if (button_pressed(BTN_CHANGE_PIN))
            {
                writeString("\r\n[PLAYBACK] Cancelado durante movimiento.\r\n");
                return;
            }

            arrived = 1;

            if (current_a1 < target_a1)      { current_a1++; arrived = 0; }
            else if (current_a1 > target_a1) { current_a1--; arrived = 0; }
            pwm_servo_set_angle(s1, current_a1);

            if (current_a2 < target_a2)      { current_a2++; arrived = 0; }
            else if (current_a2 > target_a2) { current_a2--; arrived = 0; }
            pwm_servo_set_angle(s2, current_a2);

            if (current_a3 < target_a3)      { current_a3++; arrived = 0; }
            else if (current_a3 > target_a3) { current_a3--; arrived = 0; }
            pwm_servo_t2_set_angle(s3, current_a3);

            if (current_a4 < target_a4)      { current_a4++; arrived = 0; }
            else if (current_a4 > target_a4) { current_a4--; arrived = 0; }
            pwm_servo_t0_set_angle(s4, current_a4);

            _delay_ms(PLAYBACK_STEP_DELAY_MS);
        }

        keyframe_index++;
    }

    writeString("[PLAYBACK] Reproduccion finalizada.\r\n");
}

/****************************************/
/*
 * procesar_comando_directo
 * Formato: S<id>:<angulo>   ej: S3:100
 * Limites mecanicos reales aplicados aqui con clamp por ambos lados.
 */
static void procesar_comando_directo(char *cmd,
                                      servo_t *s1, servo_t *s2,
                                      servo_t2_t *s3, servo_t0_t *s4)
{
    if (strlen(cmd) < 4)
    {
        writeString("\r\nComando invalido\r\n");
        return;
    }

    if (cmd[0] != 'S')
    {
        writeString("\r\nFormato invalido\r\n");
        return;
    }

    uint8_t servo_id = cmd[1] - '0';
    char   *ptr      = strchr(cmd, ':');

    if (ptr == NULL)
    {
        writeString("\r\nFalta ':'\r\n");
        return;
    }

    ptr++;
    uint8_t angulo = (uint8_t)atoi(ptr);

    switch (servo_id)
    {
        case 1:
            if (angulo < SERVO1_MIN_ANGLE) angulo = SERVO1_MIN_ANGLE;
            if (angulo > SERVO1_MAX_ANGLE) angulo = SERVO1_MAX_ANGLE;
            pwm_servo_set_angle(s1, angulo);
            enviar_feedback(1, angulo);
            break;

        case 2:
            if (angulo < SERVO2_MIN_ANGLE) angulo = SERVO2_MIN_ANGLE;
            if (angulo > SERVO2_MAX_ANGLE) angulo = SERVO2_MAX_ANGLE;
            pwm_servo_set_angle(s2, angulo);
            enviar_feedback(2, angulo);
            break;

        case 3:
            if (angulo < SERVO3_MIN_ANGLE) angulo = SERVO3_MIN_ANGLE;
            if (angulo > SERVO3_MAX_ANGLE) angulo = SERVO3_MAX_ANGLE;
            pwm_servo_t2_set_angle(s3, angulo);
            enviar_feedback(3, angulo);
            break;

        case 4:
            if (angulo < SERVO4_MIN_ANGLE) angulo = SERVO4_MIN_ANGLE;
            if (angulo > SERVO4_MAX_ANGLE) angulo = SERVO4_MAX_ANGLE;
            pwm_servo_t0_set_angle(s4, angulo);
            enviar_feedback(4, angulo);
            break;

        default:
            writeString("\r\nServo invalido (1-4)\r\n");
            break;
    }
}

/****************************************/
// ADC
static void adc_init(void)
{
    ADMUX  = (1 << REFS0);
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
    ADCSRA |= (1 << ADSC);
    while (ADCSRA & (1 << ADSC));
}

static uint16_t adc_read(uint8_t channel)
{
    ADMUX  = (ADMUX & 0xF0) | (channel & 0x0F);
    ADCSRA |= (1 << ADSC);
    while (ADCSRA & (1 << ADSC));
    return ADC;
}

static int32_t map_value(int32_t val, int32_t in_min, int32_t in_max,
                          int32_t out_min, int32_t out_max)
{
    return out_min + (val - in_min)
           * (out_max - out_min) / (in_max - in_min);
}

/****************************************/
// ISR UART
ISR(USART_RX_vect)
{
    datoRX     = UDR0;
    ExisteDato = 1;
}