"""
Behaviour tests for homept.lua, run against the emulated EdgeTX API.

  python tools/test_homept.py          # tests + screenshots in screenshots/
"""
import math
import os
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim import EVT_VIRTUAL_ENTER, ROOT, Radio, offset  # noqa: E402

HOME = (52.2297, 21.0122)
CRSF = ["GPS", "Sats", "Hdg", "Yaw", "RxBt", "FM", "RQly"]
SHOTS = os.path.join(ROOT, "screenshots")


def crsf_radio(**values):
    r = Radio(CRSF)
    r.rssi = 90
    base = dict(FM="ACRO*", Sats=12, RxBt=16.8, Yaw=0.0, Hdg=0.0,
                GPS={"lat": HOME[0], "lon": HOME[1]})
    base.update(values)
    r.set(**base)
    r.tick()
    return r


def approx(a, b, tol=1e-6):
    return a is not None and abs(a - b) <= tol


def angle_diff(a, b):
    return abs((a - b + 180) % 360 - 180)


# ---------------------------------------------------------------- cells
def test_cell_count_detection():
    for volts, cells in [(16.8, 4), (22.8, 6), (21.6, 6), (11.1, 3),
                         (4.1, 1), (13.6, 4), (25.2, 6), (8.4, 2)]:
        r = crsf_radio(RxBt=volts)
        s = r.state()
        assert s["cells"] == cells, (volts, s["cells"])
        assert approx(s["cellV"], volts / cells), (volts, s["cellV"])


def test_cells_frozen_while_armed():
    r = crsf_radio(RxBt=25.0)
    assert r.state()["cells"] == 6
    r.set(FM="ACRO")
    r.tick()
    r.set(RxBt=19.8)                       # 3.30 V/cell under load
    r.tick()
    s = r.state()
    assert s["cells"] == 6 and approx(s["cellV"], 3.30), s
    r.set(FM="ACRO*", RxBt=21.2)           # landed, resting but low
    r.tick()
    s = r.state()
    assert s["cells"] == 6 and approx(s["cellV"], 21.2 / 6), s


def test_inflight_link_loss_keeps_cells_and_home():
    r = crsf_radio(RxBt=25.0)
    home = r.state()["home"]
    r.set(FM="ACRO")
    r.tick()
    r.set(GPS=offset(*HOME, 800, 0))
    r.tick()
    r.rssi = 0
    for _ in range(20):                    # 10 s failsafe
        r.tick(0.5)
    r.rssi = 90
    r.set(RxBt=20.0)                       # sagging pack after reconnect
    r.tick()
    s = r.state()
    assert s["cells"] == 6, s
    assert s["home"] == home, s


def test_pack_swap_recounts_cells():
    r = crsf_radio(RxBt=24.0)
    assert r.state()["cells"] == 6
    r.rssi = 0
    for _ in range(14):                    # 7 s unplugged on the bench
        r.tick(0.5)
    assert r.state()["cells"] == 0
    r.rssi = 90
    r.set(RxBt=16.6)
    r.tick()
    s = r.state()
    assert s["cells"] == 4 and approx(s["cellV"], 4.15), s


def test_short_dropout_keeps_cells():
    r = crsf_radio(RxBt=24.0)
    r.rssi = 0
    r.tick(2.0)
    r.rssi = 90
    r.set(RxBt=16.6)
    r.tick()
    assert r.state()["cells"] == 6


def test_no_flight_mode_sensor_never_resets_on_link_loss():
    r = Radio(["GPS", "Sats", "Hdg", "RxBt"])
    r.rssi = 90
    r.set(RxBt=24.0, Sats=10, Hdg=10.0, GPS={"lat": HOME[0], "lon": HOME[1]})
    r.tick()
    r.rssi = 0
    for _ in range(30):
        r.tick(0.5)
    r.rssi = 90
    r.set(RxBt=19.5)
    r.tick()
    assert r.state()["cells"] == 6


def test_forced_cell_count():
    src = open(os.path.join(ROOT, "SCRIPTS", "TELEMETRY", "homept.lua")).read()
    assert "local CELLS       = 0" in src
    import sim
    tmp = os.path.join(SHOTS, "_forced.lua")
    with open(tmp, "w") as f:
        f.write(src.replace("local CELLS       = 0", "local CELLS       = 4"))
    old = sim.SCRIPT
    sim.SCRIPT = tmp
    try:
        r = crsf_radio(RxBt=12.0)          # 4S at 3.0 V would read as 3S
        s = r.state()
        assert s["cells"] == 4 and approx(s["cellV"], 3.0), s
    finally:
        sim.SCRIPT = old
        os.remove(tmp)


