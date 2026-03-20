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

/****************************************/
// Function prototypes

/****************************************/
// Main Function
int main(void)
{
	cli();
	setup();
	initADC();
	initTMR1();
	//Habilitar
	ADCSRA |= (1<<ADIE) | (1<<ADSC);
	TIMSK1 |= (1<<TOIE1);
	sei();
	while (1)
	{
	}
}
/****************************************/
// NON-Interrupt subroutines
void setup()
{
	// Cambiar frecuencia del sistema 1MHz
	CLKPR = (1<<CLKPCE);
	CLKPR = (1<<CLKPS2);
	
	// Configurar salidas y entradas
	DDRD = 0xFF; //TODO PORTD SALIDA
	PORTD = 0x00; //Apagado
	USCR0B = 0x00; //Apagar pines debido a UART
	initADC()
}	
void initADC()
{
	ADMUX = 0;
	// Aref ) AVcc; just a la izq.
	ADMUX = |= (1<<REFS0) | (1<<ADLAR) | (1<<MUX2) | (1<<MUX1);
	ADCSRA = 0;}
	// Habilitar ADC y seleccionar prescaler = 8
	ADCSRA = (1<<ADEN)| (1<<ADPS1)	| (1<<ADPS0);
	
}
void initTMR1()
{
	TCCR1A =0;
	TCCR1B =0;
	TCCR1B |= (1<<CS1) | (1<<CS10);
	TCNT1 = T1Value;
	
}
/****************************************/
// Interrupt routines
ISR(ADC_vect)
{
	PORTD = ADCH;
	ADCSRA |= (1<<ADSC);
}

initTMR()
{
	
}


