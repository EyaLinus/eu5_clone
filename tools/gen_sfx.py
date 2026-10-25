#!/usr/bin/env python3
"""Generates the small procedural sound effects in assets/sfx/ (16-bit mono WAV, no external assets).

Usage: python3 tools/gen_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sfx")


def env(i, n, attack=0.01, release=0.6):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = max(0.0, 1.0 - i / n) ** (1.0 / max(release, 0.01))
    return a * r


def tone(freqs, dur, vol=0.4, shape="sine", release=0.6):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        s = 0.0
        for f in freqs:
            ph = (t * f) % 1.0
            if shape == "sine":
                s += math.sin(2 * math.pi * ph)
            elif shape == "square":
                s += 1.0 if ph < 0.5 else -1.0
            elif shape == "tri":
                s += 4 * abs(ph - 0.5) - 1
        out.append(s / len(freqs) * vol * env(i, n, release=release))
    return out


def noise(dur, vol=0.4, lp=0.2, seed=1):
    rnd = random.Random(seed)
    n = int(RATE * dur)
    out, y = [], 0.0
    for i in range(n):
        y += lp * (rnd.uniform(-1, 1) - y)
        out.append(y * vol * 3 * env(i, n, release=0.4))
    return out


def seq(*parts):
    r = []
    for p in parts:
        r += p
    return r


def mix(a, b):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0) + (b[i] if i < len(b) else 0) for i in range(n)]


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


save("click", tone([880], 0.05, 0.25, "tri", 0.3))
save("event", seq(tone([523.3, 659.3], 0.14, 0.35, "tri"), tone([659.3, 784.0], 0.14, 0.35, "tri"), tone([784.0, 1046.5], 0.3, 0.35, "tri")))
save("war", mix(seq(tone([110, 220], 0.18, 0.5, "square", 0.8), tone([98, 196], 0.4, 0.5, "square", 0.6)), noise(0.5, 0.35, 0.08, 3)))
save("peace", seq(tone([392.0, 493.9], 0.2, 0.3, "sine"), tone([523.3, 659.3], 0.5, 0.3, "sine", 0.5)))
save("battle", mix(noise(0.35, 0.6, 0.35, 7), tone([70], 0.3, 0.4, "sine", 0.5)))
save("success", seq(tone([659.3], 0.08, 0.3, "tri"), tone([880.0], 0.18, 0.3, "tri")))
print("ok", OUT)
