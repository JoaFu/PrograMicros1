/*
 * PWMservo.c
 *
 * Created: 16-04-2026
 * Author: Joaquín Fuentes
 */

#define F_CPU 16000000
#include "PWMservo.h"

/****************************************/
// Varible interna
static uint16_t current_pulse_width_us = 1500U;

/****************************************/
// Implementación

void pwm_servo_init(void)
{
    DDRB |= (1<<DDB1);

    // Detener timer antes de reconfigurar
    TCCR1A = 0;
    TCCR1B = 0;

    // Período: ICR1 = TOP = 39999 ? 20 ms 
    ICR1 = (uint16_t)PWM_TIMER_TOP_VALUE;

    // Fast PWM con TOP en ICR1
    TCCR1A = (1<<COM1A1) | (1<<WGM11);
    TCCR1B = (1<<WGM13)  | (1<<WGM12) | (1<<CS11);

    // 90° posición inicial
    pwm_servo_set_us(1500U);
}

void pwm_servo_set_us(uint16_t pulse_width_us)
{
    if (pulse_width_us < PWM_MIN_PULSE_WIDTH_US) 
        pulse_width_us = PWM_MIN_PULSE_WIDTH_US;
        
    if (pulse_width_us > PWM_MAX_PULSE_WIDTH_US) 
        pulse_width_us = PWM_MAX_PULSE_WIDTH_US;

    current_pulse_width_us = pulse_width_us;
    OCR1A = PWM_MICROSECONDS_TO_TICKS(pulse_width_us);
}

void pwm_servo_set_angle(uint8_t angle_degrees)
{
    if (angle_degrees > 180U) 
		angle_degrees = 180U; //Seguridad

    uint16_t pulse_width_us = (uint16_t)(PWM_MIN_PULSE_WIDTH_US + ((uint32_t)angle_degrees * (PWM_MAX_PULSE_WIDTH_US - PWM_MIN_PULSE_WIDTH_US)) / 180U);
    pwm_servo_set_us(pulse_width_us);
}

uint16_t pwm_servo_get_us(void)
{
    return current_pulse_width_us;
}

void pwm_servo_stop(void)
{
    TCCR1A = 0;
    TCCR1B = 0;
    OCR1A  = 0;
    PORTB &= ~(1<<PORTB1);
}