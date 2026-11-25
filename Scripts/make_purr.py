"""Bake the kitten's looping, two-breath purr as mono PCM for iPhone playback."""
from pathlib import Path
import wave

import numpy as np

rate = 24000
duration = 3.2
t = np.arange(round(rate * duration)) / rate
breath = 2 * np.pi * t / duration
phase = 2 * np.pi * 80 * t / duration + 1.6 * np.sin(breath) + .22 * np.sin(3 * breath)
# Higher harmonics carry the soft rattling sound through a small phone speaker.
voice = np.zeros_like(t)
for k in range(2, 20):
    resonance = .75 * np.exp(-((k - 6) / 3.5)**2) + .15 * np.exp(-((k - 12) / 4)**2)
    voice += resonance * np.sin(k * phase + .21 * k) / np.sqrt(k)
air = np.random.default_rng(172).normal(size=t.size)
freq = np.fft.rfftfreq(t.size, 1 / rate)
air = np.fft.irfft(np.fft.rfft(air) * np.exp(-((freq - 510) / 210)**2))
signal = (voice + .4 * air) * (.29 + .71 * np.abs(np.sin(breath))**.72) * (.86 + .14*np.cos(breath))
pcm = np.rint(18500 * signal / np.max(np.abs(signal))).astype("<i2")
with wave.open(str(Path(__file__).resolve().parents[1] / "Assets/CatModel/Purr.wav"), "wb") as out:
    out.setparams((1, 2, rate, len(pcm), "NONE", ""))
    out.writeframes(pcm.tobytes())
