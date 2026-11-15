"""On-device touch verification for the joystick-follow + 1.5x hit-area fixes.

A57 portrait 1080x2340, viewport 1280x2773 @ scale 0.84375.
  Joystick home physical ~ (160, 2146); zone width physical ~ 506.
  J center physical ~ (915, 2182); graphic radius ~ 139; effective 1.5R ~ 209.

Tests:
  follow  : press disc, drag far right (x=700, beyond the 506px zone) -> disc
            must follow and player strafes right; capture mid-hold.
  jump15  : press 180px above J center (outside the 139px graphic, inside the
            209px effective radius) -> player must jump; capture airborne.
  jumpmiss: press 300px above J center (outside effective radius) -> no jump.

Run: python tools/touch_test.py [follow|jump|all]
"""
import os
import shutil
import subprocess
import sys
import time

ADB = os.environ.get("ADB_PATH") or shutil.which("adb") or "adb"
SER = os.environ.get("PARKOUR_ADB_SERIAL", "")  # adb serial or ip:port of target device
if not SER:
    sys.exit("set PARKOUR_ADB_SERIAL to your adb serial or ip:port first")
BUILD = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "build"))
PKG = "com.cykagent.parkour"


def shell(cmd):
    r = subprocess.run([ADB, "-s", SER, "shell", cmd], capture_output=True, text=True)
    return r.stdout.strip()


def shot(name):
    r = subprocess.run([ADB, "-s", SER, "exec-out", "screencap", "-p"], capture_output=True)
    p = os.path.join(BUILD, name)
    with open(p, "wb") as f:
        f.write(r.stdout)
    print("shot %-26s %d bytes" % (name, len(r.stdout)))


def motion(kind, x, y):
    shell("input motionevent %s %d %d" % (kind, x, y))


def fresh():
    shell("am force-stop " + PKG)
    shell("monkey -p " + PKG + " -c android.intent.category.LAUNCHER 1")
    time.sleep(4.0)


def setup():
    shell("settings put system screen_off_timeout 600000")
    shell("input keyevent KEYCODE_WAKEUP")


def test_follow():
    fresh()
    shot("touch_00_title.png")
    # Press the disc home -> activates + auto-starts the run.
    motion("DOWN", 160, 2146)
    time.sleep(0.15)
    # Drag far right, well beyond the 506px zone: disc must follow.
    motion("MOVE", 700, 2146)
    time.sleep(0.6)
    shot("touch_01_follow.png")
    motion("UP", 700, 2146)
    time.sleep(0.6)
    shot("touch_02_release.png")
    print("follow: disc should sit near physical x~609 in touch_01_follow.png")


def test_jump():
    fresh()
    shell("input tap 540 1276")  # START
    time.sleep(0.4)
    # 180px above J center: outside graphic (139) but inside effective (209).
    motion("DOWN", 915, 2002)
    time.sleep(0.30)
    shot("touch_03_jump_outside.png")  # expect airborne
    motion("UP", 915, 2002)
    time.sleep(0.9)
    # Control: 300px above J center -> outside effective radius -> no jump.
    motion("DOWN", 915, 1882)
    time.sleep(0.30)
    shot("touch_04_jump_miss.png")  # expect grounded
    motion("UP", 915, 1882)
    print("jump: touch_03 airborne (hit), touch_04 grounded (miss)")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    setup()
    if mode in ("follow", "all"):
        test_follow()
    if mode in ("jump", "all"):
        test_jump()
    print("DONE")
