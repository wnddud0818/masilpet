#!/usr/bin/env python3
"""Collect KOG.L mascot references and build source-shaped MasilPet assets."""

from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import json
import math
import re
import shutil
import sys
from collections import Counter, deque
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import parse_qs, unquote, urljoin, urlparse

import requests
from bs4 import BeautifulSoup
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


BASE_URL = "https://www.kogl.or.kr"
LIST_URL = f"{BASE_URL}/recommend/ajaxRecommendDivList.do?division=img"
REFERER_URL = f"{BASE_URL}/recommend/recommendDivList.do?division=img"
CELL_SIZE = 512
SPRITE_SIZE = 64
OUTLINE = (24, 24, 28, 255)

SHEET_SPECS = {
    "actions": ("action_poses_sheet.png", 2, 3, ["idle", "walking", "jumping", "eating", "sleeping", "greeting"]),
    "emotions": ("emotions_sheet.png", 2, 3, ["neutral", "happy", "excited", "sad", "surprised", "sleepy"]),
    "growth": ("growth_sheet.png", 1, 3, ["baby", "grown", "evolved"]),
    "idle_animation": ("idle_animation_sheet.png", 1, 4, ["idle_0", "idle_1", "idle_2", "idle_3"]),
    "walk_animation": ("walk_animation_sheet.png", 1, 4, ["walk_0", "walk_1", "walk_2", "walk_3"]),
    "sleep_animation": ("sleep_animation_sheet.png", 1, 4, ["sleep_0", "sleep_1", "sleep_2", "sleep_3"]),
    "eat_animation": ("eat_animation_sheet.png", 1, 4, ["eat_0", "eat_1", "eat_2", "eat_3"]),
    "greet_animation": ("greet_animation_sheet.png", 1, 4, ["greet_0", "greet_1", "greet_2", "greet_3"]),
}


def u(value: str) -> str:
    return value.encode("ascii").decode("unicode_escape")


K = {
    "shooting_agency": u("\\ucd2c\\uc601\\uae30\\uad00"),
    "holding_agency": u("\\uc18c\\uc7a5\\uae30\\uad00"),
    "character": u("\\uce90\\ub9ad\\ud130"),
    "mascot": u("\\ub9c8\\uc2a4\\ucf54\\ud2b8"),
    "emoticon": u("\\uc774\\ubaa8\\ud2f0\\ucf58"),
    "friends": u("\\ud504\\ub80c\\uc988"),
    "logo": u("\\ub85c\\uace0"),
    "slogan": u("\\uc2ac\\ub85c\\uac74"),
    "mark": u("\\ub9c8\\ud06c"),
    "brand": u("\\ube0c\\ub79c\\ub4dc"),
    "poster": u("\\ud3ec\\uc2a4\\ud130"),
    "calendar": u("\\ub2ec\\ub825"),
    "guidebook": u("\\uac00\\uc774\\ub4dc\\ubd81"),
    "card": u("\\uc5f0\\ud558\\uc7a5"),
}

INCLUDE_TERMS = [
    K["character"],
    K["mascot"],
    K["emoticon"],
    K["friends"],
    u("\\ud070\\uc560\\uae30"),
    u("\\ucf54\\ub9ac\\uc694"),
    u("\\uc544\\ub9ac\\ubbf8"),
    u("\\ud574\\ub85c"),
    u("\\ud1a0\\ub85c"),
    u("\\ub204\\ub801\\uc774"),
    u("\\uc0b0\\uc774"),
    u("\\ucfe4\\uc774"),
    u("\\uc640\\uad6c\\ub9ac"),
    u("\\ubf40\\uad6c\\ub9ac"),
    u("\\ub69c\\uae30"),
    u("\\ub69c\\ubbf8"),
    u("\\ud574\\ub728\\ubbf8"),
    u("\\ud574\\ub204\\ub9ac"),
    u("\\ud574\\ub098\\ub9ac"),
    u("\\uac00\\ud2f0"),
    u("\\uc624\\uc288"),
]
EXCLUDE_TITLE_TERMS = [
    K["logo"],
    K["slogan"],
    K["mark"],
    K["brand"],
    K["poster"],
    K["calendar"],
    K["guidebook"],
    K["card"],
]
LOCAL_TERMS = [
    u("\\ud2b9\\ubcc4\\uc2dc"),
    u("\\uad11\\uc5ed\\uc2dc"),
    u("\\ud2b9\\ubcc4\\uc790\\uce58\\uc2dc"),
    u("\\ud2b9\\ubcc4\\uc790\\uce58\\ub3c4"),
    u("\\uc790\\uce58\\ub3c4"),
    u("\\uc2dc"),
    u("\\uad70"),
    u("\\uad6c"),
    u("\\ub3c4"),
]
LOCAL_NAME_RE = re.compile(
    "|".join(
        [
            u("\\ud2b9\\ubcc4\\uc2dc"),
            u("\\uad11\\uc5ed\\uc2dc"),
            u("\\ud2b9\\ubcc4\\uc790\\uce58\\uc2dc"),
            u("\\ud2b9\\ubcc4\\uc790\\uce58\\ub3c4"),
            u("\\uc790\\uce58\\ub3c4"),
        ]
    )
    + r"|["
    + u("\\uac00")
    + "-"
    + u("\\ud7a3")
    + r"]{2,12}(?:"
    + "|".join([u("\\uc2dc"), u("\\uad70"), u("\\uad6c"), u("\\ub3c4")])
    + r")$"
)
FAMILY_PATTERNS = [
    ("kijang_friends", u("\\uae30\\uc7a5\\ud504\\ub80c\\uc988")),
    ("gunsan_nureongi", u("\\ub204\\ub801\\uc774")),
    ("gunsan_sani", u("\\uc0b0\\uc774")),
    ("gunsan_kuni", u("\\ucfe4\\uc774")),
    ("hwaseong_koriyo", u("\\ucf54\\ub9ac\\uc694")),
    ("seosan_haenuri_haenari", u("\\ud574\\ub204\\ub9ac")),
    ("seosan_haenuri_haenari", u("\\ud574\\ub098\\ub9ac")),
    ("seosan_gati_oshu", u("\\uac00\\ud2f0")),
    ("seosan_gati_oshu", u("\\uc624\\uc288")),
    ("dongnae_ttugi_ttumi", u("\\ub69c\\uae30")),
    ("dongnae_ttugi_ttumi", u("\\ub69c\\ubbf8")),
    ("ulju_haetteumi", u("\\ud574\\ub728\\ubbf8")),
    ("ulsan_bigaegi", u("\\ud070\\uc560\\uae30")),
    ("gwangju_chungjang_friends", u("\\ucda9\\uc7a5\\ud504\\ub80c\\uc988")),
    ("jecheon_jeje_cheoncheoni", u("\\uc81c\\uc81c")),
    ("jecheon_jeje_cheoncheoni", u("\\ucc9c\\ucc9c\\uc774")),
    ("jincheon_won", u("\\uc6d0\\ud654\\ub791")),
    ("jincheon_won", u("\\uc6d0\\ub0ad\\uc790")),
    ("guri_waguri", u("\\uc640\\uad6c\\ub9ac")),
    ("guri_ppoguri", u("\\ubf40\\uad6c\\ub9ac")),
    ("guri_arimi", u("\\uc544\\ub9ac\\ubbf8")),
    ("siheung_haero_toro", u("\\ud574\\ub85c\\ud1a0\\ub85c")),
    ("siheung_haero", u("\\ub9ac\\ud2c0\\ud574\\ub85c")),
    ("siheung_toro", u("\\ub9ac\\ud2c0\\ud1a0\\ub85c")),
]
KNOWN_CHARACTER_LABELS = {
    "kijang_friends": u("\\uae30\\uc7a5\\ud504\\ub80c\\uc988"),
    "gunsan_nureongi": u("\\ub204\\ub801\\uc774"),
    "gunsan_sani": u("\\uc0b0\\uc774"),
    "gunsan_kuni": u("\\ucfe4\\uc774"),
    "hwaseong_koriyo": u("\\ucf54\\ub9ac\\uc694"),
    "seosan_haenuri_haenari": u("\\ud574\\ub204\\ub9ac/\\ud574\\ub098\\ub9ac"),
    "seosan_gati_oshu": u("\\uac00\\ud2f0/\\uc624\\uc288"),
    "dongnae_ttugi_ttumi": u("\\ub69c\\uae30/\\ub69c\\ubbf8"),
    "ulju_haetteumi": u("\\ud574\\ub728\\ubbf8"),
    "ulsan_bigaegi": u("\\uc6b8\\uc0b0\\ud070\\uc560\\uae30"),
    "gwangju_chungjang_friends": u("\\ucda9\\uc7a5\\ud504\\ub80c\\uc988"),
    "jecheon_jeje_cheoncheoni": u("\\uc81c\\uc81c/\\ucc9c\\ucc9c\\uc774"),
    "jincheon_won": u("\\uc6d0\\ud654\\ub791/\\uc6d0\\ub0ad\\uc790"),
    "guri_waguri": u("\\uc640\\uad6c\\ub9ac"),
    "guri_ppoguri": u("\\ubf40\\uad6c\\ub9ac"),
    "guri_arimi": u("\\uc544\\ub9ac\\ubbf8"),
    "siheung_haero_toro": u("\\ud574\\ub85c/\\ud1a0\\ub85c"),
    "siheung_haero": u("\\ud574\\ub85c"),
    "siheung_toro": u("\\ud1a0\\ub85c"),
}
LICENSE_TEXT_RE = re.compile(
    u("\\uc81c[0-4]\\uc720\\ud615[^\\n]*\\uc870\\uac74\\uc5d0 \\ub530\\ub77c \\uc774\\uc6a9 \\ud560 \\uc218 \\uc788\\uc2b5\\ub2c8\\ub2e4")
    + r"\."
)
LICENSE_NUMBER_RE = re.compile(u("\\uc81c([0-4])\\uc720\\ud615"))


