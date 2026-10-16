import os
import re

lean_dir = "/Users/arko.sen/Desktop/BfTest/Benefuture/Benefuture"
lean_files = {}

for root, _, files in os.walk(lean_dir):
    for f in files:
        if f.endswith(".lean"):
            path = os.path.join(root, f)
            rel_path = os.path.relpath(path, lean_dir)
            with open(path, "r", encoding="utf-8") as fp:
                lean_files[rel_path] = fp.read()

print(f"Loaded {len(lean_files)} Lean files.")

# Find all def / structure / class / inductive / theorem in Lean files
decl_pattern = re.compile(r'^\s*(def|structure|class|inductive|theorem|axiom|opaque)\s+([A-Za-z0-9_\'.]+)', re.MULTILINE)

lean_decls = {}
for rel_path, content in lean_files.items():
    matches = decl_pattern.findall(content)
    for kind, name in matches:
        lean_decls[name] = (kind, rel_path)

print(f"Total declarations in Lean: {len(lean_decls)}")
for name, (kind, rel_path) in sorted(lean_decls.items()):
    print(f"  {kind} {name} (in {rel_path})")
