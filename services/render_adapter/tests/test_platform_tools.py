import pytest
import sys
import unittest.mock as mock
from typing import Any

from render_adapter.platform_tools import (
    get_platform,
    get_platform_tools_schemas,
    execute_platform_tool
)

def test_get_platform_windows() -> None:
    with mock.patch("sys.platform", "win32"):
        assert get_platform() == "windows"

def test_get_platform_linux() -> None:
    with mock.patch("sys.platform", "linux"):
        with mock.patch("os.environ", {}):
            with mock.patch("subprocess.check_output") as mock_check:
                mock_check.return_value = b"Linux ubuntu 5.4.0"
                assert get_platform() == "linux"

def test_get_platform_android_env() -> None:
    with mock.patch("sys.platform", "linux"):
        with mock.patch("os.environ", {"ANDROID_ROOT": "/system"}):
            assert get_platform() == "android"

def test_get_platform_android_uname() -> None:
    with mock.patch("sys.platform", "linux"):
        with mock.patch("os.environ", {}):
            with mock.patch("subprocess.check_output") as mock_check:
                mock_check.return_value = b"Linux android 4.19.112"
                assert get_platform() == "android"

def test_get_platform_tools_schemas_windows() -> None:
    with mock.patch("render_adapter.platform_tools.get_platform", return_value="windows"):
        schemas = get_platform_tools_schemas()
        names = [s["function"]["name"] for s in schemas]
        assert "exec_powershell" in names
        assert "capture_screen" in names
        assert "simulate_mouse" in names
        assert "simulate_keyboard" in names

def test_get_platform_tools_schemas_android() -> None:
    with mock.patch("render_adapter.platform_tools.get_platform", return_value="android"):
        schemas = get_platform_tools_schemas()
        names = [s["function"]["name"] for s in schemas]
        assert "exec_adb" in names
        assert "adb_screenshot" in names
        assert "adb_click" in names

def test_get_platform_tools_schemas_linux() -> None:
    with mock.patch("render_adapter.platform_tools.get_platform", return_value="linux"):
        schemas = get_platform_tools_schemas()
        names = [s["function"]["name"] for s in schemas]
        assert "exec_shell" in names

@pytest.mark.asyncio
async def test_execute_platform_tool_windows_powershell() -> None:
    with mock.patch("render_adapter.platform_tools.get_platform", return_value="windows"):
        with mock.patch("subprocess.run") as mock_run:
            mock_run.return_value = mock.Mock(returncode=0, stdout="Success output", stderr="")
            res = await execute_platform_tool("exec_powershell", {"script": "Get-Process"})
            assert res["status"] == "success"
            assert res["stdout"] == "Success output"
            mock_run.assert_called_once()

@pytest.mark.asyncio
async def test_execute_platform_tool_linux_shell() -> None:
    with mock.patch("render_adapter.platform_tools.get_platform", return_value="linux"):
        with mock.patch("subprocess.run") as mock_run:
            mock_run.return_value = mock.Mock(returncode=0, stdout="Linux output", stderr="")
            res = await execute_platform_tool("exec_shell", {"command": "ls"})
            assert res["status"] == "success"
            assert res["stdout"] == "Linux output"
            mock_run.assert_called_once()
