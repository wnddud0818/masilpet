# MasilPet AI Asset Prompt Guide

마실펫의 AI 에셋은 런타임 생성보다 **캐릭터별 기준 이미지를 고정한 뒤 감정, 상태, 성장 스프라이트를 사전 생성**하는 방식이 적합하다. 이 방식은 캐릭터 일관성, 앱 번들 관리, 운영비 측면에서 안정적이다.

## 핵심 원칙

- 한 번에 여러 에셋을 생성할 수 있지만, 품질 유지를 위해 **한 캐릭터의 파생 상태 묶음**으로 제한한다.
- 서로 다른 마실펫 여러 종을 한 번에 최종본으로 뽑으면 형태와 스타일 일관성이 떨어질 수 있다.
- 최종 에셋은 `기준 캐릭터 1장 -> 감정 6종 -> 추가 감정 6종 -> 성장 3단계 -> 행동 대표 포즈 6종 -> 핵심 애니메이션 프레임 시트` 순서로 나누는 것을 권장한다.
- 애니메이션은 모든 행동을 한 장에 몰아넣지 않고, `idle`, `walk`, `sleep`처럼 행동 하나당 1행 4프레임 시트로 분리한다.
- 지자체 마스코트나 공공누리 캐릭터를 사용할 때는 텍스트, 로고, 공식 마크를 복제하지 않는다.

## 권장 묶음 크기

| 에셋 유형 | 권장 생성 단위 | 최대 권장 |
| --- | ---: | ---: |
| 감정표현 | 6개 | 12개 |
| 성장 단계 | 3개 | 3개 |
| 행동 대표 포즈 | 6개 | 6개 |
| 단일 애니메이션 프레임 시트 | 4프레임 | 6프레임 |
| 아이템, 먹이, 장식 | 9~16개 | 16개 |
| 서로 다른 마실펫 캐릭터 | 1~2종 | 컨셉 시안 4종 |

## 공통 스타일 프롬프트

```text
Create a cute collectible companion pet character for a mobile location-based tourism game called MasilPet.
Style: clean cute actual 64x64 low-resolution pixel art sprite, Korean regional mascot-inspired, warm and friendly, cute-first chibi redesign, head takes about 65% to 70% of total body height, extra-large rounded face, oversized dot eyes, tiny nose, tiny gentle smile, smaller compact body, short squat limbs, tiny bean-shaped hands and feet, round soft silhouette, soft rounded cheeks with subtle blush-like color accents, simplified rounded accessories, simple readable silhouette, thick 1 pixel dark outline at 64x64 scale, limited palette of 16 to 24 colors, flat colors only, visible square pixels, stair-stepped pixel edges, no gradients, no anti-aliasing, no smooth curves, no subpixel lines, no painterly or vector smoothing, no pixel-art filter over a high-resolution illustration, clear cute facial expression, no text, no logo, transparent background, centered character, full body, game-ready asset. If the final image is larger than 64x64 per sprite, upscale only with nearest-neighbor so the blocky 64x64 pixel structure remains visible.
```

## 공통 캐릭터 정체성 규칙

레퍼런스가 있는 경우에는 귀엽게 바꾸더라도 원본이 다른 캐릭터로 재설계되지 않도록 아래 규칙을 함께 넣는다.

```text
Character identity rules:
- use the provided reference image as identity inspiration, not as an exact copy target
- preserve only the most recognizable motifs, representative colors, face shape hints, and symbolic features
- it is acceptable to round, shorten, shrink, enlarge, or simplify reference details if it makes the character cuter
- prioritize a lovable companion pet silhouette over strict reference fidelity
- preserve the character's cute mascot feeling
- do not redesign the character into a completely unrelated creature
- simplify details so it works as a 64x64 pixel game sprite
```

## 공통 귀여움 스타일 규칙

각 프롬프트에 아래 규칙을 함께 넣으면 캐릭터가 지나치게 성숙하거나 길쭉하게 변하는 것을 줄일 수 있다.

