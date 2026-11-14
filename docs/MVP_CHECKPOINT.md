# Godot voxel parkour MVP — finish-line checkpoint

Date: 2026-11-14 23:00 (GMT+8)
Task: 438_2cb070cc (Godot parkour MVP 60s). Goal: APK installed on device, launches and runs.
Project: `%USERPROFILE%\projects\godot-parkour` (standalone repo; kungshami_apk untouched).
Primary device: **A57** (SM-A576B, WiFi ADB `<LAN_IP>:5555`). A54 deferred — busy with gimbal experiment, left `unauthorized`, untouched. User directive 2026-11-14 23:09: "以A57 為主".

## Status: 5/5 steps DONE + verified on A57 (2026-11-14 ~23:15).

### Step 1 — headless validate: PASS (no tuning needed)
- Ran editor headless on Main.tscn. Autopilot cleared the whole course.
- Evidence: `artifacts\tmp\headless_run1.log` (workspace cykagent9), stderr empty.
- Result: `HUDREPORT time=46.01 falls=0 pos=(0,0.70,-268.0) running=false` => FINISH fired, 0 falls, 46.0s (<60s target). All 7 gaps (2.0..4.0m) cleared.
- Physics sanity: jump range = SPEED 6.0 * (2*JUMP_VELOCITY 8.5 / GRAVITY 22) = 4.64m; autopilot jumps 0.3m before edge => lands 4.34m past edge > max gap 4.0m. Confirmed by 0-fall run. No parameter changes made.
- NOTE: game does not self-quit after FINISH; headless process was killed manually (PIDs 16792/22572). For future automated runs add a headless auto-quit on finish if needed.

