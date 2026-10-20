"""song_midi · a song recording to an editable MIDI file, and that MIDI to 16-bit style music.

Pure Python 3, no packages. Two steps, so a person can fix wrong notes in any MIDI editor between
them:

    python -I tools/song_midi.py transcribe <in.wav> <out.mid>
    python -I tools/song_midi.py render <in.mid> <out.wav>

transcribe reads a 16-bit PCM WAV (mono or stereo, any rate), finds the tempo and the beat from the
onsets, then for every eighth note finds the strongest melody note (C4 to C6) and for every beat the
strongest bass note (C2 to B3) by harmonic salience, snaps both to the song's key, and writes a
type-1 MIDI file: track 1 the tempo, track 2 the melody (channel 1, Synth Brass), track 3 the bass
(channel 2, Synth Bass), track 4 the beat (channel 10: kick 36, snare 38, closed hat 42), the kicks
and snares where the recording has them, the hats on every eighth.

render plays a MIDI file the way a 16-bit console would: a two-operator FM voice for the melody
(Mega Drive brass), an FM slap bass, synthesised drums, and an echo on the melody like the SNES
DSP's. It writes 16-bit mono PCM at 22050 Hz. It reads any simple type-0 or type-1 file: note on and
off, tempo, running status.

The game's splash plays the rendered file (scenes/splash.tscn, `music`); the MIDI file sits beside
it in assets/audio/music/ and is not part of the build.
"""
import array, cmath, math, struct, sys

# --- reading and writing WAV ------------------------------------------------------------------

def read_wav(path):
    data = open(path, "rb").read()
    assert data[:4] == b"RIFF" and data[8:12] == b"WAVE", "not a WAV file"
    pos, fmt, pcm = 12, None, None
    while pos + 8 <= len(data):
        cid, size = data[pos:pos + 4], struct.unpack("<I", data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + size]
        if cid == b"fmt ":
            fmt = struct.unpack("<HHIIHH", body[:16])
        elif cid == b"data":
            pcm = body
        pos += 8 + size + (size & 1)
    tag, channels, rate, _, _, bits = fmt
    assert bits == 16 and tag in (1, 0xFFFE), "transcribe needs 16-bit PCM"
    raw = array.array("h")
    raw.frombytes(pcm[: len(pcm) - len(pcm) % 2])
    if sys.byteorder != "little":
        raw.byteswap()
    frames = len(raw) // channels
    mono = [sum(raw[i * channels:(i + 1) * channels]) / (channels * 32768.0) for i in range(frames)]
    return mono, rate


def write_wav(path, samples, rate):
    out = array.array("h", (max(-32767, min(32767, int(round(v * 32767)))) for v in samples))
    if sys.byteorder != "little":
        out.byteswap()
    pcm = out.tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(pcm)) + pcm)

# --- a small FFT --------------------------------------------------------------------------------