def session() -> requests.Session:
    item = requests.Session()
    item.headers.update({"User-Agent": "MasilPetSourceDrivenPipeline/1.0", "Referer": REFERER_URL})
    return item


def decode_response_text(response: requests.Response) -> str:
    response.raise_for_status()
    return response.content.decode("utf-8", errors="replace")


def list_page(client: requests.Session, page: int) -> str:
    data = [
        ("smallCode", ""),
        ("middleCode", "B012"),
        ("fontTypeCd", ""),
        ("imgViewType", "L"),
        ("searchSort", "ddate"),
        ("searchCnt", "50"),
        ("cPage", str(page)),
        ("company", ""),
        ("orgCode", ""),
        ("searchStr", ""),
        ("searchGubun", "K"),
        ("atcTypeCode", "9"),
        ("atcTypeCode", "1"),
        ("atcTypeCode", "2"),
    ]
    response = client.post(LIST_URL, data=data, timeout=40)
    return decode_response_text(response)


def background_url(node: Any) -> str:
    style = " ".join(item.get("style", "") for item in node.select("[style*=background-image]"))
    match = re.search(r"url\(['\"]?([^'\")]+)", style)
    return urljoin(BASE_URL, match.group(1)) if match else ""


def parse_list(text: str) -> tuple[list[dict[str, Any]], int]:
    soup = BeautifulSoup(text, "html.parser")
    records: list[dict[str, Any]] = []
    seen: set[str] = set()
    for item in soup.select(".photo-list__item"):
        anchor = item.select_one("a[href*=recommendDivView]")
        if anchor is None:
            continue
        href = urljoin(BASE_URL, anchor["href"])
        idx = parse_qs(urlparse(href).query).get("recommendIdx", [""])[0]
        if not idx or idx in seen:
            continue
        seen.add(idx)
        mark = item.select_one('button[class*="dialogOpencode"] img')
        title_node = item.select_one(".photo-list__title") or anchor
        records.append(
            {
                "recommendIdx": idx,
                "title": title_node.get_text(" ", strip=True),
                "detailUrl": href,
                "licenseMark": mark.get("alt", "") if mark else "",
                "thumbUrl": background_url(item),
            }
        )
    total_node = soup.select_one("#ajaxTotalCnt")
    return records, int(total_node.get("value")) if total_node else len(records)


def collect_list_records(client: requests.Session) -> list[dict[str, Any]]:
    first, total = parse_list(list_page(client, 1))
    pages = math.ceil(total / 50)
    records = list(first)
    seen = {record["recommendIdx"] for record in records}
    for page in range(2, pages + 1):
        page_records, _ = parse_list(list_page(client, page))
        for record in page_records:
            if record["recommendIdx"] not in seen:
                records.append(record)
                seen.add(record["recommendIdx"])
    return records


def text_after(full_text: str, label: str) -> str:
    match = re.search(re.escape(label) + r"\s*:\s*([^\n]+)", full_text)
    return match.group(1).strip() if match else ""


def parse_detail(record: dict[str, Any]) -> dict[str, Any]:
    client = session()
    response = client.get(record["detailUrl"], timeout=40)
    text = decode_response_text(response)
    soup = BeautifulSoup(text, "html.parser")
    full_text = soup.get_text("\n", strip=True)
    tags = [node.get_text(" ", strip=True).lstrip("#") for node in soup.select('a[href*="search"][href*="query="]')]
    image_urls = []
    for match in re.finditer(r"url\(['\"]?([^'\")]+)", text):
        value = match.group(1)
        if "/upload_recommend/" in value:
            image_urls.append(urljoin(BASE_URL, value))
    main_url = next((url for url in image_urls if "/thumb_L/" not in url), image_urls[0] if image_urls else "")
    license_match = LICENSE_TEXT_RE.search(full_text)
    return {
        **record,
        "shootingAgency": text_after(full_text, K["shooting_agency"]),
        "holdingAgency": text_after(full_text, K["holding_agency"]),
        "tags": tags,
        "licenseText": license_match.group(0) if license_match else "",
        "mainImageUrl": main_url,
    }


def enrich_records(records: list[dict[str, Any]], workers: int) -> list[dict[str, Any]]:
    detailed: list[dict[str, Any]] = []
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(parse_detail, record) for record in records]
        for count, future in enumerate(as_completed(futures), start=1):
            detailed.append(future.result())
            if count % 25 == 0:
                print(f"Fetched details: {count}/{len(records)}", file=sys.stderr, flush=True)
    return detailed


def license_number(record: dict[str, Any]) -> int | None:
    match = LICENSE_NUMBER_RE.search(" ".join([record.get("licenseMark", ""), record.get("licenseText", "")]))
    return int(match.group(1)) if match else None


def family_id(record: dict[str, Any]) -> str:
    title = record.get("title", "")
    tags = record.get("tags", [])
    haystack = " ".join([title, " ".join(tags)])
    for key, pattern in FAMILY_PATTERNS:
        if key == "gunsan_sani" and not (title.strip() == pattern or pattern in tags):
            continue
        if pattern in haystack:
            return key
    return f"mascot_{record['recommendIdx']}"


def source_character(record: dict[str, Any]) -> str:
    family = family_id(record)
    if family in KNOWN_CHARACTER_LABELS:
        return KNOWN_CHARACTER_LABELS[family]
    return record.get("tags", [record.get("title", "")])[0]


def local_government(record: dict[str, Any]) -> str:
    agency = record.get("holdingAgency") or record.get("shootingAgency") or ""
    if LOCAL_NAME_RE.search(agency):
        return agency
    for tag in record.get("tags", []):
        if LOCAL_NAME_RE.search(tag):
            return tag
    return agency


def license_flags(number: int | None) -> dict[str, bool]:
    if number == 0:
        return {"derivativeAllowed": True, "commercialAllowed": True, "attributionRequired": False}
    if number == 1:
        return {"derivativeAllowed": True, "commercialAllowed": True, "attributionRequired": True}
    if number == 2:
        return {"derivativeAllowed": True, "commercialAllowed": False, "attributionRequired": True}
    return {"derivativeAllowed": False, "commercialAllowed": False, "attributionRequired": True}


