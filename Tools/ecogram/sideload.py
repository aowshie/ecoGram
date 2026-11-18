import plistlib
import subprocess
import tempfile
from pathlib import Path

EXTENSIONS = (
    "ShareExtension",
    "NotificationContentExtension",
    "NotificationServiceExtension",
    "IntentsExtension",
    "WidgetExtension",
    "BroadcastUploadExtension",
)


def _run(args: list, capture: bool = False) -> bytes:
    return subprocess.run([str(arg) for arg in args], check=True, stdout=subprocess.PIPE if capture else None).stdout


def _entitlements(bundle_id: str, team_id: str, group: str) -> dict:
    return {
        "application-identifier": f"{team_id}.{bundle_id}",
        "com.apple.developer.team-identifier": team_id,
        "com.apple.security.application-groups": [group],
    }


def _sign(path: Path, work: Path, entitlements: dict | None = None) -> None:
    args = ["codesign", "--force", "--sign", "-", "--timestamp=none"]
    if entitlements is not None:
        file = work / f"{path.name}.entitlements"
        file.write_bytes(plistlib.dumps(entitlements))
        args += ["--entitlements", file, "--generate-entitlement-der"]
    _run([*args, path])


def _embedded_groups(path: Path) -> list:
    output = _run(["codesign", "-d", "--entitlements", "-", "--xml", path], capture=True)
    return plistlib.loads(output).get("com.apple.security.application-groups", []) if output else []


def _bundle_id(bundle: Path) -> str:
    return plistlib.loads((bundle / "Info.plist").read_bytes())["CFBundleIdentifier"]


def _nested_code(app: Path) -> list[Path]:
    code = [p for p in app.rglob("*") if p.suffix == ".framework" or (p.suffix == ".dylib" and p.is_file())]
    return sorted(code, key=lambda p: len(p.parts), reverse=True)


def embed_entitlements(ipa: Path, team_id: str) -> list[str]:
    with tempfile.TemporaryDirectory() as temporary:
        work = Path(temporary)
        root = work / "ipa"
        _run(["ditto", "-x", "-k", ipa, root])
        apps = list((root / "Payload").glob("*.app"))
        if len(apps) != 1:
            raise ValueError("IPA must contain exactly one application")
        app = apps[0]
        bundle_id = _bundle_id(app)
        group = f"group.{bundle_id}"
        plugins = sorted((app / "PlugIns").glob("*.appex"))
        missing = [name for name in EXTENSIONS if not any(p.stem.startswith(name) for p in plugins)]
        if missing:
            raise ValueError(f"IPA is missing extensions: {', '.join(missing)}")
        for code in _nested_code(app):
            _sign(code, work)
        bundles = [*plugins, app]
        for bundle in bundles:
            identifier = _bundle_id(bundle)
            if bundle is not app and not identifier.startswith(f"{bundle_id}."):
                raise ValueError(f"Extension {bundle.name} is outside the app bundle id")
            _sign(bundle, work, _entitlements(identifier, team_id, group))
        broken = [bundle.name for bundle in bundles if _embedded_groups(bundle) != [group]]
        if broken:
            raise ValueError(f"App group was not embedded into {', '.join(broken)}")
        rebuilt = work / "rebuilt.ipa"
        _run(["ditto", "-c", "-k", "--norsrc", root, rebuilt])
        ipa.write_bytes(rebuilt.read_bytes())
    return [plugin.name for plugin in plugins]
