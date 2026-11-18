import shutil
from pathlib import Path

from .lock import UpstreamLock
from .paths import PATCHES, SOURCES
from .shell import git

BASE_TAG = "ecogram-base"
IDENTITY = ("-c", "user.name=ecoGram", "-c", "user.email=build@ecogram.app")


def patch_files() -> list[Path]:
    return sorted(PATCHES.glob("*.patch"))


def checkout(tree: Path, lock: UpstreamLock, submodules: bool) -> None:
    if not lock.pinned:
        raise RuntimeError("upstream.json has no pinned commit, run: python -m Tools.ecogram bump")
    if (tree / ".git" / "rebase-apply").exists():
        git("am", "--abort", cwd=tree)
    if not (tree / ".git").exists():
        tree.mkdir(parents=True, exist_ok=True)
        git("init", "--quiet", cwd=tree)
        git("remote", "add", "origin", lock.repository, cwd=tree)
    git("fetch", "--quiet", "--depth", "1", "origin", lock.commit, cwd=tree)
    git("checkout", "--quiet", "--force", "--detach", lock.commit, cwd=tree)
    git("clean", "-ffdq", cwd=tree)
    git("tag", "--force", BASE_TAG, cwd=tree)
    if submodules:
        git("submodule", "update", "--init", "--recursive", "--depth", "1", "--jobs", "8", cwd=tree)


def apply_patches(tree: Path) -> int:
    patches = patch_files()
    if patches:
        git(*IDENTITY, "am", "--quiet", "--3way", "--keep-cr", *patches, cwd=tree)
    return len(patches)


def export_patches(tree: Path) -> int:
    for stale in patch_files():
        stale.unlink()
    PATCHES.mkdir(exist_ok=True)
    git(
        "format-patch", "--no-numbered", "--quiet", "--zero-commit", "--no-signature", "--no-stat", "--full-index",
        "--output-directory", PATCHES, f"{BASE_TAG}..HEAD", "--", ".", ":(exclude)EcoGram",
        cwd=tree,
    )
    return len(patch_files())


def install_sources(tree: Path) -> None:
    if not SOURCES.is_dir():
        return
    target = tree / SOURCES.name
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(SOURCES, target, ignore=shutil.ignore_patterns(".DS_Store"))
    resources = tree / "Telegram/Telegram-iOS/Resources/ecogram"
    if resources.exists():
        shutil.rmtree(resources)
    resources.mkdir(parents=True)
    for resource in SOURCES.glob("**/Resources/*"):
        if resource.is_file():
            shutil.copyfile(resource, resources / resource.name)
