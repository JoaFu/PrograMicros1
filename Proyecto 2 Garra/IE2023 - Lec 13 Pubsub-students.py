
import sys
import time
import serial

from Adafruit_IO import MQTTClient

# ======================================================
# SERIAL
# ======================================================

SERIAL_PORT = 'COM3'
SERIAL_BAUD = 9600

ser = serial.Serial(
    SERIAL_PORT,
    SERIAL_BAUD,
    timeout=1
)

time.sleep(2)

# ======================================================
# ADAFRUIT IO
# ======================================================

ADAFRUIT_IO_USERNAME = "JoaFu"
ADAFRUIT_IO_KEY      = "aio_lIIe91fcNFTDNNE5qrWggK7UYgez"

# ======================================================
# FEEDS CONTROL
# ======================================================

FEED_SERVO1 = 'servo1-angle'
FEED_SERVO2 = 'servo2-angle'
FEED_SERVO3 = 'servo3-angle'
FEED_SERVO4 = 'servo4-angle'

# ======================================================
# FEEDS FEEDBACK
# ======================================================

FEED_SERVO1_FB = 'servo1-position'
FEED_SERVO2_FB = 'servo2-position'
FEED_SERVO3_FB = 'servo3-position'
FEED_SERVO4_FB = 'servo4-position'

# ======================================================
# LIMITES MECANICOS
# ======================================================

SERVO_LIMITS = {

    '1': (0, 180),
    '2': (110, 180),
    '3': (95, 160),
    '4': (0, 10),
}

# ======================================================
# THROTTLE FEEDBACK POR SERVO
# ======================================================

FEEDBACK_INTERVAL = 1.5

last_fb_time = {
    '1': 0.0,
    '2': 0.0,
    '3': 0.0,
    '4': 0.0
}

# ======================================================
# THROTTLE UART
# ======================================================

COMMAND_INTERVAL = 0.5

last_cmd_time = {
    '1': 0.0,
    '2': 0.0,
    '3': 0.0,
    '4': 0.0
}

# ======================================================
# ULTIMO VALOR PUBLICADO
# ======================================================

last_published_angle = {
    '1': None,
    '2': None,
    '3': None,
    '4': None
}

# ======================================================
# MAPA FEEDBACK
# ======================================================

feedback_feed_map = {

    '1': FEED_SERVO1_FB,
    '2': FEED_SERVO2_FB,
    '3': FEED_SERVO3_FB,
    '4': FEED_SERVO4_FB,
}

# ======================================================
# ENVIAR COMANDO UART
# ======================================================

def enviar_angulo_servo(canal: str, angulo: int):

    now = time.time()

    if now - last_cmd_time[canal] < COMMAND_INTERVAL:
        return

    last_cmd_time[canal] = now

    min_angle, max_angle = SERVO_LIMITS[canal]

    angulo = max(
        min_angle,
        min(max_angle, angulo)
    )

    comando = f"S{canal}:{angulo}\r"

    ser.write(comando.encode())

    print(f'[PC → SERIAL] {comando.strip()}')

# ======================================================
# PUBLICAR FEEDBACK
# ======================================================

def publicar_feedback_servo(
    servo_id: str,
    angulo: int
):

    now = time.time()

    if now - last_fb_time[servo_id] < FEEDBACK_INTERVAL:
        return

    if last_published_angle[servo_id] == angulo:
        return

    last_fb_time[servo_id] = now

    last_published_angle[servo_id] = angulo

    feed = feedback_feed_map.get(servo_id)

    if not feed:
        return

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

# ======================================================
# PARSE FEEDBACK UART
# ======================================================

def procesar_feedback_serial(line: str):

    if 'FB' not in line:
        return

    try:

        fb_index = line.find('FB')

        fb_data = line[fb_index:]

        partes = fb_data.split(':')

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

# ======================================================
# MQTT CALLBACKS
# ======================================================

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

# ======================================================
# MQTT SETUP
# ======================================================

client = MQTTClient(
    ADAFRUIT_IO_USERNAME,
    ADAFRUIT_IO_KEY
)

client.on_connect    = connected
client.on_disconnect = disconnected
client.on_message    = message

client.connect()

client.loop_background()

# ======================================================
# MAIN LOOP
# ======================================================

print('Bridge UART <-> Adafruit IO activo')

while True:

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