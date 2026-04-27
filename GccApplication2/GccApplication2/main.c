#define F_CPU 16000000
#include <avr/io.h>
#include <util/delay.h>

int main(void)
{
	DDRB  = (1<<PB5);
	PORTB = (1<<PB5);
	while (1);
}

