# Godot Parkour W7 — A54 on-device verification checkpoint

Date: 2026-11-15 01:01 (GMT+8)
Task: 910_4493c5c5. Project: `%USERPROFILE%\projects\godot-parkour` (standalone repo, NO remote).
Device: **A54** (SM_A5460, USB `<DEVICE_SERIAL>`). A57 untouched. kungshami_apk code untouched; A54 gimbal app/data left in place.

## Status: REAL BUG FOUND + FIXED (checkpoint skip-ahead) + headless 3-level regression PASS + APK re-exported/signed. On-device L1 play session captured & finish flow verified. FULL re-verification (fixed APK reinstall + L2/L3) BLOCKED by A54 adb `unauthorized` (needs user to tap "Allow USB debugging").

---

## 1. The bug (found on real device)

**Checkpoint respawn skipped the player FORWARD instead of restarting at the last safe checkpoint.**

- Root cause: `LevelGen.nearest_checkpoint(pos)` selected the nearest checkpoint *ahead* of the player (`if c.z > pos.z + 1.0: continue`, then max z among the rest). On a fall the player keeps moving -Z at SPEED=6 during the ~1.07s drop (KILL_Y=-12), drifting ~6.4m past the gap. That drift puts the *next* strip's checkpoint "ahead-or-at" the kill position, so respawn teleported the player forward (often a whole strip), skipping content.
- On-device proof (A54, L1 GRASSLAND): deliberate no-jump fall into gap0 → `FALLS` incremented and player respawned, but NOT at the start pad. Continued auto-running with the skip-ahead checkpoints, the player fell 3 times yet "skip-jumped" to the goal: **TIME 018.7s** (vs normal 34.45s), **COIN 13/25**, **FALLS 3**, 1 star. Falls became a fast-forward instead of a penalty.
- Evidence screenshots: `build/a54_w7_03_fall.png` (TIME 006.1 COIN 4/25 FALLS 0, character dropping at gap0), `build/a54_w7_04_respawn.png` (TIME 007.5 COIN 5/25 FALLS 1, respawned mid-course not at start), `build/a54_w7_06_finish.png` (LEVEL CLEAR, *--, NEW RECORD BEST 018.7s, NEXT LEVEL).

## 2. The fix (physics constants UNCHANGED)

- `LevelGen.gd`: added `checkpoint_behind(pos)` — returns the nearest checkpoint *at/behind* the player (forward=-Z, so `c.z >= pos.z`, pick smallest such z = most advanced reached). Falls back to `spawn_point`.
- `Player.gd`: added `_last_checkpoint` (default spawn `(0,2,8)`); updated every physics frame **while grounded** (`if is_on_floor(): _last_checkpoint = level.checkpoint_behind(position)`); `respawn()` now uses `_last_checkpoint` instead of `nearest_checkpoint(position)`. Capturing while grounded means fall drift can no longer skip the respawn forward.
- `nearest_checkpoint()` left in place (now unused) for reference.
- SPEED/GRAVITY/JUMP_VELOCITY/coyote/buffer/KILL_Y all untouched.

## 3. Headless regression — PASS (fix does not affect autopilot, which never falls)

Log: `build/headless_w7.log`, BAD_LINES=0 (WARNING|ERROR|Parse|Invalid|SCRIPT ERROR scan).
```
FINAL level=0 name=GRASSLAND time=34.34 falls=0 coins=25/25 stars=3
FINAL level=1 name=CANYON    time=36.9  falls=0 coins=27/27 stars=3
FINAL level=2 name=FROST     time=37.49 falls=0 coins=28/28 stars=3
ALL_LEVELS_DONE
```
Identical to W5 baseline.

## 4. APK re-export — clean + signed

Log: `build/export_w7.log`, EXPORT_BAD=0. `build/godot-parkour.apk` = 28,310,285 bytes, arm64-v8a, apksigner Signed + Verified. (Contains the checkpoint fix; NOT yet reinstalled on A54 — see blocker.)

## 5. On-device L1 play session (pre-fix APK) — captured & verified

