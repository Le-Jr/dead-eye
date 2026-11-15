"""Synthesises every sound effect of Dead Eye Range from nothing.

    python tools/sfx/generate.py

Needs numpy and scipy. Deterministic: the same seed gives the same files.
Each key gets several variations; audio/sfx/manifest.json lists them and the
game picks one at random (see audio/sound_bank.gd).
"""
from pathlib import Path
import json
import wave

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "audio" / "sfx"
RATE = 44100


# --- Building blocks -------------------------------------------------------

def seconds(duration):
    return np.arange(int(RATE * duration)) / RATE


def band(x, low=None, high=None, order=2):
    """Butterworth low-, high- or band-pass, depending on which edges are given."""
    nyquist = RATE / 2
    if low and high:
        sos = signal.butter(order, [low / nyquist, high / nyquist], "bandpass", output="sos")
    elif low:
        sos = signal.butter(order, low / nyquist, "highpass", output="sos")
    else:
        sos = signal.butter(order, high / nyquist, "lowpass", output="sos")
    return signal.sosfilt(sos, x)


def place(buffer, sound, at, gain=1.0):
    """Mixes `sound` into `buffer` starting `at` seconds in."""
    start = int(at * RATE)
    if start >= len(buffer):
        return
    end = min(len(buffer), start + len(sound))
    buffer[start:end] += sound[: end - start] * gain


def ping(rng, freqs, decays, duration, jitter=0.0):
    """A struck object: a sum of decaying partials."""
    t = seconds(duration)
    out = np.zeros(len(t))
    for i, (freq, decay) in enumerate(zip(freqs, decays)):
        freq *= 1.0 + rng.uniform(-jitter, jitter)
        out += np.sin(2 * np.pi * freq * t + rng.uniform(0, 6.28)) * np.exp(-t * decay) / (1 + i * 0.45)
    return out


def click(rng, freq, decay=320.0, noise=0.35, duration=0.06):
    """A small metal part snapping home."""
    t = seconds(duration)
    body = ping(rng, [freq, freq * 1.83, freq * 2.94, freq * 4.6], [decay, decay * 1.3, decay * 1.7, decay * 2.2], duration, 0.03)
    snap = band(rng.normal(0, 1, len(t)), 1500, 7000) * np.exp(-t * 900)
    return body * 0.5 + snap * noise


def thunk(rng, freq, decay=70.0, duration=0.14):
    """A heavy part closing: low knock with a dull noise skin."""
    t = seconds(duration)
    knock = np.sin(2 * np.pi * (freq * t + freq * 0.4 * np.exp(-t * 60) / 60)) * np.exp(-t * decay)
    skin = band(rng.normal(0, 1, len(t)), 200, 1800) * np.exp(-t * decay * 1.6)
    return knock * 0.8 + skin * 0.5


def scrape(rng, low, high, duration, rise=0.3):
    """Metal sliding on metal."""
    t = seconds(duration)
    envelope = np.minimum(t / (duration * rise), 1.0) * np.minimum((duration - t) / (duration * 0.4), 1.0)
    return band(rng.normal(0, 1, len(t)), low, high) * np.clip(envelope, 0, 1)


