/**
 * parse.mjs — generalized parser for the Benefuture (Bf) pseudocode.
 *
 * Grammar handled:
 *   §Section: { ... }                            sections (§Sets, §Defs, §Af_Axioms, §Txonmy)
 *   Name⟦Sym⟧                                   concept declaration (anywhere in parsed sections)
 *   Name⟦Sym⟧(params) ≡|:|::|→|↔ body ;         definition (multi-line, `;`-terminated)
 *   Name⟦Sym⟧(params) | Modifier: body ;        definition with a context bar (e.g. EmbeddedLaws)
 *   BareName(params) ≡ body ;                   symbol-less definition (e.g. Liablty, Art)
 *   A ⊆ B ⊆ C                                   subset chains (§Sets)
 *   a, b, c ∈ T                                 membership lists (§Sets)
 *   Group: { a, b } / Group: { Sub: {…} }       taxonomy groups, arbitrarily nested (§Txonmy)
 *
 * References inside definition bodies resolve via, in order:
 *   explicit ⟦Sym⟧, exact symbol, exact declared name, case-insensitive (len ≥ 2),
 *   "_" token splits, and camel-boundary prefix decomposition into known symbols
 *   (SigRlvCx → Sig + Rlv + Cx). Greek α β γ δ resolve to Params⟦Pm⟧.
 * Subscripted symbols (⟦TP_k⟧) also register their base (TP) as an alias.
 *
 * Taxonomy items are registered in two phases: stubs before definition parsing
 * (so bodies can reference them, e.g. TxLog), then a merge pass after definition
 * parsing folds stubs into longer declared names (Lia → Liablty, Prog → Progrssv).
 *
 * Nodes without a taxonomy group inherit a category by strict plurality of their
 * categorized neighbors; ties stay "Other".
 *
 * Edge direction: dependency → dependent ("X feeds Y" when X appears in Y's definition).
 *
 * Pure ESM, no dependencies. Exports parseBfPseudocode(text) →
 *   { nodes, edges, categories, stats }
 */

const BRACKET_OPEN = new Set(["(", "[", "{", "⟦"]);
const BRACKET_CLOSE = new Set([")", "]", "}", "⟧"]);

/** Split text on `sep` at bracket depth 0. Returns [{ text, offset }]. */
function splitTopLevel(text, sep) {
  const parts = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (BRACKET_OPEN.has(ch)) depth++;
    else if (BRACKET_CLOSE.has(ch)) depth = Math.max(0, depth - 1);
    else if (ch === sep && depth === 0) {
      parts.push({ text: text.slice(start, i), offset: start });
      start = i + 1;
    }
  }
  parts.push({ text: text.slice(start), offset: start });
  return parts;
}

/** Index of the "}" matching the "{" at openIdx. */
function matchBrace(text, openIdx) {
  let depth = 0;
  for (let i = openIdx; i < text.length; i++) {
    if (text[i] === "{") depth++;
    else if (text[i] === "}") {
      depth--;
      if (depth === 0) return i;
    }
  }
  return text.length;
}

/** Split the file into §-sections and extract each section's top-level {…} body. */
function extractSections(text) {
  const marks = [];
  const re = /§([A-Za-z_]+)/g;
  let m;
  while ((m = re.exec(text))) marks.push({ name: m[1], index: m.index });
  const sections = [];
  for (let i = 0; i < marks.length; i++) {
    const end = i + 1 < marks.length ? marks[i + 1].index : text.length;
    const raw = text.slice(marks[i].index, end);
    const braceIdx = raw.indexOf("{");
    if (braceIdx < 0) continue;
    const close = matchBrace(raw, braceIdx);
    sections.push({
      name: marks[i].name,
      body: raw.slice(braceIdx + 1, close),
      bodyOffset: marks[i].index + braceIdx + 1,
    });
  }
  return sections;
}

function sectionKind(name) {
  if (/^sets$/i.test(name)) return "sets";
  if (/^defs$/i.test(name)) return "defs";
  if (/axiom/i.test(name)) return "axioms";
  if (/t[ax]onmy|taxonomy/i.test(name)) return "taxonomy";
  return null;
}

/**
 * Definition header: Name, optional ⟦Sym⟧, optional (nested) param groups,
 * optional context bar "|", optional trailing modifier word
 * (e.g. "Trust⟦Tt⟧Min ≡"), then an operator.
 */
