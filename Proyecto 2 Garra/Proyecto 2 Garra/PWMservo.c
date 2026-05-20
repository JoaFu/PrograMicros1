/*
 * PWMservo.c
 *
 * Servo PWM usando TIMER1
 * ATMega328P
 */

#define F_CPU 16000000UL

#include "PWMservo.h"

/****************************************/
/* TIMER1 INIT FLAG */

static uint8_t timer1_initialized = 0;

/****************************************/
/* INIT */

void pwm_servo_init(
    servo_t* servo,
    pwm_channel_t channel
)
{
    servo->channel = channel;

    servo->current_pulse_width_us = 1500U;

    servo->current_angle = 90U;

    /****************************************/
    /* TIMER1 */

    if (!timer1_initialized)
    {
        /*
         * Fast PWM Mode 14
         * TOP = ICR1
         */

        TCCR1A = 0x00;
        TCCR1B = 0x00;

        TCCR1A |= (1 << WGM11);

        TCCR1B |=
            (1 << WGM13) |
            (1 << WGM12);

        /*
         * Prescaler = 8
         */

        TCCR1B |= (1 << CS11);

        /*
         * 20ms period
         */

        ICR1 = PWM_TIMER_TOP_VALUE;

        timer1_initialized = 1;
    }

    /****************************************/
    /* CANAL A */

    if (channel == PWM_CHANNEL_A)
    {
        DDRB |= (1 << DDB1);

        TCCR1A |= (1 << COM1A1);

        OCR1A = PWM_US_TO_TICKS(1500);
    }

    /****************************************/
    /* CANAL B */

    else
    {
        DDRB |= (1 << DDB2);

        TCCR1A |= (1 << COM1B1);

        OCR1B = PWM_US_TO_TICKS(1500);
    }
}

/****************************************/
/* SET MICROSECONDS */

void pwm_servo_set_us(
    servo_t* servo,
    uint16_t pulse_width_us
)
{
    if (pulse_width_us < PWM_MIN_PULSE_WIDTH_US)
    {
        pulse_width_us = PWM_MIN_PULSE_WIDTH_US;
    }

    if (pulse_width_us > PWM_MAX_PULSE_WIDTH_US)
    {
        pulse_width_us = PWM_MAX_PULSE_WIDTH_US;
    }

    servo->current_pulse_width_us = pulse_width_us;

    /****************************************/
    /* UPDATE OCR */

    if (servo->channel == PWM_CHANNEL_A)
    {
        OCR1A = PWM_US_TO_TICKS(pulse_width_us);
    }
    else
    {
        OCR1B = PWM_US_TO_TICKS(pulse_width_us);
    }
}

/****************************************/
/* SET ANGLE */

void pwm_servo_set_angle(
    servo_t* servo,
    uint8_t angle
)
{
    if (angle > 180U)
    {
        angle = 180U;
    }

    servo->current_angle = angle;

    uint16_t pulse_width_us =
        PWM_MIN_PULSE_WIDTH_US +

        (
            ((uint32_t)angle *
            (PWM_MAX_PULSE_WIDTH_US - PWM_MIN_PULSE_WIDTH_US))
            / 180UL
        );

    pwm_servo_set_us(
        servo,
        pulse_width_us
    );
}

/****************************************/
/* GET MICROSECONDS */

uint16_t pwm_servo_get_us(
    const servo_t* servo
)
{
    return servo->current_pulse_width_us;
}

/****************************************/
/* GET ANGLE */

uint8_t pwm_servo_get_angle(
    const servo_t* servo
)
{
    return servo->current_angle;
}

/****************************************/
/* STOP */

void pwm_servo_stop(
    servo_t* servo
)
{
    if (servo->channel == PWM_CHANNEL_A)
    {
        TCCR1A &= ~(1 << COM1A1);

        OCR1A = 0;

        PORTB &= ~(1 << PORTB1);
    }
    else
    {
        TCCR1A &= ~(1 << COM1B1);

        OCR1B = 0;

        PORTB &= ~(1 << PORTB2);
    }
}