def saturate(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


def finish(x, peak=0.92, fade_out=0.02):
    x = np.nan_to_num(np.asarray(x, dtype=np.float64))
    x -= np.mean(x)
    n = min(len(x) // 4, int(RATE * 0.002))
    x[:n] *= np.linspace(0, 1, n)
    n = min(len(x) // 2, int(RATE * fade_out))
    x[-n:] *= np.linspace(1, 0, n) ** 2
    return x * (peak / max(1e-9, np.max(np.abs(x))))


def write(path, samples):
    with wave.open(str(path), "wb") as f:
        f.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        f.writeframes((np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes())


# --- Guns ------------------------------------------------------------------

GUNS = {
    #                thump Hz, body band,    body decay, crack, tail s, tail cut, drive
    "shot_revolver": (88, (160, 2600), 34, 0.9, 1.25, 1500, 3.2),
    "shot_lever": (104, (220, 3400), 42, 1.1, 1.15, 1900, 3.0),
    "shot_coach": (56, (90, 1700), 22, 0.7, 1.70, 950, 4.2),
    "shot_sharps": (66, (120, 2300), 26, 1.2, 2.10, 1250, 3.8),
}


def gunshot(rng, key):
    thump_hz, body_band, body_decay, crack_gain, tail_len, tail_cut, drive = GUNS[key]
    thump_hz *= rng.uniform(0.96, 1.04)
    t = seconds(tail_len + 0.25)
    n = len(t)
    # The muzzle crack: a few milliseconds of full-band noise.
    crack = band(rng.normal(0, 1, n), 1500, 8000) * np.exp(-t * 520) * crack_gain * 0.6
    # The body of the report.
    body = band(rng.normal(0, 1, n), *body_band) * np.exp(-t * body_decay) * 1.5
    # Chest thump: a sine that drops in pitch as the pressure wave relaxes.
    sweep = thump_hz * (1.0 + 1.6 * np.exp(-t * 55))
    thump = np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * np.exp(-t * 15) * 1.2
    dry = saturate(crack + body + thump, drive)
    # Open-air tail: darkening noise plus a few slap-backs off the buildings.
    tail = band(rng.normal(0, 1, n), 80, tail_cut) * np.exp(-t * (4.2 / tail_len)) * np.minimum(t / 0.03, 1)
    tail *= 1.0 + 0.25 * np.sin(2 * np.pi * rng.uniform(2, 5) * t + rng.uniform(0, 6))
    out = dry + tail * 0.34
    for delay, gain in [(rng.uniform(0.045, 0.07), 0.22), (rng.uniform(0.11, 0.16), 0.15), (rng.uniform(0.24, 0.33), 0.09)]:
        place(out, band(dry, high=tail_cut * 1.4), delay, gain)
    if key == "shot_coach":
        # Two barrels' worth of powder: a second, lower bloom.
        place(out, band(dry, high=600), 0.012, 0.5)
    return finish(band(out, high=9000), fade_out=0.25)


# --- Mechanisms ------------------------------------------------------------

def hammer(rng):
    """Thumb-cocking: the sear clicks over the notches, last one loudest."""
    out = np.zeros(int(RATE * 0.3))
    gap = rng.uniform(0.038, 0.05)
    for i, gain in enumerate([0.35, 0.5, 0.75, 1.0]):
        place(out, click(rng, rng.uniform(2300, 2900) * (1 + i * 0.05), 380), 0.01 + i * gap, gain)
    place(out, thunk(rng, 310, 120, 0.06), 0.01 + 3 * gap, 0.35)
    return finish(out)


def dry_fire(rng):
    out = np.zeros(int(RATE * 0.22))
    place(out, click(rng, rng.uniform(1700, 2000), 420, 0.9), 0.005)
    place(out, thunk(rng, 420, 160, 0.05), 0.006, 0.6)
    return finish(out)


def cylinder(rng):
    """Ejector rod and a spent case leaving the chamber."""
    out = np.zeros(int(RATE * 0.5))
    place(out, scrape(rng, 1800, 6000, 0.07), 0.0, 0.5)
    place(out, click(rng, rng.uniform(2000, 2400), 300), 0.07, 0.7)
    place(out, ping(rng, [3350, 5120, 7900], [45, 60, 90], 0.3, 0.05), 0.12, 0.35)
    return finish(out)


def lever(rng):
    """Lever down, lever up: two clacks joined by the bolt sliding."""
    out = np.zeros(int(RATE * 0.42))
    place(out, thunk(rng, 520, 110, 0.08), 0.0, 0.8)
    place(out, click(rng, rng.uniform(1500, 1800), 260), 0.004, 0.8)
    place(out, scrape(rng, 900, 4200, 0.09), 0.03, 0.35)
    place(out, thunk(rng, 640, 120, 0.08), 0.13, 1.0)
    place(out, click(rng, rng.uniform(2100, 2500), 300), 0.134, 1.0)
    return finish(out)


def insert(rng):
    """A cartridge pushed into a chamber or loading gate."""
    out = np.zeros(int(RATE * 0.3))
    place(out, scrape(rng, 2200, 7000, 0.06, 0.6), 0.0, 0.4)
    place(out, click(rng, rng.uniform(2600, 3200), 350, 0.4), 0.06, 0.8)
    place(out, thunk(rng, 760, 150, 0.05), 0.062, 0.4)
    return finish(out)


def action_open(rng):
    out = np.zeros(int(RATE * 0.35))
    place(out, click(rng, rng.uniform(1900, 2200), 300), 0.0, 0.8)
    place(out, scrape(rng, 500, 2500, 0.1), 0.02, 0.3)
    place(out, thunk(rng, 240, 60, 0.16), 0.09, 0.9)
    return finish(out)


def action_close(rng):
    out = np.zeros(int(RATE * 0.35))
    place(out, scrape(rng, 500, 2500, 0.06), 0.0, 0.25)
    place(out, thunk(rng, 190, 55, 0.18), 0.05, 1.0)
    place(out, click(rng, rng.uniform(2300, 2700), 280), 0.055, 0.9)
    return finish(out)


def casing(rng):
    """Spent brass bouncing on hard ground."""
    out = np.zeros(int(RATE * 0.7))
    at, gain = 0.0, 1.0
    base = rng.uniform(3000, 3800)
    for _ in range(5):
        place(out, ping(rng, [base, base * 1.52, base * 2.31], [60, 80, 120], 0.2, 0.04), at, gain)
        at += rng.uniform(0.05, 0.13) * gain + 0.03
        gain *= 0.55
    return finish(out)


# --- Impacts ---------------------------------------------------------------

def glass(rng):
    """A bottle bursting: one crack, then shards ringing as they scatter."""
    t = seconds(0.95)
    out = band(rng.normal(0, 1, len(t)), low=1200) * np.exp(-t * 110) * 1.4
    out += band(rng.normal(0, 1, len(t)), low=4000) * np.exp(-t * 9) * 0.12
    for _ in range(26):
        at = rng.exponential(0.09)
        freq = rng.uniform(2400, 9500)
        place(out, ping(rng, [freq, freq * rng.uniform(1.4, 1.9)], [rng.uniform(30, 90), 120], 0.25), at, rng.uniform(0.1, 0.4))
    return finish(out, fade_out=0.15)


def clay(rng):
    """A clay pigeon breaking: duller and drier than glass."""
    t = seconds(0.5)
    out = band(rng.normal(0, 1, len(t)), 500, 5000) * np.exp(-t * 60) * 1.5
    for _ in range(9):
        freq = rng.uniform(900, 2800)
        place(out, ping(rng, [freq, freq * 1.7], [140, 200], 0.1), rng.exponential(0.04), rng.uniform(0.15, 0.4))
    return finish(out, fade_out=0.1)


def tin(rng):
    """A bullet through a tin can."""
    t = seconds(0.45)
    base = rng.uniform(620, 900)
    out = ping(rng, [base, base * 1.47, base * 2.09, base * 2.56, base * 3.9, base * 5.3], [38, 46, 60, 75, 95, 130], 0.45, 0.05)
    out += band(rng.normal(0, 1, len(t)), 1500, 8000) * np.exp(-t * 180) * 1.2
    return finish(saturate(out, 1.8), fade_out=0.08)


def steel(rng):
    """Lead on a hanging steel plate: a hard slap and a long ring."""
    t = seconds(1.7)
    base = rng.uniform(1150, 1500)
    ratios = [1, 1.59, 2.14, 2.83, 3.51, 4.37, 5.2]
    decays = [5.5, 7, 9, 12, 16, 22, 30]
    out = ping(rng, [base * r for r in ratios], decays, 1.7, 0.01)
    out *= 1.0 + 0.12 * np.sin(2 * np.pi * rng.uniform(5, 9) * t)  # the plate swinging
    out += band(rng.normal(0, 1, len(t)), 1500, 7000) * np.exp(-t * 400) * 0.9
    out += thunk(rng, 260, 90, 1.7) * 0.5
    return finish(out, fade_out=0.3)


def ricochet(rng):
    """A deformed bullet whining away."""
    t = seconds(0.85)
    start, end = rng.uniform(3200, 4200), rng.uniform(700, 1100)
    freq = end + (start - end) * np.exp(-t * rng.uniform(4.5, 7))
    freq *= 1.0 + 0.035 * np.sin(2 * np.pi * rng.uniform(38, 55) * t)  # tumbling
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    out = (np.sin(phase) + 0.35 * np.sin(2 * phase)) * np.exp(-t * 4.2) * np.minimum(t / 0.004, 1)
    out += band(rng.normal(0, 1, len(t)), low=3000) * np.exp(-t * 300) * 1.3
    return finish(out, fade_out=0.2)


def dirt(rng):
    """A bullet burying itself in packed earth."""
    t = seconds(0.4)
    out = band(rng.normal(0, 1, len(t)), 90, 1400) * np.exp(-t * 26) * 1.4
    out += thunk(rng, rng.uniform(85, 115), 40, 0.4)
    out += band(rng.normal(0, 1, len(t)), 1500, 6000) * np.exp(-t * 50) * rng.uniform(0.2, 0.35)
    return finish(out, fade_out=0.1)


def wood(rng):
    """A bullet punching a plank."""
    t = seconds(0.35)
    base = rng.uniform(230, 330)
    out = ping(rng, [base, base * 2.3, base * 3.9], [55, 80, 110], 0.35, 0.06)
    out += band(rng.normal(0, 1, len(t)), 700, 5000) * np.exp(-t * 130) * 1.3
    return finish(saturate(out, 2.0), fade_out=0.08)


# --- World -----------------------------------------------------------------

def bell(rng):
    """The duel bell. Partials of a cast bell: hum, prime, tierce, quint, nominal."""
    base = rng.uniform(505, 520)
    ratios = [0.5, 1.0, 1.19, 1.5, 2.0, 2.51, 3.01, 4.17, 5.43]
    decays = [0.9, 1.3, 1.8, 2.4, 2.2, 3.6, 4.5, 6.5, 9.0]
    t = seconds(3.6)
    out = ping(rng, [base * r for r in ratios], decays, 3.6, 0.003)
    out += click(rng, 2600, 200, 1.0, 3.6) * 0.8  # the clapper
    out *= 1.0 + 0.05 * np.sin(2 * np.pi * 3.1 * t)
    return finish(out, fade_out=0.5)


def wind(rng, duration=14.0):
    """Desert wind that loops without a seam.

    Noise is built in the frequency domain, so it is periodic over exactly
    `duration`; the gust envelope uses whole numbers of cycles for the same
    reason.
    """
    n = int(RATE * duration)
    freqs = np.fft.rfftfreq(n, 1 / RATE)

    def periodic_noise(shape):
        spectrum = rng.normal(0, 1, len(freqs)) + 1j * rng.normal(0, 1, len(freqs))
        return np.fft.irfft(spectrum * shape, n)

    safe = np.maximum(freqs, 20.0)
    rumble = periodic_noise(1.0 / safe * (freqs > 25) * np.exp(-freqs / 900.0))
    hiss = periodic_noise(np.exp(-((np.log(safe) - np.log(650.0)) ** 2) / 0.35))
    whistle = periodic_noise(np.exp(-((freqs - 1150.0) ** 2) / (2 * 55.0 ** 2)))
    rumble /= np.max(np.abs(rumble))
    hiss /= np.max(np.abs(hiss))
    whistle /= np.max(np.abs(whistle))
    t = np.arange(n) / RATE

    def gust(cycles, phase):
        return 0.5 + 0.5 * np.sin(2 * np.pi * cycles * t / duration + phase)

    swell = 0.45 + 0.55 * gust(2, 0.4) * gust(3, 2.1)
    out = rumble * 0.9 * (0.6 + 0.4 * gust(1, 1.0)) + hiss * 0.55 * swell + whistle * 0.22 * swell ** 3
    return out * (0.9 / np.max(np.abs(out)))


def step_dirt(rng):
    """A boot on grit: heel, then the sole rolling down."""
    t = seconds(0.34)
    grit = band(rng.normal(0, 1, len(t)), 250, 3200)
    envelope = np.exp(-t * 55) + 0.6 * np.exp(-((t - 0.09) ** 2) / (2 * 0.03 ** 2))
    out = grit * envelope
    # Individual stones turning under the sole.
    grains = (rng.random(len(t)) > 0.996) * rng.normal(0, 1, len(t))
    out += band(grains, 1800, 6000) * 1.2 * np.exp(-t * 14)
    out += thunk(rng, rng.uniform(75, 95), 60, 0.34) * 0.5
    return finish(out, fade_out=0.08)


def step_wood(rng):
    """A boot heel on a hollow boardwalk."""
    t = seconds(0.36)
    base = rng.uniform(105, 140)
    out = ping(rng, [base, base * 2.2, base * 3.6, base * 5.1], [28, 45, 70, 95], 0.36, 0.05)
    out += band(rng.normal(0, 1, len(t)), 300, 2600) * np.exp(-t * 95) * 0.9
    creak_at = rng.uniform(0.08, 0.14)
    creak = np.sin(2 * np.pi * rng.uniform(410, 560) * t * (1 + 0.2 * t)) * np.exp(-((t - creak_at) ** 2) / (2 * 0.03 ** 2))
    return finish(out + creak * rng.uniform(0.02, 0.1), fade_out=0.08)


def spurs(rng):
    """Rowels jingling on a step."""
    out = np.zeros(int(RATE * 0.4))
    at = 0.0
    for _ in range(rng.integers(3, 6)):
        freq = rng.uniform(4300, 7200)
        place(out, ping(rng, [freq, freq * 1.31, freq * 1.87], [70, 90, 120], 0.2, 0.02), at, rng.uniform(0.4, 1.0))
        at += rng.uniform(0.02, 0.06)
    return finish(out, fade_out=0.1)


def whip(rng):
    t = seconds(0.5)
    sweep = 500 * (9.0 ** (t / 0.3))
    whoosh = np.sin(2 * np.pi * np.cumsum(np.minimum(sweep, 6000)) / RATE) * 0.15
    whoosh += band(rng.normal(0, 1, len(t)), 600, 5000) * 0.6
    whoosh *= np.clip(t / 0.3, 0, 1) ** 2 * (t < 0.3)
    out = whoosh
    place(out, band(rng.normal(0, 1, int(RATE * 0.15)), low=2000) * np.exp(-seconds(0.15) * 180), 0.3, 4.0)
    return finish(out, fade_out=0.05)


# --- Interface -------------------------------------------------------------

def ui_click(rng):
    """Menu choice: a brass latch."""
    out = np.zeros(int(RATE * 0.16))
    place(out, click(rng, rng.uniform(1750, 1950), 260, 0.5), 0.0)
    place(out, thunk(rng, 380, 130, 0.07), 0.002, 0.5)
    return finish(out)


def ui_hover(rng):
    out = np.zeros(int(RATE * 0.08))
    place(out, click(rng, rng.uniform(3000, 3300), 520, 0.25, 0.05), 0.0)
    return finish(out, peak=0.5)


def stamp(rng):
    """An ink stamp hitting paper on a desk: scoring feedback."""
    t = seconds(0.3)
    out = thunk(rng, rng.uniform(120, 150), 50, 0.3) * 1.2
    out += band(rng.normal(0, 1, len(t)), 400, 3500) * np.exp(-t * 85) * 0.9
    return finish(saturate(out, 2.2), fade_out=0.08)


def star(rng):
    """A rating star landing: a small bright bell."""
    base = rng.uniform(1560, 1580)
    return finish(ping(rng, [base, base * 2.0, base * 2.99, base * 4.2], [9, 12, 18, 26], 0.9, 0.002), fade_out=0.2)


def dead_eye_in(rng):
    """Time slowing: a reversed swell falling into a low heartbeat."""
    t = seconds(1.3)
    swell = band(rng.normal(0, 1, len(t)), 150, 2200) * np.clip(t / 0.75, 0, 1) ** 3 * (t < 0.75)
    drop = 220 * np.exp(-np.maximum(t - 0.75, 0) * 4.5) + 42
    boom = np.sin(2 * np.pi * np.cumsum(drop) / RATE) * np.exp(-np.maximum(t - 0.75, 0) * 5.5) * (t >= 0.75)
    return finish(swell * 0.7 + boom * 1.3, fade_out=0.2)


def dead_eye_out(rng):
    """Time snapping back."""
    t = seconds(0.6)
    rise = 60 + 900 * (t / 0.6) ** 2
    out = np.sin(2 * np.pi * np.cumsum(rise) / RATE) * np.clip(t / 0.5, 0, 1) ** 2 * 0.6
    out += band(rng.normal(0, 1, len(t)), 800, 5000) * np.clip(t / 0.55, 0, 1) ** 4 * 0.4
    place(out, click(rng, 2400, 300, 1.0), 0.55, 2.0)
    return finish(out, fade_out=0.03)


def heartbeat(rng):
    out = np.zeros(int(RATE * 0.7))
    place(out, thunk(rng, 58, 28, 0.3), 0.0, 1.0)
    place(out, thunk(rng, 50, 30, 0.3), 0.24, 0.7)
    return finish(band(out, high=220), fade_out=0.1)


# --- Catalogue -------------------------------------------------------------

SOUNDS = {
    # key: (function, variations)
    "shot_revolver": (lambda r: gunshot(r, "shot_revolver"), 4),
    "shot_lever": (lambda r: gunshot(r, "shot_lever"), 4),
    "shot_coach": (lambda r: gunshot(r, "shot_coach"), 4),
    "shot_sharps": (lambda r: gunshot(r, "shot_sharps"), 4),
    "hammer": (hammer, 4),
    "dry": (dry_fire, 3),
    "cylinder": (cylinder, 4),
    "lever": (lever, 4),
    "insert": (insert, 4),
    "open": (action_open, 3),
    "close": (action_close, 3),
    "casing": (casing, 4),
    "glass": (glass, 5),
    "clay": (clay, 4),
    "tin": (tin, 5),
    "steel": (steel, 5),
    "ricochet": (ricochet, 5),
    "dirt": (dirt, 4),
    "wood": (wood, 4),
    "bell": (bell, 2),
    "wind": (wind, 1),
    "step_dirt": (step_dirt, 6),
    "step_wood": (step_wood, 6),
    "spurs": (spurs, 4),
    "whip": (whip, 2),
    "ui": (ui_click, 3),
    "hover": (ui_hover, 3),
    "stamp": (stamp, 3),
    "star": (star, 1),
    "dead_eye_in": (dead_eye_in, 1),
    "dead_eye_out": (dead_eye_out, 1),
    "heartbeat": (heartbeat, 1),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.wav"):
        old.unlink()
    manifest = {}
    for index, (key, (make, count)) in enumerate(SOUNDS.items()):
        manifest[key] = []
        for variation in range(count):
            rng = np.random.default_rng(1878 + index * 100 + variation)
            name = f"{key}_{variation}.wav"
            write(OUT / name, make(rng))
            manifest[key].append("res://audio/sfx/" + name)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(f"{sum(map(len, manifest.values()))} sounds, {len(manifest)} keys, {RATE} Hz -> {OUT}")


if __name__ == "__main__":
    main()
