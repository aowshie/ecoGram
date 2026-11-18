import re
import shutil
from pathlib import Path

from .config import branding
from .paths import BRANDING
from .shell import run

ICON_SOURCES = BRANDING / "Icon"
COMPOSER_LAYERS = ("plane.svg", "braces.svg")
ALTERNATE_ICONS = {"EcoDark": "dark.svg", "EcoLight": "light.svg"}
ALTERNATE_SCALES = {2: 120, 3: 180}
UPSTREAM_NAME = "Swiftgram"
STRING_VALUE = re.compile(r"(<string>)([^<]*)(</string>)")
STRINGS_ENTRY = re.compile(r'^(\s*"[^"]+"\s*=\s*")(.*)(";\s*)$', re.MULTILINE)


def _replace_list(text: str, variable: str, values: list[str]) -> str:
    pattern = re.compile(rf"^{variable} = \[.*?\]", re.MULTILINE | re.DOTALL)
    if not pattern.search(text):
        raise RuntimeError(f"Telegram/BUILD no longer defines {variable}")
    rendered = ", ".join(f'"{value}"' for value in values)
    return pattern.sub(f"{variable} = [{rendered}]", text, count=1)


def _rename(text: str, pattern: re.Pattern, name: str) -> str:
    return pattern.sub(lambda m: m.group(1) + m.group(2).replace(UPSTREAM_NAME, name) + m.group(3), text)


def _brand_build_file(tree: Path, name: str) -> None:
    build = tree / "Telegram/BUILD"
    text = build.read_text(encoding="utf-8")
    text = _replace_list(text, "alternate_icon_folders", list(ALTERNATE_ICONS))
    text = _replace_list(text, "composer_icon_folders", ["EcoGram"])
    build.write_text(_rename(text, STRING_VALUE, name), encoding="utf-8")


def _brand_strings(tree: Path, name: str) -> None:
    for strings in (tree / "Telegram/Telegram-iOS").glob("*.lproj/*.strings"):
        text = strings.read_text(encoding="utf-8")
        if UPSTREAM_NAME in text:
            strings.write_text(_rename(text, STRINGS_ENTRY, name), encoding="utf-8")


def _install_composer_icon(tree: Path) -> None:
    target = tree / "Telegram/Telegram-iOS/EcoGram.icon"
    if target.exists():
        shutil.rmtree(target)
    (target / "Assets").mkdir(parents=True)
    shutil.copyfile(ICON_SOURCES / "composer.json", target / "icon.json")
    for layer in COMPOSER_LAYERS:
        shutil.copyfile(ICON_SOURCES / layer, target / "Assets" / layer)


def _install_alternate_icons(tree: Path) -> None:
    for name, source in ALTERNATE_ICONS.items():
        target = tree / f"Telegram/Telegram-iOS/{name}.alticon"
        if target.exists():
            shutil.rmtree(target)
        target.mkdir(parents=True)
        for scale, size in ALTERNATE_SCALES.items():
            run(["rsvg-convert", "--width", size, "--height", size, "--background-color", "black",
                 "--output", target / f"{name}@{scale}x.png", ICON_SOURCES / source])


def install(tree: Path) -> None:
    name = branding().display_name
    _brand_build_file(tree, name)
    _brand_strings(tree, name)
    _install_composer_icon(tree)
    _install_alternate_icons(tree)
