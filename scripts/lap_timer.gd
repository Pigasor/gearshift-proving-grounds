extends Node
# Lap timing for the race circuit. Timing gates (Area3D) report the car passing; gate 0 is the
# start/finish line. A lap only counts if every gate was passed in order (no shortcuts).
# Time is game time (physics delta), so slow motion doesn't help. Best laps are saved per car.

const SAVE_PATH := "user://records.cfg"

var gate_count: int = 10
var track_length_m: float = 0.0

var running: bool = false
var current_time: float = 0.0
var last_lap: float = 0.0
var best_laps: Dictionary = {} # vehicle type (int) -> seconds
var lap_count: int = 0
var last_lap_was_record: bool = false
var invalid_message_timer: float = 0.0
var _next_gate: int = 0
var _car_type: int = -1
var _car: Node = null

func _ready() -> void:
	add_to_group("lap_timer")
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK and cfg.has_section("laps"):
		for k in cfg.get_section_keys("laps"):
			best_laps[int(k)] = float(cfg.get_value("laps", k))

func _physics_process(delta: float) -> void:
	if invalid_message_timer > 0.0:
		invalid_message_timer -= delta
	if not running:
		return
	current_time += delta
	# Switching car mid-lap cancels the lap
	if _car and int(_car.get("record_key")) != _car_type:
		cancel()

func on_gate(body: Node, gate: int) -> void:
	if not (body is RigidBody3D) or body.get("current_vehicle_type") == null:
		return
	_car = body
	if gate == 0:
		if running and _next_gate == gate_count:
			_finish_lap()
		elif running and _next_gate > 1:
			invalid_message_timer = 3.0 # crossed the line without completing the lap
		# (Re)start a lap
		running = true
		current_time = 0.0
		_next_gate = 1
		_car_type = int(body.get("record_key")) # car + engine
	elif running and gate == _next_gate:
		_next_gate += 1

func _finish_lap() -> void:
	last_lap = current_time
	lap_count += 1
	var best: float = best_laps.get(_car_type, 0.0)
	last_lap_was_record = best <= 0.0 or last_lap < best
	if last_lap_was_record:
		best_laps[_car_type] = last_lap
		var cfg := ConfigFile.new()
		cfg.load(SAVE_PATH)
		cfg.set_value("laps", str(_car_type), last_lap)
		cfg.save(SAVE_PATH)

func cancel() -> void:
	running = false
	current_time = 0.0
	_next_gate = 0

func best_for(car_type: int) -> float:
	return best_laps.get(car_type, 0.0)

static func fmt(t: float) -> String:
	if t <= 0.0:
		return "--:--.--"
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]
