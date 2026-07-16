import sys
import os
import platform
import subprocess
import json
import logging
from typing import Any

logger = logging.getLogger(__name__)

def get_platform() -> str:
    sys_plat = sys.platform.lower()
    if 'android' in sys_plat:
        return 'android'
    elif 'win' in sys_plat:
        return 'windows'
    elif 'linux' in sys_plat:
        if os.environ.get('ANDROID_ROOT') or os.environ.get('ANDROID_DATA'):
            return 'android'
        try:
            uname_output = subprocess.check_output(['uname', '-a']).decode('utf-8').lower()
            if 'android' in uname_output:
                return 'android'
        except Exception:
            pass
        return 'linux'
    else:
        return 'linux'

def get_platform_tools_schemas() -> list[dict[str, Any]]:
    plat = get_platform()
    tools = []
    
    if plat == 'android':
        tools.append({
            "type": "function",
            "function": {
                "name": "exec_adb",
                "description": "Execute an adb command to control or query the connected Android device.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "command": {"type": "string", "description": "ADB command to run (e.g., 'devices', 'shell pm list packages', 'shell input keyevent 26')"}
                    },
                    "required": ["command"]
                }
            }
        })
        tools.append({
            "type": "function",
            "function": {
                "name": "adb_screenshot",
                "description": "Capture a screenshot of the connected Android device and pull it to the host.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "output_path": {"type": "string", "description": "Output filepath on the host (e.g., 'screenshot.png')"}
                    }
                }
            }
        })
        tools.append({
            "type": "function",
            "function": {
                "name": "adb_click",
                "description": "Simulate a click/tap at coordinates (x, y) on the connected Android device screen.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "x": {"type": "integer", "description": "X coordinate"},
                        "y": {"type": "integer", "description": "Y coordinate"}
                    },
                    "required": ["x", "y"]
                }
            }
        })
        
    elif plat == 'windows':
        tools.append({
            "type": "function",
            "function": {
                "name": "exec_powershell",
                "description": "Execute a PowerShell script or command on the host Windows machine.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "script": {"type": "string", "description": "PowerShell command or script to run"}
                    },
                    "required": ["script"]
                }
            }
        })
        tools.append({
            "type": "function",
            "function": {
                "name": "capture_screen",
                "description": "Capture a screenshot of the host Windows screen and save it to output_path.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "output_path": {"type": "string", "description": "Output path for the screenshot image"}
                    }
                }
            }
        })
        tools.append({
            "type": "function",
            "function": {
                "name": "simulate_mouse",
                "description": "Simulate mouse movement and clicks on the host Windows machine.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": ["move", "click", "double_click", "right_click"],
                            "description": "The mouse action to perform"
                        },
                        "x": {"type": "integer", "description": "X coordinate"},
                        "y": {"type": "integer", "description": "Y coordinate"}
                    },
                    "required": ["action", "x", "y"]
                }
            }
        })
        tools.append({
            "type": "function",
            "function": {
                "name": "simulate_keyboard",
                "description": "Simulate keyboard text input or key presses on the host Windows machine.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "text": {"type": "string", "description": "Text to send, supports SendKeys markup like '{ENTER}', '{TAB}', etc."}
                    },
                    "required": ["text"]
                }
            }
        })
        
    elif plat == 'linux':
        tools.append({
            "type": "function",
            "function": {
                "name": "exec_shell",
                "description": "Execute a shell command on the host Linux machine.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "command": {"type": "string", "description": "Shell command to run"}
                    },
                    "required": ["command"]
                }
            }
        })
        
    return tools

