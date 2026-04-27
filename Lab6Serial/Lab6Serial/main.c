/*
 * Laboratorio Serial
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

void initADC(void);
uint16_t leerADC(void);
void mostrarByte(uint8_t dato);
void cadena(char txt[]);
uint8_t esperarByte(void);

/****************************************/
// Variables globales

volatile uint8_t datoRX = 0;
volatile uint8_t ExisteDato = 0; 

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
		cadena("===================MENU=================== \n");
		cadena("¡Hola de nuevo! \n");
		cadena ("Inserte el número sin punto de la opción deseada\n");
		cadena ("1. Leer potenciómetro \n 2. Enviar ACSII \n");
		
		uint8_t opcion = esperarByte();
		if (opcion == '1')
		{
			cadena ("\n Seleccionaste la opcion 1\n");
			cadena ("----------------------------------------\n");
			uint16_t valor = leerADC();
			char caracter = (char)((valor * 94UL) / 1023 + 0x20);
			cadena("Valor leido: ");
			writeChar(caracter);
			cadena("\n----------------------------------------\n");
			_delay_ms(2000);   // tiempo para leer el resultado
		}
		else if (opcion == '2')
		{
			cadena("\n Seleccionaste la opcion 2\n");
			cadena("Inserta el ASCII a enviar: ");
			uint8_t ascii = esperarByte();   // espera un nuevo byte, ya no es '2'
			cadena("\n----------------------------------------\n");
			mostrarByte(ascii);
			cadena("Enviado a LEDs\n");
			cadena("----------------------------------------\n");
			_delay_ms(2000);   // tiempo para ver los LEDs
		}
		else
		{
			cadena("\nOpcion no valida, volviendo al menu...\n");
			_delay_ms(1000);
		}
	}
}

/****************************************/
// NON-Interrupt subroutines

uint8_t esperarByte(void)
{
	while (!ExisteDato);
	ExisteDato = 0;
	return datoRX;
}
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
    uint8_t bajo = dato & 0x0F;      // Nibble bajo (bits 0-3)
    uint8_t alto = (dato >> 4) & 0x0F; // Nibble alto (bits 4-7)

    // Multiplexado continuo por 2 segundos
    for(int i = 0; i < 1000; i++) {
        // Mostrar nibble bajo (PB5 activa transistor nibble bajo)
        PORTB = (1<<PB5) | bajo;
        _delay_ms(1);
        
        // Mostrar nibble alto (PB4 activa transistor nibble alto)
        PORTB = (1<<PB4) | alto;
        _delay_ms(1);
    }
    
    // Apagar LEDs al terminar
    PORTB = 0x00;
}

void cadena(char txt[])
{
	while (*txt)
	{
		writeChar(*txt++);
	}
}

/****************************************/
// Interrupt routines

ISR(USART_RX_vect)
{
    datoRX = UDR0;      // Guardar dato recibido
	ExisteDato = 1;		// Se avise la existencia del nuevo dato
    writeChar(datoRX);  // Eco hacia terminal
}