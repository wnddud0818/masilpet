import importlib.util
import json
import shutil
import sys
import unittest
import uuid
from pathlib import Path

from PIL import Image, ImageDraw


MODULE_PATH = Path(__file__).with_name("slice_sprite_sheet.py")
SPEC = importlib.util.spec_from_file_location("slice_sprite_sheet", MODULE_PATH)
slice_sprite_sheet = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = slice_sprite_sheet
SPEC.loader.exec_module(slice_sprite_sheet)


class TemporaryProject:
    def __enter__(self) -> str:
        temp_root = Path.cwd() / "build" / "asset_pipeline_tests"
        temp_root.mkdir(parents=True, exist_ok=True)
        self.path = temp_root / f"case_{uuid.uuid4().hex}"
        self.path.mkdir(parents=True)
        return str(self.path)

    def __exit__(self, exc_type, exc, traceback) -> None:
        shutil.rmtree(self.path, ignore_errors=True)


def temporary_project() -> TemporaryProject:
    return TemporaryProject()


def make_sheet(path: Path, rows: int, cols: int, cell_size: int = 12) -> None:
    image = Image.new("RGBA", (cols * cell_size, rows * cell_size), (0, 0, 0, 0))
    colors = [
        (255, 0, 0, 255),
        (0, 255, 0, 255),
        (0, 0, 255, 255),
        (255, 255, 0, 255),
        (255, 0, 255, 255),
        (0, 255, 255, 255),
        (128, 0, 0, 255),
        (0, 128, 0, 255),
        (0, 0, 128, 255),
        (128, 128, 0, 255),
        (128, 0, 128, 255),
        (0, 128, 128, 255),
    ]
    for index in range(rows * cols):
        row = index // cols
        col = index % cols
        block = Image.new("RGBA", (cell_size, cell_size), colors[index])
        image.paste(block, (col * cell_size, row * cell_size))
    image.save(path)


def make_offset_subject_sheet(path: Path, rows: int, cols: int, cell_size: int = 80) -> None:
    image = Image.new("RGBA", (cols * cell_size, rows * cell_size), (250, 250, 250, 255))
    draw = ImageDraw.Draw(image)
    colors = [
        (255, 80, 80, 255),
        (80, 200, 80, 255),
        (80, 120, 255, 255),
        (245, 200, 80, 255),
        (210, 100, 245, 255),
        (80, 220, 220, 255),
        (180, 90, 60, 255),
        (60, 160, 120, 255),
    ]
    offsets = [
        (6, 8),
        (24, 8),
        (12, 20),
        (28, 18),
        (4, 28),
        (22, 26),
        (16, 12),
        (8, 22),
    ]
    for index in range(rows * cols):
        row = index // cols
        col = index % cols
        x_offset, y_offset = offsets[index % len(offsets)]
        x0 = col * cell_size + x_offset
        y0 = row * cell_size + y_offset
        x1 = x0 + 38
        y1 = y0 + 42
        draw.rounded_rectangle(
            (x0, y0, x1, y1),
            radius=10,
            fill=colors[index % len(colors)],
            outline=(45, 35, 30, 255),
            width=2,
        )
    image.save(path)


def make_gradient_subject_sheet(path: Path, rows: int, cols: int, cell_size: int = 80) -> None:
    image = Image.new("RGBA", (cols * cell_size, rows * cell_size), (250, 250, 250, 255))
    pixels = image.load()
    for index in range(rows * cols):
        row = index // cols
        col = index % cols
        for y in range(18, 58):
            for x in range(16, 56):
                if (x - 36) * (x - 36) + (y - 38) * (y - 38) > 20 * 20:
                    continue
                px = col * cell_size + x
                py = row * cell_size + y
                pixels[px, py] = (
                    40 + (x * 3) % 180,
                    80 + (y * 4) % 140,
                    120 + ((x + y) * 2) % 100,
                    255,
                )
    image.save(path)


