#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


QUESTION_RUN_RE = re.compile(r"\?{3,}")
MOJIBAKE_MARKERS = "鍦鐢澶鎵鏃鍚鏈璇锛銆榛樿"
REPLACEMENT_CHAR = "\ufffd"
COMMON_SIMPLIFIED = "的了是在和与及或不后前用户代码流程修复问题经验默认"


def is_probably_garbled(text: str) -> bool:
    if not text:
        return False
    if REPLACEMENT_CHAR in text:
        return True
    if QUESTION_RUN_RE.search(text):
        return True

    # Common mojibake signatures from UTF-8/GBK mismatch.
    if any(token in text for token in ("锟", "烫", "ï»¿", "Ã", "Â", "鈥")):
        return True

    marker_hits = sum(1 for ch in text if ch in MOJIBAKE_MARKERS)
    if len(text) >= 12 and marker_hits >= 5:
        return True

    # Private use area chars are strong corruption signal.
    if any("\ue000" <= ch <= "\uf8ff" for ch in text):
        return True

    # Heuristic for UTF-8/GBK mojibake Chinese lines.
    cjk = sum(1 for ch in text if "\u4e00" <= ch <= "\u9fff")
    common_hits = sum(1 for ch in text if ch in COMMON_SIMPLIFIED)
    if cjk >= 8 and common_hits == 0 and marker_hits >= 2:
        return True
    return False


def iter_evolution_items(data: dict):
    for key in ("preferences", "fixes", "contexts"):
        value = data.get(key)
        if isinstance(value, list):
            for idx, item in enumerate(value):
                if isinstance(item, str):
                    yield key, idx, item
    cp = data.get("custom_prompts")
    if isinstance(cp, str):
        yield "custom_prompts", 0, cp


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    evolution_files = sorted(root.glob("skills/*/evolution.json"))
    violations = []

    for file_path in evolution_files:
        try:
            data = json.loads(file_path.read_text(encoding="utf-8"))
        except Exception as exc:
            violations.append((file_path, "parse", f"JSON parse/read failed: {exc}"))
            continue

        for key, idx, text in iter_evolution_items(data):
            if is_probably_garbled(text):
                preview = text[:80].replace("\n", " ")
                violations.append((file_path, f"{key}[{idx}]", preview))

    if not violations:
        print("[encoding-check] OK: no garbled evolution entries found.")
        return 0

    print("[encoding-check] blocked: garbled text found in evolution files:")
    for file_path, loc, preview in violations:
        print(f" - {file_path} :: {loc} :: {preview}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
