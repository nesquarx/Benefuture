import re
import os

pseudocode_path = "/Users/arko.sen/Desktop/BfTest/Bf_Pseudocode.txt"
with open(pseudocode_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

statements = []
for idx, line in enumerate(lines):
    raw = line.strip()
    if not raw or raw.startswith("//"):
        continue
    statements.append((idx + 1, raw))

print(f"Total non-empty statements/lines in pseudocode: {len(statements)}")
