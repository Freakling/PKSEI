extends SceneTree
## Audio generator · synthesises the sound effects in assets/audio/ as short 16-bit mono
## 22050 Hz WAVs (GDD › Presentation and Platforms: a bit retro, lots of comedy; stroke, splash
## and guy noises) and the hazard telegraphs in assets/audio/hazards/ (T26: the motorboat's
## engine, the jet-ski's whine, the geese's hiss, the wind rising, the whitecaps' wind, the
## beast's rumble and its grab; the ones that run while the hazard does are loops). Kept here
## so the sounds are reproducible and tweakable in code; the human reviews the result like any
## other asset.
##
## Run from the project root:
##   godot --headless --path . -s tools/gen_audio.gd
## Godot writes a .import next to each WAV on the next import pass (bash tools/check.sh).
##
## Each sound is a function that renders float samples in -1..1 by mixing tones (_tone) and
## filtered noise (_noise) into a blank buffer; _save normalises it to PEAK and writes it as a
## plain PCM WAV (_wav: the bytes AudioStreamWAV.save_to_wav() writes), with a `smpl` chunk
## holding one forward loop over the whole sound for the loops, which Godot's WAV importer reads
## ("Detect From WAV", its default), so the stream loops as loaded. A loop is built from steady
## parts (_hum, _wash, _throb) with a whole number of cycles over its length and its noise's
## tail crossfaded into its head (_seamless), so it repeats without a click. The noise comes
## from a seeded RNG, so a run gives the same bytes again; new sounds go last, so the sequence
## the earlier ones draw from stays as it was.

const OUT_DIR: String = "res://assets/audio"
const HAZARD_DIR: String = "res://assets/audio/hazards"
const RATE: int = 22050
const PEAK: float = 0.8
## Seconds of a loop's noise tail crossfaded into its head (_seamless).
const SEAM: float = 0.05
## A decay this long is no decay: the loops' gliding tones hold their level.
const FLAT: float = 1.0e6
## Pitch of each guy's grunt in Paddling.Seat order (LF, LB, RF, RB): a tenor, a baritone, a
## bass and a squeaky one, so the four are told apart by ear.
const GRUNT_PITCHES: Array[float] = [150.0, 115.0, 90.0, 200.0]

enum Wave { SINE, TRIANGLE, SQUARE }

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 2026
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_save(_stroke(), "stroke")
	_save(_fumble(), "fumble")
	_save(_splash(), "splash")
	_save(_pickup(), "pickup")
	_save(_beer_over(), "beer_over")
	for seat: int in GRUNT_PITCHES.size():
		_save(_grunt(GRUNT_PITCHES[seat]), "guy_grunt_%d" % seat)
	# It uses no noise, so the RNG's sequence for the sounds above stays as it was.
	_save(_cheer(), "cheer")
	# The hazard telegraphs (T26), after everything above for the same reason.
	DirAccess.make_dir_recursive_absolute(HAZARD_DIR)
	_save(_engine(), "engine", HAZARD_DIR, true)
	_save(_jetski(), "jetski", HAZARD_DIR, true)
	_save(_geese_hiss(), "geese_hiss", HAZARD_DIR)
	_save(_wind_rise(), "wind_rise", HAZARD_DIR)
	_save(_whitecaps(), "whitecaps", HAZARD_DIR, true)
	_save(_beast_rumble(), "beast_rumble", HAZARD_DIR, true)
	_save(_beast_grab(), "beast_grab", HAZARD_DIR)
	quit()


# --- the sounds ---------------------------------------------------------------------------------

## A short water swoosh: a noise burst whose cutoff sweeps up as the blade goes in, then a
## softer tail sweeping back down as the water closes.
func _stroke() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(0.3)
	_mix(sound, 0.0, _noise(0.2, 400.0, 3200.0, 0.07, 0.08), 1.0)
	_mix(sound, 0.12, _noise(0.18, 2600.0, 500.0, 0.02, 0.06), 0.6)
	return sound