def test_flvss_cells_table():
    r = Radio(["Cels", "VFAS", "GPS", "Hdg"])
    r.rssi = 90
    r.set(Cels=[3.91, 3.89, 3.90, 3.86], VFAS=15.56)
    r.tick()
    s = r.state()
    assert s["cells"] == 4 and approx(s["cellV"], 3.89), s


def test_frsky_vfas_fallback():
    r = Radio(["VFAS", "GPS", "Hdg"])
    r.rssi = 90
    r.set(VFAS=23.1)
    r.tick()
    s = r.state()
    assert s["cells"] == 6 and approx(s["cellV"], 3.85), s


# ---------------------------------------------------------------- arming
def test_flight_mode_parsing():
    cases = [("ACRO*", False), ("ANGL!", False), ("HOR?", False),
             ("OK", False), ("WAIT", False), ("!ERR", False),
             ("ACRO", True), ("ANGL", True), ("RTH", True), ("CRUZ", True)]
    for fm, armed in cases:
        r = crsf_radio(FM=fm)
        assert r.state()["armed"] is armed, (fm, r.state()["armed"])
    r = crsf_radio(FM="ACRO")
    r.set(FM="!FS!")                       # failsafe keeps last known state
    r.tick()
    assert r.state()["armed"] is True
    r = crsf_radio(FM="ACRO*")
    r.set(FM="!FS!")
    r.tick()
    assert r.state()["armed"] is False


# ---------------------------------------------------------------- home
def test_home_waits_for_satellites():
    r = crsf_radio(Sats=4)
    assert r.state()["home"] is None
    r.set(Sats=6)
    r.tick()
    assert r.state()["home"] == HOME


def test_home_relocks_on_arm_only():
    r = crsf_radio()
    assert r.state()["home"] == HOME
    walk = offset(*HOME, 40, 30)          # carry the quad to the launch spot
    r.set(GPS=walk)
    r.tick()
    assert r.state()["home"] == HOME
    r.set(FM="ACRO")
    r.tick()
    assert r.state()["home"] == (walk["lat"], walk["lon"])
    r.set(GPS=offset(*HOME, 500, 0))
    r.tick()
    assert r.state()["home"] == (walk["lat"], walk["lon"])


def test_arming_without_fix_keeps_previous_home():
    r = crsf_radio()
    r.set(Sats=3, GPS=offset(*HOME, 10, 0))
    r.tick()
    r.set(FM="ACRO")
    r.tick()
    assert r.state()["home"] == HOME


def test_enter_relocks_home_and_recounts():
    r = crsf_radio(RxBt=24.0)
    here = offset(*HOME, 100, 100)
    r.set(GPS=here, RxBt=16.4)
    r.tick(event=EVT_VIRTUAL_ENTER)
    s = r.state()
    assert s["home"] == (here["lat"], here["lon"]), s
    assert s["cells"] == 4, s
    assert r.tones == 1


def test_no_gps_position():
    r = crsf_radio(GPS={"lat": 0.0, "lon": 0.0})
    s = r.state()
    assert s["hasGps"] is False and s["home"] is None, s


# ---------------------------------------------------------------- direction
def test_bearing_and_heading():
    # (north m, east m) of home relative to craft, heading -> arrow angle
    cases = [((500, 0), 0, 0), ((0, 500), 90, 0), ((0, 500), 0, 90),
             ((-500, 0), 0, 180), ((-300, -300), 45, 180),
             ((300, -300), 10, 305)]
    for (n, e), hdg, arrow in cases:
        r = crsf_radio()
        r.set(GPS=offset(*HOME, -n, -e), Yaw=math.radians(hdg))
        r.tick()
        s = r.state()
        assert angle_diff(s["bearing"] - s["heading"], arrow) < 0.5, \
            ((n, e), hdg, s["bearing"], s["heading"])
        assert abs(s["dist"] - math.hypot(n, e)) < 1.0, s["dist"]


def arrow_tip(r):
    """Lit pixel of the left-half arrow farthest from its centre (31, 41)."""
    pts = [(x, y) for y in range(18, 64) for x in range(0, 63)
           if r.lcd.buf[y][x]]
    return max(pts, key=lambda p: (p[0] - 31) ** 2 + (p[1] - 41) ** 2)


def test_returning_home_arrow_points_forward():
    # take off at HOME, fly 600 m north-east, then turn around and come back
    r = crsf_radio()
    r.set(FM="ACRO")
    r.tick()
    away = offset(*HOME, 424, 424)
    r.set(GPS=away, Yaw=math.radians(45))      # nose still pointing away
    r.tick()
    x, y = arrow_tip(r)
    assert y > 55 and abs(x - 31) <= 3, ("flying away: arrow should point back", x, y)
    r.set(Yaw=math.radians(225))               # nose towards the take-off spot
    r.tick()
    x, y = arrow_tip(r)
    assert y < 24 and abs(x - 31) <= 3, ("returning: arrow should point forward", x, y)
    r.screenshot(os.path.join(SHOTS, "returning_home.png"))
    r.set(Yaw=math.radians(135))               # home is off the right wing
    r.tick()
    x, y = arrow_tip(r)
    assert x > 48 and abs(y - 41) <= 3, ("home on the right: arrow right", x, y)


