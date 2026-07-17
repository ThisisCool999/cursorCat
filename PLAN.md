# Mochi — desktop pet cat (canonical plan)

A native macOS desktop pet: a pixel-art cat that lives on your screen, roams everywhere (screen bottom, tops of app windows, climbs screen sides, dangles from the menu bar), reacts to you, and has file superpowers.

## Locked decisions (from user)
- Pet: pixel-art cat (~128pt on screen, 32x32 art at 4x nearest-neighbor).
- Roaming: FULL CHAOS — ground + window tops + wall climbing + ceiling/menu-bar hang.
- File powers (all of these):
  1. **Carry**: drop a file on Mochi → he holds it (icon at his mouth/paws); drag it back off him into any app/folder. Living clipboard.
  2. **Desktop watcher**: notices new files on ~/Desktop (runs over, sniffs); occasionally digs up an old forgotten Desktop file and offers it.
  3. **Trash helper**: drop a file on him **while holding ⌥** → he hauls it off and recycles it (NSWorkspace.recycle — always recoverable, never permanent delete).
  4. **Fetch on command**: double-click him (or menu bar → Fetch…) → type "math notes pdf" → Spotlight search → he digs, then holds the file in his mouth; drag it straight out into whatever app needs it. No Finder required.

## Tech
- Pure AppKit + Swift, **no Xcode project** — `bash make_app.sh` compiles `src/*.swift` with swiftc into `Mochi.app` (same pattern as Twin).
- `LSUIElement` (no Dock icon); menu bar 🐾 status item = controls + Quit.
- Pet = small borderless **non-activating NSPanel** (never steals focus), `.statusBar` window level (above windows/Dock/menu bar), joins all Spaces.
- 60fps timer loop; simple gravity/velocity physics; state machine.
- Sprites: pixel art embedded in code as char grids (`src/Sprites.swift`), palette in `src/Palette.swift`, rendered to NSImage cached, nearest-neighbor scaled. `tools/preview.swift` renders a contact sheet PNG for eyeballing.
- Window platforms: `CGWindowListCopyWindowInfo` bounds (no screen-recording permission needed — we never read names/pixels). Own PID excluded. CG top-left coords converted to AppKit bottom-left.
- Desktop watch: DispatchSource on ~/Desktop (triggers the standard one-time "access Desktop folder" prompt; `NSDesktopFolderUsageDescription` set).
- Fetch: `mdfind` filename query, ranked (all tokens in name, prefer recent).

## Files
- `src/Palette.swift` — colors, grid→NSImage renderer (flip H/V variants, cache)
- `src/Sprites.swift` — all pixel-art frames + per-frame mouth anchor points
- `src/Types.swift` — shared types/interfaces (pinned before module fan-out)
- `src/WindowTracker.swift` — walkable window-top platforms (agent)
- `src/SpotlightFetcher.swift` — mdfind wrapper, ranked results (agent)
- `src/DesktopWatcher.swift` — new-file events + random old file (agent)
- `src/Bubble.swift` — pixel-style speech bubble + fetch input bubble (agent)
- `src/StatusBar.swift` — 🐾 menu (agent)
- `src/PetEngine.swift` — state machine, physics, behavior director
- `src/PetView.swift` — rendering, mouse, drag in/out of paws
- `src/AppDelegate.swift`, `src/main.swift`
- `make_app.sh`

## Pet states
idle (sit/tail-flick/blink) · walk/run (ground, window tops) · chase cursor → pounce · climb left/right screen edge · hang from ceiling/menu bar (upside-down crawl) · fall / thrown (drag & fling him, he splats) · dragged (scruff) · sleep (loaf, auto after long idle) · sniff · dig (fetch + trash) · surprised · holding-file overlay on top of most states.

## Interactions
- click: chirp/heart · double-click: fetch prompt · drag: carry him (fling = physics) · right-click: menu
- drop file on him: carry · ⌥-drop: trash run · drag icon off his mouth: real file drag (NSURL pasteboard)

