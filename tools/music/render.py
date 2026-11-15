"""Renders the MIDI score to the OGG files the game plays.

    python tools/music/render.py [--fluidsynth path/to/fluidsynth.exe] [--soundfont path/to/file.sf2]

Run compose.py first. Each stem is rendered on its own with FluidSynth, so
the stems of a cue stay sample-aligned. For looping cues, whatever rings on
past the last bar (reverb, long notes) is folded back onto the start, which
makes the loop seamless. Needs numpy, soundfile, FluidSynth and a General
MIDI soundfont; by default it looks for both under .downloads/.
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import tempfile

import numpy as np
import soundfile

ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "audio" / "music"
MIDI = MUSIC / "midi"
RATE = 44100
PEAK = 0.84


def find_fluidsynth(given):
    if given:
        return given
    on_path = shutil.which("fluidsynth")
    if on_path:
        return Path(on_path)
    found = sorted((ROOT / ".downloads").rglob("fluidsynth.exe"))
    if not found:
        raise SystemExit("FluidSynth not found. Pass --fluidsynth or put it on PATH.")
    return found[0]


def render_stem(fluidsynth, soundfont, midi, folder):
    wav = Path(folder) / (midi.stem + ".wav")
    subprocess.run(
        [
            str(fluidsynth), "-ni", "-q", "-F", str(wav), "-r", str(RATE), "-g", "0.5",
            "-o", "synth.reverb.active=1", "-o", "synth.reverb.room-size=0.72",
            "-o", "synth.reverb.damp=0.35", "-o", "synth.reverb.level=0.55",
            "-o", "synth.chorus.active=0",
            str(soundfont), str(midi),
        ],
        check=True, stdout=subprocess.DEVNULL,
    )
    audio, rate = soundfile.read(wav, dtype="float64", always_2d=True)
    assert rate == RATE, rate
    return audio


def make_loop(audio, length):
    """Cuts to `length` samples and wraps the tail around to the start."""
    if len(audio) < length:
        audio = np.vstack([audio, np.zeros((length - len(audio), audio.shape[1]))])
    loop = audio[:length].copy()
    tail = audio[length:length * 2]
    loop[: len(tail)] += tail
    return loop


def write_ogg(path, audio):
    # Written in blocks: libsndfile's Vorbis encoder can overflow its stack
    # when handed a whole long file at once.
    with soundfile.SoundFile(path, "w", RATE, audio.shape[1], format="OGG", subtype="VORBIS") as f:
        for start in range(0, len(audio), RATE):
            f.write(audio[start:start + RATE])


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fluidsynth", type=Path)
    parser.add_argument("--soundfont", type=Path, default=ROOT / ".downloads" / "soundfont" / "GeneralUser-GS.sf2")
    args = parser.parse_args()
    if not args.soundfont.is_file():
        raise SystemExit(f"Soundfont not found: {args.soundfont}")
    fluidsynth = find_fluidsynth(args.fluidsynth)
    score = json.loads((MIDI / "score.json").read_text())

    for old in list(MUSIC.glob("*.ogg")) + list(MUSIC.glob("*.wav")):
        old.unlink()
    manifest = {}
    with tempfile.TemporaryDirectory() as folder:
        for name, cue in score.items():
            stems = [render_stem(fluidsynth, args.soundfont, MIDI / file, folder) for file in cue["stems"]]
            if cue["loop"]:
                length = round(cue["beats"] * 60 / cue["bpm"] * RATE)
                stems = [make_loop(stem, length) for stem in stems]
            else:
                # Trim trailing silence, keep a short fade.
                stem = stems[0]
                loud = np.nonzero(np.max(np.abs(stem), axis=1) > 0.002)[0]
                stem = stem[: loud[-1] + RATE // 5]
                fade = RATE // 5
                stem[-fade:] *= np.linspace(1, 0, fade)[:, None]
                stems = [stem]
            # One gain for the whole cue keeps the balance between stems.
            total = sum(stems)
            gain = PEAK / max(1e-9, float(np.max(np.abs(total))))
            manifest[name] = []
            for index, stem in enumerate(stems):
                path = MUSIC / f"{name}_{index}.ogg"
                write_ogg(path, stem * gain)
                manifest[name].append("res://audio/music/" + path.name)
            print(f"{name:13s} {len(stems)} stem(s)  {len(stems[0]) / RATE:6.2f} s  gain {gain:.2f}")
    (MUSIC / "manifest.json").write_text(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
