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

## 11. A57 install (2026-11-15 ~12:47, user request "裝到a57")

- A57 WiFi ADB came back online authorized: `<LAN_IP>:5555` `device` (SM-A576B / a57x). No USB needed. (Earlier today 5555 was closed — adbd tcpip mode lost, likely overnight reboot; user re-enabled it.)
- Same W7 fixed APK (`build/godot-parkour.apk`, 28,310,285 bytes) → `install -r` via WiFi = **Success**.
- Launched `com.cykagent.parkour/com.godot.game.GodotAppLauncher`; screenshot `build/a57_w7_install.png` shows live gameplay: HUD L1 GRASSLAND / TIME 011.5 / COIN 5/25 / FALLS 0, voxel character mid-run, coins + gaps + finish arch rendered, L/R/J touch buttons present. (Run already started = user tapped START on the phone; TAP TO START gate confirmed present in HUD.gd and in this APK per §5c.)
- A54 WiFi transport `<LAN_IP>:5555` currently `unauthorized` again (keys not persisted); re-allow on next A54 use. A57 is now the primary device per user instruction (2026-11-14).

## 12. HUD v2 — bigger + darker buttons (2026-11-15 ~12:57, user request "按鈕大點，顏色深點")

- `HUD.gd` `_mk_button`: faint white (alpha 0.16) → **deep navy** `Color(0.07,0.10,0.16,0.82)` + 3px light rim, corner 20, margin 14, white font + outline. Pressed/hover = deep electric blue `Color(0.10,0.34,0.72,0.95)` + bright rim (tap feedback).
- Touch keys enlarged: L/R 150×130 → **210×178** (font 60→76), J 190×130 → **240×178** (font 80). L x30–240, R x262–472, J right −270…−30, all y −200…−22 (viewport units).
- START 480×80 → **560×102** (font 54); RESTART height 52→66 (font 36); pause 56×44 → **76×56** (top bar 58→64); pause-panel RESUME/RESTART fonts 40/36, panel ±190.
- Layout checked: no overlap at base 1280 width nor phone-expanded width (START y416–518 vs touch y520+; RESTART x480–800 vs R ends 472).
- **Headless regression PASS**: `build/headless_hudv2.log` FINAL×3 (34.35/36.89/37.49s, 0 falls, 25/25+27/27+28/28, 3 stars), ALL_LEVELS_DONE, BAD_LINES=0. Physics untouched.
- APK re-exported + signed (`build/godot-parkour.apk`, 28,310,285 bytes) → A57 `install -r` **Success** (WiFi .118; adb server had restarted, needed `adb connect` first).
- **On-device visual proof**: `build/a57_hudv2_start.png` — L/R/J large dark rounded keys w/ light rims, big dark START, TAP TO START, top bar + dark II pause, no overlap/clipping.
- ⚠️ Pressed-blue state NOT visually verified: second screenshot (`a57_hudv2_pressed.png`) caught **Discord in foreground** — user actively typing on the phone. All device input stopped immediately; no force-stop/relaunch done (would interrupt user). Game left in background at start gate; new HUD shows when user returns.
- 🔴 **Orientation correction**: device runs **PORTRAIT** 1080×2340 despite `orientation=1` (matches W7 §5a coords). Viewport = 1280×2773 @ scale 0.84375 (canvas_items/expand). `tools/w7_play.py` coords updated to portrait: START(540,1260) L(114,2246) R(310,2246) J(953,2246) RESTART(540,1348) PAUSE(842,30); SER switched to A57 .118. (First driver edit wrongly assumed landscape 1560×720 — corrected before any tap used those coords.)

## 13. HUD v3 — floating joystick replaces L/R buttons (2026-11-15 ~13:00-13:30, user: 左右不要用按鈕，手指滑動＋圓盤，預留前後左右)

- New `Joystick.gd` (`class_name Joystick`): floating disc. Touch anywhere in the bottom-left 600x480 zone -> disc re-centers under the finger (clamped inside zone), drag = analog steer, release = spring back home. R165 / knob72 / travel108 / radial deadzone 0.12 + rescale. Deep-navy disc + light rim, electric-blue knob while held; E/W arrows bright, N/S arrows faint = future-axis hint.
- Full Vector2 `output`: x -> `Player.input_dir.x` (analog strafe; replaces input_left/right booleans). **y is plumbed end-to-end but NOT consumed — reserved for forward/back** (auto-run owns forward speed today). Keyboard move_left/right kept; headless autopilot untouched.
- `activated` -> start_run (same gate as old L/R keys). `force_release()` on pause so a finger lifted over the pause panel cannot leave stuck strafe. J jump button unchanged (v2 big/dark).
- Layout: home (190,250) local — moved from 260 after a 720p capture showed the disc touching START's left edge; portrait phone unaffected. Zone never overlaps J/START/pause on portrait 1280x2773.
- Verification:
  - `tools/test_joystick.tscn` headless unit test: JOYSTICK_TEST_PASS (math/deadzone/clamp/y-axis/multi-touch-ignore/release/floating-clamp/force_release).
  - Full headless regression `build/headless_joy.log`: FINAL x3 34.34/36.89/37.49s, 0 falls, 25/25+27/27+28/28, 3 stars, ALL_LEVELS_DONE, 0 errors. Bugs caught+fixed en route: HUD connected signal `pressed` but Joystick declares `activated`; GDScript `is`+`and` loses type narrowing -> explicit `as` casts; new class_name needs one `--headless --import` to refresh the class cache.
  - Rendered frames of the REAL Main scene (windowed GL, `tools/shot_hud.tscn`): `build/hud_joy_idle/active/released.png` visually verified — idle no overlap, active blue knob deflected + run auto-starts, release springs back with no stuck input.
- APK 28,323,440 bytes exported+signed -> A57 `install -r` **Success** (WiFi .118).
- RED on-device play test BLOCKED: A57 was dozing + secure keyguard (mInputRestricted=true); the first scripted run's taps hit the keyguard (black screencaps, identical sha). Screen woken via KEYCODE_WAKEUP; secure lock NOT bypassed — needs the user to unlock.
- Driver `tools/w7_play.py` v3: L/R holds -> `stick(dx,dy,ms)` drag-holds at JOY(160,2146) +/-100px (>91px full travel -> output 1.0 -> STRAFE 4.5, same displacement as old keys). Input events fire-and-forget + screencap threaded: blocking adb calls had desynced the dodge/jump schedule (2s screencap delayed left-stick + jump0). Added `a57_joy_dodge` shot at t=2.7 (knob deflection evidence).
- Next after user unlocks A57: force-stop + monkey relaunch, `set W7_LEAD=0.15&& python tools/w7_play.py clean`, expect LEVEL CLEAR + FALLS 0 + deflection shot; then logcat scan (FATAL/ANR/SIGSEGV/SCRIPT ERROR).
