# Godot Parkour W5+W6 — MVP → "human-playable" game checkpoint

Date: 2026-11-15 00:25 (GMT+8)
Task: 363_7a2be76d. Project: `%USERPROFILE%\projects\godot-parkour` (standalone repo).
Primary device: **A57** (SM-A576B, WiFi ADB `<LAN_IP>:5555`). A54 untouched (unauthorized, gimbal busy). kungshami_apk untouched.

## Status: P1–P4 code DONE + headless 3-level validation PASS + APK export/install PASS + on-device engine/logcat clean. On-device gameplay SCREENSHOTS BLOCKED by secure keyguard (needs user to unlock phone).

---

## What was built (all 4 layers)

New files:
- `Game.gd` — autoload singleton: level_index, best records (`user://parkour_save.json`), headless flag.
- `Main.gd` — root orchestrator: wires level/player/HUD/camera/audio, finish flow, star rating, record save, next-level progression, coin-burst particles, headless 180s timeout safety.
- `CameraRig.gd` — smooth third-person follow (exp lerp k=4.5) + run-direction lookahead (0,0.9,-3) + trauma-based screen shake; `snap()` on respawn.
- `Audio.gd` — SFX pool (jump/land/coin/fall/finish) + looping chiptune BGM (finished→play). Disabled in headless.
- `Coin.gd` — spinning gold Area3D, emits `collected(pos)` once.
- `tools/gen_audio.py` — stdlib procedural WAV generator (22050Hz mono 16-bit).
- `tools/gen_icon.py` — stdlib PNG writer, voxel-character app icon.
- `audio/{jump,land,coin,fall,finish,bgm}.wav` — generated (bgm = 6s 160BPM C-Am-F-G chiptune loop).
- `icon.png` — 192x192 generated; set as project icon + Android launcher icon.

Rewritten:
- `Player.gd` — block character (head/torso/arms/legs BoxMesh, code-built) + procedural run swing / jump pose / landing squash&stretch + landing dust CPUParticles3D. Signals jumped/landed/fell. **Physics constants UNCHANGED** (SPEED 6, GRAVITY 22, JUMP 8.5, coyote/buffer 0.12; jump range 4.64m). Autopilot v2: committed-lane obstacle avoidance + moving-platform brake→predict-landing-x→wait logic.
- `LevelGen.gd` — 3 themed levels (GRASSLAND/CANYON/FROST), parameterized width/strip_len/gaps/movers/obstacles/par/colors. Moving platforms = AnimatableBody3D (sync_to_physics, sine X oscillation amp 2.0 period 3.5). Coins on strips + riding movers. Obstacles = 1x1x1 stone cubes mid-strip. Per-theme ProceduralSky + sun shadow + fog.
- `HUD.gd` — code-built UI: top bar (level/TIME/COIN/FALLS/pause), touch L/R/J, start gate, pause panel (resume/restart), finish panel (1–3 stars + best record + NEXT LEVEL/PLAY AGAIN + RESTART), red fall flash. PROCESS_MODE_ALWAYS for pause.
- `Main.tscn` — minimal scene (Main/LevelGen/Player+capsule collision/CameraRig/Audio/HUD); visuals+UI built in code.
- `project.godot` — autoload Game, config/icon, `pause` input action (Escape).
- `export_presets.cfg` — launcher_icons/main_192x192 = res://icon.png.

Level difficulty progression:
- L0 GRASSLAND: width 4, gaps 2.0–3.5, 0 movers, 2 obstacles, par 50.
- L1 CANYON: width 4, gaps 2.5–4.0, 2 movers, 4 obstacles, par 58.
- L2 FROST: width 3, gaps 3.0–4.0, 3 movers, 0 obstacles, par 62.
- Static gaps kept <= 4.0m (MVP jump range 4.64m valid). Mover gaps = 6.5m total with 3x3 platform centered (landing zone computed for autopilot).

Star rating: 1 (finish) + 1 (falls<=2) + 1 (coins>=80% AND time<=par). Best record saved per level to user://.

---

## Verification evidence

### 1. Headless autopilot — ALL 3 LEVELS PASS, zero errors/falls, all coins, 3 stars
Log: `build/headless_w5.log` (27 lines, BAD_LINES=0 via WARNING|ERROR|Parse|Invalid scan).
```
FINAL level=0 name=GRASSLAND time=34.34 falls=0 coins=25/25 stars=3
FINAL level=1 name=CANYON    time=36.89 falls=0 coins=27/27 stars=3
FINAL level=2 name=FROST     time=37.5  falls=0 coins=28/28 stars=3
ALL_LEVELS_DONE
```
Auto-advances L0→L1→L2 via Game.level_index + reload_current_scene, self-quit after L2.
Bug fixed during validation: autopilot obstacle avoidance originally limit-cycled at obstacle corner (capsule radius 0.4 vs ray miss at x>0.5) → stuck at z=-10.09 until 180s timeout. Fixed with committed-lane avoidance (`_avoid_lane`/`_avoid_until_z`, hold lane until fully past, 2m chest ray). Re-run → clean 3-level pass.

### 2. Export APK — clean + signed
Log: `build/export_w5.log` (EXPORT_BAD=0). `build/godot-parkour.apk` = 28,310,285 bytes (28.3MB), arm64-v8a, apksigner Signed + Verified. Launcher icon now set (no "No project icon" warning).

