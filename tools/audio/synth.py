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


if __name__ == "__main__":
    write("step", step(), -9)
    write("draw", draw(), -7)
    write("idle", idle(), -12)
    write("armed", armed(), -16)
    write("fire", fire(), -8)
    write("combo", combo(), -7)
    write("cue", cue(), -9)
    write("cue_idle", cue_idle(), -14)
    print("wrote", sorted(os.listdir(OUT)))
