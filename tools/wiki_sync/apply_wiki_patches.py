import os
import sys
import json
import ssl
import time
import urllib.request
import urllib.parse
import http.cookiejar

API_URL = "https://benefuture.miraheze.org/w/api.php"
USER_AGENT = "BfBot/1.0 (https://benefuture.miraheze.org; contact: nesquarx@gmail.com)"

EDITS = [
    {
        "title": "Threshold of significance",
        "file": "Threshold of significance (patched).txt",
        "summary": "Oct patch: liquid democracy threshold debate, assessment scaling unit, and synergy parameters"
    },
    {
        "title": "Adversarial adaptation",
        "file": "Adversarial adaptation (patched).txt",
        "summary": "Oct patch: Goodhart failure mode mapping and metric model adversarial audits"
    },
    {
        "title": "Reputation",
        "file": "Reputation (patched).txt",
        "summary": "Oct patch: causal contribution to U/H and domain-specific novelty tracking"
    },
    {
        "title": "Measurement",
        "file": "Measurement (patched).txt",
        "summary": "Oct patch: assessment definition, Goodhart mapping, and circularity constraints on shared models"
    },
    {
        "title": "Critique addressal",
        "file": "Critique addressal (patched).txt",
        "summary": "Oct patch: Goodhart 4-variant defense, section-specific wikilinks, and liquid democracy clarification"
    },
    {
        "title": "Benefuture currency",
        "file": "Benefuture currency (patched).txt",
        "summary": "Oct patch: settlement against counterfactual assessment, reinvestment redirection, and escrow refs"
    },
    {
        "title": "Government",
        "file": "Government (patched).txt",
        "summary": "Oct patch: clean deliberation criteria and liquid democracy delegation thresholds"
    },
    {
        "title": "Technology Network",
        "file": "Technology Network (patched).txt",
        "summary": "Oct patch: heterogeneous clusters, transaction log substrate, and education-gated infohazard access"
    },
    {
        "title": "System Design",
        "file": "System Design (patched).txt",
        "summary": "Oct patch: anti-herding inter-model agreement bounds and iterated game self-memory foundation"
    },
    {
        "title": "Philosophy",
        "file": "Philosophy (patched).txt",
        "summary": "Oct patch: morality as non-zero CC in iterated reality and updated synergy weighting"
    },
    {
        "title": "Benefuture goals",
        "file": "Benefuture goals (patched).txt",
        "summary": "Oct patch: synergy operator formulation, subgoals alignment, and distribution skew priorities"
    },
    {
        "title": "Benefuture",
        "file": "Benefuture (patched).txt",
        "summary": "Oct patch: updated definitions alignment, novelty bonus, and synergy cross-linking"
    },
    {
        "title": "Being",
        "file": "Being (patched).txt",
        "summary": "Oct patch: memory as part of self and outcome of interaction"
    },
    {
        "title": "Happiness",
        "file": "Happiness (patched).txt",
        "summary": "Oct patch: subjective experience integration, diversity bonus, and priority ordering"
    },
    {
        "title": "Harm",
        "file": "Harm (patched).txt",
        "summary": "Oct patch: necessary harm definition (NHa -> ^V > Ha) and severity weighting order"
    },
    {
        "title": "Understanding",
        "file": "Understanding (patched).txt",
        "summary": "Oct patch: General vs. Pragmatic models, causal explanations, and complexity trade-offs"
    },
    {
        "title": "Implementation prototype",
        "file": "Implementation prototype (patched).txt",
        "summary": "Oct patch: phased rollout, data collection tiers, and Ostrom design principles mapping"
    },
    {
        "title": "Introduction",
        "file": "Introduction (patched).txt",
        "summary": "Oct patch: core mechanisms summary, liquid democracy, and probabilistic escrow grounding"
    }
]

