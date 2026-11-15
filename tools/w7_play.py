"""W7 A54 tap-driven play session driver.

Schedules adb input events against an absolute clock. Geometry derived from
LevelGen.gd (deterministic layout). Player auto-runs -Z at SPEED=6 from z=8.
z(t) = 8 - 6*t  (t = seconds since START / since respawn).

Controls (1080x2340 PORTRAIT, HUD v3 joystick): START(540,1260)
JOY home(160,2146) J(915,2182) RESTART(540,1348) pause(842,30).
Viewport 1280x2773 @ scale 0.84375 (canvas_items/expand, base 1280x720).
Joystick: DOWN at home, MOVE to home+deflection (100px > 91px full travel),
hold, UP. Full deflection -> output 1.0 -> STRAFE 4.5 m/s (same as old keys).
Jump: takeoff d=0.4m before gap edge -> t_jump=(7.6-z_edge)/6; range 4.64m.
"""
import os
import subprocess
import sys
import threading
import time

ADB = r"C:\Android\platform-tools\adb.exe"
SER = "<LAN_IP>:5555"  # A57 WiFi (primary device); A54 = <LAN_IP>:5555
BUILD = r"%USERPROFILE%\projects\godot-parkour\build"
Z0_RESPAWN = 2.0  # fixed respawn = strip0 checkpoint z=2 (was spawn z=8 pre-fix)

START = (540, 1260)
JOY = (160, 2146)   # joystick disc home center (screen px)
JOY_R = 100         # deflection px; > 91px full travel -> clamped output 1.0
J = (915, 2182)  # 330x330 circular jump key, same size as joystick disc (HUD v4)
RESTART = (540, 1348)
PAUSE = (842, 30)
LEAD = float(os.environ.get("W7_LEAD", "0.18"))  # compensate adb+input latency; tune for WiFi

LOG = []
_THREADS = []


def _log(msg):
    line = "%.3f %s" % (time.time(), msg)
    LOG.append(line)
    print(line, flush=True)


