class_name CameraController
extends Node3D

enum CameraMode { CHASE, HOOD, BUMPER, CINEMATIC }

@export var target_vehicle: Node3D
@export var current_mode: CameraMode = CameraMode.CHASE

# Chase Orbit settings
@export var default_distance: float = 6.4
@export var default_height: float = 2.1
@export var look_target_height: float = 0.85
@export var mouse_sensitivity: float = 0.004

var _current_distance: float = 6.4
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = -0.22 # Looking slightly down
var _mouse_active_timer: float = 0.0
var _target_fov: float = 75.0
# Set from Settings
var base_fov: float = 74.0
var speed_fov_effect: bool = true
var invert_y: bool = false
# Cinematic shots
var _shot: int = -1
var _shot_time: float = 0.0
var _shot_side: float = 1.0
var _shot_pos: Vector3
var _shot_off: Vector3
var _orbit: float = 0.0 # slow sweep around the car during a tracking shot
var _toast: Label
# Crash shake
const SHAKE_ACCEL: float = 45.0 # m/s² of sudden velocity change before the camera shakes
var _trauma: float = 0.0
var _shake_t: float = 0.0
var _prev_car_vel: Vector3 = Vector3.ZERO
var _prev_car_pos: Vector3 = Vector3.ZERO

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	if camera == null:
		camera = Camera3D.new()
		add_child(camera)
	camera.make_current()
	_current_distance = default_distance
	if target_vehicle:
		_orbit_yaw = target_vehicle.global_rotation.y

func _unhandled_input(event: InputEvent) -> void:
	# Camera key (rebindable, default C) or Gamepad 'X' toggles camera mode
	if event.is_action_pressed("camera_view", false, true):
		cycle_mode()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_X:
			cycle_mode()

	# Mouse Orbit: Works with Right-Click drag, or free mouse movement
	if event is InputEventMouseMotion:
		# If right-click is held OR mouse is captured OR left click held
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_orbit_yaw -= event.relative.x * mouse_sensitivity
			var dy: float = -event.relative.y if invert_y else event.relative.y
			_orbit_pitch = clampf(_orbit_pitch - dy * mouse_sensitivity, -1.2, 0.45)
			_mouse_active_timer = 2.0 # Keep player's angle for 2 seconds

	# Mouse Wheel Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_current_distance = clampf(_current_distance - 0.6, 3.2, 18.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_current_distance = clampf(_current_distance + 0.6, 3.2, 18.0)

func cycle_mode() -> void:
	match current_mode:
		CameraMode.CHASE: current_mode = CameraMode.HOOD
		CameraMode.HOOD: current_mode = CameraMode.BUMPER
		CameraMode.BUMPER: current_mode = CameraMode.CINEMATIC
		CameraMode.CINEMATIC: current_mode = CameraMode.CHASE
	if current_mode == CameraMode.CINEMATIC:
		_show_toast(tr("🎬 SİNEMATİK KAMERA"))
	elif current_mode == CameraMode.CHASE and target_vehicle:
		# back to the default chase view: behind the car, default height and distance
		_orbit_yaw = target_vehicle.global_rotation.y
		_orbit_pitch = -0.22
		_current_distance = default_distance
		_mouse_active_timer = 0.0

# Short on-screen notice (e.g. "Cinematic camera") that fades out
func _show_toast(text: String) -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		_toast = Label.new()
		_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast.offset_top = 90
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.add_theme_font_size_override("font_size", 30)
		_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_toast.add_theme_constant_override("outline_size", 8)
		layer.add_child(_toast)
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)

func _physics_process(scaled_delta: float) -> void:
	if target_vehicle == null:
		return
	# Camera runs on REAL time: in slow motion the world slows down, the camera stays responsive.
	var delta: float = scaled_delta / maxf(Engine.time_scale, 0.01)

	var speed_kmh: float = 0.0
	if "current_speed_kmh" in target_vehicle:
		speed_kmh = target_vehicle.current_speed_kmh

	# Dynamic FOV for speed sensation + Turbo Boost warp
	var fov_boost: float = 0.0
	if speed_fov_effect:
		fov_boost = clampf(speed_kmh / 200.0, 0.0, 1.0) * 16.0
		if target_vehicle and target_vehicle.get("turbo_boost_active"):
			fov_boost += 14.0 # High speed warp sensation on Shift Turbo!
	camera.fov = lerpf(camera.fov, base_fov + fov_boost, clampf(delta * 4.0, 0.0, 1.0))

	match current_mode:
		CameraMode.CHASE:
			_process_chase(delta, speed_kmh)
		CameraMode.HOOD:
			_process_hood(delta)
		CameraMode.BUMPER:
			_process_bumper(delta)
		CameraMode.CINEMATIC:
			_process_cinematic(delta, speed_kmh)
	_update_shake(delta, scaled_delta)