## A clumsy plop: a dull thud dropping in pitch, a tick, then the small rising bloop of a drop.
func _fumble() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(0.3)
	_mix(sound, 0.0, _tone(0.12, 420.0, 90.0, Wave.SINE, 0.004, 0.05), 1.0)
	_mix(sound, 0.0, _noise(0.06, 2000.0, 800.0, 0.003, 0.015), 0.5)
	_mix(sound, 0.1, _tone(0.18, 300.0, 900.0, Wave.SINE, 0.01, 0.06), 0.7)
	return sound


## A jump: a bigger noise burst darkening as it dies, over a low thump as he hits the water.
func _splash() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(0.5)
	_mix(sound, 0.0, _tone(0.2, 110.0, 40.0, Wave.SINE, 0.005, 0.07), 1.0)
	_mix(sound, 0.0, _noise(0.5, 5000.0, 700.0, 0.012, 0.14), 0.9)
	return sound


## A cheerful two-note blip: a fifth up on a square wave.
func _pickup() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(0.26)
	_mix(sound, 0.0, _tone(0.11, 660.0, 660.0, Wave.SQUARE, 0.005, 0.08), 0.35)
	_mix(sound, 0.1, _tone(0.16, 990.0, 990.0, Wave.SQUARE, 0.005, 0.1), 0.35)
	return sound


## A beer overboard: the clink of the can (two inharmonic partials), then a small splash.
func _beer_over() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(0.45)
	_mix(sound, 0.0, _tone(0.15, 2500.0, 2500.0, Wave.SINE, 0.002, 0.04), 0.5)
	_mix(sound, 0.0, _tone(0.15, 3700.0, 3700.0, Wave.SINE, 0.002, 0.03), 0.3)
	_mix(sound, 0.15, _noise(0.3, 2500.0, 500.0, 0.01, 0.07), 0.7)
	_mix(sound, 0.15, _tone(0.12, 400.0, 700.0, Wave.SINE, 0.01, 0.05), 0.3)
	return sound


## A short vowel-ish grunt at `hz`: a square and a triangle together, the pitch sagging as the
## breath goes, softened by a lowpass at the sixth harmonic.
func _grunt(hz: float) -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(0.2)
	_mix(sound, 0.0, _tone(0.2, hz * 1.1, hz * 0.85, Wave.SQUARE, 0.015, 0.09), 0.5)
	_mix(sound, 0.0, _tone(0.2, hz * 1.1, hz * 0.85, Wave.TRIANGLE, 0.015, 0.09), 0.5)
	return _lowpass(sound, hz * 6.0)


## The boys' cheer as they land (the win cutscene, T28): a rising major arpeggio on a square
## wave with a triangle an octave under it, the top note held.
func _cheer() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(0.8)
	var notes: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	for i: int in notes.size():
		var last: bool = i == notes.size() - 1
		var length: float = 0.45 if last else 0.14
		var decay: float = 0.2 if last else 0.08
		_mix(sound, 0.1 * i, _tone(length, notes[i], notes[i], Wave.SQUARE, 0.005, decay), 0.3)
		_mix(sound, 0.1 * i, _tone(length, notes[i] * 0.5, notes[i] * 0.5, Wave.TRIANGLE, 0.005, decay), 0.4)
	return sound


# --- the hazard telegraphs (T26) ----------------------------------------------------------------

## The motorboat's engine, heard before its wake (a 1.5 s loop): a low square with its octave,
## muffled, over a low wash of exhaust, the whole chugging eight times a second.
func _engine() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(1.5)
	_mix(sound, 0.0, _lowpass_loop(_hum(1.5, 48.0, Wave.SQUARE), 260.0), 0.8)
	_mix(sound, 0.0, _hum(1.5, 96.0, Wave.TRIANGLE), 0.35)
	_mix(sound, 0.0, _seamless(_wash(1.5 + SEAM, 500.0), 1.5), 0.5)
	return _throb(sound, 8.0, 0.75)


