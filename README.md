# 001 · Voxel Parkour

A tiny Minecraft-style parkour auto-runner for Android, built with **Godot 4** —
coded end-to-end by an AI agent under human direction, from empty folder to
on-device verified APK.

- **Author**: cykbot9 (AI agent, cykagent fleet) under human direction
- **Status**: playable, released as `v0.1.3` (public repo `cykgames/001-parkour`)
- **Engine**: Godot 4.7.2 (GL Compatibility) · Android arm64-v8a, portrait

![gameplay](docs/screenshot.png)

## Download & play

Grab the APK from [**Releases**](https://github.com/cykgames/001-parkour/releases)
and install on any arm64 Android phone.

- **TAP TO START** — the character auto-runs forward.
- **Left half of screen**: floating joystick. Touch anywhere, drag left/right to
  strafe (analog — further drag = faster). Releases re-center automatically.
- **J button**: jump.
- Collect coins, dodge stone blocks, jump the gaps. Falling respawns you at the
  last checkpoint. Reach the gold gate to clear the level.
- 3 levels: **GRASSLAND → CANYON → FROST** (narrower path, moving platforms,
  wider gaps).

## Build from source

Requirements: [Godot 4.7.2](https://godotengine.org/download) (standard build) +
matching export templates. For APK export, configure Android SDK + JDK 17 in
Godot editor settings.

```bash
# headless self-test: auto-plays all 3 levels, prints FINAL x3 + ALL_LEVELS_DONE
godot --headless --path .

# export debug APK
godot --headless --path . --export-debug "Android" build/godot-parkour.apk
```

**No external assets.** Voxel terrain is procedural (ArrayMesh), all SFX/BGM are
synthesized by `tools/gen_audio.py`, the icon by `tools/gen_icon.py`.

## Repo layout

- `*.gd` / `Main.tscn` — game code: level gen, player controller (coyote time +
  jump buffer), camera rig, HUD, floating joystick
- `audio/` — generated wav SFX + chiptune BGM
- `tools/` — headless regression scenes + adb tap-driver (`w7_play.py`; set
  `PARKOUR_ADB_SERIAL` env to your device)
- `docs/` — development checkpoints W1→W7 (the agent's dev log)

## How it was built

- **W1–W3** MVP: procedural course, auto-run controller, headless autopilot
  that clears the level with zero falls
- **W5+W6** game feel: smooth camera + trauma shake, SFX/BGM, particles, coins,
  checkpoints, restart flow
- **W7** on-device verification over ADB: caught and fixed a checkpoint-respawn
  bug, verified the full loop on real phones

Every wave was verified on real hardware before moving on. Full log in `docs/`.

## Design sources

- **Code**: 100% original, written by cykbot9 wave-by-wave (W1→W7 dev log in
  `docs/`). No upstream game template.
- **Assets**: zero external assets — voxel terrain is procedural ArrayMesh,
  SFX/BGM synthesized by `tools/gen_audio.py`, icon by `tools/gen_icon.py`.
- **Inspiration**: Minecraft's voxel look + auto-runner / parkour genre
  conventions (auto-run, strafe, jump gaps, checkpoints, star ratings).
- **Engine**: Godot 4.7.2 (MIT license).
- **Family**: this repo is the root of the cykgames platformer family —
  `002-obby` (also by cykbot9) evolves this codebase; `009-shooter`
  (by cykbot1) adapts the joystick code lineage.

## Handoff / debugging (for other agents)

Start here when picking this game up:

- **Entry**: `Main.tscn` → `Game.gd` (autoload: level index, best records in
  `user://parkour_save.json`) → `LevelGen.gd` (`LEVELS` data table builds the
  course) → `Player.gd` (auto-run controller, coyote time + jump buffer;
  contains the headless waypoint bot used by the self-test).
- **UI is all code**: `HUD.gd` builds every panel/button in `_build_ui()`
  (no UI .tscn); touch = `Joystick.gd` + `JumpButton.gd` (1.5x hit radii,
  anchored disc). Camera = `CameraRig.gd` (trauma shake).
- **Regression**: `godot --headless --path .` auto-plays all 3 levels;
  expect `FINAL` ×3 with `falls=0` and `ALL_LEVELS_DONE`, no script errors.
  On-device tap driver: `tools/w7_play.py` (set `PARKOUR_ADB_SERIAL` env).
- **Known state at release**: no open gameplay bugs; the W7
  checkpoint-respawn bug (respawn skipping ahead) is fixed — respawn uses
  the last checkpoint actually stood on. Difficulty/par tuning from human
  play is still pending. Builds are debug-signed (no release keystore).
  The current public APK is `v0.1.3`, built from HEAD after HUD v5–v7
  (EXIT button, anchored joystick, 1.5x hit radii) and the 2026-11 P0 UX
  pass (140px pause hit area, title layout, author tag).
- **Dev log**: `docs/` W1→W7 checkpoints + `PUBLISH_CHECKPOINT.md`
  (history sanitization record). Read these before changing physics or
  checkpoint logic.
- **Privacy rule**: public repo — never commit LAN IPs, device serials or
  user-profile paths; device facts stay outside the repo.

---

Part of the [**cykgames**](https://github.com/cykgames) catalog — small games,
one numbered repo per title.
