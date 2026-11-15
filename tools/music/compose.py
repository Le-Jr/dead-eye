"""Writes the score of Dead Eye Range as MIDI.

    python tools/music/compose.py

Five looping cues, each split into three stems that the game layers at run
time (see autoload/music_director.gd), plus three one-shot stingers:

    stem 0  rhythm: guitar and bass, always playing
    stem 1  melody
    stem 2  intensity: percussion and extra colour, mixed in by gameplay

Output goes to audio/music/midi/ together with score.json, which render.py
reads. All music here is original. Needs `mido`.
"""
from pathlib import Path
import json
import random

import mido

OUT = Path(__file__).resolve().parents[2] / "audio" / "music" / "midi"
TICKS = 480
DRUMS = 9  # General MIDI percussion channel

# General MIDI programs (0-based).
NYLON, STEEL, HARMONICA, WHISTLE, BANJO, FIDDLE = 24, 25, 22, 78, 105, 110
BASS, CONTRABASS, TREMOLO, STRINGS, CHOIR = 32, 43, 44, 48, 52
TRUMPET, BELLS, TIMPANI = 56, 14, 47
# General MIDI percussion keys.
KICK, STICK, SNARE, HAT, TAMBOURINE, CRASH = 36, 37, 38, 42, 54, 49
MARACAS, WOOD_HI, WOOD_LO = 70, 76, 77

NOTE_OFFSETS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

# Guitar voicings, low string first.
CHORDS = {
    "Dm": "D3 A3 D4 F4", "Bb": "Bb2 F3 Bb3 D4", "C": "C3 G3 C4 E4", "Gm": "G2 D3 G3 Bb3",
    "A": "A2 E3 A3 C#4", "F": "F2 C3 F3 A3", "Em": "E2 B2 E3 G3", "G": "G2 D3 G3 B3",
    "D": "D3 A3 D4 F#4", "B7": "B2 F#3 A3 D#4", "Bm": "B2 F#3 B3 D4",
}


def pitch(name):
    """'C#4' -> 61. Middle C is C4."""
    value = NOTE_OFFSETS[name[0]]
    rest = name[1:]
    while rest[0] in "#b":
        value += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return value + 12 * (int(rest) + 1)


def chord(name):
    return [pitch(n) for n in CHORDS[name].split()]


def bass_root(name):
    """The chord's root in the bass register (E1..D#2)."""
    return 28 + (chord(name)[0] - 28) % 12


class Track:
    def __init__(self, program, channel, seed=0):
        self.program = program
        self.channel = channel
        self.notes = []  # (start beat, length in beats, pitch, velocity)
        self._rng = random.Random(seed)

    def add(self, start, length, note, velocity):
        # A little looseness so it does not sound sequenced.
        start = max(0.0, start + self._rng.uniform(-0.008, 0.012))
        velocity = max(1, min(127, round(velocity * self._rng.uniform(0.92, 1.06))))
        self.notes.append((start, length, note, velocity))

    def melody(self, start, phrase, velocity, transpose=0, gate=0.94):
        """'A4:1 D5:1.5 r:.5 | ...'  Bar lines are only for the reader."""
        at = start
        for token in phrase.split():
            if token == "|":
                continue
            name, beats = token.split(":")
            beats = float(beats)
            if name != "r":
                self.add(at, beats * gate, pitch(name) + transpose, velocity)
            at += beats
        return at

    def drums(self, bar, key, pattern, velocity, accent=1.25):
        """One bar of sixteenths: 'x' hit, 'X' accent, anything else rest."""
        for step, mark in enumerate(pattern):
            if mark in "xX":
                self.add(bar * 4 + step * 0.25, 0.2, key, velocity * (accent if mark == "X" else 1.0))


def fingerpick(track, bar, name, velocity, order=(0, 2, 1, 3, 2, 3, 1, 2)):
    notes = chord(name)
    for i, string in enumerate(order):
        track.add(bar * 4 + i * 0.5, 1.4, notes[string], velocity * (1.15 if i % 4 == 0 else 1.0))


