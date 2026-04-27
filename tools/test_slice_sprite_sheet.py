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


class SliceSpriteSheetTest(unittest.TestCase):
    def test_slices_action_sheet_to_named_default_256px_assets(self) -> None:
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
                    self.assertEqual(image.size, (256, 256))

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
                self.assertLessEqual(abs(left - (256 - right)), 1, output.name)
                self.assertLessEqual(max(right - left, bottom - top), 224, output.name)

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
                self.assertEqual(256 - bottom, 16, output.name)
                self.assertLessEqual(abs(left - (256 - right)), 1, output.name)

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
            self.assertLessEqual(opaque_color_count(output), 64)
            self.assertLessEqual(alpha_values(output), {0, 255})

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
                if channel_max - channel_min <= 24 and channel_min >= 235:
                    self.assertEqual((red, green, blue), (255, 255, 255))
                if channel_max - channel_min <= 24 and channel_max <= 84:
                    self.assertEqual((red, green, blue), (0, 0, 0))


if __name__ == "__main__":
    unittest.main()
