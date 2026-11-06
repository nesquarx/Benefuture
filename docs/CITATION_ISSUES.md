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
- **Buckels, Jones & Paulhus 2013** (Happiness): RESOLVED, JUDGEMENT CALL. The cited title matched no record. Replaced with the same authors and year's paper on the cited sentence's topic (pleasure from causing harm): "Behavioral confirmation of everyday sadism", *Psychological Science* 24(11), 2201–2209, https://doi.org/10.1177/0956797613490749 (Crossref). Revert if the author meant another paper.
- **Fujiwara, Kawachi & Sugawara 2018** (Happiness): RESOLVED, JUDGEMENT CALL. No record under those authors. The title (near verbatim) belongs to Lee, Lin & Hung (2021), *Frontiers in Public Health* 8, 582342, https://doi.org/10.3389/fpubh.2020.582342 (Crossref); its title says "The Role of", the source's "The Mediating Roles of". Replaced; the `FujiwaraEtAl2018` ref name is kept so the prose is unaffected.
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