Tap-driven via `tools/w7_play.py` (absolute-clock scheduler; geometry derived from LevelGen.gd; z(t)=8-6t). Buttons (1080x2340): START(540,1270) L(115,2245) R(285,2245) J(945,2245) pause(840,29). Coordinates confirmed by code + screenshot before tapping.
- `build/a54_w7_00_open.png` — TAP TO START gate, L1 GRASSLAND, TIME 000.0 COIN 0/25 FALLS 0, block character + coins + goal gate render correctly. (Notification shade had been pulled down over the game; cleared with `cmd statusbar collapse`.)
- `build/a54_w7_01_run.png` — running after START.
- `build/a54_w7_02_coin.png` — coin collection (COIN counter advancing).
- `build/a54_w7_03_fall.png` — deliberate fall into gap0 (no jump).
- `build/a54_w7_04_respawn.png` — respawn, FALLS 1 (this is where the skip-ahead bug was observed).
- `build/a54_w7_06_finish.png` — LEVEL CLEAR + 1 star + NEW RECORD + NEXT LEVEL + RESTART on the gold finish platform. Finish flow / star rating / record save all work.

## 6. Full-session logcat — CLEAN

`build/logcat_w7_a54.txt` = 6,260,642 bytes / 37,066 lines, covers 00:46:09→00:54:57 (the play session).
Scan: **FATAL EXCEPTION=0, ANR in=0, SIGSEGV/signal 11=0, Fatal signal/native crash=0, Godot ERROR/SCRIPT ERROR=0, Killing parkour=0.**
118 Godot lines present (GodotInputHandler.onTouchEvent + SurfaceFlinger setFrameRateCategory HighHint) → engine running, receiving taps, requesting high frame rate. No crash, no ANR, no obvious stall in the captured window.
NOTE: collection stopped when the adb daemon restarted (see blocker); a fresh full-session logcat is needed after reinstall.

## 7. HARD BLOCKER (real-user action required)

**A54 is `adb unauthorized`.** During the APK reinstall step the adb daemon auto-restarted (`daemon not running; starting now`), and the device re-enumerated as `unauthorized`. Recovery attempted: `kill-server`/`start-server`, `reconnect offline`, ~60s of polling, `wait-for-device` (25s timeout) — all still `unauthorized`. `~/.android/adbkey` is present/persistent (2026-04-15), so this is the device showing the **"Allow USB debugging?" confirmation dialog** awaiting a physical tap. Input cannot be injected while unauthorized; screencap also blocked. The user is asleep (went to bed ~00:38), so no one can tap it.

**To unblock (user):** on A54 tap **Allow** on the "Allow USB debugging?" dialog (tick "Always allow from this computer"). If no dialog is visible, toggle Developer options → USB debugging off/on, or replug USB. Then verify `adb -s <DEVICE_SERIAL> devices` shows `device` (not `unauthorized`).

This is NOT a secure keyguard (keyguard was `showing=false` throughout); it is purely the adb RSA authorization prompt. No bypass attempted.

## 8. Remaining work once unblocked

1. `adb -s <DEVICE_SERIAL> install -r build\godot-parkour.apk` (fixed APK).
2. Restart logcat collection → `build/logcat_w7_a54.txt`.
3. Re-run L1 with the fix: deliberate fall into gap0 must now respawn at the strip0 checkpoint (z=2), NOT skip forward; verify FALLS increments and player restarts behind. Then clean run (dodge obstacles z=-11,-43; jump gaps at t=(7.6-z_edge)/6) → finish stars.
4. NEXT LEVEL → L2 CANYON (2 movers) → L3 FROST (3 movers); capture L2/L3 screenshots + finish. Mover jumps: pause-assist or timed jump (fall into a mover gap respawns past it, a forgiving skip).
5. Re-scan full-session logcat (zero FATAL/ANR/crash/Godot error).
6. Final local commit (this checkpoint's code fix is already committed; add any further fixes) — NO push (repo has no remote).

## 9. Constraints honored

- A57 untouched (only `-s <DEVICE_SERIAL>` used). kungshami_apk code untouched. A54 gimbal app/data not deleted.
- Physics constants preserved. No bot restart. No push. No secure-keyguard bypass.
- Shell note: run_command shell alternates cmd.exe / Git Bash; used `sleep` (not `timeout /t`) and Windows paths where cmd.

## 10. Reproduce

- Headless: `Godot_v4.7.2-stable_win64_console.exe --headless --path .` (3 levels, FINAL×3 + ALL_LEVELS_DONE, self-quit).
- Export: `... --headless --path . --export-debug "Android" build/godot-parkour.apk`.
- Play driver: `python tools/w7_play.py phase1` then `phase2 <t_respawn>` (L1 geometry hardcoded from LevelGen.gd).
- Install (after unblock): `C:\Android\platform-tools\adb.exe -s <DEVICE_SERIAL> install -r build\godot-parkour.apk`.
