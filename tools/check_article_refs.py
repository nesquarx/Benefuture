#!/usr/bin/env python3
"""Check that every Lean name an article links to exists in the linked file.

Articles cite code as [https://github.com/nesquarx/Benefuture/blob/main/<path> <code>a</code>, <code>b</code>];
each name must be defined (def, theorem, lemma, structure, abbrev, instance) in <path>. Repo-relative links to
other files must exist. Exit 1 on any miss.
"""
import re, sys, pathlib
root = pathlib.Path(__file__).resolve().parents[1]
link = re.compile(r'\[https://github\.com/nesquarx/Benefuture/blob/main/([^\s\]]+) ([^\]]*)\]')
code = re.compile(r'<code>([^<]+)</code>')
bad = 0
for art in sorted((root / 'docs/articles').glob('*.txt')):
    for path, label in link.findall(art.read_text()):
        f = root / path
        if not f.exists():
            print(f'{art.name}: missing file {path}'); bad += 1; continue
        if path.endswith('.lean'):
            src = f.read_text()
            for name in code.findall(label):
                if not re.search(rf'^\s*(?:@\[[^\]]*\]\s*)?(?:private\s+|noncomputable\s+|protected\s+)*(?:def|theorem|lemma|structure|abbrev|instance)\s+{re.escape(name)}\b', src, re.M):
                    print(f'{art.name}: {name} not found in {path}'); bad += 1
print('all article references found' if not bad else f'{bad} missing')
sys.exit(1 if bad else 0)
