/*
 * PWMservo_T2.h
 *
 * Servo PWM por hardware usando TIMER2 / OC2B -> PD3
 * ATMega328P @ 16MHz
 *
 * Fast PWM, TOP = OCR2A = 255, prescaler 1024
 * tick = 64 us  ->  periodo = 16.384 ms
 *
 * Rango de pulso en ticks:
 *   500  us / 64 =  7  (0 grados)
 *   2400 us / 64 = 37  (180 grados)
 * Todos caben en uint8_t sin saturar OCR2B.
 *
 * Interfaz basada en microsegundos reales, igual que TIMER1.
 * Limites mecanicos aplicados en main.c y Python, no aqui.
 */

#ifndef PWMSERVO_T2_H_
#define PWMSERVO_T2_H_

#ifndef F_CPU
#define F_CPU 16000000UL
#endif

#include <avr/io.h>
#include <stdint.h>

/****************************************/
/* CONFIGURACION                        */

#define T2_TOP              255U

#define T2_MIN_PULSE_US     500U
#define T2_MAX_PULSE_US     2400U

#define T2_MAX_ANGLE        180U

/****************************************/
/* ESTRUCTURA                           */

typedef struct
{
    uint16_t current_pulse_us;
    uint8_t  current_angle;

} servo_t2_t;

/****************************************/
/* API                                  */

void     pwm_servo_t2_init(servo_t2_t *servo);
void     pwm_servo_t2_init_at(servo_t2_t *servo, uint8_t initial_angle);

void     pwm_servo_t2_set_us(servo_t2_t *servo, uint16_t pulse_us);
void     pwm_servo_t2_set_angle(servo_t2_t *servo, uint8_t angle);

uint16_t pwm_servo_t2_get_us(const servo_t2_t *servo);
uint8_t  pwm_servo_t2_get_angle(const servo_t2_t *servo);

void     pwm_servo_t2_stop(servo_t2_t *servo);

#endif /* PWMSERVO_T2_H_ */