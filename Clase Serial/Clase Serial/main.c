#include "UART.h"
#include "avr/interrupt.h"
int main(void)
{
	cli();
	initUART();
	sei();
	
	writeChar('H');
	writeChar('o');
	writeChar('l');
	writeChar('a');
	writeString("\r\nMundo!\r\n");
	
	while (1)
	{
	}
}