### 3. Install on A57 — Success
`adb -s <LAN_IP>:5555 install -r build/godot-parkour.apk` → Incremental + Streamed Install → **Success**.
(NOTE: adb daemon auto-restarted mid-session and dropped WiFi transport; re-`adb connect <LAN_IP>:5555` restored it. IP unchanged.)

### 4. On-device engine init + logcat — CLEAN
- Godot log (`build/logcat_godot.txt`): `Godot Engine v4.7.2.stable` + `OpenGL ES 3.2 ... ANGLE (Samsung Xclipse 550) on Vulkan 1.4.304`. No errors.
- Full logcat scan (`build/logcat_w5_full.txt`): **GODOT_ERROR_LINES=0**, zero `FATAL EXCEPTION`, zero `ANR in`, zero SIGSEGV/native crash. The single "Killing ... com.cykagent.parkour" line is our own `am force-stop` (pid 17310 = shell), NOT a crash.
- Foreground activity confirmed: `ResumedActivity com.cykagent.parkour/com.godot.game.GodotAppLauncher`.

### 5. On-device gameplay screenshots — BLOCKED (secure keyguard)
Could NOT capture ready/run/coin/finish screenshots. Root cause proven (NOT a render bug):
- Screenshots showed the **lock screen** (`build/a57_w5_black.png` = purple "滑動來解鎖" swipe-to-unlock) and black doze frames.
- `dumpsys window`: `mCurrentFocus=NotificationShade`, `isKeyguardShowing=true`, `mDreamingLockscreen=true`, **`secure=true`**, **`mInputRestricted=true`**, KeyguardBiometricToastView present.
- WindowManager: app task `isSleeping=true` at launch → display dozing behind keyguard.
- `wm dismiss-keyguard` + swipe-up + MENU key all failed to unlock → consistent with a **secure credential (PIN/pattern/password)**, which cannot be bypassed programmatically.
- The previous MVP session (23:25–23:49) captured game screenshots because the phone was unlocked then; it has since auto-locked.

Conclusion: app installs + engine initializes + runs without crash on A57, but visual gameplay verification requires the user to physically unlock the screen.

---

## Hard blocker (real-user action required)
**A57 is locked with a secure keyguard (`secure=true`, `mInputRestricted=true`).** Please unlock the A57 screen (PIN/pattern/password). Once unlocked, the pending on-device verification can complete:
1. Launch app → screenshot ready (TAP TO START + block character + HUD).
2. Tap START (540, ~1270) → screenshot running + coins.
3. Auto-run / tap J → screenshot coin collection + finish star panel.
4. Re-scan logcat for FATAL/ANR across a full play session.
Device settings changed for testing (left in place, harmless): `screen_off_timeout=600000` (10min), `svc power stayon true`. AC charger connected (battery FULL).

## Ruled out
- Black screen ≠ rendering failure: proven by lock-screen screenshot + `isSleeping=true` + clean Godot GL init + zero Godot errors. The game view was never visible because the secure keyguard covered it.
- Headless obstacle stuck ≠ physics tuning: fixed in autopilot logic only; physics constants untouched.

## Constraints honored
- No commit/push (user consent required). kungshami_apk untouched. A54 untouched (unauthorized). Physics constants preserved from validated MVP.

## Reproduce / next verification
- Headless: `Godot_v4.7.2-stable_win64_console.exe --headless --path . ` (auto-runs 3 levels, prints FINAL×3 + ALL_LEVELS_DONE, self-quits).
- Export: `... --headless --path . --export-debug "Android" build/godot-parkour.apk`.
- Install: `C:\Android\platform-tools\adb.exe -s <LAN_IP>:5555 install -r build\godot-parkour.apk`.
- After user unlocks A57: monkey launch + screencap sequence (see blocker steps above).

---

## A54 preflight (2026-11-15 00:38 — user switched target device to A54)
User decision: A57 secure-lock blocker abandoned; **A54 USB is now the dev/verify device** (overrides earlier "A54 untouched" constraint; kungshami_apk code still untouched, A54 gimbal experiment app/data left in place).
- `adb devices`: `<DEVICE_SERIAL> device` (USB). A54 unlocked at preflight (keyguard `showing=false, inputRestricted=false`; secure credential configured but not active).
- `svc power stayon true` set on A54 (screen stays on while USB plugged) to prevent overnight re-lock. If it ever re-locks: STOP + log blocker, never bypass.
- `install -r build/godot-parkour.apk` → **Success**.
- Launch: `am start -n com.cykagent.parkour/com.godot.game.GodotAppLauncher` → renders correctly.
- Screenshot proof: `build/a54_launch.png` = L1 GRASSLAND, TAP TO START gate + START button, HUD (TIME/COIN 0/25/FALLS/pause), block character, coins, L/R/J touch buttons. No crash dialog.
- Shell note: run_command shell is Git Bash → use `sleep N`, NOT `timeout /t N`.
- Remaining for W7: full tap-driven play session on A54 (start/run/coin/fall-checkpoint/finish-stars/L2/L3), screenshots + full-session logcat rescan, fix any real-device bugs, local commit (repo has NO remote), W7 checkpoint.
