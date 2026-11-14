"""W7 A54 tap-driven play session driver.

Schedules adb input events against an absolute clock. Geometry derived from
LevelGen.gd (deterministic layout). Player auto-runs -Z at SPEED=6 from z=8.
z(t) = 8 - 6*t  (t = seconds since START / since respawn).

Buttons (1080x2340): START(540,1270) L(115,2245) R(285,2245) J(945,2245) pause(840,29).
Jump: takeoff d=0.4m before gap edge -> t_jump=(7.6-z_edge)/6; range 4.64m.
"""
import subprocess
import sys
import time

ADB = r"C:\Android\platform-tools\adb.exe"
SER = "<DEVICE_SERIAL>"
BUILD = r"%USERPROFILE%\projects\godot-parkour\build"

START = (540, 1270)
L = (115, 2245)
R = (285, 2245)
J = (945, 2245)
PAUSE = (840, 29)
LEAD = 0.18  # compensate adb+input injection latency for timed inputs

LOG = []


def _log(msg):
    line = "%.3f %s" % (time.time(), msg)
    LOG.append(line)
    print(line, flush=True)


def sh(cmd):
    r = subprocess.run([ADB, "-s", SER, "shell", cmd],
                       capture_output=True, text=True)
    return r.stdout.strip()


def tap(pt):
    x, y = pt
    _log("tap %d %d" % (x, y))
    sh("input tap %d %d" % (x, y))


def hold(pt, ms):
    x, y = pt
    _log("hold %d %d %dms" % (x, y, ms))
    sh("input motionevent DOWN %d %d; sleep %.3f; input motionevent UP %d %d"
       % (x, y, ms / 1000.0, x, y))


def shot(name):
    p = BUILD + "\\" + name + ".png"
    with open(p, "wb") as f:
        subprocess.run([ADB, "-s", SER, "exec-out", "screencap", "-p"],
                       stdout=f, check=True)
    _log("shot %s" % name)
    return p


class Sched:
    def __init__(self, t0):
        self.t0 = t0

    def at(self, rel, fn, *a, lead=LEAD):
        target = self.t0 + rel - lead
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


def jump_t(z_edge):
    return (7.6 - z_edge) / 6.0


def dodge(s, t_obst):
    """Strafe right around an x=0 obstacle centered at game-time t_obst."""
    s.at(t_obst - 0.67, hold, R, 400)   # move to x~1.8 before obstacle
    s.at(t_obst + 0.23, hold, L, 400)   # return to center after passing


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
    _log("PHASE1_DONE t0=%.3f" % t0)
    return t0


def phase2(t_r):
    """Full clean run from respawn: dodge both obstacles, jump all 6 gaps, finish."""
    s = Sched(t_r)
    dodge(s, 3.17)                       # obstacle z=-11
    dodge(s, 8.5)                        # obstacle z=-43
    for ze, _g in L1_GAPS:
        s.at(jump_t(ze), tap, J)
    s.at(20.0, shot, "a54_w7_05_midrun", lead=0)
    s.at(L1_GOAL_T + 1.2, shot, "a54_w7_06_finish", lead=0)
    _log("PHASE2_DONE t_r=%.3f" % t_r)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "phase1"
    if cmd == "phase1":
        phase1()
    elif cmd == "phase2":
        phase2(float(sys.argv[2]))
    with open(BUILD + "\\w7_play_log.txt", "a", encoding="utf-8") as f:
        f.write("\n".join(LOG) + "\n")
