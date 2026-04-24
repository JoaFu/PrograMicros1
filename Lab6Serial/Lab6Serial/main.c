/*
 * PreLab6serial
 *
 * Created: 24/04/2026
 * Author: Joaquín Fuentes
 * Description: 
 */
/****************************************/
// Encabezado (Libraries)

#define F_CPU 16000000
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include "UART.h"

/****************************************/
// Function prototypes

void cadena(char txt[]);
void initADC(void);
uint16_t leerADC(void);
void mostrarByte(uint8_t dato);

/****************************************/
// Variables globales

volatile uint8_t datoRX = 0;

/****************************************/
// Main Function

int main(void)
{
    cli();

    DDRB  = 0x3F; // PB0–PB5 salida
    PORTB = 0x00;

    initADC();
    initUART();

    sei();

    while (1)
    {
        // ADC -> UART
        uint16_t valor = leerADC();
        char caracter = (char)((valor * 94UL) / 1023 + 0x20);
        writeChar(caracter);

        // Mostrar recibido (por el multiplexado)
        mostrarByte(datoRX);
    }
}

/****************************************/
// NON-Interrupt subroutines

void initADC(void)
{
    DIDR0 |= (1<<ADC0D);
    ADMUX  = (1<<REFS0); // AVcc, ADC0
    ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0); // prescaler 128
}

uint16_t leerADC(void)
{
    ADCSRA |= (1<<ADSC);
    while (ADCSRA & (1<<ADSC));
    return ADC;
}

void mostrarByte(uint8_t dato)
{
    uint8_t bajo = dato & 0x0F;
    uint8_t alto = (	dato >> 4) & 0x0F; 

    // Nibble bajo
    PORTB = (1<<PB5) | bajo;
    _delay_ms(2);

    // Nibble alto
    PORTB = (1<<PB4) | alto;
    _delay_ms(2);
}

/****************************************/
// Interrupt routines

ISR(USART_RX_vect)
{
    datoRX = UDR0;      // Guardar dato recibido
    writeChar(datoRX);  // Eco hacia terminal
}