def main():
    bot_user = os.environ.get("BF_BOT_USER", "Nesquarx@bfbot")
    bot_password = os.environ.get("BF_BOT_PASS")
    if not bot_password:
        print("Error: BF_BOT_PASS environment variable required.")
        sys.exit(1)

    patches_dir = "/Users/arko.sen/Desktop/BfTest/gdrive/Benefuture/scrape Aug 2026/Wiki patches (Oct 2026)"
    
    ssl_ctx = ssl._create_unverified_context()
    cookie_jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(cookie_jar),
        urllib.request.HTTPSHandler(context=ssl_ctx)
    )
    headers = {"User-Agent": USER_AGENT}

    def api_get(params):
        url = API_URL + "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers=headers)
        with opener.open(req) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def api_post(data):
        encoded = urllib.parse.urlencode(data).encode("utf-8")
        req = urllib.request.Request(API_URL, data=encoded, headers=headers)
        with opener.open(req) as resp:
            return json.loads(resp.read().decode("utf-8"))

    print(f"1. Fetching login token...")
    token_res = api_get({"action": "query", "meta": "tokens", "type": "login", "format": "json"})
    login_token = token_res["query"]["tokens"]["logintoken"]

    print(f"2. Logging in as {bot_user}...")
    login_res = api_post({
        "action": "login",
        "lgname": bot_user,
        "lgpassword": bot_password,
        "lgtoken": login_token,
        "format": "json"
    })
    
    login_status = login_res.get("login", {}).get("result")
    if login_status != "Success":
        print(f"Login failed: {login_res}")
        sys.exit(1)
    print(f"Login successful as {login_res['login']['lgusername']}!")

    print(f"3. Fetching CSRF edit token...")
    csrf_res = api_get({"action": "query", "meta": "tokens", "type": "csrf", "format": "json"})
    csrf_token = csrf_res["query"]["tokens"]["csrftoken"]

    print(f"\n4. Applying {len(EDITS)} wiki page patches...\n")
    results = []
    
    for i, item in enumerate(EDITS, 1):
        title = item["title"]
        filename = item["file"]
        summary = item["summary"]
        filepath = os.path.join(patches_dir, filename)

        if not os.path.exists(filepath):
            print(f"[{i}/{len(EDITS)}] FAILED: {filename} does not exist!")
            results.append((title, "FAILED: file missing"))
            continue

        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        print(f"[{i}/{len(EDITS)}] Editing '{title}'...")
        edit_payload = {
            "action": "edit",
            "title": title,
            "text": content,
            "summary": summary,
            "token": csrf_token,
            "format": "json"
        }
        
        try:
            edit_res = api_post(edit_payload)
            if "edit" in edit_res:
                result_code = edit_res["edit"].get("result")
                revid = edit_res["edit"].get("newrevid")
                nochange = "nochange" in edit_res["edit"]
                if nochange:
                    print(f"   -> Unchanged (content already matches)")
                    results.append((title, "SUCCESS (already up to date)"))
                elif result_code == "Success":
                    print(f"   -> Saved! (New Rev ID: {revid})")
                    results.append((title, f"SUCCESS (Rev ID: {revid})"))
                else:
                    print(f"   -> Result: {result_code}")
                    results.append((title, f"RESULT: {result_code}"))
            elif "error" in edit_res:
                err_info = edit_res["error"].get("info", str(edit_res["error"]))
                print(f"   -> ERROR: {err_info}")
                results.append((title, f"ERROR: {err_info}"))
            else:
                print(f"   -> Response: {edit_res}")
                results.append((title, "UNKNOWN RESPONSE"))
        except Exception as e:
            print(f"   -> EXCEPTION: {e}")
            results.append((title, f"EXCEPTION: {e}"))

        time.sleep(1)  # Respectful rate limiting between edits

    print("\n=== SUMMARY OF EDITS ===")
    for title, status in results:
        print(f"- {title}: {status}")

if __name__ == "__main__":
    main()
