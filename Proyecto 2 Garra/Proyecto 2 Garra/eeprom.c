/*
 * eeprom.c
 *
 * Libreria EEPROM para ATmega328P
 * Escritura y lectura byte a byte con espera de ciclo anterior.
 */

#include "eeprom.h"

void eepromWrite(uint16_t address, uint8_t data)
{
    /* Esperar escritura anterior */
    while (EECR & (1 << EEPE));

    EEAR = address;
    EEDR = data;

    /* Secuencia de escritura obligatoria del datasheet */
    EECR |= (1 << EEMPE);
    EECR |= (1 << EEPE);
}

uint8_t eepromRead(uint16_t address)
{
    while (EECR & (1 << EEPE));

    EEAR = address;
    EECR |= (1 << EERE);

    return EEDR;
}