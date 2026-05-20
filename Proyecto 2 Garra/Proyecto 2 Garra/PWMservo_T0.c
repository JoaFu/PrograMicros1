/*
 * PWMservo_T0.c
 *
 * Servo PWM por hardware usando TIMER0 / OC0B -> PD5
 * ATMega328P @ 16MHz
 *
	 * Fast PWM, TOP = OCR0A = 249, prescaler 1024
 * Periodo ~16 ms, tick = 64 us
 * Rango: 10-33 ticks (640 us - 2112 us), angulo 0-100 grados
 */

#define F_CPU 16000000UL
#include "PWMservo_T0.h"

/****************************************/
/* INIT INTERNO — configura el timer    */

static void timer0_hw_init(void)
{
    TCCR0A = 0x00;
    TCCR0B = 0x00;

    /*
     * Fast PWM, TOP = OCR0A (WGM = 111)
     * WGM02 en TCCR0B bit 3
     * WGM01:00 en TCCR0A bits 1:0
     */
    TCCR0A |= (1 << WGM01) | (1 << WGM00);
    TCCR0B |= (1 << WGM02);

    /*
     * OC0B no-inversor: clear on compare, set on TOP
     * OC0A queda desconectado (PD6 libre para GPIO)
     */
    TCCR0A |= (1 << COM0B1);

    /*
     * Prescaler 1024: CS02=1, CS01=0, CS00=1
     */
    TCCR0B |= (1 << CS02) | (1 << CS00);

    /* TOP del periodo */
    OCR0A = T0_TOP;

    /* PD5 (OC0B) como salida */
    DDRD |= (1 << DDD5);
}

/****************************************/
/* INIT — posicion central por defecto  */

void pwm_servo_t0_init(servo_t0_t *servo)
{
    pwm_servo_t0_init_at(servo, T0_MAX_ANGLE / 2U);
}

/****************************************/
/* INIT — posicion inicial especificada */

void pwm_servo_t0_init_at(servo_t0_t *servo, uint8_t initial_angle)
{
    timer0_hw_init();
    pwm_servo_t0_set_angle(servo, initial_angle);
}

/****************************************/
/* SET TICKS (control directo)          */

void pwm_servo_t0_set_ticks(servo_t0_t *servo, uint8_t ticks)
{
    if (ticks < T0_MIN_TICKS) ticks = T0_MIN_TICKS;
    if (ticks > T0_MAX_TICKS) ticks = T0_MAX_TICKS;

    servo->current_ticks = ticks;
    OCR0B = ticks;
}

/****************************************/
/* SET ANGLE                            */

void pwm_servo_t0_set_angle(servo_t0_t *servo, uint8_t angle)
{
    if (angle > T0_MAX_ANGLE) angle = T0_MAX_ANGLE;

    servo->current_angle = angle;

    uint8_t ticks = (uint8_t)(
        T0_MIN_TICKS +
        ((uint16_t)angle * (T0_MAX_TICKS - T0_MIN_TICKS)) / T0_MAX_ANGLE
    );

    pwm_servo_t0_set_ticks(servo, ticks);
}

/****************************************/
/* GET TICKS                            */

uint8_t pwm_servo_t0_get_ticks(const servo_t0_t *servo)
{
    return servo->current_ticks;
}

/****************************************/
/* GET ANGLE                            */

uint8_t pwm_servo_t0_get_angle(const servo_t0_t *servo)
{
    return servo->current_angle;
}

/****************************************/
/* STOP                                 */

void pwm_servo_t0_stop(servo_t0_t *servo)
{
    TCCR0A &= ~(1 << COM0B1);
    OCR0B   = 0;
    PORTD  &= ~(1 << PORTD5);

    servo->current_ticks = 0;
    servo->current_angle = 0;
}