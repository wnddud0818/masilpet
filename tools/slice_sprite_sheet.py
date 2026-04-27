#!/usr/bin/env python3
"""Slice MasilPet generated sprite sheets into game-ready asset files."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from PIL import Image


PET_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
DEFAULT_OUTPUT_SIZE = 256
DEFAULT_FIT_SIZE = 224
DEFAULT_BOTTOM_PADDING = 16
DEFAULT_PALETTE_COLORS = 64
DEFAULT_WHITE_THRESHOLD = 235
DEFAULT_BLACK_THRESHOLD = 84
DEFAULT_SNAP_NEUTRAL_TOLERANCE = 24


@dataclass(frozen=True)
class SheetConfig:
    rows: int
    cols: int
    output_dir: str
    names: tuple[str, ...]
    source_name: str
    manifest_key: str


def _animation_config(action: str) -> SheetConfig:
    return SheetConfig(
        rows=1,
        cols=4,
        output_dir="animations",
        names=tuple(f"{action}_{index:02d}" for index in range(1, 5)),
        source_name=f"{action}_animation_sheet.png",
        manifest_key="animations",
    )


SHEET_TYPES: dict[str, SheetConfig] = {
    "actions": SheetConfig(
        rows=2,
        cols=3,
        output_dir="actions",
        names=("idle", "walking", "jumping", "eating", "sleeping", "greeting"),
        source_name="action_poses_sheet.png",
        manifest_key="actions",
    ),
    "emotions": SheetConfig(
        rows=2,
        cols=3,
        output_dir="emotions",
        names=("neutral", "happy", "excited", "sad", "surprised", "sleepy"),
        source_name="emotions_sheet.png",
        manifest_key="emotions",
    ),
    "emotions12": SheetConfig(
        rows=3,
        cols=4,
        output_dir="emotions",
        names=(
            "neutral",
            "happy",
            "excited",
            "sad",
            "angry",
            "surprised",
            "shy",
            "tired",
            "sleepy",
            "hungry",
            "curious",
            "proud",
        ),
        source_name="emotions_12_sheet.png",
        manifest_key="emotions",
    ),
    # Matches the current Flutter PetStage enum and existing asset folders.
    "growth": SheetConfig(
        rows=1,
        cols=3,
        output_dir="growth",
        names=("baby", "grown", "evolved"),
        source_name="growth_sheet.png",
        manifest_key="growth",
    ),
    # Matches the prompt guide's egg -> baby -> evolved concept sheet.
    "evolution": SheetConfig(
        rows=1,
        cols=3,
        output_dir="growth",
        names=("egg", "baby", "evolved"),
        source_name="evolution_sheet.png",
        manifest_key="growth",
    ),
    "idle_animation": _animation_config("idle"),
    "walk_animation": _animation_config("walk"),
    "sleep_animation": _animation_config("sleep"),
    "eat_animation": _animation_config("eat"),
    "greet_animation": _animation_config("greet"),
}


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Slice a generated MasilPet sprite sheet into game-ready PNG assets.",
    )
    parser.add_argument(
        "--pet-id",
        required=True,
        help="Pet asset key, for example roof_mascot or wave_naru.",
    )
    parser.add_argument(
        "--sheet-type",
        required=True,
        choices=sorted(SHEET_TYPES),
        help="Sprite sheet layout/type to slice.",
    )
    parser.add_argument(
        "--input",
        required=True,
        type=Path,
        help="Path to the generated sprite sheet PNG.",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Project root. Defaults to the current working directory.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing output assets and source sheet copy.",
    )
    parser.add_argument(
        "--output-size",
        type=int,
        default=DEFAULT_OUTPUT_SIZE,
        help="Output canvas size in pixels. Defaults to 256.",
    )
    parser.add_argument(
        "--fit-size",
        type=int,
        default=DEFAULT_FIT_SIZE,
        help="Maximum subject size inside the output canvas. Defaults to 224.",
    )
    parser.add_argument(
        "--anchor",
        choices=("auto", "center", "feet"),
        default="auto",
        help="Placement after trimming. auto uses feet for animations, center otherwise.",
    )
    parser.add_argument(
        "--bottom-padding",
        type=int,
        default=DEFAULT_BOTTOM_PADDING,
        help="Bottom padding in pixels when --anchor feet is active. Defaults to 16.",
    )
    parser.add_argument(
        "--trim-padding",
        type=int,
        default=2,
        help="Extra source-pixel padding around the detected character bbox. Defaults to 2.",
    )
    parser.add_argument(
        "--bg-threshold",
        type=int,
        default=36,
        help="RGB distance threshold for detecting edge-connected background. Defaults to 36.",
    )
    parser.add_argument(
        "--alpha-threshold",
        type=int,
        default=24,
        help="Pixels with alpha at or below this value are transparent. Defaults to 24.",
    )
    parser.add_argument(
        "--palette-colors",
        type=int,
        default=DEFAULT_PALETTE_COLORS,
        help="Maximum opaque colors after pixel-art quantization. Defaults to 64.",
    )
    parser.add_argument(
        "--resample",
        choices=("lanczos", "box", "nearest"),
        default="lanczos",
        help="Resize filter before palette quantization. Defaults to lanczos.",
    )
    parser.add_argument(
        "--keep-background",
        action="store_true",
        help="Disable edge-background removal and trim normalization.",
    )
    parser.add_argument(
        "--no-quantize",
        action="store_true",
        help="Disable palette reduction and hard alpha cleanup.",
    )
    parser.add_argument(
        "--no-color-snap",
        action="store_true",
        help="Disable near-white and near-black cleanup after resizing/quantization.",
    )
    parser.add_argument(
        "--white-threshold",
        type=int,
        default=DEFAULT_WHITE_THRESHOLD,
        help="Minimum RGB channel value for snapping neutral near-white pixels to pure white.",
    )
    parser.add_argument(
        "--black-threshold",
        type=int,
        default=DEFAULT_BLACK_THRESHOLD,
        help="Maximum RGB channel value for snapping neutral near-black pixels to pure black.",
    )
    parser.add_argument(
        "--snap-neutral-tolerance",
        type=int,
        default=DEFAULT_SNAP_NEUTRAL_TOLERANCE,
        help="Maximum RGB channel spread for white/black snapping. Lower keeps colored darks.",
    )
    return parser.parse_args(list(argv))


def validate_pet_id(pet_id: str) -> None:
    if not PET_ID_PATTERN.match(pet_id):
        raise ValueError(
            "--pet-id must use lowercase letters, numbers, underscores, or hyphens, "
            "and must start with a letter or number."
        )


def resolve_project_path(root: Path, value: Path) -> Path:
    path = value if value.is_absolute() else root / value
    return path.resolve()


def relative_posix(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def output_paths(root: Path, pet_id: str, config: SheetConfig) -> tuple[Path, list[Path]]:
    pet_root = root / "assets" / "pets" / pet_id
    source_path = pet_root / "source" / config.source_name
    sliced_paths = [
        pet_root / config.output_dir / f"{name}.png"
        for name in config.names
    ]
    return source_path, sliced_paths


def fail_if_targets_exist(paths: Iterable[Path], overwrite: bool) -> None:
    if overwrite:
        return
    existing = [path for path in paths if path.exists()]
    if existing:
        formatted = "\n".join(f"  - {path}" for path in existing)
        raise FileExistsError(
            "Refusing to overwrite existing files. Re-run with --overwrite if intended:\n"
            f"{formatted}"
        )


def validate_processing_args(args: argparse.Namespace) -> None:
    if not 16 <= args.output_size <= 512:
        raise ValueError("--output-size must be between 16 and 512.")
    if not 1 <= args.fit_size <= args.output_size:
        raise ValueError("--fit-size must be between 1 and --output-size.")
    if args.bottom_padding < 0:
        raise ValueError("--bottom-padding must be zero or greater.")
    if args.trim_padding < 0:
        raise ValueError("--trim-padding must be zero or greater.")
    if args.bg_threshold < 0:
        raise ValueError("--bg-threshold must be zero or greater.")
    if not 0 <= args.alpha_threshold <= 255:
        raise ValueError("--alpha-threshold must be between 0 and 255.")
    if not 2 <= args.palette_colors <= 256:
        raise ValueError("--palette-colors must be between 2 and 256.")
    if not 0 <= args.white_threshold <= 255:
        raise ValueError("--white-threshold must be between 0 and 255.")
    if not 0 <= args.black_threshold <= 255:
        raise ValueError("--black-threshold must be between 0 and 255.")
    if not 0 <= args.snap_neutral_tolerance <= 255:
        raise ValueError("--snap-neutral-tolerance must be between 0 and 255.")


def copy_source_sheet(source: Path, target: Path, overwrite: bool) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.resolve() == target.resolve():
        return
    if target.exists() and overwrite:
        target.unlink()
    shutil.copy2(source, target)


def median(values: list[int]) -> int:
    values = sorted(values)
    return values[len(values) // 2]


def estimate_background_color(image: Image.Image) -> tuple[int, int, int]:
    pixels = image.load()
    width, height = image.size
    samples: list[tuple[int, int, int]] = []

    for x in range(width):
        for y in (0, height - 1):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0:
                samples.append((red, green, blue))
    for y in range(height):
        for x in (0, width - 1):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0:
                samples.append((red, green, blue))

    if not samples:
        return (0, 0, 0)

    return (
        median([sample[0] for sample in samples]),
        median([sample[1] for sample in samples]),
        median([sample[2] for sample in samples]),
    )


def color_distance(first: tuple[int, int, int], second: tuple[int, int, int]) -> int:
    return (
        abs(first[0] - second[0])
        + abs(first[1] - second[1])
        + abs(first[2] - second[2])
    )


def edge_background_mask(
    image: Image.Image,
    bg_threshold: int,
    alpha_threshold: int,
) -> bytearray:
    width, height = image.size
    pixels = image.load()
    background = estimate_background_color(image)
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def index(x: int, y: int) -> int:
        return y * width + x

    def is_background_like(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        if alpha <= alpha_threshold:
            return True
        return color_distance((red, green, blue), background) <= bg_threshold

    def add_if_background(x: int, y: int) -> None:
        offset = index(x, y)
        if visited[offset] or not is_background_like(x, y):
            return
        visited[offset] = 1
        queue.append((x, y))

    for x in range(width):
        add_if_background(x, 0)
        add_if_background(x, height - 1)
    for y in range(height):
        add_if_background(0, y)
        add_if_background(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                add_if_background(nx, ny)

    return visited


def foreground_from_cell(
    cell: Image.Image,
    bg_threshold: int,
    alpha_threshold: int,
    trim_padding: int,
) -> tuple[Image.Image, tuple[int, int, int, int] | None]:
    width, height = cell.size
    mask = edge_background_mask(cell, bg_threshold, alpha_threshold)
    pixels = cell.load()
    foreground = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    foreground_pixels = foreground.load()

    left = width
    top = height
    right = 0
    bottom = 0

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= alpha_threshold or mask[y * width + x]:
                continue
            foreground_pixels[x, y] = (red, green, blue, alpha)
            left = min(left, x)
            top = min(top, y)
            right = max(right, x + 1)
            bottom = max(bottom, y + 1)

    if left >= right or top >= bottom:
        return foreground, None

    left = max(0, left - trim_padding)
    top = max(0, top - trim_padding)
    right = min(width, right + trim_padding)
    bottom = min(height, bottom + trim_padding)
    return foreground.crop((left, top, right, bottom)), (left, top, right, bottom)


def resampling_filter(name: str) -> Image.Resampling:
    if name == "nearest":
        return Image.Resampling.NEAREST
    if name == "box":
        return Image.Resampling.BOX
    return Image.Resampling.LANCZOS


def resize_to_fit(image: Image.Image, fit_size: int, resample: Image.Resampling) -> Image.Image:
    width, height = image.size
    if width == 0 or height == 0:
        return Image.new("RGBA", (fit_size, fit_size), (0, 0, 0, 0))
    scale = min(fit_size / width, fit_size / height)
    target_width = max(1, round(width * scale))
    target_height = max(1, round(height * scale))
    return image.resize((target_width, target_height), resample)


def quantize_pixel_art(
    image: Image.Image,
    palette_colors: int,
    alpha_threshold: int,
) -> Image.Image:
    alpha = image.getchannel("A").point(
        lambda value: 255 if value > alpha_threshold else 0,
        mode="L",
    )
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(
        colors=palette_colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def snap_key_colors(
    image: Image.Image,
    white_threshold: int,
    black_threshold: int,
    neutral_tolerance: int,
    alpha_threshold: int,
) -> Image.Image:
    output = image.copy().convert("RGBA")
    pixels = output.load()
    width, height = output.size

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= alpha_threshold:
                continue
            channel_min = min(red, green, blue)
            channel_max = max(red, green, blue)
            if channel_max - channel_min > neutral_tolerance:
                continue
            if channel_min >= white_threshold:
                pixels[x, y] = (255, 255, 255, alpha)
            elif channel_max <= black_threshold:
                pixels[x, y] = (0, 0, 0, alpha)

    return output


def trim_transparent(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return image.crop(bbox)


def resolve_anchor(anchor: str, config: SheetConfig) -> str:
    if anchor != "auto":
        return anchor
    return "feet" if config.output_dir == "animations" else "center"


def place_on_canvas(
    image: Image.Image,
    output_size: int,
    anchor: str,
    bottom_padding: int,
) -> Image.Image:
    canvas = Image.new("RGBA", (output_size, output_size), (0, 0, 0, 0))
    x = round((output_size - image.width) / 2)
    if anchor == "feet":
        y = output_size - bottom_padding - image.height
    else:
        y = round((output_size - image.height) / 2)
    canvas.alpha_composite(image, (max(0, x), max(0, y)))
    return canvas


def normalize_cell(cell: Image.Image, config: SheetConfig, args: argparse.Namespace) -> Image.Image:
    if args.keep_background:
        output = cell.resize(
            (args.output_size, args.output_size),
            resampling_filter(args.resample),
        )
        if not args.no_quantize:
            output = quantize_pixel_art(
                output,
                args.palette_colors,
                args.alpha_threshold,
            )
        if not args.no_color_snap:
            output = snap_key_colors(
                output,
                args.white_threshold,
                args.black_threshold,
                args.snap_neutral_tolerance,
                args.alpha_threshold,
            )
        return output

    foreground, bbox = foreground_from_cell(
        cell,
        args.bg_threshold,
        args.alpha_threshold,
        args.trim_padding,
    )
    if bbox is None:
        return Image.new("RGBA", (args.output_size, args.output_size), (0, 0, 0, 0))

    resized = resize_to_fit(foreground, args.fit_size, resampling_filter(args.resample))
    if not args.no_quantize:
        resized = quantize_pixel_art(resized, args.palette_colors, args.alpha_threshold)
    if not args.no_color_snap:
        resized = snap_key_colors(
            resized,
            args.white_threshold,
            args.black_threshold,
            args.snap_neutral_tolerance,
            args.alpha_threshold,
        )
    resized = trim_transparent(resized)
    return place_on_canvas(
        resized,
        args.output_size,
        resolve_anchor(args.anchor, config),
        args.bottom_padding,
    )


def slice_sheet(
    input_path: Path,
    output_files: list[Path],
    config: SheetConfig,
    args: argparse.Namespace,
) -> None:
    with Image.open(input_path) as image:
        image = image.convert("RGBA")
        cell_width = image.width / config.cols
        cell_height = image.height / config.rows

        for index, output_file in enumerate(output_files):
            row = index // config.cols
            col = index % config.cols
            left = round(col * cell_width)
            top = round(row * cell_height)
            right = round((col + 1) * cell_width)
            bottom = round((row + 1) * cell_height)

            cell = image.crop((left, top, right, bottom))
            cell = normalize_cell(cell, config, args)
            output_file.parent.mkdir(parents=True, exist_ok=True)
            cell.save(output_file, format="PNG")


def read_manifest(path: Path, pet_id: str) -> dict:
    if not path.exists():
        return {
            "petId": pet_id,
            "sourceSheets": {},
            "assets": {},
        }

    with path.open("r", encoding="utf-8") as file:
        manifest = json.load(file)
    if manifest.get("petId") not in (None, pet_id):
        raise ValueError(f"Manifest petId does not match --pet-id: {path}")
    manifest["petId"] = pet_id
    manifest.setdefault("sourceSheets", {})
    manifest.setdefault("assets", {})
    return manifest


def write_manifest(
    root: Path,
    pet_id: str,
    sheet_type: str,
    config: SheetConfig,
    source_path: Path,
    output_files: list[Path],
) -> Path:
    manifest_path = root / "assets" / "pets" / pet_id / "manifest.json"
    manifest = read_manifest(manifest_path, pet_id)
    manifest["updatedAt"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    manifest["sourceSheets"][sheet_type] = relative_posix(source_path, root)
    new_assets = [relative_posix(output_file, root) for output_file in output_files]
    if config.manifest_key == "animations":
        replaced = {Path(asset).name for asset in new_assets}
        existing_assets = manifest["assets"].get(config.manifest_key, [])
        manifest["assets"][config.manifest_key] = [
            asset for asset in existing_assets if Path(asset).name not in replaced
        ] + new_assets
    else:
        manifest["assets"][config.manifest_key] = new_assets

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    with manifest_path.open("w", encoding="utf-8", newline="\n") as file:
        json.dump(manifest, file, ensure_ascii=False, indent=2)
        file.write("\n")
    return manifest_path


def pubspec_warning(root: Path, pet_id: str, config: SheetConfig) -> str | None:
    pubspec_path = root / "pubspec.yaml"
    if not pubspec_path.exists():
        return None
    pubspec = pubspec_path.read_text(encoding="utf-8")
    expected = f"assets/pets/{pet_id}/{config.output_dir}/"
    if expected not in pubspec:
        return (
            f"Warning: {expected} is not listed in pubspec.yaml. "
            "Add it before using these assets in Flutter."
        )
    return None


def run(argv: Iterable[str]) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    input_path = resolve_project_path(root, args.input)
    pet_id = args.pet_id
    sheet_type = args.sheet_type
    config = SHEET_TYPES[sheet_type]

    validate_pet_id(pet_id)
    validate_processing_args(args)
    if not input_path.exists():
        raise FileNotFoundError(input_path)
    if len(config.names) != config.rows * config.cols:
        raise ValueError(f"Invalid sheet config for {sheet_type}")

    source_path, sliced_paths = output_paths(root, pet_id, config)
    manifest_path = root / "assets" / "pets" / pet_id / "manifest.json"
    overwrite_targets = list(sliced_paths)
    if input_path.resolve() != source_path.resolve():
        overwrite_targets.append(source_path)
    fail_if_targets_exist(overwrite_targets, args.overwrite)

    slice_sheet(input_path, sliced_paths, config, args)
    copy_source_sheet(input_path, source_path, args.overwrite)
    manifest_path = write_manifest(
        root=root,
        pet_id=pet_id,
        sheet_type=sheet_type,
        config=config,
        source_path=source_path,
        output_files=sliced_paths,
    )

    print(f"Sliced {sheet_type} for {pet_id}:")
    for path in sliced_paths:
        print(f"  {relative_posix(path, root)}")
    print(f"Source: {relative_posix(source_path, root)}")
    print(f"Manifest: {relative_posix(manifest_path, root)}")
    warning = pubspec_warning(root, pet_id, config)
    if warning:
        print(warning, file=sys.stderr)
    return 0


def main() -> None:
    try:
        raise SystemExit(run(sys.argv[1:]))
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
