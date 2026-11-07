class_name AudioSynth
extends Node

@export var vehicle: Node3D

var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0
var _engine_phase: float = 0.0
var _sub_phase: float = 0.0
var _turbo_phase: float = 0.0
var _previous_throttle: float = 0.0
var _bov_timer: float = 0.0
var _pop_timer: float = 0.0
var _overrun_timer: float = 0.0
var _smoothed_rpm: float = 900.0
var _smoothed_throttle: float = 0.0
var _lp_state: float = 0.0
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

	_smoothed_rpm = lerpf(_smoothed_rpm, vehicle.current_rpm, delta * 25.0)

	# Detect throttle release for BOV (Blow-Off Valve)
	# Pedal as the car reads it (rebindable keys + analog gamepad trigger)
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
	if vehicle.is_limiter_active and _pop_timer <= 0.0:
		_pop_timer = 0.07 # Rapid pop bursts

	if _pop_timer > 0.0:
		_pop_timer -= delta

	_fill_audio_buffer()

func _fill_audio_buffer() -> void:
	if playback == null or vehicle == null:
		return

	var frames_available: int = playback.get_frames_available()
	if frames_available <= 0:
		return

	var v_type: int = vehicle.get("current_vehicle_type") if vehicle.get("current_vehicle_type") != null else 0

	# 1. Engine Cylinder Firing Frequencies & Timbre Profiles
	var cylinder_divisor: float = 30.0 # Default 4-cyl
	var harmonic_weights: Array[float] = [1.0, 0.55, 0.35, 0.20] # Fundamental, 2nd, 3rd, 4th
	var sub_octave_gain: float = 0.20
	var rasp_gain: float = 0.15
	var lowpass_hz: float = 0.0 # 0 = no filter (original sound)
	var drive_scale: float = 1.0 # how hard the throttle saturates the tone (lower = less harsh)

	match v_type:
		0: # APEX GT-R (Twin-Turbo VR38 V6)
			cylinder_divisor = 20.0 # 6-cyl
			harmonic_weights = [1.0, 0.65, 0.45, 0.30]
			sub_octave_gain = 0.25
			rasp_gain = 0.22
		1: # VENOM V8 (Crossplane 6.2L Supercharged V8)
			cylinder_divisor = 15.0 # 8-cyl
			harmonic_weights = [1.2, 0.40, 0.60, 0.15] # Heavy bass 1st & 3rd harmonics
			sub_octave_gain = 0.45 # Deep chest-thumping low rumble
			rasp_gain = 0.10
		2: # TITAN 4x4 (Open-Header Racing V8)
			cylinder_divisor = 15.0 # 8-cyl
			harmonic_weights = [1.1, 0.50, 0.55, 0.25]
			sub_octave_gain = 0.40
			rasp_gain = 0.28
		3: # PHANTOM HYPERCAR (Quad-Turbo W16)
			# Used to be rpm/10 with heavy upper harmonics + rasp: pitch hit the 480 Hz ceiling at
			# 4800 rpm and the high end was piercing. Now a deeper, smoother W16 roar that still
			# rises all the way to redline, with a low-pass filter taking the edge off.
			cylinder_divisor = 19.0
			harmonic_weights = [1.0, 0.52, 0.30, 0.14]
			sub_octave_gain = 0.32
			rasp_gain = 0.08
			lowpass_hz = 1400.0
			drive_scale = 0.6
		5: # GOLIATH MONSTER TRUCK (Supercharged big-block V8)
			cylinder_divisor = 15.0
			harmonic_weights = [1.25, 0.45, 0.55, 0.18]
			sub_octave_gain = 0.55
			rasp_gain = 0.16
			lowpass_hz = 2200.0
		4: # TOYOTA SUPRA MK4 (Legendary 2JZ-GTE Inline-6)
			cylinder_divisor = 20.0 # 6-cyl
			harmonic_weights = [0.95, 0.70, 0.50, 0.28] # Silky metallic straight-6 tone
			sub_octave_gain = 0.28
			rasp_gain = 0.25

	var engine_freq: float = clampf(_smoothed_rpm / cylinder_divisor, 22.0, 480.0)
	var lp_alpha: float = 1.0
	if lowpass_hz > 0.0:
		lp_alpha = 1.0 - exp(-TAU * lowpass_hz / sample_rate)

	# 3. Tire Skid
	var max_slip: float = 0.0
	for i in range(4):
		max_slip = maxf(max_slip, absf(vehicle.wheel_slip_lateral[i]))
	var is_skidding: bool = max_slip > 0.28 and vehicle.current_speed_kmh > 12.0

	for i in range(frames_available):
		# Engine Phase Progression
		var phase_inc: float = (engine_freq * 2.0 * PI) / sample_rate
		_engine_phase = fmod(_engine_phase + phase_inc, 2.0 * PI)
		_sub_phase = fmod(_sub_phase + (phase_inc * 0.5), 2.0 * PI)

		# Harmonic Synthesizer
		var fundamental: float = sin(_engine_phase) * harmonic_weights[0]
		var harmonic2: float = sin(_engine_phase * 2.0) * harmonic_weights[1]
		var harmonic3: float = sin(_engine_phase * 3.0) * harmonic_weights[2]
		var harmonic4: float = sin(_engine_phase * 4.0) * harmonic_weights[3]
		var sub_bass: float = sin(_sub_phase) * sub_octave_gain

		# Subtle asymmetric combustion texture
		var wave_shape: float = (fundamental + harmonic2 + harmonic3 + harmonic4 + sub_bass)
		var combustion_rasp: float = (sin(_engine_phase * 5.0) + (randf() - 0.5) * 0.1) * rasp_gain

		var raw_engine: float = wave_shape + combustion_rasp

		# Smooth Throttle Load Saturation
		var drive_gain: float = 1.0 + (_smoothed_throttle * 1.5 * drive_scale)
		var engine_sample: float = tanh(raw_engine * drive_gain) * 0.24
		# Optional one-pole low-pass (before the limiter cut, so the cut character is unchanged)
		if lowpass_hz > 0.0:
			_lp_state += (engine_sample - _lp_state) * lp_alpha
			engine_sample = _lp_state * 1.15

		# Deceleration Overrun Burble: low, muffled rumble (low-passed noise, not a bright hiss)
		if _overrun_timer > 0.0 and _smoothed_throttle < 0.2:
			_burble_lp += ((randf() * 2.0 - 1.0) - _burble_lp) * 0.06
			engine_sample += _burble_lp * (_overrun_timer / 0.65) * 0.10

		# Rev Limiter Cut (PRESERVED EXACTLY AS PRAISED BY USER!)
		if vehicle.is_limiter_active:
			engine_sample *= randf_range(0.0, 1.2) if _pop_timer > 0.02 else 0.0

		# 2. Turbo Whistle (Gentle, realistic turbine spool - completely silent at low bar!)
		# Gain and pitch glide smoothly (~60 ms), so lifting/pressing never clicks it on or off.
		_turbo_gain += (_turbo_gain_target - _turbo_gain) * 0.0004
		_turbo_freq_s += (_turbo_freq_target - _turbo_freq_s) * 0.0002
		var turbo_sample: float = 0.0
		var is_nitro: bool = vehicle.get("turbo_boost_active") == true
		_turbo_phase = fmod(_turbo_phase + _turbo_freq_s * TAU / sample_rate, TAU)
		if _turbo_gain > 0.0005:
			# Soft whine (fundamental + a quiet octave) plus a breathy intake rush
			var whine: float = sin(_turbo_phase) + 0.25 * sin(_turbo_phase * 2.0)
			_hiss_lp += ((randf() * 2.0 - 1.0) - _hiss_lp) * 0.25
			turbo_sample = (whine * 0.006 + _hiss_lp * 0.004) * _turbo_gain
		if is_nitro:
			engine_sample *= 1.15

		# 3. Blow-off valve: a short "pssh" of band-limited air (not raw white noise), quick attack,
		# smooth decay, gentle flutter.
		var bov_sample: float = 0.0
		if _bov_amp > 0.001:
			_bov_t += 1.0 / sample_rate
			if _bov_attack > 0.0:
				_bov_env = minf(_bov_env + 1.0 / (0.012 * sample_rate), 1.0)
				if _bov_env >= 1.0:
					_bov_attack = 0.0
			else:
				_bov_env *= 0.99985 # ~0.15 s decay
			var noise: float = randf() * 2.0 - 1.0
			_bov_lp1 += (noise - _bov_lp1) * 0.30 # ~2.3 kHz low-pass
			_bov_lp2 += (noise - _bov_lp2) * 0.07 # ~500 Hz (removed: band-pass)
			var flutter: float = 0.8 + 0.2 * sin(_bov_t * TAU * 22.0)
			bov_sample = (_bov_lp1 - _bov_lp2) * _bov_env * flutter * _bov_amp * 0.09
			if _bov_attack == 0.0 and _bov_env < 0.002:
				_bov_amp = 0.0
				_bov_env = 0.0

		# 4. Tire Squeal
		var skid_sample: float = 0.0
		if is_skidding:
			var skid_intensity: float = clampf((max_slip - 0.28) * 1.6, 0.0, 1.0)
			skid_sample = (randf() * 2.0 - 1.0) * skid_intensity * 0.14

		var mixed: float = clampf(engine_sample + turbo_sample + bov_sample + skid_sample, -0.92, 0.92)
		playback.push_frame(Vector2(mixed, mixed))
