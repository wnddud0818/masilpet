# MasilPet Asset Slicing Pipeline

Generated sprite sheets should be reviewed by a person first, then placed under `assets/_incoming/[pet_id]/` and sliced with `tools/slice_sprite_sheet.py`.

Requires Python with Pillow installed.

## Examples

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type emotions --input assets/_incoming/roof_mascot/emotions_sheet.png
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type growth --input assets/_incoming/roof_mascot/growth_sheet.png
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type idle_animation --input assets/_incoming/roof_mascot/idle_animation_sheet.png
```

Use `--overwrite` only after checking that replacing existing assets is intended.

## Sheet Types

| Sheet type | Layout | Output files |
| --- | --- | --- |
| `actions` | 2 x 3 | `actions/idle.png`, `walking.png`, `jumping.png`, `eating.png`, `sleeping.png`, `greeting.png` |
| `emotions` | 2 x 3 | `emotions/neutral.png`, `happy.png`, `excited.png`, `sad.png`, `surprised.png`, `sleepy.png` |
| `emotions12` | 3 x 4 | 12 named emotion files |
| `growth` | 1 x 3 | `growth/baby.png`, `grown.png`, `evolved.png` |
| `evolution` | 1 x 3 | `growth/egg.png`, `baby.png`, `evolved.png` |
| `idle_animation` | 1 x 4 | `animations/idle_01.png` to `idle_04.png` |
| `walk_animation` | 1 x 4 | `animations/walk_01.png` to `walk_04.png` |
| `sleep_animation` | 1 x 4 | `animations/sleep_01.png` to `sleep_04.png` |
| `eat_animation` | 1 x 4 | `animations/eat_01.png` to `eat_04.png` |
| `greet_animation` | 1 x 4 | `animations/greet_01.png` to `greet_04.png` |

The script copies the source sheet to `assets/pets/[pet_id]/source/`, writes normalized PNG outputs, and updates `assets/pets/[pet_id]/manifest.json`. The default output is 256x256 so AI-generated line detail survives cleanup and later in-app scaling.

## Post-Processing

By default, each cell goes through this normalization pipeline:

1. Slice one equal-sized grid cell from the source sheet.
2. Detect the edge-connected background color.
3. Remove that background and keep only the character foreground.
4. Crop to the detected character bbox.
5. Resize the character to fit inside a 224x224 box by default.
6. Reduce the sprite to a 64 color flat palette with hard alpha.
7. Snap neutral near-white and near-black pixels to pure white and pure black.
8. Place it on a 256x256 transparent canvas by default.

Default placement:

- `actions`, `emotions`, `growth`, and `evolution` use centered placement.
- Animation sheets use feet placement with 16px bottom padding to reduce frame jitter.

Useful options:

```powershell
--output-size 256      # final PNG canvas size
--fit-size 224         # max character size inside the 256x256 canvas
--anchor center        # force center placement
--anchor feet          # force foot/bottom placement
--bottom-padding 16    # bottom padding for feet placement
--bg-threshold 36      # background removal tolerance
--palette-colors 64    # max opaque colors after quantization
--white-threshold 235  # snap neutral near-white colors to #ffffff
--black-threshold 84   # snap neutral near-black colors to #000000
--no-color-snap        # disable white/black cleanup
--keep-background      # disable background removal and centering
--no-quantize          # keep resized colors instead of reducing palette
--overwrite            # replace existing output files
```

For normal app assets, the defaults are enough:

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png
```

For stronger white/black edge cleanup, keep 256x256 and tighten key-color snapping:

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png --white-threshold 228 --black-threshold 88 --snap-neutral-tolerance 28
```

This preserves more generated detail, then forces only low-saturation off-white and off-black edge pixels to exact white/black. Colored dark regions such as blue roof shadows are protected by `--snap-neutral-tolerance`.

For very small UI slots, generate 256x256 first and let the app scale down. Only export 128x128 directly when file size is more important than preserving edge detail:

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png --output-size 128 --fit-size 112 --palette-colors 48 --bottom-padding 8
```

If the generated sheet has strong shadows, off-white panels, or background artifacts connected to the character, increase or decrease `--bg-threshold` and re-run with `--overwrite`.
