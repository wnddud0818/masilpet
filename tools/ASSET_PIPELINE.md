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

The script copies the source sheet to `assets/pets/[pet_id]/source/`, writes normalized PNG outputs, and updates `assets/pets/[pet_id]/manifest.json`. The manifest also records `slicerVersion`, a per-sheet `sourceHash` (sha256), the slicer options used, and any empty-cell warnings under `history.[sheet_type]`. The default output is 512x512 so AI-generated line detail survives cleanup and later in-app scaling.

## Post-Processing

The default pipeline operates **across the whole sheet** for color consistency:

1. Slice all equal-sized grid cells from the source sheet.
2. For each cell: detect the edge-connected background color, remove it, crop to the character bbox.
   In strict pixel-art mode, tiny disconnected fragments far from the main subject are removed automatically so neighboring-cell spill does not survive slicing.
3. Resize each character to fit inside a 448x448 box by default.
4. Build a single shared palette across all non-empty cells and quantize every cell to it (48 colors, hard alpha).
5. Snap neutral near-white and near-black pixels to pure white and pure black.
6. Place each cell on a 512x512 transparent canvas with consistent anchoring.
7. Empty cells (no character detected) are saved as fully transparent PNGs and reported on stderr + in `manifest.history.[sheet_type].emptyCells`.

Default placement:

- `actions`, `emotions`, `growth`, and `evolution` use centered placement.
- Animation sheets use feet placement with 32px bottom padding **and horizontal centroid alignment** so the character's visual mass center stays at the canvas center across all 4 frames, reducing loop jitter.

Useful options:

```powershell
--output-size 512      # final PNG canvas size
--fit-size 448         # max character size inside the 512x512 canvas
--anchor center        # force center placement
--anchor feet          # force foot/bottom placement
--bottom-padding 32    # bottom padding for feet placement
--bg-threshold 180     # background removal tolerance
--background-only      # preserve source detail/colors; remove background + normalize canvas only
--palette-colors 48    # max opaque colors after quantization
--strict-pixel-art     # 128px grid, tighter palette, outline rebuild, stray-fragment cleanup
--remove-stray-components # remove tiny distant foreground fragments without strict mode
--keep-stray-components   # preserve every detached fragment in strict mode
--pixel-grid-size 128  # optional low-res pixel grid before nearest-neighbor upscaling
--posterize-bits 3     # reduce channel precision for flatter pixel-art colors
--rebuild-outline      # add a hard outline around the normalized alpha mask
--white-threshold 228  # snap neutral near-white colors to #ffffff
--black-threshold 88   # snap neutral near-black colors to #000000
--no-color-snap        # disable white/black cleanup
--keep-background      # disable background removal and centering
--no-quantize          # keep resized colors instead of reducing palette
--per-cell-palette     # quantize each cell separately (default is sheet-wide shared palette)
--no-centroid-align    # disable horizontal centroid alignment for animation frames
--update-pubspec       # auto-add the new asset folder under flutter.assets in pubspec.yaml
--preview path.png     # write a numbered cell-guide preview PNG and exit (no app assets)
--overwrite            # replace existing output files
```

For normal app assets, the defaults are enough:

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png
```

For AI-generated sheets that already have the intended pixel detail and palette, prefer background-only mode. It keeps the original colors and source resolution, removes only the edge-connected background, protects light face/body interiors behind imperfect outlines, removes tiny neighboring-cell fragments, and normalizes the result onto the app canvas:

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png --background-only --overwrite
```

Background-only mode uses separate thresholds for removal and protection: near-white exterior pixels can be removed with the normal `180` tolerance, while pixels more than `12` RGB-distance units from the sampled background form a protective barrier. A small outline closing step prevents background flood-fill from leaking into a light face or body through minor outline gaps.

For AI-generated pixel art that still has soft edges or uneven pseudo-pixels, use strict pixel-art mode only when a deliberately chunkier, reduced-palette result is desired. This rebuilds each sprite on a 128x128 logical pixel canvas, snaps alpha harder, reduces the palette, posterizes soft gradients, rebuilds a crisp outline, and nearest-neighbor upscales to the final 512x512 PNG:

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png --strict-pixel-art --overwrite
```

For a chunkier 64x64-style result, override the grid:

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png --strict-pixel-art --pixel-grid-size 64 --overwrite
```

For stronger white/black edge cleanup, keep 512x512 and tighten key-color snapping:

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png --white-threshold 228 --black-threshold 88 --snap-neutral-tolerance 28
```

This preserves more generated detail, then forces only low-saturation off-white and off-black edge pixels to exact white/black. Colored dark regions such as blue roof shadows are protected by `--snap-neutral-tolerance`.

For very small UI slots, generate 512x512 first and let the app scale down. Only export 256x256 or 128x128 directly when file size is more important than preserving edge detail:

```powershell
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png --output-size 256 --fit-size 224 --palette-colors 48 --bottom-padding 16
python tools/slice_sprite_sheet.py --pet-id roof_mascot --sheet-type actions --input assets/_incoming/roof_mascot/action_poses_sheet.png --output-size 128 --fit-size 112 --palette-colors 48 --bottom-padding 8
```

If the generated sheet has strong shadows, off-white panels, or background artifacts connected to the character, increase or decrease `--bg-threshold` and re-run with `--overwrite`.
