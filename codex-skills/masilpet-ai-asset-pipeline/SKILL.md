---
name: masilpet-ai-asset-pipeline
description: Use when creating MasilPet AI pet assets from a reference image or text concept, applying cute-first MasilPet prompt rules from MASILPET_AI_ASSET_PROMPTS.md, generating sprite sheets, saving generated images under assets/_incoming, slicing them into assets/pets/[pet_id] with tools/slice_sprite_sheet.py, validating the outputs, and committing/pushing the resulting Flutter asset folders.
---

# MasilPet AI Asset Pipeline

## Overview

Use this skill to run the full MasilPet asset flow: generate AI sprite-sheet images, store them in the incoming folder, slice them into game-ready 256x256 PNG assets, verify the result, and commit/push the repo changes when requested.

Work from the MasilPet repo root. The expected repo files are:

- `MASILPET_AI_ASSET_PROMPTS.md` for prompt patterns and style rules.
- `tools/slice_sprite_sheet.py` for slicing and cleanup.
- `tools/ASSET_PIPELINE.md` for current sheet layouts and CLI options.
- `assets/_incoming/[pet_id]/` for raw generated sheets.
- `assets/pets/[pet_id]/` for sliced app assets.

## Asset Scope

Choose a lowercase `pet_id` using letters, digits, underscores, or hyphens, for example `roof_mascot` or `wave_naru`.

Prefer one character family per generated image. Do not ask the image model to create multiple unrelated pets in one image. For quality, generate one sheet type at a time:

- `actions`: 2 x 3 sheet for `idle`, `walking`, `jumping`, `eating`, `sleeping`, `greeting`.
- `emotions`: 2 x 3 sheet for `neutral`, `happy`, `excited`, `sad`, `surprised`, `sleepy`.
- `growth`: 1 x 3 sheet for `baby`, `grown`, `evolved`.
- `idle_animation`, `walk_animation`, `sleep_animation`, `eat_animation`, `greet_animation`: each is a separate 1 x 4 frame sheet.

Current MVP guidance: keep `growth/` as static stage assets and use common animation sheets unless the user explicitly asks for stage-specific animation support. If stage-specific animation is requested, extend the slicing script and app asset lookup first.

## Prompting

Treat `MASILPET_AI_ASSET_PROMPTS.md` as the canonical source for prompt blocks and style rules. Read it before composing prompts when it exists. If this skill summary and that file disagree, follow `MASILPET_AI_ASSET_PROMPTS.md`.

If the user provides a reference image:

- Use the image as identity inspiration, not as an exact copy target.
- Preserve only the most recognizable motifs, representative colors, face-shape hints, symbolic features, and mascot personality.
- Prioritize a lovable chibi companion pet silhouette over strict reference fidelity.
- It is acceptable to round, shorten, shrink, enlarge, or simplify reference details if it makes the character cuter.
- Do not redesign it into a completely unrelated creature.

If there is no reference image:

- Ask for or infer the regional/location theme, motif, color direction, and personality.
- Prioritize an instantly lovable chibi pet silhouette over complex originality or detailed regional symbolism.
- Keep the design simple enough to remain readable as a compact mascot sprite.

Generation prompt rules:

- Ask for clean 2D pixel-art-style mobile game pet sprites, cute-first chibi redesign, head about 65% to 70% of total body height, extra-large rounded face, oversized dot eyes, tiny nose, tiny smiling mouth, short squat body, very tiny bean-shaped hands and feet, soft rounded cheeks, rounded accessories, thick dark outline, flat colors, limited bright cute palette, transparent or plain background, no text/logo/UI.
- It is acceptable for the prompt to say `64x64 pixel style` as a visual style cue, but the slicing pipeline exports 256x256 PNG files by default for cleaner app scaling.
- Include a negative prompt against realism, 3D, plush/clay render, vector illustration, watercolor, gradients, anti-aliasing, text, watermark, cropped body, inconsistent character, extra limbs, different character identities per frame, exact reference copy, narrow face, small eyes, long limbs, tall thin silhouette, stiff mascot pose, and mature proportions.
- For animation sheets, specify equal-sized frames in a single row, consistent feet position, consistent character size, and subtle motion only.

