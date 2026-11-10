class_name AudioSynth
extends Node
# Procedural engine sound, built like the real thing instead of from plain sine tones:
#  1. Combustion: every cylinder fires an exhaust pressure pulse (fast rise, decay over ~1-2 ms).
#     At idle the pulses stand apart ("putt-putt"), at high revs they merge into a tone.
#     Small per-cylinder differences give the lumpy rumble (cross-plane V8, big blocks).
#  2. Exhaust system: two pipe resonances (band-pass) + muffler low-pass + DC blocker.
#  3. Intake roar (noise shaped by the pulses, grows with throttle), diesel knock, supercharger whine.
#  4. Turbo whistle, blow-off valve, tyre squeal and the rev-limiter cut (kept exactly as before).
# Note: this is synthesis, not recordings; per-car profiles are tuned by ear-description.

@export var vehicle: Node3D

var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0
var _turbo_phase: float = 0.0
var _previous_throttle: float = 0.0
var _bov_timer: float = 0.0
var _pop_timer: float = 0.0
var _overrun_timer: float = 0.0
var _smoothed_rpm: float = 900.0
var _smoothed_throttle: float = 0.0
# Turbo / blow-off: smoothed per sample so nothing switches on or off abruptly
var _turbo_gain: float = 0.0
var _turbo_gain_target: float = 0.0
var _turbo_freq_s: float = 400.0
var _turbo_freq_target: float = 400.0
var _hiss_lp: float = 0.0
var _bov_amp: float = 0.0
var _bov_env: float = 0.0
var _bov_attack: float = 0.0
var _bov_cooldown: float = 0.0
var _bov_lp1: float = 0.0
var _bov_lp2: float = 0.0
var _bov_t: float = 0.0
var _burble_lp: float = 0.0
# Upshift backfire bang (the car bumps backfire_count)
var _last_backfire: int = 0
var _bang_t: float = -1.0 # seconds since the bang; < 0 = silent
var _bang: Dictionary = {} # the current car's bang (BANGS)
var _bk: Array = [] # _bang copied into floats once per bang (read every sample)
var _bk_norm: float = 1.0
# Per-car backfire character (petrol cars; diesels never backfire). crack = sharpness of the
# initial crack (s), tone = brightness of the blast (low-pass 0..1), body = blast length (s),
# f0 -> f1 = low thump falling in pitch (Hz), boom = thump strength, pops / gap = repeats
# ("pa-pat", "brap"), level = loudness.
const BANGS: Dictionary = {
	"gtr":        {"crack": 0.003, "tone": 0.35, "body": 0.025, "f0": 110.0, "f1": 55.0, "boom": 0.8, "pops": 2, "gap": 0.07, "level": 0.85}, # twin-turbo V6: sharp double crack
	"challenger": {"crack": 0.004, "tone": 0.15, "body": 0.050, "f0": 80.0, "f1": 35.0, "boom": 1.3, "pops": 1, "gap": 0.0, "level": 0.95}, # supercharged V8: deep single boom
	"raptor":     {"crack": 0.003, "tone": 0.25, "body": 0.035, "f0": 90.0, "f1": 45.0, "boom": 1.0, "pops": 3, "gap": 0.055, "level": 0.9}, # race V8: "brap" triple
	"chiron":     {"crack": 0.005, "tone": 0.12, "body": 0.040, "f0": 70.0, "f1": 40.0, "boom": 1.0, "pops": 1, "gap": 0.0, "level": 0.7}, # quad-turbo W16: heavy, muffled thud
	"supra":      {"crack": 0.002, "tone": 0.50, "body": 0.020, "f0": 130.0, "f1": 60.0, "boom": 0.6, "pops": 2, "gap": 0.09, "level": 0.9}, # 2JZ: bright anti-lag style crackle
	"goliath":    {"crack": 0.006, "tone": 0.10, "body": 0.070, "f0": 60.0, "f1": 28.0, "boom": 1.5, "pops": 1, "gap": 0.0, "level": 1.0}, # big V8 monster: huge cannon
	"accent":     {"crack": 0.0025, "tone": 0.40, "body": 0.015, "f0": 160.0, "f1": 90.0, "boom": 0.4, "pops": 1, "gap": 0.0, "level": 0.45}, # small 1.4: light pop
	"egea":       {"crack": 0.0025, "tone": 0.30, "body": 0.018, "f0": 140.0, "f1": 80.0, "boom": 0.45, "pops": 1, "gap": 0.0, "level": 0.42}, # 1.4 Fire: dull pop
	"civic":      {"crack": 0.002, "tone": 0.55, "body": 0.020, "f0": 150.0, "f1": 75.0, "boom": 0.45, "pops": 2, "gap": 0.05, "level": 0.5}, # VTEC: crisp double tick
	"megane":     {"crack": 0.003, "tone": 0.25, "body": 0.020, "f0": 135.0, "f1": 70.0, "boom": 0.5, "pops": 1, "gap": 0.0, "level": 0.45}, # TCe turbo: muffled pop
	"sahin":      {"crack": 0.004, "tone": 0.30, "body": 0.045, "f0": 100.0, "f1": 50.0, "boom": 0.9, "pops": 1, "gap": 0.0, "level": 0.75}, # carburettor: classic loud "PAT"
	"cup":        {"crack": 0.003, "tone": 0.22, "body": 0.040, "f0": 85.0, "f1": 40.0, "boom": 1.1, "pops": 3, "gap": 0.05, "level": 0.95}, # NASCAR V8: open-header "brap-brap"
	"rzr":        {"crack": 0.002, "tone": 0.50, "body": 0.015, "f0": 170.0, "f1": 95.0, "boom": 0.35, "pops": 2, "gap": 0.045, "level": 0.55}, # UTV 4-cylinder: sharp little crackle
}
const BANG_DEFAULT: Dictionary = {"crack": 0.003, "tone": 0.25, "body": 0.03, "f0": 110.0, "f1": 50.0, "boom": 0.8, "pops": 1, "gap": 0.0, "level": 0.8}
var _bang_lp: float = 0.0
var _bang_ph: float = 0.0
var _skid_gain: float = 0.0
var _skid_lp1: float = 0.0
var _skid_lp2: float = 0.0
var _skid_phase: float = 0.0