### Step 2 — export templates: DONE + verified
- Clean download finished: `tpz_clean.log` => `download complete size=1281349702`, `ZIP entries=35 testzip_bad=None`, `VALID ZIP - ALL DONE` (22:54).
- Extracted via `artifacts\tmp\extract_templates.py` (strips `templates/` prefix) into `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- Verified: `android_debug.apk` = 127260725 bytes, `version.txt` = `4.7.2.stable` (matches editor).
- Corrupt predecessor `godot-templates.tpz.corrupt` (1.6GB) still parked in tools\godot-4.7.2 — safe to delete now that new file validated.

### Step 3 — export APK: DONE + signature verified
- Command: `Godot_v4.7.2-stable_win64_console.exe --headless --path <proj> --export-debug "Android" build/godot-parkour.apk`.
- Output: `build/godot-parkour.apk` = 28263190 bytes (28.3MB), arm64-v8a only, signed with debug.keystore.
- `apksigner verify --print-certs` => Signer CN=Godot (debug cert), SHA-256 ce92cae4...197. VALID.
- Editor settings confirmed: android_sdk_path=C:\Android, java_sdk_path=C:\tools\jdk-17.0.19+10, debug_keystore=%APPDATA%\Godot\keystores\debug.keystore (pass android).
- Non-fatal export warning: "No project icon specified" => default Godot icon used. Not a blocker; add icon later if desired.
- Evidence: `artifacts\tmp\export.log`.

### Step 4 — install: DONE on A57 (A54 path abandoned per user directive)
- A54 remained `unauthorized` (RSA dialog needs physical tap; device busy with gimbal). NOT touched further.
- Switched to A57 WiFi ADB `<LAN_IP>:5555` (transport `device`, authorized).
- `adb -s <LAN_IP>:5555 install -r build/godot-parkour.apk` => **Success** (Incremental + Streamed Install).

### Step 5 — on-device smoke: DONE on A57 (all conditions PASS)
- Launch: `monkey -p com.cykagent.parkour -c android.intent.category.LAUNCHER 1` => Events injected: 1.
- Foreground: `topResumedActivity=com.cykagent.parkour/com.godot.game.GodotAppLauncher`.
- Renderer: Godot v4.7.2.stable, OpenGL ES 3.2 via ANGLE on Samsung Xclipse 550 (Vulkan 1.4.304). Only non-fatal WARNING RGBAFloat->RGBAHalf (mobile GPU env texture). `AndroidRuntime:E` empty; `godot:E` empty after filtering known warning => ZERO fatal/crash.
- (a) game画面 non-black: PASS. Sky gradient, green voxel platforms w/ brown gap edges, yellow finish gate, red capsule player + shadow, HUD TIME/FALLS, touch buttons L/R/J. nonblack_ratio=1.0.
- (b) touch jump works: PASS. `a57_jump2.png` (TIME 002.2 FALLS 0) shows capsule AIRBORNE with shadow separated/offset on platform, vs grounded baseline `a57_before.png` (shadow attached). Tap J via `input touchscreen swipe 966 523 966 523 120`.
- (c) respawn + timer: PASS. Auto-run (no input) reaches FINISH; FALLS increments via `nearest_checkpoint` respawn; TIME HUD counts; `FINISH! 040.6s FALLS 2` and `FINISH! 034.5s FALLS 5` banners observed (<60s target).
- (d) full-run recording: `build/parkour_a57.mp4` (14.9MB, valid mp42, duration 50.01s via mvhd) — continuous on-device run.
- Evidence (build/): a57_smoke1.png (FINISH 40.6s), a57_before.png (grounded), a57_jump2.png (airborne), parkour_a57.mp4.
- NOTE: Falls>0 in no-input runs are expected (auto-run straight into gaps; respawn advances). Headless autopilot (precise jumps) = 0 falls. Subjective feel/fun left for user; not auto-claimed.

## Done condition: MET on A57
install Success + launch shows game画面 (non-black) + logcat no fatal + tap jump moves player — all verified. Full course completes <60s on device; 50s screen recording captured.

## Optional follow-ups (not blockers)
- Add project icon (export warning "No project icon specified"; default Godot icon used).
- A54 install still possible later once user taps "Allow USB debugging" (RSA) on A54; same arm64-v8a APK works.
- No commit/push made (user consent required).

## Constraints honored
- No commit/push (user consent required). No changes to kungshami_apk. No code rewrite; zero parameter tuning needed (headless passed first try).

## Fix round 2 — start gate + restart (2026-11-14 23:49; user report: stuck at FINISH, nothing tappable)

Root cause (code-read confirmed):
- HUD._on_finished only showed the FINISH text; player.win() set _dead=true. No restart entry existed => permanent freeze at FINISH.
- Auto-run began at app launch => game self-completed (~35s) before the user could act.

Changes:
- HUD.gd: started/finished state machine; CenterButton (START in ready state, RESTART at finish); L/R/J button_down also starts the run; timer only accumulates after start; headless auto-start + auto-quit on finish (prints FINAL).
- Player.gd: `started` gate at top of _physics_process (headless autopilot auto-starts).
- Main.tscn: CenterButton node (center-anchored, below MsgLabel).
- build/.gdignore: evidence PNGs in build/ no longer scanned/packed into the APK.

Verification:
- Headless: FINAL time=46.01 falls=0; process self-quit (supersedes round-1 NOTE about manual kill).
- A57 on-device full loop (WiFi <LAN_IP>:5555; install -r Success):
  - ready: TIME 000.0 FALLS 0, TAP TO START + START, player idle at spawn (a57_ready.png)
  - tap START (540,1290): running, TIME 003.3, overlay gone (a57_run.png)
  - no-input auto-run: FINISH! 034.4s FALLS 5 + RESTART button visible (a57_finish.png)
  - tap RESTART: back to ready, TIME 000.0 FALLS 0, player at spawn (a57_restart.png)
  - logcat last 400 lines: zero FATAL/AndroidRuntime => no crash across scene reload.
- Evidence: build/a57_ready.png, a57_run.png, a57_finish.png, a57_restart.png.

Still no commit/push (user consent required). kungshami_apk untouched. A54 untouched (unauthorized, gimbal busy).