def strum(track, at, name, velocity, up=False, length=0.45):
    notes = chord(name)
    for i, note in enumerate(reversed(notes) if up else notes):
        track.add(at + i * 0.018, length, note, velocity)


def walking_bass(track, bar, name, velocity, beats=(0, 2)):
    root = bass_root(name)
    for i, beat in enumerate(beats):
        track.add(bar * 4 + beat, 1.6, root + (7 if i % 2 else 0), velocity)


# --- Cues --------------------------------------------------------------------

def menu():
    """Main theme. D minor, slow and wide: picked guitar and a lone whistle."""
    progression = "Dm Dm Bb C Dm Gm A A Dm Dm Bb C F C A Dm".split()
    guitar, bass = Track(NYLON, 0, 1), Track(BASS, 1, 2)
    for bar, name in enumerate(progression):
        fingerpick(guitar, bar, name, 72)
        walking_bass(bass, bar, name, 78)
    whistle = Track(WHISTLE, 2, 3)
    whistle.melody(0, """
        A4:1 D5:1 F5:1.5 E5:.5 | D5:3 r:1 | D5:1 F5:1 G5:1.5 F5:.5 | E5:3 r:1 |
        A4:1 D5:1 F5:1.5 A5:.5 | G5:2 Bb5:1 G5:1 | A5:3 G5:.5 F5:.5 | E5:2 C#5:2 |
        A5:1.5 G5:.5 F5:1 D5:1 | A4:3 r:1 | Bb4:1 D5:1 F5:1.5 D5:.5 | E5:2 G5:2 |
        A5:2 F5:1 C5:1 | G5:2 E5:2 | E5:1 C#5:1 A4:1 C#5:1 | D5:4""", 60)
    pad = Track(STRINGS, 3, 4)
    choir, bells, timpani, perc = Track(CHOIR, 4, 5), Track(BELLS, 5, 6), Track(TIMPANI, 6, 7), Track(0, DRUMS, 8)
    for bar, name in enumerate(progression):
        if bar % 4 == 0:
            bells.add(bar * 4, 4, pitch("D4") if bar % 8 == 0 else pitch("A4"), 70)
        if bar >= 8:
            notes = chord(name)
            pad.add(bar * 4, 3.9, notes[2], 46)
            pad.add(bar * 4, 3.9, notes[3], 42)
            choir.add(bar * 4, 3.9, notes[0] + 12, 58)
            choir.add(bar * 4, 3.9, notes[1] + 12, 52)
            timpani.add(bar * 4, 2, bass_root(name) + 12, 74)
            perc.drums(bar, TAMBOURINE, "----x-------x-x-", 52)
    for i in range(8):  # roll into the second half
        timpani.add(31 + i * 0.125, 0.2, pitch("A2"), 34 + i * 6)
    return {"bpm": 88, "bars": 16, "stems": [[guitar, bass], [whistle, pad], [choir, bells, timpani, perc]]}


