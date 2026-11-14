# Godot parkour — export templates download checkpoint

Date: 2026-11-14 ~22:24 (GMT+8)
Task: 438_2cb070cc (Godot parkour MVP 60s A54), step 3/6. Templates needed for W4 (APK export).

## Conclusion
- Godot EDITOR is fine: `%USERPROFILE%\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --version` => 4.7.2.stable.official.ed1daf0bf. W1-W3 (terrain/run-jump/touch) can proceed with editor alone.
- Export templates `.tpz` download was BROKEN. Root cause: prior autopilot turn's `tools_dl.py` (4-thread range download via gh-proxy) left a background process alive; it ran CONCURRENTLY with my resume script, both writing the same file => interleaved corruption.
  - First scan: 4 zero-holes, ~647MB missing (all 4 threads died ~130-170MB into each ~320MB range; gh-proxy seems to cap ~150MB/connection).
  - After concurrent writes: file grew to 1601687127 (= correct 1281349702 + one part 320337425), no zero-holes, but `zipfile.testzip()` => Error -3 "too many length or distance symbols" (mid-file compressed data corrupt). EOCD duplicated at 1.6GB tail. NOT salvageable by truncation.

## Current state
- Corrupt file parked: `godot-templates.tpz.corrupt` (1.6GB) — safe to delete once new file validates.
- CLEAN re-download running in background: PID 25360, script `%USERPROFILE%\agent-workspace\artifacts\tmp\tpz_clean.py`.
  - Single stream, direct github (proxy fallback), resumable (Range from current size), persistent retry, auto testzip at end.
  - Target: `%USERPROFILE%\tools\godot-4.7.2\godot-templates.tpz`, correct size 1281349702.
  - Log: `artifacts\tmp\tpz_clean.log` / `.err`. Speed ~0.48 MB/s => ~40-45 min ETA from 22:24.
  - Success marker in log: "VALID ZIP - ALL DONE". Failure exits: 2=gave up, 3=size mismatch, 4=corrupt.

## Next verification (future turn)
1. Read `tpz_clean.log` tail — look for "VALID ZIP - ALL DONE".
2. If done: install templates (unzip tpz into Godot editor templates dir `%APPDATA%\Godot\export_templates\4.7.2.stable\`), then proceed W4 export APK.
3. If process died (no PID 25360) and not done: re-run `python artifacts\tmp\tpz_clean.py` (resumes from current size).
4. Delete `godot-templates.tpz.corrupt` after new file validates.

## Evidence / scripts
- tpz_scan.py (hole scan + HEAD), tpz_diag2.py (EOCD/testzip), tpz_resume.py (range fill, deprecated), tpz_clean.py (active clean downloader), speedtest.py — all in artifacts\tmp.
- Both mirrors HEAD => Content-Length 1281349702, Accept-Ranges bytes.
