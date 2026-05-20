/*
 * servo_manager.c
 *
 * Multiplexado de 4 servos usando Timer1
 */

#define F_CPU 16000000UL

#include "servo_manager.h"

#include <avr/io.h>
#include <avr/interrupt.h>

/****************************************/
/* ARRAY DE SERVOS */

static servo_t servos[SERVO_COUNT];

/****************************************/
/* VARIABLES INTERNAS */

static volatile uint8_t current_servo = 0;

static volatile uint8_t pulse_phase = 0;

/*
 * pulse_phase:
 *
 * 0 -> iniciar pulso
 * 1 -> terminar pulso
 */

/****************************************/
/* PINOUT */

static volatile uint8_t* servo_ports[SERVO_COUNT] =
{
    &PORTB,
    &PORTB,
    &PORTD,
    &PORTD
};

static const uint8_t servo_pins[SERVO_COUNT] =
{
    PB1,   // Servo 0
    PB2,   // Servo 1
    PD6,   // Servo 2
    PD7    // Servo 3
};

/****************************************/
/* INIT */

void servo_manager_init(void)
{
    /* Pines salida */

    DDRB |= (1 << DDB1) | (1 << DDB2);

    DDRD |= (1 << DDD6) | (1 << DDD7);

    /* Valores iniciales */

    for (uint8_t i = 0; i < SERVO_COUNT; i++)
    {
        servos[i].pulse_us = 1500;
        servos[i].angle    = 90;
    }

    /****************************************/
    /* TIMER1 */

    TCCR1A = 0x00;

    TCCR1B = 0x00;

    /*
     * CTC MODE
     */

    TCCR1B |= (1 << WGM12);

    /*
     * Prescaler = 8
     */

    TCCR1B |= (1 << CS11);

    /*
     * Primera interrupcion
     */

    OCR1A = 1000;

    /*
     * Habilitar Compare Match A
     */

    TIMSK1 |= (1 << OCIE1A);
}

/****************************************/
/* SET ANGLE */

void servo_set_angle(uint8_t servo_id, uint8_t angle)
{
    if (servo_id >= SERVO_COUNT)
        return;

    if (angle > 180)
        angle = 180;

    uint16_t pulse_us =
        SERVO_MIN_PULSE_US +

        (
            ((uint32_t)angle *
            (SERVO_MAX_PULSE_US - SERVO_MIN_PULSE_US))
            / 180UL
        );

    servo_set_pulse_us(servo_id, pulse_us);

    servos[servo_id].angle = angle;
}

/****************************************/
/* SET PULSE */

void servo_set_pulse_us(uint8_t servo_id, uint16_t pulse_us)
{
    if (servo_id >= SERVO_COUNT)
        return;

    if (pulse_us < SERVO_MIN_PULSE_US)
        pulse_us = SERVO_MIN_PULSE_US;

    if (pulse_us > SERVO_MAX_PULSE_US)
        pulse_us = SERVO_MAX_PULSE_US;

    servos[servo_id].pulse_us = pulse_us;
}

/****************************************/
/* GET ANGLE */

uint8_t servo_get_angle(uint8_t servo_id)
{
    if (servo_id >= SERVO_COUNT)
        return 0;

    return servos[servo_id].angle;
}

/****************************************/
/* ISR TIMER1 COMPARE MATCH */

ISR(TIMER1_COMPA_vect)
{
    /*
     * FASE 0:
     * Iniciar pulso
     */

    if (pulse_phase == 0)
    {
        *servo_ports[current_servo] |=
            (1 << servo_pins[current_servo]);

        OCR1A = TCNT1 +

        US_TO_TICKS(
            servos[current_servo].pulse_us
        );

        pulse_phase = 1;
    }

    /*
     * FASE 1:
     * Finalizar pulso
     */

    else
    {
        *servo_ports[current_servo] &=
            ~(1 << servo_pins[current_servo]);

        current_servo++;

        /*
         * Siguiente servo
         */

        if (current_servo >= SERVO_COUNT)
        {
            current_servo = 0;

            /*
             * Tiempo restante del frame
             */

            OCR1A = TCNT1 + US_TO_TICKS(12000);
        }
        else
        {
            OCR1A = TCNT1 + US_TO_TICKS(3000);
        }

        pulse_phase = 0;
    }
}