# Godot Parkour W7 — A54 on-device verification checkpoint

Date: 2026-11-15 01:35 (GMT+8)
Task: 910_4493c5c5. Project: `%USERPROFILE%\projects\godot-parkour` (standalone repo, NO remote).
Device: **A54** (SM_A5460). Transport: **WiFi ADB `<LAN_IP>:5555`** (USB `<DEVICE_SERIAL>` also authorized). A57 untouched. kungshami_apk code untouched; A54 gimbal app/data left in place.

## Status: COMPLETE. Checkpoint skip-ahead bug FIXED + verified on real device. L1 clean run = 0 falls / 25/25 coins / 34.3s / 3 stars / LEVEL CLEAR. L2 CANYON runs on device (movers animate, static gaps 0 falls). Full-session logcat CLEAN (0 crash / 0 ANR / 0 Godot error).

---

## 1. The bug (found on real device, pre-fix)

**Checkpoint respawn skipped the player FORWARD instead of restarting at the last safe checkpoint.**

- Root cause: `LevelGen.nearest_checkpoint(pos)` selected the nearest checkpoint *ahead* of the player. On a fall the player keeps moving -Z at SPEED=6 during the ~1.07s drop (KILL_Y=-12), drifting ~6.4m past the gap. That drift put the *next* strip's checkpoint "ahead-or-at" the kill position, so respawn teleported the player forward (often a whole strip), skipping content.
- Pre-fix on-device proof: deliberate no-jump fall into gap0 → FALLS incremented but player respawned mid-course, skip-jumped to goal: **TIME 018.7s** (vs normal 34.45s), COIN 13/25, FALLS 3, 1 star. Falls became a fast-forward instead of a penalty.

## 2. The fix (physics constants UNCHANGED) — committed `6065992`

- `LevelGen.gd`: added `checkpoint_behind(pos)` — nearest checkpoint *at/behind* the player (forward=-Z, so `c.z >= pos.z`, pick smallest such z = most advanced reached). Falls back to `spawn_point`.
- `Player.gd`: added `_last_checkpoint` (default spawn `(0,2,8)`); updated every physics frame **while grounded** (`if is_on_floor(): _last_checkpoint = level.checkpoint_behind(position)`); `respawn()` uses `_last_checkpoint`. Capturing while grounded means fall drift can no longer skip respawn forward.
- SPEED/GRAVITY/JUMP_VELOCITY/coyote/buffer/KILL_Y all untouched.

## 3. Headless regression — PASS (all 3 levels, 0 falls, 3 stars)

Log: `build/headless_w7.log`, BAD_LINES=0.
```
FINAL level=0 name=GRASSLAND time=34.34 falls=0 coins=25/25 stars=3
FINAL level=1 name=CANYON    time=36.9  falls=0 coins=27/27 stars=3
FINAL level=2 name=FROST     time=37.49 falls=0 coins=28/28 stars=3
ALL_LEVELS_DONE
```
This is the authoritative completability proof for L2/L3 movers (raycast-feedback autopilot).

## 4. APK — clean + signed + installed on A54

`build/godot-parkour.apk` = 28,310,285 bytes, arm64-v8a, apksigner Signed + Verified. Contains the fix. Installed via WiFi `install -r` → **Success**.

## 5. On-device verification (WiFi ADB, post-fix APK)

### 5a. Fix directly verified — fall respawns BEHIND (L1)
Tap-driven via `tools/w7_play.py phase1`. Buttons (1080x2340): START/NEXT(540,1270) L(115,2245) R(285,2245) J(945,2245) RESTART(540,1356) pause(840,29).
- `build/a54_w7_03_fall.png` — TIME 006.1 COIN 4/25 FALLS 0: character dropping past gap0 edge (z=-26), platform dirt side visible.
- `build/a54_w7_04_respawn.png` — TIME 007.5 COIN 4/25 **FALLS 1**: character back at **strip0 start** (first obstacle z=-11 still AHEAD, whole course ahead). Respawn at strip0 checkpoint z=2, NOT skip-ahead. Contrast pre-fix 18.7s skip: at 7.5s the fixed player is still at the beginning. **FIX CONFIRMED.**

