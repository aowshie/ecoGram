import hashlib
import json
import os
import plistlib
import shutil
import sys
import zipfile
from pathlib import Path

from . import bazel, config, sideload
from .shell import run


def _versions(tree: Path) -> dict:
    return json.loads((tree / "versions.json").read_text(encoding="utf-8"))


def _check_xcode(versions: dict) -> str:
    xcode = run(["xcodebuild", "-version"], capture=True).strip()
    if xcode.splitlines()[0] != f"Xcode {versions['xcode']}":
        raise RuntimeError(f"Xcode {versions['xcode']} is required, found {xcode.splitlines()[0]}")
    return xcode


def _build_number() -> int:
    return 100_000 + int(os.environ.get("GITHUB_RUN_NUMBER", "0")) * 10 + int(os.environ.get("GITHUB_RUN_ATTEMPT", "1"))


def _app_info(ipa: Path, bundle_id: str) -> dict:
    with zipfile.ZipFile(ipa) as archive:
        if archive.testzip():
            raise RuntimeError("IPA archive is corrupt")
        plists = [n for n in archive.namelist() if n.count("/") == 2 and n.endswith(".app/Info.plist")]
        if len(plists) != 1:
            raise RuntimeError("IPA must contain exactly one application")
        info = plistlib.loads(archive.read(plists[0]))
    if info.get("CFBundleIdentifier") != bundle_id:
        raise RuntimeError(f"IPA bundle id is {info.get('CFBundleIdentifier')}, expected {bundle_id}")
    return {key: info.get(key) for key in ("CFBundleIdentifier", "CFBundleDisplayName", "CFBundleShortVersionString", "CFBundleVersion")}


def run_build(tree: Path, output: Path, configuration: str) -> Path:
    if sys.platform != "darwin":
        raise RuntimeError("iOS builds require macOS with Xcode")
    tree, output = tree.resolve(), output.resolve()
    versions = _versions(tree)
    xcode = _check_xcode(versions)
    brand = config.branding()
    number = _build_number()
    output.mkdir(parents=True, exist_ok=True)
    configuration_file = tree / "build-input/ecogram-configuration.json"
    configuration_file.parent.mkdir(exist_ok=True)
    configuration_file.write_text(json.dumps(config.make_configuration()), encoding="utf-8")
    configuration_file.chmod(0o600)
    try:
        with bazel.unsigned_build(tree):
            make = [sys.executable, "-u", "build-system/Make/Make.py", f"--bazel={bazel.locate(tree, versions)}"]
            if cache := os.environ.get("ECOGRAM_BAZEL_CACHE"):
                make.append(f"--cacheDir={cache}")
            common = [f"--configurationPath={configuration_file}", "--xcodeManagedCodesigning", f"--buildNumber={number}"]
            run([*make, "generateProject", *common, "--disableProvisioningProfiles"], cwd=tree)
            run([*make, "build", *common, f"--configuration={configuration}"], cwd=tree)
    finally:
        configuration_file.unlink(missing_ok=True)
        (tree / "build-input/configuration-repository/variables.bzl").unlink(missing_ok=True)
    built = tree / "bazel-bin/Telegram/Swiftgram.ipa"
    if not built.is_file():
        raise RuntimeError("Build finished without bazel-bin/Telegram/Swiftgram.ipa")
    target = output / f"{brand.artifact_prefix}-{versions['app']}-{number}.ipa"
    shutil.copyfile(built, target)
    target.chmod(0o644)
    extensions = sideload.embed_entitlements(target, brand.team_id)
    manifest = {
        "app": _app_info(target, brand.bundle_id),
        "build_number": number,
        "configuration": configuration,
        "extensions": extensions,
        "ipa": target.name,
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "upstream": run(["git", "rev-parse", "ecogram-base"], cwd=tree, capture=True).strip(),
        "versions": versions,
        "xcode": xcode.splitlines()[0],
    }
    (output / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"built {target.name}")
    return target
