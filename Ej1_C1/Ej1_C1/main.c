/*
/*
 * NombreProgra.c
 *
 * Created: 
 * Author: 
 * Description: 
 */
/****************************************/
// Encabezado (Libraries)
#include 
/****************************************/
// Function prototypes
void setup();
/****************************************/
// Main Function
int main(void)
{
	setup();
}
/****************************************/
// NON-Interrupt subroutines
void setup()
{
	CLKPR = (1<<CLKPCE);
	CLKPR = (1<<CLKPS2);
	
	DDRC  = 0xFF;
	PORTC = 0X00;
}
/****************************************/
// Interrupt routines