#!/usr/bin/env python3
"""Build the bundled chat emoji glyphs.

Primary art: Microsoft Fluent Emoji 3D (MIT), flattened Unicode WebP from
https://github.com/withxat/fluentui-emoji-unicode (webp branch).
Fallback: Twemoji 72x72 (CC-BY 4.0) for sequences Fluent does not ship
(flags, some modifiers, newer Unicode).

Output: assets/emoji/glyphs/{code}.webp at 96px, plus a Dart filename index.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GLYPH_DIR = ROOT / "assets" / "emoji" / "glyphs"
TWEMOJI_DIR = ROOT / "assets" / "emoji" / "twemoji"
GEN_DART = ROOT / "lib" / "src" / "emoji" / "emoji_assets.g.dart"
FLUENT_LEGAL = ROOT / "assets" / "legal" / "fluent-emoji-mit.txt"
TWEMOJI_LEGAL = ROOT / "assets" / "legal" / "twemoji-cc-by-4.0.txt"
CATALOG_DART = ROOT / "lib" / "src" / "emoji" / "emoji_catalog.dart"

FLUENT_REPO = "https://github.com/withxat/fluentui-emoji-unicode.git"
FLUENT_SRC = Path("/tmp") / "fluentui-emoji-unicode-webp"
TWEMOJI_VERSION = "v17.0.3"
TWEMOJI_REPO = "https://github.com/jdecked/twemoji.git"
TWEMOJI_SRC = Path("/tmp") / f"twemoji-{TWEMOJI_VERSION}"

TARGET_PX = 96
WEBP_QUALITY = 82
SKIN_TONES = {"1f3fb", "1f3fc", "1f3fd", "1f3fe", "1f3ff"}


def catalog_emojis() -> list[str]:
    text = CATALOG_DART.read_text(encoding="utf-8")
    return re.findall(r"^\s+'([^']+)',\s*$", text, flags=re.M)


def emoji_candidates(emoji: str) -> list[str]:
    runes = [ord(ch) for ch in emoji]
    has_zwj = 0x200D in runes
    full = "-".join(format(rune, "x") for rune in runes)
    stripped = "-".join(format(rune, "x") for rune in runes if rune != 0xFE0F)
    if has_zwj:
        return [full, stripped]
    return [stripped, full]


def unresolved_catalog(names: set[str]) -> list[str]:
    missing: list[str] = []
    for emoji in catalog_emojis():
        if not any(code in names for code in emoji_candidates(emoji)):
            missing.append(emoji)
    return missing


def clone_fluent() -> Path:
    assets = FLUENT_SRC / "assets"
    if assets.is_dir() and any(assets.glob("*_3d.webp")):
        return assets
    if FLUENT_SRC.exists():
        shutil.rmtree(FLUENT_SRC)
    subprocess.run(
        [
            "git",
            "clone",
            "--depth",
            "1",
            "--branch",
            "webp",
            "--filter=blob:none",
            "--sparse",
            FLUENT_REPO,
            str(FLUENT_SRC),
        ],
        check=True,
    )
    subprocess.run(
        ["git", "-C", str(FLUENT_SRC), "sparse-checkout", "init", "--no-cone"],
        check=True,
    )
    subprocess.run(
        [
            "git",
            "-C",
            str(FLUENT_SRC),
            "sparse-checkout",
            "set",
            "assets/*_3d.webp",
            "LICENSE",
        ],
        check=True,
    )
    return assets


def clone_twemoji_pngs() -> Path:
    png_dir = TWEMOJI_SRC / "assets" / "72x72"
    if png_dir.is_dir():
        return png_dir
    if TWEMOJI_SRC.exists():
        shutil.rmtree(TWEMOJI_SRC)
    subprocess.run(
        [
            "git",
            "clone",
            "--depth",
            "1",
            "--branch",
            TWEMOJI_VERSION,
            "--filter=blob:none",
            "--sparse",
            TWEMOJI_REPO,
            str(TWEMOJI_SRC),
        ],
        check=True,
    )
    subprocess.run(
        ["git", "-C", str(TWEMOJI_SRC), "sparse-checkout", "set", "assets/72x72"],
        check=True,
    )
    return png_dir


def has_skin_tone(stem: str) -> bool:
    return any(part in SKIN_TONES for part in stem.split("-"))


def write_resized_webp(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(src) as image:
        rgba = image.convert("RGBA")
        resized = rgba.resize((TARGET_PX, TARGET_PX), Image.Resampling.LANCZOS)
        resized.save(dest, "WEBP", quality=WEBP_QUALITY, method=4)


def convert_one(job: tuple[Path, Path]) -> str:
    src, dest = job
    write_resized_webp(src, dest)
    return dest.stem


def write_legal() -> None:
    FLUENT_LEGAL.parent.mkdir(parents=True, exist_ok=True)
    header = (
        "Fluent Emoji 3D graphics from Microsoft Fluent Emoji\n"
        "https://github.com/microsoft/fluentui-emoji\n"
        "Flattened Unicode filenames via "
        "https://github.com/withxat/fluentui-emoji-unicode\n"
        "Licensed under the MIT License.\n\n"
        "MIT License\n\n"
        "Copyright (c) Microsoft Corporation.\n\n"
        "Permission is hereby granted, free of charge, to any person obtaining a copy\n"
        'of this software and associated documentation files (the "Software"), to deal\n'
        "in the Software without restriction, including without limitation the rights\n"
        "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n"
        "copies of the Software, and to permit persons to whom the Software is\n"
        "furnished to do so, subject to the following conditions:\n\n"
        "The above copyright notice and this permission notice shall be included in all\n"
        "copies or substantial portions of the Software.\n\n"
        "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n"
        "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n"
        "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n"
        "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n"
        "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n"
        "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n"
        "SOFTWARE\n"
    )
    FLUENT_LEGAL.write_text(header, encoding="utf-8")

    twemoji_license = TWEMOJI_SRC / "LICENSE-GRAPHICS"
    twemoji_header = (
        "Twemoji graphics from https://github.com/jdecked/twemoji "
        f"{TWEMOJI_VERSION}\n"
        "Used only as fallback for sequences Fluent Emoji does not ship.\n"
        "Graphics licensed under CC-BY 4.0.\n\n"
    )
    if twemoji_license.exists():
        TWEMOJI_LEGAL.write_text(
            twemoji_header + twemoji_license.read_text(encoding="utf-8"),
            encoding="utf-8",
        )
    elif not TWEMOJI_LEGAL.exists():
        TWEMOJI_LEGAL.write_text(
            twemoji_header + "See https://creativecommons.org/licenses/by/4.0/\n",
            encoding="utf-8",
        )


def write_index(names: list[str]) -> None:
    body = ",\n".join(f"  '{name}'" for name in names)
    GEN_DART.parent.mkdir(parents=True, exist_ok=True)
    GEN_DART.write_text(
        "// GENERATED by tool/fetch_emoji_glyphs.py — do not edit.\n"
        "// Fluent Emoji 3D (MIT) plus Twemoji fallback, 96px WebP stems.\n"
        "const kEmojiAssetNames = <String>{\n"
        f"{body},\n"
        "};\n",
        encoding="utf-8",
    )


def main() -> int:
    fluent_assets = clone_fluent()
    if GLYPH_DIR.exists():
        shutil.rmtree(GLYPH_DIR)
    GLYPH_DIR.mkdir(parents=True)

    fluent_jobs: list[tuple[Path, Path]] = []
    for src in sorted(fluent_assets.glob("*_3d.webp")):
        stem = src.name.removesuffix("_3d.webp")
        if has_skin_tone(stem):
            continue
        fluent_jobs.append((src, GLYPH_DIR / f"{stem}.webp"))

    with ThreadPoolExecutor(max_workers=8) as pool:
        fluent_names = set(pool.map(convert_one, fluent_jobs))

    missing_fluent = unresolved_catalog(fluent_names)
    print(f"fluent 3d default glyphs: {len(fluent_names)}")
    if missing_fluent:
        print(f"catalog falling back to Twemoji: {missing_fluent}")

    fallback_jobs: list[tuple[Path, Path]] = []
    if TWEMOJI_DIR.is_dir():
        for src in sorted(TWEMOJI_DIR.glob("*.webp")):
            if src.stem in fluent_names:
                continue
            fallback_jobs.append((src, GLYPH_DIR / src.name))
    else:
        twemoji_pngs = clone_twemoji_pngs()
        for png in sorted(twemoji_pngs.glob("*.png")):
            if png.stem in fluent_names:
                continue
            fallback_jobs.append((png, GLYPH_DIR / f"{png.stem}.webp"))

    with ThreadPoolExecutor(max_workers=8) as pool:
        fallback_names = set(pool.map(convert_one, fallback_jobs))

    names = sorted(fluent_names | fallback_names)
    still_missing = unresolved_catalog(set(names))
    if still_missing:
        raise SystemExit(f"catalog glyphs still missing: {still_missing}")

    write_legal()
    write_index(names)

    if TWEMOJI_DIR.exists():
        shutil.rmtree(TWEMOJI_DIR)

    print(
        f"wrote {len(fluent_names)} fluent + {len(fallback_names)} twemoji "
        f"fallback -> {GLYPH_DIR}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
