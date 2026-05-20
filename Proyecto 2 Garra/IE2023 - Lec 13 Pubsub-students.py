import sys
import time
import serial

from Adafruit_IO import MQTTClient

# =======================================================
# CONFIGURACION SERIAL
# =======================================================

SERIAL_PORT = 'COM3'
SERIAL_BAUD = 9600

ser = serial.Serial(
    SERIAL_PORT,
    SERIAL_BAUD,
    timeout=1
)

# Esperar reset del Nano
time.sleep(2)

# =======================================================
# ADAFRUIT IO
# =======================================================

ADAFRUIT_IO_USERNAME = "JoaFu"
ADAFRUIT_IO_KEY      = "aio_lIIe91fcNFTDNNE5qrWggK7UYgez"

# =======================================================
# FEEDS CONTROL
# Dashboard -> AVR
# =======================================================

FEED_SERVO1 = 'servo1-angle'
FEED_SERVO2 = 'servo2-angle'
FEED_SERVO3 = 'servo3-angle'
FEED_SERVO4 = 'servo4-angle'

# =======================================================
# FEEDS FEEDBACK
# AVR -> Dashboard
# =======================================================

FEED_SERVO1_FB = 'servo1-position'
FEED_SERVO2_FB = 'servo2-position'
FEED_SERVO3_FB = 'servo3-position'
FEED_SERVO4_FB = 'servo4-position'

# =======================================================
# LIMITES MECANICOS
# Deben coincidir con main.c
# =======================================================

SERVO_LIMITS = {

    # Servo 1 -> TIMER1
    '1': (0, 180),

    # Servo 2 -> Base
    '2': (110, 180),

    # Servo 3 -> Codo
    '3': (95, 160),

    # Servo 4 -> Garra
    '4': (0, 10),
}

# =======================================================
# THROTTLE FEEDBACK POR SERVO
# =======================================================
#
# Antes existia un throttle GLOBAL que hacia:
#
# FB1 -> publicado
# FB2 -> descartado
# FB3 -> descartado
#
# porque todos compartian el mismo timer.
#
# Ahora el throttle es INDEPENDIENTE por servo.
#
# Con 15 segundos:
#
# 4 * (60/15) = 16 mensajes/min
#
# Muy seguro para Adafruit IO Free.
#
# =======================================================

FEEDBACK_INTERVAL = 15.0

last_fb_time = {
    '1': 0.0,
    '2': 0.0,
    '3': 0.0,
    '4': 0.0
}

# =======================================================
# THROTTLE COMANDOS UART
# =======================================================

COMMAND_INTERVAL = 0.3

last_cmd_time = {
    '1': 0.0,
    '2': 0.0,
    '3': 0.0,
    '4': 0.0
}

# =======================================================
# ULTIMO VALOR PUBLICADO
# Evita spam de valores repetidos
# =======================================================

last_published_angle = {
    '1': None,
    '2': None,
    '3': None,
    '4': None
}

# =======================================================
# MAPA FEEDS FEEDBACK
# =======================================================

feedback_feed_map = {

    '1': FEED_SERVO1_FB,
    '2': FEED_SERVO2_FB,
    '3': FEED_SERVO3_FB,
    '4': FEED_SERVO4_FB,
}

# =======================================================
# ENVIAR COMANDO UART
# =======================================================

def enviar_angulo_servo(canal: str, angulo: int):

    now = time.time()

    # ---------------------------------------------------
    # THROTTLE UART
    # ---------------------------------------------------

    if now - last_cmd_time[canal] < COMMAND_INTERVAL:
        return

    last_cmd_time[canal] = now

    # ---------------------------------------------------
    # CLAMP MECANICO
    # ---------------------------------------------------

    min_angle, max_angle = SERVO_LIMITS[canal]

    angulo = max(
        min_angle,
        min(max_angle, angulo)
    )

    # ---------------------------------------------------
    # COMANDO SERIAL
    # ---------------------------------------------------

    comando = f"S{canal}:{angulo}\r"

    ser.write(comando.encode())

    print(f'[PC → SERIAL] {comando.strip()}')

