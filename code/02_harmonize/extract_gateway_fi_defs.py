"""Extract Gateway Harmonized CHARLS deficit definitions from the official .do file.

Read-only. Parses bbxleyec.do (GH_CHARLS_long D.2) to recover, for each candidate
FI deficit, the raw CHARLS variables and the exact recode logic Gateway uses.
"""
import re, csv, sys
from pathlib import Path

DO = Path("D:/AI_project/sql/Charls/bbxleyec.do")
OUT = Path("D:/AI_project/project3/docs/gateway_charls_fi_defs_2026-07-27.csv")

# candidate deficits: (harmonized_stem, domain, fi_note)
TARGETS = [
    # --- comorbidity (self-reported doctor dx) ---
    ("hibpe","comorbidity","hypertension"),
    ("diabe","comorbidity","diabetes"),
    ("cancre","comorbidity","cancer"),
    ("lunge","comorbidity","chronic lung disease"),
    ("hearte","comorbidity","heart disease"),
    ("stroke","comorbidity","stroke"),
    ("psyche","comorbidity","psychiatric problem"),
    ("arthre","comorbidity","arthritis"),
    ("dyslipe","comorbidity","dyslipidemia"),
    ("livere","comorbidity","liver disease"),
    ("kidneye","comorbidity","kidney disease"),
    ("digeste","comorbidity","digestive disease"),
    ("asthmae","comorbidity","asthma"),
    # --- ADL (use 'a' = some difficulty) ---
    ("dressa","adl","dressing"),
    ("batha","adl","bathing"),
    ("eata","adl","eating"),
    ("beda","adl","bed transfer"),
    ("toilta","adl","toileting"),
    ("urina","adl","continence"),
    # --- IADL ---
    ("moneya","iadl","managing money"),
    ("medsa","iadl","taking medication"),
    ("shopa","iadl","shopping"),
    ("mealsa","iadl","preparing meals"),
    ("housewka","iadl","housework"),
    # --- mobility / function ---
    ("walk100a","mobility","walk 100m"),
    ("walk1kma","mobility","walk 1km"),
    ("climsa","mobility","climb flights of stairs"),
    ("chaira","mobility","chair rise"),
    ("joga","mobility","jog 1km"),
    ("stoopa","mobility","stoop/kneel/crouch"),
    ("armsa","mobility","raise arms"),
    ("lifta","mobility","lift 5kg"),
    ("dimea","mobility","pick up coin"),
    # --- sensory ---
    ("dsight","sensory","distance vision"),
    ("nsight","sensory","near vision"),
    ("hearing","sensory","hearing"),
    # --- general health ---
    ("shlt","general","self-rated health"),
    ("painfr","general","frequent pain"),
    ("fall","general","fall history"),
    ("hlthlm_c","general","health limits activity"),
    ("slfmem","cognition","self-rated memory"),
    ("hearaid","general","wears hearing aid"),   # da038; NOT da040 (da040=noteeth/dentures)
    ("mbmi","general","measured BMI"),
    ("mbmicata","general","BMI category"),
]

def main():
    if not DO.exists():
        sys.exit(f"missing: {DO}")
    lines = DO.read_text(encoding="utf-8", errors="replace").splitlines()

    rows = []
    for stem, domain, note in TARGETS:
        # first definition block: gen r`wv'<stem>
        pat_gen = re.compile(r"^\s*gen\s+r`wv'" + re.escape(stem) + r"\s*=")
        start = next((i for i,l in enumerate(lines) if pat_gen.match(l)), None)
        if start is None:
            rows.append(dict(harmonized_var=f"r{{wave}}{stem}", domain=domain,
                             concept=note, found="NOT_FOUND", source_line="",
                             raw_vars="", recode_logic="", missing_codes=""))
            continue

        # collect until label values / next gen
        block = []
        for l in lines[start:start+40]:
            block.append(l)
            if re.match(r"^\s*label values", l):
                break

        body = "\n".join(block)
        # raw CHARLS vars: lowercase letter+digits patterns like db010, da007_7_
        raw = sorted(set(re.findall(r"\b([a-z]{2}\d{3}[a-z0-9_]*)\b", body)))
        # missing codes used
        miss = sorted(set(re.findall(r"\.(m|d|r|a|e|s|p|w|x|i|u|v)\b", body)))
        # substantive assignment lines: 0/1 for binary deficits, any value for
        # multi-category source items (e.g. 1-5 Likert vision/hearing, measured BMI)
        assign = re.compile(r"replace\s+r`wv'" + re.escape(stem) + r"\s*=\s*([^.\s]\S*)")
        logic = [l.strip() for l in block if assign.search(l)]
        if not logic:
            logic = [l.strip() for l in block
                     if stem in l and re.search(r"\b(replace|missing_c)", l)]

        rows.append(dict(
            harmonized_var=f"r{{wave}}{stem}", domain=domain, concept=note,
            found="OK", source_line=start+1,
            raw_vars=";".join(raw),
            recode_logic=" || ".join(logic),
            missing_codes=";".join("."+m for m in miss),
        ))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=["harmonized_var","domain","concept","found",
                                          "source_line","raw_vars","missing_codes","recode_logic"])
        w.writeheader(); w.writerows(rows)

    ok = sum(r["found"]=="OK" for r in rows)
    print(f"targets={len(rows)}  found={ok}  missing={len(rows)-ok}")
    print(f"-> {OUT}")
    for r in rows:
        if r["found"] != "OK":
            print(f"   NOT_FOUND: {r['harmonized_var']:22s} {r['concept']}")

if __name__ == "__main__":
    main()
