#!/usr/bin/env python3
import json
import re
from pathlib import Path


QUESTION_RUN_RE = re.compile(r"\?{3,}")
MOJIBAKE_MARKERS = "鍦鐢澶鎵鏃鍚鏈璇锛銆榛樿"
REPLACEMENT_CHAR = "\ufffd"
COMMON_SIMPLIFIED = "的了是在和与及或不后前用户代码流程修复问题经验默认"


def is_probably_garbled(text: str) -> bool:
    if not isinstance(text, str) or not text:
        return False
    if REPLACEMENT_CHAR in text:
        return True
    if QUESTION_RUN_RE.search(text):
        return True
    if any(token in text for token in ("锟", "烫", "ï»¿", "Ã", "Â", "鈥")):
        return True
    marker_hits = sum(1 for ch in text if ch in MOJIBAKE_MARKERS)
    if len(text) >= 12 and marker_hits >= 5:
        return True
    if any("\ue000" <= ch <= "\uf8ff" for ch in text):
        return True
    cjk = sum(1 for ch in text if "\u4e00" <= ch <= "\u9fff")
    common_hits = sum(1 for ch in text if ch in COMMON_SIMPLIFIED)
    if cjk >= 8 and common_hits == 0 and marker_hits >= 2:
        return True
    return False


def clean_list(items):
    if not isinstance(items, list):
        return items, 0
    kept = []
    removed = 0
    for item in items:
        if isinstance(item, str) and is_probably_garbled(item):
            removed += 1
            continue
        kept.append(item)
    return kept, removed


def main() -> int:
    repo_root = Path(__file__).resolve().parents[3]
    evolution_files = sorted(repo_root.glob("skills/*/evolution.json"))
    total_removed = 0

    for file_path in evolution_files:
        try:
            data = json.loads(file_path.read_text(encoding="utf-8"))
        except Exception as exc:
            print(f"[skip] {file_path}: {exc}")
            continue

        removed_here = 0
        for key in ("preferences", "fixes", "contexts"):
            cleaned, removed = clean_list(data.get(key))
            data[key] = cleaned
            removed_here += removed

        cp = data.get("custom_prompts")
        if isinstance(cp, str) and is_probably_garbled(cp):
            data["custom_prompts"] = ""
            removed_here += 1

        if removed_here > 0:
            file_path.write_text(
                json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
                newline="\n",
            )
            print(f"[cleaned] {file_path}: removed={removed_here}")
            total_removed += removed_here

    print(f"[done] total_removed={total_removed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
