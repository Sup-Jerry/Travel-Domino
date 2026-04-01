import os
import shutil
import subprocess
import sys
from pathlib import Path


LOCAL_BAT = Path.home() / ".local" / "bat" / "current" / "bat.exe"


def _candidate_paths():
    env_value = os.environ.get("BAT_EXE")
    if env_value:
        yield Path(env_value)

    for name in ("bat", "batcat"):
        found = shutil.which(name)
        if found:
            yield Path(found)

    yield LOCAL_BAT


def find_bat():
    for candidate in _candidate_paths():
        if candidate.is_file():
            return candidate
    return None


def install_with_winget():
    command = [
        "winget",
        "install",
        "--id",
        "sharkdp.bat",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--silent",
    ]
    return subprocess.run(command, text=True)


def print_missing_tool_message():
    message = f"""bat executable not found.

Checked:
- BAT_EXE
- bat on PATH
- batcat on PATH
- {LOCAL_BAT}

Next steps:
1. Install bat manually, or run:
   python scripts/wrapper.py --install
2. If bat is already installed elsewhere, set BAT_EXE to the full path.
"""
    print(message, file=sys.stderr)


def parse_args(argv):
    if not argv:
        return "help", []

    if argv[0] == "--install":
        return "install", argv[1:]

    if argv[0] == "--":
        return "run", argv[1:]

    return "run", argv


def main():
    mode, forwarded_args = parse_args(sys.argv[1:])

    if mode == "help":
        print(
            "Usage:\n"
            "  python scripts/wrapper.py -- <bat args>\n"
            "  python scripts/wrapper.py --install\n"
            "\n"
            "Examples:\n"
            "  python scripts/wrapper.py -- README.md\n"
            "  python scripts/wrapper.py -- --style=numbers,changes src/app.py\n"
            "  python scripts/wrapper.py -- --paging=never --list-themes\n"
        )
        return 0

    if mode == "install":
        result = install_with_winget()
        if result.returncode != 0:
            print("winget install failed.", file=sys.stderr)
            if result.stdout:
                print(result.stdout, file=sys.stderr)
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            return result.returncode

    bat_exe = find_bat()
    if bat_exe is None:
        print_missing_tool_message()
        return 1

    command = [str(bat_exe), *forwarded_args]
    completed = subprocess.run(command)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
