#!/usr/bin/env python3
"""
fetch_wiki_pages.py — Fetch fresh text files for all pages from the BeneFuture wiki
and populate both the local gdrive/Benefuture folder and Google Drive.
"""

import os
import sys
import json
import ssl
import time
import urllib.request
import urllib.parse

API_URL = "https://benefuture.miraheze.org/w/api.php"
USER_AGENT = "BfBot/1.0 (https://benefuture.miraheze.org; contact: nesquarx@gmail.com)"

TARGET_DIRS = [
    "/Users/arko.sen/Desktop/BfTest/gdrive/Benefuture",
    os.path.expanduser("~/Library/CloudStorage/GoogleDrive-nesquarx@gmail.com/My Drive/Benefuture"),
]

def make_request(params):
    ctx = ssl._create_unverified_context()
    url = API_URL + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8"))

def fetch_all_pages():
    print("1. Fetching all page titles from wiki (namespace 0)...")
    res = make_request({
        "action": "query",
        "list": "allpages",
        "aplimit": "500",
        "format": "json"
    })
    pages = res["query"]["allpages"]
    print(f"   Found {len(pages)} pages.")
    
    titles = [p["title"] for p in pages]
    
    # Fetch content in batches of 10
    print("2. Fetching revisions and content in batches...")
    page_data = {}
    for i in range(0, len(titles), 10):
        batch = titles[i:i + 10]
        batch_res = make_request({
            "action": "query",
            "titles": "|".join(batch),
            "prop": "revisions|info",
            "rvprop": "content|ids|timestamp",
            "format": "json"
        })
        for pid, p in batch_res["query"]["pages"].items():
            title = p["title"]
            revs = p.get("revisions", [])
            content = revs[0].get("*", "") if revs else ""
            revid = revs[0].get("revid") if revs else None
            timestamp = revs[0].get("timestamp") if revs else None
            is_redirect = "redirect" in p or content.strip().lower().startswith("#redirect")
            
            page_data[title] = {
                "pageid": p["pageid"],
                "title": title,
                "revid": revid,
                "timestamp": timestamp,
                "is_redirect": is_redirect,
                "length": len(content),
                "content": content
            }
        print(f"   Progress: {min(i + 10, len(titles))}/{len(titles)} pages fetched")
        time.sleep(0.5)

    return page_data

def sync_to_directory(target_dir, page_data):
    os.makedirs(target_dir, exist_ok=True)
    print(f"\nWriting {len(page_data)} pages to: {target_dir}")
    
    # Track written files
    redirects_list = []
    
    for title, info in sorted(page_data.items()):
        content = info["content"]
        
        # Handle case-insensitive collision on macOS (APFS) for 'System design' vs 'System Design'
        if title == "System design":
            filename = "System design (redirect).txt"
        else:
            filename = f"{title}.txt"
            
        filepath = os.path.join(target_dir, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
            
        if info["is_redirect"]:
            target_match = content.strip().split("\n")[0]
            redirects_list.append(f"{title} -> {target_match}")

    # Write a clean redirects.txt summary
    redirects_path = os.path.join(target_dir, "redirects.txt")
    with open(redirects_path, "w", encoding="utf-8") as f:
        f.write("# BeneFuture Wiki Redirects\n\n")
        f.write("\n".join(sorted(redirects_list)) + "\n")

    # Write a clean manifest
    manifest = {
        "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "total_pages": len(page_data),
        "pages": [
            {
                "pageid": info["pageid"],
                "title": info["title"],
                "revid": info["revid"],
                "timestamp": info["timestamp"],
                "is_redirect": info["is_redirect"],
                "length": info["length"],
                "filename": "System design (redirect).txt" if info["title"] == "System design" else f"{info['title']}.txt"
            }
            for info in sorted(page_data.values(), key=lambda x: x["title"])
        ]
    }
    manifest_path = os.path.join(target_dir, "_manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    print(f"   Successfully wrote {len(page_data)} text files + redirects.txt + _manifest.json")

def main():
    page_data = fetch_all_pages()
    
    for d in TARGET_DIRS:
        if not os.path.exists(d):
            print(f"Target directory does not exist, creating: {d}")
            os.makedirs(d, exist_ok=True)
            
        # Clean out existing files/folders from benefuture folder
        print(f"\nCleaning existing contents in: {d}")
        for item in os.listdir(d):
            item_path = os.path.join(d, item)
            if os.path.isdir(item_path):
                import shutil
                shutil.rmtree(item_path)
                print(f"   Removed directory: {item}")
            else:
                os.remove(item_path)
                print(f"   Removed file: {item}")
                
        sync_to_directory(d, page_data)

    print("\nAll done!")

if __name__ == "__main__":
    main()