def sh(cmd, wait=True):
    # wait=False: fire-and-forget so a slow WiFi adb round-trip never
    # blocks the absolute-clock schedule (blocking calls desync dodges/jumps).
    if not wait:
        subprocess.Popen([ADB, "-s", SER, "shell", cmd],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return ""
    r = subprocess.run([ADB, "-s", SER, "shell", cmd],
                       capture_output=True, text=True)
    return r.stdout.strip()


def tap(pt):
    x, y = pt
    _log("tap %d %d" % (x, y))
    sh("input tap %d %d" % (x, y), wait=False)


def hold(pt, ms):
    x, y = pt
    _log("hold %d %d %dms" % (x, y, ms))
    sh("input motionevent DOWN %d %d; sleep %.3f; input motionevent UP %d %d"
       % (x, y, ms / 1000.0, x, y), wait=False)


def stick(dx, dy, ms):
    """Deflect the floating joystick (dx,dy in -1..1) and hold for ms."""
    x0, y0 = JOY
    x1 = int(x0 + dx * JOY_R)
    y1 = int(y0 + dy * JOY_R)
    _log("stick %.2f %.2f %dms" % (dx, dy, ms))
    sh("input motionevent DOWN %d %d; input motionevent MOVE %d %d; sleep %.3f; input motionevent UP %d %d"
       % (x0, y0, x1, y1, ms / 1000.0, x1, y1), wait=False)


def shot(name):
    p = BUILD + "\\" + name + ".png"

    def _cap():
        with open(p, "wb") as f:
            subprocess.run([ADB, "-s", SER, "exec-out", "screencap", "-p"],
                           stdout=f, check=True)

    t = threading.Thread(target=_cap, daemon=True)
    t.start()
    _THREADS.append(t)
    _log("shot %s" % name)
    return p


class Sched:
    """Collect events, then run() executes them in chronological order.
    (Insertion order != time order; sorting is required so dodges/jumps/shots
    interleaved by time fire at the right absolute clock.)"""
    def __init__(self, t0):
        self.t0 = t0
        self._events = []

    def at(self, rel, fn, *a, lead=LEAD):
        self._events.append((self.t0 + rel - lead, fn, a))

    def run(self):
        for target, fn, a in sorted(self._events, key=lambda e: e[0]):
            now = time.time()
            if target > now:
                time.sleep(target - now)
            fn(*a)


# ---- L1 GRASSLAND geometry ----
# gap edges / widths
L1_GAPS = [(-26, 2.0), (-58, 2.5), (-90.5, 3.0),
           (-123.5, 3.2), (-156.7, 3.5), (-190.2, 3.5)]
L1_OBST = [-11, -43]          # x=0 stone cubes
L1_GOAL_T = 34.45             # (8-(-198.7))/6


def jump_t(z_edge, z0=8.0):
    return (z0 - 0.4 - z_edge) / 6.0


def dodge(s, t_obst):
    """Strafe right around an x=0 obstacle centered at game-time t_obst."""
    s.at(t_obst - 0.67, stick, 1.0, 0.0, 400)   # move to x~1.8 before obstacle
    s.at(t_obst + 0.23, stick, -1.0, 0.0, 400)  # return to center after passing


def phase1():
    """START -> run -> coins -> dodge obst1 -> deliberate fall gap0 -> respawn."""
    t0 = time.time()
    s = Sched(t0)
    s.at(0, tap, START)
    s.at(1.5, shot, "a54_w7_01_run", lead=0)
    dodge(s, 3.17)                       # obstacle z=-11
    s.at(4.5, shot, "a54_w7_02_coin", lead=0)
    # NO jump at gap0 (edge z=-26, t=5.67) -> deliberate fall
    s.at(6.0, shot, "a54_w7_03_fall", lead=0)
    s.at(7.4, shot, "a54_w7_04_respawn", lead=0)
    s.run()
    _log("PHASE1_DONE t0=%.3f" % t0)
    return t0


def phase2(t_r):
    """Full clean run from FIXED respawn (z0=2): dodge both obstacles, jump all
    6 gaps, finish. Times shifted -1s vs pre-fix (respawn z=2 not z=8)."""
    z0 = Z0_RESPAWN
    s = Sched(t_r)
    dodge(s, (z0 - (-11)) / 6.0)         # obstacle z=-11 -> t=2.17
    dodge(s, (z0 - (-43)) / 6.0)         # obstacle z=-43 -> t=7.5
    for ze, _g in L1_GAPS:
        s.at(jump_t(ze, z0), hold, J, 120)
    s.at(18.0, shot, "a54_w7_05_midrun", lead=0)
    goal_t = (z0 - (-198.7)) / 6.0       # 33.45s from z=2
    s.at(goal_t + 1.2, shot, "a54_w7_06_finish", lead=0)
    s.run()
    _log("PHASE2_DONE t_r=%.3f goal_t=%.2f" % (t_r, goal_t))


def clean():
    """Fresh full clean run from START (z0=8): dodge both obstacles, jump all 6
    gaps, finish. Deterministic (no fall). Used after a fresh app launch."""
    t0 = time.time() + LEAD   # align to actual run start (START arrives ~LEAD later)
    s = Sched(t0)
    s.at(0, tap, START)
    z0 = 8.0
    dodge(s, (z0 - (-11)) / 6.0)         # obstacle z=-11 -> t=3.17
    dodge(s, (z0 - (-43)) / 6.0)         # obstacle z=-43 -> t=8.5
    for ze, _g in L1_GAPS:
        s.at(jump_t(ze, z0), hold, J, 120)   # hold spans physics frames so jump registers
    s.at(2.7, shot, "a57_joy_dodge", lead=0)    # knob deflected right mid-dodge
    s.at(6.5, shot, "a54_w7_g0", lead=0)     # diagnostic: just after gap0
    s.at(12.0, shot, "a54_w7_g1", lead=0)    # diagnostic: just after gap1
    s.at(18.0, shot, "a54_w7_05_midrun", lead=0)
    s.at(L1_GOAL_T + 1.2, shot, "a54_w7_06_finish", lead=0)
    s.run()
    _log("CLEAN_DONE t0=%.3f LEAD=%.3f" % (t0, LEAD))
    return t0


def l2():
    """L2 CANYON on-device run evidence: dodge obstacles, jump static gaps,
    attempt mover gap at edge. Movers need raycast feedback (headless autopilot)
    for reliable landing; this captures canyon gameplay + mover animation."""
    t0 = time.time() + LEAD
    s = Sched(t0)
    s.at(0, tap, START)
    z0 = 8.0
    dodge(s, (z0 - (-11)) / 6.0)
    dodge(s, (z0 - (-43.5)) / 6.0)
    s.at(jump_t(-26, z0), hold, J, 120)      # gap0 static 2.5
    s.at(jump_t(-58.5, z0), hold, J, 120)    # gap1 static 3.0
    s.at(9.0, shot, "a54_w7_l2_run", lead=0)
    s.at((z0 - (-91.5)) / 6.0, hold, J, 120)  # mover gap2 at edge (phase blind)
    s.at(17.5, shot, "a54_w7_l2_mover", lead=0)
    s.run()
    _log("L2_DONE t0=%.3f LEAD=%.3f" % (t0, LEAD))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "phase1"
    if cmd == "phase1":
        phase1()
    elif cmd == "phase2":
        phase2(float(sys.argv[2]))
    elif cmd == "clean":
        clean()
    elif cmd == "l2":
        l2()
    elif cmd == "next":
        tap(START)                       # NEXT LEVEL / START share this position
    elif cmd == "shot":
        shot(sys.argv[2])
    for t in _THREADS:
        t.join(timeout=15)
    with open(BUILD + "\\w7_play_log.txt", "a", encoding="utf-8") as f:
        f.write("\n".join(LOG) + "\n")
