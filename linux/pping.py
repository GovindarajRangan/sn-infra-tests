import argparse
import socket

def check_port(host, port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.settimeout(5)  # 5 second timeout
        try:
            sock.connect((host, port))
            return True
        except socket.timeout:
            return False
        except socket.error as err:
            print(f"Socket error: ", err)
            return False

parser = argparse.ArgumentParser(description="Test Connectivity")
parser.add_argument('host', type=str, help='Hostname or IP')
parser.add_argument('port', type=int, help='Port')
args = parser.parse_args()
host = args.host
port = args.port

if check_port(host, port):
    print(f"Port ping {host}:{port}: PASS")
else:
    print(f"Port ping {host}:{port}: FAIL")
