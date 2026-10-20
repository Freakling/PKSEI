"""song_styles · the director's song in five retro gaming styles, each with and without the vocals.

Pure Python 3, no packages. It keeps the real recording, so the song stays the song, and runs it
through a different retro chain per style:

    python -I tools/song_styles.py <stereo source.wav> <out folder>

The source is a stereo WAV, 16-bit PCM or 32-bit float, any rate. "Without vocals" is the karaoke
trick: the left channel minus the right cancels whatever is panned to the middle (the lead vocal),
and the middle's low end (under about 160 Hz: the bass and the kick) is added back. Every version is
written as 16-bit mono PCM at 22050 Hz, peak-normalised, named <style>_vocals.wav and
<style>_instrumental.wav:

    nes        8-bit console: 5-bit samples, held at 11 kHz so it aliases, driven a little
    gameboy    handheld: band-limited 150 Hz to 3.5 kHz, 4-bit samples held at 8 kHz
    snes       16-bit console: the soft sample interpolation (a low-pass), 12-bit, the echo
    megadrive  16-bit console: an 11 kHz low-pass, a gritty soft-clip, a 9-bit DAC
    outrun     modern retro (synthwave): tape wobble, warmth, a big 80s reverb

The out folder should be one Godot doesn't import (playtesting/ has a .gdignore); the pick that
goes into the game is copied to assets/audio/music/ by hand.
"""
import array, math, os, struct, sys

RATE = 22050

# --- input and output -------------------------------------------------------------------------

def read_stereo(path):
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
    if tag == 0xFFFE:
        tag = 3 if bits == 32 else 1
    if tag == 3 and bits == 32:
        s = array.array("f")
        s.frombytes(pcm[: len(pcm) - len(pcm) % 4])
        if sys.byteorder != "little":
            s.byteswap()
    elif tag == 1 and bits == 16:
        raw = array.array("h")
        raw.frombytes(pcm[: len(pcm) - len(pcm) % 2])
        if sys.byteorder != "little":
            raw.byteswap()
        s = array.array("f", (v / 32768.0 for v in raw))
    else:
        sys.exit("the source must be 16-bit PCM or 32-bit float")
    # Arrays, not lists, until the rate is down: a three-minute song is millions of samples.
    if channels == 1:
        left = right = s
    else:
        left, right = s[0::channels], s[1::channels]
    # Down to about 22 kHz by averaging blocks.
    factor = max(1, int(round(rate / RATE)))
    n = len(left) // factor
    left = [sum(left[i * factor:(i + 1) * factor]) / factor for i in range(n)]
    right = [sum(right[i * factor:(i + 1) * factor]) / factor for i in range(n)]
    return left, right, rate / factor


def write_mono(path, samples):
    peak = max(1e-9, max(abs(v) for v in samples))
    g = 0.89 / peak
    out = array.array("h", (max(-32767, min(32767, int(v * g * 32767))) for v in samples))
    if sys.byteorder != "little":
        out.byteswap()
    pcm = out.tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(pcm)) + pcm)
    print("wrote", path)

# --- building blocks ------------------------------------------------------------------------------

def lowpass(x, hz):
    a = 1.0 - math.exp(-2 * math.pi * hz / RATE)
    y, out = 0.0, [0.0] * len(x)
    for i, v in enumerate(x):
        y += a * (v - y)
        out[i] = y
    return out


def highpass(x, hz):
    lp = lowpass(x, hz)
    return [v - l for v, l in zip(x, lp)]


def hold(x, hz):
    """Sample-and-hold at a lower rate, without a filter first: the aliasing old hardware had."""
    step = RATE / hz
    out, held, next_t = [0.0] * len(x), 0.0, 0.0
    for i, v in enumerate(x):
        if i >= next_t:
            held = v
            next_t += step
        out[i] = held
    return out


def crush(x, bits):
    levels = 2 ** (bits - 1)
    return [round(v * levels) / levels for v in x]


def drive(x, amount):
    k = math.tanh(amount)
    return [math.tanh(v * amount) / k for v in x]