## Status
- [x] Plan agreed (pet/files/roaming picked by user)
- [x] Art: 17 frames drawn + visually verified via tools contact sheet (climb/hang/run derived via rotation/flip/speed at runtime)
- [x] Module fan-out (WindowTracker/Fetch/DesktopWatcher/Bubbles/FinderBridge/StatusBar — all typechecked)
- [x] Engine + view + app shell (Brain+Physics merged into PetEngine.swift)
- [x] Builds clean, launches, falls in, lands on window tops, roams (verified via MOCHI_DEBUG=1 state dump → $TMPDIR/mochi_state.txt)
- [x] Review pass (multi-agent): 3 confirmed bugs fixed (occluder set vs platform candidates split, segments clamped to screen, left-edge-resize teleport guard) + manually adjudicated the unverified findings (sleep now ends, stale errand completions cleared on grab/new-errand, platform hop-down re-landing loop fixed via -6pt detach, trash-run guards heldFile, CGContext pointer-escape fixed)
- [x] v1.1 (user feedback round): 3x scale (96pt cat) + H highlight/S shade pass + soft ground shadow · click held file = open · organic wander (speed jitter, mid-walk flips, micro-pauses, zoomies) · jump up onto window tops · spontaneous cursor pounce → sometimes naps ON cursor (pillow) · sleep→"goes into" cursor as mini sleeping cat, click anywhere to drop him out · Treat Box (fish/biscuit/water = yum + hearts; chocolate/lemon = recoil/hiss/flee) as cursor follower sprite · pixel HelpCard ("What Can Mochi Do?") · Treat Box + Help in menus
- [x] v1.2 gag batch: EffectsOverlay.swift (single full-screen click-through panel: particles + tongue + fake cursor) — rainbow trail on ~40% of zoomies · water splash after drinking (droplets arc then slide down screen) · tongue-eats-cursor gag (tongueOut/chew frames, 4.4s sequence, spits arrow back) · app-watch quips (NSWorkspace.didActivateApplication, rate-limited 90s) · treats consumed on eat (cursor snack disappears; bad treats re-react fast 5-9s cooldown) · click-him-with-treat = instant feed · comes down off windows/walls for nearby food
- [x] v1.3 real-cursor-eat: CGSSetConnectionProperty(SetsCursorInBackground) at launch so a background LSUIElement app may CGDisplayHideCursor — the tongue gag now actually hides the real pointer for the 3 chew seconds, restored on spit / interruption / quit (applicationWillTerminate → cleanupOnQuit). Tuning: rainbow-run 0.9 + run weight up, cursor-eat rate 0.022/s, landing squash only on impact>1500 & 0.14s.
- [x] v1.4 MULTI-CAT + coats + custom drawer + guests (big refactor: PetController is now a DIRECTOR over `[Cat]`, not a single pet):
  - Cat.swift = per-cat unit (engine+panel+view+bubbles+look+spec). PetController owns shared services (tracker/effects/companion/treatBox/helpCard/pixelDrawer/statusbar/fetch/finder/watcher) + the single displayLink that ticks ALL cats.
  - Coats.swift: 8 presets (grey/orange/void/snow/tuxedo/siamese/calico/blue) recoloring the B/S/H/T/C/P/N palette chars via Coat.colorMap; render path is Sprites.cg(look:key:...) keyed by CatLook.id.
  - CatLook/CatSpec/CatStore: permanent cats persisted in UserDefaults "mochi.cats.v1" (name+coatId+optional customGrid); default = one grey "Mochi".
  - PixelDrawer.swift (agent-built): paint the sit template interior with the 7 semantic fur colors → saves a custom cat (customGrid used for idle poses, coat recolors motion frames).
  - Guests: occasional temporary friends (random coat, ~35-75s life, fade out + removed), never persisted; 🐾 → Cats submenu (Add a Cat ▸ coats/Draw Your Own…; per-cat Change Coat / Remove).
  - Arbitration: only one cat naps-in-cursor (nappingCat) and one drives the tongue/cursor-hide at a time.
- v1 scope: main screen only; launch-at-login later; sounds later. Window-shoving ("push your windows off the desk") possible but needs Accessibility permission — offered, not built.
- Cursor "transform" is a follower panel next to the pointer (macOS forbids global system-cursor replacement from a background app).

## Notes / gotchas discovered
- `isFloatingPanel = true` silently resets `level` — set `level = .statusBar` LAST (or drop isFloatingPanel).
- The Desktop TCC prompt BLOCKS whichever thread does the first ~/Desktop read: preflight it on a background queue before `DesktopWatcher.start()` (PetController.start()).
- Finder AppleScript: `it` is a reserved word; FinderBridge uses `di` as loop var.
- StatusBar captures MenuActions at init — wire all actions before constructing StatusBarController.
- Set petPanel level/collectionBehavior before creating BubbleController (bubbles inherit at creation).
- tools/main.swift must be named main.swift (top-level code); build preview: `swiftc -swift-version 5 src/Palette.swift src/Sprites.swift tools/main.swift -o preview && ./preview sheet.png`.
- Debug: launch with `MOCHI_DEBUG=1 ./Mochi.app/Contents/MacOS/Mochi` → 1Hz engine state lines in $TMPDIR/mochi_state.txt.
- CRITICAL: `NSView.displayLink` pauses when the view's window is not visible — NEVER `orderOut` the pet panel (the whole tick pipeline dies and nothing can ever un-hide it). Hide via `alphaValue = 0` + `ignoresMouseEvents = true` instead (cursor-nap does this). Recovery paths: watchdog in step() (off-screen → summon; hidden >150s → force wake), `applicationShouldHandleReopen` → summon (double-clicking Mochi.app always brings him back), 🐾 → Summon Mochi.