Use exact prompt blocks from `MASILPET_AI_ASSET_PROMPTS.md` when available, then tailor only the sheet contents, action/expression list, and reference/no-reference identity section.

## Save Generated Sheets

Create the incoming folder:

```powershell
New-Item -ItemType Directory -Force -Path assets\_incoming\[pet_id]
```

Save generated images using the standard names:

```text
assets/_incoming/[pet_id]/action_poses_sheet.png
assets/_incoming/[pet_id]/emotions_sheet.png
assets/_incoming/[pet_id]/growth_sheet.png
assets/_incoming/[pet_id]/idle_animation_sheet.png
assets/_incoming/[pet_id]/walk_animation_sheet.png
assets/_incoming/[pet_id]/sleep_animation_sheet.png
assets/_incoming/[pet_id]/eat_animation_sheet.png
assets/_incoming/[pet_id]/greet_animation_sheet.png
```

Only slice sheets that actually exist. Do not fabricate missing generated files.

## Slice Into App Assets

Run the slicer from the repo root. Defaults are 256x256 output, 224px fit size, 64 colors, hard alpha, background removal, character centering, and white/black key-color cleanup.

```powershell
$pet = "[pet_id]"
$sheets = @(
  @{ type = "actions"; file = "action_poses_sheet.png" },
  @{ type = "emotions"; file = "emotions_sheet.png" },
  @{ type = "growth"; file = "growth_sheet.png" },
  @{ type = "idle_animation"; file = "idle_animation_sheet.png" },
  @{ type = "walk_animation"; file = "walk_animation_sheet.png" },
  @{ type = "sleep_animation"; file = "sleep_animation_sheet.png" },
  @{ type = "eat_animation"; file = "eat_animation_sheet.png" },
  @{ type = "greet_animation"; file = "greet_animation_sheet.png" }
)
foreach ($sheet in $sheets) {
  $inputPath = Join-Path "assets\_incoming\$pet" $sheet.file
  if (Test-Path -LiteralPath $inputPath) {
    python tools\slice_sprite_sheet.py --pet-id $pet --sheet-type $sheet.type --input $inputPath --overwrite
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}
```

For stronger outline/white cleanup, add:

```powershell
--white-threshold 228 --black-threshold 88 --snap-neutral-tolerance 28
```

For direct 128x128 export only when needed:

```powershell
--output-size 128 --fit-size 112 --palette-colors 48 --bottom-padding 8
```

## Verify

Check the generated structure:

```text
assets/pets/[pet_id]/actions/*.png       expected 6 when actions sheet exists
assets/pets/[pet_id]/emotions/*.png      expected 6 when emotions sheet exists
assets/pets/[pet_id]/growth/*.png        expected 3 when growth sheet exists
assets/pets/[pet_id]/animations/*.png    expected 4 per animation sheet
assets/pets/[pet_id]/source/*.png        source sheet copies
assets/pets/[pet_id]/manifest.json
```

Inspect at least one action and one animation output with `view_image` when available. Numeric checks should confirm:

- PNG size is 256x256 unless intentionally overridden.
- Alpha values are hard `{0, 255}`.
- Character bbox is centered for actions/emotions/growth.
- Animation frames use a consistent bottom/feet anchor.
- Near-white and near-black neutral colors were snapped to `#ffffff` and `#000000` when cleanup is enabled.

If `tools/slice_sprite_sheet.py` changed, run:

```powershell
python -m unittest discover -s tools -p "test_*.py"
```

Flutter note: if a new pet is meant to be loaded in-app, add its asset folders to `pubspec.yaml`. Include `actions/`, `emotions/`, `growth/`, and `animations/` if animations are used.

## Commit And Push

Before committing, review the staged scope:

```powershell
git status --short --branch
git diff --stat
```

For source and generated assets, include:

```powershell
git add -- assets/_incoming/[pet_id] assets/pets/[pet_id]
```

If code, prompts, guides, or pubspec changed, add those files explicitly. Use a Korean commit message consistent with the repo history. Push only when the user asks for GitHub/remote upload:

```powershell
git commit -m "AI 에셋 파이프라인 산출물 추가"
git push origin main
```
