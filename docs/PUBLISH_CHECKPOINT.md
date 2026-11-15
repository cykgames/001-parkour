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
