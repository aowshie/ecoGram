import subprocess
from pathlib import Path
from typing import Sequence


class CommandError(RuntimeError):
    pass


def run(args: Sequence[object], cwd: Path | None = None, capture: bool = False, env: dict | None = None) -> str:
    result = subprocess.run(
        [str(arg) for arg in args],
        cwd=cwd,
        env=env,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )
    if result.returncode != 0:
        details = f"\n{result.stdout}" if capture and result.stdout else ""
        raise CommandError(f"{' '.join(map(str, args[:3]))} failed with code {result.returncode}{details}")
    return result.stdout or ""


def git(*args: object, cwd: Path, capture: bool = False) -> str:
    return run(["git", *args], cwd=cwd, capture=capture)
