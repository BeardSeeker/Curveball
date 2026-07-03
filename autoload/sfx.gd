extends Node

## Procedural sound effects: every stream is synthesized into an in-memory
## AudioStreamWAV at startup, so there are zero audio assets to import. When
## real SFX assets arrive, swap the entries in `_streams` for loaded files and
## everything else stays the same. Play with `Sfx.play("hit")`.

const MIX_RATE := 22050
const POOL_SIZE := 8
const BASE_VOLUME_DB := -8.0

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	_streams = {
		# Correct bar hit: short bright blip (pitch is raised per rally hit).
		"hit": _render([_tone(0.07, 520.0, 660.0, "square", 0.5, 22.0)]),
		# Wrong-bar touch: low harsh buzz.
		"foul": _render([_tone(0.2, 160.0, 110.0, "square", 0.5, 8.0)]),
		# Power-up collected: two-note chime up.
		"pickup": _render([
			_tone(0.09, 660.0, 660.0, "sine", 0.5, 6.0),
			_tone(0.12, 990.0, 990.0, "sine", 0.5, 8.0),
		]),
		# Power-up activated: rising sweep.
		"activate": _render([_tone(0.16, 300.0, 900.0, "saw", 0.4, 6.0)]),
		# Charger pad: quick zap.
		"charge": _render([_tone(0.09, 200.0, 1200.0, "saw", 0.4, 10.0)]),
		# Life lost: long falling sweep.
		"life_lost": _render([_tone(0.35, 420.0, 130.0, "saw", 0.5, 5.0)]),
		# Countdown tick and the launch note.
		"count": _render([_tone(0.05, 1000.0, 1000.0, "sine", 0.5, 25.0)]),
		"go": _render([_tone(0.15, 880.0, 1320.0, "sine", 0.55, 9.0)]),
		# Match over: little ascending jingle.
		"win": _render([
			_tone(0.12, 523.0, 523.0, "sine", 0.5, 5.0),
			_tone(0.12, 659.0, 659.0, "sine", 0.5, 5.0),
			_tone(0.22, 784.0, 784.0, "sine", 0.5, 6.0),
		]),
	}
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = BASE_VOLUME_DB
		add_child(p)
		_players.append(p)


## Fire-and-forget playback; `pitch` lets callers add variation (e.g. rally
## hits creep upward). Rotates through a small player pool so overlapping
## sounds don't cut each other off.
func play(sound: String, pitch := 1.0) -> void:
	if not _streams.has(sound):
		push_warning("Sfx: unknown sound '%s'" % sound)
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.play()


# --- Synthesis ----------------------------------------------------------------

## Render mono 16-bit PCM segments into one playable stream.
func _render(segments: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for seg in segments:
		data.append_array(seg)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## One tone sweeping f0 -> f1 over `duration` seconds with an exponential
## decay envelope. `kind`: sine / square / saw.
func _tone(duration: float, f0: float, f1: float, kind: String, volume: float,
		decay: float) -> PackedByteArray:
	var count := int(duration * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var freq := lerpf(f0, f1, t / duration)
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		var s: float
		match kind:
			"square":
				s = 1.0 if phase < 0.5 else -1.0
			"saw":
				s = 2.0 * phase - 1.0
			_:
				s = sin(phase * TAU)
		s *= volume * exp(-decay * t)
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return bytes
