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
	CLKPR = (1<<CLKPCE);
	CLKPR = (1<<CLKPS2);
	initPWM0();
	while(1)
	{
		
	}
void updateDutyCycle0A(uint8_t duty);
	
};
/****************************************/
// NON-Interrupt subroutines

void initPWM0()
{
	DDRD |= (1<<DDD6) | (1<<DDD5)
	
	TCCR0A = 0;
	TCCR0B = 0;
	
	TCCR0A |= (1<<COM0A1); //No invertido
	TCCR0A |= (1<<COM0B1) | (1<<COM0B0); //Invertido
	
	TCCR0A |= (1<<WGM01) |(1<<WGM00);
	
	// Prescaler de 8 
	TCCR0B |= (1<<CS01);
}
void updateDutyCycle0A(uint8_t duty)
{	
	uint8_t dutyCycle = 127
	CLKPR =
	};


/****************************************/
// Interrupt routines