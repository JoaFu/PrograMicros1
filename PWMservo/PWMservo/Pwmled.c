/*
 * PWMLed.c
 *
 * Created: 16-04-2026
 * Author: Joaquín Fuentes
 *
 * Usa el Timer0 en modo Fast PWM (modo 3, TOP = 0xFF).
 * Genera una señal PWM en OC0B (PD5 / D5) para control de LED.
 *
 *  F_timer = 16MHz / 256 = 62.5kHz
 *  OCR0B = valor de 0-255 para duty cycle 0-100%
 */
#define F_CPU 16000000
#include "PWMLed.h"

/****************************************/
// Variable Externa
static uint8_t current_duty_cycle = 0U;
/****************************************/
// Implementación
void pwm_led_init(void)
{
    DDRD |= (1<<DDD5);
    // Detener timer antes de reconfigurar
    TCCR0A = 0;
    TCCR0B = 0;
    // Fast PWM modo 3 (TOP = 0xFF), no invertido en OC0B
    TCCR0A = (1<<COM0B1) | (1<<WGM01) | (1<<WGM00);
    TCCR0B = (1<<CS02);
    // LED apagado inicialmente
    pwm_led_set_duty(0U);
}
void pwm_led_set_duty(uint8_t duty_cycle)
{
    current_duty_cycle = duty_cycle;
    OCR0B = duty_cycle;
}
void pwm_led_set_percent(uint8_t percent)
{
    if (percent > 100U) 
        percent = 100U;
    uint8_t duty_cycle = (uint8_t)(((uint16_t)percent * 255U) / 100U);
    pwm_led_set_duty(duty_cycle);
}
uint8_t pwm_led_get_duty(void)
{
    return current_duty_cycle;
}
void pwm_led_stop(void)
{
    TCCR0A = 0;
    TCCR0B = 0;
    OCR0B  = 0;
    PORTD &= ~(1<<PORTD5);
}