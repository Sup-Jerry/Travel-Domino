#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

QUESTION_RUN_RE = re.compile(r"\?{3,}")
REPLACEMENT_CHAR = "\ufffd"
HIGH_CONFIDENCE_MOJIBAKE_MARKERS = (
    "鐢ㄦ埛",
    "褰撶敤鎴",
    "鎵ц",
    "澶嶇洏",
    "鍚屾",
    "缁忛獙",
    "鐦﹁韩",
    "鍙戝竷",
    "閿欒",
    "璇佹嵁",
    "鍛戒护",
)
SUSPICIOUS_SUBSTRINGS = ("???", "锟", "�")
MOJIBAKE_PUNCT_CHARS = set("銆锛鈥€")


def is_probably_garbled(text: str) -> bool:
    if not isinstance(text, str):
        return False
    value = text.strip()
    if not value:
        return False
    if REPLACEMENT_CHAR in value:
        return True
    if QUESTION_RUN_RE.search(value):
        return True
    if any(token in value for token in SUSPICIOUS_SUBSTRINGS):
        return True
    if any(token in value for token in HIGH_CONFIDENCE_MOJIBAKE_MARKERS):
        return True
    if any(ch in MOJIBAKE_PUNCT_CHARS for ch in value):
        return True
    if any("\ue000" <= ch <= "\uf8ff" for ch in value):
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


def resolve_targets(args):
    repo_root = Path(__file__).resolve().parents[3]
    if not args:
        return sorted(repo_root.glob("skills/*/evolution.json"))
    targets = []
    for raw in args:
        p = Path(raw)
        if not p.is_absolute():
            p = repo_root / raw
        p = p.resolve()
        if p.is_dir():
            p = p / "evolution.json"
        targets.append(p)
    return targets


def main() -> int:
    evolution_files = resolve_targets(sys.argv[1:])
    total_removed = 0

    for file_path in evolution_files:
        if not file_path.exists():
            print(f"[skip] {file_path}: not found")
            continue
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
        else:
            print(f"[ok] {file_path}: removed=0")

    print(f"[done] total_removed={total_removed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
