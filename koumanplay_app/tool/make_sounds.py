"""Génère les effets sonores du jeu (assets/sounds/*.wav).

Sons synthétisés ici, donc originaux et libres de droits : un timbre proche du
balafon (sinus amorti et harmoniques) pour les notes, une percussion façon
djembé pour la corde. Relancer après une modification :
    python tool/make_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'sounds'


def note(freq, dur, start=0.0, vol=0.6, decay=7.0):
    """Lame de balafon : fondamentale, quinte et octave qui s'éteignent vite."""
    def f(t):
        t -= start
        if t < 0 or t > dur:
            return 0.0
        env = math.exp(-decay * t) * min(1.0, t * 400)
        return vol * env * (
            math.sin(2 * math.pi * freq * t)
            + 0.35 * math.sin(2 * math.pi * freq * 3.0 * t) * math.exp(-12 * t)
            + 0.2 * math.sin(2 * math.pi * freq * 2.0 * t)
        )
    return f


def drum(start=0.0, vol=0.9, low=95.0):
    """Frappe de djembé : note grave qui descend et petit bruit d'attaque."""
    rnd = random.Random(7)
    noise = [rnd.uniform(-1, 1) for _ in range(int(RATE * 0.03))]

    def f(t):
        t -= start
        if t < 0 or t > 0.35:
            return 0.0
        freq = low + 90 * math.exp(-25 * t)
        body = math.sin(2 * math.pi * freq * t) * math.exp(-11 * t)
        i = int(t * RATE)
        hit = noise[i] * math.exp(-80 * t) if i < len(noise) else 0.0
        return vol * (0.9 * body + 0.4 * hit)
    return f


def render(name, dur, voices):
    OUT.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for i in range(int(RATE * dur)):
        t = i / RATE
        v = sum(voice(t) for voice in voices)
        v = max(-1.0, min(1.0, v * 0.55))
        frames += struct.pack('<h', int(v * 32767))
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print(name, f'{len(frames) // 1024} Ko')


C5, D5, E5, G5, A5, C6, E6, G6 = 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1318.5, 1568.0

render('correct', 0.5, [note(G5, 0.5, 0.0), note(C6, 0.5, 0.08), note(E6, 0.45, 0.16, vol=0.45)])
render('wrong', 0.45, [note(196.0, 0.45, 0.0, vol=0.7, decay=6), note(174.6, 0.4, 0.12, vol=0.7, decay=6)])
render('win', 1.6, [
    drum(0.0, 0.6), note(C5, 0.6, 0.0), note(E5, 0.6, 0.12), note(G5, 0.6, 0.24), drum(0.36, 0.6),
    note(C6, 1.0, 0.36), note(E6, 0.9, 0.5, vol=0.35), note(G6, 1.0, 0.62, vol=0.3), drum(0.62, 0.5, low=80),
])
render('lose', 1.0, [note(G5, 0.6, 0.0, vol=0.45), note(E5, 0.6, 0.18, vol=0.45), note(C5, 0.8, 0.36, vol=0.5, decay=4)])
render('pull', 0.35, [drum(0.0, 1.0)])
render('flip', 0.12, [note(1760.0, 0.12, 0.0, vol=0.25, decay=40)])
render('match', 0.35, [note(E6, 0.35, 0.0, vol=0.4), note(G6, 0.3, 0.06, vol=0.35)])
render('tick', 0.1, [note(1200.0, 0.1, 0.0, vol=0.3, decay=50)])
render('go', 0.6, [drum(0.0, 0.8, low=110), note(C6, 0.6, 0.02, vol=0.5)])
