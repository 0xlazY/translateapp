#!/usr/bin/env python3
"""Records the story narration with Silero TTS (neural, offline, runs on CPU).

For every story it writes, in Pandouchka/Stories/Audio/:
  <id>.m4a            AAC, mono, loudness-normalised
  <id>.timings.json   start/end of every line, for highlighting and "play this sentence"

Runs in the tools container (see tools/tts.Containerfile):
  podman build -t pandouchka-tts -f tools/tts.Containerfile tools
  podman run --rm -v "$PWD:/repo:Z" -v pandouchka-tts-cache:/cache pandouchka-tts \
      python /repo/tools/make_audio.py --speaker xenia [story-id ...]

Silero models: https://github.com/snakers4/silero-models (CC BY-NC-SA 4.0, fine for
personal use, not for selling the app).
"""
import argparse
import json
import os
import re
import subprocess
import tempfile
import wave

import numpy as np
import torch

RATE = 48000
LEAD = 0.35         # silence before the first line
GAP = 0.55          # between lines
PARAGRAPH = 1.0     # before a new paragraph
TAIL = 0.8


def speakable(text: str) -> str:
    """Silero reads Cyrillic and basic punctuation; quotes and dashes become pauses."""
    t = text.replace("«", "").replace("»", "").replace("„", "").replace("“", "")
    t = re.sub(r"\s+[—–]\s+", ", ", t)
    t = t.replace("—", ", ").replace("–", ", ")
    t = re.sub(r",\s*,", ",", t)
    t = re.sub(r"^\s*,\s*", "", t)
    t = re.sub(r",\s*([.!?])", r"\1", t)
    return re.sub(r"\s+", " ", t).strip()


def silence(seconds: float) -> np.ndarray:
    return np.zeros(int(seconds * RATE), dtype=np.float32)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*", help="story ids (default: all)")
    ap.add_argument("--speaker", default="xenia", help="xenia, baya, kseniya, aidar, eugene")
    ap.add_argument("--repo", default="/repo")
    ap.add_argument("--cache", default="/cache")
    ap.add_argument("--sample", action="store_true",
                    help="write the start of one story in every voice to voice-samples/, to choose a speaker")
    a = ap.parse_args()

    stories = json.load(open(os.path.join(a.repo, "Pandouchka/Stories/stories.json"), encoding="utf-8"))["stories"]
    if a.ids:
        stories = [s for s in stories if s["id"] in a.ids]
    out_dir = os.path.join(a.repo, "Pandouchka/Stories/Audio")
    os.makedirs(out_dir, exist_ok=True)

    torch.hub.set_dir(os.path.join(a.cache, "hub"))
    torch.set_num_threads(max(os.cpu_count() or 2, 2))
    model, _ = torch.hub.load("snakers4/silero-models", "silero_tts", language="ru", speaker="v4_ru", trust_repo=True)

    if a.sample:
        story = next(s for s in json.load(open(os.path.join(a.repo, "Pandouchka/Stories/stories.json"),
                                               encoding="utf-8"))["stories"] if s["id"] == "pirozhok-propal")
        text = " ".join(speakable(l["ru"]) for l in story["lines"][:4])
        sample_dir = os.path.join(a.repo, "voice-samples")
        os.makedirs(sample_dir, exist_ok=True)
        for speaker in ["xenia", "baya", "kseniya", "aidar", "eugene"]:
            wav_path = os.path.join(sample_dir, f"{speaker}.wav")
            model.save_wav(text=text, speaker=speaker, sample_rate=RATE, put_accent=True, put_yo=True, audio_path=wav_path)
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav_path, "-b:a", "96k",
                            os.path.join(sample_dir, f"{speaker}.mp3")], check=True)
            os.remove(wav_path)
            print("sample:", speaker)
        return

    for story in stories:
        pieces = [silence(LEAD)]
        t = LEAD
        spans = []
        for i, line in enumerate(story["lines"]):
            if i > 0:
                gap = PARAGRAPH if line.get("paragraph") else GAP
                pieces.append(silence(gap))
                t += gap
            audio = model.apply_tts(text=speakable(line["ru"]), speaker=a.speaker, sample_rate=RATE,
                                    put_accent=True, put_yo=True).numpy().astype(np.float32)
            start = t
            pieces.append(audio)
            t += len(audio) / RATE
            spans.append({"start": round(start, 3), "end": round(t, 3)})
        pieces.append(silence(TAIL))
        t += TAIL
        signal = np.concatenate(pieces)
        pcm = (np.clip(signal, -1, 1) * 32767).astype(np.int16)

        with tempfile.TemporaryDirectory() as tmp:
            wav_path = os.path.join(tmp, "story.wav")
            with wave.open(wav_path, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(pcm.tobytes())
            m4a = os.path.join(out_dir, f"{story['id']}.m4a")
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav_path,
                            "-af", "loudnorm=I=-18:TP=-1.5:LRA=11", "-ar", "44100", "-ac", "1",
                            "-c:a", "aac", "-b:a", "64k", m4a], check=True)

        with open(os.path.join(out_dir, f"{story['id']}.timings.json"), "w", encoding="utf-8") as f:
            json.dump({"voice": f"silero-v4_ru-{a.speaker}", "duration": round(t, 3), "lines": spans}, f, indent=1)
        print(f"{story['id']}: {t:.1f}s, {len(spans)} lines")


if __name__ == "__main__":
    main()