def gallery():
    """Shooting gallery. E minor at a gallop: fiddle, banjo, a train of a rhythm."""
    progression = "Em Em G D Em C B7 B7 Em Em G D C D Em Em".split()
    guitar, bass = Track(STEEL, 0, 11), Track(BASS, 1, 12)
    for bar, name in enumerate(progression):
        for beat in range(4):
            at = bar * 4 + beat
            strum(guitar, at, name, 74 if beat % 2 else 60, length=0.3)
            strum(guitar, at + 0.5, name, 46, up=True, length=0.18)
            strum(guitar, at + 0.75, name, 52, length=0.18)
            bass.add(at, 0.85, bass_root(name) + (7 if beat % 2 else 0), 86)
    fiddle, banjo = Track(FIDDLE, 2, 13), Track(BANJO, 3, 14)
    first = """
        E5:.5 G5:.5 B5:1 A5:.5 G5:.5 E5:1 | G5:.5 A5:.5 B5:1 E5:2 |
        D5:.5 G5:.5 B5:1 A5:.5 G5:.5 D5:1 | F#5:.5 A5:.5 D6:1 A5:2 |"""
    fiddle.melody(0, first + """
        E5:.5 G5:.5 B5:1 C6:.5 B5:.5 G5:1 | E5:.5 G5:.5 C6:1 B5:.5 A5:.5 G5:1 |
        F#5:1 B5:1 D#5:1 F#5:1 | B5:2 A5:1 F#5:1 |""" + first + """
        C6:1 B5:.5 A5:.5 G5:1 E5:1 | D5:1 F#5:.5 A5:.5 D6:1 C6:.5 A5:.5 |
        B5:1 G5:1 E5:2 | E5:1 B4:1 E5:2""", 96)
    roll = (1, 2, 3, 2, 1, 3, 2, 3)
    for bar, name in enumerate(progression):
        notes = chord(name)
        for i in range(16):
            banjo.add(bar * 4 + i * 0.25, 0.3, notes[roll[i % 8]] + 12, 58 if i % 4 else 70)
    drums, trumpet = Track(0, DRUMS, 15), Track(TRUMPET, 4, 16)
    for bar, name in enumerate(progression):
        drums.drums(bar, KICK, "x-----x-x-----x-", 92)
        drums.drums(bar, SNARE, "----x-------x--x" if bar % 4 == 3 else "----x-------x---", 84)
        drums.drums(bar, TAMBOURINE, "x-xxx-xxx-xxx-xx", 44, 1.4)
        if bar % 8 == 0:
            drums.add(bar * 4, 1, CRASH, 76)
        if bar % 4 == 3:
            top = chord(name)[3] + 12
            for at, length in [(2, 0.4), (2.5, 0.4), (3, 0.9)]:
                trumpet.add(bar * 4 + at, length, top, 88)
                trumpet.add(bar * 4 + at, length, top - 5, 76)
    return {"bpm": 138, "bars": 16, "stems": [[guitar, bass], [fiddle, banjo], [drums, trumpet]]}


def quick_draw():
    """The standoff. One held note, a clock, a heartbeat, a far-off trumpet."""
    drone, tremolo, guitar = Track(CONTRABASS, 0, 21), Track(TREMOLO, 1, 22), Track(NYLON, 2, 23)
    for bar in range(8):
        drone.add(bar * 4, 4.05, pitch("D1"), 70)
        drone.add(bar * 4, 4.05, pitch("D2"), 58)
        tremolo.add(bar * 4, 4.05, pitch("D3"), 38)
        tremolo.add(bar * 4, 4.05, pitch("A3") if bar % 4 != 3 else pitch("Bb3"), 34)
    guitar.melody(0, """
        D3:1 A3:1 D4:2 | Eb4:1 D4:3 | D3:1 A3:1 D4:2 | C4:1 D4:3 |
        G2:1 D3:1 G3:1 Bb3:1 | A3:2 D3:2 | D3:1 A3:1 Eb4:2 | D4:4""", 66, gate=1.6)
    trumpet, bells = Track(TRUMPET, 3, 24), Track(BELLS, 4, 25)
    trumpet.melody(8, """
        A4:2 D5:2 | Eb5:1.5 D5:.5 C5:1 D5:1 | Bb4:2.5 A4:.5 G4:1 | A4:4 |
        D5:1 Eb5:1 D5:1 A4:1 | A4:3 r:1""", 72)
    bells.add(0, 6, pitch("D4"), 64)
    bells.add(16, 6, pitch("D4"), 58)
    heart, clock = Track(TIMPANI, 5, 26), Track(0, DRUMS, 27)
    for beat in range(32):
        heart.add(beat, 0.25, pitch("D2"), 50)
        heart.add(beat + 0.3, 0.25, pitch("D2"), 34)
        clock.add(beat, 0.1, STICK, 44)
        clock.add(beat + 0.5, 0.1, STICK, 30)
    for bar in (3, 7):  # a rattlesnake
        for i in range(16):
            clock.add(bar * 4 + 3 + i / 16, 0.05, MARACAS, 30 + i * 3)
    return {"bpm": 60, "bars": 8, "stems": [[drone, tremolo, guitar], [trumpet, bells], [heart, clock]]}