## The jet-ski, loud from offscreen (a 1.2 s loop): a higher whine (a square and a triangle an
## octave up) revving up over each loop and dropping back, as it bounces over the waves, with
## its spray hissing under it.
func _jetski() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(1.2 + SEAM)
	_mix(sound, 0.0, _tone(1.2 + SEAM, 170.0, 240.0, Wave.SQUARE, 0.01, FLAT), 0.5)
	_mix(sound, 0.0, _tone(1.2 + SEAM, 340.0, 480.0, Wave.TRIANGLE, 0.01, FLAT), 0.5)
	_mix(sound, 0.0, _wash(1.2 + SEAM, 2500.0), 0.35)
	return _seamless(_lowpass_loop(sound, 1800.0), 1.2)


## The geese, hissing as the boat nears them: a bright hiss, then two honks (a square and a
## triangle sagging in pitch, muffled) on top of it.
func _geese_hiss() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(1.0)
	_mix(sound, 0.0, _noise(0.8, 2500.0, 6000.0, 0.08, 0.35), 0.8)
	_mix(sound, 0.45, _honk(0.22, 330.0, 270.0), 0.9)
	_mix(sound, 0.72, _honk(0.2, 300.0, 250.0), 0.8)
	return sound


## One goose honk of `seconds` gliding from `from_hz` to `to_hz`.
func _honk(seconds: float, from_hz: float, to_hz: float) -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(seconds)
	_mix(sound, 0.0, _lowpass(_tone(seconds, from_hz, to_hz, Wave.SQUARE, 0.02, 0.12), 1500.0), 0.5)
	_mix(sound, 0.0, _tone(seconds, from_hz, to_hz, Wave.TRIANGLE, 0.02, 0.12), 0.4)
	return sound


## The wind rising before a gust: a wash that swells over a second while its cutoff opens up,
## then falls away, with a faint whistle climbing under it.
func _wind_rise() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(1.5)
	_mix(sound, 0.0, _noise(1.5, 250.0, 2200.0, 1.0, 1.4), 1.0)
	_mix(sound, 0.0, _tone(1.5, 180.0, 520.0, Wave.SINE, 0.9, 1.0), 0.2)
	return sound


## The harsh wind over the whitecaps (a 1.5 s loop): a steady wash gusting slowly, with a
## brighter wash gusting against it.
func _whitecaps() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(1.5)
	_mix(sound, 0.0, _throb(_seamless(_wash(1.5 + SEAM, 700.0), 1.5), 1.33, 0.5), 1.0)
	_mix(sound, 0.0, _throb(_seamless(_wash(1.5 + SEAM, 2000.0), 1.5), 2.0, 0.6), 0.35)
	return sound


## The beast circling (a 1.5 s loop): a low sine with a muffled square a fifth up over a deep
## wash, the whole heaving twice a second.
func _beast_rumble() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(1.5)
	_mix(sound, 0.0, _hum(1.5, 36.0, Wave.SINE), 0.8)
	_mix(sound, 0.0, _lowpass_loop(_hum(1.5, 54.0, Wave.SQUARE), 110.0), 0.5)
	_mix(sound, 0.0, _seamless(_wash(1.5 + SEAM, 140.0), 1.5), 0.6)
	return _throb(sound, 2.0, 0.5)


## The beast's grab: two snaps of its jaws, each a noise bite over a low thud, then the splash
## of the dive (the jumper's splash, bigger).
func _beast_grab() -> PackedFloat32Array:
	var sound: PackedFloat32Array = _blank(0.8)
	_mix(sound, 0.0, _noise(0.1, 1800.0, 300.0, 0.003, 0.03), 0.8)
	_mix(sound, 0.0, _tone(0.18, 160.0, 55.0, Wave.SINE, 0.004, 0.06), 1.0)
	_mix(sound, 0.1, _noise(0.08, 1200.0, 200.0, 0.003, 0.025), 0.6)
	_mix(sound, 0.1, _tone(0.15, 120.0, 45.0, Wave.SINE, 0.004, 0.05), 0.8)
	_mix(sound, 0.28, _tone(0.2, 110.0, 40.0, Wave.SINE, 0.005, 0.07), 0.8)
	_mix(sound, 0.28, _noise(0.5, 5000.0, 700.0, 0.012, 0.14), 0.9)
	return sound


