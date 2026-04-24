/*
 * main.c
 *
 * Created: 16-04-2026
 * Author: Joaquín Fuentes
 * Description: Control de dos servos y LED con potenciómetros (ATmega328P / Arduino Nano)
 */
/****************************************/
// Encabezado (Libraries)
#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include "PWMservo.h"
#include "PWMservo2.h"
#include "PWMLed.h"
/****************************************/
// Function prototypes
static void adc_init(void);
static uint16_t adc_read(uint8_t adc_channel);
static int32_t map_value(int32_t input_value, int32_t input_min,  int32_t input_max, int32_t output_min, int32_t output_max);
/****************************************/
// Main Function
int main(void)
{
    adc_init();
    pwm_servo_init();
    pwm_servo_init2();
    pwm_led_init();
    
    uint16_t adc_reading;
    uint16_t pulse_width_us;
    uint16_t pulse_width_us2;
    uint8_t  led_brightness;
    
    while (1)
    {
        // Control de Servo 1 con potenciómetro A0 (Timer1)
        adc_reading = adc_read(0);
        pulse_width_us = (uint16_t)
		map_value((int32_t)adc_reading, 0, 1023, PWM_MIN_PULSE_WIDTH_US, PWM_MAX_PULSE_WIDTH_US);
        pwm_servo_set_us(pulse_width_us);
        
        // Control de Servo 2 con potenciómetro A1 (Timer2)
        adc_reading = adc_read(1);
        pulse_width_us2 = (uint16_t)
		map_value((int32_t)adc_reading, 0, 1023, PWM2_MIN_PULSE_WIDTH_US, PWM2_MAX_PULSE_WIDTH_US);
        pwm_servo_set_us2(pulse_width_us2);
        
        // Control de LED con potenciómetro A2 (Timer0)
        adc_reading = adc_read(2);
        led_brightness = (uint8_t)
        map_value((int32_t)adc_reading, 0, 1023, 0, 255);
        pwm_led_set_duty(led_brightness);
        
        _delay_ms(20);
    }
    return 0;
}
/****************************************/
// NON-Interrupt subroutines
// Inicializar ADC (AVCC, prescaler 128)
static void adc_init(void)
{
    ADMUX = (1<<REFS0);
    ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0); // Dividido por 128
    ADCSRA |= (1<<ADSC); //ADC Start Conversion
    while (ADCSRA & (1<<ADSC));
}
// Lectura ADC
static uint16_t adc_read(uint8_t adc_channel)
{
    ADMUX = (ADMUX & 0xF0) | (adc_channel & 0x0F);
    ADCSRA |= (1<<ADSC);
    while (ADCSRA & (1<<ADSC));
    return ADC;
}
// Mapea rango de valores
static int32_t map_value(int32_t input_value, int32_t input_min,  int32_t input_max, int32_t output_min, int32_t output_max)
{
	//y   = b          +      (x-input_min)       *       m
    return output_min + (input_value - input_min) * (output_max - output_min) / (input_max - input_min);
}


/*
0 -  output_min
1023 - output_max

y = mx + b

/****************************************/
// Interrupt routines