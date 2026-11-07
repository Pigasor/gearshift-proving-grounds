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

	if _previous_throttle > 0.5 and current_thr < 0.15 and vehicle.turbo_boost_bar > 0.3:
		_bov_timer = 0.32 # Realistic blow-off turbo flutter
		_overrun_timer = 0.65 # Exhaust overrun crackles

	_previous_throttle = current_thr

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

	# 2. Warm, Non-Fatiguing Turbo Spool Tone (Deeper frequency range)
	var turbo_freq: float = 320.0 + (clampf(vehicle.turbo_boost_bar, 0.0, 2.5) * 260.0)

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

		# Deceleration Overrun Burble (smooth transition when lifting off throttle)
		if _overrun_timer > 0.0 and _smoothed_throttle < 0.2:
			var burble: float = (randf() * 2.0 - 1.0) * (_overrun_timer / 0.65) * 0.06
			engine_sample += burble

		# Rev Limiter Cut (PRESERVED EXACTLY AS PRAISED BY USER!)
		if vehicle.is_limiter_active:
			engine_sample *= randf_range(0.0, 1.2) if _pop_timer > 0.02 else 0.0

		# 2. Turbo Whistle (Gentle, realistic turbine spool - completely silent at low bar!)
		var turbo_sample: float = 0.0
		var is_nitro: bool = vehicle.get("turbo_boost_active") == true
		# Only audible under actual positive boost (> 0.35 bar) and active throttle load
		if (vehicle.turbo_enabled or is_nitro) and vehicle.turbo_boost_bar > 0.35 and _smoothed_throttle > 0.15:
			var turbo_phase_inc: float = (turbo_freq * 2.0 * PI) / sample_rate
			_turbo_phase = fmod(_turbo_phase + turbo_phase_inc, 2.0 * PI)
			# Quadratic volume curve: completely inaudible at low bar, subtle background spool at high boost
			var boost_ratio: float = clampf((vehicle.turbo_boost_bar - 0.35) / 1.45, 0.0, 1.0)
			var boost_gain: float = boost_ratio * boost_ratio * _smoothed_throttle
			var whistle: float = sin(_turbo_phase) * (0.010 if is_nitro else 0.005) * boost_gain
			var air_flow: float = (randf() * 2.0 - 1.0) * (0.006 if is_nitro else 0.0025) * boost_gain
			turbo_sample = whistle + air_flow
			if is_nitro:
				engine_sample *= 1.15

		# 3. Blow-off Valve Hiss / Flutter
		var bov_sample: float = 0.0
		if _bov_timer > 0.0:
			var flutter: float = sin(_bov_timer * 45.0) * 0.5 + 0.5
			bov_sample = (randf() * 2.0 - 1.0) * (_bov_timer / 0.32) * flutter * 0.12

		# 4. Tire Squeal
		var skid_sample: float = 0.0
		if is_skidding:
			var skid_intensity: float = clampf((max_slip - 0.28) * 1.6, 0.0, 1.0)
			skid_sample = (randf() * 2.0 - 1.0) * skid_intensity * 0.14

		var mixed: float = clampf(engine_sample + turbo_sample + bov_sample + skid_sample, -0.92, 0.92)
		playback.push_frame(Vector2(mixed, mixed))
