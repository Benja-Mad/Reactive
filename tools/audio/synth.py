"""The program's sounds, synthesised so they can be tuned in code: python3 tools/audio/synth.py

Short and soft, made to sit under play, not over it. Each one answers a moment the HUD already
lights: a routine firing, each DO acting, a DO that changed nothing, a THEN let go, a combo, a click.
The game pitches `step` per position, so a routine plays its own little phrase as it runs.
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(x, attack, decay):
    """A plucked shape: a quick rise, then an exponential fall with time constant `decay`."""
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(x - attack, 0) / decay)


def lowpass(signal, cutoff):
    """One-pole low-pass, to take the edge off noise."""
    k = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.zeros_like(signal)
    y = 0.0
    for i, s in enumerate(signal):
        y += k * (s - y)
        out[i] = y
    return out


def noise(n, seed):
    return np.random.default_rng(seed).uniform(-1, 1, n)


def fade_out(signal, seconds=0.01):
    n = min(len(signal), int(RATE * seconds))
    signal[-n:] *= np.linspace(1, 0, n)
    return signal


def write(name, signal, peak_db=-6.0):
    signal = fade_out(signal.astype(np.float64))
    signal = signal / max(1e-9, np.max(np.abs(signal))) * 10 ** (peak_db / 20)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((signal * 32767).astype("<i2").tobytes())


def step():
    """A glassy pluck: a sine with a soft FM bite at the start. Pitched per DO by the game."""
    x = t(0.16)
    f = 784.0
    bite = 1.6 * np.exp(-x / 0.012)
    tone = np.sin(2 * np.pi * f * x + bite * np.sin(2 * np.pi * f * 2 * x))
    return tone * env(x, 0.002, 0.045) + 0.15 * np.sin(2 * np.pi * f * 2 * x) * env(x, 0.001, 0.02)


def draw():
    """The WHEN firing: a low soft thump whose pitch falls, with a breath of filtered noise."""
    x = t(0.22)
    f = 180 * np.exp(-x / 0.08) + 90
    phase = 2 * np.pi * np.cumsum(f) / RATE
    body = np.sin(phase) * env(x, 0.003, 0.07)
    air = lowpass(noise(len(x), 1), 1800) * env(x, 0.001, 0.03) * 0.6
    return body + air


def idle():
    """A DO that changed nothing, or a condition that said no: a muffled wooden knock."""
    x = t(0.09)
    body = np.sin(2 * np.pi * 210 * x) * env(x, 0.001, 0.018)
    knock = lowpass(noise(len(x), 2), 900) * env(x, 0.0005, 0.01)
    return body + 0.8 * knock


def armed():
    """A THEN waiting: a faint rising glint."""
    x = t(0.14)
    f = 900 + 500 * x / x[-1]
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * env(x, 0.02, 0.05)


def fire():
    """A THEN let go: brighter than a step, two partials a fifth apart and a short spark of noise."""
    x = t(0.3)
    f = 523.25
    tone = np.sin(2 * np.pi * f * x) + 0.6 * np.sin(2 * np.pi * f * 1.5 * x) + 0.25 * np.sin(2 * np.pi * f * 3 * x)
    spark = lowpass(noise(len(x), 3), 5000) * env(x, 0.0005, 0.012)
    return tone * env(x, 0.003, 0.09) + 0.5 * spark


def combo():
    """Two routines' matter meeting: a two-note bell, the second note a fifth over the first."""
    x = t(0.7)
    out = np.zeros_like(x)
    for start, f in ((0.0, 659.25), (0.08, 987.77)):
        y = np.clip(x - start, 0, None)
        on = (x >= start).astype(float)
        bell = np.sin(2 * np.pi * f * y) + 0.35 * np.sin(2 * np.pi * f * 2.76 * y) * np.exp(-y / 0.05)
        out += on * bell * env(y, 0.002, 0.22)
    return out


def cue():
    """A click a routine answered: a crisp tick with a short tonal tail."""
    x = t(0.12)
    tick = lowpass(noise(len(x), 4), 3500) * env(x, 0.0003, 0.004)
    tail = np.sin(2 * np.pi * 1320 * x) * env(x, 0.001, 0.03)
    return tick + 0.7 * tail


def cue_idle():
    """A click nothing answered: just the dull tick."""
    x = t(0.06)
    return lowpass(noise(len(x), 5), 1500) * env(x, 0.0003, 0.006)




# The world: reactions heard by everyone, placed where they happen (fields_fx.rule).

from scipy.signal import butter, sosfilt  # noqa: E402


def band(signal, low, high, order=2):
    return sosfilt(butter(order, [low, high], btype="band", fs=RATE, output="sos"), signal)


def low(signal, cutoff, order=2):
    return sosfilt(butter(order, cutoff, btype="low", fs=RATE, output="sos"), signal)


def zap():
    """Current jumping: a buzz at mains hum torn by random crackles."""
    x = t(0.32)
    rng = np.random.default_rng(10)
    buzz = np.sign(np.sin(2 * np.pi * 110 * x)) * 0.35 + np.sin(2 * np.pi * 330 * x) * 0.3
    gate = np.zeros_like(x)
    for _ in range(14):
        at = int(rng.uniform(0, 0.24) * RATE)
        n = int(rng.uniform(0.003, 0.012) * RATE)
        gate[at:at + n] = rng.uniform(0.5, 1.0)
    crackle = band(noise(len(x), 11), 1500, 7000) * gate
    return (buzz * env(x, 0.002, 0.08) + 1.6 * crackle) * env(x, 0.001, 0.15)


