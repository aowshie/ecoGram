import sys
from contextlib import chdir, contextmanager
from pathlib import Path
from typing import Iterator

UNSIGNED_RC = "\n".join((
    "build --action_env=PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
    "build --//Telegram:disableProvisioningProfiles=true",
    "build --features=disable_legacy_signing",
    "build --jobs=2",
    "build --worker_max_instances=SwiftCompile=1",
    "build --experimental_ui_max_stdouterr_bytes=-1",
    "build --keep_going",
    "build --@build_bazel_rules_swift//swift:copt=-no-warnings-as-errors",
))

PROFILE_GUARD = (
    "    if platform_prerequisites.platform.is_device:\n"
    "        processor_partials.append(\n"
    "            partials.provisioning_profile_partial("
)
UNSIGNED_GUARD = PROFILE_GUARD.replace(
    "platform.is_device:", 'platform.is_device and "disable_legacy_signing" not in features:'
)


@contextmanager
def unsigned_build(tree: Path) -> Iterator[None]:
    rc = tree / ".bazelrc"
    rules = tree / "build-system/bazel-rules/rules_apple/apple/internal/ios_rules.bzl"
    original_rc, original_rules = rc.read_bytes(), rules.read_bytes()
    rules_text = original_rules.decode("utf-8")
    if PROFILE_GUARD not in rules_text:
        raise RuntimeError("rules_apple provisioning guard changed upstream, update Tools/ecogram/bazel.py")
    try:
        rules.write_text(rules_text.replace(PROFILE_GUARD, UNSIGNED_GUARD), encoding="utf-8")
        rc.write_bytes(original_rc + b"\n" + UNSIGNED_RC.encode() + b"\n")
        yield
    finally:
        rules.write_bytes(original_rules)
        rc.write_bytes(original_rc)


def locate(tree: Path, versions: dict) -> Path:
    sys.path.insert(0, str(tree / "build-system/Make"))
    from BazelLocation import calculate_sha256, locate_bazel

    with chdir(tree):
        bazel = Path(locate_bazel(str(tree), None, None))
    expected_hash = versions["bazel"].split(":", 1)[1]
    if calculate_sha256(str(bazel)) != expected_hash:
        raise RuntimeError("Downloaded Bazel does not match versions.json")
    return bazel
