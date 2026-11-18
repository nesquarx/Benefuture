# Citation issues for the author (2026-11-06)

Found while linking every reference in `docs/articles/`, then corrected against Crossref (reference
metadata fetched from `api.crossref.org`) and Open Library. Only `<ref>` contents were changed; the
author's prose is untouched. `docs/articles/Citations.txt` (generated) and `docs/citations_index.json`
were regenerated; `tools/wiki/extract_refs.py` now strips references from the whole preceding text before
taking the supporting sentence (a longer reference no longer leaks into the next row's "supports" column).
Reference uses: 315 in 25 articles (293 distinct); 29 uses (27 distinct) still lack a link.

## References that did not match the real publication
- **Hong & Page** (Diversity): RESOLVED. Now Hong & Page (2001), *Journal of Economic Theory* 97(1), 123–163, https://doi.org/10.1006/jeth.2000.2709 (Crossref).
- **Woolley et al.** (Diversity): RESOLVED. Now Woolley, Chabris, Pentland, Hashmi & Malone (2010), *Science* 330(6004), 686–688, https://doi.org/10.1126/science.1193147 (Crossref).
- **Csikszentmihalyi & Larson 1987** (Happiness): RESOLVED. Venue *The Journal of Nervous and Mental Disease* 175(9), pages 526–536 (the existing DOI was right; Crossref).
- **Ritchie & Tucker-Drob 2018** (Philosophy): RESOLVED. Pages 1358–1369 and title "How Much Does Education Improve Intelligence? A Meta-Analysis" (Crossref).
- **Mercer** (Understanding): RESOLVED. Mercer (2008), "Talk and the development of reasoning and understanding", *Human Development* 51(1), 90–100, https://doi.org/10.1159/000113158 (Crossref; author and title match).
- **Buckels, Jones & Paulhus 2013** (Happiness): RESOLVED, APPROVED by the author 2026-11-07. The cited title matched no record. Replaced with the same authors and year's paper on the cited sentence's topic (pleasure from causing harm): "Behavioral confirmation of everyday sadism", *Psychological Science* 24(11), 2201–2209, https://doi.org/10.1177/0956797613490749 (Crossref). Revert if the author meant another paper.
- **Fujiwara, Kawachi & Sugawara 2018** (Happiness): RESOLVED, APPROVED by the author 2026-11-07 (ref renamed LeeEtAl2021). No record under those authors. The title (near verbatim) belongs to Lee, Lin & Hung (2021), *Frontiers in Public Health* 8, 582342, https://doi.org/10.3389/fpubh.2020.582342 (Crossref); its title says "The Role of", the source's "The Mediating Roles of". Replaced; the `FujiwaraEtAl2018` ref name is kept so the prose is unaffected.
- **Packard 1988** (Diversity): STILL OPEN. The real paper is likely "Adaptation toward the edge of chaos" in Kelso, Mandell & Shlesinger (eds.), *Dynamic Patterns in Complex Systems* (World Scientific, 1988, pp. 293–301; book record 10.1142/0534), not in *Complexity: The Emerging Science…*; the chapter's own metadata could not be verified in Crossref, so nothing was changed.
- **De Vries et al. 2022** (Implementation prototype): STILL OPEN. No Crossref or Open Library record for "Hope for Democracy: 35 Years of Participatory Budgeting Worldwide", so the garbled author list (`De Vries, M.S.,";";`) cannot be corrected from a matched record; the author needs to supply the editors.
- **Black & Wiliam 1998** (was "Dylan, W., & Black, P. (2001)"): already corrected earlier.

## Still unlinked (27 distinct references, 29 uses)
Newly linked (Open Library work pages, title and author checked; the Analects edition confirmed as Slingerland's Hackett translation): Gilovich 1991, Black & Wiliam 1998 *Inside the Black Box*, Al-Ghazali *Book of Knowledge* (2016), Slingerland's *Analects*, Bodhi's *Samyutta Nikaya* (*Connected Discourses of the Buddha*, 2000).

Remaining, and why:
- Hayek 1945 (JSTOR 1809376 probable) and Railton 1984 (JSTOR 2265273 probable): JSTOR answers only a bot challenge page, so the title cannot be checked; Crossref has no DOI for either.
- Kolmogorov 1965: Crossref only has the 1968 English translation in *Int. J. Computer Mathematics* (10.1080/00207166808803030); different venue and year, so not linked.
- Kawharu 2000, Hill 1910, Ruiz-Primo & Shavelson 1997, Hurwicz 1960, Frederick & Loewenstein 1999, Brickman & Campbell 1971 (two forms), Chin 2006, Diener, Sandvik & Pavot 2003: Crossref has no record matching title, authors and year (nearest hits are other works or later reprints, e.g. Diener et al. 2009 in *Assessing Well-Being*).
- Popper 1959, Franklin 2005, Arter & McTighe 2001, Griffin 1986, Plato *Republic* and *Philebus* (Hackett), Vatsyayana, Diderot 1751: Open Library gave no matching work (or the search was refused); Plato's work pages exist only per language or other translator, so none was accepted.
- Vassil 2016, e-Governance Academy 2023, Porter et al. 2016 (Social Progress Index), the standards list in Domain: no official page could be confirmed from here (publisher sites not reachable through the proxy); the author may supply URLs.
- Cox's *Wonders of the Universe*: a television series, no stable record; kept by the author's decision (below).

## Kept by the author's decision
- The Wikipedia citation for multi-objective optimisation (Benefuture goals › Synergy), beside Figueira, Greco & Ehrgott (2005): kept, serving as a literature review.
- Cox's *Wonders of the Universe* (TV series), beside Sagan's *Cosmos* for the same line: kept.

Books are linked to edition-agnostic Open Library work pages; the cited edition's year and publisher
are kept in the reference text.

## Relevance check (2026-11-06)

Per use, the cited work's content was compared with the sentence it supports (`docs/citations_relevance.json`).
148 uses were judged from the work's abstract or description (95 support, 41 related, 7 mismatch, 5 too
thin to tell); 138 uses have no abstract online and were judged only by title match and general
knowledge (82 support, 55 related, 1 mismatch): those are not yet content-checked.

Fixed: "Being creative makes you happier" was attributed to Acar & Runco (2019, J. Creative Behavior),
whose DOI is a different paper; the work is Tan, Chuah, Lee & Tan (2021), IJERPH 18(14) 7244, verified
on Crossref and its abstract matches the claim. Pang & Lee (2008) and Phan et al. (2002) DOIs pointed to
other papers; corrected and verified. Nāgārjuna (Garfield trans.) and Garfield (1955) were fetcher errors;
their DOIs are right.

Open:
- Dunn & Neighbors (2019), "Wearable technology: a promising tool for mental health researchers",
  Depression and Anxiety 36(10): no record found; its DOI is a corrigendum on another study. Likely not a
  real paper; needs a replacement or removal (author).
- Spence (1973), job-market signalling, cited for government weighting (System Design): the right paper,
  but it does not support that claim.
- Uses marked "related" (96) cite a general work for a specific claim the content does not show; the
  dataset home pages and broad books are the bulk.

## Discussion section link mismatches (2026-11-18)

Running `tools/wiki/fetch_abstracts.py` after fixing macOS SSL (`_USE_CURL` fallback) over the newly
added `==Discussion==` `<ref>` delta (`84` linked uses, recorded in `docs/citations_relevance.json`)
flagged **28 mismatched URLs** (27 Open Library `/works/OL...W` IDs pointing to unrelated works and
1 wrong Econometrica DOI). These are recorded as `"verdict": "mismatch"` in `docs/citations_relevance.json`;
`docs/articles/*.txt` was left untouched while `==Discussion==` is under author review:

- **Hart & Moore (1988)** (`Contract`): `https://doi.org/10.2307/1911054` resolves to Hart & Mas-Colell (1989) *"Potential, Value, and Consistency"*, not *"Incomplete Contracts and Renegotiation"*.
- **27 Open Library work IDs (`openlibrary.org/works/OL...W`)** resolving to unrelated titles:
  - `Accolade`: Urmson (1958) `OL4907340W` (*Tamrā nok khao Chawā...*), Shapley (1953) `OL4417976W` (*Mind over motor*)
  - `Benesophont`: Rawls (1993) `OL2009261W` (*Pensioner soiuznogo znacheniia*)
  - `Communication`: Lewis (1969) `OL3508914W` (*Freshwater Fish*)
  - `Contract`: Shavell (2004) `OL3324505W` (*The 2007-2012 World Outlook for Non-Electric Oil Forced Warm Air Furnaces...*)
  - `Crime`: Hart (1968) `OL1876645W` (*The Gulf between us*)
  - `Decision`: von Neumann & Morgenstern (1944) `OL3963222W` (*Gunpowder Valley*)
  - `Enforcement`: Ayres & Braithwaite (1992) `OL1964526W` (*A national sample survey*)
  - `Good and Bad`: Thomson (2008) `OL16516590W` (*Waithayamahidon*), Broome (1991) `OL1868121W` (*Impacts of heavy axle loads...*)
  - `Ignorance`: Knight (1921) `OL65359W` (*Monsieur Pamplemousse on vacation*)
  - `Influence`: Lukes (2005) `OL1881562W` (*David Johnson Passed Through Here*)
  - `Input`: Bateson (1972) `OL53864W` (*Michel de Montaigne*), Ashby (1956) `OL1183948W` (*Late arrival*)
  - `Interaction`: Salmon (1984) `OL2796608W` (*Aspetti istituzionali della giungla retributiva*)
  - `Law`: Hart (1961) `OL1876642W` (*The Religious Thought of Chu Hsi*), Lessig (1999) `OL41913W` (*Malpractice in Maggody*)
  - `Outcome`: Savage (1954) `OL4498501W` (*Elementi di economia e tecnica del credito*)
  - `Power`: Morriss (2002) `OL3974763W` (*Usin g Novell DOS 7*), Russell (1938) `OL1105246W` (*Ursache, Grund und Zweck*)
  - `Reality`: Nozick (1974) `OL2634276W` (*The African studies companion*)
  - `Sapience`: Brandom (1994) `OL1897635W` (*Readings in aging and death*)
  - `Thing`: Wheeler / Zurek (1990) `OL2204224W` (*Sovetskoe monumental'noe iskusstvo*), Quine (1960) `OL2664673W` (*Nur eine kleine Insel*)
  - `Truth`: Kneale & Kneale (1962) `OL1370838W` (*Farloyrene vegn*)
  - `Untruth`: Grice (1989) `OL1897631W` (*Brain disorders in the elderly*), Bok (1978) `OL1102124W` (*The more I see of men ..*)
