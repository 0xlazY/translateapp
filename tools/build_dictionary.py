#!/usr/bin/env python3
"""Builds Pandouchka/Resources/dictionary.sqlite from Wiktionary extracts.

Sources (all downloaded from https://kaikki.org, wiktextract output):
  fr  French Wiktionary, Russian entries   -> French glosses, examples, declensions, IPA
  en  English Wiktionary, Russian entries  -> conjugations, aspect pairs, English fallback
  freq  hermitdave/FrequencyWords ru_50k.txt (MIT)  -> ranking

Usage:
  python3 tools/build_dictionary.py --fr ru.jsonl --en en-ru.jsonl --freq ru_50k.txt \
      --out Pandouchka/Resources/dictionary.sqlite

Wiktionary content is CC BY-SA 4.0; the app credits it on the About screen.
"""
import argparse
import json
import os
import re
import sqlite3
import unicodedata

ACUTE = "\u0301"
GRAVE = "\u0300"
SKIP_POS = {"character", "symbol", "punct", "infix", "interfix"}
# Form tags that are metadata, not inflections.
META_TAGS = {"romanization", "table-tags", "inflection-template", "class", "error-unknown-tag",
             "error-unrecognized-form", "canonical"}
DROP_FORM_TAGS = {"dated", "obsolete", "archaic", "rare", "proscribed", "poetic", "dialectal", "nonstandard"}
# A table form must carry at least one of these to be an inflection of the entry.
INFLECTION_TAGS = {"nominative", "genitive", "dative", "accusative", "instrumental", "prepositional",
                   "locative", "partitive", "vocative", "singular", "plural", "first-person", "second-person",
                   "third-person", "present", "past", "future", "infinitive", "imperative", "participle",
                   "short-form", "comparative", "superlative", "masculine", "feminine", "neuter"}
CYR = re.compile(r"^[\u0400-\u04FF\u0301\u0300\-]+$")


# Personal pronoun paradigms: both Wiktionaries mix all persons into one table, so these are
# written out by hand.
PERSONAL = {
    "я": [("меня́", "genitive accusative"), ("мне", "dative prepositional"), ("мной", "instrumental"), ("мно́ю", "instrumental")],
    "ты": [("тебя́", "genitive accusative"), ("тебе́", "dative prepositional"), ("тобо́й", "instrumental"), ("тобо́ю", "instrumental")],
    "он": [("его́", "genitive accusative"), ("ему́", "dative"), ("им", "instrumental"), ("нём", "prepositional"),
           ("него́", "genitive accusative after-preposition"), ("нему́", "dative after-preposition"), ("ним", "instrumental after-preposition")],
    "она": [("её", "genitive accusative"), ("ей", "dative instrumental"), ("е́ю", "instrumental"), ("ней", "prepositional"),
            ("неё", "genitive accusative after-preposition"), ("ней", "dative instrumental after-preposition"), ("не́ю", "instrumental after-preposition")],
    "оно": [("его́", "genitive accusative"), ("ему́", "dative"), ("им", "instrumental"), ("нём", "prepositional"),
            ("него́", "genitive accusative after-preposition"), ("нему́", "dative after-preposition"), ("ним", "instrumental after-preposition")],
    "мы": [("нас", "genitive accusative prepositional"), ("нам", "dative"), ("на́ми", "instrumental")],
    "вы": [("вас", "genitive accusative prepositional"), ("вам", "dative"), ("ва́ми", "instrumental")],
    "себя": [("себя́", "genitive accusative"), ("себе́", "dative prepositional"), ("собо́й", "instrumental"), ("собо́ю", "instrumental")],
    "они": [("их", "genitive accusative"), ("им", "dative"), ("и́ми", "instrumental"),
            ("них", "genitive accusative prepositional after-preposition"), ("ним", "dative after-preposition"), ("ни́ми", "instrumental after-preposition")],
}
MODERN = re.compile(r"^[а-яё][а-яё\-]*$")
PRE_REFORM = re.compile(r"[ѣіѳѵ]|[бвгджзклмнпрстфхцчшщ]ъ$")


def key(word: str) -> str:
    """Lookup key: lowercase, no stress marks, ё -> е. Must match RussianText.key in Swift."""
    w = word.lower().replace(ACUTE, "").replace(GRAVE, "")
    return w.replace("ё", "е")


def display(word: str) -> str:
    """Display spelling without stress marks (keeps ё)."""
    return word.replace(ACUTE, "").replace(GRAVE, "")