def is_candidate(record: dict[str, Any]) -> bool:
    number = license_number(record)
    if number not in {0, 1, 2}:
        return False
    title = record.get("title", "")
    haystack = " ".join([title, local_government(record), " ".join(record.get("tags", [])), record.get("licenseText", "")])
    if not any(term in haystack for term in INCLUDE_TERMS):
        return False
    if any(term in title for term in EXCLUDE_TITLE_TERMS) and not any(term in title for term in [K["character"], K["friends"]]):
        return False
    return LOCAL_NAME_RE.search(local_government(record)) is not None


def asset_key(record: dict[str, Any]) -> str:
    return f"kogl_src_{record['recommendIdx']}_{family_id(record)}"


def select_records(records: list[dict[str, Any]], limit: int, family_limit: int) -> list[dict[str, Any]]:
    candidates = [record for record in records if is_candidate(record)]
    candidates.sort(key=lambda value: int(value["recommendIdx"]), reverse=True)
    selected: list[dict[str, Any]] = []
    family_counts: Counter[str] = Counter()
    for record in candidates:
        family = family_id(record)
        if family_counts[family] >= family_limit:
            continue
        selected.append(record)
        family_counts[family] += 1
        if len(selected) >= limit:
            return selected
    for record in candidates:
        if record not in selected:
            selected.append(record)
            if len(selected) >= limit:
                break
    return selected[:limit]


def image_extension(url: str, content_type: str) -> str:
    suffix = Path(unquote(urlparse(url).path)).suffix.lower()
    if suffix in {".png", ".jpg", ".jpeg", ".webp"}:
        return ".jpg" if suffix == ".jpeg" else suffix
    if "png" in content_type:
        return ".png"
    if "webp" in content_type:
        return ".webp"
    return ".jpg"


def download_reference(client: requests.Session, record: dict[str, Any], image_dir: Path) -> str:
    urls = [record.get("mainImageUrl", ""), record.get("thumbUrl", "")]
    last_error: Exception | None = None
    for url in [value for value in urls if value]:
        try:
            response = client.get(url, timeout=60)
            response.raise_for_status()
            ext = image_extension(url, response.headers.get("Content-Type", ""))
            target = image_dir / f"{asset_key(record)}{ext}"
            target.write_bytes(response.content)
            with Image.open(target) as image:
                image.verify()
            return target.as_posix()
        except Exception as error:  # KOG.L sometimes returns an HTML fallback for source images.
            last_error = error
            if "target" in locals() and target.exists():
                target.unlink()
    raise RuntimeError(f"No valid image reference for {record.get('recommendIdx')}: {last_error}")


