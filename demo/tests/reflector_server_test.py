"""Local test fixture for modern tgcalls reflector framing; no Telegram keys/accounts."""
import socket
import struct
import subprocess
import sys
import threading
import time

udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udp.bind(("127.0.0.1", 0))
port = udp.getsockname()[1]
tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
tcp.bind(("127.0.0.1", port))
tcp.listen()
routes = {}
drop_udp = False
dropped = 0
lock = threading.Lock()

def route(packet, send, identity):
    if len(packet) < 20:
        return
    # Register the exact 16-byte tag on hello; relay data by destination tag.
    if (len(packet) == 40 and packet[16:32] == b"\xff" * 12 + b"\xfe\xff\xff\xff") or (len(packet) == 20 and packet[16:] == b"\0" * 4):
        with lock:
            routes[packet[:16]] = send
        send(packet)
    elif len(packet) >= 24:
        with lock:
            receiver = routes.get(packet[:16])
        if receiver:
            receiver(packet)

def datagrams():
    global dropped
    while True:
        packet, address = udp.recvfrom(65536)
        if drop_udp:
            dropped += 1
            continue
        route(packet, lambda data, addr=address: udp.sendto(data, addr), address)

def exact(connection, count):
    data = b""
    while len(data) < count:
        part = connection.recv(count - len(data))
        if not part:
            raise EOFError
        data += part
    return data

def stream(connection):
    output_lock = threading.Lock()
    def send(data):
        frame = struct.pack("<I", len(data)) + data
        with output_lock:
            # Deliberately split the length prefix across separate receives.
            connection.sendall(frame[:2])
            time.sleep(0.002)
            connection.sendall(frame[2:])
    try:
        assert exact(connection, 4) == b"\xee" * 4
        while True:
            count = struct.unpack("<I", exact(connection, 4))[0]
            assert 16 <= count <= 65536
            route(exact(connection, count), send, connection)
    except (EOFError, ConnectionError, OSError):
        pass
    finally:
        connection.close()

def streams():
    while True:
        connection, _ = tcp.accept()
        threading.Thread(target=stream, args=(connection,), daemon=True).start()

threading.Thread(target=datagrams, daemon=True).start()
threading.Thread(target=streams, daemon=True).start()
for wrapper in ("0", "1"):
    for mode in ("0", "1"):
        subprocess.run([sys.argv[1], str(port), mode, wrapper], check=True, timeout=35)

# The wrapper receives only a usable UDP address; all UDP is black-holed.
# A real delayed TCP attempt must carry ICE, DTLS and the payload round trip.
drop_udp = True
subprocess.run([sys.argv[1], str(port), "2", "1"], check=True, timeout=35)
assert dropped > 0, "UDP failure path was not exercised"