func _vehicle_scale() -> float:
	var s = target_vehicle.get("camera_scale")
	return float(s) if s != null else 1.0

func _process_chase(delta: float, speed_kmh: float) -> void:
	var car_pos: Vector3 = target_vehicle.global_position
	var v_scale: float = _vehicle_scale() # big vehicles (monster truck) get a wider, higher view
	var look_at_pos: Vector3 = car_pos + Vector3.UP * look_target_height * v_scale

	# Gamepad Right Stick 360 Camera Orbit
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(rx) > 0.15 or absf(ry) > 0.15:
		_orbit_yaw -= rx * delta * 3.4
		_orbit_pitch = clampf(_orbit_pitch - ry * delta * 2.4, -1.2, 0.45)
		_mouse_active_timer = 2.2

	# If player hasn't moved mouse/stick recently, smoothly align camera behind car when driving forward
	if _mouse_active_timer > 0.0:
		_mouse_active_timer -= delta
	else:
		if speed_kmh > 8.0:
			var car_yaw: float = target_vehicle.global_rotation.y
			# Smoothly blend yaw to car rear
			_orbit_yaw = lerp_angle(_orbit_yaw, car_yaw, delta * 2.8)

	# Calculate spherical orbit position (sitting behind car along -Z when yaw=0)
	var cam_offset: Vector3 = Vector3(
		-sin(_orbit_yaw) * cos(_orbit_pitch),
		-sin(_orbit_pitch),
		-cos(_orbit_yaw) * cos(_orbit_pitch)
	) * _current_distance * v_scale

	var desired_pos: Vector3 = look_at_pos + cam_offset

	# Prevent camera from clipping through floor / ground
	desired_pos = _clear_spot(look_at_pos, desired_pos)

	# Ensure minimum height above terrain
	if desired_pos.y < 0.6:
		desired_pos.y = 0.6

	# Smooth follow
	global_position = global_position.lerp(desired_pos, delta * 12.0)
	camera.look_at(look_at_pos, Vector3.UP)

func _process_hood(delta: float) -> void:
	var t: Transform3D = target_vehicle.global_transform
	var s: float = _vehicle_scale()
	var local: Vector3 = target_vehicle.get("cam_hood")
	if local == Vector3.ZERO:
		local = Vector3(0.0, 0.88 * s, 0.6 * s)
	var hood_pos: Vector3 = t * local
	global_position = hood_pos
	camera.look_at(hood_pos + (t.basis.z * 15.0), t.basis.y)

func _process_bumper(delta: float) -> void:
	var t: Transform3D = target_vehicle.global_transform
	var s: float = _vehicle_scale()
	var local: Vector3 = target_vehicle.get("cam_bumper")
	if local == Vector3.ZERO:
		local = Vector3(0.0, 0.35 * s, 2.15 * (1.0 + (s - 1.0) * 0.4))
	var bumper_pos: Vector3 = t * local
	global_position = bumper_pos
	camera.look_at(bumper_pos + (t.basis.z * 15.0), t.basis.y)

# Cinematic camera: cuts between HIGH shots only - every one at least CINE_HIGH car heights above
# the car (helicopter chase, high side, roadside crane, overhead). The one exception is the speed
# shot: above 200 km/h a camera at car height beside the road, which only pans left/right
# (yaw) as the car blasts past - its job is to show how fast the car is.
const CINE_HIGH: float = 5.0
const SPEED_SHOT: int = 4
var _high_idx: int = -1

