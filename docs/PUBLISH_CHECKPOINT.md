# Public release checkpoint (2026-11-15)

- Published to GitHub org **cykgames** as public repo `001-parkour` (first push
  ever; the repo was local-only before this date).
- Release `v0.1.0` carries the W7-fixed, HUD-v4 APK (28.3 MB, arm64-v8a,
  debug-signed, same build verified on real devices).

## History sanitization (done BEFORE first push)

Full git history rewritten with `git-filter-repo` (blob callback + path filter):

- LAN IP addresses -> `<LAN_IP>`
- Device serials -> `<DEVICE_SERIAL>`
- Windows user-profile paths -> `%USERPROFILE%`
- Agent workspace paths -> `agent-workspace`
- `.godot/` editor cache removed from ALL history (it had been committed in
  W1-W3 before `.gitignore` existed; a later ignore commit cannot undo that)
- Verification: re-scan of every blob in the rewritten history = 0 sensitive
  hits (only generic word "password" in a keyguard description remains).
- 7 commits -> 6: the ".godot ignore" housekeeping commit became empty after
  the path filter and was auto-pruned. All milestone commits preserved
  (hashes changed by the rewrite).

## Portability fix

`tools/w7_play.py` no longer hardcodes device or paths:

- `PARKOUR_ADB_SERIAL` env var (adb serial or ip:port) — required to run
- `ADB_PATH` env var, else `adb` found on PATH
- build dir resolved relative to the repo root

## Author credit + handoff docs (2026-11-15, docs pass by cykbot1)

- Game author is **cykbot9** (the cykgames catalog lists cykbot9 for
  001/002). The first credit pass misattributed the game to cykbot1, who
  only authored 009-shooter; corrected in place the same evening.
- In-game: "by cykbot9" label on the title gate (HUD.gd `_author_label`,
  hidden once the run starts). project.godot description carries the author.
- README: author/status header, Design sources, Handoff/debugging section
  (entry points, regression expectations, known state, privacy rule).
- Verify: headless self-test `build/verify_author.log` = FINAL x3, falls=0,
  3 stars each, ALL_LEVELS_DONE, no script errors (re-run after the
  attribution fix).
- Released v0.1.0 APK predates the credit; a rebuild + new release is needed
  for it to show on devices (pending owner consent).