# --- Engine model state ---
var _cycle_phase: float = 0.0 # 0..1 over one 4-stroke cycle (720° crank)
var _last_slot: int = -1
var _knock_env: float = 0.0
var _sc_phase: float = 0.0
var _rpm_s: float = 900.0 # per-sample smoothed rpm
var _load_s: float = 0.0 # per-sample smoothed throttle/load
var _noise_lp1: float = 0.0
var _noise_lp2: float = 0.0
var _mlp1: float = 0.0 # muffler low-pass (2 poles)
var _mlp2: float = 0.0
var _dc_x: float = 0.0
var _dc_y: float = 0.0
var _bq: Array = [] # two band-pass biquads: [b0, b2, a1, a2, x1, x2, y1, y2]
var _profile: Dictionary = {}
var _profile_key: String = ""
var _cyl_amp: PackedFloat32Array = PackedFloat32Array()
var _cyl_tau: PackedFloat32Array = PackedFloat32Array()

# Engine sound profiles
#  cyl      cylinders            tau     pulse decay (ms)      irr  per-cylinder unevenness
#  r1,q1,g1 / r2,q2,g2  exhaust resonances (Hz, Q, gain)      lp   muffler cut-off (Hz)
#  rasp     combustion roughness  intake  intake roar          knock diesel clatter
#  whine    supercharger whine    gain    output level         drive saturation
const PROFILES: Dictionary = {
	"gtr":     {"cyl": 6, "tau": 1.1, "irr": 0.10, "r1": 130.0, "q1": 2.2, "g1": 0.9, "r2": 520.0, "q2": 2.5, "g2": 0.55, "lp": 3200.0, "rasp": 0.35, "intake": 0.30, "knock": 0.0, "whine": 0.0, "gain": 0.55, "drive": 2.2},
	"v8_sc":   {"cyl": 8, "tau": 1.5, "irr": 0.32, "r1": 85.0, "q1": 2.0, "g1": 1.3, "r2": 300.0, "q2": 2.2, "g2": 0.60, "lp": 2400.0, "rasp": 0.30, "intake": 0.20, "knock": 0.0, "whine": 0.08, "gain": 0.55, "drive": 2.6},
	"v8_race": {"cyl": 8, "tau": 1.2, "irr": 0.28, "r1": 100.0, "q1": 1.8, "g1": 1.1, "r2": 380.0, "q2": 2.0, "g2": 0.75, "lp": 4200.0, "rasp": 0.55, "intake": 0.35, "knock": 0.0, "whine": 0.0, "gain": 0.52, "drive": 3.0},
	"w16":     {"cyl": 16, "tau": 0.9, "irr": 0.06, "r1": 110.0, "q1": 1.8, "g1": 1.0, "r2": 330.0, "q2": 2.0, "g2": 0.45, "lp": 2900.0, "rasp": 0.15, "intake": 0.25, "knock": 0.0, "whine": 0.0, "gain": 0.62, "drive": 1.8},
	"i6_jz":   {"cyl": 6, "tau": 1.0, "irr": 0.05, "r1": 150.0, "q1": 2.4, "g1": 0.9, "r2": 600.0, "q2": 2.6, "g2": 0.65, "lp": 3800.0, "rasp": 0.40, "intake": 0.30, "knock": 0.0, "whine": 0.0, "gain": 0.52, "drive": 2.3},
	"v8_big":  {"cyl": 8, "tau": 1.8, "irr": 0.38, "r1": 65.0, "q1": 1.8, "g1": 1.4, "r2": 220.0, "q2": 2.0, "g2": 0.60, "lp": 1900.0, "rasp": 0.35, "intake": 0.25, "knock": 0.0, "whine": 0.10, "gain": 0.58, "drive": 2.8},
	"i4":      {"cyl": 4, "tau": 1.2, "irr": 0.06, "r1": 160.0, "q1": 2.0, "g1": 0.8, "r2": 480.0, "q2": 2.4, "g2": 0.45, "lp": 1500.0, "rasp": 0.25, "intake": 0.30, "knock": 0.0, "whine": 0.0, "gain": 0.50, "drive": 1.8},
	"i4_turbo": {"cyl": 4, "tau": 1.1, "irr": 0.06, "r1": 170.0, "q1": 2.0, "g1": 0.8, "r2": 520.0, "q2": 2.4, "g2": 0.50, "lp": 1800.0, "rasp": 0.30, "intake": 0.25, "knock": 0.0, "whine": 0.0, "gain": 0.50, "drive": 1.9},
	"i4_diesel": {"cyl": 4, "tau": 1.6, "irr": 0.08, "r1": 120.0, "q1": 1.8, "g1": 0.9, "r2": 380.0, "q2": 2.0, "g2": 0.40, "lp": 1300.0, "rasp": 0.30, "intake": 0.20, "knock": 0.55, "whine": 0.0, "gain": 0.52, "drive": 1.7},
	# big slow-revving 6-cylinder tractor diesel: deep, heavy knock
	"i6_diesel_big": {"cyl": 6, "tau": 2.0, "irr": 0.10, "r1": 80.0, "q1": 1.6, "g1": 1.1, "r2": 260.0, "q2": 1.8, "g2": 0.45, "lp": 1000.0, "rasp": 0.35, "intake": 0.15, "knock": 0.75, "whine": 0.0, "gain": 0.56, "drive": 1.9},
}
const LEGACY_PROFILE: Array[String] = ["gtr", "v8_sc", "v8_race", "w16", "i6_jz", "v8_big"]

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	if audio_player == null:
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)

	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = sample_rate
	generator.buffer_length = 0.1 # 100ms low latency buffer
	audio_player.stream = generator
	audio_player.play()
	playback = audio_player.get_stream_playback()