def normalise(x, peak=0.9):
    p = max(1e-9, max(abs(v) for v in x))
    return [v * peak / p for v in x]


def echo(x, seconds, feedback, wet, tone_hz):
    d = int(seconds * RATE)
    buf, out = [0.0] * len(x), [0.0] * len(x)
    a = 1.0 - math.exp(-2 * math.pi * tone_hz / RATE)
    lp = 0.0
    for i, v in enumerate(x):
        delayed = buf[i - d] if i >= d else 0.0
        lp += a * (delayed - lp)          # each repeat a little darker, as the SNES's FIR does
        buf[i] = v + lp * feedback
        out[i] = v + wet * lp
    return out


def reverb(x, wet):
    """A small Schroeder reverb: four combs into two all-passes."""
    def comb(sig, ms, fb):
        d = int(ms * RATE / 1000)
        buf, out = [0.0] * len(sig), [0.0] * len(sig)
        for i, v in enumerate(sig):
            y = buf[i - d] if i >= d else 0.0
            buf[i] = v + y * fb
            out[i] = y
        return out
    def allpass(sig, ms, g):
        d = int(ms * RATE / 1000)
        buf, out = [0.0] * len(sig), [0.0] * len(sig)
        for i, v in enumerate(sig):
            y = buf[i - d] if i >= d else 0.0
            buf[i] = v + y * g
            out[i] = y - g * buf[i]
        return out
    combs = [comb(x, ms, fb) for ms, fb in ((29.7, 0.80), (37.1, 0.79), (41.1, 0.78), (43.7, 0.77))]
    mixed = [sum(c[i] for c in combs) * 0.25 for i in range(len(x))]
    mixed = allpass(allpass(mixed, 5.0, 0.7), 1.7, 0.7)
    return [v + wet * r for v, r in zip(x, mixed)]


def wobble(x, depth_ms, rate_hz):
    """Tape wow: a slowly varying delay, read with linear interpolation."""
    out = [0.0] * len(x)
    base = depth_ms * RATE / 1000 * 2
    for i in range(len(x)):
        d = base + depth_ms * RATE / 1000 * math.sin(2 * math.pi * rate_hz * i / RATE)
        p = i - d
        j = int(p)
        if j < 0 or j + 1 >= len(x):
            continue
        f = p - j
        out[i] = x[j] * (1 - f) + x[j + 1] * f
    return out

# --- the styles ------------------------------------------------------------------------------------

def nes(x):
    x = highpass(x, 90)
    x = drive(x, 1.8)
    x = hold(x, 11025)
    return crush(normalise(x), 5)


def gameboy(x):
    x = highpass(lowpass(x, 3500), 150)
    x = drive(normalise(x), 2.5)
    x = hold(x, 8192)
    return crush(normalise(x), 4)


def snes(x):
    x = lowpass(lowpass(x, 9000), 9000)
    x = crush(normalise(x), 12)
    return echo(x, 0.24, 0.42, 0.35, 3500)


def megadrive(x):
    x = lowpass(x, 11000)
    x = drive(normalise(x), 2.2)
    x = hold(x, 13300)
    return crush(normalise(x), 9)


def outrun(x):
    x = wobble(x, 1.2, 0.6)
    x = lowpass(x, 9000)
    x = drive(normalise(x), 1.3)
    return reverb(x, 0.35)


STYLES = [("nes", nes), ("gameboy", gameboy), ("snes", snes), ("megadrive", megadrive), ("outrun", outrun)]


def main(src, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    left, right, rate = read_stereo(src)
    print("source at %d Hz, %.1f s" % (rate, len(left) / RATE))
    with_vocals = [(l + r) * 0.5 for l, r in zip(left, right)]
    low_mid = lowpass(lowpass(with_vocals, 160), 160)
    instrumental = [(l - r) * 0.5 + lm for l, r, lm in zip(left, right, low_mid)]
    for name, style in STYLES:
        write_mono(os.path.join(out_dir, name + "_vocals.wav"), style(with_vocals))
        write_mono(os.path.join(out_dir, name + "_instrumental.wav"), style(instrumental))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