# =======================================================
# PUBLICAR FEEDBACK
# =======================================================

def publicar_feedback_servo(
    servo_id: str,
    angulo: int
):

    now = time.time()

    # ---------------------------------------------------
    # THROTTLE POR SERVO
    # ---------------------------------------------------

    if now - last_fb_time[servo_id] < FEEDBACK_INTERVAL:
        return

    # ---------------------------------------------------
    # EVITAR REPETIDOS
    # ---------------------------------------------------

    if last_published_angle[servo_id] == angulo:
        return

    # ---------------------------------------------------
    # ACTUALIZAR ESTADOS
    # ---------------------------------------------------

    last_fb_time[servo_id] = now

    last_published_angle[servo_id] = angulo

    # ---------------------------------------------------
    # FEED DESTINO
    # ---------------------------------------------------

    feed = feedback_feed_map.get(servo_id)

    if not feed:
        return

    # ---------------------------------------------------
    # PUBLICAR MQTT
    # ---------------------------------------------------

    try:

        client.publish(feed, angulo)

        print(
            f'[PC → ADAFRUIT] '
            f'Servo {servo_id} -> {angulo}°'
        )

    except Exception as e:

        print(
            f'[ERROR MQTT] '
            f'No se pudo publicar feedback: {e}'
        )

# =======================================================
# PARSE FEEDBACK UART
# Formato esperado:
#
# FB1:90
# FB2:150
# FB3:100
# FB4:5
# =======================================================

def procesar_feedback_serial(line: str):

    if not line.startswith('FB'):
        return

    try:

        partes = line.split(':')

        servo_id = partes[0][2:]

        angulo = int(partes[1])

        publicar_feedback_servo(
            servo_id,
            angulo
        )

    except (IndexError, ValueError):

        print(
            f'[ERROR] Feedback invalido: {line}'
        )

# =======================================================
# MQTT CALLBACKS
# =======================================================

def connected(client):

    print('Conectado a Adafruit IO')

    client.subscribe(FEED_SERVO1)
    client.subscribe(FEED_SERVO2)
    client.subscribe(FEED_SERVO3)
    client.subscribe(FEED_SERVO4)

    print('Esperando datos del dashboard...')

def disconnected(client):

    print('Desconectado de Adafruit IO')

    sys.exit(1)

def message(client, feed_id, payload):

    try:

        angulo = int(float(payload))

    except ValueError:

        print(
            f'[ERROR] Payload invalido: {payload}'
        )

        return

    print(
        f'[ADAFRUIT → PC] '
        f'{feed_id} -> {angulo}°'
    )

    # ---------------------------------------------------
    # MAPEO FEED -> SERVO
    # ---------------------------------------------------

    feed_to_servo = {

        FEED_SERVO1: '1',
        FEED_SERVO2: '2',
        FEED_SERVO3: '3',
        FEED_SERVO4: '4',
    }

    servo_id = feed_to_servo.get(feed_id)

    if servo_id:

        enviar_angulo_servo(
            servo_id,
            angulo
        )

# =======================================================
# MQTT SETUP
# =======================================================

client = MQTTClient(
    ADAFRUIT_IO_USERNAME,
    ADAFRUIT_IO_KEY
)

client.on_connect    = connected
client.on_disconnect = disconnected
client.on_message    = message

client.connect()

# MQTT corre en background
client.loop_background()

# =======================================================
# MAIN LOOP
# =======================================================

print('Bridge UART <-> Adafruit IO activo')

while True:

    # ---------------------------------------------------
    # LEER SERIAL
    # ---------------------------------------------------

    while ser.in_waiting > 0:

        try:

            line = ser.readline() \
                .decode(
                    'utf-8',
                    errors='replace'
                ) \
                .strip()

        except serial.SerialException as e:

            print(f'[ERROR SERIAL] {e}')

            break

        if line:

            print(f'[SERIAL → PC] {line}')

            procesar_feedback_serial(line)

    time.sleep(0.05)
