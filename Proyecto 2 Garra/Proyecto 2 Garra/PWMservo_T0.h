/*
 * PWMservo_T0.h
 *
 * Servo PWM por hardware usando TIMER0 / OC0B
 * ATMega328P @ 16MHz
 *
 * Canal: OC0B -> PD5
 *
 * Fast PWM TOP = OCR0A, prescaler 1024
 * tick = 64 us, OCR0A = 249 -> periodo ~16 ms
 *
 * OC0A (PD6) se usa como TOP (WGM=7), no disponible como PWM.
 *
 * ADVERTENCIA: TIMER0 es el mismo timer que millis() en Arduino.
 * En bare-metal no hay conflicto.
 */

#ifndef PWMSERVO_T0_H_
#define PWMSERVO_T0_H_

#ifndef F_CPU
#define F_CPU 16000000UL
#endif

#include <avr/io.h>
#include <stdint.h>

/****************************************/
/* CONFIGURACION TIMER0                 */

#define T0_PRESCALER           1024UL
#define T0_TICK_US             (1000000UL / (F_CPU / T0_PRESCALER))  /* 64 us */
#define T0_TOP                 249U                                   /* OCR0A */

#define T0_MIN_TICKS           10U    /*  640 us ~ 0 grados   */
#define T0_MAX_TICKS           33U    /* 2112 us ~ 100 grados */

#define T0_MAX_ANGLE           100U

/****************************************/
/* ESTRUCTURA SERVO T0                  */

typedef struct
{
    uint8_t current_ticks;
    uint8_t current_angle;

} servo_t0_t;

/****************************************/
/* API                                  */

void    pwm_servo_t0_init(servo_t0_t *servo);
void    pwm_servo_t0_init_at(servo_t0_t *servo, uint8_t initial_angle);

void    pwm_servo_t0_set_ticks(servo_t0_t *servo, uint8_t ticks);
void    pwm_servo_t0_set_angle(servo_t0_t *servo, uint8_t angle);

uint8_t pwm_servo_t0_get_ticks(const servo_t0_t *servo);
uint8_t pwm_servo_t0_get_angle(const servo_t0_t *servo);

void    pwm_servo_t0_stop(servo_t0_t *servo);

#endif /* PWMSERVO_T0_H_ */