```text
Cute style rules:
- cute-first redesign: make the character noticeably cuter than the reference, even if exact source fidelity is reduced
- soft mascot-like cute proportions, not fabric or 3D plush material
- baby chibi proportions
- head takes about 65% to 70% of total body height
- extra-large rounded face with oversized dot eyes
- tiny nose and tiny smiling mouth
- smaller compact body, short and squat
- very tiny bean-shaped hands and feet
- soft rounded cheeks with subtle blush-like color accents
- gentle happy expression by default
- simplified accessories or tail if the character has one, made shorter, rounder, and cuter
- limited bright cute color palette, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions
```

## 공통 픽셀아트 규칙

아래 규칙은 생성 결과가 부드러운 일러스트나 벡터풍으로 흐르는 것을 막고, 앱에서 자르기 쉬운 게임 에셋에 가깝게 만든다.

```text
Pixel art rules:
- actual low-resolution 64x64 pixel art for each character sprite, not a high-resolution illustration
- draw every sprite as if it was hand-placed on a 64x64 pixel canvas first
- visible square pixels and clearly stair-stepped/jagged pixel edges
- if the output image is larger than 64x64 per sprite, it must look nearest-neighbor upscaled from 64x64
- thick 1 pixel dark outline at the original 64x64 sprite scale
- limited palette, 16 to 24 colors
- flat colors and solid color clusters
- no gradients
- no anti-aliasing
- no smooth curves
- no subpixel lines
- no blended shading
- no soft blur
- no too many colors
- no pixel-art filter applied to smooth high-resolution artwork
- clean game asset style
- transparent background or plain solid background
```

## 공통 네거티브 프롬프트

```text
realistic, semi-realistic, 3D render, clay render, plush toy, fabric texture, high-resolution illustration, vector illustration, anime illustration, painterly style, oil painting, watercolor, smooth vector art, detailed background, complex scenery, text, letters, labels, watermark, logo, UI, decorative symbols, exclamation marks, Z symbols, motion lines, multiple characters, human character, scary, violent, overly detailed, cropped body, blurry, soft blur, anti-aliasing, anti-aliased illustration, antialiased edges, gradient shading, blended shading, soft cel shading, airbrush shading, glossy shading, smooth curves, subpixel lines, pixel-filtered illustration, high-resolution art pretending to be pixel art, AI-upscaled illustration, too many colors, noisy pixels, messy pixel art, inconsistent character, inconsistent proportions, inconsistent colors, different character in each frame, inconsistent limbs, extra limbs, extra eyes, photo style, weapon, armor, human adult body, tall body, long limbs, sharp hat, serious expression, adult proportions, exact copy of the reference, realistic anatomy, narrow face, tiny face, small eyes, stiff mascot pose, mature mascot proportions, tall thin silhouette
```

## 레퍼런스가 있는 경우

지자체 마스코트, 공공누리 캐릭터, 지역 상징 이미지가 있을 때 사용한다.

### 기본 캐릭터 생성

```text
Using the provided reference image, create a MasilPet version of this character.

Keep only the recognizable identity cues from the reference:
- representative colors
- symbolic features
- soft hint of the face shape and key features
- friendly mascot feeling
- do not turn it into a completely unrelated creature

Convert it into a cute pixel art companion pet for a mobile tourism game.
The character should feel like a small pet that can grow, travel, and emotionally interact with the user.
Prioritize cuteness over exact reference fidelity: make the silhouette shorter, rounder, softer, and more pet-like.
Shrink, soften, or remove details that make it look stiff, mature, sharp, or too close to the source.

Cute style rules:
- cute-first redesign: make the character noticeably cuter than the reference, even if exact source fidelity is reduced
- soft mascot-like cute proportions, not fabric or 3D plush material
- baby chibi proportions
- head takes about 65% to 70% of total body height
- extra-large rounded face with oversized dot eyes
- tiny nose and tiny smiling mouth
- smaller compact body, short and squat
- very tiny bean-shaped hands and feet
- soft rounded cheeks with subtle blush-like color accents
- gentle happy expression by default
- simplified accessories or tail if the character has one, made shorter, rounder, and cuter
- limited bright cute color palette, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Style: clean cute actual 64x64 low-resolution pixel art sprite, full body, transparent background, centered, simple readable shape, thick 1 pixel dark outline at 64x64 scale, limited palette of 16 to 24 colors, flat colors only, visible square pixels, stair-stepped pixel edges, no gradients, no anti-aliasing, no smooth curves, no subpixel lines, no blended shading, no pixel-art filter over a high-resolution illustration, Korean regional mascot-inspired, warm and friendly, game-ready asset. If the final image is larger than 64x64 per sprite, upscale only with nearest-neighbor so the blocky pixel structure remains visible.

Do not copy text, logos, or official marks from the reference.
Do not make it realistic, tall, long-limbed, narrow-faced, small-eyed, sharp, stiff, mature, or serious.
```

