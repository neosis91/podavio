#!/usr/bin/env python3
"""Mesures locales EfficientAT mn04, hors du binaire Flutter.

Le graphe est l'export ONNX MIT de mn04_as (Florian Schmid,
https://github.com/fschmid56/EfficientAT), fichier
efficientat-mn04-3s.onnx, SHA-256
db3ae00d161763be541d2af53aa72c44f42cd9bcd7bd63d652aaa684fb436749.
Il prend 3 s de mono 32 kHz et rend 527 scores AudioSet.

L'application Dart n'a pas d'interpréteur ONNX ni TFLite. Ce script
tourne le graphe s'il est présent à côté, sur le CPU. XNNPACK n'est
demandé que si le runtime l'expose. L'export ne contient pas
l'embedding interne : le saut est 1 − cosinus des vecteurs de scores.
"""

import hashlib
import json
import os
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent
MODEL = Path(os.environ.get("EFFICIENTAT_ONNX", ROOT / "models" / "efficientat-mn04-3s.onnx"))
EXPECTED = "db3ae00d161763be541d2af53aa72c44f42cd9bcd7bd63d652aaa684fb436749"
SPEECH = 0
MUSIC = 137
BACKGROUND = 267
JINGLE = 269
RATE = 32000
WINDOW = 96000
HOP_S = 3.0


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(2)


def resample(samples, src_rate):
    if src_rate == RATE:
        out = samples
    else:
        count = int(round(len(samples) * RATE / src_rate))
        if count < 2:
            return np.zeros(WINDOW, np.float32)
        pos = np.linspace(0, len(samples) - 1, count)
        left = np.floor(pos).astype(np.int64)
        frac = (pos - left).astype(np.float32)
        right = np.minimum(left + 1, len(samples) - 1)
        out = samples[left] * (1 - frac) + samples[right] * frac
    if len(out) < WINDOW:
        out = np.pad(out, (0, WINDOW - len(out)))
    return out[:WINDOW].astype(np.float32)


def cosine_gap(left, right):
    a = float(np.linalg.norm(left))
    b = float(np.linalg.norm(right))
    if a < 1e-8 or b < 1e-8:
        return 0.0
    return float(1 - np.dot(left, right) / (a * b))


def peak_kb():
    import resource

    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss


def main():
    if len(sys.argv) != 3:
        fail("usage: efficientat_mn04.py manifest.json cues.json")
    if not MODEL.is_file():
        fail(f"modèle absent : {MODEL}")
    digest = hashlib.sha256(MODEL.read_bytes()).hexdigest()
    if digest != EXPECTED:
        fail(f"SHA-256 inattendu : {digest}")
    import onnxruntime as ort

    available = ort.get_available_providers()
    providers = ["CPUExecutionProvider"]
    if "XnnpackExecutionProvider" in available:
        providers = ["XnnpackExecutionProvider", "CPUExecutionProvider"]
    session = ort.InferenceSession(str(MODEL), providers=providers)
    used = session.get_providers()[0]
    manifest = json.loads(Path(sys.argv[1]).read_text())
    cues = []
    windows = 0
    started = time.perf_counter()
    for item in manifest:
        path = item["path"]
        episode = int(item["episodeId"])
        src = int(item.get("sampleRate", 11025))
        pcm = np.fromfile(path, dtype="<i2").astype(np.float32) / 32768.0
        hop = int(round(HOP_S * src))
        previous = None
        for start in range(0, max(1, len(pcm) - hop // 4), hop):
            piece = pcm[start : start + int(round(3 * src))]
            if len(piece) < src:
                break
            wave = resample(piece, src)[None, :]
            probs = session.run(None, {"waveform": wave})[0][0]
            jump = 0.0 if previous is None else cosine_gap(previous, probs)
            previous = probs
            begin = int(round(start * 1000 / src))
            cues.append(
                {
                    "episodeId": episode,
                    "startMs": begin,
                    "endMs": begin + 3000,
                    "speech": float(probs[SPEECH]),
                    "music": float(probs[MUSIC]),
                    "jingle": float(probs[JINGLE]),
                    "backgroundMusic": float(probs[BACKGROUND]),
                    "scoreJump": jump,
                }
            )
            windows += 1
        del pcm
    elapsed = int(round((time.perf_counter() - started) * 1000))
    Path(sys.argv[2]).write_text(json.dumps(cues))
    print(
        f"MN04 provider={used} windows={windows} ms={elapsed} "
        f"peak_kb={peak_kb()} sha={digest} embedding=absent",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
