#!/usr/bin/env python3
"""Slice MasilPet generated sprite sheets into game-ready asset files."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageColor, ImageFilter, ImageOps


SLICER_VERSION = "2.4.0"
PET_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
DEFAULT_OUTPUT_SIZE = 512
DEFAULT_FIT_SIZE = 448
DEFAULT_BOTTOM_PADDING = 32
DEFAULT_BG_THRESHOLD = 180
DEFAULT_PALETTE_COLORS = 48
DEFAULT_WHITE_THRESHOLD = 228
DEFAULT_BLACK_THRESHOLD = 88
DEFAULT_SNAP_NEUTRAL_TOLERANCE = 28
DEFAULT_STRICT_PIXEL_GRID_SIZE = 128
DEFAULT_STRICT_PALETTE_COLORS = 20
DEFAULT_STRICT_ALPHA_THRESHOLD = 128
DEFAULT_STRICT_WHITE_THRESHOLD = 228
DEFAULT_STRICT_BLACK_THRESHOLD = 88
DEFAULT_STRICT_SNAP_NEUTRAL_TOLERANCE = 28
DEFAULT_STRICT_POSTERIZE_BITS = 3
DEFAULT_OUTLINE_COLOR = "#18181a"
DEFAULT_BACKGROUND_ONLY_BG_THRESHOLD = 180
DEFAULT_OUTLINE_PROTECTION_COLOR_DISTANCE = 12
DEFAULT_OUTLINE_PROTECTION_FILTER_SIZE = 7
DEFAULT_STRAY_COMPONENT_MIN_AREA_RATIO = 0.03
DEFAULT_STRAY_COMPONENT_MAX_GAP_RATIO = 0.03


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


def argument_was_provided(args: list[str], name: str) -> bool:
    return any(value == name or value.startswith(f"{name}=") for value in args)


def apply_strict_pixel_art_defaults(args: argparse.Namespace, raw_args: list[str]) -> None:
    if not args.strict_pixel_art:
        return
    if not argument_was_provided(raw_args, "--pixel-grid-size"):
        args.pixel_grid_size = DEFAULT_STRICT_PIXEL_GRID_SIZE
    if not argument_was_provided(raw_args, "--palette-colors"):
        args.palette_colors = DEFAULT_STRICT_PALETTE_COLORS
    if not argument_was_provided(raw_args, "--alpha-threshold"):
        args.alpha_threshold = DEFAULT_STRICT_ALPHA_THRESHOLD
    if not argument_was_provided(raw_args, "--resample"):
        args.resample = "nearest"
    if not argument_was_provided(raw_args, "--posterize-bits"):
        args.posterize_bits = DEFAULT_STRICT_POSTERIZE_BITS
    if (
        not argument_was_provided(raw_args, "--rebuild-outline")
        and not argument_was_provided(raw_args, "--no-rebuild-outline")
    ):
        args.rebuild_outline = True
    if not argument_was_provided(raw_args, "--white-threshold"):
        args.white_threshold = DEFAULT_STRICT_WHITE_THRESHOLD
    if not argument_was_provided(raw_args, "--black-threshold"):
        args.black_threshold = DEFAULT_STRICT_BLACK_THRESHOLD
    if not argument_was_provided(raw_args, "--snap-neutral-tolerance"):
        args.snap_neutral_tolerance = DEFAULT_STRICT_SNAP_NEUTRAL_TOLERANCE
    if (
        not argument_was_provided(raw_args, "--remove-stray-components")
        and not argument_was_provided(raw_args, "--keep-stray-components")
    ):
        args.remove_stray_components = True


def apply_background_only_defaults(
    args: argparse.Namespace,
    raw_args: list[str],
) -> None:
    if not args.background_only:
        return
    if args.strict_pixel_art:
        raise ValueError("--background-only cannot be combined with --strict-pixel-art.")
    if args.keep_background:
        raise ValueError("--background-only cannot be combined with --keep-background.")
    if argument_was_provided(raw_args, "--pixel-grid-size"):
        raise ValueError("--background-only cannot be combined with --pixel-grid-size.")

    args.pixel_grid_size = 0
    args.posterize_bits = 0
    args.rebuild_outline = False
    args.no_quantize = True
    args.no_color_snap = True
    if not argument_was_provided(raw_args, "--bg-threshold"):
        args.bg_threshold = DEFAULT_BACKGROUND_ONLY_BG_THRESHOLD
    if (
        not argument_was_provided(raw_args, "--remove-stray-components")
        and not argument_was_provided(raw_args, "--keep-stray-components")
    ):
        args.remove_stray_components = True
    if (
        not argument_was_provided(raw_args, "--protect-enclosed-regions")
        and not argument_was_provided(raw_args, "--no-protect-enclosed-regions")
    ):
        args.protect_enclosed_regions = True


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    raw_args = list(argv)
    parser = argparse.ArgumentParser(
        description="Slice a generated MasilPet sprite sheet into game-ready PNG assets.",
    )
    parser.add_argument(
        "--pet-id",
        required=True,
        help="Pet asset key, for example roof_mascot or sample_pet.",
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
        help="Output canvas size in pixels. Defaults to 512.",
    )
    parser.add_argument(
        "--fit-size",
        type=int,
        default=DEFAULT_FIT_SIZE,
        help="Maximum subject size inside the output canvas. Defaults to 448.",
    )
    parser.add_argument(
        "--strict-pixel-art",
        action="store_true",
        help=(
            "Normalize on a 128px pixel grid, reduce to a tighter palette, harden alpha, "
            "then upscale with nearest-neighbor. Explicit options override the shortcut."
        ),
    )
    parser.add_argument(
        "--background-only",
        action="store_true",
        help=(
            "Preserve generated resolution and colors: remove the background, trim, "
            "and place on the output canvas without palette reduction, pixel-grid "
            "rebuild, posterization, color snapping, or outline reconstruction."
        ),
    )
    parser.add_argument(
        "--pixel-grid-size",
        type=int,
        default=0,
        help=(
            "Optional low-resolution pixel canvas size before nearest-neighbor upscaling. "
            "Use 128 for clean 2x upscale pixels, or 64 for chunkier 64px pixel art. "
            "Defaults to disabled."
        ),
    )
    parser.add_argument(
        "--posterize-bits",
        type=int,
        default=0,
        help=(
            "Reduce RGB channel precision before final color snapping. "
            "Use 3 or 4 for flatter pixel-art colors. Defaults to disabled."
        ),
    )
    parser.set_defaults(rebuild_outline=None)
    parser.add_argument(
        "--rebuild-outline",
        dest="rebuild_outline",
        action="store_true",
        help="Draw a hard one-pixel outline around the normalized alpha mask.",
    )
    parser.add_argument(
        "--no-rebuild-outline",
        dest="rebuild_outline",
        action="store_false",
        help="Disable outline rebuild when using --strict-pixel-art.",
    )
    parser.add_argument(
        "--outline-color",
        default=DEFAULT_OUTLINE_COLOR,
        help=f"Outline color for --rebuild-outline. Defaults to {DEFAULT_OUTLINE_COLOR}.",
    )
    parser.add_argument(
        "--outline-thickness",
        type=int,
        default=1,
        help="Outline thickness in low-resolution pixels. Defaults to 1.",
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
        help="Bottom padding in pixels when --anchor feet is active. Defaults to 32.",
    )
    parser.add_argument(
        "--trim-padding",
        type=int,
        default=2,
        help="Extra source-pixel padding around the detected character bbox. Defaults to 2.",
    )
    parser.set_defaults(remove_stray_components=None)
    parser.add_argument(
        "--remove-stray-components",
        dest="remove_stray_components",
        action="store_true",
        help=(
            "Remove tiny disconnected foreground fragments far from the main subject. "
            "Enabled automatically by --strict-pixel-art."
        ),
    )
    parser.add_argument(
        "--keep-stray-components",
        dest="remove_stray_components",
        action="store_false",
        help="Preserve all disconnected foreground fragments in strict pixel-art mode.",
    )
    parser.add_argument(
        "--bg-threshold",
        type=int,
        default=DEFAULT_BG_THRESHOLD,
        help="RGB distance threshold for detecting edge-connected background. Defaults to 180.",
    )
    parser.set_defaults(protect_enclosed_regions=None)
    parser.add_argument(
        "--protect-enclosed-regions",
        dest="protect_enclosed_regions",
        action="store_true",
        help=(
            "Close small outline gaps before background flood-fill so light face and "
            "body interiors are not removed. Enabled automatically by --background-only."
        ),
    )
    parser.add_argument(
        "--no-protect-enclosed-regions",
        dest="protect_enclosed_regions",
        action="store_false",
        help="Disable outline-gap protection during background removal.",
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
        help="Maximum opaque colors after pixel-art quantization. Defaults to 48.",
    )
    parser.add_argument(
        "--per-cell-palette",
        action="store_true",
        help=(
            "Quantize each cell to its own palette. Default is a sheet-wide shared palette "
            "so emotion/animation cells stay color-consistent."
        ),
    )
    parser.add_argument(
        "--resample",
        choices=("lanczos", "box", "nearest"),
        default="nearest",
        help="Resize filter before palette quantization. Defaults to nearest.",
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
    parser.add_argument(
        "--no-centroid-align",
        action="store_true",
        help=(
            "Disable horizontal centroid alignment for animation frames. "
            "Centroid alignment is on by default for animation sheets to reduce loop jitter."
        ),
    )
    parser.add_argument(
        "--update-pubspec",
        action="store_true",
        help="Auto-insert the new asset folder under flutter.assets in pubspec.yaml when missing.",
    )
    parser.add_argument(
        "--preview",
        type=Path,
        default=None,
        help=(
            "Write a sliced preview PNG (with cell guides + numbering) to the given path "
            "and exit without producing app assets."
        ),
    )
    args = parser.parse_args(raw_args)
    apply_strict_pixel_art_defaults(args, raw_args)
    apply_background_only_defaults(args, raw_args)
    if args.rebuild_outline is None:
        args.rebuild_outline = False
    if args.remove_stray_components is None:
        args.remove_stray_components = False
    if args.protect_enclosed_regions is None:
        args.protect_enclosed_regions = False
    return args


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
    if args.pixel_grid_size:
        if not 16 <= args.pixel_grid_size <= args.output_size:
            raise ValueError("--pixel-grid-size must be between 16 and --output-size.")
        if args.output_size % args.pixel_grid_size != 0:
            raise ValueError("--output-size must be divisible by --pixel-grid-size.")
    if args.bottom_padding < 0:
        raise ValueError("--bottom-padding must be zero or greater.")
    if not 0 <= args.posterize_bits <= 8:
        raise ValueError("--posterize-bits must be between 0 and 8.")
    if args.posterize_bits == 1:
        raise ValueError("--posterize-bits must be 0 or between 2 and 8.")
    if args.outline_thickness < 0:
        raise ValueError("--outline-thickness must be zero or greater.")
    try:
        ImageColor.getrgb(args.outline_color)
    except ValueError as exc:
        raise ValueError("--outline-color must be a valid Pillow color.") from exc
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
    protect_enclosed_regions: bool = False,
) -> bytearray:
    width, height = image.size
    pixels = image.load()
    background = estimate_background_color(image)
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()
    protected_pixels = None

    if protect_enclosed_regions:
        protection_threshold = min(
            bg_threshold,
            DEFAULT_OUTLINE_PROTECTION_COLOR_DISTANCE,
        )
        barrier = Image.new("L", image.size, 0)
        barrier_pixels = barrier.load()
        for y in range(height):
            for x in range(width):
                red, green, blue, alpha = pixels[x, y]
                if alpha <= alpha_threshold:
                    continue
                if color_distance((red, green, blue), background) > protection_threshold:
                    barrier_pixels[x, y] = 255
        protected = barrier.filter(
            ImageFilter.MaxFilter(DEFAULT_OUTLINE_PROTECTION_FILTER_SIZE)
        ).filter(ImageFilter.MinFilter(DEFAULT_OUTLINE_PROTECTION_FILTER_SIZE))
        protected_pixels = protected.load()

    def index(x: int, y: int) -> int:
        return y * width + x

    def is_background_like(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        if alpha <= alpha_threshold:
            return True
        if protected_pixels is not None and protected_pixels[x, y] > 0:
            return False
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


def remove_stray_foreground_components(
    foreground: Image.Image,
    alpha_threshold: int,
) -> Image.Image:
    """Drop tiny, distant components caused by neighboring sprite-cell spill.

    Generated sheets occasionally leave a narrow colored fragment exactly at a cell
    boundary. The largest connected alpha component is treated as the character.
    Detached components are retained when they are sizeable or spatially close to
    that character, preserving legitimate props, feet, and accessories.
    """
    width, height = foreground.size
    alpha = foreground.getchannel("A")
    alpha_pixels = alpha.load()
    visited = bytearray(width * height)
    components: list[tuple[list[int], tuple[int, int, int, int]]] = []

    for y in range(height):
        for x in range(width):
            start = y * width + x
            if visited[start] or alpha_pixels[x, y] <= alpha_threshold:
                continue

            visited[start] = 1
            queue: deque[int] = deque((start,))
            offsets: list[int] = []
            left = right = x
            top = bottom = y

            while queue:
                offset = queue.popleft()
                current_x = offset % width
                current_y = offset // width
                offsets.append(offset)
                left = min(left, current_x)
                top = min(top, current_y)
                right = max(right, current_x)
                bottom = max(bottom, current_y)

                for next_x, next_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if not (0 <= next_x < width and 0 <= next_y < height):
                        continue
                    next_offset = next_y * width + next_x
                    if (
                        visited[next_offset]
                        or alpha_pixels[next_x, next_y] <= alpha_threshold
                    ):
                        continue
                    visited[next_offset] = 1
                    queue.append(next_offset)

            components.append((offsets, (left, top, right + 1, bottom + 1)))

    if len(components) <= 1:
        return foreground

    components.sort(key=lambda item: len(item[0]), reverse=True)
    main_offsets, main_bbox = components[0]
    minimum_kept_area = max(
        4,
        round(len(main_offsets) * DEFAULT_STRAY_COMPONENT_MIN_AREA_RATIO),
    )
    maximum_kept_gap = max(
        2,
        round(min(width, height) * DEFAULT_STRAY_COMPONENT_MAX_GAP_RATIO),
    )
    main_left, main_top, main_right, main_bottom = main_bbox
    removable_offsets: list[int] = []

    for offsets, bbox in components[1:]:
        if len(offsets) >= minimum_kept_area:
            continue
        left, top, right, bottom = bbox
        horizontal_gap = max(main_left - right, left - main_right, 0)
        vertical_gap = max(main_top - bottom, top - main_bottom, 0)
        if max(horizontal_gap, vertical_gap) <= maximum_kept_gap:
            continue
        removable_offsets.extend(offsets)

    if not removable_offsets:
        return foreground

    cleaned = foreground.copy()
    cleaned_pixels = cleaned.load()
    for offset in removable_offsets:
        cleaned_pixels[offset % width, offset // width] = (0, 0, 0, 0)
    return cleaned


def foreground_from_cell(
    cell: Image.Image,
    bg_threshold: int,
    alpha_threshold: int,
    trim_padding: int,
    remove_stray_components: bool = False,
    protect_enclosed_regions: bool = False,
) -> tuple[Image.Image, tuple[int, int, int, int] | None]:
    width, height = cell.size
    mask = edge_background_mask(
        cell,
        bg_threshold,
        alpha_threshold,
        protect_enclosed_regions,
    )
    pixels = cell.load()
    foreground = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    foreground_pixels = foreground.load()

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= alpha_threshold or mask[y * width + x]:
                continue
            foreground_pixels[x, y] = (red, green, blue, alpha)

    if remove_stray_components:
        foreground = remove_stray_foreground_components(
            foreground,
            alpha_threshold,
        )

    bbox = foreground.getchannel("A").getbbox()
    if bbox is None:
        return foreground, None

    left, top, right, bottom = bbox
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


def scale_dimension(value: int, source_size: int, target_size: int) -> int:
    return max(1, round(value * target_size / source_size))


def scale_padding(value: int, source_size: int, target_size: int) -> int:
    return max(0, round(value * target_size / source_size))


def hard_alpha_mask(image: Image.Image, alpha_threshold: int) -> Image.Image:
    return image.getchannel("A").point(
        lambda value: 255 if value > alpha_threshold else 0,
        mode="L",
    )


def quantize_pixel_art(
    image: Image.Image,
    palette_colors: int,
    alpha_threshold: int,
) -> Image.Image:
    alpha = hard_alpha_mask(image, alpha_threshold)
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(
        colors=palette_colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def build_shared_palette(
    images: list[Image.Image],
    palette_colors: int,
    alpha_threshold: int,
) -> Image.Image | None:
    """Concatenate all opaque foreground samples into a single image and quantize once.

    Returns a paletted (mode "P") image whose palette is shared across the sheet's cells.
    Returns None when no opaque pixels are available.
    """
    samples: list[Image.Image] = []
    max_height = 0
    total_width = 0
    for image in images:
        alpha = hard_alpha_mask(image, alpha_threshold)
        rgb = Image.new("RGB", image.size, (0, 0, 0))
        rgb.paste(image.convert("RGB"), mask=alpha)
        samples.append(rgb)
        max_height = max(max_height, rgb.height)
        total_width += rgb.width
    if not samples or total_width == 0 or max_height == 0:
        return None
    canvas = Image.new("RGB", (total_width, max_height), (0, 0, 0))
    cursor = 0
    for sample in samples:
        canvas.paste(sample, (cursor, 0))
        cursor += sample.width
    return canvas.quantize(
        colors=palette_colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )


def quantize_with_shared_palette(
    image: Image.Image,
    palette_image: Image.Image,
    alpha_threshold: int,
) -> Image.Image:
    alpha = hard_alpha_mask(image, alpha_threshold)
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(
        palette=palette_image,
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


def posterize_colors(image: Image.Image, bits: int) -> Image.Image:
    if bits == 0:
        return image
    alpha = image.getchannel("A")
    rgb = ImageOps.posterize(image.convert("RGB"), bits)
    output = rgb.convert("RGBA")
    output.putalpha(alpha)
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


def horizontal_centroid(image: Image.Image, alpha_threshold: int) -> int | None:
    """Return the x-coordinate of the opaque-pixel centroid, or None when fully transparent."""
    alpha = image.getchannel("A")
    width, height = image.size
    weight_sum = 0
    weighted_x = 0
    data = alpha.load()
    for y in range(height):
        for x in range(width):
            if data[x, y] > alpha_threshold:
                weight_sum += 1
                weighted_x += x
    if weight_sum == 0:
        return None
    return round(weighted_x / weight_sum)


def place_on_canvas(
    image: Image.Image,
    output_size: int,
    anchor: str,
    bottom_padding: int,
    centroid_x: int | None = None,
) -> Image.Image:
    canvas = Image.new("RGBA", (output_size, output_size), (0, 0, 0, 0))
    if centroid_x is not None:
        x = round(output_size / 2) - centroid_x
    else:
        x = round((output_size - image.width) / 2)
    if anchor == "feet":
        y = output_size - bottom_padding - image.height
    else:
        y = round((output_size - image.height) / 2)
    if x < 0:
        x = 0
    if x + image.width > output_size:
        x = output_size - image.width
    if y < 0:
        y = 0
    if y + image.height > output_size:
        y = output_size - image.height
    canvas.alpha_composite(image, (x, y))
    return canvas


def outline_color_rgba(raw: str) -> tuple[int, int, int, int]:
    red, green, blue = ImageColor.getrgb(raw)
    return red, green, blue, 255


def rebuild_outline(
    image: Image.Image,
    color: tuple[int, int, int, int],
    thickness: int,
    alpha_threshold: int,
) -> Image.Image:
    if thickness == 0:
        return image

    output = image.copy().convert("RGBA")
    width, height = output.size

    for _ in range(thickness):
        alpha = output.getchannel("A")
        pixels = output.load()
        outline_pixels: list[tuple[int, int]] = []

        for y in range(height):
            for x in range(width):
                if alpha.getpixel((x, y)) > alpha_threshold:
                    continue
                for nx, ny in (
                    (x - 1, y),
                    (x + 1, y),
                    (x, y - 1),
                    (x, y + 1),
                    (x - 1, y - 1),
                    (x + 1, y - 1),
                    (x - 1, y + 1),
                    (x + 1, y + 1),
                ):
                    if 0 <= nx < width and 0 <= ny < height:
                        if alpha.getpixel((nx, ny)) > alpha_threshold:
                            outline_pixels.append((x, y))
                            break

        for x, y in outline_pixels:
            pixels[x, y] = color

    return output


def slice_grid(image: Image.Image, config: SheetConfig) -> list[Image.Image]:
    """Crop equal-sized cells from a sheet in row-major order."""
    cell_width = image.width / config.cols
    cell_height = image.height / config.rows
    cells: list[Image.Image] = []
    for index in range(config.rows * config.cols):
        row = index // config.cols
        col = index % config.cols
        left = round(col * cell_width)
        top = round(row * cell_height)
        right = round((col + 1) * cell_width)
        bottom = round((row + 1) * cell_height)
        cells.append(image.crop((left, top, right, bottom)))
    return cells


def normalize_cells(
    cells: list[Image.Image],
    config: SheetConfig,
    args: argparse.Namespace,
) -> list[tuple[Image.Image, bool]]:
    """Run the normalization pipeline over all sheet cells.

    Returns a list of `(image, was_empty)` tuples in cell order.
    Uses a single shared palette for the whole sheet by default.
    """
    normalize_size = args.pixel_grid_size or args.output_size
    fit_size = (
        scale_dimension(args.fit_size, args.output_size, normalize_size)
        if args.pixel_grid_size
        else args.fit_size
    )
    bottom_padding = (
        scale_padding(args.bottom_padding, args.output_size, normalize_size)
        if args.pixel_grid_size
        else args.bottom_padding
    )
    anchor = resolve_anchor(args.anchor, config)
    centroid_align = (
        anchor == "feet"
        and not args.no_centroid_align
        and config.manifest_key == "animations"
    )

    # Step 1: extract foreground (or keep raw) and resize each cell.
    extracted: list[tuple[Image.Image, bool]] = []
    for cell in cells:
        if args.keep_background:
            resized = cell.resize(
                (normalize_size, normalize_size),
                resampling_filter(args.resample),
            )
            extracted.append((resized, False))
            continue

        foreground, bbox = foreground_from_cell(
            cell,
            args.bg_threshold,
            args.alpha_threshold,
            args.trim_padding,
            args.remove_stray_components,
            args.protect_enclosed_regions,
        )
        if bbox is None:
            extracted.append(
                (Image.new("RGBA", (normalize_size, normalize_size), (0, 0, 0, 0)), True)
            )
            continue

        resized = resize_to_fit(foreground, fit_size, resampling_filter(args.resample))
        extracted.append((resized, False))

    # Step 2: shared palette quantization across the whole sheet.
    quantized: list[tuple[Image.Image, bool]] = []
    if not args.no_quantize:
        if args.per_cell_palette:
            for image, was_empty in extracted:
                if was_empty:
                    quantized.append((image, was_empty))
                    continue
                quantized.append(
                    (quantize_pixel_art(image, args.palette_colors, args.alpha_threshold), False)
                )
        else:
            non_empty = [image for image, was_empty in extracted if not was_empty]
            palette_image = build_shared_palette(
                non_empty, args.palette_colors, args.alpha_threshold
            )
            for image, was_empty in extracted:
                if was_empty or palette_image is None:
                    quantized.append((image, was_empty))
                    continue
                quantized.append(
                    (
                        quantize_with_shared_palette(
                            image, palette_image, args.alpha_threshold
                        ),
                        False,
                    )
                )
    else:
        quantized = extracted

    # Step 3: posterize, snap colors.
    polished: list[tuple[Image.Image, bool]] = []
    for image, was_empty in quantized:
        if was_empty:
            polished.append((image, True))
            continue
        out = posterize_colors(image, args.posterize_bits)
        if not args.no_color_snap:
            out = snap_key_colors(
                out,
                args.white_threshold,
                args.black_threshold,
                args.snap_neutral_tolerance,
                args.alpha_threshold,
            )
        polished.append((out, False))

    # Step 4: trim, place on canvas with shared anchor, optional outline + upscale.
    placed: list[tuple[Image.Image, bool]] = []
    for image, was_empty in polished:
        if was_empty:
            empty_canvas = Image.new(
                "RGBA", (args.output_size, args.output_size), (0, 0, 0, 0)
            )
            placed.append((empty_canvas, True))
            continue

        if args.keep_background:
            canvas = image
        else:
            trimmed = trim_transparent(image)
            centroid_x: int | None = None
            if centroid_align:
                centroid_x = horizontal_centroid(trimmed, args.alpha_threshold)
            canvas = place_on_canvas(
                trimmed,
                normalize_size,
                anchor,
                bottom_padding,
                centroid_x=centroid_x,
            )

        if args.rebuild_outline:
            canvas = rebuild_outline(
                canvas,
                outline_color_rgba(args.outline_color),
                args.outline_thickness,
                args.alpha_threshold,
            )
        if args.pixel_grid_size:
            canvas = canvas.resize(
                (args.output_size, args.output_size),
                Image.Resampling.NEAREST,
            )
        placed.append((canvas, False))

    return placed


def slice_sheet(
    input_path: Path,
    output_files: list[Path],
    config: SheetConfig,
    args: argparse.Namespace,
) -> list[str]:
    """Slice the sheet, write outputs, and return the list of empty cell names."""
    with Image.open(input_path) as image:
        image = image.convert("RGBA")
        cells = slice_grid(image, config)

    results = normalize_cells(cells, config, args)
    empty_names: list[str] = []
    for output_file, name, (final_image, was_empty) in zip(
        output_files, config.names, results
    ):
        output_file.parent.mkdir(parents=True, exist_ok=True)
        final_image.save(output_file, format="PNG")
        if was_empty:
            empty_names.append(name)
    return empty_names


def write_preview(
    input_path: Path,
    config: SheetConfig,
    preview_path: Path,
) -> None:
    """Write a preview PNG with red cell guides + cell numbers for human inspection."""
    from PIL import ImageDraw, ImageFont

    with Image.open(input_path) as image:
        canvas = image.convert("RGBA").copy()
    draw = ImageDraw.Draw(canvas)
    cell_width = canvas.width / config.cols
    cell_height = canvas.height / config.rows
    try:
        font = ImageFont.truetype("arial.ttf", max(12, int(cell_height // 8)))
    except OSError:
        font = ImageFont.load_default()
    for index in range(config.rows * config.cols):
        row = index // config.cols
        col = index % config.cols
        left = round(col * cell_width)
        top = round(row * cell_height)
        right = round((col + 1) * cell_width)
        bottom = round((row + 1) * cell_height)
        draw.rectangle((left, top, right - 1, bottom - 1), outline=(255, 0, 0, 255), width=2)
        label = config.names[index] if index < len(config.names) else str(index + 1)
        draw.text((left + 4, top + 4), f"{index + 1}: {label}", fill=(255, 0, 0, 255), font=font)
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(preview_path, format="PNG")


def compute_sheet_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def slicer_options_summary(args: argparse.Namespace) -> dict:
    return {
        "outputSize": args.output_size,
        "fitSize": args.fit_size,
        "anchor": args.anchor,
        "bottomPadding": args.bottom_padding,
        "trimPadding": args.trim_padding,
        "removeStrayComponents": bool(args.remove_stray_components),
        "protectEnclosedRegions": bool(args.protect_enclosed_regions),
        "protectionColorDistance": (
            DEFAULT_OUTLINE_PROTECTION_COLOR_DISTANCE
            if args.protect_enclosed_regions
            else None
        ),
        "bgThreshold": args.bg_threshold,
        "alphaThreshold": args.alpha_threshold,
        "paletteColors": args.palette_colors,
        "perCellPalette": bool(args.per_cell_palette),
        "resample": args.resample,
        "keepBackground": bool(args.keep_background),
        "noQuantize": bool(args.no_quantize),
        "noColorSnap": bool(args.no_color_snap),
        "whiteThreshold": args.white_threshold,
        "blackThreshold": args.black_threshold,
        "snapNeutralTolerance": args.snap_neutral_tolerance,
        "strictPixelArt": bool(args.strict_pixel_art),
        "backgroundOnly": bool(args.background_only),
        "pixelGridSize": args.pixel_grid_size,
        "posterizeBits": args.posterize_bits,
        "rebuildOutline": bool(args.rebuild_outline),
        "outlineColor": args.outline_color,
        "outlineThickness": args.outline_thickness,
        "centroidAlign": (not args.no_centroid_align),
    }


def read_manifest(path: Path, pet_id: str) -> dict:
    if not path.exists():
        return {
            "petId": pet_id,
            "slicerVersion": SLICER_VERSION,
            "sourceSheets": {},
            "assets": {},
            "history": {},
        }

    with path.open("r", encoding="utf-8") as file:
        manifest = json.load(file)
    if manifest.get("petId") not in (None, pet_id):
        raise ValueError(f"Manifest petId does not match --pet-id: {path}")
    manifest["petId"] = pet_id
    manifest.setdefault("slicerVersion", SLICER_VERSION)
    manifest.setdefault("sourceSheets", {})
    manifest.setdefault("assets", {})
    manifest.setdefault("history", {})
    return manifest


def write_manifest(
    root: Path,
    pet_id: str,
    sheet_type: str,
    config: SheetConfig,
    source_path: Path,
    output_files: list[Path],
    args: argparse.Namespace,
    empty_names: list[str],
) -> Path:
    manifest_path = root / "assets" / "pets" / pet_id / "manifest.json"
    manifest = read_manifest(manifest_path, pet_id)
    manifest["slicerVersion"] = SLICER_VERSION
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

    manifest["history"][sheet_type] = {
        "updatedAt": manifest["updatedAt"],
        "sourceHash": compute_sheet_hash(source_path),
        "options": slicer_options_summary(args),
        "emptyCells": list(empty_names),
        "outputs": new_assets,
    }

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
            "Add it before using these assets in Flutter, or re-run with --update-pubspec."
        )
    return None


def update_pubspec_assets(root: Path, pet_id: str, config: SheetConfig) -> bool:
    """Insert `assets/pets/[pet_id]/[output_dir]/` under `flutter.assets`. Returns True on change."""
    pubspec_path = root / "pubspec.yaml"
    if not pubspec_path.exists():
        return False
    text = pubspec_path.read_text(encoding="utf-8")
    needle = f"assets/pets/{pet_id}/{config.output_dir}/"
    if needle in text:
        return False
    lines = text.splitlines()
    flutter_index: int | None = None
    assets_index: int | None = None
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("flutter:") and not line.startswith(" "):
            flutter_index = index
        if flutter_index is not None and index > flutter_index:
            if stripped.startswith("assets:") and line.startswith("  assets:"):
                assets_index = index
                break
            if stripped and not line.startswith(" "):
                break
    if assets_index is None:
        return False
    insert_at = assets_index + 1
    while insert_at < len(lines):
        line = lines[insert_at]
        if not line.startswith("    -") and line.strip():
            break
        insert_at += 1
    lines.insert(insert_at, f"    - {needle}")
    pubspec_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return True


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

    if args.preview is not None:
        preview_path = resolve_project_path(root, args.preview)
        write_preview(input_path, config, preview_path)
        print(f"Wrote preview: {preview_path}")
        return 0

    source_path, sliced_paths = output_paths(root, pet_id, config)
    overwrite_targets = list(sliced_paths)
    if input_path.resolve() != source_path.resolve():
        overwrite_targets.append(source_path)
    fail_if_targets_exist(overwrite_targets, args.overwrite)

    empty_names = slice_sheet(input_path, sliced_paths, config, args)
    copy_source_sheet(input_path, source_path, args.overwrite)
    manifest_path = write_manifest(
        root=root,
        pet_id=pet_id,
        sheet_type=sheet_type,
        config=config,
        source_path=source_path,
        output_files=sliced_paths,
        args=args,
        empty_names=empty_names,
    )

    print(f"Sliced {sheet_type} for {pet_id}:")
    for path in sliced_paths:
        print(f"  {relative_posix(path, root)}")
    print(f"Source: {relative_posix(source_path, root)}")
    print(f"Manifest: {relative_posix(manifest_path, root)}")

    if empty_names:
        joined = ", ".join(empty_names)
        print(
            f"Warning: {len(empty_names)} cell(s) had no detected character "
            f"and were saved as fully transparent PNGs: {joined}. "
            "Inspect the source sheet and re-run with adjusted --bg-threshold/--alpha-threshold "
            "or regenerate the sheet.",
            file=sys.stderr,
        )

    if args.update_pubspec:
        changed = update_pubspec_assets(root, pet_id, config)
        if changed:
            print(
                f"Updated pubspec.yaml: added assets/pets/{pet_id}/{config.output_dir}/"
            )
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
