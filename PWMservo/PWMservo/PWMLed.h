/*
 * PWMLed.h
 *
 * Created: 16-04-2026
 * Author: Joaquín Fuentes
 *
 * Usa el Timer0 en modo Fast PWM (modo 3, TOP = 0xFF).
 * Genera una señal PWM en OC0B (PD5) para control de LED.
 *
 *  F_timer = 16MHz / 256 = 62.5kHz
 *  OCR0B = valor de 0-255 para duty cycle 0-100%
 */
#ifndef PWMLED_H
#define PWMLED_H
#ifndef F_CPU
#define F_CPU 16000000UL
#endif
#include <avr/io.h>
#include <stdint.h>
/****************************************/
// Constantes
#define PWM_LED_FREQUENCY_HZ      ((F_CPU / 256UL) / 256UL)
#define PWM_LED_MAX_DUTY          255U
/****************************************/
// Funciones
void     pwm_led_init(void);
void     pwm_led_set_duty(uint8_t duty_cycle);
void     pwm_led_set_percent(uint8_t percent);
uint8_t pwm_led_get_duty(void);
void     pwm_led_stop(void);
#endif /* PWMLED_H */