class FFT:
    def __init__(self, n):
        self.n = n
        bits = n.bit_length() - 1
        self.rev = [int(format(i, "0%db" % bits)[::-1], 2) for i in range(n)]
        self.tw = [cmath.exp(-2j * math.pi * k / n) for k in range(n // 2)]
        self.window = [0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)) for i in range(n)]

    def mags(self, signal, start):
        n, sig = self.n, signal
        a = [complex(sig[start + r] * self.window[r]) if 0 <= start + r < len(sig) else 0j for r in self.rev]
        size = 2
        while size <= n:
            half, step = size // 2, n // size
            tw = self.tw
            for s in range(0, n, size):
                for k in range(half):
                    t = tw[k * step] * a[s + k + half]
                    u = a[s + k]
                    a[s + k] = u + t
                    a[s + k + half] = u - t
            size *= 2
        return [abs(a[i]) for i in range(n // 2)]

# --- transcription ------------------------------------------------------------------------------

MAJOR = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MINOR = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def salience(mags, df, m, harmonics):
    f0, total = midi_hz(m), 0.0
    for h, w in enumerate(harmonics, start=1):
        b = h * f0 / df
        i = int(b)
        if i + 1 >= len(mags):
            break
        total += w * max(mags[i], mags[i + 1])
    return total


def best_note(mags, df, low, high, harmonics):
    best, best_s = None, 0.0
    for m in range(low, high + 1):
        s = salience(mags, df, m, harmonics)
        # A note an octave up is only taken over its own sub-octave if it is clearly stronger.
        if s > best_s:
            best, best_s = m, s
    return best, best_s


def percentile(values, p):
    v = sorted(values)
    return v[min(len(v) - 1, int(p * len(v)))] if v else 0.0


def transcribe(wav_path, mid_path):
    audio, rate = read_wav(wav_path)
    # Work at about 11 kHz: enough for a melody's harmonics, half the work.
    factor = max(1, rate // 11025)
    sig = [sum(audio[i:i + factor]) / factor for i in range(0, len(audio) - factor + 1, factor)]
    sr = rate / factor
    seconds = len(sig) / sr
    print("audio %.1f s at %d Hz" % (seconds, sr))

    # Onsets: spectral flux over the whole band, and over the kick's and the snare's bands.
    hop, small = 256, FFT(1024)
    df_small = sr / 1024
    lo = (int(40 / df_small), int(160 / df_small))
    hi = (int(1800 / df_small), int(5000 / df_small))
    prev, flux, flux_lo, flux_hi = None, [], [], []
    for start in range(0, len(sig) - 1024, hop):
        m = [math.log1p(10 * x) for x in small.mags(sig, start)]
        if prev is None:
            prev = m
        d = [max(0.0, a - b) for a, b in zip(m, prev)]
        flux.append(sum(d))
        flux_lo.append(sum(d[lo[0]:lo[1]]))
        flux_hi.append(sum(d[hi[0]:hi[1]]))
        prev = m
    frame_s = hop / sr
    mean = sum(flux) / len(flux)
    env = [max(0.0, f - mean) for f in flux]

    def env_at(t):
        x = t / frame_s
        i = int(x)
        if i + 1 >= len(env) or i < 0:
            return 0.0
        return env[i] + (env[i + 1] - env[i]) * (x - i)

    # Tempo and beat phase: the comb of beats that lands on the most onset, with a gentle
    # preference for tempos near 120 BPM (halves and doubles of a beat score alike otherwise).
    best = (0.0, 0.5, 0.0)
    period = 60.0 / 180.0
    while period <= 60.0 / 70.0:
        bpm = 60.0 / period
        prior = math.exp(-0.5 * (math.log2(bpm / 120.0) / 0.6) ** 2)
        phase = 0.0
        while phase < period:
            t, s, k = phase, 0.0, 0
            while t < seconds:
                s += env_at(t)
                t += period
                k += 1
            score = s / max(1, k) * prior
            if score > best[0]:
                best = (score, period, phase)
            phase += frame_s
        period += 0.002
    _, period, phase = best
    bpm = 60.0 / period
    print("tempo %.1f BPM, first beat at %.2f s" % (bpm, phase))

    big = FFT(2048)
    bass_fft = FFT(4096)
    slot = period / 2
    n_slots = int((seconds - phase) / slot)
    mel_h = [1.0, 0.8, 0.6, 0.45, 0.35]
    bass_h = [1.0, 0.8, 0.6, 0.45]
    mel, mel_s, onset = [], [], []
    for k in range(n_slots):
        t = phase + k * slot
        start = int((t + 0.1 * slot) * sr)
        mags = big.mags(sig, start)
        note, s = best_note(mags, sr / 2048, 60, 84, mel_h)
        mel.append(note)
        mel_s.append(s)
        onset.append(env_at(t))
    bass, bass_s = [], []
    for b in range(n_slots // 2):
        t = phase + b * period
        mags = bass_fft.mags(sig, int(t * sr))
        note, s = best_note(mags, sr / 4096, 36, 59, bass_h)
        bass.append(note)
        bass_s.append(s)

    # Voiced where the note is strong for this song; quiet slots are rests.
    mel_thr = 0.35 * percentile(mel_s, 0.9)
    bass_thr = 0.3 * percentile(bass_s, 0.9)
    mel = [n if s >= mel_thr else None for n, s in zip(mel, mel_s)]
    bass = [n if s >= bass_thr else None for n, s in zip(bass, bass_s)]
    # Smooth: a lone note an octave off its two neighbours is folded back, a lone blip between two
    # equal notes takes theirs.
    for seq in (mel, bass):
        for i in range(1, len(seq) - 1):
            a, b, c = seq[i - 1], seq[i], seq[i + 1]
            if a is None or b is None or c is None:
                continue
            if a == c and b != a:
                if abs(b - a) % 12 == 0 or abs(b - a) <= 2:
                    seq[i] = a
            elif abs(b - a) >= 12 and abs(b - c) >= 12:
                seq[i] = b - 12 if b > a else b + 12

    # Key: the 24 key profiles against the notes' weighted pitch classes; snap to its scale.
    chroma = [0.0] * 12
    for n, s in zip(mel, mel_s):
        if n is not None:
            chroma[n % 12] += s
    for n, s in zip(bass, bass_s):
        if n is not None:
            chroma[n % 12] += s
    def corr(profile, tonic):
        p = [profile[(i - tonic) % 12] for i in range(12)]
        mp, mc = sum(p) / 12, sum(chroma) / 12
        num = sum((x - mp) * (y - mc) for x, y in zip(p, chroma))
        den = math.sqrt(sum((x - mp) ** 2 for x in p) * sum((y - mc) ** 2 for y in chroma)) or 1.0
        return num / den
    key = max(((corr(MAJOR, t), t, "major") for t in range(12)), key=lambda x: x[0])
    key_m = max(((corr(MINOR, t), t, "minor") for t in range(12)), key=lambda x: x[0])
    _, tonic, mode = key if key[0] >= key_m[0] else key_m
    steps = [0, 2, 4, 5, 7, 9, 11] if mode == "major" else [0, 2, 3, 5, 7, 8, 10, 11]
    scale = {(tonic + s) % 12 for s in steps}
    def snap(n):
        if n is None or n % 12 in scale:
            return n
        return n - 1 if (n - 1) % 12 in scale else n + 1
    mel = [snap(n) for n in mel]
    bass = [snap(n) for n in bass]
    print("key %s %s" % (NOTE_NAMES[tonic], mode))

    # Notes: a slot repeating the note before it holds it on, unless an onset re-strikes it.
    onset_med = percentile([o for o in onset if o > 0] or [0.0], 0.5)
    ticks_slot = 240   # an eighth at 480 ticks a quarter
    mel_notes = []     # (start tick, length ticks, note, velocity)
    for i, n in enumerate(mel):
        if n is None:
            continue
        if mel_notes and i > 0 and mel[i - 1] == n and onset[i] < onset_med and \
                mel_notes[-1][0] + mel_notes[-1][1] == i * ticks_slot:
            s0, ln, nn, v = mel_notes[-1]
            mel_notes[-1] = (s0, ln + ticks_slot, nn, v)
        else:
            mel_notes.append((i * ticks_slot, ticks_slot, n, 96 if i % 2 == 0 else 84))
    bass_notes = []
    for b, n in enumerate(bass):
        if n is None:
            continue
        if bass_notes and bass[b - 1] == n and onset[min(len(onset) - 1, b * 2)] < onset_med and \
                bass_notes[-1][0] + bass_notes[-1][1] == b * 480:
            s0, ln, nn, v = bass_notes[-1]
            bass_notes[-1] = (s0, ln + 480, nn, v)
        else:
            bass_notes.append((b * 480, 480, n, 100))

    # The beat: kicks and snares where their bands strike, hats on every eighth.
    def band_at(band, t):
        i = int(t / frame_s)
        return max(band[max(0, i - 1):i + 2] or [0.0])
    lo_vals = [band_at(flux_lo, phase + k * slot) for k in range(n_slots)]
    hi_vals = [band_at(flux_hi, phase + k * slot) for k in range(n_slots)]
    lo_thr = 1.3 * percentile(lo_vals, 0.5)
    hi_thr = 1.3 * percentile(hi_vals, 0.5)
    drums = []
    for k in range(n_slots):
        pos = k % 8
        if lo_vals[k] >= lo_thr and pos in (0, 3, 4, 7):
            drums.append((k * ticks_slot, 120, 36, 110))
        if hi_vals[k] >= hi_thr and pos in (2, 6):
            drums.append((k * ticks_slot, 120, 38, 100))
        drums.append((k * ticks_slot, 60, 42, 70 if pos % 2 == 0 else 50))
    kicks = sum(1 for d in drums if d[2] == 36)
    snares = sum(1 for d in drums if d[2] == 38)
    bars = max(1, n_slots // 8)
    if kicks < bars * 1.5:     # too few found: the plain rock beat instead
        drums = [d for d in drums if d[2] == 42]
        for bar in range(bars):
            for pos, note in ((0, 36), (2, 38), (4, 36), (6, 38)):
                drums.append(((bar * 8 + pos) * ticks_slot, 120, note, 108))
    print("melody %d notes, bass %d notes, kicks %d, snares %d over %d bars" % (
        len(mel_notes), len(bass_notes), kicks, snares, bars))
    write_midi(mid_path, bpm, [("Melody", 0, 62, mel_notes), ("Bass", 1, 38, bass_notes), ("Beat", 9, None, drums)],
               n_slots * ticks_slot)

# --- MIDI files -----------------------------------------------------------------------------------

def vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.insert(0, (n & 0x7F) | 0x80)
        n >>= 7
    return bytes(out)


def write_midi(path, bpm, tracks, end_tick):
    def track(events):
        events.sort(key=lambda e: (e[0], e[1]))
        out, last = b"", 0
        for tick, _, data in events:
            out += vlq(tick - last) + data
            last = tick
        out += vlq(max(0, end_tick - last)) + b"\xff\x2f\x00"
        return b"MTrk" + struct.pack(">I", len(out)) + out
    tempo = int(round(60_000_000 / bpm))
    chunks = [track([(0, 0, b"\xff\x51\x03" + tempo.to_bytes(3, "big")),
                     (0, 0, b"\xff\x58\x04\x04\x02\x18\x08")])]
    for name, ch, program, notes in tracks:
        ev = [(0, 0, b"\xff\x03" + vlq(len(name)) + name.encode())]
        if program is not None:
            ev.append((0, 1, bytes([0xC0 | ch, program])))
        for start, length, note, vel in notes:
            ev.append((start, 3, bytes([0x90 | ch, note, vel])))
            ev.append((start + length, 2, bytes([0x80 | ch, note, 0])))
        chunks.append(track(ev))
    with open(path, "wb") as f:
        f.write(b"MThd" + struct.pack(">IHHH", 6, 1, len(chunks), 480))
        for c in chunks:
            f.write(c)
    print("wrote", path)


def read_midi(path):
    """Notes as (start seconds, length seconds, channel, note, velocity), and the end in seconds."""
    data = open(path, "rb").read()
    assert data[:4] == b"MThd"
    _, ntracks, division = struct.unpack(">HHH", data[8:14])
    pos, raw, tempos = 14, [], []
    for _ in range(ntracks):
        assert data[pos:pos + 4] == b"MTrk"
        size = struct.unpack(">I", data[pos + 4:pos + 8])[0]
        p, end, tick, status = pos + 8, pos + 8 + size, 0, 0
        while p < end:
            delta = 0
            while True:
                b = data[p]; p += 1
                delta = (delta << 7) | (b & 0x7F)
                if b < 0x80:
                    break
            tick += delta
            b = data[p]
            if b == 0xFF:
                kind, p = data[p + 1], p + 2
                ln = 0
                while True:
                    c = data[p]; p += 1
                    ln = (ln << 7) | (c & 0x7F)
                    if c < 0x80:
                        break
                if kind == 0x51:
                    tempos.append((tick, int.from_bytes(data[p:p + 3], "big")))
                p += ln
                continue
            if b in (0xF0, 0xF7):
                p += 1
                ln = 0
                while True:
                    c = data[p]; p += 1
                    ln = (ln << 7) | (c & 0x7F)
                    if c < 0x80:
                        break
                p += ln
                continue
            if b & 0x80:
                status, p = b, p + 1
            kind, ch = status & 0xF0, status & 0x0F
            if kind in (0xC0, 0xD0):
                p += 1
                continue
            d1, d2 = data[p], data[p + 1]
            p += 2
            if kind in (0x80, 0x90):
                raw.append((tick, ch, d1, d2 if kind == 0x90 else 0))
        pos = end
    tempos.sort()
    if not tempos or tempos[0][0] > 0:
        tempos.insert(0, (0, 500000))   # the MIDI default, 120 BPM, until a tempo says otherwise
    def seconds(t):
        s, last_tick, us = 0.0, 0, tempos[0][1]
        for tt, tu in tempos[1:]:
            if tt >= t:
                break
            s += (tt - last_tick) * us / division / 1e6
            last_tick, us = tt, tu
        return s + (t - last_tick) * us / division / 1e6
    raw.sort()
    open_notes, notes, last = {}, [], 0
    for tick, ch, note, vel in raw:
        last = max(last, tick)
        key = (ch, note)
        if key in open_notes:
            s, v = open_notes.pop(key)
            notes.append((seconds(s), seconds(tick) - seconds(s), ch, note, v))
        if vel > 0:
            open_notes[key] = (tick, vel)
    return notes, seconds(last)

# --- rendering, 16-bit style ----------------------------------------------------------------------

RATE = 22050


def env_adsr(i, n, a, d, s, r):
    t = i / RATE
    length = n / RATE
    if t < a:
        v = t / a
    elif t < a + d:
        v = 1.0 - (1.0 - s) * (t - a) / d
    else:
        v = s
    left = length - t
    if left < r:
        v *= max(0.0, left / r)
    return v


def fm_brass(freq, seconds, vel):
    """Two-operator FM, modulator at 1:1 with a bright attack: Mega Drive brass."""
    n = int((seconds + 0.08) * RATE)
    out = [0.0] * n
    w = 2 * math.pi * freq / RATE
    for i in range(n):
        t = i / RATE
        e = env_adsr(i, n, 0.012, 0.15, 0.7, 0.07)
        index = 1.2 + 2.2 * math.exp(-t * 9.0)
        vib = 1.0 + 0.004 * math.sin(2 * math.pi * 5.5 * t) * min(1.0, t / 0.25)
        ph = w * i * vib
        out[i] = math.sin(ph + index * math.sin(ph)) * e * vel
    return out


def fm_bass(freq, seconds, vel):
    """FM slap bass: a hard index drop on the attack, then a round tone with a sub sine."""
    n = int((seconds + 0.04) * RATE)
    out = [0.0] * n
    w = 2 * math.pi * freq / RATE
    for i in range(n):
        t = i / RATE
        e = env_adsr(i, n, 0.004, 0.25, 0.55, 0.04)
        index = 0.8 + 3.0 * math.exp(-t * 25.0)
        ph = w * i
        out[i] = (0.75 * math.sin(ph + index * math.sin(ph)) + 0.35 * math.sin(ph)) * e * vel
    return out


class Noise:
    def __init__(self):
        self.state = 0x1234ABCD
    def next(self):
        self.state = (self.state * 1103515245 + 12345) & 0x7FFFFFFF
        return (self.state / 0x3FFFFFFF) - 1.0


def kick(vel):
    n = int(0.28 * RATE)
    out, ph = [0.0] * n, 0.0
    for i in range(n):
        t = i / RATE
        f = 45 + 110 * math.exp(-t * 28)
        ph += 2 * math.pi * f / RATE
        out[i] = math.sin(ph) * math.exp(-t * 11) * vel
    return out


def snare(vel, noise):
    n = int(0.2 * RATE)
    out, last, ph = [0.0] * n, 0.0, 0.0
    for i in range(n):
        t = i / RATE
        x = noise.next()
        hp = x - last
        last = x
        ph += 2 * math.pi * 185 / RATE
        out[i] = (0.75 * hp * math.exp(-t * 18) + 0.45 * math.sin(ph) * math.exp(-t * 30)) * vel
    return out


def hat(vel, noise):
    n = int(0.05 * RATE)
    out, last = [0.0] * n, 0.0
    for i in range(n):
        x = noise.next()
        out[i] = (x - last) * math.exp(-i / RATE * 70) * vel
        last = x
    return out


def render(mid_path, wav_path):
    notes, end = read_midi(mid_path)
    total = int((end + 0.5) * RATE)
    lead = [0.0] * total
    rest = [0.0] * total
    noise = Noise()
    def mix(buf, part, at, gain):
        s = int(at * RATE)
        for i, v in enumerate(part):
            j = s + i
            if 0 <= j < total:
                buf[j] += v * gain
    for start, length, ch, note, vel in notes:
        v = vel / 127.0
        if ch == 9:
            if note in (35, 36):
                mix(rest, kick(v), start, 0.55)
            elif note in (38, 40):
                mix(rest, snare(v, noise), start, 0.32)
            elif note in (42, 44, 46):
                mix(rest, hat(v, noise), start, 0.16)
        elif ch == 1:
            mix(rest, fm_bass(midi_hz(note), length, v), start, 0.36)
        else:
            mix(lead, fm_brass(midi_hz(note), length, v), start, 0.3)
    # The SNES-style echo on the melody: a feedback delay, mixed back under it.
    delay, feedback, wet = int(0.19 * RATE), 0.35, 0.3
    echo = [0.0] * total
    for i in range(delay, total):
        echo[i] = lead[i - delay] + echo[i - delay] * feedback
    out = [lead[i] + wet * echo[i] + rest[i] for i in range(total)]
    # Trim to the last bar's end so the loop meets itself, then normalise.
    out = out[: int(end * RATE)] or out
    peak = max(1e-9, max(abs(x) for x in out))
    out = [x * 0.89 / peak for x in out]
    write_wav(wav_path, out, RATE)
    print("wrote %s, %.1f s, %d notes" % (wav_path, len(out) / RATE, len(notes)))


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] not in ("transcribe", "render"):
        sys.exit(__doc__)
    (transcribe if sys.argv[1] == "transcribe" else render)(sys.argv[2], sys.argv[3])
