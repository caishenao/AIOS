import os
import subprocess
import time
import socket
import pytest
import httpx

# Find the absolute path to the headless_daemon directory
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
DAEMON_DIR = os.path.join(REPO_ROOT, "apps", "headless_daemon")
TEST_PORT = 19000
BASE_URL = f"http://127.0.0.1:{TEST_PORT}"

def is_port_in_use(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('127.0.0.1', port)) == 0

@pytest.fixture(scope="module")
def daemon_process():
    # Ensure port is not in use before starting
    if is_port_in_use(TEST_PORT):
        pytest.skip(f"Port {TEST_PORT} is already in use, cannot run headless daemon integration tests.")

    # Start the daemon process
    # Use dart from PATH or fallback to full path if needed
    import platform
    is_win = platform.system() == "Windows"
    proc = subprocess.Popen(
        ["dart", "run", "bin/main.dart", "--port", str(TEST_PORT), "--name", "TestIntegrationDaemon", "--skills", "command_exec,file_upload,iot_data,iot_control,script_exec,screen_parse"],
        cwd=DAEMON_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        shell=is_win
    )
    
    # Wait for the daemon to start by polling the health endpoint
    start_time = time.time()
    success = False
    while time.time() - start_time < 15:
        try:
            with httpx.Client() as client:
                resp = client.get(f"{BASE_URL}/agent-card", timeout=1.0)
                if resp.status_code == 200:
                    success = True
                    break
        except (httpx.RequestError, httpx.HTTPStatusError):
            time.sleep(0.5)

    if not success:
        proc.terminate()
        proc.wait()
        pytest.fail(f"Headless daemon failed to start on port {TEST_PORT} within 15 seconds.")

    yield proc

    # Cleanup: terminate the daemon process
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()

    # Delete temporary file if created during tests
    temp_file = os.path.join(DAEMON_DIR, "test_temp.txt")
    if os.path.exists(temp_file):
        try:
            os.remove(temp_file)
        except Exception:
            pass

def test_daemon_agent_card(daemon_process) -> None:
    with httpx.Client() as client:
        resp = client.get(f"{BASE_URL}/agent-card")
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] is not None
        assert data["name"] == "TestIntegrationDaemon"
        assert "skills" in data
        assert "devices" in data
        assert len(data["devices"]) > 0

def test_daemon_iot_data(daemon_process) -> None:
    with httpx.Client() as client:
        resp = client.get(f"{BASE_URL}/iot-data")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
        assert "devices" in data
        devices = data["devices"]
        assert any(d["id"] == "living_room_light" for d in devices)

def test_daemon_control_device(daemon_process) -> None:
    with httpx.Client() as client:
        # Turn living room light ON
        resp = client.post(
            f"{BASE_URL}/control-device",
            json={"deviceId": "living_room_light", "action": "on"}
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
        assert data["device"]["state"] == "on"

        # Verify state in iot-data
        resp = client.get(f"{BASE_URL}/iot-data")
        devices = resp.json()["devices"]
        light = next(d for d in devices if d["id"] == "living_room_light")
        assert light["state"] == "on"

        # Turn living room light OFF
        resp = client.post(
            f"{BASE_URL}/control-device",
            json={"deviceId": "living_room_light", "action": "off"}
        )
        assert resp.status_code == 200
        assert resp.json()["device"]["state"] == "off"

def test_daemon_execute_command(daemon_process) -> None:
    with httpx.Client() as client:
        cmd = "echo hello_integration_test"
        resp = client.post(
            f"{BASE_URL}/execute-command",
            json={"command": cmd}
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
        assert "hello_integration_test" in data["stdout"]

def test_daemon_execute_script(daemon_process) -> None:
    with httpx.Client() as client:
        # Check platform script execution
        import platform
        if platform.system() == "Windows":
            script = "Write-Output 'script_output_win'"
            ext = ".ps1"
        else:
            script = "echo 'script_output_unix'"
            ext = ".sh"

        resp = client.post(
            f"{BASE_URL}/execute-script",
            json={"script": script, "extension": ext}
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
        assert "script_output" in data["stdout"]

def test_daemon_file_upload_download(daemon_process) -> None:
    with httpx.Client() as client:
        # Upload a test file
        upload_resp = client.post(
            f"{BASE_URL}/upload-file",
            json={"path": "test_temp.txt", "content": "file_content_test_123", "is_base64": False}
        )
        assert upload_resp.status_code == 200
        assert upload_resp.json()["status"] == "success"

        # Download the file and check content
        download_resp = client.post(
            f"{BASE_URL}/download-file",
            json={"path": "test_temp.txt"}
        )
        assert download_resp.status_code == 200
        data = download_resp.json()
        assert data["status"] == "success"
        assert data["content"] == "file_content_test_123"
        assert not data["is_binary"]

def test_daemon_screen_structure(daemon_process) -> None:
    with httpx.Client() as client:
        resp = client.get(f"{BASE_URL}/screen-structure?maxDepth=2")
        # Could fail on Linux if pyatspi/xdotool is missing or on Windows under some CI settings,
        # but we check if it responds with a valid json schema structure (either success or error)
        assert resp.status_code in [200, 403, 500]
        data = resp.json()
        if resp.status_code == 200:
            assert "status" in data
            assert data["status"] in ["success", "error"]
            if data["status"] == "success":
                assert "root" in data
                assert "meta" in data