def results():
    """After the smoke clears. D major, two trumpets in thirds."""
    progression = "D G D A Bm G A D".split()
    guitar, bass = Track(STEEL, 0, 31), Track(BASS, 1, 32)
    for bar, name in enumerate(progression):
        for at, up, velocity in [(0, False, 78), (1, False, 62), (1.5, True, 50), (2.5, True, 52), (3, False, 66), (3.5, True, 50)]:
            strum(guitar, bar * 4 + at, name, velocity, up)
        walking_bass(bass, bar, name, 84)
    lead, second = Track(TRUMPET, 2, 33), Track(TRUMPET, 3, 34)
    lead.melody(0, """
        F#4:1 A4:1 D5:1.5 A4:.5 | B4:2 G4:1 B4:1 | A4:1.5 F#4:.5 D4:1 F#4:1 | E4:3 r:1 |
        F#4:1 B4:1 D5:1.5 B4:.5 | B4:2 D5:1 B4:1 | C#5:1 A4:1 E4:1 A4:1 | D5:3 r:1""", 94)
    second.melody(0, """
        D4:1 F#4:1 A4:1.5 F#4:.5 | G4:2 D4:1 G4:1 | F#4:1.5 D4:.5 A3:1 D4:1 | C#4:3 r:1 |
        D4:1 F#4:1 B4:1.5 F#4:.5 | G4:2 B4:1 G4:1 | A4:1 E4:1 C#4:1 E4:1 | A4:3 r:1""", 76)
    drums, bells, timpani = Track(0, DRUMS, 35), Track(BELLS, 4, 36), Track(TIMPANI, 5, 37)
    for bar, name in enumerate(progression):
        drums.drums(bar, KICK, "x-------x-x-----", 88)
        drums.drums(bar, SNARE, "----x-------x---", 80)
        drums.drums(bar, TAMBOURINE, "x-x-X-x-x-x-X-x-", 46)
        timpani.add(bar * 4, 1.5, bass_root(name) + 12, 72)
        if bar % 4 == 0:
            bells.add(bar * 4, 4, pitch("D5"), 72)
            drums.add(bar * 4, 1, CRASH, 70)
    return {"bpm": 112, "bars": 8, "stems": [[guitar, bass], [lead, second], [drums, bells, timpani]]}


def town():
    """Free Range and Long Shot. G major, in no hurry; the harmonica comes and goes."""
    progression = "G G C G Em C D D G G C G Em D G G".split()
    guitar, bass = Track(NYLON, 0, 41), Track(BASS, 1, 42)
    for bar, name in enumerate(progression):
        fingerpick(guitar, bar, name, 64, (0, 2, 3, 2, 1, 2, 3, 2))
        walking_bass(bass, bar, name, 66)
    harmonica = Track(HARMONICA, 2, 43)
    harmonica.melody(16, """
        B4:1.5 G4:.5 E4:2 | E4:1 G4:1 C5:2 | A4:1.5 B4:.5 A4:1 F#4:1 | D4:3 r:1""", 74)
    harmonica.melody(48, """
        B4:1 E5:1 D5:1 B4:1 | A4:2 F#4:1 A4:1 | G4:1.5 A4:.5 B4:1 D5:1 | G4:3 r:1""", 74)
    hooves, banjo = Track(0, DRUMS, 44), Track(BANJO, 3, 45)
    for bar, name in enumerate(progression):
        for beat in range(4):
            hooves.add(bar * 4 + beat, 0.1, WOOD_HI, 40)
            hooves.add(bar * 4 + beat + 0.5, 0.1, WOOD_LO, 34)
        hooves.drums(bar, MARACAS, "--x---x---x---x-", 30)
        if bar % 4 == 3:
            notes = chord(name)
            for i, string in enumerate((0, 1, 2, 3, 2, 3, 1, 3)):
                banjo.add(bar * 4 + 2 + i * 0.25, 0.4, notes[string] + 12, 56 + i * 2)
    return {"bpm": 76, "bars": 16, "stems": [[guitar, bass], [harmonica], [hooves, banjo]]}