func _physics_process(delta: float) -> void:
	if vehicle == null or playback == null:
		return

	_update_profile()
	_smoothed_rpm = lerpf(_smoothed_rpm, vehicle.current_rpm, delta * 25.0)

	# Pedal as the car reads it (rebindable keys + analog gamepad trigger / wheel pedal)
	var current_thr: float = float(vehicle.get("pedal_throttle"))
	_smoothed_throttle = lerpf(_smoothed_throttle, current_thr, delta * 15.0)

	# Blow-off valve: only when real boost pressure is dumped. Its loudness follows the pressure,
	# so quick pumping of the pedal (no boost built up yet) stays quiet instead of hissing every time.
	if _bov_cooldown > 0.0:
		_bov_cooldown -= delta
	if _previous_throttle > 0.5 and current_thr < 0.15:
		_overrun_timer = 0.65 # Exhaust overrun crackles
		if vehicle.turbo_boost_bar > 0.45 and _bov_cooldown <= 0.0:
			_bov_amp = clampf((vehicle.turbo_boost_bar - 0.45) / 1.2, 0.15, 1.0)
			_bov_attack = 1.0
			_bov_t = 0.0
			_bov_cooldown = 0.35
	_previous_throttle = current_thr

	# Turbo whistle targets (smoothed per sample in the buffer fill)
	var is_nitro_now: bool = vehicle.get("turbo_boost_active") == true
	var boost_ratio_now: float = 0.0
	if vehicle.turbo_enabled or is_nitro_now:
		boost_ratio_now = clampf((vehicle.turbo_boost_bar - 0.25) / 1.5, 0.0, 1.0)
	_turbo_gain_target = boost_ratio_now * boost_ratio_now * (0.35 + 0.65 * _smoothed_throttle) * (2.0 if is_nitro_now else 1.0)
	_turbo_freq_target = 380.0 + clampf(vehicle.turbo_boost_bar, 0.0, 2.5) * 240.0

	if _bov_timer > 0.0:
		_bov_timer -= delta
	if _overrun_timer > 0.0:
		_overrun_timer -= delta

	# Preserved Limiter Pop timing
	if (vehicle.is_limiter_active or bool(vehicle.get("limiter_zone"))) and _pop_timer <= 0.0:
		_pop_timer = 0.07 # Rapid pop bursts
	if _pop_timer > 0.0:
		_pop_timer -= delta
	var bf: int = int(vehicle.get("backfire_count")) if vehicle.get("backfire_count") != null else 0
	if bf != _last_backfire:
		_last_backfire = bf
		trigger_bang()

	_fill_audio_buffer()

