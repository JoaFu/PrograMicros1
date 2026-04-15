/*
 * PreLab4.c
 *
 * Created: 10-04-2026
 * Author: Joaquín Fuentes
 * Description:
 */
/****************************************/
// Encabezado (Libraries)
#define F_CPU 16000000
#include <avr/io.h>
#include <util/delay.h>
#include <stdint.h>
// Definiciones
#define BTN_UP   PC1
#define BTN_DOWN PC2
#define SEG_G    PC3
#define DIG1     PC4
#define DIG2     PC5
// Tabla 7 segmentos (gfedcba)
const uint8_t seg_table[10] = {
    0b00111111, // 0
    0b00000110, // 1
    0b01011011, // 2
    0b01001111, // 3
    0b01100110, // 4
    0b01101101, // 5
    0b01111101, // 6
    0b00000111, // 7
    0b01111111, // 8
    0b01101111  // 9
};
// Variables globales
uint8_t counter         = 0;
uint8_t btn_up_last     = 1;
uint8_t btn_down_last   = 1;
/****************************************/
// Function prototypes
uint8_t button_pressed(uint8_t pin, uint8_t *last_state);
void display_write(uint8_t value);
void display_fixed(void);
/****************************************/
// Main Function
int main(void)
{
    // LEDs - PORTD
    DDRD  = 0xFF;
    PORTD = 0x00;
    // Botones - entradas con pull-up
    DDRC  &= ~((1 << BTN_UP) | (1 << BTN_DOWN));
    PORTC |=  (1 << BTN_UP)  | (1 << BTN_DOWN);
    // Display - segmentos y dígitos como salidas
    DDRB  = 0xFF;
    DDRC |= (1 << SEG_G) | (1 << DIG1) | (1 << DIG2);
    while (1)
    {
        // --- CONTADOR ---
        if (button_pressed(BTN_UP,   &btn_up_last))   counter++;
        if (button_pressed(BTN_DOWN, &btn_down_last)) counter--;
        PORTD = counter;
        // --- DISPLAY ---
        display_fixed();
    }
}
/****************************************/
// NON-Interrupt subroutines

// Antirebote simple con puntero para guardar el estado anterior

uint8_t button_pressed(uint8_t pin, uint8_t *last_state)
{
    uint8_t current;

    // Lee el estado actual del botón
    if (PINC & (1 << pin))
        current = 1;
    else
        current = 0;

    // ¿Ha cambiado?
    if (current != *last_state)
    {
        _delay_ms(20);

        // Lee de nuevo para confirmar
        if (PINC & (1 << pin))
            current = 1;
        else
            current = 0;

        // ¿Sigue siendo diferente?
        if (current != *last_state)
        {
            *last_state = current;

            // 0 = presionado (pull-up)
            if (current == 0)
                return 1;
        }
    }
    return 0;
}
// Escribe los segmentos según el valor recibido
void display_write(uint8_t value)
{
    // Segmentos a-f van a PORTB (bits 0 a 5)
    PORTB = value & 0b00111111;
    // Segmento g va a PC3
    if (value & (1 << 6))
        PORTC |=  (1 << SEG_G);
    else
        PORTC &= ~(1 << SEG_G);
}
// Multiplexado: muestra el dígito 6 y el dígito 7 alternadamente
void display_fixed(void)
{
    // Apagar ambos dígitos antes de cambiar segmentos
    PORTC &= ~((1 << DIG1) | (1 << DIG2));
	
    // Mostrar dígito 1 con valor 6
    display_write(seg_table[6]);
    PORTC |= (1 << DIG1);
    _delay_ms(5);
	
    // Apagar antes de cambiar al siguiente dígito
    PORTC &= ~((1 << DIG1) | (1 << DIG2));
	
    // Mostrar dígito 2 con valor 7
    display_write(seg_table[7]);
    PORTC |= (1 << DIG2);
    _delay_ms(5);
}
/****************************************/
// Interrupt routines
// (No hay interrupciones en este programa)
