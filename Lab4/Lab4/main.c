/*
 * Lab04.c
 *
 * Created: 2026
 * Author: Joaquín Fuentes 
 * Description: Contador binario 8 bits con ADC, multiplexado de displays
 *              y LED de alarma.
 */

/****************************************/
// Encabezado (Libraries)
#define F_CPU 16000000
#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdint.h>

// Pines
#define BTN_UP   PC1
#define BTN_DOWN PC2
#define CTRL     PC3
#define DIG1     PC4
#define DIG2     PC5
#define ALARM    PB5

// Variables globales
volatile uint8_t counter  = 0;
volatile uint8_t pot      = 0;
volatile uint8_t flag_up  = 0;
volatile uint8_t flag_down = 0;

// Tabla 7 segmentos 0-F
const uint8_t hex_seg[16] = {
    0b00111111, 0b00000110, 0b01011011, 0b01001111,
    0b01100110, 0b01101101, 0b01111101, 0b00000111,
    0b01111111, 0b01101111, 0b01110111, 0b01111100,
    0b00111001, 0b01011110, 0b01111001, 0b01110001
};

/****************************************/
// Function prototypes
void ports_init(void);
void timer0_init(void);
void adc_init(void);

/****************************************/
// Main Function
int main(void)
{
    ports_init();
    adc_init();
    timer0_init();
    sei();

    uint8_t up_lock   = 0;
    uint8_t down_lock = 0;

    while (1)
    {
        // Boton subir
        if (flag_up)
        {
            flag_up = 0;
            if (!up_lock) { counter++; up_lock = 1; }
        }
        else if (PINC & (1<<BTN_UP)) up_lock = 0;

        // Boton bajar
        if (flag_down)
        {
            flag_down = 0;
            if (!down_lock) { counter--; down_lock = 1; }
        }
        else if (PINC & (1<<BTN_DOWN)) down_lock = 0;

        // Alarma: ADC > contador
        if (pot > counter)
            PORTB |=  (1<<ALARM);
        else
            PORTB &= ~(1<<ALARM);
    }
}

/****************************************/
// NON-Interrupt subroutines
void ports_init(void)
{
    DDRD  = 0xFF;
    DDRC &= ~((1<<BTN_UP)|(1<<BTN_DOWN));
    PORTC |=  (1<<BTN_UP)|(1<<BTN_DOWN);
    DDRC  |=  (1<<CTRL)|(1<<DIG1)|(1<<DIG2);
    DDRB  |=  (1<<ALARM);
    PORTC &= ~((1<<CTRL)|(1<<DIG1)|(1<<DIG2));
    PORTB &= ~(1<<ALARM);
    PORTD  =  0x00;
}

void timer0_init(void)
{
    TCCR0A = (1<<WGM01);
    TCCR0B = (1<<CS01)|(1<<CS00);  // Prescaler 64
    OCR0A  = 124;                  // 2 kHz
    TIMSK0 = (1<<OCIE0A);
}

void adc_init(void)
{
    ADMUX  = (1<<REFS0)|(1<<ADLAR);            // Justificación a la izquierda (8 bits en ADCH)
    ADCSRA = (1<<ADEN)|(1<<ADATE)|(1<<ADIE)
            |(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0); // Free-running, interrupción, /128
    ADCSRA |= (1<<ADSC);
}

/****************************************/
// Interrupt routines
ISR(TIMER0_COMPA_vect)
{
    static uint8_t fase = 0;

    // Apagar todos los drivers antes de cambiar datos
    PORTC &= ~((1<<DIG1)|(1<<DIG2)|(1<<CTRL));
    PORTD  = 0x00;

    switch (fase)
    {
        case 0: // Digito alto del ADC en hex
            PORTD = hex_seg[(pot >> 4) & 0x0F];
            PORTC |= (1<<DIG1);
            break;
        case 1: // Digito bajo del ADC en hex
            PORTD = hex_seg[pot & 0x0F];
            PORTC |= (1<<DIG2);
            break;
        case 2: // Contador binario en LEDs
            PORTD = counter;
            PORTC |= (1<<CTRL);
            break;
    }

    fase++;

    if (fase == 3)
    {
	    fase = 0;
    }

    // Debounce cada 10ms (20 ticks a 2kHz)
    static uint8_t debounce_tick = 0;
    if (++debounce_tick >= 20)
    {
        debounce_tick = 0;
        if (!(PINC & (1<<BTN_UP)))   flag_up   = 1;
        if (!(PINC & (1<<BTN_DOWN))) flag_down = 1;
    }
}

ISR(ADC_vect)
{
    pot = ADCH;
}