### 감정표현 6종 스프라이트 시트

```text
Using the provided MasilPet character reference, create a cute 64x64 MasilPet pixel-art emotion sprite sheet.

Layout: 2 rows x 3 columns, 6 sprites total.
Target sprite size: 64x64 pixels per sprite.
Strict pixel execution: draw each sprite as true low-resolution 64x64 pixel art first, then upscale with nearest-neighbor only if the final sheet is larger. The pixels must be visibly blocky; outlines must be stair-stepped, not smooth curves. Do not create a high-resolution illustration with a pixel-art filter.

Character identity rules:
- use the provided reference image as identity inspiration, not as an exact copy target
- preserve the recognizable motifs, main colors, face shape hints, and key features
- keep the same cute chibi redesign across all cells
- do not redesign the character into a completely unrelated creature

Each sprite must be inside an equal-sized cell.
Use the exact same character design, colors, proportions, and accessories in every cell.
Only the facial expression and small body pose should change.

Cute style rules:
- cute-first redesign: make the character noticeably cuter than the reference, even if exact source fidelity is reduced
- soft mascot-like cute proportions, not fabric or 3D plush material
- baby chibi proportions
- head takes about 65% to 70% of total body height
- extra-large rounded face with oversized dot eyes
- tiny nose and tiny smiling mouth
- smaller compact body, short and squat
- very tiny bean-shaped hands and feet
- soft rounded cheeks with subtle blush-like color accents
- gentle happy expression by default
- simplified accessories or tail if the character has one, made shorter, rounder, and cuter
- limited bright cute color palette, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Expressions:
1. neutral
2. happy
3. excited
4. sad
5. surprised
6. sleepy

Style: clean cute actual 64x64 low-resolution pixel art, thick 1 pixel dark outline at 64x64 scale, limited palette of 16 to 24 colors, flat colors only, visible square pixels, stair-stepped pixel edges, no gradients, no anti-aliasing, no smooth curves, no subpixel lines, no blended shading, cute Korean regional mascot-inspired companion pet, transparent background, centered full body, readable silhouette, mobile game-ready asset.

No text, no letters, no labels, no background, no logo, no watermark, no exclamation marks, no Z symbols, no motion lines, no tall body, no long limbs, no sharp accessories, no serious expression.
```

### 감정표현 12종 스프라이트 시트

```text
Using the provided MasilPet character reference, create a consistent emotion sprite sheet.

Keep the recognizable identity cues from the reference:
core colors, symbolic features, a soft hint of the face shape, and friendly mascot feeling.
Prioritize a cute chibi pet version over exact reference fidelity.
Do not redesign the character into a completely unrelated creature.

Layout: 3 rows x 4 columns, 12 sprites total.
Each cell contains the same character with a different expression.
The character must remain identical across all cells:
same body shape, same colors, same accessories, same proportions.

Target sprite size: 64x64 pixels per sprite.
Strict pixel execution: draw each sprite as true low-resolution 64x64 pixel art first, then upscale with nearest-neighbor only if the final sheet is larger. The pixels must be visibly blocky; outlines must be stair-stepped, not smooth curves. Do not create a high-resolution illustration with a pixel-art filter.

Cute style rules:
- cute-first redesign: make the character noticeably cuter than the reference, even if exact source fidelity is reduced
- soft mascot-like cute proportions, not fabric or 3D plush material
- baby chibi proportions
- head takes about 65% to 70% of total body height
- extra-large rounded face with oversized dot eyes
- tiny nose and tiny smiling mouth
- smaller compact body, short and squat
- very tiny bean-shaped hands and feet
- soft rounded cheeks with subtle blush-like color accents
- gentle happy expression by default
- simplified accessories or tail if the character has one, made shorter, rounder, and cuter
- limited bright cute color palette, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Expressions:
neutral, happy, excited, sad, angry, surprised, shy, tired, sleepy, hungry, curious, proud.

Style: clean cute actual 64x64 low-resolution pixel art per sprite, transparent background, centered full body, simple readable silhouette, thick 1 pixel dark outline at 64x64 scale, limited palette of 16 to 24 colors, flat colors only, visible square pixels, stair-stepped pixel edges, no gradients, no anti-aliasing, no smooth curves, no subpixel lines, no blended shading, cute mobile game asset, Korean regional mascot-inspired.

Do not copy text, logos, or official marks from the reference.
No text, no labels, no background, no watermark, no tall body, no long limbs, no sharp accessories, no serious expression.
```

