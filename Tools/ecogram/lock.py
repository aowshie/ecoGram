import json
import re
from dataclasses import asdict, dataclass, replace

from .paths import UPSTREAM_LOCK
from .shell import run

COMMIT = re.compile(r"[0-9a-f]{40}")


@dataclass(frozen=True)
class UpstreamLock:
    repository: str
    branch: str
    commit: str

    @property
    def pinned(self) -> bool:
        return bool(COMMIT.fullmatch(self.commit))


def load() -> UpstreamLock:
    return UpstreamLock(**json.loads(UPSTREAM_LOCK.read_text(encoding="utf-8")))


def save(lock: UpstreamLock) -> None:
    UPSTREAM_LOCK.write_text(json.dumps(asdict(lock), indent=2) + "\n", encoding="utf-8")


def remote_head(lock: UpstreamLock) -> str:
    output = run(["git", "ls-remote", lock.repository, f"refs/heads/{lock.branch}"], capture=True).split()
    if not output or not COMMIT.fullmatch(output[0]):
        raise RuntimeError(f"Cannot resolve {lock.branch} of {lock.repository}")
    return output[0]


def bump() -> tuple[UpstreamLock, UpstreamLock]:
    current = load()
    updated = replace(current, commit=remote_head(current))
    if updated != current:
        save(updated)
    return current, updated
