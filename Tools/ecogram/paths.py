from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / ".work"
UPSTREAM_CHECKOUT = WORK / "swiftgram"
UPSTREAM_LOCK = ROOT / "upstream.json"
PATCHES = ROOT / "Patches"
SOURCES = ROOT / "EcoGram"
BRANDING = ROOT / "Branding"
BRANDING_CONFIG = BRANDING / "branding.json"