# Start the current car's backfire bang (BANGS)
func trigger_bang() -> void:
	_bang_t = 0.0
	_bang = BANGS.get(str(CarDatabase.car(int(vehicle.get("current_vehicle_type")))["id"]), BANG_DEFAULT)
	_bk = [float(_bang["crack"]), float(_bang["tone"]), float(_bang["body"]), float(_bang["f0"]), float(_bang["f1"]),
		float(_bang["boom"]), float(_bang["pops"]), float(_bang["gap"]), float(_bang["level"])]
	# low-passed noise gets quieter the darker the tone: scale it back to the same loudness
	_bk_norm = sqrt((0.25 / 1.75) / (float(_bk[1]) / (2.0 - float(_bk[1]))))

# Pick the profile for the current car/engine and prepare its filters
func _update_profile() -> void:
	var v_type: int = int(vehicle.get("current_vehicle_type")) if vehicle.get("current_vehicle_type") != null else 0
	var key: String
	var own: String = str(vehicle.get("engine_sound")) if vehicle.get("engine_sound") != null else ""
	if PROFILES.has(own):
		key = own # the car names its own sound (CarDatabase "sound")
	elif v_type < LEGACY_PROFILE.size() and int(vehicle.get("current_engine_index")) == 0:
		key = LEGACY_PROFILE[v_type]
	elif str(vehicle.get("engine_fuel")) == "dizel":
		key = "i4_diesel"
	elif int(vehicle.get("engine_cylinders")) >= 6:
		key = "i6_jz"
	else:
		key = "i4_turbo" if bool(vehicle.get("turbo_enabled")) else "i4"
	if key == _profile_key:
		return
	_profile_key = key
	_profile = PROFILES[key]
	_bq = [_bandpass(float(_profile["r1"]), float(_profile["q1"])), _bandpass(float(_profile["r2"]), float(_profile["q2"]))]
	# Fixed per-engine cylinder character (seeded so a car always sounds the same)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var n: int = int(_profile["cyl"])
	_cyl_amp.resize(n)
	_cyl_tau.resize(n)
	var irr: float = float(_profile["irr"])
	for i in range(n):
		# cross-plane V8 style: one bank a bit stronger than the other, plus random spread
		var bank: float = (0.5 if (i % 2 == 0) else -0.5) * irr if n == 8 else 0.0
		_cyl_amp[i] = 1.0 + bank + rng.randf_range(-irr, irr) * 0.6
		_cyl_tau[i] = 1.0 + rng.randf_range(-irr, irr) * 0.5

