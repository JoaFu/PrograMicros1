/*
 * NombreProgra.c
 *
 * Created: 
 * Author: 
 * Description: 
 */
/****************************************/
// Encabezado (Libraries)
#include <avr/io.h>
#include <avr/interrupt.h>
/****************************************/
// Function prototypes
void initUART();
void writeChar(char caracter);
void writeString(char* string);

/****************************************/
// Main Function
int main(void)
{
	/* Replace with your application code */
	cli();
	initUART();
	sei();
	
	writeChar('H');
	writeChar('o');
	writeChar('l');
	writeChar('a');
	while (1)
	{
	}
}


/****************************************/
// NON-Interrupt subroutines
void initUART()
{
	// Configurar pines RX y TX
	DDRD &= ~(1<<DDD0);
	DDRD |=	 (1<<DDD1);
	
	UCSR0A = 0;
	// Habilitando interrupciones, habilitando RX y TXX del UART0
	UCSR0B = (1<<RXCIE0) | (1<<RXEN0) | (1<<TXEN0);
	// Async, Paridad deshabilitada, 1 stop bit, 8 data bits, 
	UCSR0C = (1<<UCSZ01) | (1<<UCSZ00);
	// Setear UBRR0 = 103
	UBRR0 = 103; //Boud Rate
	
	
	
	
}
void writeChar(char caracter)
{
	while (!(UCSR0B & (1<<UDRE0)));
	UDR0 = caracter;
}
void writeString(char* string)
{
	
}
/****************************************/
// Interrupt routines