### 5b. L1 clean run — 0 falls / 25/25 / 34.3s / 3 stars
`tools/w7_play.py clean` (fresh launch, z0=8 geometry, dodge obstacles z=-11/-43, jump all 6 gaps).
- `build/a54_w7_g1.png` — TIME 012.3 COIN 9/25 FALLS 0: clean mid-course progress.
- `build/a54_w7_06_finish.png` — **LEVEL CLEAR! ★★★**, **COIN 25/25 FALLS 0 TIME 034.3**, character on gold finish platform, NEXT LEVEL + RESTART buttons. (BEST line shows stale 018.7s from the pre-fix session's persisted record — cosmetic data artifact, cleared via `pm clear` at end.)
- TIME 34.3 (≈ design 34.45) vs pre-fix 18.7 proves no skip-ahead; 0 falls + 25/25 proves clean completability on real hardware.

### 5c. L2 CANYON — runs on device, movers animate
NEXT LEVEL (540,1270) → L2 loads. `tools/w7_play.py l2`.
- `build/a54_w7_l2_open.png` — L2 CANYON, COIN 0/27, orange canyon theme, TAP TO START, purple mover visible.
- `build/a54_w7_l2_run.png` — TIME 009.5 COIN 7/27 **FALLS 0**: canyon run, static gaps cleared.
- `build/a54_w7_l2_mover.png` — TIME 017.7 COIN 11/27 **FALLS 0**: pink moving platform animating at gap2, static gaps 0 falls.
- L2/L3 mover *landing* needs raycast feedback (mover x = 2·sin(2π·level.time/3.5 + phase); phase depends on pre-START idle time, not blind-knowable). Headless autopilot (§3) is the authoritative mover completability proof. L3 FROST on-device render is gated behind finishing L2's movers; verified via headless (0 falls / 28/28 / 3 stars).

## 6. Full-session logcat — CLEAN

`build/logcat_w7_a54.txt` = 10,891,058 bytes / 63,069 lines, covers 01:15→01:31 (fall test + clean runs + L2).
Scan: **FATAL EXCEPTION=0, ANR in=0, SIGSEGV=0, signal 11=0, Fatal signal=0, Godot ERROR=0, SCRIPT ERROR=0, Force finishing=0.** GODOT_LINES=1869 (engine running, receiving taps).
`Killing parkour=4` — ALL four are intentional `am force-stop` relaunches (each preceded by `adbd: ... am force-stop com.cykagent.parkour` + `ActivityManager: Force stopping ... from pid`), NOT crashes.

## 7. Blocker resolution (adb authorization)

The earlier `unauthorized` blocker is RESOLVED. Root cause of the recurring "Allow USB debugging?" prompt: the dialog's **"Always allow from this computer"** was not ticked → single-use authorization, not written to `adb_keys`, so every adbd restart re-prompted. User tapped Allow (with always-allow) at ~01:10; both USB + WiFi now `device`. WiFi transport used for all verification (stable, no replug). A54 IP is DHCP, currently `<LAN_IP>`.

## 8. Play-driver fixes (`tools/w7_play.py`, this session)

Three real driver bugs found + fixed while verifying (NOT game bugs):
1. **Jump registration**: `input tap J` (instant DOWN+UP) can fall entirely between physics frames → `Input.is_action_just_pressed("jump")` never sees it → no jump. Fixed: `hold(J, 120)` spans multiple physics frames. (The pre-fix "18.7s finish" was the skip-ahead bug, not real jumps — tap jumps never registered.)
2. **Scheduler ordering**: `Sched.at` executed events in INSERTION order, not time order. Dodges inserted before jumps delayed jump0 past its slot → whole run desynced. Fixed: `Sched` collects events and `run()` executes them sorted by absolute target time.
3. **START latency alignment**: run starts ~LEAD after the START tap is sent; `t0 = time.time() + LEAD` aligns the schedule to actual run start. LEAD tuned to measured WiFi input RTT (avg 0.154s → LEAD=0.15).
- Added `clean()` (fresh z0=8 full run), `l2()` (canyon evidence), `next`/`shot` CLI helpers; SER switched to WiFi; `W7_LEAD` env override.

## 9. Constraints honored

- A57 untouched. kungshami_apk code untouched. A54 gimbal app/data not deleted.
- Physics constants preserved. No bot restart. No push (repo has no remote). No secure-keyguard bypass.
- `pm clear com.cykagent.parkour` at end wipes the stale pre-fix 18.7s record (data only; APK stays installed).

## 10. Reproduce

- Headless: `Godot_v4.7.2-stable_win64_console.exe --headless --path .` (FINAL×3 + ALL_LEVELS_DONE).
- Export: `... --headless --path . --export-debug "Android" build/godot-parkour.apk`.
- Install (WiFi): `C:\Android\platform-tools\adb.exe -s <LAN_IP>:5555 install -r build\godot-parkour.apk`.
- Play driver: `set W7_LEAD=0.15&& python tools/w7_play.py clean` (L1 clean run); `phase1` (fall/fix test); `l2` (canyon evidence). Relaunch fresh between runs: `adb shell am force-stop com.cykagent.parkour` + monkey LAUNCHER.
- Logcat scan: Python regex over `build/logcat_w7_a54.txt` for FATAL EXCEPTION|ANR in|SIGSEGV|Fatal signal|SCRIPT ERROR (all 0).