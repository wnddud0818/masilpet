#!/usr/bin/env python3
"""Quantize bundled MasilPet sprite PNGs to 8-bit palette PNGs.

The sliced sprites ship as 32-bit RGBA PNGs, which puts ~250 MB of assets into
the Android base module — past Play's 200 MB download-size limit. The art is
hard-edged with only two alpha values (0 and 255), so an 8-bit palette holds it
with no alpha loss and a barely measurable RGB shift, cutting the bundle to
roughly a sixth of its size.

Only the directories `pubspec.yaml` bundles are rewritten. The generator sheets
under `assets/pets/{petKey}/source/` stay untouched, so `slice_sprite_sheet.py`
can always regenerate the originals.

Usage:
    python tools/optimize_pet_assets.py --dry-run
    python tools/optimize_pet_assets.py
"""

from __future__ import annotations

import argparse
import io
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


DEFAULT_PALETTE_COLORS = 256

# Mirrors the `assets/pets/{petKey}/...` entries in pubspec.yaml. `source/` is
# deliberately absent: those sheets are inputs, not shipped assets.
BUNDLED_SUBDIRS = ("actions", "animations", "emotions", "growth")


# An octree palette can land a hard edge one step off (255 -> 254). That is a
# rounding residue, not the edge banding that would signal real alpha loss.
ALPHA_ROUNDING_TOLERANCE = 1


@dataclass
class FileResult:
    path: Path
    before: int
    after: int
    skipped: bool
    max_alpha_delta: int


def _iter_bundled_pngs(pets_root: Path):
    for pet_dir in sorted(p for p in pets_root.iterdir() if p.is_dir()):
        for subdir in BUNDLED_SUBDIRS:
            target = pet_dir / subdir
            if not target.is_dir():
                continue
            yield from sorted(target.glob("*.png"))


def _quantize(path: Path, colors: int, dry_run: bool) -> FileResult:
    before = path.stat().st_size
    with Image.open(path) as opened:
        # Already palette-mode from an earlier run — leave it alone so the
        # script stays idempotent and never re-quantizes a quantized image.
        if opened.mode == "P":
            return FileResult(path, before, before, True, 0)

        original = opened.convert("RGBA")

    quantized = original.quantize(colors=colors, method=Image.FASTOCTREE)
    source_alpha = original.getchannel("A").tobytes()
    result_alpha = quantized.convert("RGBA").getchannel("A").tobytes()
    max_alpha_delta = max(
        (abs(a - b) for a, b in zip(source_alpha, result_alpha)),
        default=0,
    )

    if dry_run:
        buffer = io.BytesIO()
        quantized.save(buffer, "PNG", optimize=True)
        return FileResult(path, before, buffer.tell(), False, max_alpha_delta)

    quantized.save(path, "PNG", optimize=True)
    return FileResult(path, before, path.stat().st_size, False, max_alpha_delta)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Repository root (defaults to the parent of tools/).",
    )
    parser.add_argument(
        "--colors",
        type=int,
        default=DEFAULT_PALETTE_COLORS,
        help=f"Palette size, 2-256 (default {DEFAULT_PALETTE_COLORS}).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report the savings without rewriting any file.",
    )
    args = parser.parse_args(argv)

    if not 2 <= args.colors <= 256:
        parser.error("--colors must be between 2 and 256")

    pets_root = args.root / "assets" / "pets"
    if not pets_root.is_dir():
        print(f"No sprite directory at {pets_root}", file=sys.stderr)
        return 1

    files = list(_iter_bundled_pngs(pets_root))
    if not files:
        print(f"No bundled sprite PNGs under {pets_root}", file=sys.stderr)
        return 1

    results: list[FileResult] = []
    for index, path in enumerate(files, start=1):
        results.append(_quantize(path, args.colors, args.dry_run))
        if index % 200 == 0 or index == len(files):
            print(f"  {index}/{len(files)} processed", flush=True)

    converted = [r for r in results if not r.skipped]
    skipped = [r for r in results if r.skipped]
    rounded = [r for r in converted if r.max_alpha_delta > 0]
    banded = [
        r for r in converted if r.max_alpha_delta > ALPHA_ROUNDING_TOLERANCE
    ]

    before = sum(r.before for r in results)
    after = sum(r.after for r in results)

    print()
    print(f"files            {len(results)} ({len(converted)} converted, {len(skipped)} already palette)")
    print(f"before           {before / 1048576:.1f} MB")
    print(f"after            {after / 1048576:.1f} MB")
    if before:
        print(f"saved            {(before - after) / 1048576:.1f} MB ({(1 - after / before) * 100:.1f}%)")
    worst_alpha = max((r.max_alpha_delta for r in converted), default=0)
    print(
        f"alpha            max delta {worst_alpha}/255 "
        f"({len(converted) - len(rounded)} exact, {len(rounded)} within rounding)"
    )
    if banded:
        print()
        print(
            f"WARNING: {len(banded)} file(s) shifted alpha by more than "
            f"{ALPHA_ROUNDING_TOLERANCE}; soft edges may band:"
        )
        for result in banded[:10]:
            print(f"  {result.path} (delta {result.max_alpha_delta})")
        if len(banded) > 10:
            print(f"  ... and {len(banded) - 10} more")
    if args.dry_run:
        print()
        print("dry run: nothing was written")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
