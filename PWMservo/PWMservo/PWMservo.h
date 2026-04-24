/*
 * PWMservo.c
 *
 * Created: 16-04-2026
 * Author: Joaquín Fuentes
 *
 * Usa el Timer1 en modo Fast PWM (modo 14, TOP = ICR1).
 * Genera una señal de 50Hz en OC1A (PB1).
 *
 *  F_timer = 16MHz / 8 = 2MHz  ?  1 tick = 0.5us
 *  TOP (ICR1) = 39999  ?  período 20 ms (50 Hz)
 *  OCR1A = microsegundos × 2 ? 1
 *    1000us (0°)	=>	 OCR1A = 1999
 *    1500us (90°)  =>	 OCR1A = 2999
 *    2000us (180°) =>   OCR1A = 3999
 */

#ifndef PWMSERVO_H
#define PWMSERVO_H

#ifndef F_CPU
#define F_CPU 16000000UL
#endif

#include <avr/io.h>
#include <stdint.h>

/****************************************/
// Constantes

#define PWM_SERVO_FREQUENCY_HZ    50UL
#define PWM_TIMER_PRESCALER       8UL
#define PWM_TIMER_CLOCK_HZ        (F_CPU / PWM_TIMER_PRESCALER)
#define PWM_TIMER_TOP_VALUE       ((PWM_TIMER_CLOCK_HZ / PWM_SERVO_FREQUENCY_HZ) - 1UL)

#define PWM_MIN_PULSE_WIDTH_US    500U
#define PWM_MAX_PULSE_WIDTH_US    2400U

#define PWM_MICROSECONDS_TO_TICKS(pulse_width_us)  ((uint16_t)((pulse_width_us) * 2U - 1U))

/****************************************/
// Funciones

void     pwm_servo_init(void);
void     pwm_servo_set_us(uint16_t pulse_width_us);
void     pwm_servo_set_angle(uint8_t angle_degrees);
uint16_t pwm_servo_get_us(void);
void     pwm_servo_stop(void);

#endif /* PWMSERVO_H */