def hiss():
    """Steam: a soft rush of high noise that swells and dies."""
    x = t(0.7)
    shape = np.clip(x / 0.06, 0, 1) * np.exp(-np.maximum(x - 0.06, 0) / 0.22)
    return band(noise(len(x), 12), 2500, 9000) * shape


def sizzle():
    """A fire drowned: hiss full of tiny pops, falling in pitch."""
    x = t(0.55)
    rng = np.random.default_rng(13)
    pops = np.zeros_like(x)
    for _ in range(40):
        at = int(rng.uniform(0, 0.45) * RATE)
        pops[at] = rng.uniform(-1, 1)
    pops = band(pops, 1200, 6000) * 8
    rush = band(noise(len(x), 14), 900, 4000)
    return (rush + pops) * env(x, 0.01, 0.16)


def ignite():
    """A machine catching: a swelling whoomp of low noise."""
    x = t(0.5)
    shape = np.clip(x / 0.08, 0, 1) ** 2 * np.exp(-np.maximum(x - 0.08, 0) / 0.12)
    body = low(noise(len(x), 15), 700) * shape
    crack = band(noise(len(x), 16), 2000, 6000) * env(x - 0.07, 0.002, 0.03) * (x > 0.07)
    return body * 3 + crack * 0.5


def frost():
    """Water freezing: a crack and glassy partials that ring out briefly."""
    x = t(0.45)
    crack = band(noise(len(x), 17), 2500, 9000) * env(x, 0.0005, 0.008)
    glass = sum(np.sin(2 * np.pi * f * x) * env(x, 0.001, d) for f, d in ((2093, 0.12), (3136, 0.08), (4186 * 1.07, 0.06), (5588, 0.04)))
    return 1.5 * crack + 0.35 * glass


def nanites():
    """Nanites going off: a cluster of small metal pings and a dry burst."""
    x = t(0.4)
    rng = np.random.default_rng(18)
    out = band(noise(len(x), 19), 800, 5000) * env(x, 0.001, 0.02) * 1.2
    for _ in range(7):
        start = rng.uniform(0, 0.12)
        f = rng.uniform(1800, 3600)
        y = np.clip(x - start, 0, None)
        out += (x >= start) * np.sin(2 * np.pi * f * y + 2 * np.sin(2 * np.pi * f * 1.41 * y)) * env(y, 0.0005, 0.04) * 0.3
    return out


def grind():
    """Scrap or ice biting a machine as it goes round: a short gritty scrape."""
    x = t(0.16)
    rasp = band(noise(len(x), 20), 600, 3500) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * x)))
    return rasp * env(x, 0.005, 0.05)


def thud():
    """Two machines meeting: a low body hit with a metal knock on top."""
    x = t(0.3)
    f = 95 * np.exp(-x / 0.1) + 45
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(x, 0.001, 0.08)
    knock = band(noise(len(x), 21), 400, 2500) * env(x, 0.0005, 0.015)
    return body + 0.7 * knock


def whoosh():
    """A well letting go: air rushing out, its colour rising then falling."""
    x = t(0.6)
    shape = np.sin(np.pi * np.clip(x / 0.6, 0, 1)) ** 2
    lo = low(noise(len(x), 22), 600)
    hi = band(noise(len(x), 23), 900, 3000)
    mix = np.clip(np.sin(np.pi * x / 0.6), 0, 1)
    return (lo * (1 - mix) * 2 + hi * mix) * shape


def boom():
    """A drum set off or a heap bursting: a low thump with a long rumbling tail."""
    x = t(0.9)
    f = 70 * np.exp(-x / 0.12) + 38
    sub = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(x, 0.002, 0.18)
    rumble = low(noise(len(x), 24), 400) * env(x, 0.003, 0.28) * 2.5
    crack = band(noise(len(x), 25), 1500, 6000) * env(x, 0.0005, 0.02) * 0.6
    return sub + rumble + crack


def clatter():
    """Shrapnel landing: metal pieces knocking one after another."""
    x = t(0.5)
    rng = np.random.default_rng(26)
    out = np.zeros_like(x)
    for i in range(9):
        start = 0.03 + i * 0.04 + rng.uniform(-0.01, 0.02)
        f = rng.uniform(1400, 3200)
        y = np.clip(x - start, 0, None)
        out += (x >= start) * np.sin(2 * np.pi * f * y) * env(y, 0.0005, 0.025) * (1 - i / 11)
    return out


if __name__ == "__main__":
    write("step", step(), -9)
    write("draw", draw(), -7)
    write("idle", idle(), -12)
    write("armed", armed(), -16)
    write("fire", fire(), -8)
    write("combo", combo(), -7)
    write("cue", cue(), -9)
    write("cue_idle", cue_idle(), -14)
    for name, fn, peak in (("zap", zap, -6), ("hiss", hiss, -12), ("sizzle", sizzle, -6), ("ignite", ignite, -7), ("frost", frost, -9), ("nanites", nanites, -8), ("grind", grind, -12), ("thud", thud, -6), ("whoosh", whoosh, -8), ("boom", boom, -4), ("clatter", clatter, -9)):
        write(name, fn(), peak)
    print("wrote", sorted(os.listdir(OUT)))