def test_negative_yaw_radians():
    r = crsf_radio(Yaw=-1.5708)
    assert approx(r.state()["heading"], 270.0, 0.01)


def test_hdg_fallback_and_degree_yaw():
    r = Radio(["GPS", "Hdg", "RxBt"])
    r.rssi = 90
    r.set(Hdg=123.45, RxBt=16.0)
    r.tick()
    assert approx(r.state()["heading"], 123.45, 1e-4)
    r = Radio(["GPS", "Yaw", "RxBt"])     # FlySky style Yaw in degrees
    r.add_sensor("Yaw", unit=20)
    r.rssi = 90
    r.set(Yaw=-45.0, RxBt=16.0)
    r.tick()
    assert approx(r.state()["heading"], 315.0, 1e-4)


def test_no_telemetry_clears_values():
    r = crsf_radio()
    r.rssi = 0
    r.tick()
    s = r.state()
    assert s["linked"] is False and s["cellV"] is None and s["heading"] is None


def test_draw_calls_valid_everywhere():
    """Every primitive gets on-screen integer coordinates in all states,
    at every arrow angle."""
    r = crsf_radio(RxBt=15.2)
    r.set(FM="ACRO")
    for hdg in range(0, 360, 3):
        r.set(GPS=offset(*HOME, -400, 0), Yaw=math.radians(hdg))
        r.tick()
    for state in [dict(Sats=2), dict(GPS={"lat": 0.0, "lon": 0.0})]:
        q = crsf_radio(**state)
        q.tick()
        r.warnings += q.warnings
    q = crsf_radio()
    q.rssi = 0
    q.tick()
    r.warnings += q.warnings
    assert not r.warnings, r.warnings[:5]


# ---------------------------------------------------------------- screenshots
def make_screenshots():
    os.makedirs(SHOTS, exist_ok=True)
    shots = {}

    r = crsf_radio(RxBt=16.8)
    r.set(FM="ACRO")
    r.tick()
    r.set(GPS=offset(*HOME, -300, -150), Yaw=math.radians(-87), RxBt=15.4)
    r.tick()
    shots["flying_4s"] = r.screenshot(os.path.join(SHOTS, "flying_4s.png"))

    r = crsf_radio(RxBt=25.0)
    r.set(FM="ACRO")
    r.tick()
    r.set(GPS=offset(*HOME, 420, -510), Yaw=math.radians(160), RxBt=21.36)
    r.time = 1000                          # battery icon blink phase: shown
    r.tick(0.6)
    shots["flying_6s_low"] = r.screenshot(os.path.join(SHOTS, "flying_6s_low.png"))

    r = crsf_radio(RxBt=16.7, Yaw=math.radians(12))
    shots["at_home"] = r.screenshot(os.path.join(SHOTS, "at_home.png"))

    r = crsf_radio(Sats=3, RxBt=25.1, Yaw=math.radians(301))
    shots["waiting_fix"] = r.screenshot(os.path.join(SHOTS, "waiting_fix.png"))

    r = Radio(CRSF)
    r.tick()
    shots["no_telemetry"] = r.screenshot(os.path.join(SHOTS, "no_telemetry.png"))

    # short animated flight: orbit around home while yawing
    frames = []
    r = crsf_radio(RxBt=16.8)
    r.set(FM="ACRO")
    r.tick()
    for i in range(48):
        a = i * 2 * math.pi / 48
        v = 16.4 - i * 0.03
        r.set(GPS=offset(*HOME, 250 * math.cos(a), 250 * math.sin(a)),
              Yaw=a + math.pi / 2 + 0.4 * math.sin(3 * a), RxBt=v)
        r.tick(0.1)
        frames.append(r.lcd.to_image(4))
    gif = os.path.join(SHOTS, "demo.gif")
    frames[0].save(gif, save_all=True, append_images=frames[1:],
                   duration=120, loop=0)
    shots["demo"] = gif
    return shots


def main():
    tests = [(n, f) for n, f in sorted(globals().items())
             if n.startswith("test_") and callable(f)]
    failed = 0
    for name, fn in tests:
        try:
            fn()
            print(f"PASS {name}")
        except Exception:
            failed += 1
            print(f"FAIL {name}")
            traceback.print_exc()
    for k, v in make_screenshots().items():
        print(f"shot {k}: {os.path.relpath(v, ROOT)}")
    print(f"\n{len(tests) - failed}/{len(tests)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
