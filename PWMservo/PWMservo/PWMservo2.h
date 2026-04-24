/*
 * PWMservo2.h
 *
 * Created: 16-04-2026
 * Author: Joaquín Fuentes
 *
 * Usa el Timer2 en modo Fast PWM (modo 7, TOP = OCR2A).
 * Genera una señal de 50Hz en OC2B (PD3).
 *
 *  F_timer = 16MHz / 1024 = 15625Hz  ?  1 tick = 64us
 *  TOP (OCR2A) = 15625 / 50 - 1 = 311
 *  OCR2B = microsegundos / 64
 *    500us (0°)   =>  OCR2B = 7
 *    1500us (90°) =>  OCR2B = 23
 *    2400us (180°)=>  OCR2B = 37
 */
#ifndef PWMSERVO2_H
#define PWMSERVO2_H
#ifndef F_CPU
#define F_CPU 16000000UL
#endif
#include <avr/io.h>
#include <stdint.h>
/****************************************/
// Constantes
#define PWM2_SERVO_FREQUENCY_HZ    50UL
#define PWM2_TIMER_PRESCALER       1024UL
#define PWM2_TIMER_CLOCK_HZ        (F_CPU / PWM2_TIMER_PRESCALER)
#define PWM2_TIMER_TOP_VALUE       ((PWM2_TIMER_CLOCK_HZ / PWM2_SERVO_FREQUENCY_HZ) - 1UL)
#define PWM2_MIN_PULSE_WIDTH_US    500U
#define PWM2_MAX_PULSE_WIDTH_US    2400U
#define PWM2_MICROSECONDS_TO_TICKS(pulse_width_us)  ((uint8_t)((pulse_width_us) / 64U))
/****************************************/
// Funciones
void     pwm_servo_init2(void);
void     pwm_servo_set_us2(uint16_t pulse_width_us);
void     pwm_servo_set_angle2(uint8_t angle_degrees);
uint16_t pwm_servo_get_us2(void);
void     pwm_servo_stop2(void);
#endif /* PWMSERVO2_H */