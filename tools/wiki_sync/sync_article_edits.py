"""
Push article edits made in this repo to the live wiki as targeted replacements.

Unlike apply_wiki_patches.py (whole-page overwrite), this replays only the
changed blocks between two git revisions onto the page's *current* live text,
so edits made on the wiki since the last scrape are preserved. A block whose
old text is not found exactly once on the live page is reported and that page
is skipped. Edits carry basetimestamp, so a concurrent edit causes a conflict
instead of an overwrite.

Usage:
  BF_BOT_PASS=... python3 tools/wiki_sync/sync_article_edits.py [--base REV] [--head REV] [--apply]

Default is a dry run against HEAD~1..HEAD.
"""
import argparse
import difflib
import http.cookiejar
import json
import os
import ssl
import subprocess
import sys
import urllib.parse
import urllib.request

API_URL = "https://benefuture.miraheze.org/w/api.php"
USER_AGENT = "BfBot/1.0 (https://benefuture.miraheze.org)"
ARTICLES = "docs/articles/"


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def git_optional(*args):
    p = subprocess.run(["git", *args], capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else None


def changed_articles(base, head):
    out = git("diff", "--name-only", base, head, "--", ARTICLES)
    return [p for p in out.splitlines() if p.endswith(".txt")
            and os.path.basename(p) not in ("Citations.txt", "Template.txt", "redirects.txt")]


def edit_blocks(old_text, new_text):
    """Changed blocks as (old, new) strings, each widened by one unchanged line of context."""
    a, b = old_text.split("\n"), new_text.split("\n")
    blocks = []
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if op == "equal":
            continue
        while i1 > 0 and j1 > 0 and a[i1 - 1] == b[j1 - 1]:
            i1, j1 = i1 - 1, j1 - 1
            if a[i1].strip():
                break
        if (i1 == i2 or not "\n".join(a[i1:i2]).strip()) and i2 < len(a) and j2 < len(b):
            while i2 < len(a) and j2 < len(b) and a[i2] == b[j2]:
                orig_line = a[i2]
                i2, j2 = i2 + 1, j2 + 1
                if orig_line.strip():
                    break
        blocks.append(("\n".join(a[i1:i2]), "\n".join(b[j1:j2])))
    return blocks


def apply_blocks(live, blocks):
    """Returns (new_text, problems). Blocks already applied are skipped."""
    problems = []
    for old, new in blocks:
        if live.count(new) == 1:
            continue
        elif live.count(old) == 1:
            live = live.replace(old, new)
        else:
            problems.append(f"old text found {live.count(old)}x: {old[:80]!r}")
    return live, problems


class Wiki:
    def __init__(self):
        ssl_ctx = ssl._create_unverified_context()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()),
            urllib.request.HTTPSHandler(context=ssl_ctx))

    def call(self, params, post=False):
        params = {**params, "format": "json", "formatversion": "2"}
        data = urllib.parse.urlencode(params).encode()
        url = API_URL if post else f"{API_URL}?{data.decode()}"
        req = urllib.request.Request(url, data=data if post else None, headers={"User-Agent": USER_AGENT})
        with self.opener.open(req, timeout=60) as r:
            return json.load(r)

    def login(self, user, password):
        token = self.call({"action": "query", "meta": "tokens", "type": "login"})["query"]["tokens"]["logintoken"]
        res = self.call({"action": "login", "lgname": user, "lgpassword": password, "lgtoken": token}, post=True)
        if res.get("login", {}).get("result") != "Success":
            sys.exit(f"Login failed: {res}")
        self.csrf = self.call({"action": "query", "meta": "tokens"})["query"]["tokens"]["csrftoken"]

    def page(self, title):
        res = self.call({"action": "query", "prop": "revisions", "titles": title,
                         "rvprop": "content|timestamp", "rvslots": "main", "curtimestamp": 1})
        pg = res["query"]["pages"][0]
        if pg.get("missing"):
            return None, None, res["curtimestamp"]
        rev = pg["revisions"][0]
        return rev["slots"]["main"]["content"], rev["timestamp"], res["curtimestamp"]

    def edit(self, title, text, basets, startts, summary, create=False):
        params = {"action": "edit", "title": title, "text": text, "summary": summary,
                  "starttimestamp": startts, "bot": 1, "token": self.csrf}
        if create:
            params["createonly"] = 1
        else:
            params["basetimestamp"] = basets
            params["nocreate"] = 1
        return self.call(params, post=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="HEAD~1")
    ap.add_argument("--head", default="HEAD")
    ap.add_argument("--apply", action="store_true", help="write to the wiki (default: dry run)")
    ap.add_argument("--create-missing", action="store_true", help="create pages that do not exist yet on the live wiki")
    ap.add_argument("--summary", default=None)
    args = ap.parse_args()

    summary = args.summary or git("log", "-1", "--format=%s", args.head).strip()
    wiki = Wiki()
    if args.apply:
        password = os.environ.get("BF_BOT_PASS") or sys.exit("BF_BOT_PASS required for --apply")
        wiki.login(os.environ.get("BF_BOT_USER", "Nesquarx@bfbot"), password)

    failed = False
    for path in changed_articles(args.base, args.head):
        title = os.path.basename(path)[:-4]
        if title.endswith(" (redirect)"):
            title = title[:-11]
        old_rev = git_optional("show", f"{args.base}:{path}")
        new_rev = git("show", f"{args.head}:{path}")
        live, basets, startts = wiki.page(title)
        if live is None:
            if not args.create_missing:
                print(f"NEW  {title}: missing on live wiki (pass --create-missing to create)")
                continue
            elif not args.apply:
                print(f"DRY  {title}: would create new page ({len(new_rev)} bytes)")
                continue
            else:
                res = wiki.edit(title, new_rev, None, startts, summary, create=True)
                status = res.get("edit", {}).get("result")
                failed |= status != "Success"
                print(f"{'NEW ' if status == 'Success' else 'FAIL'} {title}: {status or res}")
                continue
        blocks = edit_blocks(old_rev if old_rev is not None else live, new_rev)
        new, problems = apply_blocks(live, blocks)
        if problems:
            for sha in git("log", "--format=%H", f"{args.base}..{args.head}", "--", path).splitlines():
                hist = git_optional("show", f"{sha}:{path}")
                if hist is not None and hist.rstrip() == live.rstrip():
                    blocks = edit_blocks(hist, new_rev)
                    new, problems = apply_blocks(live, blocks)
                    break
        if problems:
            failed = True
            print(f"SKIP {title}: " + "; ".join(problems))
        elif new == live:
            print(f"OK   {title}: already up to date")
        elif not args.apply:
            print(f"DRY  {title}: {len(blocks)} block(s) would change")
        else:
            res = wiki.edit(title, new, basets, startts, summary)
            status = res.get("edit", {}).get("result")
            failed |= status != "Success"
            print(f"{'EDIT' if status == 'Success' else 'FAIL'} {title}: {status or res}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
