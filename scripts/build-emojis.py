#!/usr/bin/env python3
"""Build emojis.json from Unicode emoji-test.txt plus Omarchy keywords."""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.request
from pathlib import Path

UNICODE_URL = "https://unicode.org/Public/emoji/latest/emoji-test.txt"
GROUP_MAP = {
    "smileys & emotion": "smileys",
    "people & body": "people",
    "animals & nature": "nature",
    "food & drink": "food",
    "travel & places": "travel",
    "activities": "activities",
    "objects": "objects",
    "symbols": "symbols",
    "flags": "flags",
}
SKIN_TONE_RE = re.compile(r"\b(light|medium-light|medium|medium-dark|dark) skin tone\b")
LINE_RE = re.compile(
    r"^(?P<codes>[0-9A-F ]+)\s*;\s*(?P<status>[^#]+)#\s*(?P<emoji>\S+)\s+E[0-9.]+(?P<name>.*)$"
)


def display_name(name: str) -> str:
    name = name.strip()
    if not name:
        return name
    return name[0].upper() + name[1:]


EXTRA_ALIASES = {
    "😀": "smile happy grinning",
    "😂": "lol lmao cry-laugh tears",
    "🤣": "lol lmao rofl",
    "😊": "smile blush happy",
    "😍": "love crush hearts",
    "👍": "yes like agree ok +1 thumbsup",
    "👎": "no dislike nope -1 thumbsdown",
    "❤️": "love like heart",
    "🔥": "fire lit hot",
    "🙏": "please thanks pray",
    "🎉": "party celebrate tada",
    "✨": "sparkle shine",
    "✅": "yes check done",
    "❌": "no x wrong",
}

def strip_variant(value: str) -> str:
    return value.replace("\ufe0f", "")


def unique_keywords(*parts: str) -> str:
    seen: dict[str, None] = {}
    for part in parts:
        for word in re.split(r"\s+", part.lower()):
            word = word.strip(".,;:()[]{}")
            if not word or word in seen:
                continue
            seen[word] = None
    return " ".join(seen)


def omarchy_keywords(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    out: dict[str, str] = {}
    if not isinstance(data, list):
        return out
    for item in data:
        if not isinstance(item, dict):
            continue
        emoji = item.get("e")
        keywords = item.get("k")
        if isinstance(emoji, str) and isinstance(keywords, str) and emoji:
            out[emoji] = keywords
            stripped = strip_variant(emoji)
            if stripped not in out:
                out[stripped] = keywords
    return out


def parse_emoji_test(text: str) -> list[dict[str, str]]:
    group = ""
    items: list[dict[str, str]] = []
    seen: set[str] = set()
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
            continue
        if not line or line.startswith("#"):
            continue
        match = LINE_RE.match(line)
        if not match:
            continue
        status = match.group("status").strip()
        if status != "fully-qualified":
            continue
        if group.lower() == "component":
            continue
        name = match.group("name").strip()
        if SKIN_TONE_RE.search(name):
            continue
        category = GROUP_MAP.get(group.lower())
        if not category:
            continue
        emoji = match.group("emoji")
        if emoji in seen:
            continue
        seen.add(emoji)
        items.append(
            {
                "e": emoji,
                "n": display_name(name),
                "k": unique_keywords(name),
                "c": category,
            }
        )
    return items


def merge_keywords(items: list[dict[str, str]], extras: dict[str, str]) -> None:
    for item in items:
        extra = extras.get(item["e"], "") or extras.get(strip_variant(item["e"]), "")
        alias = EXTRA_ALIASES.get(item["e"], "") or EXTRA_ALIASES.get(strip_variant(item["e"]), "")
        item["k"] = unique_keywords(item["n"], item["k"], extra, alias)


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read().decode("utf-8")


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    omarchy_path = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
    omarchy_json = omarchy_path / "shell/plugins/emojis/emojis.json"
    out_path = root / "emojis.json"

    try:
        source = fetch(UNICODE_URL)
    except Exception as exc:  # noqa: BLE001
        print(f"failed to download {UNICODE_URL}: {exc}", file=sys.stderr)
        return 1

    items = parse_emoji_test(source)
    merge_keywords(items, omarchy_keywords(omarchy_json))
    out_path.write_text(json.dumps(items, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")

    counts: dict[str, int] = {}
    for item in items:
        counts[item["c"]] = counts.get(item["c"], 0) + 1
    print(f"wrote {len(items)} emojis to {out_path}")
    for category in sorted(counts):
        print(f"  {category}: {counts[category]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
