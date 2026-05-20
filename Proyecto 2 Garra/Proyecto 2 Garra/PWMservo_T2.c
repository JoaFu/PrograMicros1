/*
 * PWMservo_T2.c
 *
 * Servo PWM por hardware usando TIMER2 / OC2B -> PD3
 * ATMega328P @ 16MHz
 *
 * Fast PWM, TOP = OCR2A = 255, prescaler 1024
 * tick = 64 us  ->  periodo = 256 * 64 us = 16.384 ms (~16 ms)
 *
 * Conversion us -> ticks: ticks = us / 64
 *   500  us / 64 =  7 ticks  (0 grados)
 *   1450 us / 64 = 22 ticks  (90 grados)
 *   2400 us / 64 = 37 ticks  (180 grados)
 *
 * Todos los valores caben en uint8_t sin clamp problematico.
 * El SG90 tolera el periodo de 16 ms sin problema.
 */

#define F_CPU 16000000UL
#include "PWMservo_T2.h"

/****************************************/
/* CONSTANTES INTERNAS                  */

/* tick = 64 us */
#define T2_TICK_US_VAL     64UL

/* us -> ticks: dividir por 64 */
#define T2_US_TO_OCR(us)   ((uint8_t)((us) / T2_TICK_US_VAL))

/****************************************/
/* INIT INTERNO                         */

static void timer2_hw_init(void)
{
    TCCR2A = 0x00;
    TCCR2B = 0x00;

    /*
     * Fast PWM, TOP = OCR2A (WGM = 111)
     * WGM22 en TCCR2B bit 3
     * WGM21:20 en TCCR2A bits 1:0
     */
    TCCR2A |= (1 << WGM21) | (1 << WGM20);
    TCCR2B |= (1 << WGM22);

    /* OC2B no-inversor */
    TCCR2A |= (1 << COM2B1);

    /*
     * Prescaler 1024: CS22=1, CS21=1, CS20=1
     * tick = 16MHz / 1024 = 64 us
     */
    TCCR2B |= (1 << CS22) | (1 << CS21) | (1 << CS20);

    /* TOP = 255 -> periodo = 256 * 64 us = 16.384 ms */
    OCR2A = T2_TOP;

    /* PD3 (OC2B) como salida */
    DDRD |= (1 << DDD3);
}

/****************************************/
/* INIT                                 */

void pwm_servo_t2_init(servo_t2_t *servo)
{
    pwm_servo_t2_init_at(servo, T2_MAX_ANGLE / 2U);
}

void pwm_servo_t2_init_at(servo_t2_t *servo, uint8_t initial_angle)
{
    timer2_hw_init();
    pwm_servo_t2_set_angle(servo, initial_angle);
}

/****************************************/
/* SET MICROSECONDS                     */

void pwm_servo_t2_set_us(servo_t2_t *servo, uint16_t pulse_us)
{
    if (pulse_us < T2_MIN_PULSE_US) pulse_us = T2_MIN_PULSE_US;
    if (pulse_us > T2_MAX_PULSE_US) pulse_us = T2_MAX_PULSE_US;

    servo->current_pulse_us = pulse_us;

    /*
     * ticks = us / 64
     * 500  us -> 7
     * 2400 us -> 37
     * Siempre < 255, sin clamp problematico
     */
    OCR2B = T2_US_TO_OCR(pulse_us);
}

/****************************************/
/* SET ANGLE                            */

void pwm_servo_t2_set_angle(servo_t2_t *servo, uint8_t angle)
{
    if (angle > T2_MAX_ANGLE) angle = T2_MAX_ANGLE;

    servo->current_angle = angle;

    uint16_t pulse_us = T2_MIN_PULSE_US +
        ((uint32_t)angle * (T2_MAX_PULSE_US - T2_MIN_PULSE_US)) / T2_MAX_ANGLE;

    pwm_servo_t2_set_us(servo, pulse_us);
}

/****************************************/
/* GET                                  */

uint16_t pwm_servo_t2_get_us(const servo_t2_t *servo)
{
    return servo->current_pulse_us;
}

uint8_t pwm_servo_t2_get_angle(const servo_t2_t *servo)
{
    return servo->current_angle;
}

/****************************************/
/* STOP                                 */

void pwm_servo_t2_stop(servo_t2_t *servo)
{
    TCCR2A &= ~(1 << COM2B1);
    OCR2B   = 0;
    PORTD  &= ~(1 << PORTD3);

    servo->current_pulse_us = 0;
    servo->current_angle    = 0;
}