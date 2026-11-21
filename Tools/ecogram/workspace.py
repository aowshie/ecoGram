import shutil
from pathlib import Path

from .lock import UpstreamLock
from .paths import PATCHES, SOURCES
from .shell import git

BASE_TAG = "ecogram-base"
IDENTITY = ("-c", "user.name=ecoGram", "-c", "user.email=build@ecogram.app")


def patch_files() -> list[Path]:
    return sorted(PATCHES.glob("*.patch"))


def _is_applying(tree: Path) -> bool:
    return (tree / ".git" / "rebase-apply").exists()


def _has_local_changes(tree: Path) -> bool:
    return bool(git("status", "--porcelain", "--untracked-files=no", cwd=tree, capture=True).strip())


def checkout(tree: Path, lock: UpstreamLock, submodules: bool, force: bool = False) -> None:
    if not lock.pinned:
        raise RuntimeError("upstream.json has no pinned commit, run: python -m Tools.ecogram bump")
    if (tree / ".git").exists() and not force:
        if _is_applying(tree):
            raise RuntimeError(f"a patch is being applied in {tree}, finish it with git am --continue and export, or pass --force to discard it")
        if _has_local_changes(tree):
            raise RuntimeError(f"{tree} has uncommitted changes, commit and export them, or pass --force to discard them")
    if _is_applying(tree):
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


def export_patches(tree: Path, lock: UpstreamLock) -> int:
    if _is_applying(tree):
        raise RuntimeError(f"a patch is still being applied in {tree}, finish it with git am --continue first")
    if _has_local_changes(tree):
        raise RuntimeError(f"{tree} has uncommitted changes, commit them first")
    base = git("rev-parse", f"{BASE_TAG}^{{commit}}", cwd=tree, capture=True).strip()
    if base != lock.commit:
        raise RuntimeError(f"{BASE_TAG} is {base}, but upstream.json pins {lock.commit}, run sync first")
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
    installed: dict[str, Path] = {}
    for resource in sorted(SOURCES.glob("**/Resources/*")):
        if not resource.is_file():
            raise RuntimeError(f"{resource} is not a file, resources must be flat files")
        if resource.name in installed:
            raise RuntimeError(f"{resource} and {installed[resource.name]} share the name {resource.name}")
        installed[resource.name] = resource
        shutil.copyfile(resource, resources / resource.name)