### 성장 단계 3종

```text
Using the provided MasilPet reference, create a 3-stage evolution sprite sheet.

Layout: 1 row x 3 columns.
Stages:
1. egg form
2. baby pet form
3. evolved companion form

Target sprite size: 64x64 pixels per stage.
Strict pixel execution: draw each stage as true low-resolution 64x64 pixel art first, then upscale with nearest-neighbor only if the final sheet is larger. The pixels must be visibly blocky; outlines must be stair-stepped, not smooth curves. Do not create a high-resolution illustration with a pixel-art filter.

Maintain visual continuity across all stages:
same color identity, same symbolic motif, same regional inspiration.
Preserve only the recognizable reference cues, colors, symbolic features, and cute mascot feeling from baby stage onward.
It is acceptable to make each stage shorter, rounder, and more pet-like than the reference.
Do not redesign the character into a completely unrelated creature.

Cute style rules:
- cute-first redesign across all stages, even if exact source fidelity is reduced
- soft mascot-like cute proportions across all stages, not fabric or 3D plush material
- baby chibi proportions from baby stage onward
- head takes about 65% to 70% of total body height from baby stage onward
- extra-large rounded face with oversized dot eyes from baby stage onward
- smaller compact body, short and squat
- very tiny bean-shaped hands and feet from baby stage onward
- soft rounded cheeks with subtle blush-like color accents from baby stage onward
- gentle happy expression by default from baby stage onward
- simplified accessories or tail if the character has one, made shorter, rounder, and cuter
- limited bright cute color palette, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Style: cute Korean tourism mascot-inspired actual 64x64 low-resolution pixel art per sprite, transparent background, centered, game-ready, thick 1 pixel dark outline at 64x64 scale, limited palette of 16 to 24 colors, flat colors only, visible square pixels, stair-stepped pixel edges, no gradients, no anti-aliasing, no smooth curves, no subpixel lines, no blended shading, no text, no background.
```

### 행동 대표 포즈 시트

```text
Using the provided MasilPet character reference, create a pixel art action pose sprite sheet.

This is not an animation frame sheet.
Create one representative pose for each action.

Layout: 2 rows x 3 columns, 6 sprites total.
Target sprite size: 64x64 pixels per sprite.
Strict pixel execution: draw each sprite as true low-resolution 64x64 pixel art first, then upscale with nearest-neighbor only if the final sheet is larger. The pixels must be visibly blocky; outlines must be stair-stepped, not smooth curves. Do not create a high-resolution illustration with a pixel-art filter.

Character identity rules:
- use the provided reference image as identity inspiration, not as an exact copy target
- preserve the recognizable motifs, main colors, face shape hints, and key features
- preserve the character's cute mascot feeling
- do not redesign the character into a completely unrelated creature

Actions:
- idle
- walking
- jumping
- eating
- sleeping
- greeting

Make the character much cuter than the reference:
- cute-first redesign: prioritize a lovable chibi pet over exact reference fidelity
- soft mascot-like cute proportions, not fabric or 3D plush material
- baby chibi proportions
- head takes about 65% to 70% of total body height
- extra-large rounded face with oversized dot eyes
- tiny nose and tiny smiling mouth
- smaller compact body, short and squat
- very tiny bean-shaped hands and feet
- soft rounded cheeks with subtle blush-like color accents
- gentle happy expression by default
- shorter, rounder, cuter head accessory
- limited bright cute color palette, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Keep the character design consistent in every cell:
same body shape, same colors, same proportions, same accessories.
Only the action pose may change.
Do not create a different character in each cell.

Style: clean cute actual 64x64 low-resolution pixel art, thick 1 pixel dark outline at 64x64 scale, limited palette of 16 to 24 colors, flat colors only, visible square pixels, stair-stepped pixel edges, no gradients, no anti-aliasing, no smooth curves, no subpixel lines, no blended shading, transparent background, evenly spaced sprite sheet, simple readable pose, mobile game-ready.

No text, no letters, no labels, no background, no logo, no watermark, no exclamation marks, no Z symbols, no motion lines, no sharp hat, no tall body, no long limbs, no serious expression.
```