async def execute_platform_tool(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    plat = get_platform()
    logger.info(f"Executing platform tool '{name}' on '{plat}' with args: {arguments}")
    
    # ------------------ ANDROID ------------------
    if plat == 'android':
        if name == 'exec_adb':
            command = arguments.get('command', '')
            if command.startswith('adb '):
                command = command[4:]
            try:
                proc = subprocess.run(f"adb {command}", shell=True, capture_output=True, text=True, timeout=30)
                return {
                    "status": "success",
                    "stdout": proc.stdout,
                    "stderr": proc.stderr,
                    "exit_code": proc.returncode
                }
            except Exception as e:
                return {"status": "error", "message": str(e)}
                
        elif name == 'adb_screenshot':
            output_path = arguments.get('output_path', 'screenshot.png')
            try:
                subprocess.run("adb shell screencap -p /sdcard/screen_aios.png", shell=True, check=True, timeout=15)
                subprocess.run(f"adb pull /sdcard/screen_aios.png \"{output_path}\"", shell=True, check=True, timeout=15)
                subprocess.run("adb shell rm /sdcard/screen_aios.png", shell=True, check=True, timeout=15)
                return {"status": "success", "message": f"Screenshot pulled to {output_path}"}
            except Exception as e:
                return {"status": "error", "message": str(e)}
                
        elif name == 'adb_click':
            x = arguments.get('x', 0)
            y = arguments.get('y', 0)
            try:
                proc = subprocess.run(f"adb shell input tap {x} {y}", shell=True, capture_output=True, text=True, timeout=10)
                return {
                    "status": "success",
                    "stdout": proc.stdout,
                    "stderr": proc.stderr,
                    "exit_code": proc.returncode
                }
            except Exception as e:
                return {"status": "error", "message": str(e)}
                
    # ------------------ WINDOWS ------------------
    elif plat == 'windows':
        if name == 'exec_powershell':
            script = arguments.get('script', '')
            try:
                proc = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script], capture_output=True, text=True, timeout=60)
                return {
                    "status": "success",
                    "stdout": proc.stdout,
                    "stderr": proc.stderr,
                    "exit_code": proc.returncode
                }
            except Exception as e:
                return {"status": "error", "message": str(e)}
                
        elif name == 'capture_screen':
            output_path = arguments.get('output_path', 'screenshot.png')
            output_path = os.path.abspath(output_path)
            ps_script = f"""
            Add-Type -AssemblyName System.Windows.Forms;
            Add-Type -AssemblyName System.Drawing;
            $screen = [System.Windows.Forms.Screen]::PrimaryScreen;
            $bounds = $screen.Bounds;
            $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height);
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap);
            $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size);
            $bitmap.Save('{output_path}', [System.Drawing.Imaging.ImageFormat]::Png);
            $graphics.Dispose();
            $bitmap.Dispose();
            """
            try:
                proc = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_script], capture_output=True, text=True, timeout=20)
                if proc.returncode != 0:
                    return {"status": "error", "message": proc.stderr}
                return {"status": "success", "message": f"Screenshot saved to {output_path}"}
            except Exception as e:
                return {"status": "error", "message": str(e)}
                
        elif name == 'simulate_mouse':
            action = arguments.get('action', 'click')
            x = arguments.get('x', 0)
            y = arguments.get('y', 0)
            
            ps_script = f"""
            Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern void mouse_event(int dwFlags, int dx, int dy, int cButtons, int dwExtraInfo); [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);' -Name Win32Mouse -Namespace Win32API;
            [Win32API.Win32Mouse]::SetCursorPos({x}, {y});
            """
            if action == 'click':
                ps_script += "\n[Win32API.Win32Mouse]::mouse_event(0x02 -bor 0x04, 0, 0, 0, 0);"
            elif action == 'right_click':
                ps_script += "\n[Win32API.Win32Mouse]::mouse_event(0x08 -bor 0x10, 0, 0, 0, 0);"
            elif action == 'double_click':
                ps_script += """
                [Win32API.Win32Mouse]::mouse_event(0x02 -bor 0x04, 0, 0, 0, 0);
                Start-Sleep -m 100;
                [Win32API.Win32Mouse]::mouse_event(0x02 -bor 0x04, 0, 0, 0, 0);
                """
            try:
                proc = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_script], capture_output=True, text=True, timeout=10)
                if proc.returncode != 0:
                    return {"status": "error", "message": proc.stderr}
                return {"status": "success", "message": f"Simulated mouse {action} at ({x}, {y})"}
            except Exception as e:
                return {"status": "error", "message": str(e)}
                
        elif name == 'simulate_keyboard':
            text = arguments.get('text', '')
            escaped_text = text.replace("'", "''")
            ps_script = f"""
            Add-Type -AssemblyName System.Windows.Forms;
            [System.Windows.Forms.SendKeys]::SendWait('{escaped_text}');
            """
            try:
                proc = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_script], capture_output=True, text=True, timeout=10)
                if proc.returncode != 0:
                    return {"status": "error", "message": proc.stderr}
                return {"status": "success", "message": f"Simulated keyboard input: {text}"}
            except Exception as e:
                return {"status": "error", "message": str(e)}
                
    # ------------------ LINUX ------------------
    elif plat == 'linux':
        if name == 'exec_shell':
            command = arguments.get('command', '')
            try:
                proc = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=60)
                return {
                    "status": "success",
                    "stdout": proc.stdout,
                    "stderr": proc.stderr,
                    "exit_code": proc.returncode
                }
            except Exception as e:
                return {"status": "error", "message": str(e)}
                
    return {"status": "error", "message": f"Tool '{name}' is not supported on platform '{plat}'"}