def stress_index(word: str) -> int:
    """Index (in the display string) of the stressed vowel, -1 when not marked.
    A word with ё is stressed on ё."""
    i = word.find(ACUTE)
    if i < 0:
        i = word.find(GRAVE)
    if i > 0:
        # characters before the mark, minus earlier marks
        return len(display(word[:i])) - 1
    d = display(word)
    j = d.lower().find("ё")
    return j


def fr_strip(s: str) -> str:
    s = unicodedata.normalize("NFD", s.lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


FR_STOP = set("""le la les l un une des de du d a au aux en et ou ni que qui quoi dont se s sa son ses
sur sous par pour avec sans dans chez ce cet cette ces y est etre avoir faire quelque quelqu chose
qqch qqn quelqu'un on il elle ils elles lui leur leurs me te nous vous ne pas plus tres comme etc
sens figure familier populaire voir variante""".split())
FR_WORD = re.compile(r"[a-zàâäçéèêëîïôöùûüÿœæ'\-]+", re.I)


def fr_terms(gloss: str):
    """Yields (term, primary) for a French gloss. Primary terms are the head words of each
    comma/semicolon separated alternative, outside parentheses."""
    g = re.sub(r"\([^)]*\)", " ", gloss)
    g = g.strip().rstrip(".")
    for part_index, part in enumerate(re.split(r"[;,]", g)):
        words = [w.strip("'-") for w in FR_WORD.findall(part)]
        words = [fr_strip(w) for w in words if w]
        content = [w for w in words if w not in FR_STOP and len(w) > 1]
        for i, w in enumerate(content):
            yield w, (i == 0 and len(content) <= 3)


def clean_gloss(g: str) -> str:
    g = g.strip()
    return g


def load_freq(path):
    rank = {}
    with open(path, encoding="utf-8") as f:
        for i, line in enumerate(f):
            w = line.split(" ")[0]
            k = key(w)
            rank.setdefault(k, i + 1)
    return rank


def iter_jsonl(path):
    with open(path, encoding="utf-8") as f:
        for line in f:
            yield json.loads(line)


def is_form_entry(e):
    ss = e.get("senses", [])
    return bool(ss) and all(("form_of" in s) or ("alt_of" in s) or ("form-of" in s.get("tags", [])) for s in ss)


def good_sense(s):
    t = set(s.get("tags", []))
    return s.get("glosses") and not ({"obsolete", "archaic"} & t) and "form_of" not in s


def table_forms(e):
    out = []
    for f in e.get("forms", []):
        tags = set(f.get("tags", []))
        form = f.get("form", "")
        if not tags or tags & META_TAGS or tags & DROP_FORM_TAGS or not tags & INFLECTION_TAGS:
            continue
        if " " in form or not CYR.match(form) or not MODERN.match(key(form)):
            continue
        out.append((form, sorted(tags)))
    return out


def canonical(e):
    for f in e.get("forms", []):
        if "canonical" in f.get("tags", []) and CYR.match(f.get("form", "").replace(" ", "")):
            return f["form"], set(f.get("tags", []))
    return None, set()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fr", required=True)
    ap.add_argument("--en", required=True)
    ap.add_argument("--freq", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--supplement", help="hand-written entries (JSON), see tools/supplement.json")
    a = ap.parse_args()

    rank = load_freq(a.freq)
    entries = {}      # (key, pos) -> dict
    form_of = []      # (form_key, form_display_with_stress, lemma_key, pos, tags)

    def get(k, pos):
        return entries.setdefault((k, pos), {
            "key": k, "pos": pos, "word": None, "fr": [], "en": [], "examples": [], "forms": [],
            "ipa": None, "audio": None, "gender": None, "animacy": None, "aspect": None, "pairs": [],
            "from_fr": False,
        })

    for src in ("fr", "en"):
        for e in iter_jsonl(a.fr if src == "fr" else a.en):
            pos = e.get("pos")
            word = e.get("word", "")
            if pos in SKIP_POS or not word or " " in word.strip() and pos != "phrase":
                continue
            if PRE_REFORM.search(word.lower()) or not MODERN.match(key(word)):
                continue
            if is_form_entry(e):
                for s in e["senses"]:
                    for fo in s.get("form_of", []) or []:
                        lw = fo.get("word")
                        if lw:
                            canon, _ = canonical(e)
                            form_of.append((key(word), canon or word, key(lw), pos, " ".join(sorted(set(s.get("tags", [])) - {"form-of"}))))
                continue
            senses = [s for s in e.get("senses", []) if good_sense(s)]
            if not senses:
                continue
            ent = get(key(word), pos)
            glosses = [clean_gloss(" ; ".join(s["glosses"][-1:])) for s in senses]
            glosses = [g for g in glosses if g]
            if src == "fr":
                ent["from_fr"] = True
                ent["fr"].extend(g for g in glosses if g not in ent["fr"])
                for s in senses:
                    for ex in s.get("examples", []):
                        if ex.get("text") and ex.get("translation") and len(ent["examples"]) < 3 and len(ex["text"]) < 160:
                            ent["examples"].append([ex["text"], ex["translation"]])
                tags = set(e.get("tags", []))
            else:
                ent["en"].extend(g for g in glosses if g not in ent["en"])
                _, tags = canonical(e)
                tags |= set(e.get("tags", []))
            canon, ctags = canonical(e)
            tf = table_forms(e)
            if not ent["word"]:
                if canon:
                    ent["word"] = canon
                else:
                    head = [f for f, t in tf if ({"nominative", "singular"} <= set(t) and "plural" not in t) or "infinitive" in t
                            or ({"masculine", "nominative"} <= set(t))]
                    ent["word"] = head[0] if head else word
            elif stress_index(ent["word"]) < 0 and canon and display(canon) == display(ent["word"]):
                ent["word"] = canon
            if tf and (src == "en" or not ent["forms"]):
                ent["forms"] = tf
            for g in ("masculine", "feminine", "neuter"):
                if g in tags and pos == "noun" and not ent["gender"]:
                    ent["gender"] = g
            for an in ("animate", "inanimate"):
                if an in tags and pos == "noun" and not ent["animacy"]:
                    ent["animacy"] = an
            if pos == "verb":
                for asp in ("imperfective", "perfective"):
                    if asp in ctags or asp in tags:
                        ent["aspect"] = ent["aspect"] or asp
                for f in e.get("forms", []):
                    ft = set(f.get("tags", []))
                    if ft in ({"perfective"}, {"imperfective"}) and CYR.match(f["form"]):
                        if f["form"] not in ent["pairs"]:
                            ent["pairs"].append(f["form"])
            for snd in e.get("sounds", []):
                if snd.get("ipa") and not ent["ipa"]:
                    ent["ipa"] = snd["ipa"].strip("\\[]/")
                if snd.get("mp3_url") and not ent["audio"]:
                    ent["audio"] = snd["mp3_url"]

    if a.supplement:
        with open(a.supplement, encoding="utf-8") as f:
            for item in json.load(f):
                ent = get(key(item["word"]), item["pos"])
                ent["word"] = item["word"]
                ent["fr"] = item["fr"] + [g for g in ent["fr"] if g not in item["fr"]]
                ent["en"] = ent["en"] or item.get("en", [])
                ent["forms"] = [(f, t.split()) for f, t in item["forms"]] or ent["forms"]
                ent["gender"] = item.get("gender") or ent["gender"]
                ent["animacy"] = item.get("animacy") or ent["animacy"]
                ent["from_fr"] = True
                ent["supplement"] = True

    for (k, pos), ent in entries.items():
        if pos == "pron" and k in PERSONAL:
            ent["forms"] = [(f, t.split()) for f, t in PERSONAL[k]]
        elif pos == "pron":
            ent["forms"] = [(f, t) for f, t in ent["forms"] if "personal" not in t]

    # Keep French entries, and English-only ones that are reasonably common.
    def entry_rank(ent):
        if ent["key"] in rank:
            return rank[ent["key"]]
        best = 10 ** 6
        for f, _ in ent["forms"]:
            best = min(best, rank.get(key(f), 10 ** 6))
        return best

    kept = []
    for ent in entries.values():
        r = entry_rank(ent)
        ent["rank"] = r
        if ent.get("supplement"):
            ent["rank"] = min(r, 5000)
            kept.append(ent)
        elif ent["pos"] == "name":
            if r <= 30000 and (ent["fr"] or ent["en"]):
                kept.append(ent)
        elif ent["from_fr"] or r <= 50000:
            kept.append(ent)
    kept.sort(key=lambda e: (e["rank"], e["key"]))

    if os.path.exists(a.out):
        os.remove(a.out)
    db = sqlite3.connect(a.out)
    db.executescript("""
    PRAGMA page_size = 4096;
    CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT) WITHOUT ROWID;
    CREATE TABLE tagset (id INTEGER PRIMARY KEY, tags TEXT NOT NULL);
    -- One row per dictionary entry. JSON columns are arrays.
    CREATE TABLE entry (
      id INTEGER PRIMARY KEY,
      word TEXT NOT NULL,      -- display spelling, stress marked with U+0301
      key TEXT NOT NULL,       -- normalized lookup key
      pos TEXT NOT NULL,
      rank INTEGER NOT NULL,   -- frequency rank, lower is more common
      fr TEXT,                 -- French glosses (JSON)
      en TEXT,                 -- English glosses (JSON)
      examples TEXT,           -- [[ru, fr], ...] (JSON)
      gender TEXT, animacy TEXT, aspect TEXT,
      pairs TEXT,              -- aspect partners (JSON)
      ipa TEXT, audio TEXT
    );
    -- Every inflected spelling -> entry. word is the stress-marked spelling.
    CREATE TABLE form (
      key TEXT NOT NULL,
      entry INTEGER NOT NULL,
      stress INTEGER NOT NULL, -- index of the stressed letter in the display spelling, -1 unknown
      word TEXT,               -- display spelling when it differs from key (ё, capitals), else NULL
      tagset INTEGER NOT NULL,
      ord INTEGER NOT NULL
    );
    -- French word -> entry, for French -> Russian lookups.
    CREATE TABLE fr_index (term TEXT NOT NULL, entry INTEGER NOT NULL, primary_hit INTEGER NOT NULL);
    """)
    tagsets = {}

    def tagset_id(tags):
        t = " ".join(tags)
        if t not in tagsets:
            tagsets[t] = len(tagsets) + 1
            db.execute("INSERT INTO tagset VALUES (?, ?)", (tagsets[t], t))
        return tagsets[t]

    id_of = {}
    form_rows = []
    fr_rows = set()
    for i, ent in enumerate(kept, start=1):
        id_of[(ent["key"], ent["pos"])] = i
        j = lambda v: json.dumps(v, ensure_ascii=False) if v else None
        db.execute("INSERT INTO entry VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", (
            i, ent["word"], ent["key"], ent["pos"], ent["rank"], j(ent["fr"][:8]), j([g[:240] for g in ent["en"][:(3 if ent["fr"] else 6)]]),
            j(ent["examples"]), ent["gender"], ent["animacy"], ent["aspect"], j(ent["pairs"][:4]),
            ent["ipa"], ent["audio"]))
        seen = set()
        form_rows.append((ent["key"], i, ent["word"], tagset_id(["lemma"]), 0))
        seen.add((ent["key"], display(ent["word"])))
        for o, (f, tags) in enumerate(ent["forms"], start=1):
            form_rows.append((key(f), i, f, tagset_id(tags), o))
        for g_index, g in enumerate(ent["fr"][:8]):
            for term, primary in fr_terms(g):
                fr_rows.add((term, i, 1 if (primary and g_index < 3) else 0))

    # Form-of entries add spellings that are missing from tables (comparatives, variants).
    have = {(r[0], r[1]) for r in form_rows}
    for fkey, fword, lkey, pos, tags in form_of:
        eid = id_of.get((lkey, pos))
        if eid is None:
            for p in ("noun", "verb", "adj", "adv", "pron", "num", "det", "name"):
                eid = id_of.get((lkey, p))
                if eid:
                    break
        lemma_key = kept[eid - 1]["key"] if eid else None
        if eid and lemma_key in PERSONAL:
            continue
        if eid and (fkey, eid) not in have and MODERN.match(fkey):
            have.add((fkey, eid))
            form_rows.append((fkey, eid, fword, tagset_id(tags.split() if tags else ["form"]), 900))

    def compact(r):
        k, eid, w, ts, o = r
        d = display(w)
        return (k, eid, stress_index(w), None if d == k else d, ts, o)
    db.executemany("INSERT INTO form VALUES (?,?,?,?,?,?)", [compact(r) for r in form_rows])
    db.executemany("INSERT INTO fr_index VALUES (?,?,?)", sorted(fr_rows))
    db.executescript("""
    CREATE INDEX form_key ON form(key);
    CREATE INDEX form_entry ON form(entry, ord);
    CREATE INDEX entry_key ON entry(key);
    CREATE INDEX fr_term ON fr_index(term);
    """)
    db.execute("INSERT INTO meta VALUES ('version', '1')")
    db.execute("INSERT INTO meta VALUES ('entries', ?)", (str(len(kept)),))
    db.commit()
    db.execute("VACUUM")
    db.close()
    print(f"entries={len(kept)} forms={len(form_rows)} fr_terms={len(fr_rows)} tagsets={len(tagsets)}")
    print(f"size={os.path.getsize(a.out) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