# RBJ band-pass biquad (constant 0 dB peak gain): [b0, b2, a1, a2, x1, x2, y1, y2]
func _bandpass(f: float, q: float) -> Array:
	var w0: float = TAU * f / sample_rate
	var alpha: float = sin(w0) / (2.0 * q)
	var a0: float = 1.0 + alpha
	return [alpha / a0, -alpha / a0, -2.0 * cos(w0) / a0, (1.0 - alpha) / a0, 0.0, 0.0, 0.0, 0.0]

func _fill_audio_buffer() -> void:
	if playback == null or vehicle == null:
		return
	var frames_available: int = playback.get_frames_available()
	if frames_available <= 0:
		return
	playback.push_buffer(generate(frames_available))

# Produces `frames_available` stereo samples from the car's current state (also used by tests
# to render WAV previews).
func generate(frames_available: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if _profile.is_empty():
		_update_profile()
	out.resize(frames_available)
	var p: Dictionary = _profile
	var n_cyl: int = int(p["cyl"])
	var tau_base: float = float(p["tau"]) * 0.001
	var rasp: float = float(p["rasp"])
	var intake: float = float(p["intake"])
	var knock: float = float(p["knock"])
	var whine: float = float(p["whine"])
	var g1: float = float(p["g1"])
	var g2: float = float(p["g2"])
	var gain: float = float(p["gain"])
	var drive: float = float(p["drive"])
	var lp_a: float = 1.0 - exp(-TAU * float(p["lp"]) / sample_rate)
	var dt: float = 1.0 / sample_rate
	var bq1: Array = _bq[0]
	var bq2: Array = _bq[1]
	var target_rpm: float = maxf(_smoothed_rpm, 300.0)
	var target_load: float = _smoothed_throttle
	# On the limiter (or held right at it, e.g. top speed in top gear) it always sounds like the
	# limiter bouncing - no switching between "limiter" and "max revs" sounds.
	var limiter: bool = vehicle.is_limiter_active or bool(vehicle.get("limiter_zone"))

	# Tire Skid
	var max_slip: float = 0.0
	for i in range(4):
		max_slip = maxf(max_slip, absf(vehicle.wheel_slip_lateral[i]))
	var is_skidding: bool = max_slip > 0.28 and vehicle.current_speed_kmh > 12.0
	var skid_target: float = clampf((max_slip - 0.28) * 1.6, 0.0, 1.0)
	var is_nitro: bool = vehicle.get("turbo_boost_active") == true

	for i in range(frames_available):
		# smooth rpm & load per sample (no zipper noise when the revs jump)
		_rpm_s += (target_rpm - _rpm_s) * 0.002
		_load_s += (target_load - _load_s) * 0.0008
		var load: float = _load_s

		# --- 1. Combustion pulses ---
		var cycle_hz: float = _rpm_s / 120.0 # one 4-stroke cycle = 2 crank revolutions
		_cycle_phase += cycle_hz * dt
		if _cycle_phase >= 1.0:
			_cycle_phase -= 1.0
		var slot_f: float = _cycle_phase * n_cyl
		var slot: int = int(slot_f)
		var frac: float = slot_f - float(slot)
		var t_since: float = frac / (cycle_hz * n_cyl) # seconds since this cylinder fired
		var tau: float = tau_base * _cyl_tau[slot] * lerpf(1.35, 1.0, load) # softer off-load
		var x: float = t_since / tau
		var pulse: float = x * exp(1.0 - x) * _cyl_amp[slot] * lerpf(0.42, 1.0, load)
		var noise: float = randf() * 2.0 - 1.0
		pulse *= 1.0 + noise * rasp * 0.35 # combustion roughness
		if slot != _last_slot:
			_last_slot = slot
			_knock_env = 1.0 # diesel injection knock at every firing
		var sig: float = pulse

		# --- 2. Exhaust resonances (two band-passes) on top of the raw pulses ---
		var y1: float = bq1[0] * sig + bq1[1] * bq1[5] - bq1[2] * bq1[6] - bq1[3] * bq1[7]
		bq1[5] = bq1[4]; bq1[4] = sig; bq1[7] = bq1[6]; bq1[6] = y1
		var y2: float = bq2[0] * sig + bq2[1] * bq2[5] - bq2[2] * bq2[6] - bq2[3] * bq2[7]
		bq2[5] = bq2[4]; bq2[4] = sig; bq2[7] = bq2[6]; bq2[6] = y2
		var ex: float = sig * 0.35 + y1 * g1 * 3.0 + y2 * g2 * 3.0

		# --- 3. Intake roar, diesel knock, supercharger whine ---
		_noise_lp1 += (noise - _noise_lp1) * 0.18
		_noise_lp2 += (_noise_lp1 - _noise_lp2) * 0.05
		var band_noise: float = _noise_lp1 - _noise_lp2
		ex += band_noise * intake * load * (0.4 + pulse) * 0.8
		if knock > 0.0:
			_knock_env *= 0.9965 # ~6 ms clatter
			var clat: float = (noise - _noise_lp1) * _knock_env * knock * lerpf(1.0, 0.55, clampf((_rpm_s - 900.0) / 2500.0, 0.0, 1.0))
			ex += clat * 0.9
		if whine > 0.0:
			_sc_phase = fmod(_sc_phase + _rpm_s / 60.0 * 3.2 * TAU * dt, TAU)
			ex += sin(_sc_phase) * whine * (0.3 + 0.7 * load) * 0.35

		# --- Muffler (2-pole low-pass) + DC blocker + saturation ---
		_mlp1 += (ex - _mlp1) * lp_a
		_mlp2 += (_mlp1 - _mlp2) * lp_a
		var hp: float = _mlp2 - _dc_x + 0.995 * _dc_y
		_dc_x = _mlp2
		_dc_y = hp
		var engine_sample: float = tanh(hp * drive * (0.8 + 0.5 * load)) * gain * 0.42

		# Deceleration Overrun Burble: low, muffled rumble (low-passed noise, not a bright hiss)
		if _overrun_timer > 0.0 and load < 0.2:
			_burble_lp += (noise - _burble_lp) * 0.06
			engine_sample += _burble_lp * (_overrun_timer / 0.65) * 0.10 * pulse

		# Rev Limiter Cut (PRESERVED EXACTLY AS PRAISED BY USER!)
		if limiter:
			engine_sample *= randf_range(0.0, 1.2) if _pop_timer > 0.02 else 0.0

		# Backfire, gunshot-like: a sharp crack, a short blast and a low thump falling in pitch,
		# repeated for multi-pop cars, soft-clipped so it hits hard. Shape per car: BANGS.
		if _bang_t >= 0.0:
			var bt: float = _bang_t
			var ec: float = 0.0
			var eb: float = 0.0
			var et: float = 0.0
			var tl: float = bt
			for pn in range(int(_bk[6])):
				var tp: float = bt - pn * float(_bk[7])
				if tp < 0.0:
					break
				var amp: float = 1.0 - 0.25 * pn
				ec += amp * exp(-tp / float(_bk[0]))
				eb += amp * exp(-tp / float(_bk[2]))
				et += amp * exp(-tp / (float(_bk[2]) * 2.3))
				tl = tp
			_bang_lp += (noise - _bang_lp) * float(_bk[1])
			_bang_ph = fmod(_bang_ph + lerpf(float(_bk[3]), float(_bk[4]), minf(tl / 0.08, 1.0)) * TAU / sample_rate, TAU)
			var bang: float = noise * ec + _bang_lp * 2.2 * _bk_norm * eb + sin(_bang_ph) * float(_bk[5]) * et
			engine_sample += tanh(bang * 1.6) * 0.85 * float(_bk[8])
			_bang_t += dt
			if _bang_t > (float(_bk[6]) - 1.0) * float(_bk[7]) + 0.3:
				_bang_t = -1.0

		# Turbo whistle: gain and pitch glide smoothly (~60 ms), never clicking on or off
		_turbo_gain += (_turbo_gain_target - _turbo_gain) * 0.0004
		_turbo_freq_s += (_turbo_freq_target - _turbo_freq_s) * 0.0002
		var turbo_sample: float = 0.0
		_turbo_phase = fmod(_turbo_phase + _turbo_freq_s * TAU / sample_rate, TAU)
		if _turbo_gain > 0.0005:
			var tw: float = sin(_turbo_phase) + 0.25 * sin(_turbo_phase * 2.0)
			_hiss_lp += (noise - _hiss_lp) * 0.25
			turbo_sample = (tw * 0.006 + _hiss_lp * 0.004) * _turbo_gain
		if is_nitro:
			engine_sample *= 1.15

		# Blow-off valve: a short "pssh" of band-limited air, quick attack, smooth decay
		var bov_sample: float = 0.0
		if _bov_amp > 0.001:
			_bov_t += dt
			if _bov_attack > 0.0:
				_bov_env = minf(_bov_env + 1.0 / (0.012 * sample_rate), 1.0)
				if _bov_env >= 1.0:
					_bov_attack = 0.0
			else:
				_bov_env *= 0.99985 # ~0.15 s decay
			_bov_lp1 += (noise - _bov_lp1) * 0.30
			_bov_lp2 += (noise - _bov_lp2) * 0.07
			var flutter: float = 0.8 + 0.2 * sin(_bov_t * TAU * 22.0)
			bov_sample = (_bov_lp1 - _bov_lp2) * _bov_env * flutter * _bov_amp * 0.09
			if _bov_attack == 0.0 and _bov_env < 0.002:
				_bov_amp = 0.0
				_bov_env = 0.0

		# Tyre squeal: a band-limited, slightly tonal screech that fades in and out smoothly
		# (it used to be raw white noise at 0.14 - almost as loud as the engine).
		_skid_gain += ((skid_target if is_skidding else 0.0) - _skid_gain) * 0.0005
		var skid_sample: float = 0.0
		if _skid_gain > 0.0005:
			_skid_lp1 += (noise - _skid_lp1) * 0.22
			_skid_lp2 += (_skid_lp1 - _skid_lp2) * 0.06
			_skid_phase = fmod(_skid_phase + (880.0 + 120.0 * sin(_skid_phase * 0.0007)) * TAU * dt, TAU * 1000.0)
			var squeal: float = (_skid_lp1 - _skid_lp2) * 0.8 + sin(_skid_phase) * 0.25
			skid_sample = squeal * _skid_gain * 0.045

		var mixed: float = clampf(engine_sample + turbo_sample + bov_sample + skid_sample, -0.92, 0.92)
		out[i] = Vector2(mixed, mixed)
	return out