func _process_cinematic(delta: float, speed_kmh: float) -> void:
	var car_pos: Vector3 = target_vehicle.global_position
	var s: float = _vehicle_scale()
	var fwd: Vector3 = target_vehicle.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.BACK
	var right: Vector3 = Vector3.UP.cross(fwd)
	var look_pos: Vector3 = car_pos + Vector3.UP * 0.6 * s
	var vel: Vector3 = target_vehicle.linear_velocity
	var high: float = 1.4 * s * CINE_HIGH # car ~1.4 m tall -> 7 m (monster truck ~13 m)
	_shot_time -= delta
	var passed: bool = (_shot == SPEED_SHOT or _shot == 2) and (car_pos - _shot_pos).dot(fwd) > (35.0 if _shot == SPEED_SHOT else 40.0) * s # car is gone: cut
	var cut: bool = false
	if _shot < 0 or _shot_time <= 0.0 or passed:
		cut = true
		_orbit = 0.0
		_shot_side = -_shot_side
		if speed_kmh > 200.0 and _shot != SPEED_SHOT:
			_shot = SPEED_SHOT
			_shot_time = 5.0
			var lead: Vector3 = (vel * 1.0).limit_length(60.0)
			_shot_pos = _ground_spot(car_pos + lead + right * _shot_side * 6.0 * s, 0.8 * s) # car height
			_shot_pos = _clear_spot(look_pos, _shot_pos)
		else:
			_high_idx = (_high_idx + 1) % 4
			_shot = _high_idx
			_shot_time = 7.0
			if _shot == 2: # crane on the roadside ahead, the car drives under/past it
				_shot_pos = _ground_spot(car_pos + (vel * 2.5).limit_length(60.0) + right * _shot_side * 12.0 * s, high * 1.3)
	var target: Vector3
	match _shot:
		0: target = car_pos - fwd * 12.0 * s + Vector3.UP * high # helicopter chase
		1: target = car_pos + right * _shot_side * 11.0 * s + fwd * 3.0 * s + Vector3.UP * high * 1.1 # high side
		2:
			_shot_pos += vel * 0.2 * delta # the crane drifts a little after the car
			target = _shot_pos
		3: target = car_pos - fwd * 3.0 * s + Vector3.UP * high * 1.8 # overhead
		_: target = _shot_pos # speed shot: fixed spot
	if _shot != 2 and _shot != SPEED_SHOT:
		_orbit += delta * 0.15 * _shot_side
		target = car_pos + (target - car_pos).rotated(Vector3.UP, _orbit)
		target = _clear_spot(look_pos, target)
	# tracking shots smooth their offset from the car, so speed never makes them fall behind
	if cut or _shot == 2 or _shot == SPEED_SHOT:
		_shot_off = target - car_pos
	else:
		_shot_off = _shot_off.lerp(target - car_pos, clampf(delta * 4.0, 0.0, 1.0))
	global_position = car_pos + _shot_off
	if _shot == SPEED_SHOT:
		var flat: Vector3 = look_pos - global_position
		flat.y = 0.0 # level camera: it only turns left / right
		if flat.length() > 0.1:
			camera.look_at(global_position + flat, Vector3.UP)
	else:
		camera.look_at(look_pos, Vector3.UP)

# Pull a camera spot in front of anything between it and the car
func _clear_spot(from: Vector3, to: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	if target_vehicle is CollisionObject3D:
		q.exclude = [target_vehicle.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position + hit.normal * 0.35 if hit else to

func _ground_spot(p: Vector3, height: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 40.0, p + Vector3.DOWN * 40.0)
	if target_vehicle is CollisionObject3D:
		q.exclude = [target_vehicle.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position if hit else p) + Vector3.UP * height

# Controller vibration on hits and hard landings (Settings > Kontroller > Titreşim). Steering wheels only
# vibrate if Windows sees them as an XInput pad: Godot has no force feedback.
func _rumble(strength: float) -> void:
	if not bool(GameSettings.get_value("vibration")):
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(strength, 0.0, 1.0), clampf(strength * 1.3, 0.0, 1.0), 0.15 + 0.35 * strength)

# Camera shake from hard hits (walls, crashes, heavy landings), measured from the car's
# deceleration; teleports and the recover jump are ignored.
func _update_shake(delta: float, step: float) -> void:
	var v: Vector3 = target_vehicle.linear_velocity
	var p: Vector3 = target_vehicle.global_position
	var moved: float = p.distance_to(_prev_car_pos)
	if step > 0.0 and moved < (v.length() + _prev_car_vel.length()) * step + 0.5:
		var accel: float = (v - _prev_car_vel).length() / step
		if accel > SHAKE_ACCEL:
			_trauma = minf(_trauma + (accel - SHAKE_ACCEL) * step * 0.07, 1.0) # ~0.4 at a 20 km/h knock, full at 50+
			_rumble(_trauma)
	_prev_car_vel = v
	_prev_car_pos = p
	_trauma = maxf(_trauma - delta * 1.4, 0.0)
	_shake_t += delta
	var k: float = _trauma * _trauma
	camera.h_offset = k * 0.22 * (sin(_shake_t * 41.0) + 0.5 * sin(_shake_t * 67.0))
	camera.v_offset = k * 0.18 * (sin(_shake_t * 53.0 + 1.3) + 0.5 * sin(_shake_t * 79.0))
	camera.rotate_object_local(Vector3.BACK, k * 0.045 * sin(_shake_t * 31.0))
