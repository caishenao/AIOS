import os
import subprocess
import time
import socket
import json
import pytest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
DAEMON_DIR = os.path.join(REPO_ROOT, "apps", "headless_daemon")
TEST_DAEMON_PORT = 19001
TEST_DAEMON_NAME = "DiscoveryTestDaemon"

def test_udp_discovery_heartbeat() -> None:
    # 1. Setup UDP socket to listen on port 12100
    udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    # Enable address/port reuse
    if hasattr(socket, 'SO_REUSEADDR'):
        udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if hasattr(socket, 'SO_REUSEPORT'):
        try:
            udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except Exception:
            pass

    try:
        udp_sock.bind(('', 12100))
    except Exception as e:
        pytest.skip(f"Could not bind to UDP port 12100 (might be in use by another instance): {e}")

    udp_sock.settimeout(12.0)  # The daemon broadcasts every 5 seconds, so 12s is plenty

    # 2. Spin up the headless daemon
    import platform
    is_win = platform.system() == "Windows"
    proc = subprocess.Popen(
        ["dart", "run", "bin/main.dart", "--port", str(TEST_DAEMON_PORT), "--name", TEST_DAEMON_NAME],
        cwd=DAEMON_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        shell=is_win
    )

    try:
        # 3. Listen for the broadcast message
        start_time = time.time()
        discovered = False
        
        while time.time() - start_time < 12.0:
            try:
                data, addr = udp_sock.recvfrom(4096)
                payload = json.loads(data.decode('utf-8'))
                
                # Check if it's our test daemon
                if payload.get("name") == TEST_DAEMON_NAME and payload.get("port") == TEST_DAEMON_PORT:
                    discovered = True
                    # Verify fields
                    assert "id" in payload
                    assert "skills" in payload
                    assert "auth" in payload
                    break
            except socket.timeout:
                break
            except (json.JSONDecodeError, UnicodeDecodeError):
                # Ignore invalid packets from other sources on the network
                continue
                
        assert discovered, "Did not receive UDP discovery heartbeat from the daemon on port 12100"

    finally:
        # 4. Clean up
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        udp_sock.close()
