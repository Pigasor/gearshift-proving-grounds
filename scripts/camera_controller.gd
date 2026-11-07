class_name CameraController
extends Node3D

enum CameraMode { CHASE, HOOD, BUMPER, DRONE }

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
		CameraMode.BUMPER: current_mode = CameraMode.DRONE
		CameraMode.DRONE: current_mode = CameraMode.CHASE

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
		CameraMode.DRONE:
			_process_drone(delta)

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
	var world := get_world_3d()
	if world:
		var space_state := world.direct_space_state
		if space_state:
			var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(look_at_pos, desired_pos)
			if target_vehicle is CollisionObject3D:
				ray_query.exclude = [target_vehicle.get_rid()]

			var ray_res: Dictionary = space_state.intersect_ray(ray_query)
			if ray_res:
				desired_pos = ray_res.position + ray_res.normal * 0.35

	# Ensure minimum height above terrain
	if desired_pos.y < 0.6:
		desired_pos.y = 0.6

	# Smooth follow
	global_position = global_position.lerp(desired_pos, delta * 12.0)
	camera.look_at(look_at_pos, Vector3.UP)

func _process_hood(delta: float) -> void:
	var t: Transform3D = target_vehicle.global_transform
	var s: float = _vehicle_scale()
	var hood_pos: Vector3 = t.origin + (t.basis.z * 0.6 * s) + (t.basis.y * 0.88 * s)
	global_position = hood_pos
	camera.look_at(hood_pos + (t.basis.z * 15.0), t.basis.y)

func _process_bumper(delta: float) -> void:
	var t: Transform3D = target_vehicle.global_transform
	var s: float = _vehicle_scale()
	var bumper_pos: Vector3 = t.origin + (t.basis.z * 2.15 * (1.0 + (s - 1.0) * 0.4)) + (t.basis.y * 0.35 * s)
	global_position = bumper_pos
	camera.look_at(bumper_pos + (t.basis.z * 15.0), t.basis.y)

func _process_drone(delta: float) -> void:
	var car_pos: Vector3 = target_vehicle.global_position
	var top_pos: Vector3 = car_pos + Vector3(0.0, 18.0, -8.0)
	global_position = global_position.lerp(top_pos, delta * 5.0)
	camera.look_at(car_pos + Vector3(0.0, 0.0, 4.0), Vector3.UP)
