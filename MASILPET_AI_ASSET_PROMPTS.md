# MasilPet AI Asset Prompt Guide

마실펫의 AI 에셋은 런타임 생성보다 **캐릭터별 기준 이미지를 고정한 뒤 감정, 상태, 성장 스프라이트를 사전 생성**하는 방식이 적합하다. 이 방식은 캐릭터 일관성, 앱 번들 관리, 운영비 측면에서 안정적이다.

## 핵심 원칙

- 한 번에 여러 에셋을 생성할 수 있지만, 품질 유지를 위해 **한 캐릭터의 파생 상태 묶음**으로 제한한다.
- 서로 다른 마실펫 여러 종을 한 번에 최종본으로 뽑으면 형태와 스타일 일관성이 떨어질 수 있다.
- 최종 에셋은 `기준 캐릭터 1장 -> 감정 6종 -> 추가 감정 6종 -> 성장 3단계 -> 행동 4~6프레임` 순서로 나누는 것을 권장한다.
- 지자체 마스코트나 공공누리 캐릭터를 사용할 때는 텍스트, 로고, 공식 마크를 복제하지 않는다.

## 권장 묶음 크기

| 에셋 유형 | 권장 생성 단위 | 최대 권장 |
| --- | ---: | ---: |
| 감정표현 | 6개 | 12개 |
| 성장 단계 | 3개 | 3개 |
| 행동 애니메이션 | 4~6프레임 | 6프레임 |
| 아이템, 먹이, 장식 | 9~16개 | 16개 |
| 서로 다른 마실펫 캐릭터 | 1~2종 | 컨셉 시안 4종 |

## 공통 스타일 프롬프트

```text
Create a cute collectible companion pet character for a mobile location-based tourism game called MasilPet.
Style: clean pixel art sprite, Korean regional mascot-inspired, warm and friendly, simple readable silhouette, small mobile game asset, 32x32 or 64x64 sprite scale, consistent proportions, soft color palette, clear facial expression, no text, no logo, transparent background, centered character, full body, game-ready asset.
```

## 공통 네거티브 프롬프트

```text
realistic, 3D render, complex background, text, watermark, logo, human character, scary, violent, overly detailed, blurry, inconsistent limbs, extra eyes, extra arms, cropped body, noisy pixels, anti-aliased illustration, photo style
```

## 레퍼런스가 있는 경우

지자체 마스코트, 공공누리 캐릭터, 지역 상징 이미지가 있을 때 사용한다.

### 기본 캐릭터 생성

```text
Using the provided reference image, create a MasilPet version of this character.

Keep the core identity from the reference:
- main silhouette
- representative colors
- symbolic features
- friendly mascot feeling

Convert it into a cute pixel art companion pet for a mobile tourism game.
The character should feel like a small pet that can grow, travel, and emotionally interact with the user.

Style: clean 64x64 pixel art sprite, full body, transparent background, centered, simple readable shape, Korean regional mascot-inspired, warm and friendly, game-ready asset.

Do not copy text, logos, or official marks from the reference.
Do not make it realistic.
```

### 감정표현 6종 스프라이트 시트

```text
Using the provided MasilPet character reference, create a consistent emotion sprite sheet.

Layout: 2 rows x 3 columns, 6 sprites total.
Each sprite must be inside an equal-sized cell.
Use the exact same character design, colors, proportions, and accessories in every cell.
Only the facial expression and small body pose should change.

Expressions:
1. neutral
2. happy
3. excited
4. sad
5. surprised
6. sleepy

Style: cute Korean regional mascot-inspired pixel art, 64x64 per sprite, transparent background, centered full body, readable silhouette, mobile game-ready asset.

No text, no labels, no background, no logo, no watermark.
```

### 감정표현 12종 스프라이트 시트

```text
Using the provided MasilPet character reference, create a consistent emotion sprite sheet.

Keep the character identity from the reference:
main silhouette, core colors, symbolic features, and friendly mascot feeling.

Layout: 3 rows x 4 columns, 12 sprites total.
Each cell contains the same character with a different expression.
The character must remain identical across all cells:
same body shape, same colors, same accessories, same proportions.

Expressions:
neutral, happy, excited, sad, angry, surprised, shy, tired, sleepy, hungry, curious, proud.

Style: clean 64x64 pixel art per sprite, transparent background, centered full body, simple readable silhouette, cute mobile game asset, Korean regional mascot-inspired.

Do not copy text, logos, or official marks from the reference.
No text, no labels, no background, no watermark.
```

### 성장 단계 3종

```text
Using the provided MasilPet reference, create a 3-stage evolution sprite sheet.

Layout: 1 row x 3 columns.
Stages:
1. egg form
2. baby pet form
3. evolved companion form

Maintain visual continuity across all stages:
same color identity, same symbolic motif, same regional inspiration.

Style: cute Korean tourism mascot-inspired pixel art, 64x64 per sprite, transparent background, centered, game-ready, no text, no background.
```

### 행동 애니메이션

```text
Using the provided MasilPet character reference, create a pixel art animation sprite sheet.

Actions:
- idle
- walking
- jumping
- eating
- sleeping
- greeting
- discovering a tourist spot

Keep the character design consistent in every frame.
Style: clean 64x64 pixel art, transparent background, evenly spaced sprite sheet, simple readable motion, mobile game-ready.
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

Design a cute collectible pet that feels naturally connected to this region.
It should not look like an existing commercial character.
It should be simple enough to work as a small mobile game sprite.

Style: clean 64x64 pixel art, full body, transparent background, centered, warm and friendly, Korean regional mascot-inspired, readable silhouette, game-ready asset, no text, no logo.
```

### 예시: 제주 마실펫

```text
Create an original MasilPet character for a Korean regional tourism mobile game.

Region: Jeju Island
Regional keywords: volcanic stone, tangerine, sea breeze, haenyeo culture
Personality: curious, cheerful, slightly mischievous
Element motif: small volcanic stone pet with tangerine-colored ears and wave-shaped tail

Design a cute collectible pet that feels naturally connected to Jeju.
Style: clean 64x64 pixel art, full body, transparent background, centered, warm and friendly, Korean regional mascot-inspired, readable silhouette, game-ready asset, no text, no logo.
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
- expression must be clear even at small size
- full body visible
- no text or labels

Style: clean 64x64 pixel art, transparent background, evenly spaced grid, mobile game-ready asset.
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
Style: clean 64x64 pixel art, transparent background, centered, game-ready sprite, no text.
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
6. 같은 레퍼런스로 행동 애니메이션 4~6프레임 생성
7. 최종 선택본만 앱 에셋 번들에 포함
```

## 제안서용 설명 문장

```text
마실펫의 AI 에셋은 런타임 생성이 아니라, 캐릭터별 기준 이미지를 고정한 뒤 감정, 상태, 성장 스프라이트를 사전 생성하여 앱 에셋 번들로 관리한다. 이를 통해 캐릭터 일관성을 확보하고, 생성형 AI 호출 비용과 품질 변동성을 줄인다.
```
