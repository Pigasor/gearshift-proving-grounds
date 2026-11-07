class_name ProvingGround
extends Node3D

@export var vehicle: Node3D

# Performance Testing Metrics
var is_measuring_accel: bool = false
var accel_timer: float = 0.0
var time_0_100: float = 0.0
var best_0_100: float = 0.0

var is_measuring_quarter_mile: bool = false
var quarter_mile_timer: float = 0.0
var quarter_mile_start_pos: Vector3 = Vector3.ZERO
var time_quarter_mile: float = 0.0
var speed_quarter_mile: float = 0.0

var top_speed_record: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO

# Jump Tracking
var is_in_air: bool = false
var air_timer: float = 0.0
var jump_start_pos: Vector3 = Vector3.ZERO
var last_jump_distance: float = 0.0
var last_jump_airtime: float = 0.0

@onready var label_records: Label = $CanvasLayerStats/Margin/Panel/VBox/LabelRecords

func _ready() -> void:
	_update_stats_display()

func _physics_process(delta: float) -> void:
	if vehicle == null:
		return

	# Teleport / reset (car jumped > 30 m in one step): drop measurements in progress
	if vehicle.global_position.distance_to(_last_pos) > 30.0:
		is_measuring_accel = false
		is_measuring_quarter_mile = false
		is_in_air = false
	_last_pos = vehicle.global_position

	_track_acceleration(delta)
	_track_jumps(delta)
	_track_top_speed()
	_update_stats_display()

func _track_acceleration(delta: float) -> void:
	var speed: float = vehicle.current_speed_kmh

	# 0-100 km/h tracking
	if speed < 1.0 and not is_measuring_accel:
		# Ready at standstill
		pass
	elif speed >= 1.0 and speed < 100.0:
		if not is_measuring_accel and vehicle.current_gear >= 2:
			is_measuring_accel = true
			accel_timer = 0.0
			is_measuring_quarter_mile = true
			quarter_mile_timer = 0.0
			quarter_mile_start_pos = vehicle.global_position
		elif is_measuring_accel:
			accel_timer += delta
	elif speed >= 100.0 and is_measuring_accel:
		time_0_100 = accel_timer
		is_measuring_accel = false
		if best_0_100 == 0.0 or time_0_100 < best_0_100:
			best_0_100 = time_0_100

	# 400m Quarter Mile tracking
	if is_measuring_quarter_mile:
		quarter_mile_timer += delta
		var dist_traveled: float = (vehicle.global_position - quarter_mile_start_pos).length()
		if dist_traveled >= 402.33: # 1/4 mile in meters
			time_quarter_mile = quarter_mile_timer
			speed_quarter_mile = speed
			is_measuring_quarter_mile = false

func _track_jumps(delta: float) -> void:
	var all_wheels_in_air: bool = true
	for i in range(4):
		if vehicle.wheel_is_grounded[i]:
			all_wheels_in_air = false
			break

	if all_wheels_in_air and vehicle.current_speed_kmh > 30.0:
		if not is_in_air:
			is_in_air = true
			air_timer = 0.0
			jump_start_pos = vehicle.global_position
		else:
			air_timer += delta
	else:
		if is_in_air:
			# Landed!
			is_in_air = false
			last_jump_airtime = air_timer
			last_jump_distance = (vehicle.global_position - jump_start_pos).length()

func _track_top_speed() -> void:
	if vehicle.current_speed_kmh > top_speed_record:
		top_speed_record = vehicle.current_speed_kmh

func _update_stats_display() -> void:
	if label_records == null:
		return

	var t_0_100_str: String = "%1.2fs (Best: %1.2fs)" % [time_0_100, best_0_100] if best_0_100 > 0.0 else "--"
	var t_qm_str: String = "%1.2fs @ %3.0f km/h" % [time_quarter_mile, speed_quarter_mile] if time_quarter_mile > 0.0 else "--"
	var jump_str: String = "%1.1fm (%1.2fs)" % [last_jump_distance, last_jump_airtime] if last_jump_distance > 0.0 else "--"

	label_records.text = """[ TEST SAHASI TELEMETRİSİ ]
0-100 km/s : %s
400m Süresi: %s
Son Atlama : %s
Maks Hız   : %3.0f km/s""" % [t_0_100_str, t_qm_str, jump_str, top_speed_record]

	# Race circuit lap times
	var timer: Node = get_tree().get_first_node_in_group("lap_timer")
	if timer:
		var lt = timer.get_script()
		var car_type: int = int(vehicle.get("current_vehicle_type"))
		var cur: String = lt.fmt(timer.current_time) if timer.running else "--:--.--"
		label_records.text += "\n\n[ YARIŞ PİSTİ ]\nTur        : %s\nSon Tur    : %s%s\nEn İyi Tur : %s" % [
			cur, lt.fmt(timer.last_lap), "  ★ REKOR!" if timer.last_lap_was_record and timer.last_lap > 0.0 else "",
			lt.fmt(timer.best_for(car_type))]
		if timer.invalid_message_timer > 0.0:
			label_records.text += "\n⚠ Tur geçersiz (kapı atlandı)"
