import os
import sys
import json
import datetime
import re

QUESTION_RUN_RE = re.compile(r"\?{3,}")
MOJIBAKE_MARKERS = "鍦鐢澶鎵鏃鍚鏈璇锛銆榛樿"
REPLACEMENT_CHAR = "\ufffd"
COMMON_SIMPLIFIED = "的了是在和与及或不后前用户代码流程修复问题经验默认"


def is_probably_garbled(text):
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

def merge_evolution(skill_dir, new_data_json_str):
    """
    Merges new evolution data into existing evolution.json.
    Deduplicates list items.
    """
    evolution_json_path = os.path.join(skill_dir, "evolution.json")
    
    # Load existing or create new
    if os.path.exists(evolution_json_path):
        try:
            with open(evolution_json_path, 'r', encoding='utf-8') as f:
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

    # Validate incoming payload to prevent persisting garbled text.
    for list_key in ['preferences', 'fixes', 'contexts']:
        value = new_data.get(list_key)
        if isinstance(value, list):
            for idx, item in enumerate(value):
                if is_probably_garbled(item):
                    print(
                        f"Error: garbled text detected in {list_key}[{idx}]",
                        file=sys.stderr,
                    )
                    return False
    custom_prompts = new_data.get('custom_prompts')
    if isinstance(custom_prompts, str) and is_probably_garbled(custom_prompts):
        print("Error: garbled text detected in custom_prompts", file=sys.stderr)
        return False

    # Merge logic
    # 1. Update timestamp
    current_data['last_updated'] = datetime.datetime.now().isoformat()
    
    # 2. Merge Lists (preferences, fixes, contexts) with deduplication
    for list_key in ['preferences', 'fixes', 'contexts']:
        if list_key in new_data:
            existing_list = current_data.get(list_key, [])
            new_items = new_data[list_key]
            if isinstance(new_items, list):
                # Simple dedupe by string equality
                for item in new_items:
                    if item not in existing_list:
                        existing_list.append(item)
                current_data[list_key] = existing_list
                
    # 3. Overwrite/Append Custom Prompts (Concatenate if exists to preserve history? Or overwrite?)
    # Decision: Overwrite if provided, as prompts usually need to be coherent. 
    # Or, the Agent should have read the old one and combined it before sending here.
    # We assume Agent sends the FINAL desired state for custom_prompts if it wants to merge.
    if 'custom_prompts' in new_data:
        current_data['custom_prompts'] = new_data['custom_prompts']

    # 4. Update last_evolved_hash if provided
    if 'last_evolved_hash' in new_data:
        current_data['last_evolved_hash'] = new_data['last_evolved_hash']

    # Save back
    with open(evolution_json_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(current_data, f, indent=2, ensure_ascii=False)
        
    print(f"Successfully merged evolution data for {os.path.basename(skill_dir)}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python merge_evolution.py <skill_dir> <json_string>")
        sys.exit(1)
        
    skill_dir = sys.argv[1]
    json_str = sys.argv[2]
    merge_evolution(skill_dir, json_str)