### 애니메이션 프레임 시트

실제 애니메이션은 행동 하나를 여러 프레임으로 쪼갠 시트다. 한 장에 `idle`, `walk`, `sleep`을 모두 넣지 않고, 행동별로 `1 row x 4 frames`를 따로 생성한다. 이 방식이 캐릭터 일관성, 프레임 가독성, 후처리 자동화 측면에서 가장 안정적이다.

```text
Using the provided MasilPet character reference, create one 64x64 pixel-art animation frame sheet for a single action.

Action: [idle / walk / sleep / eat / greet]
Layout: 1 row x 4 columns, 4 frames total.
Target sprite size: 64x64 pixels per frame.
Strict pixel execution: draw each frame as true low-resolution 64x64 pixel art first, then upscale with nearest-neighbor only if the final sheet is larger. The pixels must be visibly blocky; outlines must be stair-stepped, not smooth curves. Do not create a high-resolution illustration with a pixel-art filter.

Character identity rules:
- use the provided reference image as identity inspiration, not as an exact copy target
- preserve the recognizable motifs, main colors, face shape hints, and key features
- preserve the character's cute mascot feeling
- do not redesign the character into a completely unrelated creature

Keep the same character identity in every frame:
- same body shape
- same colors
- same proportions
- same accessories
- same head accessory detail
- same tail design if the character has one

Cute style rules:
- cute-first redesign: make the character noticeably cuter than the reference, even if exact source fidelity is reduced
- soft mascot-like cute proportions, not fabric or 3D plush material
- baby chibi proportions
- head takes about 65% to 70% of total body height
- extra-large rounded face with oversized dot eyes
- tiny nose and tiny smiling mouth
- smaller compact body, short and squat
- very tiny bean-shaped hands and feet
- soft rounded cheeks with subtle blush-like color accents
- gentle happy expression by default
- simplified accessories or tail if the character has one, made shorter, rounder, and cuter
- limited bright cute color palette, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Animation rules:
- show a smooth, readable motion loop across 4 frames
- frame 1 and frame 4 should connect naturally when looped
- keep the feet and body roughly aligned so the sprite does not jitter
- only small pose changes should occur between frames
- every frame must show the full body
- every frame must be centered inside an equal-sized cell
- do not create a different character in each frame

Style: clean cute actual 64x64 low-resolution pixel art, thick 1 pixel dark outline at 64x64 scale, limited palette of 16 to 24 colors, flat colors only, visible square pixels, stair-stepped pixel edges, no gradients, no anti-aliasing, no smooth curves, no subpixel lines, no blended shading, cute Korean regional mascot-inspired companion pet, transparent background, evenly spaced frame sheet, mobile game-ready.

No text, no letters, no labels, no background, no logo, no watermark, no exclamation marks, no Z symbols, no motion lines, no decorative effects.
Do not make it realistic, 3D, high-resolution, painterly, smooth vector art, detailed illustration, antialiased, smoothly curved, pixel-filtered, tall body, long limbs, sharp accessories, or serious expression.
```

### 애니메이션별 추천 프롬프트

#### Idle 4프레임

