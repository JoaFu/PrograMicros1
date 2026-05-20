/*
 * PWMservo.h
 *
 * Servo PWM por hardware usando TIMER1
 * Canales:
 *  - OC1A -> PB1
 *  - OC1B -> PB2
 */

#ifndef PWMSERVO_H_
#define PWMSERVO_H_

#ifndef F_CPU
#define F_CPU 16000000UL
#endif

#include <avr/io.h>
#include <stdint.h>

/****************************************/
/* CONFIGURACION */

#define PWM_SERVO_FREQUENCY_HZ         50UL

#define PWM_TIMER_PRESCALER            8UL

#define PWM_TIMER_CLOCK_HZ             (F_CPU / PWM_TIMER_PRESCALER)

#define PWM_TIMER_TOP_VALUE            ((PWM_TIMER_CLOCK_HZ / PWM_SERVO_FREQUENCY_HZ) - 1UL)

/*
 * 0.5us por tick
 */

#define PWM_MIN_PULSE_WIDTH_US         500U
#define PWM_MAX_PULSE_WIDTH_US         2400U

#define PWM_US_TO_TICKS(us)            ((uint16_t)((us) * 2U))

/****************************************/
/* ENUM CANAL */

typedef enum
{
    PWM_CHANNEL_A = 0,   /* OC1A -> PB1 */
    PWM_CHANNEL_B        /* OC1B -> PB2 */

} pwm_channel_t;

/****************************************/
/* ESTRUCTURA SERVO */

typedef struct
{
    pwm_channel_t channel;

    uint16_t current_pulse_width_us;

    uint8_t current_angle;

} servo_t;

/****************************************/
/* API */

void pwm_servo_init(
    servo_t* servo,
    pwm_channel_t channel
);

void pwm_servo_set_us(
    servo_t* servo,
    uint16_t pulse_width_us
);

void pwm_servo_set_angle(
    servo_t* servo,
    uint8_t angle
);

uint16_t pwm_servo_get_us(
    const servo_t* servo
);

uint8_t pwm_servo_get_angle(
    const servo_t* servo
);

void pwm_servo_stop(
    servo_t* servo
);

#endif