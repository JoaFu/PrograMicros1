/*
 * ClaseEjercicioSERIAL.c
 *
 * Created: 22/04/2026 16:23:18
 * Author : joaqu
 */ 

#include <avr/io.h>
#include "avr/interrupt.h"
#include "UART.h"


int main(void)
{
    /* Replace with your application code */

		cli();
		DDRD |= (1<<DDD6)	| (1<<DDD5);
		PORTD &= ~((1<<PORTD6) | (1<<PORTD5));
		//PD2 como pull up habilitado
		DDRD &= ~(1<<DDD2);
		PORTD |= (1<<PORTD2);
		
		PCICR |= (1<<PCIE2);
		PCMSK2 |= (1<<PCINT18);
		initUART();
		sei();
		V
        while (1)
        {
		}
}

//Interrupt routines

ISR(USART_RX_vect)
{
	char bufferRX = UDR0;
	writeChar(bufferRX);
	if (bufferRX == 'a')
	{
		PORTD ^= (1<<PORTD5);
		
	}
	
	if (bufferRX == 'b')
	{
		PORTD ^= (1<<PORTD6);
	}
}

ISR(PCINT2_vect)
{
	uint8_t estadoPD2 = PIND & (1<<PIND2);
	if (estadoPD2 != (1<<PIND2))
	{
		PORTD ^= (1<<PORTD5);
	}
}