```text
Action: idle breathing loop.
Create 4 frames where the MasilPet gently bobs up and down while breathing.
The face stays calm and cute.
Keep soft mascot-like baby chibi proportions consistent in every frame.
Only tiny body movement, head accessory movement, ear movement, or tail movement should change.
No walking, no jumping, no effects.
```

#### Walk 4프레임

```text
Action: walking loop.
Create 4 frames of a cute side-or-front walking cycle.
The feet alternate clearly, the body bobs slightly, and the head accessory or tail follows the motion if the character has one.
Keep the character centered and aligned so it can loop smoothly in a mobile game.
Keep the body compact, the head large, and the hands and feet bean-shaped across all frames.
No dust, no speed lines, no background.
```

#### Sleep 4프레임

```text
Action: sleeping loop.
Create 4 frames where the MasilPet sleeps in a small curled or seated pose.
Use closed eyes and gentle breathing motion.
The body should subtly rise and fall across frames.
Keep the sleeping pose compact, mascot-like, and softly rounded.
Do not include Z letters, bubbles, symbols, or text.
```

#### Eat 4프레임

```text
Action: eating loop.
Create 4 frames where the MasilPet eats a tiny simple food item.
Use small mouth and hand movement only.
The food item should be very simple and should not distract from the character.
Keep the character compact, mascot-like, and gently happy.
No crumbs, no text, no decorative effects.
```

#### Greet 4프레임

```text
Action: greeting loop.
Create 4 frames where the MasilPet waves one small paw.
The body should remain mostly stable while the paw moves.
The expression should be friendly and welcoming.
Keep the character compact, mascot-like, with a large face and tiny bean-shaped hands.
No exclamation marks, no motion lines, no text.
```

## 효율적 생성 전략

- `기본 캐릭터`는 3~5장 생성해 가장 좋은 1장을 기준 레퍼런스로 고정한다.
- `감정표현`은 한 장에 6종을 묶는다. 12종은 최종 스타일이 안정된 뒤에만 생성한다.
- `성장 단계`는 한 장에 3단계를 묶는다.
- `행동 대표 포즈`는 한 장에 6종을 묶어도 된다. 이 시트는 기획 확인용 또는 정적 UI용으로 사용한다.
- `애니메이션 프레임 시트`는 행동 하나당 4프레임으로 따로 생성한다. `idle`, `walk`, `sleep`을 MVP 우선순위로 둔다.
- 6개 행동을 각각 4프레임으로 한 장에 넣는 `6 actions x 4 frames = 24 sprites` 방식은 비추천한다. 셀 수가 많아지면 캐릭터 형태, 표정, 위치 정렬이 쉽게 흔들린다.
- 후처리 자동화를 위해 프롬프트에 항상 `Layout`, `Target sprite size`, `equal-sized cells`, `centered full body`, `no text`, `no symbols`를 명시한다.

## 에셋 분리 기준

스프라이트 시트는 생성 후 고정 레이아웃으로 자른다. 생성 이미지의 실제 픽셀 크기가 64px 배수가 아니더라도, 시트 전체를 행과 열 기준으로 균등 분할한 뒤 각 셀을 64x64로 리사이즈해 사용한다.

| 시트 유형 | 레이아웃 | 분리 결과 |
| --- | --- | --- |
| 감정표현 6종 | 2 rows x 3 columns | `neutral`, `happy`, `excited`, `sad`, `surprised`, `sleepy` |
| 감정표현 12종 | 3 rows x 4 columns | `neutral`, `happy`, `excited`, `sad`, `angry`, `surprised`, `shy`, `tired`, `sleepy`, `hungry`, `curious`, `proud` |
| 성장 단계 | 1 row x 3 columns | `egg`, `baby`, `evolved` |
| 행동 대표 포즈 | 2 rows x 3 columns | `idle`, `walking`, `jumping`, `eating`, `sleeping`, `greeting` |
| Idle 애니메이션 | 1 row x 4 columns | `idle_01`, `idle_02`, `idle_03`, `idle_04` |
| Walk 애니메이션 | 1 row x 4 columns | `walk_01`, `walk_02`, `walk_03`, `walk_04` |
| Sleep 애니메이션 | 1 row x 4 columns | `sleep_01`, `sleep_02`, `sleep_03`, `sleep_04` |