# --- synthesis ----------------------------------------------------------------------------------

## `seconds` of silence.
func _blank(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


## Adds `part` at `gain` into `into`, starting `at` seconds in; what runs past the end is cut.
func _mix(into: PackedFloat32Array, at: float, part: PackedFloat32Array, gain: float) -> void:
	var offset: int = int(at * RATE)
	for i: int in part.size():
		var index: int = offset + i
		if index < into.size():
			into[index] += part[i] * gain


## A quick linear attack of `attack` seconds, then an exponential decay with time constant
## `decay`.
func _envelope(t: float, attack: float, decay: float) -> float:
	return minf(t / attack, 1.0) * exp(-t / decay)


## A tone of `wave` gliding (exponentially) from `from_hz` to `to_hz` over `seconds`, shaped by
## _envelope.
func _tone(seconds: float, from_hz: float, to_hz: float, wave: Wave, attack: float, decay: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _blank(seconds)
	var phase: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / RATE
		var hz: float = from_hz * pow(to_hz / from_hz, t / seconds)
		phase = fmod(phase + hz / RATE, 1.0)
		samples[i] = _shape(phase, wave) * _envelope(t, attack, decay)
	return samples


## `wave`'s value at `phase` (0..1 over one cycle).
func _shape(phase: float, wave: Wave) -> float:
	match wave:
		Wave.SINE:
			return sin(TAU * phase)
		Wave.TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		Wave.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
	return 0.0


## A steady tone of `wave` near `hz` for `seconds` with no envelope, its pitch nudged so a whole
## number of cycles fits, so it loops without a click.
func _hum(seconds: float, hz: float, wave: Wave) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _blank(seconds)
	var cycles: float = maxf(roundf(hz * seconds), 1.0)
	for i: int in samples.size():
		samples[i] = _shape(fmod(cycles * float(i) / samples.size(), 1.0), wave)
	return samples


## White noise through a one-pole lowpass at `hz` for `seconds` with no envelope: a steady wash.
func _wash(seconds: float, hz: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _blank(seconds)
	var a: float = _coefficient(hz)
	var y: float = 0.0
	for i: int in samples.size():
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		samples[i] = y
	return samples


## `samples` cut to `seconds`, the part cut off crossfaded into the head, so the loop's seam
## doesn't click.
func _seamless(samples: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = _blank(seconds)
	var fade: int = samples.size() - out.size()
	for i: int in out.size():
		out[i] = samples[i]
	for i: int in fade:
		var weight: float = float(i) / fade
		out[i] = samples[i] * weight + samples[out.size() + i] * (1.0 - weight)
	return out


## `samples` throbbing: its gain swings between 1 - `depth` and 1 near `hz`, a whole number of
## times over the length, so it loops.
func _throb(samples: PackedFloat32Array, hz: float, depth: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = samples.duplicate()
	var cycles: float = maxf(roundf(hz * samples.size() / RATE), 1.0)
	for i: int in out.size():
		out[i] *= 1.0 - depth * (0.5 + 0.5 * cos(TAU * cycles * i / out.size()))
	return out


## White noise through a one-pole lowpass whose cutoff sweeps from `from_hz` to `to_hz` over
## `seconds`, shaped by _envelope.
func _noise(seconds: float, from_hz: float, to_hz: float, attack: float, decay: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _blank(seconds)
	var y: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / RATE
		var cutoff: float = lerpf(from_hz, to_hz, t / seconds)
		y += _coefficient(cutoff) * (_rng.randf_range(-1.0, 1.0) - y)
		samples[i] = y * _envelope(t, attack, decay)
	return samples


## `samples` through a one-pole lowpass at `hz`.
func _lowpass(samples: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = _blank(float(samples.size()) / RATE)
	var a: float = _coefficient(hz)
	var y: float = 0.0
	for i: int in samples.size():
		y += a * (samples[i] - y)
		out[i] = y
	return out


## _lowpass for a loop: the filter runs over `samples` once first, so its state at the head is
## the one it has at the tail and the seam doesn't thump.
func _lowpass_loop(samples: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = _blank(float(samples.size()) / RATE)
	var a: float = _coefficient(hz)
	var y: float = 0.0
	for _run: int in 2:
		for i: int in samples.size():
			y += a * (samples[i] - y)
			out[i] = y
	return out


## The one-pole lowpass coefficient for a cutoff of `hz` at RATE.
func _coefficient(hz: float) -> float:
	return 1.0 - exp(-TAU * hz / RATE)


# --- output -------------------------------------------------------------------------------------

## Normalises `samples` to PEAK, packs them as PCM16 and writes `dir`/<sound_name>.wav, with a
## forward loop over the whole sound when `loop` is set.
func _save(samples: PackedFloat32Array, sound_name: String, dir: String = OUT_DIR, loop: bool = false) -> void:
	var peak: float = 0.0
	for sample: float in samples:
		peak = maxf(peak, absf(sample))
	var gain: float = PEAK / peak if peak > 0.0 else 0.0
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(roundf(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0)))
	var bytes: PackedByteArray = _wav(data, samples.size() if loop else 0)
	var path: String = dir.path_join(sound_name + ".wav")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var ok: bool = file != null and file.store_buffer(bytes)
	print("%s %s (%.2f s, %d bytes%s)" % ["wrote" if ok else "FAILED", path, float(samples.size()) / RATE, bytes.size(), ", loop" if loop else ""])


## The WAV file for PCM16 mono `data` at RATE: the RIFF, fmt and data chunks exactly as
## AudioStreamWAV.save_to_wav() writes them, then, when `loop_frames` is more than 0, a `smpl`
## chunk with one forward loop from frame 0 to `loop_frames`, which the importer's "Detect From
## WAV" loop mode reads into the stream's loop_mode, loop_begin and loop_end.
func _wav(data: PackedByteArray, loop_frames: int) -> PackedByteArray:
	var smpl: PackedByteArray = PackedByteArray()
	if loop_frames > 0:
		_chunk(smpl, "smpl", 60)
		# Manufacturer, product, the sample period in nanoseconds, MIDI unity note and pitch
		# fraction, SMPTE format and offset, one loop, no sampler data.
		for value: int in [0, 0, int(1.0e9 / RATE), 60, 0, 0, 0, 1, 0]:
			_u32(smpl, value)
		# The loop: cue id, forward, start, end, no fraction, plays forever.
		for value: int in [0, 0, 0, loop_frames, 0, 0]:
			_u32(smpl, value)
	var out: PackedByteArray = PackedByteArray()
	_chunk(out, "RIFF", 36 + data.size() + smpl.size())
	out.append_array("WAVE".to_ascii_buffer())
	_chunk(out, "fmt ", 16)
	_u16(out, 1)  # PCM
	_u16(out, 1)  # mono
	_u32(out, RATE)
	_u32(out, RATE * 2)  # bytes per second
	_u16(out, 2)  # bytes per frame
	_u16(out, 16)  # bits per sample
	_chunk(out, "data", data.size())
	out.append_array(data)
	out.append_array(smpl)
	return out


## Appends a chunk header: the four-letter `id` and the chunk's `size` in bytes.
func _chunk(into: PackedByteArray, id: String, size: int) -> void:
	into.append_array(id.to_ascii_buffer())
	_u32(into, size)


func _u32(into: PackedByteArray, value: int) -> void:
	into.resize(into.size() + 4)
	into.encode_u32(into.size() - 4, value)


func _u16(into: PackedByteArray, value: int) -> void:
	into.resize(into.size() + 2)
	into.encode_u16(into.size() - 2, value)
