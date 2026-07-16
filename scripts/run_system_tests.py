import os
import subprocess
import sys
import time

# Colors for output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"

# Find root of the repository
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FLUTTER_APP_DIR = os.path.join(REPO_ROOT, "apps", "client_flutter")
RENDER_ADAPTER_DIR = os.path.join(REPO_ROOT, "services", "render_adapter")

def run_command(cmd, cwd, name):
    print(f"\n{BOLD}{CYAN}=== Running {name} ==={RESET}")
    print(f"Directory: {cwd}")
    print(f"Command: {' '.join(cmd)}")
    
    start_time = time.time()
    # Check if on Windows and we need shell=True
    is_win = os.name == 'nt'
    
    # Run subprocess
    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        shell=is_win,
        encoding="utf-8"
    )
    
    output = []
    # Stream stdout
    while True:
        line = proc.stdout.readline()
        if not line and proc.poll() is not None:
            break
        if line:
            sys.stdout.write(line)
            sys.stdout.flush()
            output.append(line)
            
    proc.wait()
    duration = time.time() - start_time
    
    full_output = "".join(output)
    success = proc.returncode == 0
    
    status_str = f"{GREEN}PASSED{RESET}" if success else f"{RED}FAILED{RESET}"
    print(f"\n{BOLD}{CYAN}=== {name} Finished: {status_str} (took {duration:.2f}s) ==={RESET}\n")
    
    return success, full_output, duration

def parse_pytest_summary(output):
    # Parse pytest output like: "19 passed, 7 warnings in 0.49s"
    # or "32 passed, 7 warnings in 26.05s"
    import re
    summary_match = re.search(r"===+ (.* passed.*) in (.*)s ===+", output)
    if summary_match:
        return summary_match.group(1).strip()
    
    # Fallback to look at the last few lines
    for line in reversed(output.splitlines()):
        if "passed" in line and ("seconds" in line or "s" in line) and "in" in line:
            return line.strip()
    return "Unknown pytest summary"

def parse_flutter_summary(output):
    # Parse flutter test output: "All tests passed!" or count lines
    if "All tests passed!" in output:
        return "All tests passed successfully."
    if "Some tests failed" in output:
        return "Some tests failed."
    return "Flutter test execution completed."

def main():
    print(f"{BOLD}{YELLOW}==================================================={RESET}")
    print(f"{BOLD}{YELLOW}          AIOS System Capability Test Runner         {RESET}")
    print(f"{BOLD}{YELLOW}==================================================={RESET}")
    
    overall_start = time.time()
    results = {}
    
    # 1. Run Flutter client unit/layout tests
    flutter_cmd = ["flutter", "test"]
    fl_success, fl_output, fl_duration = run_command(flutter_cmd, FLUTTER_APP_DIR, "Flutter Client Tests")
    results["Flutter Client Tests"] = {
        "success": fl_success,
        "duration": fl_duration,
        "summary": parse_flutter_summary(fl_output)
    }
    
    # 2. Run Python render adapter & integration tests
    pytest_cmd = ["uv", "run", "pytest", "-v"]
    py_success, py_output, py_duration = run_command(pytest_cmd, RENDER_ADAPTER_DIR, "Python Render Adapter & Daemon Integration Tests")
    results["Python Render Adapter & Daemon Integration Tests"] = {
        "success": py_success,
        "duration": py_duration,
        "summary": parse_pytest_summary(py_output)
    }
    
    # 3. Overall Summary
    total_duration = time.time() - overall_start
    print(f"{BOLD}{YELLOW}==================================================={RESET}")
    print(f"{BOLD}{YELLOW}                 TEST RUN SUMMARY                  {RESET}")
    print(f"{BOLD}{YELLOW}==================================================={RESET}")
    
    all_passed = True
    for name, res in results.items():
        status_color = GREEN if res["success"] else RED
        status_text = "PASS" if res["success"] else "FAIL"
        if not res["success"]:
            all_passed = False
        print(f"{BOLD}{name}:{RESET}")
        print(f"  Status:   {status_color}{status_text}{RESET}")
        print(f"  Duration: {res['duration']:.2f}s")
        print(f"  Details:  {res['summary']}")
        print()
        
    print(f"{BOLD}Total Time: {total_duration:.2f}s{RESET}")
    
    if all_passed:
        print(f"\n{BOLD}{GREEN}ALL CAPABILITY TESTS PASSED SUCCESSFULLY!{RESET}\n")
        sys.exit(0)
    else:
        print(f"\n{BOLD}{RED}SOME CAPABILITY TESTS FAILED. PLEASE CHECK LOGS.{RESET}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
