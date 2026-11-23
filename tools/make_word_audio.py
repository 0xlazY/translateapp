#!/usr/bin/env python3
"""Records single-word pronunciations with Silero for the app's offline word pack.

Words: the N most common dictionary entries (dictionary form, stress from the
dictionary) plus every word that appears in the stories (as written there).
Output: Pandouchka/WordAudio/<hex of the lookup key>.m4a, AAC mono 32 kbps.
Existing files are kept, so re-running only records what is missing.

  podman run --rm -v "$PWD:/repo:Z" -v pandouchka-tts-cache:/cache pandouchka-tts \
      python /repo/tools/make_word_audio.py --speaker xenia --top 5000

Needs Pandouchka/Resources/dictionary.sqlite (xcodegen unpacks it, or:
gunzip -c Data/dictionary.sqlite.gz > Pandouchka/Resources/dictionary.sqlite).
"""
import argparse
import json
import os
import re
import sqlite3
import subprocess
import tempfile
import wave
from concurrent.futures import ThreadPoolExecutor

import numpy as np
import torch

RATE = 24000
ACUTE = "́"
VOWELS = "аеёиоуыэюяАЕЁИОУЫЭЮЯ"


def key(word: str) -> str:
    """Same as RussianText.key in Swift and key() in build_dictionary.py."""
    return word.lower().replace(ACUTE, "").replace("̀", "").replace("ё", "е")


def file_name(k: str) -> str:
    return k.encode("utf-8").hex()


def silero_stress(word: str) -> str:
    """кни́га -> кн+ига: Silero takes '+' before the stressed vowel."""
    out = []
    chars = list(word)
    for i, c in enumerate(chars):
        if c == ACUTE:
            continue
        if i + 1 < len(chars) and chars[i + 1] == ACUTE and c in VOWELS:
            out.append("+")
        out.append(c)
    return "".join(out)


def trim(audio: np.ndarray, threshold=0.01, pad=0.06) -> np.ndarray:
    idx = np.where(np.abs(audio) > threshold)[0]
    if len(idx) == 0:
        return audio
    p = int(pad * RATE)
    return audio[max(idx[0] - p, 0): min(idx[-1] + p, len(audio))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--speaker", default="xenia")
    ap.add_argument("--top", type=int, default=5000)
    ap.add_argument("--repo", default="/repo")
    ap.add_argument("--cache", default="/cache")
    a = ap.parse_args()

    db = sqlite3.connect(os.path.join(a.repo, "Pandouchka/Resources/dictionary.sqlite"))
    words = {}  # key -> text to speak
    for word, k in db.execute(
            "SELECT word, key FROM entry WHERE pos != 'name' AND (fr IS NOT NULL OR en IS NOT NULL) ORDER BY rank, id"):
        if len(words) >= a.top:
            break
        if " " not in word and k not in words:
            words[k] = silero_stress(word)

    stories = json.load(open(os.path.join(a.repo, "Pandouchka/Stories/stories.json"), encoding="utf-8"))["stories"]
    for s in stories:
        texts = [l["ru"] for l in s["lines"]] + [k["ru"] for k in s["keywords"]]
        for t in texts:
            for w in re.findall(r"[А-Яа-яЁё]+(?:-[А-Яа-яЁё]+)*", t):
                k = key(w)
                if k in words:
                    continue
                # Stress from the dictionary when every reading of the spelling agrees.
                rows = db.execute("SELECT DISTINCT f.stress, f.word FROM form f JOIN entry e ON e.id = f.entry "
                                  "WHERE f.key = ? AND f.stress >= 0 ORDER BY e.rank LIMIT 4", (k,)).fetchall()
                spoken = w.lower()
                if len({r[0] for r in rows}) == 1:
                    base = rows[0][1] or k
                    i = rows[0][0]
                    if i < len(base) and base[i] in VOWELS:
                        spoken = base[:i] + "+" + base[i:]
                words[k] = spoken

    out_dir = os.path.join(a.repo, "Pandouchka/WordAudio")
    os.makedirs(out_dir, exist_ok=True)
    todo = [(k, t) for k, t in words.items() if not os.path.exists(os.path.join(out_dir, file_name(k) + ".m4a"))]
    print(f"{len(words)} words, {len(todo)} to record")

    torch.hub.set_dir(os.path.join(a.cache, "hub"))
    torch.set_num_threads(max(os.cpu_count() or 2, 2))
    model, _ = torch.hub.load("snakers4/silero-models", "silero_tts", language="ru", speaker="v4_ru", trust_repo=True)

    def encode(job):
        wav_path, m4a = job
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav_path, "-af", "loudnorm=I=-16:TP=-1.5",
                        "-ar", "24000", "-ac", "1", "-c:a", "aac", "-b:a", "32k", m4a], check=True)
        os.remove(wav_path)

    with tempfile.TemporaryDirectory() as tmp, ThreadPoolExecutor(max_workers=4) as pool:
        futures = []
        for n, (k, text) in enumerate(todo, 1):
            try:
                audio = model.apply_tts(text=text, speaker=a.speaker, sample_rate=RATE,
                                        put_accent="+" not in text, put_yo=True).numpy().astype(np.float32)
            except Exception as e:  # unusual spellings Silero rejects
                print("skip", k, e)
                continue
            pcm = (np.clip(trim(audio), -1, 1) * 32767).astype(np.int16)
            wav_path = os.path.join(tmp, f"{n}.wav")
            with wave.open(wav_path, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(pcm.tobytes())
            futures.append(pool.submit(encode, (wav_path, os.path.join(out_dir, file_name(k) + ".m4a"))))
            if n % 250 == 0:
                print(f"{n}/{len(todo)}")
        for f in futures:
            f.result()
    print("done")


if __name__ == "__main__":
    main()
