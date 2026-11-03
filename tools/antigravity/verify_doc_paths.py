import re
import os
import json
import hashlib

DOCS = [
    "antigravity/INTEGRATION.md",
    "antigravity/CHANGELOG.md",
    "antigravity/STATUS.md",
    "antigravity/VISUAL-AUDIT.md"
]

print("=== 1. VERIFYING SHA256 HASHES IN INTEGRATION.MD ===")
with open("tools/approved-asset-hashes.json", "r", encoding="utf-8") as f:
    approved_hashes = json.load(f)

approved_map = {}
for item in approved_hashes:
    approved_map[item["imported"]] = item["sha256"]

with open("antigravity/INTEGRATION.md", "r", encoding="utf-8") as f:
    integration_text = f.read()

for imported_name, expected_hash in approved_map.items():
    if expected_hash in integration_text:
        print(f"[PASS] Approved asset '{imported_name}' hash {expected_hash} found in INTEGRATION.md")
    else:
        print(f"[FAIL] Approved asset '{imported_name}' hash {expected_hash} NOT found in INTEGRATION.md")

# Also check campus.glb hash
campus_path = "assets/campus.glb"
if os.path.exists(campus_path):
    with open(campus_path, "rb") as f:
        campus_hash = hashlib.sha256(f.read()).hexdigest().upper()
    if campus_hash in integration_text:
        print(f"[PASS] campus.glb hash {campus_hash} found in INTEGRATION.md")
    else:
        print(f"[FAIL] campus.glb hash {campus_hash} NOT found in INTEGRATION.md")

print("\n=== 2. EXTRACTING AND VERIFYING FILE PATHS IN ALL 4 DOCS ===")

# Look for patterns like backticked paths, markdown links, res:// paths
path_pattern = re.compile(r'(`|\[.*?\]\()(?:res://)?([a-zA-Z0-9_\-\./\\]+\.[a-zA-Z0-9_\-]+)(`|\))')
# Also general token pattern for file paths
token_pattern = re.compile(r'(?:res://)?((?:assets|scripts|tools|docs|antigravity|[a-zA-Z0-9_\-]+)/[a-zA-Z0-9_\-\./\\]+\.[a-zA-Z0-9_\-]+|[a-zA-Z0-9_\-]+\.(?:tscn|godot|cmd|glb|json|png|gd|md))')

extracted = set()

for doc in DOCS:
    with open(doc, "r", encoding="utf-8") as f:
        text = f.read()
    
    # matches from backticks / links
    for m in path_pattern.finditer(text):
        path = m.group(2).strip()
        extracted.add((doc, path))
        
    # matches from token pattern
    for m in token_pattern.finditer(text):
        path = m.group(1).strip()
        extracted.add((doc, path))

# Normalize and test
results = []
missing = []
found = []

# Exclude non-file strings that might match regex accidentally (e.g. version numbers or markdown artifacts)
ignore_list = {
    "2.0.0", "1.0.0", "2.0.0-rc1", "0.08", "0.10", "0.11", "0.12", "0.18", "0.20", "0.28", "0.32", "0.36", "0.38", "0.40", "0.55", "0.70", "0.80", "0.85", "0.88", "0.91", "0.94", "0.95", "0.98", "1.40", "1.55", "2.80", "2.86", "2.95", "6.5"
}

for doc, raw_path in sorted(extracted):
    cleaned = raw_path.replace("res://", "").replace("\\", "/").strip().rstrip(".,;:)")
    if cleaned in ignore_list:
        continue
    # ignore URLs
    if cleaned.startswith("http://") or cleaned.startswith("https://"):
        continue

    # Check if exists directly or relative to root
    # Note: if it's a bare script name like campus_materials.gd, check if it's in scripts/
    check_paths = [
        cleaned,
        os.path.join("scripts", cleaned),
        os.path.join("tools", cleaned),
        os.path.join("assets", cleaned)
    ]
    
    is_found = False
    resolved_path = None
    for cp in check_paths:
        if os.path.exists(cp):
            is_found = True
            resolved_path = cp
            break
            
    if is_found:
        found.append((doc, raw_path, resolved_path))
    else:
        missing.append((doc, raw_path))

print(f"Total paths checked: {len(found) + len(missing)}")
print(f"Paths found on disk: {len(found)}")
print(f"Missing / Unresolved paths: {len(missing)}")

if missing:
    print("\n--- MISSING PATH DETAILS ---")
    for doc, p in missing:
        print(f"Doc: {doc} | Path: {p}")
else:
    print("\n[ALL PATHS VERIFIED ON DISK]")
