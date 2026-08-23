# Midnight Blocks

A self-contained, touch-first Tetris web app in a single HTML file (`index.html`).
No build step, no dependencies, no network required — everything (game logic,
styles, sounds) is inline.

## Playing on iPhone

**Fully offline (local file):**
1. Get `index.html` onto your phone (AirDrop it, email it to yourself, or
   download it from this repo) and choose **Save to Files**.
2. Tap the file in the Files app — the game runs right in the preview.
   For a nicer full-screen experience, open it with a file-browser app that has
   a built-in browser (e.g. the free *Documents by Readdle*).

**App-like install (needs hosting):**
1. Serve the file over HTTPS (GitHub Pages or any static host) and open the
   URL in Safari.
2. Share → **Add to Home Screen**. The page ships the `apple-mobile-web-app`
   meta tags, so it launches full-screen without Safari chrome.

## Controls

| Gesture | Action |
| --- | --- |
| Drag left/right | Move piece (follows your finger, column by column) |
| Tap right / left half | Rotate clockwise / counter-clockwise |
| Drag down slowly | Soft drop |
| Flick down | Hard drop |
| Swipe up (or tap the Hold tray) | Hold piece |

Keyboard (desktop): arrows/WASD move and rotate, `Z`/`X` rotate, `Space` hard
drop, `C`/`Shift` hold, `P`/`Esc` pause.

## Features

7-bag randomizer, SRS rotation with wall kicks, ghost piece, hold, 3-piece next
queue, lock delay with bounded resets, line-clear animation, guideline-style
scoring with soft/hard-drop points, level speed curve, WebAudio sound effects
with a persistent mute toggle, and a high score saved in `localStorage`.
Auto-pauses when the app goes to the background; safe-area aware for notched
iPhones.