def make_key_color_sheet(path: Path, rows: int, cols: int, cell_size: int = 80) -> None:
    image = Image.new("RGBA", (cols * cell_size, rows * cell_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for index in range(rows * cols):
        row = index // cols
        col = index % cols
        x0 = col * cell_size + 16
        y0 = row * cell_size + 14
        x1 = col * cell_size + 62
        y1 = row * cell_size + 64
        draw.rounded_rectangle(
            (x0, y0, x1, y1),
            radius=14,
            fill=(242, 244, 246, 255),
            outline=(26, 27, 29, 255),
            width=5,
        )
        draw.ellipse((x0 + 14, y0 + 16, x0 + 22, y0 + 24), fill=(18, 19, 20, 255))
        draw.ellipse((x0 + 30, y0 + 16, x0 + 38, y0 + 24), fill=(18, 19, 20, 255))
    image.save(path)


def make_stray_component_sheet(
    path: Path,
    rows: int,
    cols: int,
    cell_size: int = 120,
) -> None:
    image = Image.new(
        "RGBA",
        (cols * cell_size, rows * cell_size),
        (250, 250, 250, 255),
    )
    draw = ImageDraw.Draw(image)
    for row in range(rows):
        for col in range(cols):
            origin_x = col * cell_size
            origin_y = row * cell_size
            draw.rounded_rectangle(
                (origin_x + 32, origin_y + 24, origin_x + 94, origin_y + 102),
                radius=18,
                fill=(220, 120, 80, 255),
                outline=(35, 30, 45, 255),
                width=4,
            )
            draw.rectangle(
                (origin_x, origin_y + 52, origin_x + 2, origin_y + 65),
                fill=(60, 90, 120, 255),
            )
    image.save(path)


def make_light_subject_with_outline_gap_sheet(
    path: Path,
    rows: int,
    cols: int,
    cell_size: int = 120,
) -> None:
    image = Image.new(
        "RGBA",
        (cols * cell_size, rows * cell_size),
        (255, 255, 255, 255),
    )
    draw = ImageDraw.Draw(image)
    for row in range(rows):
        for col in range(cols):
            origin_x = col * cell_size
            origin_y = row * cell_size
            draw.ellipse(
                (origin_x + 24, origin_y + 18, origin_x + 96, origin_y + 104),
                fill=(255, 255, 255, 255),
                outline=(25, 35, 55, 255),
                width=6,
            )
            # Simulate a small AI-generated break in the dark outer outline.
            draw.rectangle(
                (origin_x + 59, origin_y + 17, origin_x + 61, origin_y + 26),
                fill=(255, 255, 255, 255),
            )
            draw.ellipse(
                (origin_x + 45, origin_y + 48, origin_x + 53, origin_y + 56),
                fill=(25, 35, 55, 255),
            )
            draw.ellipse(
                (origin_x + 67, origin_y + 48, origin_x + 75, origin_y + 56),
                fill=(25, 35, 55, 255),
            )
    image.save(path)


def alpha_bbox(path: Path) -> tuple[int, int, int, int]:
    with Image.open(path).convert("RGBA") as image:
        bbox = image.getchannel("A").getbbox()
    assert bbox is not None
    return bbox


def opaque_color_count(path: Path) -> int:
    with Image.open(path).convert("RGBA") as image:
        data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
        colors = {
            (red, green, blue)
            for red, green, blue, alpha in data
            if alpha > 0
        }
    return len(colors)


def opaque_colors(path: Path) -> set[tuple[int, int, int]]:
    with Image.open(path).convert("RGBA") as image:
        data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
        return {
            (red, green, blue)
            for red, green, blue, alpha in data
            if alpha > 0
        }


def alpha_values(path: Path) -> set[int]:
    with Image.open(path).convert("RGBA") as image:
        alpha = image.getchannel("A")
        data = alpha.get_flattened_data() if hasattr(alpha, "get_flattened_data") else alpha.getdata()
        return set(data)


def alpha_component_count(path: Path) -> int:
    with Image.open(path).convert("RGBA") as image:
        alpha = image.getchannel("A")
        pixels = alpha.load()
        width, height = alpha.size
        visited = bytearray(width * height)
        components = 0
        for y in range(height):
            for x in range(width):
                start = y * width + x
                if visited[start] or pixels[x, y] == 0:
                    continue
                components += 1
                visited[start] = 1
                queue = [(x, y)]
                while queue:
                    current_x, current_y = queue.pop()
                    for next_x, next_y in (
                        (current_x - 1, current_y),
                        (current_x + 1, current_y),
                        (current_x, current_y - 1),
                        (current_x, current_y + 1),
                    ):
                        if not (0 <= next_x < width and 0 <= next_y < height):
                            continue
                        offset = next_y * width + next_x
                        if visited[offset] or pixels[next_x, next_y] == 0:
                            continue
                        visited[offset] = 1
                        queue.append((next_x, next_y))
        return components


def matches_pixel_grid(path: Path, grid_size: int) -> bool:
    with Image.open(path).convert("RGBA") as image:
        if image.width != image.height or image.width % grid_size != 0:
            return False
        scale = image.width // grid_size
        pixels = image.load()
        for y in range(0, image.height, scale):
            for x in range(0, image.width, scale):
                color = pixels[x, y]
                for dy in range(scale):
                    for dx in range(scale):
                        if pixels[x + dx, y + dy] != color:
                            return False
    return True


class SliceSpriteSheetTest(unittest.TestCase):
    def test_slices_action_sheet_to_named_default_512px_assets(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "action_poses_sheet.png"
            make_sheet(input_path, rows=2, cols=3)

            exit_code = slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "actions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                ]
            )

            self.assertEqual(exit_code, 0)
            expected = ["idle", "walking", "jumping", "eating", "sleeping", "greeting"]
            for name in expected:
                output = root / "assets" / "pets" / "roof_mascot" / "actions" / f"{name}.png"
                self.assertTrue(output.exists(), output)
                with Image.open(output) as image:
                    self.assertEqual(image.size, (512, 512))

            manifest = json.loads(
                (root / "assets" / "pets" / "roof_mascot" / "manifest.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(manifest["petId"], "roof_mascot")
            self.assertEqual(
                manifest["sourceSheets"]["actions"],
                "assets/pets/roof_mascot/source/action_poses_sheet.png",
            )
            self.assertEqual(len(manifest["assets"]["actions"]), 6)

    def test_growth_sheet_matches_current_flutter_stage_names(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "growth_sheet.png"
            make_sheet(input_path, rows=1, cols=3)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "wave_naru",
                    "--sheet-type",
                    "growth",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                ]
            )

            growth_dir = root / "assets" / "pets" / "wave_naru" / "growth"
            self.assertTrue((growth_dir / "baby.png").exists())
            self.assertTrue((growth_dir / "grown.png").exists())
            self.assertTrue((growth_dir / "evolved.png").exists())

    def test_refuses_to_overwrite_without_flag(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "emotions_sheet.png"
            make_sheet(input_path, rows=2, cols=3)
            args = [
                "--pet-id",
                "story_goun",
                "--sheet-type",
                "emotions",
                "--input",
                str(input_path),
                "--root",
                str(root),
            ]

            slice_sprite_sheet.run(args)

            with self.assertRaises(FileExistsError):
                slice_sprite_sheet.run(args)

            exit_code = slice_sprite_sheet.run([*args, "--overwrite"])
            self.assertEqual(exit_code, 0)

    def test_animation_manifest_entries_are_merged(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            idle_sheet = root / "idle_animation_sheet.png"
            walk_sheet = root / "walk_animation_sheet.png"
            make_sheet(idle_sheet, rows=1, cols=4)
            make_sheet(walk_sheet, rows=1, cols=4)

            common_args = ["--pet-id", "roof_mascot", "--root", str(root)]
            slice_sprite_sheet.run(
                [
                    *common_args,
                    "--sheet-type",
                    "idle_animation",
                    "--input",
                    str(idle_sheet),
                ]
            )
            slice_sprite_sheet.run(
                [
                    *common_args,
                    "--sheet-type",
                    "walk_animation",
                    "--input",
                    str(walk_sheet),
                ]
            )

            manifest = json.loads(
                (root / "assets" / "pets" / "roof_mascot" / "manifest.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(len(manifest["assets"]["animations"]), 8)
            self.assertIn(
                "assets/pets/roof_mascot/animations/idle_01.png",
                manifest["assets"]["animations"],
            )
            self.assertIn(
                "assets/pets/roof_mascot/animations/walk_04.png",
                manifest["assets"]["animations"],
            )

    def test_removes_background_and_centers_offset_subjects(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "action_poses_sheet.png"
            make_offset_subject_sheet(input_path, rows=2, cols=3)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "actions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                ]
            )

            actions_dir = root / "assets" / "pets" / "roof_mascot" / "actions"
            for output in sorted(actions_dir.glob("*.png")):
                with Image.open(output).convert("RGBA") as image:
                    self.assertEqual(image.getpixel((0, 0))[3], 0)
                left, top, right, bottom = alpha_bbox(output)
                self.assertLessEqual(abs(left - (512 - right)), 1, output.name)
                self.assertLessEqual(max(right - left, bottom - top), 448, output.name)

    def test_animation_frames_use_feet_anchor(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "idle_animation_sheet.png"
            make_offset_subject_sheet(input_path, rows=1, cols=4)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "idle_animation",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                ]
            )

            animations_dir = root / "assets" / "pets" / "roof_mascot" / "animations"
            for output in sorted(animations_dir.glob("idle_*.png")):
                left, top, right, bottom = alpha_bbox(output)
                self.assertEqual(512 - bottom, 32, output.name)
                self.assertLessEqual(abs(left - (512 - right)), 1, output.name)

    def test_quantizes_colors_and_hardens_alpha(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "emotions_sheet.png"
            make_gradient_subject_sheet(input_path, rows=2, cols=3)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "emotions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                ]
            )

            output = root / "assets" / "pets" / "roof_mascot" / "emotions" / "neutral.png"
            self.assertLessEqual(opaque_color_count(output), 48)
            self.assertLessEqual(alpha_values(output), {0, 255})

    def test_strict_pixel_art_rebuilds_on_128px_grid(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "emotions_sheet.png"
            make_gradient_subject_sheet(input_path, rows=2, cols=3, cell_size=120)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "emotions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                    "--strict-pixel-art",
                ]
            )

            output = root / "assets" / "pets" / "roof_mascot" / "emotions" / "neutral.png"
            with Image.open(output) as image:
                self.assertEqual(image.size, (512, 512))
            self.assertTrue(matches_pixel_grid(output, 128))
            self.assertLessEqual(opaque_color_count(output), 20)
            self.assertLessEqual(alpha_values(output), {0, 255})

    def test_strict_pixel_art_removes_tiny_distant_cell_fragments(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "action_poses_sheet.png"
            make_stray_component_sheet(input_path, rows=2, cols=3)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "actions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                    "--strict-pixel-art",
                    "--pixel-grid-size",
                    "64",
                ]
            )

            output = root / "assets" / "pets" / "roof_mascot" / "actions" / "idle.png"
            self.assertEqual(alpha_component_count(output), 1)
            manifest = json.loads(
                (root / "assets" / "pets" / "roof_mascot" / "manifest.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertTrue(
                manifest["history"]["actions"]["options"]["removeStrayComponents"]
            )

    def test_background_only_preserves_source_colors_and_resolution(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "emotions_sheet.png"
            make_gradient_subject_sheet(input_path, rows=2, cols=3, cell_size=120)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "emotions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                    "--background-only",
                ]
            )

            output = root / "assets" / "pets" / "roof_mascot" / "emotions" / "neutral.png"
            with Image.open(output) as image:
                self.assertEqual(image.size, (512, 512))
            self.assertGreater(opaque_color_count(output), 48)

            manifest = json.loads(
                (root / "assets" / "pets" / "roof_mascot" / "manifest.json").read_text(
                    encoding="utf-8"
                )
            )
            options = manifest["history"]["emotions"]["options"]
            self.assertTrue(options["backgroundOnly"])
            self.assertTrue(options["noQuantize"])
            self.assertTrue(options["noColorSnap"])
            self.assertTrue(options["removeStrayComponents"])
            self.assertTrue(options["protectEnclosedRegions"])
            self.assertEqual(
                options["bgThreshold"],
                slice_sprite_sheet.DEFAULT_BACKGROUND_ONLY_BG_THRESHOLD,
            )
            self.assertEqual(options["pixelGridSize"], 0)
            self.assertFalse(options["rebuildOutline"])

    def test_background_only_protects_light_interior_through_outline_gap(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "emotions_sheet.png"
            make_light_subject_with_outline_gap_sheet(input_path, rows=2, cols=3)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "emotions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                    "--background-only",
                ]
            )

            output = root / "assets" / "pets" / "roof_mascot" / "emotions" / "neutral.png"
            with Image.open(output).convert("RGBA") as image:
                self.assertGreater(image.getpixel((256, 256))[3], 0)

    def test_pixel_grid_size_must_evenly_scale_output(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "emotions_sheet.png"
            make_gradient_subject_sheet(input_path, rows=2, cols=3)

            with self.assertRaises(ValueError):
                slice_sprite_sheet.run(
                    [
                        "--pet-id",
                        "roof_mascot",
                        "--sheet-type",
                        "emotions",
                        "--input",
                        str(input_path),
                        "--root",
                        str(root),
                        "--pixel-grid-size",
                        "48",
                    ]
                )

    def test_supports_smaller_output_size_when_explicitly_requested(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "action_poses_sheet.png"
            make_offset_subject_sheet(input_path, rows=2, cols=3, cell_size=120)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "actions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                    "--output-size",
                    "128",
                    "--fit-size",
                    "112",
                    "--palette-colors",
                    "48",
                    "--bottom-padding",
                    "8",
                ]
            )

            output = root / "assets" / "pets" / "roof_mascot" / "actions" / "idle.png"
            with Image.open(output).convert("RGBA") as image:
                self.assertEqual(image.size, (128, 128))
                self.assertEqual(image.getpixel((0, 0))[3], 0)
            left, top, right, bottom = alpha_bbox(output)
            self.assertLessEqual(abs(left - (128 - right)), 1)
            self.assertLessEqual(max(right - left, bottom - top), 112)
            self.assertLessEqual(opaque_color_count(output), 48)

    def test_warns_when_a_cell_has_no_detected_character(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "emotions_sheet.png"
            make_offset_subject_sheet(input_path, rows=2, cols=3)
            with Image.open(input_path).convert("RGBA") as image:
                blank_cell = Image.new(
                    "RGBA", (image.width // 3, image.height // 2), (250, 250, 250, 255)
                )
                image.paste(blank_cell, (0, 0))
                image.save(input_path)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "emotions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                ]
            )

            manifest = json.loads(
                (root / "assets" / "pets" / "roof_mascot" / "manifest.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertIn("history", manifest)
            history = manifest["history"]["emotions"]
            self.assertIn("neutral", history["emptyCells"])
            self.assertEqual(
                history["options"]["paletteColors"],
                slice_sprite_sheet.DEFAULT_PALETTE_COLORS,
            )
            self.assertIn("sourceHash", history)
            self.assertEqual(len(history["sourceHash"]), 64)

    def test_shared_palette_is_consistent_across_sheet_cells(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "emotions_sheet.png"
            make_gradient_subject_sheet(input_path, rows=2, cols=3)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "emotions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                    "--palette-colors",
                    "16",
                ]
            )

            emotions_dir = root / "assets" / "pets" / "roof_mascot" / "emotions"
            cell_palettes = [
                opaque_colors(path) for path in sorted(emotions_dir.glob("*.png"))
            ]
            union = set().union(*cell_palettes)
            # Shared palette: union should not exceed the requested cap.
            self.assertLessEqual(len(union), 16)

    def test_per_cell_palette_flag_disables_shared_palette(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "emotions_sheet.png"
            make_gradient_subject_sheet(input_path, rows=2, cols=3)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "emotions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                    "--per-cell-palette",
                    "--palette-colors",
                    "16",
                ]
            )

            manifest = json.loads(
                (root / "assets" / "pets" / "roof_mascot" / "manifest.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertTrue(
                manifest["history"]["emotions"]["options"]["perCellPalette"]
            )

    def test_preview_writes_guide_image_and_skips_assets(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "action_poses_sheet.png"
            make_offset_subject_sheet(input_path, rows=2, cols=3)
            preview_path = root / "preview.png"

            exit_code = slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "actions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                    "--preview",
                    str(preview_path),
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertTrue(preview_path.exists())
            self.assertFalse(
                (root / "assets" / "pets" / "roof_mascot").exists(),
                "preview mode must not produce app assets",
            )

    def test_snaps_neutral_near_white_and_near_black_pixels(self) -> None:
        with temporary_project() as tmp:
            root = Path(tmp)
            input_path = root / "action_poses_sheet.png"
            make_key_color_sheet(input_path, rows=2, cols=3)

            slice_sprite_sheet.run(
                [
                    "--pet-id",
                    "roof_mascot",
                    "--sheet-type",
                    "actions",
                    "--input",
                    str(input_path),
                    "--root",
                    str(root),
                ]
            )

            output = root / "assets" / "pets" / "roof_mascot" / "actions" / "idle.png"
            colors = opaque_colors(output)
            self.assertIn((255, 255, 255), colors)
            self.assertIn((0, 0, 0), colors)
            for red, green, blue in colors:
                channel_min = min(red, green, blue)
                channel_max = max(red, green, blue)
                if channel_max - channel_min <= 28 and channel_min >= 228:
                    self.assertEqual((red, green, blue), (255, 255, 255))
                if channel_max - channel_min <= 28 and channel_max <= 88:
                    self.assertEqual((red, green, blue), (0, 0, 0))


if __name__ == "__main__":
    unittest.main()
