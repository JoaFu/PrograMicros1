/*
 * PWMservo2.c
 *
 * Created: 16-04-2026
 * Author: Joaquín Fuentes
 *
 * Usa el Timer2 en modo Fast PWM (modo 7, TOP = OCR2A).
 * Genera una señal de 50Hz en OC2B (PD3 / D3).
 *
 *  F_timer = 16MHz / 1024 = 15625Hz  ?  1 tick = 64us
 *  TOP (OCR2A) = 15625 / 50 - 1 = 311
 *  OCR2B = microsegundos / 64
 *    500us (0°)   =>  OCR2B = 7
 *    1500us (90°) =>  OCR2B = 23
 *    2400us (180°)=>  OCR2B = 37
 */
#define F_CPU 16000000
#include "PWMservo2.h"

/****************************************/
// Variable Externa
static uint16_t current_pulse_width_us2 = 1500U;
/****************************************/
// Implementación
void pwm_servo_init2(void)
{
    DDRD |= (1<<DDD3);
    // Detener timer antes de reconfigurar
    TCCR2A = 0;
    TCCR2B = 0;
    // Período: OCR2A = TOP = 311 => ~20 ms
    OCR2A = (uint8_t)PWM2_TIMER_TOP_VALUE;
    // Fast PWM con TOP en OCR2A, modo no invertido en OC2B
    TCCR2A = (1<<COM2B1) | (1<<WGM21) | (1<<WGM20);
    TCCR2B = (1<<WGM22) | (1<<CS22) | (1<<CS21) | (1<<CS20);
    // 90° posición inicial
    pwm_servo_set_us2(1500U);
}
void pwm_servo_set_us2(uint16_t pulse_width_us)
{
    if (pulse_width_us < PWM2_MIN_PULSE_WIDTH_US) 
        pulse_width_us = PWM2_MIN_PULSE_WIDTH_US;
        
    if (pulse_width_us > PWM2_MAX_PULSE_WIDTH_US) 
        pulse_width_us = PWM2_MAX_PULSE_WIDTH_US;
    current_pulse_width_us2 = pulse_width_us;
    OCR2B = PWM2_MICROSECONDS_TO_TICKS(pulse_width_us);
}
void pwm_servo_set_angle2(uint8_t angle_degrees)
{
    if (angle_degrees > 180U) 
		angle_degrees = 180U;
    uint16_t pulse_width_us = (uint16_t)(PWM2_MIN_PULSE_WIDTH_US + ((uint32_t)angle_degrees * (PWM2_MAX_PULSE_WIDTH_US - PWM2_MIN_PULSE_WIDTH_US)) / 180U);
    pwm_servo_set_us2(pulse_width_us);
}
uint16_t pwm_servo_get_us2(void)
{
    return current_pulse_width_us2;
}
void pwm_servo_stop2(void)
{
    TCCR2A = 0;
    TCCR2B = 0;
    OCR2B  = 0;
    PORTD &= ~(1<<PORTD3);
}