# --- Stingers ----------------------------------------------------------------

def sting_record():
    """A new best score."""
    trumpet, guitar, bells = Track(TRUMPET, 0, 51), Track(STEEL, 1, 52), Track(BELLS, 2, 53)
    trumpet.melody(0, "D4:.5 F#4:.5 A4:.5 D5:2.5", 100)
    trumpet.melody(0, "A3:.5 D4:.5 F#4:.5 A4:2.5", 82)
    strum(guitar, 1.5, "D", 84, length=2.5)
    bells.add(1.5, 3, pitch("D5"), 80)
    return {"bpm": 132, "bars": 1, "stems": [[trumpet, guitar, bells]]}


def sting_fail():
    """A foul, or shooting someone you should not have."""
    guitar, timpani = Track(NYLON, 0, 54), Track(TIMPANI, 1, 55)
    guitar.melody(0, "D4:.5 C4:.5 Bb3:.5 A3:2.5", 86, gate=1.5)
    timpani.add(1.5, 2, pitch("A1"), 80)
    return {"bpm": 96, "bars": 1, "stems": [[guitar, timpani]]}


def sting_ready():
    """A round is about to start."""
    guitar, bells = Track(NYLON, 0, 56), Track(BELLS, 1, 57)
    strum(guitar, 0, "Dm", 84, length=3.5)
    bells.add(0, 3.5, pitch("A4"), 62)
    return {"bpm": 90, "bars": 1, "stems": [[guitar, bells]]}


CUES = {"menu": menu, "gallery": gallery, "quick_draw": quick_draw, "results": results, "town": town}
STINGERS = {"sting_record": sting_record, "sting_fail": sting_fail, "sting_ready": sting_ready}
# Beats of silence after the last bar so reverb and long notes can ring out.
TAIL_BEATS = 8


def write_midi(path, tracks, bpm, beats):
    midi = mido.MidiFile(ticks_per_beat=TICKS)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(bpm), time=0))
    conductor.append(mido.MetaMessage("end_of_track", time=round((beats + TAIL_BEATS) * TICKS)))
    midi.tracks.append(conductor)
    for track in tracks:
        events = []
        for start, length, note, velocity in track.notes:
            events.append((round(start * TICKS), 1, mido.Message("note_on", channel=track.channel, note=note, velocity=velocity)))
            events.append((round((start + length) * TICKS), 0, mido.Message("note_off", channel=track.channel, note=note)))
        events.sort(key=lambda e: (e[0], e[1]))
        out = mido.MidiTrack()
        if track.channel != DRUMS:
            out.append(mido.Message("program_change", channel=track.channel, program=track.program, time=0))
        last = 0
        for tick, _, message in events:
            out.append(message.copy(time=tick - last))
            last = tick
        out.append(mido.MetaMessage("end_of_track", time=max(0, round((beats + TAIL_BEATS) * TICKS) - last)))
        midi.tracks.append(out)
    midi.save(path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.mid"):
        old.unlink()
    score = {}
    for name, make in {**CUES, **STINGERS}.items():
        cue = make()
        beats = cue["bars"] * 4
        files = []
        for index, tracks in enumerate(cue["stems"]):
            path = OUT / f"{name}_{index}.mid"
            write_midi(path, tracks, cue["bpm"], beats)
            files.append(path.name)
        write_midi(OUT / f"{name}.mid", [t for stem in cue["stems"] for t in stem], cue["bpm"], beats)
        score[name] = {"bpm": cue["bpm"], "beats": beats, "loop": name in CUES, "stems": files}
    (OUT / "score.json").write_text(json.dumps(score, indent=2))
    print(f"{len(CUES)} cues and {len(STINGERS)} stingers -> {OUT}")


if __name__ == "__main__":
    main()