def collect(args: argparse.Namespace) -> dict[str, Any]:
    client = session()
    records = enrich_records(collect_list_records(client), args.workers)
    selected = select_records(records, args.limit, args.family_limit)
    args.reference_dir.mkdir(parents=True, exist_ok=True)
    image_dir = args.reference_dir / "images"
    image_dir.mkdir(parents=True, exist_ok=True)
    output_records = []
    for record in selected:
        number = license_number(record)
        reference_path = download_reference(client, record, image_dir)
        output_records.append(
            {
                "assetKey": asset_key(record),
                "recommendIdx": record["recommendIdx"],
                "sourceTitle": record.get("title", ""),
                "sourceCharacter": source_character(record),
                "familyId": family_id(record),
                "localGovernment": local_government(record),
                "shootingAgency": record.get("shootingAgency", ""),
                "holdingAgency": record.get("holdingAgency", ""),
                "licenseType": f"KOG.L Type {number}" if number is not None else "",
                "licenseNumber": number,
                "licenseMark": record.get("licenseMark", ""),
                "licenseText": record.get("licenseText", ""),
                **license_flags(number),
                "detailUrl": record.get("detailUrl", ""),
                "mainImageUrl": record.get("mainImageUrl", ""),
                "referenceImage": reference_path,
                "tags": record.get("tags", []),
            }
        )
    payload = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "koglHome": f"{BASE_URL}/index.do",
        "filter": {
            "division": "img",
            "middleCode": "B012",
            "searchGubun": "K",
            "allowedKoglTypes": [0, 1, 2],
        },
        "records": output_records,
    }
    (args.reference_dir / "kogl_mascot_sources.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    write_sources_markdown(output_records, args.docs_out)
    return payload


def write_sources_markdown(records: list[dict[str, Any]], target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# KOG.L Source-Driven MasilPet References",
        "",
        "Filter: KOG.L original image works, category B012 (character/logo), KOG.L type 0/1/2 only.",
        "",
        "| # | Asset key | Character | Local government | License | Source |",
        "| ---: | --- | --- | --- | --- | --- |",
    ]
    for index, record in enumerate(records, start=1):
        lines.append(
            f"| {index} | `{record['assetKey']}` | {markdown_cell(record['sourceCharacter'])} | "
            f"{markdown_cell(record['localGovernment'])} | {record['licenseType']} | "
            f"[{markdown_link_text(record['sourceTitle'])}]({record['detailUrl']}) |"
        )
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")


def markdown_cell(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def markdown_link_text(value: Any) -> str:
    return markdown_cell(value).replace("[", "\\[").replace("]", "\\]")


def load_slicer(root: Path) -> Any:
    module_path = root / "tools" / "slice_sprite_sheet.py"
    spec = importlib.util.spec_from_file_location("slice_sprite_sheet", module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def border_background(image: Image.Image) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    samples = []
    for x in range(width):
        samples.append(rgb.getpixel((x, 0)))
        samples.append(rgb.getpixel((x, height - 1)))
    for y in range(height):
        samples.append(rgb.getpixel((0, y)))
        samples.append(rgb.getpixel((width - 1, y)))
    quantized = [(r // 16 * 16, g // 16 * 16, b // 16 * 16) for r, g, b in samples]
    return Counter(quantized).most_common(1)[0][0]


def color_distance(pixel: tuple[int, int, int], bg: tuple[int, int, int]) -> int:
    return abs(pixel[0] - bg[0]) + abs(pixel[1] - bg[1]) + abs(pixel[2] - bg[2])


def foreground_mask(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    rgba.thumbnail((512, 512), Image.Resampling.LANCZOS)
    alpha = rgba.getchannel("A")
    alpha_bbox_value = alpha_bbox(rgba)
    alpha_data = alpha.get_flattened_data() if hasattr(alpha, "get_flattened_data") else alpha.getdata()
    if alpha_bbox_value and len(set(alpha_data)) > 1:
        mask = alpha.point(lambda value: 255 if value > 24 else 0)
    else:
        bg = border_background(rgba)
        rgb = rgba.convert("RGB")
        mask = Image.new("L", rgba.size, 0)
        mask_pixels = mask.load()
        rgb_pixels = rgb.load()
        for y in range(rgba.height):
            for x in range(rgba.width):
                pixel = rgb_pixels[x, y]
                whiteish = pixel[0] > 242 and pixel[1] > 242 and pixel[2] > 242
                near_bg = color_distance(pixel, bg) < 72
                mask_pixels[x, y] = 0 if whiteish or near_bg else 255
    mask = mask.filter(ImageFilter.MedianFilter(3))
    return largest_components(mask, keep=2)


def largest_components(mask: Image.Image, keep: int) -> Image.Image:
    mask = mask.point(lambda value: 255 if value > 0 else 0)
    width, height = mask.size
    pixels = mask.load()
    visited = bytearray(width * height)
    components: list[tuple[int, tuple[int, int, int, int], list[tuple[int, int]]]] = []
    for y in range(height):
        for x in range(width):
            index = y * width + x
            if visited[index] or pixels[x, y] == 0:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            visited[index] = 1
            points: list[tuple[int, int]] = []
            min_x = max_x = x
            min_y = max_y = y
            while queue:
                px, py = queue.popleft()
                points.append((px, py))
                min_x = min(min_x, px)
                max_x = max(max_x, px)
                min_y = min(min_y, py)
                max_y = max(max_y, py)
                for nx, ny in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    nindex = ny * width + nx
                    if visited[nindex] or pixels[nx, ny] == 0:
                        continue
                    visited[nindex] = 1
                    queue.append((nx, ny))
            if len(points) >= 30:
                components.append((len(points), (min_x, min_y, max_x + 1, max_y + 1), points))
    if not components:
        return mask
    components.sort(key=lambda item: item[0], reverse=True)
    largest = components[0][0]
    kept = components[:keep]
    kept = [component for component in kept if component[0] >= largest * 0.22]
    output = Image.new("L", mask.size, 0)
    out_pixels = output.load()
    for _, _, points in kept:
        for x, y in points:
            out_pixels[x, y] = 255
    return output.filter(ImageFilter.MaxFilter(3))


def source_cutout(reference: Path) -> Image.Image:
    original = Image.open(reference).convert("RGBA")
    original.thumbnail((512, 512), Image.Resampling.LANCZOS)
    mask = foreground_mask(original)
    if original.size != mask.size:
        original = original.resize(mask.size, Image.Resampling.LANCZOS)
    cutout = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    cutout.paste(original, (0, 0), mask)
    bbox = alpha_bbox(cutout)
    if bbox is None:
        raise ValueError(f"No foreground found in {reference}")
    pad = 8
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(cutout.width, bbox[2] + pad)
    bottom = min(cutout.height, bbox[3] + pad)
    return cutout.crop((left, top, right, bottom))


def quantize_sprite(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (255, 255, 255))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=24, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha.point(lambda value: 255 if value > 32 else 0))
    return quantized


def rebuild_outline(sprite: Image.Image) -> Image.Image:
    alpha = sprite.getchannel("A").point(lambda value: 255 if value > 0 else 0)
    expanded = alpha.filter(ImageFilter.MaxFilter(3))
    outline = ImageChops.subtract(expanded, alpha)
    outlined = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
    outlined.paste(OUTLINE, (0, 0), outline)
    outlined.alpha_composite(sprite)
    return outlined


def base_sprite(reference: Path) -> Image.Image:
    cutout = source_cutout(reference)
    cutout.thumbnail((54, 54), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
    x = (SPRITE_SIZE - cutout.width) // 2
    y = SPRITE_SIZE - cutout.height - 4
    canvas.paste(cutout, (x, y), cutout)
    canvas = quantize_sprite(canvas)
    return rebuild_outline(canvas)


def transform_sprite(sprite: Image.Image, variant: str, frame: int) -> Image.Image:
    working = sprite.copy()
    if variant in {"baby"}:
        working = scale_center(working, 0.74)
    elif variant in {"grown"}:
        working = scale_center(working, 0.94)
    elif variant in {"evolved"}:
        working = scale_center(working, 1.08)
    elif variant in {"jumping", "excited"}:
        working = shift(working, 0, -5)
    elif variant in {"sleeping", "sleepy"} or variant.startswith("sleep"):
        working = working.rotate(-10, resample=Image.Resampling.NEAREST, expand=False)
        working = shift(working, 0, 5)
    elif variant.startswith("walk"):
        working = shift(working.rotate([-4, 2, 4, -2][frame % 4], resample=Image.Resampling.NEAREST, expand=False), [-3, -1, 2, 0][frame % 4], [1, 0, 1, 0][frame % 4])
    elif variant.startswith("idle"):
        working = shift(working, 0, [0, -1, 0, 1][frame % 4])
    elif variant.startswith("greet") or variant == "greeting":
        working = shift(working, 0, [0, -2, 0, -1][frame % 4])
    elif variant.startswith("eat") or variant == "eating":
        working = shift(working, [0, 1, 0, -1][frame % 4], 0)

    draw = ImageDraw.Draw(working)
    if variant in {"happy", "excited", "greeting"} or variant.startswith("greet"):
        draw_blush(draw)
    if variant == "sad":
        draw.ellipse((45, 27, 50, 35), fill=(85, 170, 255, 255))
    if variant == "surprised":
        draw.ellipse((28, 43, 36, 50), fill=OUTLINE)
        draw.ellipse((31, 45, 33, 48), fill=(255, 255, 255, 255))
    if variant in {"sleeping", "sleepy"} or variant.startswith("sleep"):
        draw.line((23, 25, 30, 25), fill=OUTLINE, width=2)
        draw.line((35, 25, 42, 25), fill=OUTLINE, width=2)
    if variant == "evolved":
        draw.ellipse((48, 12, 55, 19), fill=OUTLINE)
        draw.ellipse((50, 14, 53, 17), fill=(255, 232, 96, 255))
    if variant in {"eating"} or variant.startswith("eat"):
        draw.rounded_rectangle((44, 43, 57, 52), radius=2, fill=OUTLINE)
        draw.rounded_rectangle((46, 44, 55, 50), radius=1, fill=(255, 220, 120, 255))
    return rebuild_outline(working)


def draw_blush(draw: ImageDraw.ImageDraw) -> None:
    draw.ellipse((13, 32, 20, 37), fill=(255, 150, 174, 210))
    draw.ellipse((44, 32, 51, 37), fill=(255, 150, 174, 210))


def scale_center(sprite: Image.Image, factor: float) -> Image.Image:
    bbox = alpha_bbox(sprite)
    if bbox is None:
        return sprite
    crop = sprite.crop(bbox)
    new_size = (max(1, round(crop.width * factor)), max(1, round(crop.height * factor)))
    crop = crop.resize(new_size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
    x = (SPRITE_SIZE - crop.width) // 2
    y = SPRITE_SIZE - crop.height - 4
    canvas.paste(crop, (x, y), crop)
    return canvas


def shift(sprite: Image.Image, dx: int, dy: int) -> Image.Image:
    canvas = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
    canvas.paste(sprite, (dx, dy), sprite)
    return canvas


def upscale(sprite: Image.Image) -> Image.Image:
    return sprite.resize((CELL_SIZE, CELL_SIZE), Image.Resampling.NEAREST)


AA_SCALE = 3


@dataclass(frozen=True)
class ChibiProfile:
    family: str
    kind: str
    main: tuple[int, int, int, int]
    accent: tuple[int, int, int, int]
    secondary: tuple[int, int, int, int]
    skin: tuple[int, int, int, int]
    outline: tuple[int, int, int, int]
    blush: tuple[int, int, int, int]
    variant: int


FAMILY_STYLE: dict[str, dict[str, Any]] = {
    "kijang_friends": {
        "kind": "food_bowl",
        "main": "#f6d66c",
        "accent": "#4ec7b0",
        "secondary": "#f07ca2",
    },
    "gunsan_nureongi": {
        "kind": "egg_blob",
        "main": "#f6ecaa",
        "accent": "#d6cf72",
        "secondary": "#f7b7a3",
    },
    "gunsan_sani": {
        "kind": "egg_blob",
        "main": "#7ecb63",
        "accent": "#eef2a4",
        "secondary": "#f7b7a3",
    },
    "gunsan_kuni": {
        "kind": "egg_blob",
        "main": "#f4a23f",
        "accent": "#f8d47f",
        "secondary": "#88c95a",
    },
    "hwaseong_koriyo": {
        "kind": "dino",
        "main": "#f5bf3e",
        "accent": "#6fc66f",
        "secondary": "#785a38",
    },
    "seosan_haenuri_haenari": {
        "kind": "human",
        "main": "#f28d32",
        "accent": "#2f84c8",
        "secondary": "#f7cf5a",
    },
    "seosan_gati_oshu": {
        "kind": "soft_creature",
        "main": "#efe3d1",
        "accent": "#9fd7ec",
        "secondary": "#f5b6c9",
    },
    "dongnae_ttugi_ttumi": {
        "kind": "pot",
        "main": "#2e3446",
        "accent": "#9ed6e8",
        "secondary": "#f0f4f6",
    },
    "ulju_haetteumi": {
        "kind": "sun",
        "main": "#f8d34b",
        "accent": "#f39a3d",
        "secondary": "#f9f0a4",
    },
    "ulsan_bigaegi": {
        "kind": "human",
        "main": "#ed514f",
        "accent": "#161b2a",
        "secondary": "#f4c07b",
    },
    "gwangju_chungjang_friends": {
        "kind": "round_pet",
        "main": "#f4a3c6",
        "accent": "#7fc7e8",
        "secondary": "#f6e56f",
    },
    "jecheon_jeje_cheoncheoni": {
        "kind": "pot",
        "main": "#303542",
        "accent": "#6fb7d4",
        "secondary": "#d9edf3",
    },
    "jincheon_won": {
        "kind": "human",
        "main": "#b86a45",
        "accent": "#4d9c58",
        "secondary": "#d85c63",
    },
    "guri_waguri": {
        "kind": "round_pet",
        "main": "#c9955b",
        "accent": "#5da765",
        "secondary": "#7d5738",
    },
    "guri_ppoguri": {
        "kind": "round_pet",
        "main": "#c9955b",
        "accent": "#5c92bd",
        "secondary": "#7d5738",
    },
    "guri_arimi": {
        "kind": "round_pet",
        "main": "#6ea3c6",
        "accent": "#2f6f9f",
        "secondary": "#bfddec",
    },
}


def hex_rgba(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def with_alpha(color: tuple[int, int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return (color[0], color[1], color[2], alpha)


def blend(
    color: tuple[int, int, int, int],
    target: tuple[int, int, int, int],
    amount: float,
) -> tuple[int, int, int, int]:
    return (
        round(color[0] + (target[0] - color[0]) * amount),
        round(color[1] + (target[1] - color[1]) * amount),
        round(color[2] + (target[2] - color[2]) * amount),
        round(color[3] + (target[3] - color[3]) * amount),
    )


def lighten(color: tuple[int, int, int, int], amount: float) -> tuple[int, int, int, int]:
    return blend(color, (255, 255, 255, color[3]), amount)


def darken(color: tuple[int, int, int, int], amount: float) -> tuple[int, int, int, int]:
    return blend(color, (0, 0, 0, color[3]), amount)


def colorfulness(color: tuple[int, int, int]) -> int:
    return max(color) - min(color)


def extracted_palette(reference: Path, limit: int = 8) -> list[tuple[int, int, int, int]]:
    with Image.open(reference) as raw:
        image = raw.convert("RGBA")
    image.thumbnail((256, 256), Image.Resampling.LANCZOS)
    mask = foreground_mask(image)
    rgb = Image.new("RGB", image.size, (255, 255, 255))
    rgb.paste(image.convert("RGB"), mask=mask)
    sample = rgb.quantize(colors=16, method=Image.Quantize.MEDIANCUT).convert("RGB")
    counts: Counter[tuple[int, int, int]] = Counter()
    mask_pixels = mask.load()
    sample_pixels = sample.load()
    for y in range(sample.height):
        for x in range(sample.width):
            if mask_pixels[x, y] == 0:
                continue
            r, g, b = sample_pixels[x, y]
            if r > 240 and g > 240 and b > 240:
                continue
            if r < 24 and g < 24 and b < 24:
                continue
            counts[(r, g, b)] += 1
    ranked = sorted(
        counts,
        key=lambda item: (counts[item] * (1 + min(colorfulness(item), 120) / 120)),
        reverse=True,
    )
    return [(r, g, b, 255) for r, g, b in ranked[:limit]]


def chibi_profile(record: dict[str, Any], reference: Path) -> ChibiProfile:
    family = record.get("familyId") or family_id(record)
    style = FAMILY_STYLE.get(family, {"kind": "round_pet", "main": "#d6a46a", "accent": "#6fb7d4", "secondary": "#f4d36f"})
    palette = extracted_palette(reference)
    main = hex_rgba(style["main"])
    accent = hex_rgba(style["accent"])
    secondary = hex_rgba(style["secondary"])
    if palette:
        candidate = palette[0]
        if colorfulness(candidate[:3]) > 32:
            main = blend(main, candidate, 0.28)
    if len(palette) > 1 and colorfulness(palette[1][:3]) > 24:
        accent = blend(accent, palette[1], 0.22)
    if len(palette) > 2 and colorfulness(palette[2][:3]) > 24:
        secondary = blend(secondary, palette[2], 0.18)
    return ChibiProfile(
        family=family,
        kind=style["kind"],
        main=main,
        accent=accent,
        secondary=secondary,
        skin=hex_rgba("#ffd8be"),
        outline=hex_rgba("#22222a"),
        blush=(255, 142, 164, 210),
        variant=int(record["recommendIdx"]) % 6,
    )


class ScaledCanvas:
    def __init__(self) -> None:
        self.image = Image.new("RGBA", (CELL_SIZE * AA_SCALE, CELL_SIZE * AA_SCALE), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def xy(self, values: Iterable[float]) -> tuple[int, ...]:
        return tuple(round(value * AA_SCALE) for value in values)

    def ellipse(
        self,
        box: tuple[float, float, float, float],
        fill: tuple[int, int, int, int],
        outline: tuple[int, int, int, int] | None = None,
        width: int = 1,
    ) -> None:
        self.draw.ellipse(self.xy(box), fill=fill, outline=outline, width=max(1, width * AA_SCALE))

    def rounded(
        self,
        box: tuple[float, float, float, float],
        radius: float,
        fill: tuple[int, int, int, int],
        outline: tuple[int, int, int, int] | None = None,
        width: int = 1,
    ) -> None:
        self.draw.rounded_rectangle(
            self.xy(box),
            radius=round(radius * AA_SCALE),
            fill=fill,
            outline=outline,
            width=max(1, width * AA_SCALE),
        )

    def polygon(self, points: list[tuple[float, float]], fill: tuple[int, int, int, int]) -> None:
        self.draw.polygon([self.xy(point) for point in points], fill=fill)

    def line(
        self,
        points: list[tuple[float, float]],
        fill: tuple[int, int, int, int],
        width: int,
    ) -> None:
        self.draw.line([self.xy(point) for point in points], fill=fill, width=max(1, width * AA_SCALE), joint="curve")

    def downsample(self) -> Image.Image:
        return self.image.resize((CELL_SIZE, CELL_SIZE), Image.Resampling.LANCZOS)


def draw_face(
    canvas: ScaledCanvas,
    profile: ChibiProfile,
    center_x: float,
    center_y: float,
    expression: str,
    scale: float = 1.0,
) -> None:
    outline = profile.outline
    blush = profile.blush
    if expression in {"sleeping", "sleepy"}:
        canvas.line(
            [(center_x - 54 * scale, center_y - 8 * scale), (center_x - 28 * scale, center_y - 8 * scale)],
            outline,
            round(5 * scale),
        )
        canvas.line(
            [(center_x + 28 * scale, center_y - 8 * scale), (center_x + 54 * scale, center_y - 8 * scale)],
            outline,
            round(5 * scale),
        )
    elif expression == "happy":
        canvas.ellipse((center_x - 61 * scale, center_y - 30 * scale, center_x - 25 * scale, center_y + 6 * scale), outline)
        canvas.ellipse((center_x + 25 * scale, center_y - 30 * scale, center_x + 61 * scale, center_y + 6 * scale), outline)
        canvas.ellipse((center_x - 50 * scale, center_y - 23 * scale, center_x - 36 * scale, center_y - 9 * scale), (255, 255, 255, 235))
        canvas.ellipse((center_x + 36 * scale, center_y - 23 * scale, center_x + 50 * scale, center_y - 9 * scale), (255, 255, 255, 235))
    elif expression == "surprised":
        canvas.ellipse((center_x - 63 * scale, center_y - 36 * scale, center_x - 25 * scale, center_y + 4 * scale), outline)
        canvas.ellipse((center_x + 25 * scale, center_y - 36 * scale, center_x + 63 * scale, center_y + 4 * scale), outline)
        canvas.ellipse((center_x - 52 * scale, center_y - 25 * scale, center_x - 42 * scale, center_y - 15 * scale), (255, 255, 255, 240))
        canvas.ellipse((center_x + 42 * scale, center_y - 25 * scale, center_x + 52 * scale, center_y - 15 * scale), (255, 255, 255, 240))
    else:
        canvas.ellipse((center_x - 61 * scale, center_y - 34 * scale, center_x - 27 * scale, center_y + 8 * scale), outline)
        canvas.ellipse((center_x + 27 * scale, center_y - 34 * scale, center_x + 61 * scale, center_y + 8 * scale), outline)
        canvas.ellipse((center_x - 51 * scale, center_y - 25 * scale, center_x - 41 * scale, center_y - 15 * scale), (255, 255, 255, 245))
        canvas.ellipse((center_x + 41 * scale, center_y - 25 * scale, center_x + 51 * scale, center_y - 15 * scale), (255, 255, 255, 245))
    canvas.ellipse((center_x - 91 * scale, center_y + 12 * scale, center_x - 50 * scale, center_y + 35 * scale), blush)
    canvas.ellipse((center_x + 50 * scale, center_y + 12 * scale, center_x + 91 * scale, center_y + 35 * scale), blush)
    if expression == "sad":
        canvas.line(
            [(center_x - 18 * scale, center_y + 54 * scale), (center_x, center_y + 44 * scale), (center_x + 18 * scale, center_y + 54 * scale)],
            outline,
            round(4 * scale),
        )
        canvas.ellipse((center_x + 70 * scale, center_y - 4 * scale, center_x + 91 * scale, center_y + 24 * scale), (94, 174, 245, 230))
    elif expression == "surprised":
        canvas.ellipse((center_x - 16 * scale, center_y + 32 * scale, center_x + 16 * scale, center_y + 65 * scale), outline)
        canvas.ellipse((center_x - 6 * scale, center_y + 40 * scale, center_x + 6 * scale, center_y + 55 * scale), (255, 255, 255, 230))
    elif expression in {"sleeping", "sleepy"}:
        canvas.line(
            [(center_x - 16 * scale, center_y + 38 * scale), (center_x + 16 * scale, center_y + 38 * scale)],
            outline,
            round(4 * scale),
        )
    else:
        canvas.line(
            [(center_x - 18 * scale, center_y + 35 * scale), (center_x, center_y + 48 * scale), (center_x + 18 * scale, center_y + 35 * scale)],
            outline,
            round(4 * scale),
        )


def draw_tiny_limbs(canvas: ScaledCanvas, profile: ChibiProfile, raised: bool = False) -> None:
    outline = profile.outline
    hand = lighten(profile.main, 0.25)
    if raised:
        canvas.ellipse((112, 236, 166, 291), outline)
        canvas.ellipse((122, 245, 156, 280), hand)
        canvas.ellipse((347, 166, 405, 223), outline)
        canvas.ellipse((357, 176, 394, 213), hand)
    else:
        canvas.ellipse((96, 284, 153, 345), outline)
        canvas.ellipse((107, 294, 143, 334), hand)
        canvas.ellipse((359, 284, 416, 345), outline)
        canvas.ellipse((369, 294, 405, 334), hand)
    canvas.ellipse((166, 400, 226, 454), outline)
    canvas.ellipse((178, 408, 217, 442), lighten(profile.main, 0.12))
    canvas.ellipse((286, 400, 346, 454), outline)
    canvas.ellipse((295, 408, 334, 442), lighten(profile.main, 0.12))


def draw_accessory(canvas: ScaledCanvas, profile: ChibiProfile) -> None:
    outline = profile.outline
    choice = profile.variant
    if choice == 0:
        canvas.polygon([(359, 91), (389, 66), (414, 94), (389, 122)], outline)
        canvas.polygon([(371, 93), (389, 78), (403, 95), (389, 110)], lighten(profile.secondary, 0.15))
    elif choice == 1:
        canvas.ellipse((349, 84, 411, 139), outline)
        canvas.ellipse((361, 95, 399, 128), lighten(profile.accent, 0.15))
    elif choice == 2:
        canvas.line([(364, 98), (405, 72)], outline, 8)
        canvas.ellipse((395, 56, 431, 88), outline)
        canvas.ellipse((402, 62, 424, 82), lighten(profile.accent, 0.18))
    elif choice == 3:
        canvas.rounded((348, 87, 414, 130), 14, outline)
        canvas.rounded((360, 97, 402, 120), 9, lighten(profile.secondary, 0.1))
    elif choice == 4:
        canvas.ellipse((364, 61, 398, 95), outline)
        canvas.ellipse((372, 69, 390, 87), lighten(profile.accent, 0.22))


def draw_egg_blob(canvas: ScaledCanvas, profile: ChibiProfile, expression: str, raised: bool) -> None:
    outline = profile.outline
    canvas.ellipse((116, 70, 396, 426), outline)
    canvas.ellipse((131, 86, 381, 412), lighten(profile.main, 0.04))
    canvas.ellipse((164, 72, 348, 175), outline)
    canvas.ellipse((178, 84, 334, 157), lighten(profile.accent, 0.12))
    draw_tiny_limbs(canvas, profile, raised)
    draw_face(canvas, profile, 256, 241, expression)
    draw_accessory(canvas, profile)


def draw_round_pet(canvas: ScaledCanvas, profile: ChibiProfile, expression: str, raised: bool) -> None:
    outline = profile.outline
    canvas.ellipse((105, 122, 205, 238), outline)
    canvas.ellipse((307, 122, 407, 238), outline)
    canvas.ellipse((120, 138, 195, 230), lighten(profile.secondary, 0.18))
    canvas.ellipse((317, 138, 392, 230), lighten(profile.secondary, 0.18))
    canvas.ellipse((104, 88, 408, 424), outline)
    canvas.ellipse((120, 104, 392, 411), lighten(profile.main, 0.06))
    canvas.ellipse((170, 151, 342, 315), lighten(profile.main, 0.18))
    draw_tiny_limbs(canvas, profile, raised)
    canvas.line([(382, 326), (424, 309), (443, 342), (407, 365)], outline, 9)
    canvas.line([(386, 326), (419, 315), (432, 340), (404, 356)], lighten(profile.accent, 0.12), 6)
    draw_face(canvas, profile, 256, 244, expression)
    draw_accessory(canvas, profile)


def draw_dino(canvas: ScaledCanvas, profile: ChibiProfile, expression: str, raised: bool) -> None:
    outline = profile.outline
    canvas.polygon([(169, 82), (197, 44), (226, 89)], outline)
    canvas.polygon([(231, 66), (258, 34), (286, 70)], outline)
    canvas.polygon([(293, 82), (323, 44), (349, 91)], outline)
    canvas.polygon([(184, 83), (198, 63), (212, 89)], lighten(profile.accent, 0.18))
    canvas.polygon([(244, 68), (258, 52), (272, 72)], lighten(profile.accent, 0.18))
    canvas.polygon([(308, 85), (323, 63), (336, 92)], lighten(profile.accent, 0.18))
    canvas.ellipse((100, 82, 412, 420), outline)
    canvas.ellipse((119, 99, 391, 405), lighten(profile.main, 0.04))
    canvas.ellipse((248, 214, 399, 318), outline)
    canvas.ellipse((260, 226, 388, 307), lighten(profile.secondary, 0.26))
    canvas.line([(374, 331), (438, 304), (456, 344), (401, 371)], outline, 12)
    canvas.line([(379, 333), (432, 313), (443, 341), (401, 361)], lighten(profile.main, 0.08), 8)
    draw_tiny_limbs(canvas, profile, raised)
    draw_face(canvas, profile, 242, 231, expression)
    draw_accessory(canvas, profile)


def draw_sun(canvas: ScaledCanvas, profile: ChibiProfile, expression: str, raised: bool) -> None:
    outline = profile.outline
    rays = [
        [(256, 44), (279, 100), (233, 100)],
        [(377, 82), (359, 141), (324, 110)],
        [(431, 220), (373, 238), (382, 190)],
        [(379, 386), (326, 353), (362, 325)],
        [(134, 386), (151, 326), (187, 355)],
        [(80, 220), (136, 191), (142, 240)],
        [(136, 82), (188, 110), (153, 143)],
    ]
    for ray in rays:
        canvas.polygon(ray, outline)
        inner = [(x * 0.92 + 256 * 0.08, y * 0.92 + 250 * 0.08) for x, y in ray]
        canvas.polygon(inner, lighten(profile.accent, 0.15))
    canvas.ellipse((95, 87, 417, 421), outline)
    canvas.ellipse((113, 105, 399, 403), lighten(profile.main, 0.06))
    draw_tiny_limbs(canvas, profile, raised)
    draw_face(canvas, profile, 256, 248, expression)


def draw_human(canvas: ScaledCanvas, profile: ChibiProfile, expression: str, raised: bool) -> None:
    outline = profile.outline
    hair = profile.main if profile.family != "ulsan_bigaegi" else profile.accent
    outfit = profile.accent if profile.family != "ulsan_bigaegi" else profile.main
    canvas.rounded((178, 287, 334, 430), 43, outline)
    canvas.rounded((193, 301, 319, 417), 35, lighten(outfit, 0.06))
    canvas.ellipse((121, 74, 391, 342), outline)
    canvas.ellipse((140, 95, 372, 330), profile.skin)
    canvas.ellipse((123, 63, 393, 210), outline)
    canvas.ellipse((142, 80, 374, 197), lighten(hair, 0.05))
    canvas.ellipse((125, 148, 179, 232), outline)
    canvas.ellipse((333, 148, 387, 232), outline)
    canvas.ellipse((137, 159, 171, 221), lighten(hair, 0.05))
    canvas.ellipse((341, 159, 375, 221), lighten(hair, 0.05))
    if raised:
        canvas.ellipse((113, 255, 168, 313), outline)
        canvas.ellipse((124, 266, 157, 301), profile.skin)
        canvas.ellipse((344, 190, 404, 252), outline)
        canvas.ellipse((355, 201, 392, 241), profile.skin)
    else:
        canvas.ellipse((118, 303, 173, 361), outline)
        canvas.ellipse((129, 314, 162, 349), profile.skin)
        canvas.ellipse((339, 303, 394, 361), outline)
        canvas.ellipse((350, 314, 383, 349), profile.skin)
    canvas.ellipse((178, 405, 228, 458), outline)
    canvas.ellipse((284, 405, 334, 458), outline)
    canvas.ellipse((188, 415, 219, 446), lighten(outfit, 0.18))
    canvas.ellipse((293, 415, 324, 446), lighten(outfit, 0.18))
    draw_face(canvas, profile, 256, 232, expression)
    draw_accessory(canvas, profile)


def draw_pot(canvas: ScaledCanvas, profile: ChibiProfile, expression: str, raised: bool) -> None:
    outline = profile.outline
    canvas.ellipse((123, 84, 389, 266), outline)
    canvas.ellipse((143, 106, 369, 246), darken(profile.main, 0.02))
    canvas.rounded((116, 164, 396, 420), 78, outline)
    canvas.rounded((136, 184, 376, 402), 64, lighten(profile.main, 0.08))
    canvas.ellipse((150, 130, 362, 220), darken(profile.main, 0.24))
    canvas.ellipse((176, 148, 336, 205), lighten(profile.accent, 0.18))
    draw_tiny_limbs(canvas, profile, raised)
    draw_face(canvas, profile, 256, 279, expression, 0.9)
    draw_accessory(canvas, profile)


def draw_soft_creature(canvas: ScaledCanvas, profile: ChibiProfile, expression: str, raised: bool) -> None:
    outline = profile.outline
    canvas.ellipse((94, 157, 234, 303), outline)
    canvas.ellipse((278, 156, 418, 304), outline)
    canvas.ellipse((87, 210, 425, 423), outline)
    canvas.ellipse((109, 176, 240, 290), lighten(profile.main, 0.05))
    canvas.ellipse((272, 176, 403, 290), lighten(profile.secondary, 0.18))
    canvas.ellipse((107, 228, 405, 407), lighten(profile.main, 0.08))
    draw_tiny_limbs(canvas, profile, raised)
    draw_face(canvas, profile, 256, 277, expression, 0.88)
    draw_accessory(canvas, profile)


def draw_food_bowl(canvas: ScaledCanvas, profile: ChibiProfile, expression: str, raised: bool) -> None:
    outline = profile.outline
    canvas.ellipse((107, 146, 405, 291), outline)
    canvas.ellipse((126, 163, 386, 273), lighten(profile.secondary, 0.26))
    canvas.rounded((116, 222, 396, 410), 78, outline)
    canvas.rounded((135, 238, 377, 392), 66, lighten(profile.main, 0.1))
    canvas.ellipse((167, 87, 345, 251), outline)
    canvas.ellipse((183, 103, 329, 235), lighten(profile.accent, 0.12))
    canvas.ellipse((114, 196, 206, 285), outline)
    canvas.ellipse((130, 211, 194, 271), lighten(profile.secondary, 0.12))
    canvas.ellipse((306, 196, 398, 285), outline)
    canvas.ellipse((318, 211, 383, 271), lighten(profile.secondary, 0.12))
    draw_tiny_limbs(canvas, profile, raised)
    draw_face(canvas, profile, 256, 210, expression, 0.82)
    draw_accessory(canvas, profile)


def render_chibi_design(profile: ChibiProfile, variant: str, frame: int) -> Image.Image:
    expression = {
        "neutral": "neutral",
        "idle": "neutral",
        "happy": "happy",
        "excited": "happy",
        "jumping": "happy",
        "greeting": "happy",
        "sad": "sad",
        "surprised": "surprised",
        "sleeping": "sleeping",
        "sleepy": "sleepy",
    }.get(variant, "neutral")
    if variant.startswith("sleep"):
        expression = "sleeping"
    elif variant.startswith("greet"):
        expression = "happy"
    elif variant.startswith("eat"):
        expression = "happy"
    raised = variant in {"greeting", "excited"} or variant.startswith("greet")
    canvas = ScaledCanvas()
    if profile.kind == "egg_blob":
        draw_egg_blob(canvas, profile, expression, raised)
    elif profile.kind == "dino":
        draw_dino(canvas, profile, expression, raised)
    elif profile.kind == "human":
        draw_human(canvas, profile, expression, raised)
    elif profile.kind == "pot":
        draw_pot(canvas, profile, expression, raised)
    elif profile.kind == "sun":
        draw_sun(canvas, profile, expression, raised)
    elif profile.kind == "soft_creature":
        draw_soft_creature(canvas, profile, expression, raised)
    elif profile.kind == "food_bowl":
        draw_food_bowl(canvas, profile, expression, raised)
    else:
        draw_round_pet(canvas, profile, expression, raised)
    sprite = canvas.downsample()
    if variant in {"eating"} or variant.startswith("eat"):
        draw = ImageDraw.Draw(sprite)
        draw.rounded_rectangle((342, 353, 431, 407), radius=18, fill=profile.outline)
        draw.rounded_rectangle((356, 364, 417, 394), radius=14, fill=lighten(profile.secondary, 0.18))
        draw.ellipse((377, 343, 405, 371), fill=lighten(profile.accent, 0.2))
    if variant == "evolved":
        draw = ImageDraw.Draw(sprite)
        draw.ellipse((363, 73, 414, 124), fill=profile.outline)
        draw.ellipse((374, 83, 403, 113), fill=lighten(profile.secondary, 0.08))
    return apply_chibi_pose(sprite, variant, frame)


def apply_chibi_pose(sprite: Image.Image, variant: str, frame: int) -> Image.Image:
    bbox = alpha_bbox(sprite)
    if bbox is None:
        return sprite
    crop = sprite.crop(bbox)
    scale = 1.0
    angle = 0
    dx = 0
    dy = 0
    if variant == "baby":
        scale = 0.78
        dy = 18
    elif variant == "grown":
        scale = 0.96
    elif variant == "evolved":
        scale = 1.05
        dy = -8
    elif variant in {"jumping", "excited"}:
        dy = -30
    elif variant in {"sleeping", "sleepy"} or variant.startswith("sleep"):
        angle = -12
        dy = 28
    elif variant.startswith("walk"):
        angle = [-4, 2, 4, -2][frame % 4]
        dx = [-11, -3, 8, 0][frame % 4]
        dy = [6, 0, 5, 0][frame % 4]
    elif variant.startswith("idle"):
        dy = [0, -6, 0, 5][frame % 4]
    elif variant.startswith("greet"):
        angle = [-2, 3, -2, 2][frame % 4]
        dy = [0, -9, 0, -5][frame % 4]
    elif variant.startswith("eat"):
        dx = [0, 5, 0, -4][frame % 4]
    if scale != 1.0:
        crop = crop.resize((round(crop.width * scale), round(crop.height * scale)), Image.Resampling.LANCZOS)
    if angle:
        crop = crop.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    x = (CELL_SIZE - crop.width) // 2 + dx
    y = CELL_SIZE - crop.height - 38 + dy
    canvas.alpha_composite(crop, (x, y))
    return canvas


def make_chibi_sheet(profile: ChibiProfile, rows: int, cols: int, variants: list[str]) -> Image.Image:
    sheet = Image.new("RGBA", (cols * CELL_SIZE, rows * CELL_SIZE), (0, 0, 0, 0))
    for index, variant in enumerate(variants):
        sprite = render_chibi_design(profile, variant, index)
        x = index % cols * CELL_SIZE
        y = index // cols * CELL_SIZE
        sheet.alpha_composite(sprite, (x, y))
    return sheet


def make_sheet(base: Image.Image, rows: int, cols: int, variants: list[str]) -> Image.Image:
    sheet = Image.new("RGBA", (cols * CELL_SIZE, rows * CELL_SIZE), (0, 0, 0, 0))
    for index, variant in enumerate(variants):
        sprite = transform_sprite(base, variant, index)
        cell = upscale(sprite)
        x = index % cols * CELL_SIZE
        y = index // cols * CELL_SIZE
        sheet.paste(cell, (x, y), cell)
    return sheet


def generate_sheets(root: Path, record: dict[str, Any]) -> list[tuple[str, Path]]:
    reference = root / record["referenceImage"]
    pet_id = record["assetKey"]
    incoming = root / "assets" / "_incoming" / pet_id
    incoming.mkdir(parents=True, exist_ok=True)
    shutil.copy2(reference, incoming / f"reference{reference.suffix.lower()}")
    with contextlib.suppress(FileNotFoundError):
        (incoming / "base_pixel_reference.png").unlink()
    profile = chibi_profile(record, reference)
    base = render_chibi_design(profile, "idle", 0)
    base.save(incoming / "base_sd_chibi_reference.png")
    outputs: list[tuple[str, Path]] = []
    for sheet_type, (file_name, rows, cols, variants) in SHEET_SPECS.items():
        target = incoming / file_name
        make_chibi_sheet(profile, rows, cols, variants).save(target)
        outputs.append((sheet_type, target))
    return outputs


def slice_sheets(root: Path, slicer: Any, pet_id: str, sheets: Iterable[tuple[str, Path]], verbose: bool) -> None:
    for sheet_type, path in sheets:
        args = [
            "--pet-id",
            pet_id,
            "--sheet-type",
            sheet_type,
            "--input",
            str(path),
            "--root",
            str(root),
            "--overwrite",
            "--resample",
            "lanczos",
            "--fit-size",
            "438",
            "--alpha-threshold",
            "8",
            "--no-quantize",
            "--no-color-snap",
        ]
        if verbose:
            exit_code = slicer.run(args)
        else:
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                exit_code = slicer.run(args)
        if exit_code != 0:
            raise RuntimeError(f"Slicing failed for {pet_id} {sheet_type}")


def add_manifest_source(root: Path, record: dict[str, Any]) -> None:
    path = root / "assets" / "pets" / record["assetKey"] / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["koglSource"] = record
    manifest["generation"] = {
        "method": "source_feature_sd_chibi_redesign",
        "sourceUse": "reference image was used for palette, silhouette family, and mascot cues only; text/logo/official marks are not copied",
        "spriteBase": "512x512 hand-drawn SD chibi-style sprite sheet cells, sliced by tools/slice_sprite_sheet.py",
    }
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def update_pubspec(root: Path, records: list[dict[str, Any]]) -> None:
    path = root / "pubspec.yaml"
    text = path.read_text(encoding="utf-8")
    existing = set(re.findall(r"^\s+- (assets/pets/[^ \n]+/)\s*$", text, flags=re.MULTILINE))
    lines = []
    for record in records:
        for folder in ("actions", "emotions", "growth", "animations"):
            entry = f"assets/pets/{record['assetKey']}/{folder}/"
            if entry not in existing:
                lines.append(f"    - {entry}")
                existing.add(entry)
    if lines:
        path.write_text(text.rstrip() + "\n" + "\n".join(lines) + "\n", encoding="utf-8")


def load_payload(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def generate(args: argparse.Namespace) -> None:
    root = args.root.resolve()
    payload = load_payload(root / args.sources)
    records = payload["records"][args.offset : args.offset + args.limit]
    slicer = load_slicer(root)
    for index, record in enumerate(records, start=1):
        print(f"[{index}/{len(records)}] {record['assetKey']} from {record['sourceCharacter']}", flush=True)
        sheets = generate_sheets(root, record)
        slice_sheets(root, slicer, record["assetKey"], sheets, args.verbose_slicer)
        add_manifest_source(root, record)
    if args.update_pubspec:
        update_pubspec(root, records)
    generated_keys = [
        record["assetKey"]
        for record in payload["records"]
        if (root / "assets" / "pets" / record["assetKey"] / "manifest.json").exists()
    ]
    summary = {
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "generatedCount": len(generated_keys),
        "assetKeys": generated_keys,
    }
    summary_path = root / "codex-skills" / "masilpet-ai-asset-pipeline" / "references" / "kogl_mascots" / "generated_assets.json"
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def collect_command(args: argparse.Namespace) -> None:
    collect(args)


def all_command(args: argparse.Namespace) -> None:
    payload = collect(args)
    args.sources = args.reference_dir / "kogl_mascot_sources.json"
    args.limit = len(payload["records"])
    args.offset = 0
    generate(args)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    collect_parser = subparsers.add_parser("collect")
    collect_parser.add_argument("--limit", type=int, default=50)
    collect_parser.add_argument("--family-limit", type=int, default=6)
    collect_parser.add_argument("--workers", type=int, default=6)
    collect_parser.add_argument(
        "--reference-dir",
        type=Path,
        default=Path("codex-skills/masilpet-ai-asset-pipeline/references/kogl_mascots"),
    )
    collect_parser.add_argument("--docs-out", type=Path, default=Path("docs/kogl_mascot_sources.md"))
    collect_parser.set_defaults(func=collect_command)

    generate_parser = subparsers.add_parser("generate")
    generate_parser.add_argument("--root", type=Path, default=Path.cwd())
    generate_parser.add_argument(
        "--sources",
        type=Path,
        default=Path("codex-skills/masilpet-ai-asset-pipeline/references/kogl_mascots/kogl_mascot_sources.json"),
    )
    generate_parser.add_argument("--offset", type=int, default=0)
    generate_parser.add_argument("--limit", type=int, default=50)
    generate_parser.add_argument("--update-pubspec", action="store_true")
    generate_parser.add_argument("--verbose-slicer", action="store_true")
    generate_parser.set_defaults(func=generate)

    all_parser = subparsers.add_parser("all")
    all_parser.add_argument("--root", type=Path, default=Path.cwd())
    all_parser.add_argument("--limit", type=int, default=50)
    all_parser.add_argument("--family-limit", type=int, default=6)
    all_parser.add_argument("--workers", type=int, default=6)
    all_parser.add_argument(
        "--reference-dir",
        type=Path,
        default=Path("codex-skills/masilpet-ai-asset-pipeline/references/kogl_mascots"),
    )
    all_parser.add_argument("--docs-out", type=Path, default=Path("docs/kogl_mascot_sources.md"))
    all_parser.add_argument("--update-pubspec", action="store_true")
    all_parser.add_argument("--verbose-slicer", action="store_true")
    all_parser.set_defaults(func=all_command)

    args = parser.parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