추천 저장 구조:

```text
assets/masilpets/[pet_id]/
  source/
    base.png
    emotions_sheet.png
    evolution_sheet.png
    action_poses_sheet.png
    idle_animation_sheet.png
    walk_animation_sheet.png
    sleep_animation_sheet.png
  emotions/
    neutral.png
    happy.png
    excited.png
    sad.png
    surprised.png
    sleepy.png
  evolution/
    egg.png
    baby.png
    evolved.png
  actions/
    idle.png
    walking.png
    jumping.png
    eating.png
    sleeping.png
    greeting.png
  animations/
    idle_01.png
    idle_02.png
    idle_03.png
    idle_04.png
    walk_01.png
    walk_02.png
    walk_03.png
    walk_04.png
    sleep_01.png
    sleep_02.png
    sleep_03.png
    sleep_04.png
  manifest.json
```

## 레퍼런스가 없는 경우

설화, 특산물, 자연, 역사, 축제 등 지역 요소를 바탕으로 오리지널 마실펫을 만들 때 사용한다.

### 지역 기반 오리지널 마실펫 생성

```text
Create an original MasilPet character for a Korean regional tourism mobile game.

Region: [지역명]
Regional keywords: [설화 / 특산물 / 자연 / 역사 / 축제 / 상징물]
Personality: [성격 키워드]
Element motif: [바다 / 산 / 꽃 / 돌 / 별 / 음식 / 전설 동물 등]

Design a very cute collectible pet that feels naturally connected to this region.
It should not look like an existing commercial character.
It should be simple enough to work as a small mobile game sprite.
Prioritize an instantly lovable chibi pet silhouette over complex originality or detailed regional symbolism.

Cute style rules:
- cute-first design: make the character feel adorable at first glance
- soft mascot-like cute proportions, not fabric or 3D plush material
- baby chibi proportions
- head takes about 65% to 70% of total body height
- extra-large rounded face with oversized dot eyes
- tiny nose and tiny smiling mouth
- smaller compact body, short and squat
- very tiny bean-shaped hands and feet
- soft rounded cheeks with subtle blush-like color accents
- gentle happy expression by default
- simplified accessories or tail if the character has one, made shorter, rounder, and cuter
- limited bright cute color palette, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Style: clean cute 64x64 pixel art, full body, transparent background, centered, thick 1 pixel dark outline, limited palette of 16 to 24 colors, flat colors, no gradients, no anti-aliasing, crisp pixel edges, warm and friendly, Korean regional mascot-inspired, readable silhouette, game-ready asset, no text, no logo.
```

### 예시: 제주 마실펫

```text
Create an original MasilPet character for a Korean regional tourism mobile game.

Region: Jeju Island
Regional keywords: volcanic stone, tangerine, sea breeze, haenyeo culture
Personality: curious, cheerful, slightly mischievous
Element motif: small volcanic stone pet with tangerine-colored ears and wave-shaped tail

Design a very cute collectible pet that feels naturally connected to Jeju.
Prioritize an instantly lovable chibi pet silhouette over complex originality or detailed regional symbolism.

Cute style rules:
- cute-first design: make the character feel adorable at first glance
- soft mascot-like cute proportions, not fabric or 3D plush material
- baby chibi proportions
- head takes about 65% to 70% of total body height
- extra-large rounded face with oversized dot eyes
- tiny nose and tiny smiling mouth
- smaller compact body, short and squat
- very tiny bean-shaped hands and feet
- soft rounded cheeks with subtle blush-like color accents
- gentle happy expression by default
- simplified wave-shaped tail, made shorter, rounder, and cuter
- limited bright tangerine and volcanic-stone colors, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Style: clean cute 64x64 pixel art, full body, transparent background, centered, thick 1 pixel dark outline, limited palette of 16 to 24 colors, flat colors, no gradients, no anti-aliasing, crisp pixel edges, warm and friendly, Korean regional mascot-inspired, readable silhouette, game-ready asset, no text, no logo.
```

