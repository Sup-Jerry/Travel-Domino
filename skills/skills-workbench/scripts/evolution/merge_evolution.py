import datetime
import json
import os
import re
import sys

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
SUSPICIOUS_SUBSTRINGS = (
    "???",
    "锟",
    "�",
)
MOJIBAKE_PUNCT_CHARS = set("銆锛鈥€")


def is_probably_garbled(text):
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


def merge_evolution(skill_dir, new_data_json_str):
    """Merge new evolution data into existing evolution.json."""
    evolution_json_path = os.path.join(skill_dir, "evolution.json")

    if os.path.exists(evolution_json_path):
        try:
            with open(evolution_json_path, "r", encoding="utf-8") as f:
                current_data = json.load(f)
        except Exception:
            current_data = {}
    else:
        current_data = {}

    try:
        new_data = json.loads(new_data_json_str)
    except json.JSONDecodeError as e:
        print(f"Error decoding new data JSON: {e}", file=sys.stderr)
        return False

    for list_key in ("preferences", "fixes", "contexts"):
        value = new_data.get(list_key)
        if isinstance(value, list):
            for idx, item in enumerate(value):
                if is_probably_garbled(item):
                    print(
                        f"Error: garbled text detected in {list_key}[{idx}]",
                        file=sys.stderr,
                    )
                    return False
    custom_prompts = new_data.get("custom_prompts")
    if isinstance(custom_prompts, str) and is_probably_garbled(custom_prompts):
        print("Error: garbled text detected in custom_prompts", file=sys.stderr)
        return False

    current_data["last_updated"] = datetime.datetime.now().isoformat()

    for list_key in ("preferences", "fixes", "contexts"):
        if list_key in new_data:
            existing_list = current_data.get(list_key, [])
            new_items = new_data[list_key]
            if isinstance(new_items, list):
                for item in new_items:
                    if item not in existing_list:
                        existing_list.append(item)
                current_data[list_key] = existing_list

    if "custom_prompts" in new_data:
        current_data["custom_prompts"] = new_data["custom_prompts"]

    if "last_evolved_hash" in new_data:
        current_data["last_evolved_hash"] = new_data["last_evolved_hash"]

    with open(evolution_json_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(current_data, f, indent=2, ensure_ascii=False)

    print(f"Successfully merged evolution data for {os.path.basename(skill_dir)}")
    return True


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python merge_evolution.py <skill_dir> <json_string>")
        sys.exit(1)

    skill_dir = sys.argv[1]
    json_str = sys.argv[2]
    ok = merge_evolution(skill_dir, json_str)
    if not ok:
        sys.exit(1)