const DEF_RE =
  /^\s*([A-Za-z][A-Za-z0-9_]*)(?:⟦([^⟧]+)⟧)?((?:\((?:[^()]|\([^()]*\))*\))*)\s*(?:\|\s*)?(?:[A-Za-z]+\s*)?(≡|::|:|↔|→)/;

function matchDef(chunk) {
  const m = DEF_RE.exec(chunk);
  if (!m) return null;
  const [, name, symbol, params, op] = m;
  if (!symbol) {
    if (/^[a-z]$/.test(name)) return null; // stray lowercase token
    if (/^[A-Za-z]_[A-Za-z0-9]$/.test(name)) return null; // instance var (T_a, E_i, k_c)
    if ((op === "→" || op === "↔") && !params) return null; // bare "X → …" is a relation, not a def
    if (op === ":" && !/^[A-Z]/.test(name)) return null; // "fallbk: …" style annotations
  }
  return { name, symbol: symbol || null, body: chunk.slice(m[0].length) };
}

/** Nested taxonomy groups: returns [{ path: [..], items: [..] }]. */
function parseTaxonomyGroups(body) {
  const groups = [];
  function scan(text, path) {
    const re = /([A-Za-z][A-Za-z0-9_]*)\s*:\s*\{/g;
    const spans = [];
    let m;
    while ((m = re.exec(text))) {
      const open = re.lastIndex - 1;
      const close = matchBrace(text, open);
      const inner = text.slice(open + 1, close);
      groups.push({ path: [...path, m[1]], items: [] });
      scan(inner, [...path, m[1]]);
      spans.push([m.index, close + 1]);
      re.lastIndex = close + 1;
    }
    if (path.length > 0) {
      let cleaned = "";
      let prev = 0;
      for (const [s, e] of spans) {
        cleaned += text.slice(prev, s) + " ";
        prev = e;
      }
      cleaned += text.slice(prev);
      const items = cleaned
        .split(/[,;\n]/)
        .map((s) => s.trim())
        .filter(Boolean);
      const self = groups.find((g) => g.path.join("/") === path.join("/"));
      if (self) self.items = items;
    }
  }
  scan(body, []);
  return groups;
}

/** Preferred primary-category order; first match wins. */
const CATEGORY_ORDER = [
  "Ontlgy",
  "Epstmlgy",
  "Axiolgy",
  "Sys/Meta",
  "Sys/I",
  "Sys/Me",
  "Sys/Econ",
  "Sys/Gv",
  "Sys/TN",
];

/** Display style for known groups; unknown groups get a label from their name and a free palette slot. */
const CATEGORY_STYLE = {
  Ontlgy: { label: "Ontology", color: "blue" },
  Epstmlgy: { label: "Epistemology", color: "cyan" },
  Axiolgy: { label: "Axiology", color: "pink" },
  "Sys/Meta": { label: "Meta / Anti-fragility", color: "yellow" },
  "Sys/I": { label: "Interaction", color: "orange" },
  "Sys/Me": { label: "Measurement", color: "green" },
  "Sys/Econ": { label: "Economy", color: "purple" },
  "Sys/Gv": { label: "Governance", color: "red" },
  "Sys/TN": { label: "Tech Network", color: "gray" },
  Other: { label: "Other / Unclassified", color: "gray" },
};

const PALETTE = ["blue", "cyan", "pink", "orange", "green", "purple", "red", "yellow", "gray"];

const slug = (s) =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");

export function parseBfPseudocode(text) {
  const nodes = new Map(); // id -> node
  let edges = [];
  const edgeKeys = new Set();
  const symbolToId = new Map();
  const nameToId = new Map();
  const lowerIndex = new Map(); // lowercase symbol/name -> id

  const lineStarts = [0];
  for (let i = 0; i < text.length; i++) if (text[i] === "\n") lineStarts.push(i + 1);
  const lineOf = (offset) => {
    let lo = 0;
    let hi = lineStarts.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= offset) lo = mid;
      else hi = mid - 1;
    }
    return lo + 1;
  };

  const declareNode = ({
    name = null,
    symbol = null,
    def = "",
    line = null,
    section = null,
    axiom = false,
    isSet = false,
    fromTaxonomy = false,
  }) => {
    const id = symbol || name;
    if (!id) return null;
    let n = nodes.get(id);
    if (!n) {
      n = {
        id,
        name: name || id,
        symbol,
        def: "",
        line: null,
        section: null,
        groups: [],
        subGoal: false,
        axiom: false,
        isSet: false,
        fromTaxonomy: false,
      };
      nodes.set(id, n);
    }
    if (name && n.name === n.id) n.name = name;
    if (def && !n.def) n.def = def;
    if (line != null && n.line == null) n.line = line;
    if (section && !n.section) n.section = section;
    if (axiom) n.axiom = true;
    if (isSet) n.isSet = true;
    if (fromTaxonomy) n.fromTaxonomy = true;
    if (symbol) {
      n.symbol = symbol;
      symbolToId.set(symbol, id);
      lowerIndex.set(symbol.toLowerCase(), id);
      // Subscripted symbols (TP_k) also answer to their base (TP).
      const base = symbol.split("_")[0];
      if (base && base !== symbol && !symbolToId.has(base)) {
        symbolToId.set(base, id);
        lowerIndex.set(base.toLowerCase(), id);
      }
    }
    if (name) {
      nameToId.set(name, id);
      lowerIndex.set(name.toLowerCase(), id);
    }
    return n;
  };

  const addEdge = (from, to, kind) => {
    if (!from || !to || from === to) return;
    const key = from + " " + to;
    if (edgeKeys.has(key)) return;
    edgeKeys.add(key);
    edges.push({ from, to, kind });
  };

  const sections = extractSections(text);
  const parsed = sections.filter((s) => sectionKind(s.name));

  // ---- Pass 1: every Name⟦Sym⟧ declaration in parsed sections -------------
  for (const sec of parsed) {
    const kind = sectionKind(sec.name);
    const re = /([A-Za-z][A-Za-z0-9_]*)⟦([^⟧]+)⟧/g;
    let m;
    while ((m = re.exec(sec.body))) {
      declareNode({
        name: m[1],
        symbol: m[2],
        line: lineOf(sec.bodyOffset + m.index),
        section: sec.name,
        axiom: kind === "axioms",
        isSet: kind === "sets",
      });
    }
  }

  // Symbols usable for camel-boundary prefix decomposition, longest first.
  let prefixSymbols = [...symbolToId.keys()]
    .filter((s) => /^[A-Za-z][A-Za-z0-9_]*$/.test(s))
    .sort((a, b) => b.length - a.length);

  const resolveToken = (token, refs) => {
    const direct = symbolToId.get(token) ?? nameToId.get(token);
    if (direct) {
      refs.add(direct);
      return;
    }
    if (token.includes("_")) {
      for (const part of token.split("_")) if (part) resolveToken(part, refs);
      return;
    }
    if (token.length >= 2) {
      const ci = lowerIndex.get(token.toLowerCase());
      if (ci) {
        refs.add(ci);
        return;
      }
    }
    // Camel-boundary prefix decomposition: longest known symbol (len ≥ 2) that is a
    // prefix, followed by an uppercase letter, with a lowercase letter somewhere in
    // the remainder (rejects all-caps words like CRUD). Remainder resolves recursively.
    for (const sym of prefixSymbols) {
      if (sym.length < 2 || sym.length >= token.length || !token.startsWith(sym)) continue;
      const rest = token.slice(sym.length);
      if (!/[A-Z]/.test(rest[0])) continue;
      if (!/[a-z]/.test(rest)) continue;
      refs.add(symbolToId.get(sym));
      resolveToken(rest, refs);
      return;
    }
  };

  const extractRefs = (chunk) => {
    const refs = new Set();
    for (const m of chunk.matchAll(/⟦([^⟧]+)⟧/g)) {
      const id = symbolToId.get(m[1]);
      if (id) refs.add(id);
    }
    if (/[αβγδ]/.test(chunk) && symbolToId.has("Pm")) refs.add("Pm");
    for (const m of chunk.matchAll(/[A-Za-z][A-Za-z0-9_]*/g)) resolveToken(m[0], refs);
    for (const [sym, id] of symbolToId) {
      if (/[^ -~]/.test(sym) && chunk.includes(sym)) refs.add(id); // non-ASCII symbols (ℝ, 𝕌)
    }
    return refs;
  };

  /** Loose resolution for §Sets relations and §Txonmy items. */
  const resolveRefLoose = (rawToken) => {
    const token = rawToken.replace(/[.\s]+$/g, "").trim();
    if (!token) return null;
    const direct = symbolToId.get(token) ?? nameToId.get(token);
    if (direct) return direct;
    if (token.length >= 2) {
      const ci = lowerIndex.get(token.toLowerCase());
      if (ci) return ci;
    }
    if (token.length >= 3) {
      // Prefix of a declared name: Lia → Liablty, Prog → Progrssv, Econ → Economy.
      for (const [name, nid] of nameToId) {
        if (name.length > token.length && name.startsWith(token)) return nid;
      }
    }
    return null;
  };

  // ---- Taxonomy phase 1: register groups + stubs BEFORE defs, so definition
  //      bodies can reference taxonomy-only names (TxLog, PrAcc). -------------
  const taxonomySections = parsed.filter((s) => sectionKind(s.name) === "taxonomy");
  const taxonomyGroups = taxonomySections.flatMap((sec) =>
    parseTaxonomyGroups(sec.body).map((g) => ({ ...g, sec }))
  );
  const applyGroup = (key, leaf, id) => {
    const n = nodes.get(id);
    if (!n) return;
    if (/^subg/i.test(leaf)) n.subGoal = true;
    else if (!n.groups.includes(key)) n.groups.push(key);
  };
  for (const g of taxonomyGroups) {
    const key = g.path.join("/");
    const leaf = g.path[g.path.length - 1];
    for (const item of g.items) {
      let id = resolveRefLoose(item);
      if (!id) {
        const stub = declareNode({
          name: item,
          line: lineOf(g.sec.bodyOffset),
          section: g.sec.name,
          fromTaxonomy: true,
        });
        id = stub ? stub.id : null;
      }
      if (id) applyGroup(key, leaf, id);
    }
  }
  prefixSymbols = [...symbolToId.keys()]
    .filter((s) => /^[A-Za-z][A-Za-z0-9_]*$/.test(s))
    .sort((a, b) => b.length - a.length);

  // ---- §Sets: ⊆ chains and ∈ memberships -----------------------------------
  for (const sec of parsed.filter((s) => sectionKind(s.name) === "sets")) {
    for (const stmt of splitTopLevel(sec.body, ";")) {
      const s = stmt.text;
      if (s.includes("⊆")) {
        const ids = s
          .split("⊆")
          .map((p) => resolveRefLoose(p))
          .filter(Boolean);
        for (let i = ids.length - 1; i > 0; i--) addEdge(ids[i], ids[i - 1], "subset");
      } else if (s.includes("∈")) {
        const idx = s.indexOf("∈");
        const container = resolveRefLoose(s.slice(idx + 1));
        if (!container) continue;
        for (const item of s.slice(0, idx).split(",")) {
          const id = resolveRefLoose(item);
          if (id) addEdge(container, id, "member");
        }
      }
    }
  }

  // ---- §Defs / §Af_Axioms: definition statements -----------------------------
  const cleanDef = (body) => {
    const oneLine = body.replace(/\s+/g, " ").trim();
    return oneLine.length > 240 ? oneLine.slice(0, 239) + "…" : oneLine;
  };

  for (const sec of parsed.filter((s) => ["defs", "axioms"].includes(sectionKind(s.name)))) {
    const isAxiom = sectionKind(sec.name) === "axioms";
    for (const stmt of splitTopLevel(sec.body, ";")) {
      const chunks = splitTopLevel(stmt.text, ",");
      const defs = []; // { name, symbol, body, chunkText }
      const nonDefRefs = new Set();
      for (const chunk of chunks) {
        const d = matchDef(chunk.text);
        if (d) defs.push({ ...d, chunkText: chunk.text });
        else for (const r of extractRefs(chunk.text)) nonDefRefs.add(r);
      }
      if (defs.length === 0) continue;

      const line = lineOf(sec.bodyOffset + stmt.offset);
      const definedIds = new Set();
      for (const d of defs) {
        const node = declareNode({
          name: d.name,
          symbol: d.symbol,
          def: cleanDef(d.body),
          line,
          section: sec.name,
          axiom: isAxiom,
        });
        if (node) definedIds.add(node.id);
      }

      defs.forEach((d, i) => {
        const id = (d.symbol && symbolToId.get(d.symbol)) || nameToId.get(d.name) || d.name;
        const refs = extractRefs(d.chunkText);
        if (i === 0) for (const r of nonDefRefs) refs.add(r); // continuation chunks belong to the first def
        for (const r of refs) {
          if (definedIds.has(r)) continue; // no self/co-definition loops
          addEdge(r, id, "def");
        }
        if (i > 0) {
          const first =
            (defs[0].symbol && symbolToId.get(defs[0].symbol)) || nameToId.get(defs[0].name) || defs[0].name;
          addEdge(first, id, "introduces"); // co-defined in the same statement
        }
      });
    }
  }

  // ---- Taxonomy phase 2: merge stubs into longer declared names --------------
  //      (Lia → Liablty, Prog → Progrssv) now that definitions exist.
  const remap = new Map(); // stubId -> targetId
  for (const n of [...nodes.values()]) {
    if (!n.fromTaxonomy || n.def || n.symbol) continue;
    for (const [name, nid] of nameToId) {
      if (nid !== n.id && name.length > n.id.length && name.startsWith(n.id)) {
        remap.set(n.id, nid);
        break;
      }
    }
  }
  if (remap.size > 0) {
    for (const [stubId, targetId] of remap) {
      const stub = nodes.get(stubId);
      const target = nodes.get(targetId);
      if (!stub || !target) continue;
      for (const g of stub.groups) if (!target.groups.includes(g)) target.groups.push(g);
      if (stub.subGoal) target.subGoal = true;
      nodes.delete(stubId);
    }
    edgeKeys.clear();
    const rerouted = [];
    for (const e of edges) {
      const from = remap.get(e.from) ?? e.from;
      const to = remap.get(e.to) ?? e.to;
      if (from === to) continue;
      const key = from + " " + to;
      if (edgeKeys.has(key)) continue;
      edgeKeys.add(key);
      rerouted.push({ from, to, kind: e.kind });
    }
    edges = rerouted;
  }

  // ---- Categories -------------------------------------------------------------
  const usedColors = new Set();
  const catMeta = new Map();
  const metaFor = (key) => {
    if (!catMeta.has(key)) {
      const style = CATEGORY_STYLE[key] ?? {
        label: key.split("/").pop(),
        color: PALETTE.find((c) => !usedColors.has(c)) ?? "gray",
      };
      usedColors.add(style.color);
      catMeta.set(key, { id: slug(key), label: style.label, color: style.color, count: 0 });
    }
    return catMeta.get(key);
  };

  // A node whose id/symbol names a leaf taxonomy group belongs to that group
  // (TN → Sys/TN, Gv → Sys/Gv, Me → Sys/Me).
  const leafKeyByName = new Map();
  for (const g of taxonomyGroups) {
    if (g.items.length === 0) continue;
    const leaf = g.path[g.path.length - 1];
    if (!leafKeyByName.has(leaf)) leafKeyByName.set(leaf, g.path.join("/"));
  }

  // Primary key from taxonomy (or the anti-fragility group for axioms).
  const keyOf = new Map(); // nodeId -> group key
  for (const n of nodes.values()) {
    const ownGroup = leafKeyByName.get(n.id) ?? (n.symbol ? leafKeyByName.get(n.symbol) : null);
    const key =
      ownGroup ??
      CATEGORY_ORDER.find((k) => n.groups.includes(k)) ??
      n.groups[0] ??
      (n.axiom ? "Sys/Meta" : null);
    if (key) keyOf.set(n.id, key);
  }
  // Ungrouped nodes inherit by strict plurality of categorized neighbors.
  const neighborsOf = new Map(); // nodeId -> Set<nodeId>
  for (const e of edges) {
    if (!neighborsOf.has(e.from)) neighborsOf.set(e.from, new Set());
    if (!neighborsOf.has(e.to)) neighborsOf.set(e.to, new Set());
    neighborsOf.get(e.from).add(e.to);
    neighborsOf.get(e.to).add(e.from);
  }
  for (const n of nodes.values()) {
    if (keyOf.has(n.id)) continue;
    const counts = new Map();
    for (const nb of neighborsOf.get(n.id) ?? []) {
      const k = keyOf.get(nb);
      if (k) counts.set(k, (counts.get(k) ?? 0) + 1);
    }
    let best = null;
    let bestCount = 0;
    let tied = false;
    for (const [k, c] of counts) {
      if (c > bestCount) {
        best = k;
        bestCount = c;
        tied = false;
      } else if (c === bestCount) {
        tied = true;
      }
    }
    if (best && !tied) keyOf.set(n.id, best);
  }

  for (const n of nodes.values()) {
    n.cat = metaFor(keyOf.get(n.id) ?? "Other").id;
  }
  for (const n of nodes.values()) {
    const meta = [...catMeta.values()].find((c) => c.id === n.cat);
    if (meta) meta.count++;
  }
  const categories = [...catMeta.values()].filter((c) => c.count > 0);

  return {
    nodes: [...nodes.values()].map((n) => ({
      id: n.id,
      name: n.name,
      cat: n.cat,
      def: n.def,
      line: n.line,
      subGoal: n.subGoal,
      axiom: n.axiom,
      isSet: n.isSet,
    })),
    edges: edges.filter((e) => nodes.has(e.from) && nodes.has(e.to)),
    categories,
    stats: { sections: parsed.length },
  };
}
