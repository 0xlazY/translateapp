# Pandouchka

A personal SwiftUI app for learning Russian from French: graded stories where every word
is tappable, an offline French ↔ Russian dictionary, and spaced-repetition flashcards.

## Features

- **Stories.** 16 original stories, A1 and A2, following Camille, a student from Lyon,
  in Kazan. Every word opens its dictionary entry, with the form explained
  (книгу → кни́га, accusative singular). Sentence translations on demand, read-aloud with
  word highlighting, key words, and a short quiz per story.
- **Words you know show in the text.** Words in your deck are underlined in a colour
  that tracks how well you remember them. Each story shows the share of its words you
  already know.
- **Dictionary.** About 30,000 entries built from the French Wiktionary (French
  meanings) and the English Wiktionary (conjugations, aspect pairs, and a fallback
  meaning). It works offline. Stress marks, declension and conjugation tables, native
  recordings when online. Search in Cyrillic, French, or Latin transliteration
  (*khorosho* finds хорошо).
- **Sentence translation.** Apple's on-device Translation framework, free and offline
  once iOS has downloaded the languages.
- **Flashcards.** FSRS-5 scheduling, Russian → French, French → Russian, or both. Cards
  flip in 3D and can be swiped. Cards made from a story keep the sentence they came from.
- **Import / export.** CSV (spreadsheet- and Anki-friendly, comma, semicolon or tab, with
  or without header) and full JSON backups with review history.

## Build

The project has no committed `.xcodeproj`. It's generated from [project.yml](project.yml).

- **Remotely:** push to GitHub. [The Build workflow](.github/workflows/build.yml) produces
  an unsigned IPA (Actions › latest run › Artifacts).
- **On a Mac:** `brew install xcodegen && xcodegen generate && open Pandouchka.xcodeproj`

XcodeGen unpacks `Data/dictionary.sqlite.gz` into `Pandouchka/Resources/` before
generating the project.

Run the core tests on any OS with Swift or a container runtime:

```sh
podman run --rm -v "$PWD:/repo:ro,Z" swift:6.1 bash -c \
  'cp -r /repo /tmp/r && cd /tmp/r/Packages/PandouchkaCore && swift test'
```

To install the app on an iPhone, see [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md).

## Rebuilding content

```sh
# Dictionary (downloads ~1.1 GB of Wiktionary extracts from kaikki.org)
curl -LO https://kaikki.org/frwiktionary/Russe/kaikki.org-dictionary-Russe.jsonl
curl -LO https://kaikki.org/dictionary/Russian/kaikki.org-dictionary-Russian.jsonl
curl -LO https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/ru/ru_50k.txt
python3 tools/build_dictionary.py --fr kaikki.org-dictionary-Russe.jsonl \
  --en kaikki.org-dictionary-Russian.jsonl --freq ru_50k.txt \
  --supplement tools/supplement.json --out Pandouchka/Resources/dictionary.sqlite
gzip -9 -c Pandouchka/Resources/dictionary.sqlite > Data/dictionary.sqlite.gz

# Stories (source of truth: tools/make_stories.py)
python3 tools/make_stories.py Pandouchka/Stories/stories.json

# Icon
python3 tools/make_icon.py Pandouchka/Assets.xcassets/AppIcon.appiconset/icon-1024.png
python3 tools/make_icon.py Pandouchka/Assets.xcassets/Logo.imageset/logo.png 512
```

`tools/supplement.json` holds hand-written entries the Wiktionary data lacks (the story
characters' names, for example).

## Layout

| Path | Contents |
| --- | --- |
| `Packages/PandouchkaCore` | Platform-independent rules: Russian text handling, FSRS, CSV/backup formats, story model. Tested on Linux and macOS. |
| `Pandouchka/Services` | Dictionary (SQLite), Apple Translation bridge, speech, cards |
| `Pandouchka/Model` | SwiftData storage |
| `Pandouchka/Views` | SwiftUI screens |
| `tools` | Dictionary, story and icon generators |

## Credits

- Dictionary data: [Wiktionary](https://www.wiktionary.org/) contributors, CC BY-SA 4.0,
  extracted by [wiktextract](https://github.com/tatuylonen/wiktextract) / kaikki.org.
- Word frequencies: [FrequencyWords](https://github.com/hermitdave/FrequencyWords), MIT.
- Scheduling: [FSRS](https://github.com/open-spaced-repetition) default parameters.