### 감정표현 세트

```text
Create a consistent emotion sprite sheet for this original MasilPet character.

Character concept:
[캐릭터 설명 입력]

Layout: 2 rows x 3 columns, 6 sprites total.
Create 6 expressions:
neutral, happy, excited, sad, surprised, sleepy.

Rules:
- same character design across all expressions
- same colors and proportions
- keep the same cute chibi design across all expressions
- expression must be clear even at small size
- full body visible
- no text or labels
- cute-first design with soft mascot-like baby chibi proportions, not fabric or 3D plush material
- head takes about 65% to 70% of total body height
- extra-large rounded face with oversized dot eyes
- tiny nose and tiny smiling mouth
- compact short body and very tiny bean-shaped hands and feet
- soft rounded cheeks with subtle blush-like color accents and gentle cute expressions
- limited bright cute color palette, 16 to 24 colors
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Style: clean cute 64x64 pixel art, transparent background, evenly spaced grid, thick 1 pixel dark outline, limited palette of 16 to 24 colors, flat colors, no gradients, no anti-aliasing, crisp pixel edges, mobile game-ready asset.
```

### 성장 단계

```text
Create a 3-stage evolution line for an original MasilPet.

Region: [지역명]
Motif: [지역 상징]
Personality: [성격]
Core colors: [색상]

Stages:
1. egg form inspired by the regional motif
2. baby pet form, small and cute
3. evolved companion form, more expressive and regionally distinctive

All stages must feel like the same character growing over time.
Prioritize a cute, round, pet-like silhouette in every stage over complex originality.

Cute style rules:
- cute-first design across all stages
- soft mascot-like cute proportions across all stages, not fabric or 3D plush material
- baby chibi proportions from baby stage onward
- head takes about 65% to 70% of total body height from baby stage onward
- extra-large rounded face with oversized dot eyes from baby stage onward
- compact short body and very tiny bean-shaped hands and feet from baby stage onward
- soft rounded cheeks with subtle blush-like color accents from baby stage onward
- gentle happy expression by default from baby stage onward
- limited bright cute color palette, 16 to 24 colors
- soft rounded silhouette with no sharp corners
- no sharp or tall body proportions
- avoid realistic anatomy, long limbs, narrow faces, or mature proportions

Style: clean cute 64x64 pixel art, transparent background, centered, thick 1 pixel dark outline, limited palette of 16 to 24 colors, flat colors, no gradients, no anti-aliasing, crisp pixel edges, game-ready sprite, no text.
```

## 감정 키워드 매핑

```text
neutral: calm face, relaxed posture
happy: smiling eyes, lifted body posture
excited: sparkling eyes, energetic pose
sad: lowered ears or body, teary eyes
angry: puffed cheeks, furrowed eyes
surprised: wide eyes, open mouth
shy: blushing cheeks, small closed posture
tired: half-closed eyes, drooping body
sleepy: closed eyes, soft sleeping pose
hungry: looking at food, pleading eyes
curious: tilted head, focused eyes
proud: chest out, confident smile
```

## 실무 생성 순서

```text
1. 캐릭터별 기본 디자인 1장 생성
2. 가장 좋은 디자인을 기준 레퍼런스로 고정
3. 해당 레퍼런스로 감정표현 6종 생성
4. 필요 시 추가 감정표현 6종 생성
5. 같은 레퍼런스로 성장 3단계 생성
6. 같은 레퍼런스로 행동 대표 포즈 6종 생성
7. MVP 핵심 애니메이션을 행동별 4프레임 시트로 생성
8. 우선순위는 idle -> walk -> sleep -> eat -> greet 순서로 둔다
9. 최종 선택본만 앱 에셋 번들에 포함
```

## 제안서용 설명 문장

```text
마실펫의 AI 에셋은 런타임 생성이 아니라, 캐릭터별 기준 이미지를 고정한 뒤 감정, 상태, 성장 스프라이트를 사전 생성하여 앱 에셋 번들로 관리한다. 이를 통해 캐릭터 일관성을 확보하고, 생성형 AI 호출 비용과 품질 변동성을 줄인다.
```
