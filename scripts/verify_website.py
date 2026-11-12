"""
Healthcare Portfolio Website Verification Script
Checks all internal links, IDs, asset paths, and canvas selectors.
"""
import os
import re

def verify_website():
    with open("index.html", "r", encoding="utf-8") as f:
        html = f.read()

    errors = []

    # 1. Check anchor links
    href_targets = re.findall(r'href="#([^"]+)"', html)
    element_ids = set(re.findall(r'id="([^"]+)"', html))

    for target in href_targets:
        if target not in element_ids:
            errors.append(f"Broken anchor link: #{target} does not exist in index.html")

    # 2. Check tab buttons and tab panels
    data_targets = re.findall(r'data-target="([^"]+)"', html)
    for target in data_targets:
        if target not in element_ids:
            errors.append(f"Broken tab target: data-target='{target}' does not exist in index.html")

    # 3. Check CSS and JS links
    local_assets = re.findall(r'(?:href|src)="(assets/[^"]+)"', html)
    for asset in local_assets:
        if not os.path.exists(asset):
            errors.append(f"Missing local asset: {asset}")

    # 4. Check JS canvases
    with open("assets/js/main.js", "r", encoding="utf-8") as f:
        js = f.read()

    canvas_ids_in_js = re.findall(r"getElementById\('([^']+)'\)", js)
    for cid in canvas_ids_in_js:
        if cid not in element_ids:
            errors.append(f"Canvas/Element in JS not found in HTML: #{cid}")

    # 5. Check JSON endpoints in JS
    json_paths = re.findall(r"retrieveDataset\('[^']+',\s*'([^']+)'\)", js)
    for jp in json_paths:
        if not os.path.exists(jp):
            errors.append(f"JSON endpoint in JS not found on disk: {jp}")

    if errors:
        print(f"FAILED with {len(errors)} errors:")
        for e in errors:
            print("  -", e)
        return False
    else:
        print("SUCCESS: 100% of links, IDs, tabs, assets, canvases, and JSON endpoints verified!")
        print(f"Verified {len(href_targets)} anchor links.")
        print(f"Verified {len(data_targets)} tab buttons.")
        print(f"Verified {len(local_assets)} local assets.")
        print(f"Verified {len(canvas_ids_in_js)} Chart.js canvas elements.")
        print(f"Verified {len(json_paths)} JSON data endpoints.")
        return True

if __name__ == "__main__":
    verify_website()
