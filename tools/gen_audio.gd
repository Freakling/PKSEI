extends SceneTree
## Audio generator · synthesises the sound effects in assets/audio/ as short 16-bit mono
## 22050 Hz WAVs (GDD › Presentation and Platforms: a bit retro, lots of comedy; stroke, splash
## and guy noises). Kept here so the sounds are reproducible and tweakable in code; the human
## reviews the result like any other asset. The hazard telegraph sounds are T26's, not here.
##
## Run from the project root:
##   godot --headless --path . -s tools/gen_audio.gd
## Godot writes a .import next to each WAV on the next import pass (bash tools/check.sh).
##
## Each sound is a function that renders float samples in -1..1 by mixing tones (_tone) and
## filtered noise (_noise) into a blank buffer; _save normalises it to PEAK and writes it with
## AudioStreamWAV.save_to_wav(). The noise comes from a seeded RNG, so a run gives the same
## bytes again.

const OUT_DIR: String = "res://assets/audio"
const RATE: int = 22050
const PEAK: float = 0.8
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
		var value: float = 0.0
		match wave:
			Wave.SINE:
				value = sin(TAU * phase)
			Wave.TRIANGLE:
				value = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SQUARE:
				value = 1.0 if phase < 0.5 else -1.0
		samples[i] = value * _envelope(t, attack, decay)
	return samples


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


## The one-pole lowpass coefficient for a cutoff of `hz` at RATE.
func _coefficient(hz: float) -> float:
	return 1.0 - exp(-TAU * hz / RATE)


# --- output -------------------------------------------------------------------------------------

## Normalises `samples` to PEAK, packs them as PCM16 and writes OUT_DIR/<sound_name>.wav.
func _save(samples: PackedFloat32Array, sound_name: String) -> void:
	var peak: float = 0.0
	for sample: float in samples:
		peak = maxf(peak, absf(sample))
	var gain: float = PEAK / peak if peak > 0.0 else 0.0
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(roundf(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0)))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	var path: String = OUT_DIR.path_join(sound_name + ".wav")
	var err: Error = stream.save_to_wav(path)
	print("%s %s (%.2f s, %d bytes)" % ["wrote" if err == OK else "FAILED", path, float(samples.size()) / RATE, data.size() + 44])
