# Getting Pandouchka onto an iPhone

The app is for personal use, so it's sideloaded with a free Apple ID through SideStore.
The signature lasts 7 days and SideStore refreshes it from the phone.

## One-time setup (from Linux)

Using [iloader](https://iloader.app/):

1. Install `usbmuxd` and iloader, then connect the iPhone by USB and trust the computer.
2. In iloader, sign in with your Apple ID, select the phone and install SideStore. A
   secondary Apple ID is a sensible precaution.
3. On the iPhone, enable Developer Mode if asked, then trust your Apple ID under
   Settings › General › VPN & Device Management.
4. Install LocalDevVPN from the App Store, connect it, open SideStore, sign in, and
   refresh once.

## Installing a build

1. Push to `main` (or run the **Build** workflow by hand from the Actions tab).
2. Open the finished run, download the `Pandouchka-unsigned-ipa` artifact, unzip it,
   and save `Pandouchka.ipa` to Files on the phone.
   Tagging a commit `v0.1.0` and pushing the tag also publishes the IPA as a release,
   which is easier to download from the phone.
3. In SideStore: My Apps › + › pick the IPA.

Updating keeps your cards: SideStore replaces the app in place as long as the bundle
identifier (`io.github.lazy.pandouchka`) stays the same. Export a backup from
Cards › ⇅ before experimenting anyway.

## Limits of a free account

- Signatures last 7 days: open SideStore (with LocalDevVPN connected) to refresh before then.
- Three sideloaded apps at once, SideStore included.
- Ten new App IDs per week.
- LocalDevVPN uses the iOS VPN slot, so it can conflict with another VPN.

## First launch

- Sentence translation uses Apple's on-device models. The first translation asks to
  download Russian and French. After that it works offline.
- For a better Russian voice, download *Milena (Enhanced)* under Settings › Accessibility
  › Spoken Content › Voices › Russian.
