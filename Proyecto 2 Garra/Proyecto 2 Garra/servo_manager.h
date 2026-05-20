/*
 * servo_manager.h
 *
 * Control multiplexado de 4 servos usando:
 *  - TIMER1
 *  - Compare Match ISR
 *  - Pulsos secuenciales
 *
 * ATMega328P
 */

#ifndef SERVO_MANAGER_H_
#define SERVO_MANAGER_H_

#ifndef F_CPU
#define F_CPU 16000000UL
#endif

#include <avr/io.h>
#include <stdint.h>

/****************************************/
/* CONFIGURACION */

#define SERVO_COUNT                4

#define SERVO_MIN_PULSE_US         500U
#define SERVO_MAX_PULSE_US         2400U

#define SERVO_FRAME_TIME_US        20000UL

/*
 * Timer1:
 * Prescaler = 8
 * Ftimer = 2MHz
 * Tick = 0.5us
 */

#define TIMER1_PRESCALER           8UL

#define TIMER1_TICK_US             0.5f

#define US_TO_TICKS(us)            ((uint16_t)((us) * 2U))

/****************************************/
/* ESTRUCTURA */

typedef struct
{
    volatile uint16_t pulse_us;
    volatile uint8_t angle;

} servo_t;

/****************************************/
/* API */

void servo_manager_init(void);

void servo_set_angle(uint8_t servo_id, uint8_t angle);

void servo_set_pulse_us(uint8_t servo_id, uint16_t pulse_us);

uint8_t servo_get_angle(uint8_t servo_id);

#endif