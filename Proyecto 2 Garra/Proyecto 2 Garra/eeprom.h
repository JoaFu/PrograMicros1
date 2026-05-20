/*
 * eeprom.h
 *
 * Libreria EEPROM para ATmega328P
 * Interfaz minima: read / write byte
 */

#ifndef EEPROM_H_
#define EEPROM_H_

#include <avr/io.h>
#include <stdint.h>

void    eepromWrite(uint16_t address, uint8_t data);
uint8_t eepromRead(uint16_t address);

#endif /* EEPROM_H_ */