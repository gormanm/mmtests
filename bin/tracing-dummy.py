#!/usr/bin/env python3
"""
Prints a PID, optionally saves it to a file, and wait forever. The intent
is to be used with tracing tools like perf, trace-cmd or bpftrace. Tracing
tools are not guaranteed to exit gracefully on interrupt and this provides
a suitable target.

Usage: tracing-dummy.py [pid_file]
"""
import os
import sys
import signal
import time
import atexit


def cleanup(active_file):
    print(f"cleanup {active_file}")
    if active_file:
        os.unlink(active_file)

def main():
    pid = os.getpid()
    print(f"{pid}")

    # Save PID to file if specified
    if len(sys.argv) > 1:
        pid_file = sys.argv[1]
        pid_path = os.makedirs(os.path.dirname(pid_file), exist_ok=True)

        try:
            with open(pid_file, 'w') as f:
                f.write(f"{pid}")
        except Exception as e:
            print(f"Error saving PID to file: {e}", file=sys.stderr)

    # Save PID to separate file to predictably detect when its running
    if len(sys.argv) > 2:
        active_file = f"/tmp/tracing-dummy-{sys.argv[2]}-active"
        with open(active_file, 'w') as f:
            f.write(f"{pid}")
        atexit.register(cleanup, active_file)

    # Wait until external termination
    while True:
        try:
            time.sleep(3600*24)
        except Exception as e:
            sys.exit(0)
        except KeyboardInterrupt as e:
            sys.exit(0)

if __name__ == "__main__":
    main()
