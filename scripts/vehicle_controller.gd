class_name VehicleController
extends RigidBody3D

enum VehicleType { GT_SPORT, MUSCLE_V8, TROPHY_TRUCK, HYPERCAR, SUPRA_MK4, MONSTER_TRUCK }

# Standard car body geometry (from vehicle.tscn) - restored when switching away from the monster truck
const DEFAULT_WHEEL_OFFSETS: Array[Vector3] = [Vector3(-0.86, 0.0, 1.32), Vector3(0.86, 0.0, 1.32), Vector3(-0.88, 0.0, -1.32), Vector3(0.88, 0.0, -1.32)]
const DEFAULT_RIDE: float = 0.54 # tire_radius + suspension_rest_length of a normal car
const VISUAL_TIRE_RADIUS: float = 0.32 # radius of the tyre mesh in vehicle.tscn

# Camera distance multiplier (big vehicles get a wider chase view)
var camera_scale: float = 1.0
# Hood / bumper camera spots (local), set from the procedural body; ZERO = use the default spot
var cam_hood: Vector3 = Vector3.ZERO
var cam_bumper: Vector3 = Vector3.ZERO
var exhaust_smokes: Array[ExhaustSmoke] = [] # one per tailpipe
var engine_sound: String = "" # AudioSynth profile picked by the car (CarDatabase "sound"), "" = by engine type
var front_wheel_r: float = 0.0 # smaller front wheels (tractor), visual only; 0 = same as the rear
var _rim_mat: StandardMaterial3D # shared by all four rims: chrome, or painted per car (body "rim")
var _coilovers: Array = [] # per-wheel coil-over springs (buggy): chassis to wheel, follow the suspension
var backfire_count: int = 0 # bumped on every backfire; the audio plays a bang when it changes
# Rotational inertia (kg*m^2): one wheel+tyre, and the engine's flywheel/crank
var front_lateral_bias: float = 1.13
# Pedal positions 0..1 as the driver presses them (HUD), and the tail-light materials
# Tyre grip per surface. Road tyres: great on tarmac, poor on loose ground.
# Off-road tyres (Trophy Truck, monster truck): a bit less on tarmac, far better off-road.
const SURFACE_GRIP_ROAD: Dictionary = {"asphalt": 1.0, "concrete": 0.95, "kerb": 0.92, "dirt": 0.64, "grass": 0.55, "sand": 0.475}
const SURFACE_GRIP_OFFROAD: Dictionary = {"asphalt": 0.92, "concrete": 0.9, "kerb": 0.88, "dirt": 0.95, "grass": 0.85, "sand": 0.8}
# Extra rolling resistance (fraction of wheel load) on soft ground
const SURFACE_ROLLING_DRAG: Dictionary = {"dirt": 0.025, "grass": 0.035, "sand": 0.09}
var offroad_tires: bool = false
var wheel_surface: Array[String] = ["asphalt", "asphalt", "asphalt", "asphalt"]
# Tyre contact data for TyreFX (skid marks, smoke, flying grass): world point, ground normal,
# wheelspin (m/s, + = wheel faster than the ground) and sideways slide (m/s)
var wheel_contact_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var wheel_contact_normal: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
var wheel_long_slip: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_lat_slip: Array[float] = [0.0, 0.0, 0.0, 0.0]
var input_blocked: bool = false # true while the garage menu is open (inputs ignored, car rolls on)
var steer_sensitivity: float = 1.0 # how fast the wheel turns with keys (Settings)
var joy_deadzone: float = 0.08 # gamepad stick dead zone (Settings)
# Steering wheel set (Settings > Kontroller): axes, pedal calibration, buttons
var wheel_cfg: Dictionary = {}
var using_wheel: bool = false # a configured wheel is connected and driving the car
const STEER_RATIO: float = 14.0 # steering-wheel degrees per road-wheel degree (typical car)
var pedal_throttle: float = 0.0
var pedal_brake: float = 0.0
var _brake_light_mats: Array[StandardMaterial3D] = []
var light_mode: int = 0 # L cycles: 0 off, 1 parking lights, 2 low beam
var high_beam: bool = false # K
var _head_mat: StandardMaterial3D
var _tail_base: float = 1.2
var _beams: Array[SpotLight3D] = []
var wheel_inertia: float = 1.2
var engine_inertia: float = 0.25

# --- CURRENT VEHICLE TYPE ---
# Index into CarDatabase.CARS (0-5 are the original cars, same numbers as VehicleType)
@export var current_vehicle_type: int = VehicleType.GT_SPORT
var is_monster: bool = false # monster-truck chassis (Goliath and its siblings): wall climbing, wide wheels
var legacy_paint: Color = Color(0, 0, 0, 0) # paint for a hand-built legacy body (alpha 0 = its own colour)
var current_engine_index: int = 0
var record_key: int = 0 # lap records: car index, or car*100+engine for non-default engines
var engine_cylinders: int = 6
var engine_fuel: String = "benzin"

# Realistic engines (CarDatabase): a real torque curve instead of the legacy hp formula
const LEGACY_GEARS: Array[float] = [-3.4, 0.0, 3.62, 2.18, 1.54, 1.21, 1.00, 0.81]
var use_torque_curve: bool = false
var speed_limit_kmh: float = 0.0 # factory electronic top-speed limiter (0 = none)
var gearbox_type: String = "tc" # automatic: "tc" torque converter, "dct" dual clutch
var torque_peak_nm: float = 0.0
var torque_rpm_from: float = 0.0
var torque_rpm_to: float = 0.0
var power_rpm: float = 6000.0
const DRIVETRAIN_EFFICIENCY: float = 0.88 # gearbox/diff losses (realistic engines)

# --- TRANSMISSION & DRIVETRAIN ---
@export_group("Transmission")
@export var is_automatic: bool = true
@export var drivetrain_mode: String = "RWD" # "RWD", "AWD", "FWD"
@export var manual_clutch_enabled: bool = false
@export var final_drive_ratio: float = 3.73
@export var gear_ratios: Array[float] = [-3.4, 0.0, 3.62, 2.18, 1.54, 1.21, 1.00, 0.81]
@export var shift_delay_seconds: float = 0.12

# --- ENGINE & TURBO ---
@export_group("Engine & Turbo")
@export var peak_horsepower: float = 480.0
@export var idle_rpm: float = 900.0
@export var max_rpm: float = 7800.0
@export var limiter_rpm: float = 7400.0
@export var turbo_enabled: bool = true
@export var turbo_max_boost_bar: float = 1.4
@export var turbo_spool_rate: float = 2.4

# --- SHIFT TURBO BOOST (COOLDOWN) ---
@export_group("Shift Turbo Boost")
@export var turbo_boost_enabled: bool = true
@export var turbo_boost_duration: float = 3.5
@export var turbo_boost_cooldown: float = 6.0
var turbo_boost_active: bool = false
var turbo_boost_timer: float = 0.0
var turbo_boost_cooldown_timer: float = 0.0
var turbo_boost_ready: bool = true

# --- CHASSIS & AERODYNAMICS ---
@export_group("Suspension & Aero")
@export var suspension_rest_length: float = 0.22
@export var suspension_travel: float = 0.12
@export var spring_stiffness: float = 44000.0
@export var damper_bump: float = 4200.0
@export var damper_rebound: float = 5600.0
@export var anti_roll_stiffness: float = 11000.0
@export var camber_angle_front_deg: float = -2.2
@export var camber_angle_rear_deg: float = -1.2
@export var downforce_coefficient: float = 1.2
@export var drag_coefficient: float = 0.33 # 0.5 * air density * Cd * frontal area

# --- TIRES & BRAKES ---
@export_group("Tires & Brakes")
@export var tire_grip_factor: float = 1.22
@export var tire_radius: float = 0.32
@export var max_steer_angle_deg: float = 35.0
@export var brake_torque_max: float = 4600.0
@export var handbrake_torque_max: float = 8500.0
@export var brake_bias_front: float = 0.65

# --- ASSISTS ---
@export_group("Assists")
@export var abs_enabled: bool = true
@export var tcs_enabled: bool = true
var tcs_active: bool = false # TCS is cutting power right now (for the HUD)
var _tcs_cut: Array[float] = [0.0, 0.0, 0.0, 0.0]
@export var esp_enabled: bool = false

# --- TELEMETRY ---
var current_rpm: float = 900.0
var current_gear: int = 2
var clutch_pedal: float = 0.0
var current_speed_kmh: float = 0.0
var turbo_boost_bar: float = 0.0
var is_limiter_active: bool = false
var limiter_zone: bool = false # pedal down with the revs at the limiter (any gear): the sound is the limiter
var wheel_compression: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_angular_velocity: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_slip_lateral: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_is_grounded: Array[bool] = [false, false, false, false]
var wheel_contact_point: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var wall_climbing: bool = false # monster truck stuck to a steep surface
var g_force_lateral: float = 0.0
var g_force_longitudinal: float = 0.0
var is_handbrake_active: bool = false
var is_burnout: bool = false # handbrake + throttle at a standstill: driven wheels spin on the spot

# --- INTERNAL STATE ---
var _current_steer_angle: float = 0.0
var _throttle_input: float = 0.0
var _brake_input: float = 0.0
var _handbrake_input: float = 0.0
var _is_shifting: bool = false
var _shift_timer: float = 0.0
var _target_gear: int = 2
var _limiter_timer: float = 0.0
var _wrong_way_rpm: float = 0.0 # > 0 while the wheels try to turn the engine backwards
# Pulling away: clutch (manual, auto-clutch) or torque converter (automatic) slips between the
# engine and the gearbox. While slipping, the engine speed follows its own torque balance.
var engine_classic: bool = false # old engine without modern idle control: revs can sag below idle
var _clutch_slipping: bool = true
var _clutch_torque: float = 0.0 # torque the clutch/converter passes to the gearbox (Nm, engine side)
var _auto_clutch: float = 0.0 # 0..1 engagement of the game's automatic clutch (manual mode)
var _tc_mult: float = 1.0 # torque converter multiplication
var _prev_clutch_rpm: float = 900.0
var _slip_time: float = 0.0 # how long the auto clutch has been slipping under throttle
var _since_upshift: float = 10.0
var _manual_hold: bool = false # automatic box keeps the gear the driver picked
# Teleport done while the game is paused (big map, ESC menu): the physics server could hand back the
# pre-pause position on the next step, so the new transform is applied again inside the physics step.
var spawn_count: int = 0 # bumped on every car change (the camera must not read the speed reset as a crash)
var _impact_t: float = 0.0 # seconds left of "just hit something": the body may pitch, roll and spin freely
var _prev_lin_vel: Vector3 = Vector3.ZERO
var _teleport_pending: bool = false
var _teleport_xform: Transform3D
var _since_low_thr: float = 10.0 # seconds since the throttle was last below 75% (kickdown trigger)
var _dir_change_armed: bool = true # auto box: may switch D<->R with the next pedal press
var _prev_body_pos: Vector3 = Vector3.INF
var _auto_shift_cooldown: float = 0.0
var _previous_linear_velocity: Vector3 = Vector3.ZERO
var _prev_raw_compression: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _initial_transform: Transform3D

# Wheel mount offsets relative to vehicle body [FL, FR, RL, RR]
var wheel_offsets: Array[Vector3] = [
	Vector3(-0.86, 0.0, 1.32),  # FL
	Vector3(0.86, 0.0, 1.32),   # FR
	Vector3(-0.88, 0.0, -1.32), # RL
	Vector3(0.88, 0.0, -1.32)   # RR
]

@onready var wheel_mesh_fl: Node3D = $WheelFL
@onready var wheel_mesh_fr: Node3D = $WheelFR
@onready var wheel_mesh_rl: Node3D = $WheelRL
@onready var wheel_mesh_rr: Node3D = $WheelRR
var wheel_mounts: Array[Node3D]
var wheel_rolls: Array[Node3D]

@onready var visual_models_parent: Node3D = $VisualModel

func _ready() -> void:
	_initial_transform = global_transform
	wheel_mounts = [wheel_mesh_fl, wheel_mesh_fr, wheel_mesh_rl, wheel_mesh_rr]
	wheel_rolls = []
	for mount in wheel_mounts:
		if mount != null:
			var roll := mount.get_node_or_null("RollNode") as Node3D
			wheel_rolls.append(roll)
		else:
			wheel_rolls.append(null)

	_build_wheel_details()

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.18, 0.0)
	mass = 1380.0
	# No hidden velocity damping: Godot adds the project default (0.1/s) on top, which acted like
	# an invisible brake (~0.7 G when lifting off at 200 km/h). Air drag & rolling resistance
	# are simulated explicitly in _apply_aerodynamics() instead.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 3.2
	# walls: the body glances off and scrapes along instead of sticking to them
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.25
	physics_material_override.friction = 0.45
	continuous_cd = true # fast drops/crashes must not pass through the ground
	var fx := TyreFX.new()
	fx.vehicle = self
	add_child(fx)
	apply_car(current_vehicle_type, 0)

# Realistic wheel inside each RollNode (axle = X): open tyre tread + rounded sidewalls, chrome rim
# lip, dark rim barrel, 5 chrome spokes, chrome centre cap & lug nuts, brake disc behind the spokes.
func _wheel_mat(c: Color, metal: float, rough: float, two_sided: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _wheel_part(parent: Node3D, mesh: Mesh, pos: Vector3, axle_scale: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# meshes are built around Y: turn Y onto the axle (X), optionally squashed along it
	mi.transform = Transform3D(Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)) * Basis.from_scale(Vector3(1, axle_scale, 1)), pos)
	parent.add_child(mi)
	return mi

func _build_wheel_details() -> void:
	var rubber := _wheel_mat(Color(0.07, 0.07, 0.08), 0.0, 0.9)
	var chrome := _wheel_mat(Color(0.93, 0.94, 0.96), 1.0, 0.07)
	_rim_mat = chrome
	var barrel_mat := _wheel_mat(Color(0.16, 0.16, 0.18), 0.7, 0.4, true)
	var disc_mat := _wheel_mat(Color(0.55, 0.56, 0.58), 0.9, 0.35)
	var tread := CylinderMesh.new()
	tread.top_radius = 0.32
	tread.bottom_radius = 0.32
	tread.height = 0.22
	tread.radial_segments = 40
	tread.cap_top = false
	tread.cap_bottom = false
	tread.material = rubber
	var sidewall := TorusMesh.new() # squashed along the axle: a rounded tyre shoulder
	sidewall.inner_radius = 0.205
	sidewall.outer_radius = 0.32
	sidewall.rings = 40
	sidewall.ring_segments = 12
	sidewall.material = rubber
	var lip := TorusMesh.new()
	lip.inner_radius = 0.19
	lip.outer_radius = 0.225
	lip.rings = 40
	lip.ring_segments = 8
	lip.material = chrome
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.205
	barrel.bottom_radius = 0.205
	barrel.height = 0.21
	barrel.radial_segments = 32
	barrel.cap_top = false
	barrel.cap_bottom = false
	barrel.material = barrel_mat
	var back := CylinderMesh.new()
	back.top_radius = 0.2
	back.bottom_radius = 0.2
	back.height = 0.01
	back.radial_segments = 32
	back.material = _wheel_mat(Color(0.05, 0.05, 0.06), 0.3, 0.7)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.17
	disc.bottom_radius = 0.17
	disc.height = 0.025
	disc.radial_segments = 32
	disc.material = disc_mat
	var cap := CylinderMesh.new()
	cap.top_radius = 0.045
	cap.bottom_radius = 0.06
	cap.height = 0.04
	cap.radial_segments = 20
	cap.material = chrome
	var nut := CylinderMesh.new()
	nut.top_radius = 0.009
	nut.bottom_radius = 0.011
	nut.height = 0.02
	nut.radial_segments = 6
	nut.material = chrome
	var spoke := BoxMesh.new()
	spoke.size = Vector3(0.026, 0.15, 0.045) # x = depth along the axle, y = radial length
	spoke.material = chrome

	for i in range(wheel_mounts.size()):
		var mount: Node3D = wheel_mounts[i]
		var roll: Node3D = wheel_rolls[i]
		if mount == null or roll == null:
			continue
		var side: float = -1.0 if i % 2 == 0 else 1.0 # outer face of the wheel
		for n in ["TireMesh", "RimMesh"]:
			var old := roll.get_node_or_null(n)
			if old:
				old.queue_free()
		_wheel_part(roll, tread, Vector3.ZERO)
		for sd in [-1.0, 1.0]:
			_wheel_part(roll, sidewall, Vector3(sd * 0.105, 0, 0), 0.45)
		_wheel_part(roll, lip, Vector3(side * 0.118, 0, 0), 0.5)
		_wheel_part(roll, barrel, Vector3(0.0, 0, 0))
		_wheel_part(roll, back, Vector3(-side * 0.06, 0, 0))
		_wheel_part(roll, disc, Vector3(side * 0.0, 0, 0))
		_wheel_part(roll, cap, Vector3(side * 0.1, 0, 0)).rotation_degrees.z = -90.0 * side
		for k in range(5):
			var a: float = k * TAU / 5.0
			var s := MeshInstance3D.new()
			s.mesh = spoke
			s.position = Vector3(side * 0.095, 0.12 * cos(a), 0.12 * sin(a))
			s.rotation.x = a
			roll.add_child(s)
			var n_a: float = a + TAU / 10.0
			_wheel_part(roll, nut, Vector3(side * 0.112, 0.07 * cos(n_a), 0.07 * sin(n_a)))

		# Red brake caliper on the mount (does NOT roll with the wheel), inside the rim barrel
		var caliper := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.06, 0.07, 0.11)
		var caliper_mat := StandardMaterial3D.new()
		caliper_mat.albedo_color = Color(0.92, 0.12, 0.08)
		caliper_mat.metallic = 0.5
		caliper_mat.roughness = 0.25
		caliper_mat.clearcoat_enabled = true
		caliper_mat.clearcoat = 0.8
		cm.material = caliper_mat
		caliper.mesh = cm
		caliper.position = Vector3(side * 0.045, 0.12, 0.06)
		caliper.rotation_degrees = Vector3(25.0, 0.0, 0.0)
		mount.add_child(caliper)

func trigger_turbo_boost() -> bool:
	if not turbo_boost_enabled or current_gear == 0: # no boost in reverse
		return false
	if turbo_boost_cooldown_timer <= 0.0 and not turbo_boost_active:
		turbo_boost_active = true
		turbo_boost_timer = turbo_boost_duration
		turbo_boost_cooldown_timer = turbo_boost_cooldown
		turbo_boost_ready = false
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	# Rebindable controls (Settings > Atamalar)
	if event.is_action_pressed("gear_up", false, true):
		_driver_shift(true)
	elif event.is_action_pressed("gear_down", false, true):
		_driver_shift(false)
	elif event.is_action_pressed("toggle_transmission", false, true):
		is_automatic = !is_automatic
	elif event.is_action_pressed("repair", false, true):
		repair_vehicle()
	elif event.is_action_pressed("lights", false, true):
		light_mode = (light_mode + 1) % 3
		_update_lights()
	elif event.is_action_pressed("high_beam", false, true):
		high_beam = not high_beam
		_update_lights()
	elif event.is_action_pressed("reset_car", false, true):
		reset_vehicle()
	elif event.is_action_pressed("slow_mo", false, true):
		toggle_slow_mo()
	# (Cars are picked in the garage menu now - there are too many for the number keys.)

	# Steering wheel buttons (paddle shifters) - set up in Settings > Kontroller
	elif event is InputEventJoypadButton and event.pressed and _is_wheel_device(event.device):
		if event.button_index == int(wheel_cfg.get("shift_up_btn", -1)):
			_driver_shift(true)
		elif event.button_index == int(wheel_cfg.get("shift_down_btn", -1)):
			_driver_shift(false)

	# Gamepad Button Support (A/B = handbrake, turbo = left stick click)
	elif event is InputEventJoypadButton and event.pressed and not _is_wheel_device(event.device):
		match event.button_index:
			JOY_BUTTON_RIGHT_SHOULDER: # RB
				_driver_shift(true)
			JOY_BUTTON_LEFT_SHOULDER: # LB
				_driver_shift(false)
			JOY_BUTTON_DPAD_DOWN:
				toggle_slow_mo()
			JOY_BUTTON_Y: # Triangle / Y: put the car back on its wheels
				repair_vehicle()
			JOY_BUTTON_BACK: # Select
				is_automatic = !is_automatic

# Pick a car + engine from CarDatabase (garage menu). Legacy cars use their tuned presets below.
func apply_car(index: int, engine_index: int = 0) -> void:
	_reset_turbo_boost()
	var c: Dictionary = CarDatabase.car(index)
	index = clampi(index, 0, CarDatabase.count() - 1)
	engine_index = clampi(engine_index, 0, (c["engines"] as Array).size() - 1)
	var en: Dictionary = CarDatabase.engine(index, engine_index)
	cam_hood = Vector3.ZERO
	cam_bumper = Vector3.ZERO
	front_wheel_r = 0.0
	_set_rims(Color(0.93, 0.94, 0.96), false)
	for roll in wheel_rolls:
		if roll != null:
			roll.position = Vector3.ZERO
	_place_exhausts([Vector3(-0.55, -0.05, -2.4)], false) # legacy trophy truck; bodies / monster override
	legacy_paint = c.get("paint", Color(0, 0, 0, 0))
	if c.has("legacy"):
		apply_vehicle_preset(int(c["legacy"]))
		_apply_engine(en)
		if en.has("mass"):
			# real kerb weight: scale springs, dampers, anti-roll bars and brakes with it so the
			# suspension keeps its ride height and character
			var k: float = float(en["mass"]) / maxf(mass, 1.0)
			mass = float(en["mass"])
			spring_stiffness *= k
			damper_bump *= k
			damper_rebound *= k
			anti_roll_stiffness *= k
			brake_torque_max *= k
			handbrake_torque_max *= k
		else:
			mass += float(en.get("mass_add", 0.0))
		if c.has("body"):
			# realistic body for this model, on the legacy chassis' wheel positions
			var bd: Dictionary = (c["body"] as Dictionary).duplicate()
			bd["wheelbase"] = absf(wheel_offsets[0].z - wheel_offsets[2].z)
			bd["track"] = absf(wheel_offsets[0].x - wheel_offsets[1].x)
			_rebuild_body(bd)
	else:
		var old_ride: float = tire_radius + suspension_rest_length
		_apply_sedan(c, en)
		var new_ride: float = tire_radius + suspension_rest_length
		if is_inside_tree() and new_ride > old_ride:
			global_position += Vector3.UP * (new_ride - old_ride + 0.1)
	current_vehicle_type = index
	is_monster = int(c.get("legacy", -1)) == VehicleType.MONSTER_TRUCK
	current_engine_index = engine_index
	record_key = index if engine_index == 0 else index * 100 + engine_index
	engine_classic = bool(c.get("classic", false))
	engine_sound = str(en.get("sound", ""))
	engine_cylinders = int(en.get("cyl", 4))
	engine_fuel = str(en.get("fuel", "benzin"))
	_update_wheel_colliders()
	spawn_count += 1
	# the new car appears where the old one was, standing still
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	for i in range(4):
		wheel_angular_velocity[i] = 0.0
	current_rpm = idle_rpm
	_engage_gear_now(1) # neutral: the new car must not creep off on its own (auto picks D/R from the pedals)

func _apply_engine(en: Dictionary) -> void:
	use_torque_curve = true
	peak_horsepower = float(en["hp"])
	torque_peak_nm = float(en["torque"])
	torque_rpm_from = float(en["tq_from"])
	torque_rpm_to = float(en["tq_to"])
	power_rpm = float(en["power_rpm"])
	idle_rpm = float(en["idle"])
	limiter_rpm = float(en["limiter"])
	max_rpm = float(en["max_rpm"])
	turbo_max_boost_bar = float(en["turbo"])
	turbo_enabled = turbo_max_boost_bar > 0.0
	turbo_spool_rate = 1.5 if str(en.get("fuel", "")) == "dizel" else 2.0
	gear_ratios.assign(en["gears"])
	final_drive_ratio = float(en["final"])
	current_rpm = idle_rpm
	speed_limit_kmh = float(en.get("vmax", 0.0))
	gearbox_type = str(en.get("trans", "tc"))
	if en.has("drag"):
		drag_coefficient = float(en["drag"])
	if en.has("grip"):
		tire_grip_factor = float(en["grip"])
	if en.has("shift"):
		shift_delay_seconds = float(en["shift"])
	if current_gear >= gear_ratios.size():
		_engage_gear_now(2)

# Rims: chrome, or painted in the car's colour (e.g. a tractor's yellow wheels)
func _set_rims(col: Color, painted: bool) -> void:
	if _rim_mat == null:
		return
	_rim_mat.albedo_color = col
	_rim_mat.metallic = 0.25 if painted else 1.0
	_rim_mat.roughness = 0.45 if painted else 0.07

# Family sedan: front-wheel drive, soft road suspension, eco tyres.
func _apply_sedan(c: Dictionary, en: Dictionary) -> void:
	var b: Dictionary = c["body"]
	_apply_engine(en)
	mass = float(b["mass"]) + float(en.get("mass_add", 0.0))
	drivetrain_mode = str(b.get("drive", "FWD"))
	downforce_coefficient = 0.05
	drag_coefficient = float(b["cd_area"])
	tire_radius = float(b["tire_r"])
	suspension_rest_length = 0.24
	suspension_travel = 0.15
	spring_stiffness = mass * 26.0
	damper_bump = mass * 2.1
	damper_rebound = mass * 2.9
	anti_roll_stiffness = 8500.0
	tire_grip_factor = 1.0
	max_steer_angle_deg = 37.0
	offroad_tires = false
	camera_scale = 1.0
	wheel_inertia = 1.0
	engine_inertia = 0.16
	brake_torque_max = mass * 2.9
	handbrake_torque_max = 9000.0
	brake_bias_front = 0.68
	shift_delay_seconds = 0.32 # an ordinary gearbox, not a race DCT
	center_of_mass = Vector3(0.0, -0.12, 0.18) # engine up front (mid / rear-engined cars override it in "setup")
	# per-model setup (race car, tractor, buggy...): overrides any of the values above
	var setup: Dictionary = b.get("setup", {})
	for k in setup:
		set(k, setup[k])
	if b.has("rim"):
		_set_rims(b["rim"], true)
	var wb: float = float(b["wheelbase"])
	var tr: float = float(b["track"])
	wheel_offsets = [Vector3(-tr * 0.5, 0.0, wb * 0.5), Vector3(tr * 0.5, 0.0, wb * 0.5), Vector3(-tr * 0.5, 0.0, -wb * 0.5), Vector3(tr * 0.5, 0.0, -wb * 0.5)]
	# Collision: lower body + cabin, sized to the car
	var ground_y: float = -(tire_radius + suspension_rest_length - 0.09)
	var L: float = float(b["length"])
	var W: float = float(b["width"])
	var H: float = float(b["height"])
	var z_mid: float = (wb * 0.5 + float(b["front_overhang"]) - (L - wb * 0.5 - float(b["front_overhang"]))) * 0.5
	var chassis_col := get_node_or_null("CollisionChassis") as CollisionShape3D
	var cabin_col := get_node_or_null("CollisionCabin") as CollisionShape3D
	if chassis_col and chassis_col.shape is BoxShape3D:
		var clear: float = float(b.get("ground_clearance", 0.18)) # high-riding off-roaders clear logs and rocks
		(chassis_col.shape as BoxShape3D).size = Vector3(W - 0.08, 0.8 - clear, L - 0.12)
		chassis_col.position = Vector3(0.0, ground_y + clear + (0.8 - clear) * 0.5, z_mid)
	if cabin_col and cabin_col.shape is BoxShape3D:
		(cabin_col.shape as BoxShape3D).size = Vector3(W * 0.78, H - 0.95, 2.1)
		cabin_col.position = Vector3(0.0, ground_y + 0.80 + (H - 0.95) * 0.5, z_mid - 0.15)
	for i in range(wheel_rolls.size()):
		if wheel_rolls[i] != null:
			var wr: float = front_wheel_r if (i < 2 and front_wheel_r > 0.0) else tire_radius
			var ws: float = wr / VISUAL_TIRE_RADIUS
			wheel_rolls[i].scale = Vector3(ws * 0.85, ws, ws)
			wheel_rolls[i].position = Vector3(0.0, wr - tire_radius, 0.0) # a smaller wheel still sits on the ground
	for i in range(mini(wheel_mounts.size(), 4)):
		if wheel_mounts[i] != null:
			wheel_mounts[i].position = wheel_offsets[i]
	for i in range(4):
		_prev_raw_compression[i] = 0.0
	if visual_models_parent == null:
		visual_models_parent = get_node_or_null("VisualModel") as Node3D
	_rebuild_body(b)

# Procedural body (BodyBuilder) sitting at the car's real ride height
func _rebuild_body(b: Dictionary) -> void:
	if visual_models_parent == null:
		visual_models_parent = get_node_or_null("VisualModel") as Node3D
	_clear_car_model()
	if visual_models_parent == null:
		return
	var sag: float = mass * 9.81 / 4.0 / maxf(spring_stiffness, 1.0)
	var ground_y: float = -(tire_radius + suspension_rest_length - sag)
	var builder := BodyBuilder.new()
	_brake_light_mats.append_array(builder.build(visual_models_parent, b, ground_y, tire_radius))
	if b.get("coilovers", false):
		var spring_mat := StandardMaterial3D.new()
		spring_mat.albedo_color = Color(0.85, 0.08, 0.06)
		spring_mat.metallic = 0.4
		spring_mat.roughness = 0.35
		for i in 4:
			var cm := CylinderMesh.new()
			cm.top_radius = 0.065
			cm.bottom_radius = 0.065
			cm.height = 1.0
			cm.radial_segments = 10
			cm.material = spring_mat
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			visual_models_parent.add_child(mi)
			_coilovers.append(mi)
	# on the hood just ahead of the windscreen, and just ahead of the nose
	cam_hood = Vector3(0.0, builder.g + float(builder.s["cowl"]) + 0.2, builder.cowl_z + 0.3)
	cam_bumper = Vector3(0.0, builder.g + 0.5, builder.zf + 0.1)
	_place_exhausts(builder.exhausts, builder.exhaust_up)
	# headlight beams at the front corners (switched with L / K)
	var lamp_y: float = builder.g + float(builder.s["nose"]) - 0.06
	_add_headlamps([Vector3(-(builder.hw - 0.35), lamp_y, builder.zf + 0.05), Vector3(builder.hw - 0.35, lamp_y, builder.zf + 0.05)], builder.head)

# Headlight beams at these (car-local) lamp positions; head_mat = the lamp glass material, which
# glows brighter with the lights.
func _add_headlamps(lamps: Array, head_mat: StandardMaterial3D) -> void:
	_head_mat = head_mat
	for p in lamps:
		var sl := SpotLight3D.new()
		sl.position = p
		sl.light_color = Color(1.0, 0.95, 0.85)
		sl.light_specular = 0.2
		visual_models_parent.add_child(sl)
		_beams.append(sl)
	_update_lights()

func _update_lights() -> void:
	var on: bool = light_mode == 2 or high_beam
	for sl in _beams:
		sl.visible = on
		sl.spot_range = 200.0 if high_beam else 75.0
		sl.spot_angle = 26.0 if high_beam else 40.0
		sl.light_energy = 18.0 if high_beam else 9.0
		sl.basis = Basis.looking_at(Vector3(0.0, -0.01 if high_beam else -0.1, 1.0))
	if _head_mat:
		_head_mat.emission_energy_multiplier = 16.0 if high_beam else [0.3, 3.0, 9.0][light_mode]
	_tail_base = 1.2 if light_mode == 0 and not high_beam else 3.0

# Smoke emitter on every tailpipe tip (local); up = vertical stacks blowing upwards
func _place_exhausts(tips: Array, up: bool) -> void:
	for e in exhaust_smokes:
		e.queue_free()
	exhaust_smokes.clear()
	for p in tips:
		var e := ExhaustSmoke.new()
		e.vehicle = self
		e.pipe_pos = p
		e.position = p
		e.pipe_dir = Vector3(0.0, 1.0, -0.15) if up else Vector3(0.0, 0.15, -1.0)
		e.share = 1.0 / float(tips.size())
		add_child(e)
		exhaust_smokes.append(e)

# Wheels used to have no collision of their own (raycast suspension), so they sank into walls and
# platform edges. A cylinder per wheel (a bit smaller than the tyre, at the fully compressed
# position) blocks that without ever touching the road during normal driving.
func _update_wheel_colliders() -> void:
	var monster: bool = is_monster
	for i in range(4):
		var nm: String = "CollisionWheel%d" % i
		var col := get_node_or_null(nm) as CollisionShape3D
		if col == null:
			col = CollisionShape3D.new()
			col.name = nm
			col.shape = CylinderShape3D.new()
			add_child(col)
		var cyl := col.shape as CylinderShape3D
		cyl.radius = tire_radius * 0.72
		cyl.height = 0.75 if monster else 0.22
		col.rotation = Vector3(0.0, 0.0, PI * 0.5) # axle along X
		col.position = wheel_offsets[i] + Vector3.DOWN * maxf(suspension_rest_length - suspension_travel, 0.0)

func apply_vehicle_preset(type: int) -> void:
	var old_ride: float = tire_radius + suspension_rest_length
	current_vehicle_type = type
	is_monster = type == VehicleType.MONSTER_TRUCK
	current_engine_index = 0
	record_key = type
	# Values the realistic (database) cars change - restore the legacy defaults
	use_torque_curve = false
	speed_limit_kmh = 0.0
	gearbox_type = "tc"
	gear_ratios.assign(LEGACY_GEARS)
	idle_rpm = 900.0
	turbo_spool_rate = 2.4
	max_steer_angle_deg = 35.0
	brake_bias_front = 0.65
	shift_delay_seconds = 0.12
	if current_gear >= gear_ratios.size():
		_engage_gear_now(2)
	match type:
		VehicleType.GT_SPORT: # Nissan GT-R Style
			peak_horsepower = 565.0
			mass = 1380.0
			drivetrain_mode = "AWD"
			turbo_enabled = true
			turbo_max_boost_bar = 1.4
			max_rpm = 7800.0
			limiter_rpm = 7400.0
			downforce_coefficient = 1.2
			drag_coefficient = 0.33
			final_drive_ratio = 3.73
			anti_roll_stiffness = 11000.0
			suspension_rest_length = 0.22
			suspension_travel = 0.12
			spring_stiffness = 44000.0
			damper_bump = 4200.0
			damper_rebound = 5600.0
			tire_grip_factor = 1.22
			tire_radius = 0.32
			_build_real_car_model("GT_SPORT")

		VehicleType.MUSCLE_V8: # Dodge Challenger / Fastback V8 Style
			peak_horsepower = 707.0
			mass = 1620.0
			drivetrain_mode = "RWD"
			turbo_enabled = false
			turbo_max_boost_bar = 0.0
			max_rpm = 7200.0
			limiter_rpm = 6800.0
			downforce_coefficient = 0.6
			drag_coefficient = 0.49
			final_drive_ratio = 3.73
			anti_roll_stiffness = 11000.0
			suspension_rest_length = 0.24
			suspension_travel = 0.14
			spring_stiffness = 40000.0
			damper_bump = 3800.0
			damper_rebound = 5000.0
			tire_grip_factor = 1.08
			tire_radius = 0.33
			_build_real_car_model("MUSCLE_V8")

		VehicleType.TROPHY_TRUCK: # Baja 1000 Desert Runner
			peak_horsepower = 600.0
			mass = 1850.0
			drivetrain_mode = "AWD"
			turbo_enabled = true
			turbo_max_boost_bar = 1.1
			max_rpm = 6800.0
			limiter_rpm = 6400.0
			downforce_coefficient = 0.3
			drag_coefficient = 0.95
			final_drive_ratio = 5.10
			anti_roll_stiffness = 17000.0
			suspension_rest_length = 0.38
			suspension_travel = 0.24
			spring_stiffness = 30000.0
			damper_bump = 4400.0
			damper_rebound = 5800.0
			tire_grip_factor = 1.25
			tire_radius = 0.40
			_build_real_car_model("TROPHY_TRUCK")

		VehicleType.HYPERCAR: # Bugatti / Koenigsegg W16 Hypercar
			peak_horsepower = 1150.0
			mass = 1220.0
			drivetrain_mode = "AWD"
			turbo_enabled = true
			turbo_max_boost_bar = 2.4
			max_rpm = 9200.0
			limiter_rpm = 8800.0
			downforce_coefficient = 1.3
			drag_coefficient = 0.44
			final_drive_ratio = 3.73
			anti_roll_stiffness = 12000.0
			suspension_rest_length = 0.18
			suspension_travel = 0.10
			spring_stiffness = 58000.0
			damper_bump = 5200.0
			damper_rebound = 6800.0
			tire_grip_factor = 1.45
			tire_radius = 0.32
			_build_real_car_model("HYPERCAR")

		VehicleType.SUPRA_MK4: # Legendary Toyota Supra A80 (2JZ-GTE Twin-Turbo)
			peak_horsepower = 680.0
			mass = 1420.0
			drivetrain_mode = "RWD"
			turbo_enabled = true
			turbo_max_boost_bar = 1.8
			max_rpm = 8400.0
			limiter_rpm = 8000.0
			downforce_coefficient = 1.0
			drag_coefficient = 0.39
			final_drive_ratio = 3.73
			anti_roll_stiffness = 11000.0
			suspension_rest_length = 0.22
			suspension_travel = 0.12
			spring_stiffness = 43000.0
			damper_bump = 4200.0
			damper_rebound = 5500.0
			tire_grip_factor = 1.28
			tire_radius = 0.32
			_build_real_car_model("SUPRA_MK4")

		VehicleType.MONSTER_TRUCK: # Goliath 4x4 - 66" tyres, supercharged big-block, ~4.2 t
			peak_horsepower = 1500.0
			mass = 4200.0
			drivetrain_mode = "AWD"
			turbo_enabled = false
			turbo_max_boost_bar = 0.0
			max_rpm = 6800.0
			limiter_rpm = 6400.0
			downforce_coefficient = 0.0
			drag_coefficient = 1.5 # huge frontal area
			final_drive_ratio = 13.0 # tops out around 190 km/h
			anti_roll_stiffness = 26000.0
			suspension_rest_length = 0.55
			suspension_travel = 0.45 # long-travel bouncy suspension for hills & jumps
			spring_stiffness = 60000.0
			damper_bump = 6500.0
			damper_rebound = 9000.0
			tire_grip_factor = 1.05
			tire_radius = 0.83
			_build_real_car_model("MONSTER_TRUCK")
			_place_exhausts([Vector3(-0.75, 2.2, -1.12), Vector3(0.75, 2.2, -1.12)], true) # chrome stacks behind the cab

	_apply_body_geometry(type)

	# Switching to a taller vehicle while driving: lift it so the new wheels don't spawn in the ground.
	var new_ride: float = tire_radius + suspension_rest_length
	if is_inside_tree() and new_ride > old_ride:
		global_position += Vector3.UP * (new_ride - old_ride + 0.1)
	var en: Dictionary = CarDatabase.engine(type, 0)
	engine_classic = bool(CarDatabase.car(type).get("classic", false))
	engine_cylinders = int(en.get("cyl", 6))
	engine_fuel = str(en.get("fuel", "benzin"))
	_update_wheel_colliders()

# Wheel positions, collision boxes, centre of mass, brakes, wheel mesh size & camera distance.
func _apply_body_geometry(type: VehicleType) -> void:
	var chassis_col := get_node_or_null("CollisionChassis") as CollisionShape3D
	var cabin_col := get_node_or_null("CollisionCabin") as CollisionShape3D
	var tire_width_scale: float = 1.0
	offroad_tires = type == VehicleType.TROPHY_TRUCK or type == VehicleType.MONSTER_TRUCK

	if type == VehicleType.MONSTER_TRUCK:
		wheel_offsets = [Vector3(-1.5, 0.0, 1.85), Vector3(1.5, 0.0, 1.85), Vector3(-1.5, 0.0, -1.85), Vector3(1.5, 0.0, -1.85)]
		center_of_mass = Vector3(0.0, -0.25, 0.0)
		brake_torque_max = 17000.0
		handbrake_torque_max = 40000.0
		camera_scale = 1.9
		tire_width_scale = 1.45 # extra-wide flotation tyres
		wheel_inertia = 70.0 # ~250 kg tyre each
		engine_inertia = 0.6
		if chassis_col and chassis_col.shape is BoxShape3D:
			(chassis_col.shape as BoxShape3D).size = Vector3(1.4, 0.4, 4.2)
			chassis_col.position = Vector3(0.0, 0.0, 0.0)
		if cabin_col and cabin_col.shape is BoxShape3D:
			(cabin_col.shape as BoxShape3D).size = Vector3(2.5, 1.1, 4.9)
			cabin_col.position = Vector3(0.0, 1.0, 0.0)
	else:
		wheel_offsets = DEFAULT_WHEEL_OFFSETS.duplicate()
		center_of_mass = Vector3(0.0, -0.18, 0.0)
		brake_torque_max = 4600.0
		handbrake_torque_max = 14000.0
		camera_scale = 1.15 if type == VehicleType.TROPHY_TRUCK else 1.0
		wheel_inertia = 3.5 if type == VehicleType.TROPHY_TRUCK else 1.2
		engine_inertia = 0.25
		if chassis_col and chassis_col.shape is BoxShape3D:
			(chassis_col.shape as BoxShape3D).size = Vector3(1.76, 0.36, 4.15)
			chassis_col.position = Vector3(0.0, 0.12, 0.0)
		if cabin_col and cabin_col.shape is BoxShape3D:
			(cabin_col.shape as BoxShape3D).size = Vector3(1.36, 0.42, 1.7)
			cabin_col.position = Vector3(0.0, 0.48, -0.2)

	# Scale the wheel meshes to the physics tyre size (this also fixes the Trophy Truck's
	# tyres that used to float above the ground: physics 0.40 m vs mesh 0.32 m).
	var s: float = tire_radius / VISUAL_TIRE_RADIUS
	for roll in wheel_rolls:
		if roll != null:
			roll.scale = Vector3(s * tire_width_scale, s, s)
	for i in range(mini(wheel_mounts.size(), 4)):
		if wheel_mounts[i] != null:
			wheel_mounts[i].position = wheel_offsets[i]
	for i in range(4):
		_prev_raw_compression[i] = 0.0

# --- PROCEDURAL REAL-LIFE 3D CAR BODY BUILDER ---
func _build_real_car_model(car_type: String) -> void:
	if visual_models_parent == null:
		visual_models_parent = get_node_or_null("VisualModel") as Node3D
	if visual_models_parent == null:
		return
	_clear_car_model()

	match car_type:
		"SUPRA_MK4":
			_build_supra_a80_mesh()
		"GT_SPORT":
			_build_gtr_r35_mesh()
		"MUSCLE_V8":
			_build_muscle_v8_mesh()
		"TROPHY_TRUCK":
			_build_trophy_truck_mesh()
		"HYPERCAR":
			_build_hypercar_mesh()
		"MONSTER_TRUCK":
			_build_monster_truck_mesh()

# Remove the current procedural body parts
func _clear_car_model() -> void:
	_beams.clear()
	_head_mat = null
	_dynamic_links.clear()
	_coilovers.clear()
	_brake_light_mats.clear()
	if visual_models_parent == null:
		return
	for child in visual_models_parent.get_children():
		visual_models_parent.remove_child(child)
		child.queue_free()

func _create_part(m: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	visual_models_parent.add_child(mi)
	return mi

# 1. TOYOTA SUPRA MK4 (A80 2JZ-GTE)
func _build_supra_a80_mesh() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.06, 0.14, 0.72) # Iconic Royal Sapphire Blue Metallic
	paint.metallic = 0.85
	paint.roughness = 0.18
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.06, 0.08, 0.12, 0.94)
	glass.metallic = 0.6
	glass.roughness = 0.08

	var carbon := StandardMaterial3D.new()
	carbon.albedo_color = Color(0.08, 0.08, 0.09)
	carbon.roughness = 0.4

	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.95, 0.95, 0.96)
	chrome.metallic = 0.98
	chrome.roughness = 0.05

	var red_tail := StandardMaterial3D.new()
	red_tail.albedo_color = Color(0.95, 0.05, 0.05)
	red_tail.emission_enabled = true
	red_tail.emission = Color(1.0, 0.05, 0.05)
	red_tail.emission_energy_multiplier = 4.0
	_brake_light_mats.append(red_tail)

	var headlight_mat := StandardMaterial3D.new()
	headlight_mat.albedo_color = Color(1, 1, 0.95)
	headlight_mat.emission_enabled = true
	headlight_mat.emission = Color(1, 1, 0.95)
	headlight_mat.emission_energy_multiplier = 5.0

	# Main Sleek Lower Body
	var body_m := BoxMesh.new()
	body_m.size = Vector3(1.76, 0.34, 4.15)
	_create_part(body_m, paint, Vector3(0, 0.08, 0))

	# Curved 90s Sports Hood
	var hood_m := BoxMesh.new()
	hood_m.size = Vector3(1.58, 0.18, 1.7)
	_create_part(hood_m, paint, Vector3(0, 0.18, 1.15), Vector3(-3, 0, 0))

	# Front Bumper with Wide Intercooler Mouth
	var bumper_m := BoxMesh.new()
	bumper_m.size = Vector3(1.72, 0.32, 0.45)
	_create_part(bumper_m, paint, Vector3(0, 0.06, 2.15))
	var mouth_m := BoxMesh.new()
	mouth_m.size = Vector3(1.10, 0.16, 0.08)
	_create_part(mouth_m, carbon, Vector3(0, 0.02, 2.39))
	# Front Chin Lip
	var lip_m := BoxMesh.new()
	lip_m.size = Vector3(1.74, 0.04, 0.35)
	_create_part(lip_m, carbon, Vector3(0, -0.09, 2.22))

	# Rounded Bubble Cabin
	var cabin_m := BoxMesh.new()
	cabin_m.size = Vector3(1.36, 0.44, 1.65)
	_create_part(cabin_m, glass, Vector3(0, 0.44, -0.22))
	var roof_m := BoxMesh.new()
	roof_m.size = Vector3(1.24, 0.06, 1.1)
	_create_part(roof_m, paint, Vector3(0, 0.67, -0.22))

	# Sloping Rear Hatch Window
	var hatch_m := BoxMesh.new()
	hatch_m.size = Vector3(1.34, 0.15, 0.95)
	_create_part(hatch_m, glass, Vector3(0, 0.38, -1.3), Vector3(-18, 0, 0))

	# ICONIC TOYOTA SUPRA MK4 HOOP REAR WING
	var wing_left_m := BoxMesh.new()
	wing_left_m.size = Vector3(0.08, 0.46, 0.28)
	_create_part(wing_left_m, paint, Vector3(-0.72, 0.46, -1.95))
	var wing_right_m := BoxMesh.new()
	wing_right_m.size = Vector3(0.08, 0.46, 0.28)
	_create_part(wing_right_m, paint, Vector3(0.72, 0.46, -1.95))
	var wing_arch_m := BoxMesh.new()
	wing_arch_m.size = Vector3(1.56, 0.07, 0.32)
	_create_part(wing_arch_m, paint, Vector3(0, 0.68, -1.95), Vector3(4, 0, 0))

	# ICONIC SUPRA 4-CIRCLE TAILLIGHTS
	var tail_panel_m := BoxMesh.new()
	tail_panel_m.size = Vector3(1.5, 0.18, 0.05)
	_create_part(tail_panel_m, carbon, Vector3(0, 0.18, -2.10))
	for t in range(4):
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.055
		cyl.bottom_radius = 0.055
		cyl.height = 0.04
		cyl.radial_segments = 16
		var tx: float = -0.52 + (t * 0.35)
		_create_part(cyl, red_tail, Vector3(tx, 0.18, -2.12), Vector3(90, 0, 0))

	# Headlights
	var hl_m := BoxMesh.new()
	hl_m.size = Vector3(0.32, 0.12, 0.25)
	_create_part(hl_m, headlight_mat, Vector3(-0.62, 0.19, 2.05), Vector3(-8, 0, 0))
	_create_part(hl_m, headlight_mat, Vector3(0.62, 0.19, 2.05), Vector3(-8, 0, 0))

	# Big 4-inch Single Cannon Chrome Exhaust
	var exh_m := CylinderMesh.new()
	exh_m.top_radius = 0.07
	exh_m.bottom_radius = 0.07
	exh_m.height = 0.45
	_create_part(exh_m, chrome, Vector3(-0.55, -0.05, -2.15), Vector3(90, 8, 0))

# 2. APEX GT-R (NISSAN GT-R R35)
func _build_gtr_r35_mesh() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.10, 0.12) # Nismo Championship Red Metallic
	paint.metallic = 0.88
	paint.roughness = 0.18
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0

	var carbon := StandardMaterial3D.new()
	carbon.albedo_color = Color(0.06, 0.06, 0.07)
	carbon.roughness = 0.35

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.12, 0.18, 0.92)
	glass.metallic = 0.6
	glass.roughness = 0.08

	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.7, 0.75, 0.9) # Titanium tips
	chrome.metallic = 0.95

	var red_tail := StandardMaterial3D.new()
	red_tail.albedo_color = Color(0.95, 0.05, 0.05)
	red_tail.emission_enabled = true
	red_tail.emission = Color(1.0, 0.05, 0.05)
	red_tail.emission_energy_multiplier = 4.0
	_brake_light_mats.append(red_tail)

	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color(1, 1, 0.95)
	hl_mat.emission_enabled = true
	hl_mat.emission = Color(1, 1, 0.95)
	hl_mat.emission_energy_multiplier = 5.0

	# Main Angular GT-R Body
	var body_m := BoxMesh.new()
	body_m.size = Vector3(1.78, 0.36, 4.2)
	_create_part(body_m, paint, Vector3(0, 0.08, 0))

	# GT-R V-Motion Carbon Grille & Bumper
	var bumper_m := BoxMesh.new()
	bumper_m.size = Vector3(1.74, 0.35, 0.5)
	_create_part(bumper_m, paint, Vector3(0, 0.08, 2.15))
	var v_grille_m := BoxMesh.new()
	v_grille_m.size = Vector3(1.0, 0.24, 0.06)
	_create_part(v_grille_m, carbon, Vector3(0, 0.06, 2.42))
	var splitter_m := BoxMesh.new()
	splitter_m.size = Vector3(1.82, 0.05, 0.42)
	_create_part(splitter_m, carbon, Vector3(0, -0.09, 2.25))

	# Hood with Twin NACA Ducts
	var hood_m := BoxMesh.new()
	hood_m.size = Vector3(1.58, 0.16, 1.75)
	_create_part(hood_m, paint, Vector3(0, 0.20, 1.15), Vector3(-4, 0, 0))
	var naca_m := BoxMesh.new()
	naca_m.size = Vector3(0.18, 0.04, 0.32)
	_create_part(naca_m, carbon, Vector3(-0.35, 0.28, 1.15))
	_create_part(naca_m, carbon, Vector3(0.35, 0.28, 1.15))

	# Chiseled Cabin & Roofline
	var cabin_m := BoxMesh.new()
	cabin_m.size = Vector3(1.36, 0.45, 1.8)
	_create_part(cabin_m, glass, Vector3(0, 0.45, -0.15))
	var roof_m := BoxMesh.new()
	roof_m.size = Vector3(1.26, 0.05, 1.4)
	_create_part(roof_m, paint, Vector3(0, 0.68, -0.15))

	# GT-R High Carbon GT Spoiler on Stanchions
	var pyl_m := BoxMesh.new()
	pyl_m.size = Vector3(0.06, 0.35, 0.18)
	_create_part(pyl_m, carbon, Vector3(-0.55, 0.42, -1.95))
	_create_part(pyl_m, carbon, Vector3(0.55, 0.42, -1.95))
	var wing_m := BoxMesh.new()
	wing_m.size = Vector3(1.68, 0.06, 0.38)
	_create_part(wing_m, carbon, Vector3(0, 0.60, -1.98), Vector3(6, 0, 0))

	# Signature GT-R Twin Round Taillights
	for pos_x in [-0.55, -0.32, 0.32, 0.55]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.065
		cyl.bottom_radius = 0.065
		cyl.height = 0.04
		_create_part(cyl, red_tail, Vector3(pos_x, 0.22, -2.12), Vector3(90, 0, 0))

	# Sharp Angular Headlights
	var hl_m := BoxMesh.new()
	hl_m.size = Vector3(0.28, 0.15, 0.32)
	_create_part(hl_m, hl_mat, Vector3(-0.64, 0.22, 2.05), Vector3(-12, 5, 0))
	_create_part(hl_m, hl_mat, Vector3(0.64, 0.22, 2.05), Vector3(-12, -5, 0))

	# Quad Titanium Exhausts
	var exh_m := CylinderMesh.new()
	exh_m.top_radius = 0.05
	exh_m.bottom_radius = 0.05
	exh_m.height = 0.25
	_create_part(exh_m, chrome, Vector3(-0.58, -0.04, -2.12), Vector3(90, 0, 0))
	_create_part(exh_m, chrome, Vector3(-0.46, -0.04, -2.12), Vector3(90, 0, 0))
	_create_part(exh_m, chrome, Vector3(0.46, -0.04, -2.12), Vector3(90, 0, 0))
	_create_part(exh_m, chrome, Vector3(0.58, -0.04, -2.12), Vector3(90, 0, 0))

# 3. VENOM V8 MUSCLE (CLASSIC AMERICAN MUSCLE)
func _build_muscle_v8_mesh() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.12, 0.13, 0.14) # Matte Black with menacing aura
	paint.metallic = 0.25
	paint.roughness = 0.55

	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.95, 0.95, 0.96)
	chrome.metallic = 0.95
	chrome.roughness = 0.1

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.08, 0.10, 0.95)
	glass.roughness = 0.1

	var red_tail := StandardMaterial3D.new()
	red_tail.albedo_color = Color(0.95, 0.05, 0.05)
	red_tail.emission_enabled = true
	red_tail.emission = Color(1.0, 0.05, 0.05)
	red_tail.emission_energy_multiplier = 4.0
	_brake_light_mats.append(red_tail)

	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color(1.0, 0.95, 0.85)
	hl_mat.emission_enabled = true
	hl_mat.emission = Color(1.0, 0.95, 0.85)
	hl_mat.emission_energy_multiplier = 4.5

	# Broad Muscular Body
	var body_m := BoxMesh.new()
	body_m.size = Vector3(1.85, 0.38, 4.35)
	_create_part(body_m, paint, Vector3(0, 0.10, 0))

	# Raised Power Bulge Hood Scoop
	var hood_m := BoxMesh.new()
	hood_m.size = Vector3(1.65, 0.16, 2.0)
	_create_part(hood_m, paint, Vector3(0, 0.22, 1.15))
	var scoop_m := BoxMesh.new()
	scoop_m.size = Vector3(0.55, 0.10, 0.85)
	_create_part(scoop_m, paint, Vector3(0, 0.34, 1.1))

	# Deep Recessed Black Grille
	var grille_m := BoxMesh.new()
	grille_m.size = Vector3(1.72, 0.28, 0.12)
	_create_part(grille_m, paint, Vector3(0, 0.12, 2.20))
	var chin_m := BoxMesh.new()
	chin_m.size = Vector3(1.82, 0.08, 0.35)
	_create_part(chin_m, paint, Vector3(0, -0.08, 2.22))

	# Quad Retro Round Headlights
	for pos_x in [-0.62, -0.38, 0.38, 0.62]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.075
		cyl.bottom_radius = 0.075
		cyl.height = 0.05
		_create_part(cyl, hl_mat, Vector3(pos_x, 0.14, 2.22), Vector3(90, 0, 0))

	# Fastback Muscle Cabin with Thick C-Pillars
	var cabin_m := BoxMesh.new()
	cabin_m.size = Vector3(1.42, 0.44, 1.85)
	_create_part(cabin_m, glass, Vector3(0, 0.46, -0.2))
	var roof_m := BoxMesh.new()
	roof_m.size = Vector3(1.36, 0.06, 1.55)
	_create_part(roof_m, paint, Vector3(0, 0.68, -0.2))

	# Ducktail Trunk Lip Spoiler
	var duck_m := BoxMesh.new()
	duck_m.size = Vector3(1.75, 0.12, 0.24)
	_create_part(duck_m, paint, Vector3(0, 0.32, -2.12), Vector3(25, 0, 0))

	# Horizontal Retro LED Taillight Bar
	var tail_m := BoxMesh.new()
	tail_m.size = Vector3(1.68, 0.12, 0.06)
	_create_part(tail_m, red_tail, Vector3(0, 0.18, -2.19))

	# Dual Wide Rectangular Chrome Exhaust Tips
	var exh_m := BoxMesh.new()
	exh_m.size = Vector3(0.22, 0.08, 0.25)
	_create_part(exh_m, chrome, Vector3(-0.55, -0.04, -2.2))
	_create_part(exh_m, chrome, Vector3(0.55, -0.04, -2.2))

# 4. TITAN 4x4 (BAJA 1000 TROPHY TRUCK)
func _build_trophy_truck_mesh() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.94, 0.76, 0.08) # Electric Racing Yellow
	paint.metallic = 0.35
	paint.roughness = 0.35

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.12, 0.12, 0.14)
	steel.metallic = 0.7
	steel.roughness = 0.4

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.1, 0.12, 0.92)

	var led_light := StandardMaterial3D.new()
	led_light.albedo_color = Color(1.0, 1.0, 1.0)
	led_light.emission_enabled = true
	led_light.emission = Color(1.0, 1.0, 1.0)
	led_light.emission_energy_multiplier = 6.0

	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.12, 0.12, 0.13)
	tire_mat.roughness = 0.9

	# High Truck Cab
	var cab_m := BoxMesh.new()
	cab_m.size = Vector3(1.88, 0.52, 2.2)
	_create_part(cab_m, paint, Vector3(0, 0.28, 0.6))
	var glass_m := BoxMesh.new()
	glass_m.size = Vector3(1.5, 0.44, 1.4)
	_create_part(glass_m, glass, Vector3(0, 0.68, 0.4))

	# Heavy Duty Front Tubular Bull Bar & Skid Plate
	var bar_m := BoxMesh.new()
	bar_m.size = Vector3(1.9, 0.38, 0.25)
	_create_part(bar_m, steel, Vector3(0, 0.24, 2.15))
	var skid_m := BoxMesh.new()
	skid_m.size = Vector3(1.1, 0.45, 0.08)
	_create_part(skid_m, steel, Vector3(0, 0.05, 2.18), Vector3(35, 0, 0))

	# Roof 4-Pod LED Lightbar (its headlights: brightens with L / K)
	var pod_mat := led_light.duplicate() as StandardMaterial3D
	for p in range(4):
		var pod_m := BoxMesh.new()
		pod_m.size = Vector3(0.18, 0.10, 0.12)
		var px: float = -0.45 + (p * 0.30)
		_create_part(pod_m, pod_mat, Vector3(px, 1.02, 0.4))
	_add_headlamps([Vector3(-0.3, 1.02, 0.5), Vector3(0.3, 1.02, 0.5)], pod_mat)

	# Open Rear Trophy Truck Bed with Tubular Frame
	var bed_floor_m := BoxMesh.new()
	bed_floor_m.size = Vector3(1.75, 0.14, 1.9)
	_create_part(bed_floor_m, steel, Vector3(0, 0.24, -1.2))
	# Roll Cage Bars
	var roll_m := BoxMesh.new()
	roll_m.size = Vector3(0.08, 0.75, 1.6)
	_create_part(roll_m, steel, Vector3(-0.78, 0.62, -1.0), Vector3(15, 0, 0))
	_create_part(roll_m, steel, Vector3(0.78, 0.62, -1.0), Vector3(15, 0, 0))

	# Full-Size Spare Knobby Tire Strapped in Bed!
	var spare_m := CylinderMesh.new()
	spare_m.top_radius = 0.40
	spare_m.bottom_radius = 0.40
	spare_m.height = 0.28
	_create_part(spare_m, tire_mat, Vector3(0, 0.55, -1.2), Vector3(45, 0, 0))

# 5. PHANTOM HYPERCAR (W16 / HYPERCAR)
func _build_hypercar_mesh() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.88, 0.92) # Liquid Mercury Silver Metallic
	paint.metallic = 0.94
	paint.roughness = 0.12
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0

	var carbon := StandardMaterial3D.new()
	carbon.albedo_color = Color(0.05, 0.05, 0.06)
	carbon.metallic = 0.4
	carbon.roughness = 0.25

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.04, 0.08, 0.12, 0.95)
	glass.metallic = 0.8
	glass.roughness = 0.05

	var red_tail := StandardMaterial3D.new()
	red_tail.albedo_color = Color(1.0, 0.02, 0.02)
	red_tail.emission_enabled = true
	red_tail.emission = Color(1.0, 0.02, 0.02)
	red_tail.emission_energy_multiplier = 5.0
	_brake_light_mats.append(red_tail)

	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color(0.9, 0.98, 1.0)
	hl_mat.emission_enabled = true
	hl_mat.emission = Color(0.9, 0.98, 1.0)
	hl_mat.emission_energy_multiplier = 6.0

	# Ultra-Low Aerodynamic Wedge Body
	var body_m := BoxMesh.new()
	body_m.size = Vector3(1.88, 0.28, 4.35)
	_create_part(body_m, paint, Vector3(0, 0.04, 0))

	# Carbon Front Diffuser & Splitter
	var split_m := BoxMesh.new()
	split_m.size = Vector3(1.92, 0.04, 0.55)
	_create_part(split_m, carbon, Vector3(0, -0.09, 2.22))

	# Teardrop Cockpit Canopy
	var canopy_m := BoxMesh.new()
	canopy_m.size = Vector3(1.28, 0.38, 1.7)
	_create_part(canopy_m, glass, Vector3(0, 0.36, -0.15))
	var roof_m := BoxMesh.new()
	roof_m.size = Vector3(0.98, 0.04, 1.2)
	_create_part(roof_m, carbon, Vector3(0, 0.55, -0.15))

	# Roof Induction Air Scoop
	var scoop_m := BoxMesh.new()
	scoop_m.size = Vector3(0.32, 0.08, 0.55)
	_create_part(scoop_m, carbon, Vector3(0, 0.60, -0.2))

	# Central Shark Fin Aerodynamic Stabilizer
	var fin_m := BoxMesh.new()
	fin_m.size = Vector3(0.04, 0.26, 1.4)
	_create_part(fin_m, carbon, Vector3(0, 0.56, -1.2), Vector3(-6, 0, 0))

	# Active Hydraulic Carbon Rear Wing
	var wing_m := BoxMesh.new()
	wing_m.size = Vector3(1.82, 0.05, 0.42)
	_create_part(wing_m, carbon, Vector3(0, 0.62, -2.05), Vector3(8, 0, 0))
	var st_m := BoxMesh.new()
	st_m.size = Vector3(0.05, 0.35, 0.15)
	_create_part(st_m, carbon, Vector3(-0.45, 0.44, -2.0))
	_create_part(st_m, carbon, Vector3(0.45, 0.44, -2.0))

	# Thin Laser Blade Headlights
	var hl_m := BoxMesh.new()
	hl_m.size = Vector3(0.34, 0.05, 0.24)
	_create_part(hl_m, hl_mat, Vector3(-0.68, 0.14, 2.12), Vector3(-15, 0, 0))
	_create_part(hl_m, hl_mat, Vector3(0.68, 0.14, 2.12), Vector3(-15, 0, 0))

	# Thin Full-Width Red Laser Taillight Ribbon
	var tail_m := BoxMesh.new()
	tail_m.size = Vector3(1.78, 0.04, 0.04)
	_create_part(tail_m, red_tail, Vector3(0, 0.18, -2.18))

# A part stretched between a fixed point on the body and a point on a wheel hub.
var _dynamic_links: Array = [] # [MeshInstance3D, body_anchor: Vector3, wheel_index: int, hub_offset: Vector3]

func _add_dynamic_link(m: Mesh, mat: Material, anchor: Vector3, wheel: int, hub_offset: Vector3) -> void:
	var mi := _create_part(m, mat, anchor)
	_dynamic_links.append([mi, anchor, wheel, hub_offset])

func _update_dynamic_links() -> void:
	for link in _dynamic_links:
		var mi: MeshInstance3D = link[0]
		if not is_instance_valid(mi):
			continue
		var mount: Node3D = wheel_mounts[link[2]]
		if mount == null:
			continue
		var a: Vector3 = link[1]
		var b: Vector3 = mount.position + link[3]
		var d: Vector3 = b - a
		var length: float = d.length()
		if length < 0.01:
			continue
		var dir: Vector3 = d / length
		if dir.y < 0.0:
			dir = -dir # cylinders are symmetric; keeps the rotation away from the degenerate up->down case
		var basis := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(1.0, length, 1.0))
		mi.transform = Transform3D(basis, (a + b) * 0.5)

# 6. GOLIATH 4x4 MONSTER TRUCK
# Body origin sits ~1.2 m above the ground; wheel centres are ~0.38 m below it, tyres reach ~0.45 m above it.
func _build_monster_truck_mesh() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = legacy_paint if legacy_paint.a > 0.0 else Color(0.36, 0.82, 0.10) # Toxic lime green
	paint.metallic = 0.6
	paint.roughness = 0.22
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0

	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.06, 0.06, 0.07)
	black.roughness = 0.45

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.85, 0.12, 0.10) # Red tube chassis
	frame_mat.metallic = 0.5
	frame_mat.roughness = 0.3

	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.94, 0.94, 0.96)
	chrome.metallic = 0.98
	chrome.roughness = 0.06

	var shock_mat := StandardMaterial3D.new()
	shock_mat.albedo_color = Color(1.0, 0.78, 0.05) # Yellow coil-overs
	shock_mat.metallic = 0.6
	shock_mat.roughness = 0.25

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.07, 0.10, 0.93)
	glass.metallic = 0.6
	glass.roughness = 0.08

	var led := StandardMaterial3D.new()
	led.albedo_color = Color(1, 1, 0.95)
	led.emission_enabled = true
	led.emission = Color(1, 1, 0.95)
	led.emission_energy_multiplier = 6.0

	var red_tail := StandardMaterial3D.new()
	red_tail.albedo_color = Color(0.95, 0.05, 0.05)
	red_tail.emission_enabled = true
	red_tail.emission = Color(1.0, 0.05, 0.05)
	red_tail.emission_energy_multiplier = 4.0
	_brake_light_mats.append(red_tail)

	# --- Tube frame chassis (visible under the body) ---
	var rail_m := BoxMesh.new()
	rail_m.size = Vector3(0.16, 0.2, 4.6)
	_create_part(rail_m, frame_mat, Vector3(-0.6, -0.02, 0))
	_create_part(rail_m, frame_mat, Vector3(0.6, -0.02, 0))
	var cross_m := BoxMesh.new()
	cross_m.size = Vector3(1.36, 0.14, 0.14)
	for z in [-2.1, -1.85, 0.0, 1.85, 2.1]:
		_create_part(cross_m, frame_mat, Vector3(0, -0.02, z))

	# Differentials on the frame; every wheel gets its OWN half-shaft and twin coil-over shocks
	# that stretch/compress with that wheel's suspension (updated each frame in _update_dynamic_links).
	var diff_m := SphereMesh.new()
	diff_m.radius = 0.24
	diff_m.height = 0.42
	_create_part(diff_m, chrome, Vector3(0, -0.2, 1.85))
	_create_part(diff_m, chrome, Vector3(0, -0.2, -1.85))

	var shaft_m := CylinderMesh.new()
	shaft_m.top_radius = 0.07
	shaft_m.bottom_radius = 0.07
	shaft_m.height = 1.0 # unit length, scaled to fit
	var shock_m := CylinderMesh.new()
	shock_m.top_radius = 0.075
	shock_m.bottom_radius = 0.075
	shock_m.height = 1.0
	for w in range(4):
		var sx: float = -1.0 if w % 2 == 0 else 1.0
		var z: float = 1.85 if w < 2 else -1.85
		# half-shaft: diff -> inner side of the hub
		_add_dynamic_link(shaft_m, black, Vector3(sx * 0.2, -0.2, z), w, Vector3(-sx * 0.45, 0.0, 0.0))
		# two shocks: high on the frame -> axle near the hub
		for dz in [-0.22, 0.22]:
			_add_dynamic_link(shock_m, shock_mat, Vector3(sx * 0.62, 0.55, z + dz), w, Vector3(-sx * 0.5, 0.1, dz))

	# --- Pickup body shell, perched high above the tyres ---
	var body_m := BoxMesh.new()
	body_m.size = Vector3(2.5, 0.5, 4.9)
	_create_part(body_m, paint, Vector3(0, 0.72, 0))
	# Black side stripes
	var stripe_m := BoxMesh.new()
	stripe_m.size = Vector3(2.52, 0.08, 4.4)
	_create_part(stripe_m, black, Vector3(0, 0.62, 0))

	# Hood with a huge chrome supercharger blower poking through
	var hood_m := BoxMesh.new()
	hood_m.size = Vector3(2.3, 0.12, 1.7)
	_create_part(hood_m, paint, Vector3(0, 1.02, 1.55), Vector3(-3, 0, 0))
	var blower_m := BoxMesh.new()
	blower_m.size = Vector3(0.55, 0.32, 0.7)
	_create_part(blower_m, chrome, Vector3(0, 1.24, 1.45))
	var scoop_m := BoxMesh.new()
	scoop_m.size = Vector3(0.62, 0.22, 0.45)
	_create_part(scoop_m, black, Vector3(0, 1.5, 1.5))

	# Cab
	var cab_m := BoxMesh.new()
	cab_m.size = Vector3(2.15, 0.78, 1.7)
	_create_part(cab_m, glass, Vector3(0, 1.36, -0.15))
	var roof_m := BoxMesh.new()
	roof_m.size = Vector3(2.2, 0.1, 1.45)
	_create_part(roof_m, paint, Vector3(0, 1.8, -0.22))
	var pillar_m := BoxMesh.new()
	pillar_m.size = Vector3(0.1, 0.78, 0.1)
	for px in [-1.05, 1.05]:
		for pz in [0.68, -0.98]:
			_create_part(pillar_m, paint, Vector3(px, 1.36, pz))

	# Roof LED light bar
	var bar_m := BoxMesh.new()
	bar_m.size = Vector3(1.9, 0.14, 0.18)
	_create_part(bar_m, black, Vector3(0, 1.92, 0.35))
	for i in range(6):
		var pod_m := BoxMesh.new()
		pod_m.size = Vector3(0.22, 0.1, 0.06)
		_create_part(pod_m, led, Vector3(-0.8 + i * 0.32, 1.92, 0.45))

	# Open bed with tailgate
	var bed_side_m := BoxMesh.new()
	bed_side_m.size = Vector3(0.1, 0.35, 1.75)
	_create_part(bed_side_m, paint, Vector3(-1.2, 1.14, -1.55))
	_create_part(bed_side_m, paint, Vector3(1.2, 1.14, -1.55))
	var tailgate_m := BoxMesh.new()
	tailgate_m.size = Vector3(2.5, 0.35, 0.1)
	_create_part(tailgate_m, paint, Vector3(0, 1.14, -2.42))

	# Twin chrome exhaust stacks behind the cab
	var stack_m := CylinderMesh.new()
	stack_m.top_radius = 0.09
	stack_m.bottom_radius = 0.09
	stack_m.height = 1.3
	_create_part(stack_m, chrome, Vector3(-0.75, 1.55, -1.12))
	_create_part(stack_m, chrome, Vector3(0.75, 1.55, -1.12))

	# Front: chrome grille, headlights, steel push bar
	var grille_m := BoxMesh.new()
	grille_m.size = Vector3(1.5, 0.36, 0.08)
	_create_part(grille_m, chrome, Vector3(0, 0.78, 2.46))
	var hl_m := BoxMesh.new()
	hl_m.size = Vector3(0.36, 0.18, 0.08)
	var head := led.duplicate() as StandardMaterial3D # its own glass: brightens with the lights
	_create_part(hl_m, head, Vector3(-0.95, 0.8, 2.46))
	_create_part(hl_m, head, Vector3(0.95, 0.8, 2.46))
	_add_headlamps([Vector3(-0.95, 0.8, 2.52), Vector3(0.95, 0.8, 2.52)], head)
	var push_m := BoxMesh.new()
	push_m.size = Vector3(2.3, 0.16, 0.16)
	_create_part(push_m, black, Vector3(0, 0.42, 2.5))

	# Taillights
	var tl_m := BoxMesh.new()
	tl_m.size = Vector3(0.3, 0.2, 0.06)
	_create_part(tl_m, red_tail, Vector3(-1.05, 1.0, -2.47))
	_create_part(tl_m, red_tail, Vector3(1.05, 1.0, -2.47))

func toggle_slow_mo() -> void:
	if Engine.time_scale < 0.9:
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = 0.2

func _physics_process(delta: float) -> void:
	_prevent_tunnelling()
	_read_inputs(delta)
	_calculate_g_forces(delta)
	_apply_aerodynamics(delta)
	_process_automatic_transmission(delta)
	_update_drivetrain(delta)
	_simulate_suspension_and_tires(delta)
	_monster_wall_climb()
	_update_wheel_visuals(delta)
	_update_body_damping(delta)

# Monster truck only: it can drive up a vertical wall. Nose into the wall with the throttle on: the
# front tips up and the truck rolls onto the wall face. While its tyres are on a steep surface they
# are pressed onto it (like suction) and gravity along the wall is mostly cancelled, so the engine
# can climb it. Lift off and it peels away and falls.
func _monster_wall_climb() -> void:
	wall_climbing = false
	if not is_monster or _throttle_input < 0.15 or current_gear < 2:
		return
	var b: Basis = global_transform.basis
	var g: float = mass * 9.81
	# 1) wall right in front: tip the nose up onto it
	var q := PhysicsRayQueryParameters3D.create(global_position + b.y * 0.3, global_position + b.y * 0.3 + b.z * 6.0)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.normal.dot(b.y) < 0.7 and hit.normal.dot(-b.z) > 0.5 and not hit.collider.has_meta("no_climb"):
		var axis: Vector3 = b.y.cross(hit.normal).normalized() # turns the underside towards the wall
		angular_velocity = angular_velocity.lerp(axis * 2.6, 0.25)
		apply_central_force(Vector3.UP * g * 1.3 * _throttle_input)
		apply_central_force(-hit.normal * g * 0.4)
	# 2) tyres on a steep surface: stick to it and climb
	var n := Vector3.ZERO
	var count: int = 0
	for i in 4:
		if wheel_is_grounded[i]:
			n += wheel_contact_normal[i]
			count += 1
	if count < 2:
		return
	n = n.normalized()
	if n.y > 0.75: # flatter than ~40 deg: normal driving
		return
	wall_climbing = true
	apply_central_force(-n * g * 1.3) # suction onto the face
	var g_along: Vector3 = Vector3.DOWN - n * Vector3.DOWN.dot(n)
	apply_central_force(-g_along * g * 0.85 * _throttle_input)

# The strong rotation damping that keeps the car calm on its wheels made it fly and crash like a
# plank (no tumbling, no nose dive, no spin off a wall). In the air and for a moment after a hit
# (5 G+: a wall, a hard landing) the body rotates freely; on the wheels it settles back.
func _update_body_damping(delta: float) -> void:
	var dv: float = (linear_velocity - _prev_lin_vel).length() / maxf(delta, 0.001)
	_prev_lin_vel = linear_velocity
	if dv > 50.0:
		_impact_t = 0.7
	_impact_t = maxf(_impact_t - delta, 0.0)
	var airborne: bool = not wheel_is_grounded.has(true)
	var free_k: float = clampf(_impact_t / 0.4, 0.0, 1.0)
	# Power slide at low speed with TCS off (burnout turning into a donut): the spinning rear tyres
	# let go sideways and the car must be free to pivot round its front wheels.
	if not tcs_enabled and not is_burnout:
		var rear_spin: float = maxf(absf(wheel_long_slip[2]), absf(wheel_long_slip[3]))
		free_k = maxf(free_k, clampf((rear_spin - 2.0) / 4.0, 0.0, 1.0) * clampf(1.0 - (linear_velocity.length() - 8.0) / 12.0, 0.0, 1.0))
	angular_damp = 0.6 if airborne else lerpf(3.2, 0.3, free_k)

# Safety net for big drops: at high speed the body can pass through a thin ground mesh in one
# physics step and get stuck inside it. If the car's centre crossed a surface since the last
# step, put it back on the outside and remove the velocity going into it.
func _prevent_tunnelling() -> void:
	var pos: Vector3 = global_position
	if linear_velocity.length() > 10.0 and _prev_body_pos != Vector3.INF:
		var q := PhysicsRayQueryParameters3D.create(_prev_body_pos, pos)
		q.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			var n: Vector3 = hit.normal
			var clearance: float = (tire_radius + suspension_rest_length) if n.y > 0.6 else 1.2
			global_position = hit.position + n * clearance
			var into: float = linear_velocity.dot(n)
			if into < 0.0:
				linear_velocity -= n * into
			pos = global_position
	_prev_body_pos = pos

# Calibrated pedal position 0..1 from its axis value at rest and fully pressed.
func _wheel_pedal(dev: int, pedal: String) -> float:
	var axis: int = int(wheel_cfg.get(pedal + "_axis", -1))
	if axis < 0:
		return 0.0
	var rest: float = float(wheel_cfg.get(pedal + "_rest", 1.0))
	var full: float = float(wheel_cfg.get(pedal + "_full", -1.0))
	if absf(full - rest) < 0.05:
		return 0.0
	var p: float = clampf((Input.get_joy_axis(dev, axis) - rest) / (full - rest), 0.0, 1.0)
	return 0.0 if p < 0.02 else p # tiny dead zone at rest

# H-pattern shifter (wheel sets, manual mode): the gear follows the lever. Lever in the middle
# (no gear button held) = neutral. Gears that the car doesn't have are ignored.
func _read_h_shifter(dev: int) -> void:
	if is_automatic:
		return
	var keys: Array = ["hr_btn", "h1_btn", "h2_btn", "h3_btn", "h4_btn", "h5_btn", "h6_btn", "h7_btn"]
	var gears: Array = [0, 2, 3, 4, 5, 6, 7, 8]
	var any_set: bool = false
	var wanted: int = 1 # neutral
	for k in range(keys.size()):
		var b: int = int(wheel_cfg.get(keys[k], -1))
		if b < 0:
			continue
		any_set = true
		if Input.is_joy_button_pressed(dev, b) and gears[k] < gear_ratios.size():
			wanted = gears[k]
	if not any_set or wanted == current_gear or _is_shifting:
		return
	_target_gear = wanted
	_start_shift()

func _is_wheel_device(dev: int) -> bool:
	return bool(wheel_cfg.get("enabled", false)) and dev == int(wheel_cfg.get("device", 0))

func _read_inputs(delta: float) -> void:
	# Steering: Key A / Left Arrow / Left Stick turn LEFT
	#           Key D / Right Arrow / Right Stick turn RIGHT
	# Keyboard steering through the (rebindable) actions. Positive = left.
	var raw_steer: float = 0.0
	if Input.is_action_pressed("steer_left"):
		raw_steer += 1.0
	if Input.is_action_pressed("steer_right"):
		raw_steer -= 1.0

	# Steering wheel set: the car's front wheels follow the real wheel 1:1 through a normal steering
	# ratio (e.g. 900° wheel: full lock at ~490° of rotation), pedals use their calibrated range.
	using_wheel = false
	var gamepad_ok: bool = true # device 0 is read as a gamepad unless it is the wheel
	var w_throttle: float = 0.0
	var w_brake: float = 0.0
	var w_clutch: float = -1.0
	var w_handbrake: bool = false
	var w_handbrake_lever: float = 0.0
	if bool(wheel_cfg.get("enabled", false)):
		var dev: int = int(wheel_cfg.get("device", 0))
		if Input.get_connected_joypads().has(dev):
			using_wheel = true
			gamepad_ok = dev != 0
			var v: float = Input.get_joy_axis(dev, int(wheel_cfg.get("steer_axis", 0)))
			if bool(wheel_cfg.get("steer_invert", false)):
				v = -v
			var wheel_deg: float = v * float(wheel_cfg.get("range", 900.0)) * 0.5
			if raw_steer == 0.0: # keyboard keys still win while pressed
				raw_steer = clampf(-wheel_deg / (max_steer_angle_deg * STEER_RATIO), -1.0, 1.0)
			w_throttle = _wheel_pedal(dev, "throttle")
			w_brake = _wheel_pedal(dev, "brake")
			if int(wheel_cfg.get("clutch_axis", -1)) >= 0:
				w_clutch = _wheel_pedal(dev, "clutch")
			var hb: int = int(wheel_cfg.get("handbrake_btn", -1))
			w_handbrake = hb >= 0 and Input.is_joy_button_pressed(dev, hb)
			w_handbrake_lever = _wheel_pedal(dev, "handbrake") # analog lever (0 if none)
			_read_h_shifter(dev)

	# Gamepad Left Analog Stick Steering (dead zone from Settings)
	var joy_steer: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X) if gamepad_ok else 0.0
	if absf(joy_steer) > joy_deadzone:
		# rescale so steering starts smoothly at the edge of the dead zone
		raw_steer = -signf(joy_steer) * (absf(joy_steer) - joy_deadzone) / (1.0 - joy_deadzone)

	if input_blocked:
		raw_steer = 0.0

	# Turbo Boost (rebindable key, or gamepad left stick click)
	if not input_blocked and (Input.is_action_pressed("turbo") or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK)):
		trigger_turbo_boost()

	var speed_mps: float = linear_velocity.length()
	# Speed-sensitive steering (like a real steering rack + driver input):
	# ~35 deg when parking, ~18 deg at 70 km/h, ~11 deg at 145 km/h, ~9 deg at 180 km/h, ~6.5 deg at 250 km/h.
	var speed_steer_factor: float = clampf(1.0 / (1.0 + pow(speed_mps / 24.0, 1.4)), 0.14, 1.0)
	if using_wheel:
		speed_steer_factor = 1.0 # a real wheel: the driver's hands decide, no speed limiting
	# Countersteer: in a slide the wheels may turn as far as the slide angle (+8 deg) at any speed.
	# The speed limit kept them at ~18 deg in a 40 deg drift, so the front tyres went on pushing the
	# nose further round instead of catching the car.
	var countersteer: bool = false
	var v_loc: Vector3 = global_transform.basis.inverse() * linear_velocity
	if not using_wheel and speed_mps > 5.0 and v_loc.z > 1.0:
		var beta: float = rad_to_deg(atan2(v_loc.x, v_loc.z)) # slide angle, + = travelling to the car's left
		if raw_steer * beta > 0.0 and absf(beta) > 5.0:
			countersteer = true
			speed_steer_factor = maxf(speed_steer_factor, minf((absf(beta) + 8.0) / max_steer_angle_deg, 1.0))
	var target_steer: float = raw_steer * max_steer_angle_deg * speed_steer_factor
	# Keyboard steering ramps in more gently at speed, but always returns to centre quickly.
	var steering_in: bool = absf(target_steer) > absf(_current_steer_angle) and signf(target_steer) == signf(_current_steer_angle) or absf(_current_steer_angle) < 0.01
	var steer_rate: float = 18.0
	if steering_in and absf(raw_steer) > 0.0:
		steer_rate = lerpf(14.0, 8.5, clampf(speed_mps / 50.0, 0.0, 1.0))
	if countersteer:
		steer_rate = 20.0 # catching a slide needs quick hands
	if using_wheel and absf(raw_steer) > 0.0 and not (Input.is_action_pressed("steer_left") or Input.is_action_pressed("steer_right")):
		steer_rate = 40.0 # the wheel itself is the input: follow it almost directly
	_current_steer_angle = lerpf(_current_steer_angle, target_steer, clampf(delta * steer_rate * steer_sensitivity, 0.0, 1.0))

	# Keyboard & Gamepad Throttle
	var raw_throttle: float = maxf(Input.get_action_raw_strength("throttle"), w_throttle)
	# Gamepad Right Trigger (RT / R2)
	var joy_rt: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) if gamepad_ok else 0.0
	if joy_rt > 0.05:
		raw_throttle = maxf(raw_throttle, joy_rt)

	# Keyboard & Gamepad Brake
	var raw_brake: float = maxf(Input.get_action_raw_strength("brake"), w_brake)
	# Gamepad Left Trigger (LT / L2)
	var joy_lt: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) if gamepad_ok else 0.0
	if joy_lt > 0.05:
		raw_brake = maxf(raw_brake, joy_lt)

	# Keyboard & Gamepad Handbrake
	var raw_handbrake: float = 0.0
	if Input.is_action_pressed("handbrake") or w_handbrake or (gamepad_ok and (Input.is_joy_button_pressed(0, JOY_BUTTON_B) or Input.is_joy_button_pressed(0, JOY_BUTTON_A))):
		raw_handbrake = 1.0
	raw_handbrake = maxf(raw_handbrake, w_handbrake_lever) # analog lever: pull harder, brake harder

	# Clutch pedal (wheel sets): only in manual mode and never fighting an automatic gear change
	if w_clutch >= 0.0 and not is_automatic and not _is_shifting:
		clutch_pedal = w_clutch

	# Garage menu open: the driver's inputs are ignored (keys go to the menu), but the car just
	# keeps rolling as it was - it no longer brakes to a stop.
	if input_blocked:
		raw_throttle = 0.0
		raw_brake = 0.0
		raw_handbrake = 0.0

	_handbrake_input = raw_handbrake
	is_handbrake_active = (_handbrake_input > 0.1)
	# Raw pedal positions (keyboard = 0/1, gamepad triggers = analog) for the HUD
	pedal_throttle = raw_throttle
	pedal_brake = raw_brake

	# Automatic gearbox direction logic (forward is +Z).
	if is_automatic:
		var forward_speed: float = linear_velocity.dot(global_transform.basis.z)
		# Braking to a stop keeps the car stopped (brake held = car held). Only a NEW press of the
		# pedal once standing (both pedals released in between) selects the other direction.
		if absf(forward_speed) > 1.5:
			_dir_change_armed = false
		elif absf(forward_speed) < 0.5 and raw_brake < 0.1 and raw_throttle < 0.1:
			_dir_change_armed = true
		if current_gear >= 2:
			# Stopped and pressing S again -> reverse. Only the driver picks the direction: rolling back
			# a little (on a hill, off a wall) stays in D like a real automatic - it used to drop into R.
			if _dir_change_armed and forward_speed < 0.8 and raw_brake > 0.2 and raw_throttle < 0.1:
				_engage_gear_now(0)
		elif current_gear == 0:
			if _dir_change_armed and forward_speed > -0.8 and raw_throttle > 0.2 and raw_brake < 0.1:
				_engage_gear_now(2)
		elif current_gear == 1: # neutral in auto mode: pick a direction from the pedals
			if raw_throttle > 0.2:
				_engage_gear_now(2)
			elif raw_brake > 0.2:
				_engage_gear_now(0)
		if current_gear == 0:
			_throttle_input = raw_brake # S drives backwards
			_brake_input = raw_throttle # W brakes while rolling backwards
		else:
			_throttle_input = raw_throttle
			_brake_input = raw_brake
	else:
		_throttle_input = raw_throttle
		_brake_input = raw_brake
	if input_blocked:
		_throttle_input = 0.0
		_brake_input = 0.0

func _engage_gear_now(g: int) -> void:
	_clutch_slipping = true
	_auto_clutch = 0.0
	_slip_time = 0.0
	current_gear = g
	_target_gear = g
	_is_shifting = false
	clutch_pedal = 0.0
	_auto_shift_cooldown = 0.6

func _apply_aerodynamics(_delta: float) -> void:
	var speed_mps: float = linear_velocity.length()
	if speed_mps < 0.05:
		return
	var vel_dir: Vector3 = linear_velocity / speed_mps

	# Downforce pushes the car onto the road, growing with speed squared.
	if speed_mps > 6.0:
		var downforce_mag: float = clampf(downforce_coefficient * speed_mps * speed_mps, 0.0, mass * 9.81 * 1.5)
		apply_central_force(-global_transform.basis.y * downforce_mag)

	# Air drag (0.5 * rho * Cd * A * v^2) - what really limits top speed.
	apply_central_force(-vel_dir * drag_coefficient * speed_mps * speed_mps)

	# Tyre rolling resistance, faded in near standstill so a parked car doesn't jitter.
	var grounded_count: int = 0
	for g in wheel_is_grounded:
		if g:
			grounded_count += 1
	if grounded_count > 0:
		var rolling: float = 0.015 * mass * 9.81 * (float(grounded_count) / 4.0) * clampf(speed_mps, 0.0, 1.0)
		apply_central_force(-vel_dir * rolling)

func _process_automatic_transmission(delta: float) -> void:
	_since_upshift += delta
	# kickdown is the pedal being pushed down (time since it was last under 75%), not a held pedal
	_since_low_thr = 0.0 if _throttle_input < 0.75 else _since_low_thr + delta
	if absf(linear_velocity.dot(global_transform.basis.z)) < 1.5 or not is_automatic:
		_manual_hold = false
	if not is_automatic or _is_shifting:
		return
	if _auto_shift_cooldown > 0.0:
		_auto_shift_cooldown -= delta
		return

	if current_gear < 2:
		return

	# Shift decisions use the rpm the CAR'S SPEED gives (not spinning wheels), so wheelspin on a
	# hill never triggers a false upshift, and the box upshifts before the limiter even off-throttle
	# (e.g. rolling down a hill).
	var g_rpm: float = _ground_rpm(current_gear)
	var top_gear: int = gear_ratios.size() - 1

	if current_gear < top_gear:
		var next_rpm: float = _ground_rpm(current_gear + 1)
		# A real gearbox reads its output shaft (the driven wheels), so with wheelspin at speed it
		# still shifts at the limiter instead of bouncing off it. Pulling away slowly (e.g. on a hill)
		# only the car's speed counts, so spinning wheels there never cause an early upshift.
		var moving: bool = absf(linear_velocity.dot(global_transform.basis.z)) > 7.0
		var near_limit: bool = g_rpm > limiter_rpm - 300.0 or (_throttle_input > 0.05 and current_rpm > limiter_rpm - 200.0 and (g_rpm > limiter_rpm * 0.82 or moving))
		# Shift point follows the pedal like a real automatic: gentle throttle or cruising shifts
		# early (low revs), only a floored pedal holds the gear up to the limiter.
		var shift_rpm: float = lerpf(limiter_rpm * 0.42, limiter_rpm - 300.0, clampf(_throttle_input / 0.9, 0.0, 1.0))
		# off the throttle the gear is held (engine braking), no lift-off upshifts
		var early: bool = _throttle_input > 0.05 and _throttle_input < 0.85 and _brake_input < 0.1 and g_rpm > shift_rpm and next_rpm > limiter_rpm * 0.34
		# never into a gear the car would lug in right away (with wheelspin that caused 6-7-6-7 hunting)
		if (near_limit or (early and not _manual_hold)) and next_rpm > idle_rpm * 1.6 and next_rpm > limiter_rpm * 0.33:
			shift_up()
			_auto_shift_cooldown = 0.5
			_since_upshift = 0.0
			return

	if current_gear > 2:
		var prev_rpm: float = _ground_rpm(current_gear - 1)
		var lugging: bool = g_rpm < limiter_rpm * 0.28
		# kickdown: pedal just floored -> one jump to the lowest gear that stays clear of the limiter;
		# a held pedal never re-triggers it, so no 2-3-2-3 hunting after an upshift
		var kickdown: bool = not _manual_hold and _throttle_input > 0.9 and _since_low_thr < 0.5 and current_rpm < limiter_rpm * 0.75
		if (lugging or kickdown) and prev_rpm < limiter_rpm - 900.0:
			# kickdown goes straight to the lowest gear that stays clear of the limiter (6->4, not 6->5->4)
			var target: int = current_gear - 1
			if kickdown:
				while target > 2 and _ground_rpm(target - 1) < limiter_rpm - 900.0:
					target -= 1
			_target_gear = target
			_start_shift()
			_auto_shift_cooldown = 0.6
			return

# Engine rpm the given gear would have at the car's current ground speed.
func _ground_rpm(gear_idx: int) -> float:
	var fwd: float = absf(linear_velocity.dot(global_transform.basis.z))
	return fwd / maxf(tire_radius, 0.05) * absf(gear_ratios[gear_idx]) * final_drive_ratio * (60.0 / TAU)

func _is_driven(i: int) -> bool:
	if drivetrain_mode == "RWD":
		return i >= 2
	if drivetrain_mode == "FWD":
		return i < 2
	return true

# A gear change asked for by the driver. In automatic mode it is held (no early auto upshift) so the
# car stays in the gear picked, like paddles on an automatic; the box takes over again once stopped.
func _driver_shift(up: bool) -> void:
	if is_automatic:
		_manual_hold = true
	if up:
		shift_up()
	else:
		shift_down()

func shift_up() -> void:
	if current_gear < gear_ratios.size() - 1 and not _is_shifting:
		# hard upshift on a petrol car (each car has its own bang, see AudioSynth.BANGS): the ignition cut lights unburnt fuel in the exhaust
		var red_zone: bool = is_limiter_active or current_rpm >= limiter_rpm - 250.0 # same red zone as the rev bar
		if engine_fuel != "dizel" and current_gear >= 2 and red_zone and _throttle_input > 0.6 and randf() < 0.67: # petrol only: diesels don't backfire
			backfire_count += 1
			for e in exhaust_smokes:
				e.backfire()
		_target_gear = current_gear + 1
		_start_shift()

func shift_down() -> void:
	if current_gear > 0 and not _is_shifting:
		_target_gear = current_gear - 1
		_start_shift()

func _start_shift() -> void:
	_is_shifting = true
	_shift_timer = shift_delay_seconds
	clutch_pedal = 1.0

func _calculate_g_forces(delta: float) -> void:
	var accel: Vector3 = (linear_velocity - _previous_linear_velocity) / maxf(delta, 0.001)
	_previous_linear_velocity = linear_velocity
	var local_accel: Vector3 = global_transform.basis.inverse() * accel
	g_force_lateral = lerpf(g_force_lateral, local_accel.x / 9.81, delta * 12.0)
	g_force_longitudinal = lerpf(g_force_longitudinal, local_accel.z / 9.81, delta * 12.0)
	current_speed_kmh = linear_velocity.length() * 3.6

const RPM_DROP_RATE: float = 6000.0 # rpm per second the engine can lose at most (outside gear changes)
func _update_drivetrain(delta: float) -> void:
	var rpm_before: float = current_rpm
	if _is_shifting:
		_shift_timer -= delta
		if _shift_timer <= 0.0:
			current_gear = _target_gear
			_is_shifting = false
			clutch_pedal = 0.0

	# Engine is connected to the DRIVEN wheels (their own spin, incl. wheelspin or wheels in the air).
	var avg_drive_wheel_speed: float = 0.0
	var count: int = 0
	for i in range(4):
		if _is_driven(i):
			avg_drive_wheel_speed += absf(wheel_angular_velocity[i])
			count += 1
	if count > 0:
		avg_drive_wheel_speed /= float(count)

	var active_ratio: float = gear_ratios[current_gear]
	var transmission_rpm: float = avg_drive_wheel_speed * absf(active_ratio) * final_drive_ratio * (60.0 / TAU)

	# Is the drivetrain trying to turn the engine BACKWARDS? (rolling back in a forward gear, or
	# rolling forward in R). An engine can't run backwards: it holds near idle and its compression
	# resists the wheels instead (it used to read |speed|, so the revs rose and engine braking
	# pushed the car even faster the wrong way).
	var signed_wheel: float = 0.0
	if count > 0:
		for i in range(4):
			if _is_driven(i):
				signed_wheel += wheel_angular_velocity[i]
		signed_wheel /= float(count)
	var engine_dir_speed: float = signed_wheel * signf(active_ratio)
	_wrong_way_rpm = 0.0
	if active_ratio != 0.0 and engine_dir_speed < -0.3:
		_wrong_way_rpm = -engine_dir_speed * absf(active_ratio) * final_drive_ratio * (60.0 / TAU)
		transmission_rpm = 0.0

	# Rev limiter cut logic (preserved as requested)
	# In the top gear the soft limiter (see _get_engine_torque_nm) holds the revs just under the
	# limit, so the hard cut only fires if something pushes the engine past it (e.g. downhill).
	var top_gear_now: bool = current_gear == gear_ratios.size() - 1
	if current_rpm >= limiter_rpm + (90.0 if top_gear_now else 0.0):
		is_limiter_active = true
		_limiter_timer = 0.07
	if is_limiter_active:
		_limiter_timer -= delta
		if _limiter_timer <= 0.0:
			is_limiter_active = false
	limiter_zone = _throttle_input > 0.3 and current_rpm >= limiter_rpm - 80.0

	# Turbo Boost (Shift Key) Timer & Cooldown Update
	if turbo_boost_active:
		turbo_boost_timer -= delta
		turbo_boost_ready = false
		if turbo_boost_timer <= 0.0 or current_gear == 0: # also ends when shifted into reverse
			turbo_boost_active = false
			turbo_boost_cooldown_timer = turbo_boost_cooldown
	elif turbo_boost_cooldown_timer > 0.0:
		turbo_boost_cooldown_timer -= delta
		turbo_boost_ready = false
		if turbo_boost_cooldown_timer <= 0.0:
			turbo_boost_cooldown_timer = 0.0
			turbo_boost_ready = true
	else:
		turbo_boost_ready = true

	# Turbo spool & Boost surge
	if turbo_enabled:
		# Full boost from ~4200 rpm (legacy cars) or just before the torque plateau (real engines)
		var spool_rpm: float = maxf(torque_rpm_from * 0.95, idle_rpm * 1.5) if use_torque_curve else 4200.0
		var target_boost: float = turbo_max_boost_bar * _throttle_input * clampf(current_rpm / spool_rpm, 0.0, 1.0)
		if _is_shifting and use_torque_curve and not (is_automatic and gearbox_type == "dct"): # a DCT shifts without lifting
			target_boost = 0.0 # throttle closes for the gear change: boost drops and must build again
		if turbo_boost_active:
			target_boost = turbo_max_boost_bar + 1.6 # Massive overboost!
		var spool_spd: float = turbo_spool_rate * (3.5 if turbo_boost_active else 1.0)
		if target_boost < turbo_boost_bar and _throttle_input < 0.15:
			spool_spd *= 5.0 # lifting off: the blow-off valve dumps the pressure at once
		turbo_boost_bar = lerpf(turbo_boost_bar, target_boost, delta * spool_spd)
	else:
		if turbo_boost_active:
			turbo_boost_bar = lerpf(turbo_boost_bar, 1.4, delta * 5.0)
		else:
			turbo_boost_bar = 0.0

	var effective_throttle: float = 0.0 if is_limiter_active else _throttle_input
	var clutch_engagement: float = 1.0 - clutch_pedal

	if _is_shifting:
		# Gear change: revs drop/rise to match the gear being engaged (rev-matching), no flare
		var next_rpm: float = avg_drive_wheel_speed * absf(gear_ratios[_target_gear]) * final_drive_ratio * (60.0 / TAU)
		current_rpm = move_toward(current_rpm, maxf(next_rpm, idle_rpm), 25000.0 * delta)
	elif current_gear == 1 or clutch_engagement < 0.05: # neutral, or clutch fully pressed
		# Neutral: the engine revs freely. Throttle spins it up quickly, internal friction slows
		# it down. Part throttle settles at a steady rpm; full throttle bounces just under the
		# limiter (a short, tight cut) instead of the old big swings down towards idle.
		if effective_throttle > 0.05:
			var target_free_rpm: float = idle_rpm + effective_throttle * (limiter_rpm + 80.0 - idle_rpm)
			current_rpm = move_toward(current_rpm, target_free_rpm, (5000.0 + 10000.0 * effective_throttle) * delta)
		else:
			current_rpm = move_toward(current_rpm, idle_rpm, (1500.0 + current_rpm * 0.5) * delta)
	else:
		_update_clutch(delta, transmission_rpm)
	if current_gear == 1 or _is_shifting and _target_gear == 1:
		_clutch_slipping = true # next gear starts from a slipping clutch / converter
		_auto_clutch = 0.0

	# The flywheel and crank can't lose revs instantly: when spinning tyres hook up (or the clutch
	# bites) the revs fall over a few tenths of a second (~6000 rpm/s), not in one frame.
	# (gear changes have their own rev-matching above)
	if not _is_shifting:
		current_rpm = maxf(current_rpm, rpm_before - RPM_DROP_RATE * delta)
	# Rolling down a hill can drive the engine past the limiter (no fuel, engine braking only).
	current_rpm = clampf(current_rpm, idle_rpm * 0.5, max_rpm * 1.12)

# Full-load torque (Nm) of a realistic engine: rises from idle to the peak, stays flat over the
# turbo plateau, then falls to the torque that gives the rated power, and tails off to the limiter.
func _curve_torque(rpm: float) -> float:
	var t_pk: float = torque_peak_nm
	var t_pw: float = minf(peak_horsepower * 7023.5 / maxf(power_rpm, 1.0), t_pk) # PS -> Nm at power peak
	# off-boost torque: diesels (big turbo, high compression) are weakest before the turbo wakes up
	var t_idle: float = t_pk * ((0.32 if engine_fuel == "dizel" else 0.45) if turbo_enabled else 0.62)
	if rpm <= torque_rpm_from:
		return lerpf(t_idle, t_pk, smoothstep(idle_rpm * 0.8, torque_rpm_from, rpm))
	if rpm <= torque_rpm_to:
		return t_pk
	if rpm <= power_rpm:
		return lerpf(t_pk, t_pw, (rpm - torque_rpm_to) / maxf(power_rpm - torque_rpm_to, 1.0))
	return lerpf(t_pw, t_pw * 0.8, clampf((rpm - power_rpm) / maxf(max_rpm - power_rpm, 1.0), 0.0, 1.0))

# In gear: the clutch (manual) or torque converter (automatic) between engine and gearbox.
# Locked: the engine turns with the wheels. Slipping (pulling away): the engine speed follows
# its own torque balance - throttle torque spins it up, the clutch load pulls it down - so the
# revs rise, dip as the clutch bites, then climb with the car's speed (they used to sit flat at
# a fixed "launch rpm" until the car caught up).
func _update_clutch(delta: float, w_rpm: float) -> void:
	var prev_rpm_for_rate: float = _prev_clutch_rpm
	_prev_clutch_rpm = current_rpm
	var t_net: float = _get_engine_torque_nm() + _idle_governor_torque(current_rpm)
	var peak_tq: float = torque_peak_nm if use_torque_curve else peak_horsepower * 7120.0 / 5252.0
	# Lowest revs the engine runs at before the clutch must slip (old engines lug lower)
	var floor_rpm: float = idle_rpm * (0.72 if engine_classic else 0.93)
	var pedal_eng: float = 1.0 - clutch_pedal # wheel-set clutch pedal (1 = released)
	var wheel_clutch: bool = using_wheel and int(wheel_cfg.get("clutch_axis", -1)) >= 0 and not is_automatic

	if not _clutch_slipping:
		current_rpm = lerpf(current_rpm, w_rpm, clampf(delta * 18.0, 0.0, 1.0))
		_slip_time = 0.0
		_clutch_torque = 0.0
		_tc_mult = 1.0
		if w_rpm < floor_rpm or (wheel_clutch and pedal_eng < 0.9):
			_clutch_slipping = true
			_auto_clutch = 1.0 if w_rpm >= floor_rpm else 0.5
		return

	var slip: float = current_rpm - w_rpm
	var cap: float = 0.0 # most torque the clutch can pass right now
	var eng: float = 1.0
	# Automatic with a torque converter - or a dual-clutch box (GT-R, Chiron), which pulls away
	# on a clutch like the manual one, just with a higher launch speed
	var use_tc: bool = is_automatic and gearbox_type != "dct"
	var stall_rpm: float = idle_rpm + (limiter_rpm - idle_rpm) * 0.24 # ~2000-2700 rpm, like real converters
	if use_tc:
		# Torque converter: passes torque ~ slip², stalls at ~24% of the rev range at full load,
		# multiplies torque (up to 2x) while the car is slow, then locks up.
		var k: float = _full_load_torque(stall_rpm) / (stall_rpm * stall_rpm)
		cap = k * slip * slip
		var speed_ratio: float = clampf(w_rpm / maxf(current_rpm, 1.0), 0.0, 1.0)
		_tc_mult = lerpf(2.0, 1.0, clampf(speed_ratio / 0.85, 0.0, 1.0))
	else:
		_tc_mult = 1.0
		if wheel_clutch:
			eng = pedal_eng
		else:
			# Automatic clutch for keyboard/gamepad drivers, working like a driver's left foot:
			# it feeds the clutch in while the revs are above a launch speed that grows with the
			# throttle, and eases off when they drop below it - so the revs flare, dip as the clutch
			# bites, settle, then rise with the car. Old engines are launched lower (revs may sag
			# under idle at little throttle); it lets go when stopping so the engine never stalls.
			var launch_frac: float = 0.24 if (is_automatic and gearbox_type == "dct") else 0.18 # DCT launches a bit higher
			var launch: float = idle_rpm * (0.78 if engine_classic else 1.15) + _throttle_input * (limiter_rpm - idle_rpm) * launch_frac
			launch = maxf(launch, floor_rpm * 1.03)
			# A driver lets the clutch out progressively: within ~1.5 s the clutch closes and the revs
			# come down to what the car's speed gives (in a high gear the engine then lugs and pulls
			# up from low revs) instead of sitting at one launch rpm for many seconds.
			if _throttle_input > 0.05:
				_slip_time += delta
			launch = lerpf(launch, maxf(w_rpm + 150.0, floor_rpm * 1.05), clampf(_slip_time / 1.5, 0.0, 1.0))
			if _throttle_input > 0.05 and _auto_clutch < 0.12:
				_auto_clutch = 0.12 # straight to the bite point (no dead pedal travel)
			# look a little ahead: ease off before the revs fall through the launch speed
			var rpm_ahead: float = current_rpm + (current_rpm - prev_rpm_for_rate) / maxf(delta, 0.001) * 0.15
			if _throttle_input > 0.05:
				if current_rpm > launch + 1000.0:
					# far above the launch speed (e.g. a big engine bouncing off the limiter):
					# just keep feeding the clutch in - the look-ahead would misread the limiter's dips
					_auto_clutch += delta * (1.2 + _throttle_input) * 1.5
				else:
					_auto_clutch += delta * clampf((rpm_ahead - launch) / 400.0, -4.0, 2.5 + 2.0 * _throttle_input)
				if current_rpm < floor_rpm:
					_auto_clutch -= delta * 4.0
				if absf(slip) < 150.0:
					_auto_clutch += delta * 3.0 # speeds nearly matched: let it fully out
			elif w_rpm < idle_rpm * 1.05:
				_auto_clutch -= delta * 3.0
			else:
				_auto_clutch += delta * 2.0 # rolling: let the clutch out (engine braking)
			_auto_clutch = clampf(_auto_clutch, 0.0, 1.0)
			eng = _auto_clutch
		cap = peak_tq * 1.5 * eng * eng
	# Brake held at a standstill with the throttle down (a launch from a brake stand): the clutch /
	# converter lets the engine rev freely; let go of the brake and the car launches.
	# (front-wheel drive spins its tyres instead - see the line lock in _simulate_suspension_and_tires)
	if _brake_input > 0.3 and _throttle_input > 0.1 and current_gear >= 2 and not wheel_clutch and drivetrain_mode != "FWD" and absf(linear_velocity.dot(global_transform.basis.z)) < 1.0:
		cap = 0.0
		_auto_clutch = 0.0
		_slip_time = 0.0
		_clutch_torque = 0.0
	# A converter's fluid torque cannot vanish from one step to the next: computed from last step's
	# wheel speed it did, so a spinning wheel caught up, lost all torque, stopped, and spun again
	# every other frame - automatics could hardly spin their tyres. Smoothing finds the real balance.
	_clutch_torque = lerpf(_clutch_torque, signf(slip) * cap, clampf(delta * 15.0, 0.0, 1.0)) if use_tc else signf(slip) * cap
	var inertia: float = maxf(engine_inertia, 0.08)
	var new_rpm: float = current_rpm + (t_net - _clutch_torque) / inertia * (60.0 / TAU) * delta
	# Engine and gearbox speeds meet: lock up if the clutch can hold the engine's torque
	if slip != 0.0 and signf(new_rpm - w_rpm) != signf(slip):
		var can_lock: bool = cap >= absf(t_net) * 0.9 and eng > 0.95 and w_rpm >= floor_rpm
		if use_tc:
			can_lock = _ground_rpm(current_gear) > idle_rpm * 1.25 # the CAR rolling, not wheelspin (burnouts)
		if can_lock:
			_clutch_slipping = false
			_clutch_torque = 0.0
			_tc_mult = 1.0
		new_rpm = w_rpm
	elif use_tc and _ground_rpm(current_gear) > idle_rpm * 1.25 and slip > 0.0 and (w_rpm / maxf(current_rpm, 1.0) > 0.93 or w_rpm > stall_rpm * 0.85):
		# lock-up clutch closes once the car is rolling (it used to wait for a 93% speed ratio,
		# which never came under full load - the converter kept slipping ~3000 rpm at top speed)
		_clutch_slipping = false
		new_rpm = w_rpm
	current_rpm = maxf(new_rpm, idle_rpm * 0.5)

# Torque the engine makes at this rpm with the pedal fully down (current boost included)
func _full_load_torque(rpm: float) -> float:
	if rpm < idle_rpm * 0.45:
		return 0.0 # about to stall: no useful torque
	var rpm_norm: float = (rpm - idle_rpm) / (max_rpm - idle_rpm)
	var torque_curve: float = sin(clampf(rpm_norm, 0.0, 1.0) * PI * 0.88 + 0.25)
	var base_torque: float = (peak_horsepower * 7120.0 / 5252.0) * torque_curve
	var boost_multiplier: float = 1.0 + (turbo_boost_bar * 0.7)
	if use_torque_curve:
		# Real engine data: the curve is the torque at full boost; with no boost yet (turbo lag)
		# a turbo engine makes ~60% of it. Gearbox/diff losses are taken off here too.
		base_torque = _curve_torque(rpm) * DRIVETRAIN_EFFICIENCY
		boost_multiplier = 1.0
		if turbo_enabled:
			boost_multiplier = lerpf(0.6, 1.0, clampf(turbo_boost_bar / maxf(turbo_max_boost_bar, 0.01), 0.0, 1.0))
	if turbo_boost_active:
		boost_multiplier *= 1.45 # Massive +45% extra torque kick when Shift turbo is active!
	# Below idle the engine labours: torque falls away towards stalling
	if rpm < idle_rpm:
		base_torque *= clampf((rpm - idle_rpm * 0.45) / (idle_rpm * 0.55), 0.0, 1.0)
	return base_torque * boost_multiplier

# Idle control: an engine at closed throttle still holds its idle speed (modern ECU strongly,
# old carburettor engines only weakly - their revs sag under load).
func _idle_governor_torque(rpm: float) -> float:
	var peak: float = peak_horsepower * 7120.0 / 5252.0 if not use_torque_curve else torque_peak_nm
	var strength: float = 0.10 if engine_classic else 0.30
	return peak * strength * clampf((idle_rpm + 60.0 - rpm) / 250.0, 0.0, 1.0)

func _get_engine_torque_nm() -> float:
	var full: float = _full_load_torque(current_rpm)
	# Rev limiter is a real FUEL CUT: no drive torque while it's active (it used to be sound only,
	# so the car kept accelerating at the limiter in every gear, including reverse).
	var throttle: float = 0.0 if is_limiter_active else _throttle_input
	# Factory top-speed limiter: smooth fuel trim over the last few km/h (no limiter crackle)
	if speed_limit_kmh > 0.0:
		throttle *= clampf((speed_limit_kmh - current_speed_kmh) / 4.0, 0.0, 1.0)
	# Top speed in the top gear: like a real ECU's top-speed / soft rev limiter, power fades out
	# smoothly over the last 250 rpm, so the car holds its top speed steadily instead of bouncing
	# off the hard cut forever (limiter crackle - full revs - limiter ...).
	if current_gear == gear_ratios.size() - 1 and throttle >= 0.05:
		throttle *= clampf((limiter_rpm + 20.0 - current_rpm) / 60.0, 0.0, 1.0) # holds the revs right at the limiter
		if throttle < 0.05:
			return 0.0
	if throttle < 0.05:
		# Engine braking off-throttle / during fuel cut, stronger at high rpm.
		var over: float = clampf((current_rpm - idle_rpm) / (max_rpm - idle_rpm), 0.0, 1.3)
		var eb: float = -(peak_horsepower * 7120.0 / 5252.0) * 0.18 * over * sqrt(over)
		# Limiter cut with the pedal still down: throttle is wide open, so there are hardly any
		# pumping losses. Only a little drag, and the car holds the limiter instead of surging.
		if is_limiter_active and _throttle_input > 0.05:
			eb *= 0.25
		return eb
	return full * throttle

func _simulate_suspension_and_tires(delta: float) -> void:
	var world := get_world_3d()
	if world == null:
		return
	var space_state := world.direct_space_state
	if space_state == null:
		return

	var up_vec: Vector3 = global_transform.basis.y
	var forward_vec: Vector3 = global_transform.basis.z
	var right_vec: Vector3 = global_transform.basis.x

	var active_gear_ratio: float = gear_ratios[current_gear]
	var clutch_engagement: float = 1.0 - clutch_pedal
	var engine_torque: float = _get_engine_torque_nm()
	var gear_mult_abs: float = absf(active_gear_ratio) * final_drive_ratio * clutch_engagement
	# Positive engine torque drives the car in the gear's direction. Engine braking (and the
	# resistance of an engine being forced backwards) instead acts like a brake on the driven
	# wheels: it always opposes their spin, whichever way they turn, and can stop them but never
	# spin them the other way.
	var total_drive_torque: float = 0.0
	var engine_drag_total: float = 0.0
	var slipping_now: bool = _clutch_slipping and current_gear != 1 and not _is_shifting
	if slipping_now:
		# Pulling away: the wheels get what the slipping clutch / torque converter passes on
		var t_c: float = _clutch_torque * _tc_mult
		if t_c >= 0.0:
			total_drive_torque = t_c * active_gear_ratio * final_drive_ratio
		else:
			engine_drag_total = -t_c * absf(active_gear_ratio) * final_drive_ratio
	else:
		if current_gear != 1:
			engine_torque += _idle_governor_torque(current_rpm) # idle control keeps pulling at low revs
		if engine_torque >= 0.0:
			total_drive_torque = engine_torque * active_gear_ratio * final_drive_ratio * clutch_engagement
		else:
			engine_drag_total = -engine_torque * gear_mult_abs
	if _wrong_way_rpm > 0.0:
		var peak_tq: float = peak_horsepower * 7120.0 / 5252.0
		# Manual: the clutch is locked, so the engine's compression nearly holds the car (like
		# parking in gear). Automatic: the torque converter slips, giving only a gentle resistance,
		# and the box then follows the car into R.
		var hold: float = 0.15 if is_automatic else 0.6
		engine_drag_total += peak_tq * hold * clampf(_wrong_way_rpm / 300.0, 0.0, 1.0) * gear_mult_abs

	var split: Array[float] = [0.0, 0.0, 0.5, 0.5] # RWD
	if drivetrain_mode == "FWD":
		split = [0.5, 0.5, 0.0, 0.0]
	elif drivetrain_mode != "RWD":
		split = [0.225, 0.225, 0.275, 0.275]
	var drive_torques: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var engine_drag: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i in range(4):
		drive_torques[i] = total_drive_torque * split[i]
		engine_drag[i] = engine_drag_total * split[i]

	# Traction control, like a real ECU: lets the driven tyre slip a little (that's where the grip
	# peaks) and smoothly trims engine torque on a wheel that spins beyond that, then gives it back.
	# (The old on/off 35% cut chattered; with TCS off the powerful cars spun up in every gear.)
	var speed_for_tcs: float = linear_velocity.length()
	for i in range(4):
		var want_cut: float = 0.0
		if tcs_enabled and not is_burnout and _throttle_input > 0.1 and _is_driven(i) and wheel_is_grounded[i]:
			var allowed_spin: float = maxf(2.5, 0.15 * speed_for_tcs) # same slip the torque cap below allows
			want_cut = clampf((_wheel_spin_speed(i) - allowed_spin) / 3.0, 0.0, 0.9)
			if absf(wheel_slip_lateral[i]) > 0.45 and speed_for_tcs > 8.0:
				want_cut = maxf(want_cut, 0.4) # power oversteer: ease off
		var rate: float = 10.0 if want_cut > _tcs_cut[i] else 4.0
		_tcs_cut[i] = move_toward(_tcs_cut[i], want_cut, rate * delta)
		drive_torques[i] *= 1.0 - _tcs_cut[i]
	tcs_active = _tcs_cut.max() > 0.05

	# Each wheel's rotational inertia: tyre+rim, plus the engine/gearbox spinning with it in gear.
	var n_driven: int = 0
	for i in range(4):
		if _is_driven(i):
			n_driven += 1
	var gear_mult: float = active_gear_ratio * final_drive_ratio * clutch_engagement
	if slipping_now:
		gear_mult = 0.0 # a slipping clutch doesn't tie the engine's inertia to the wheels
	var engine_share: float = engine_inertia * gear_mult * gear_mult / float(maxi(n_driven, 1))
	# Burnout: slow, in gear, handbrake + throttle -> the handbrake holds the axle that is NOT driven
	# (the front on RWD/AWD) so the driven wheels spin and the tyres smoke; TCS stays out of it.
	# Front-wheel drive: foot brake + throttle does it too ("line lock"): the brake then holds only the
	# rear wheels and the driven fronts spin.
	var line_lock: bool = drivetrain_mode == "FWD" and _brake_input > 0.3 and _handbrake_input < 0.5
	var burnout: bool = (_handbrake_input > 0.5 or line_lock) and _throttle_input > 0.5 and current_gear >= 2 and absf(linear_velocity.dot(global_transform.basis.z)) < 5.5
	line_lock = line_lock and burnout
	var hb_front: bool = burnout and drivetrain_mode != "FWD"
	is_burnout = burnout
	var speed_now: float = linear_velocity.length()
	# How many grounded wheels are braking (they share the job of holding the car)
	var n_braked: int = 0
	for i in range(4):
		if wheel_is_grounded[i] and (_brake_input > 0.01 or ((i >= 2) != hb_front and _handbrake_input > 0.01) or engine_drag[i] > 0.0):
			n_braked += 1

	for i in range(4):
		var r_tyre: float = maxf(tire_radius, 0.05)
		var inertia: float = wheel_inertia + (engine_share if _is_driven(i) else 0.0)
		var mount_pos: Vector3 = global_transform * wheel_offsets[i]
		var ray_dir: Vector3 = -up_vec
		var ray_length: float = suspension_rest_length + suspension_travel + tire_radius

		var result: Dictionary = _wheel_contact(space_state, mount_pos, up_vec, forward_vec, right_vec, ray_length, r_tyre)

		if result:
			wheel_is_grounded[i] = true
			wheel_contact_point[i] = result.position
			var hit_dist: float = result.hub_dist
			var n_contact: Vector3 = result.normal # from the contact point to the wheel hub
			var raw_compression: float = suspension_rest_length - hit_dist
			var compression: float = clampf(raw_compression, 0.0, suspension_travel)
			wheel_compression[i] = compression

			var point_vel: Vector3 = linear_velocity + angular_velocity.cross(mount_pos - global_position)

			# Damper works on how fast the spring is actually compressing, measured against the ground.
			# (Using body velocity along the car's up axis made the damper pull the car down whenever
			# the body pitched slightly at speed, so the suspension collapsed and the belly hit the road.)
			var comp_vel: float = clampf((raw_compression - _prev_raw_compression[i]) / maxf(delta, 0.001), -12.0, 12.0)
			_prev_raw_compression[i] = raw_compression

			var f_spring: float = compression * spring_stiffness
			var f_damper: float = comp_vel * (damper_bump if comp_vel > 0.0 else damper_rebound)
			# Bump stop: a very stiff rubber stop once travel runs out, so the chassis never grounds.
			var f_bump: float = maxf(raw_compression - suspension_travel, 0.0) * spring_stiffness * 12.0
			if f_bump > 0.0:
				# Rubber bump stops are heavily damped: they absorb a hard landing and give very little
				# of it back (an elastic stop launched the car metres back into the air like a trampoline).
				# (half of it comes back: the car bounces and pitches on landing, it doesn't stop dead)
				if comp_vel > 0.0:
					f_bump += comp_vel * damper_bump * 2.0
				else:
					f_bump *= 0.5
			var normal_force: float = clampf(f_spring + f_damper + f_bump, 0.0, mass * 9.81 * 7.0)

			# Front wheel steering direction (wheel_steer is negative for Left, positive for Right)
			var wheel_steer: float = deg_to_rad(_current_steer_angle) if i < 2 else 0.0
			var wheel_forward: Vector3 = forward_vec.rotated(up_vec, wheel_steer)
			var wheel_right: Vector3 = right_vec.rotated(up_vec, wheel_steer)
			# Touching an edge or slope ahead (round tyre): the tyre's driving direction follows the
			# surface it touches - pushing against a step's face drives the wheel UP it.
			if n_contact.dot(up_vec) < 0.995:
				wheel_forward = (wheel_forward - n_contact * wheel_forward.dot(n_contact)).normalized()

			var forward_vel: float = point_vel.dot(wheel_forward)
			var lateral_vel: float = point_vel.dot(wheel_right)

			var slip_ratio_lat: float = clampf(lateral_vel / maxf(absf(forward_vel) + 1.0, 1.0), -2.0, 2.0)
			wheel_slip_lateral[i] = slip_ratio_lat

			# Surface under this wheel (tagged on the map's bodies): grip & rolling drag depend on it
			var surface: String = "asphalt"
			var hit_obj: Object = result.get("collider")
			if hit_obj and hit_obj.has_meta("surface"):
				surface = str(hit_obj.get_meta("surface"))
			wheel_surface[i] = surface
			var surf_table: Dictionary = SURFACE_GRIP_OFFROAD if offroad_tires else SURFACE_GRIP_ROAD
			var grip_mult: float = tire_grip_factor * float(surf_table.get(surface, 1.0))
			# Handbrake at speed: locked rear tyres slide (drift entry). Slow or parked, the tyres keep
			# their full grip so the handbrake really holds the car (e.g. on a hill).
			if is_handbrake_active and i >= 2 and not hb_front:
				grip_mult *= lerpf(1.0, 0.40, clampf((speed_now - 3.0) / 9.0, 0.0, 1.0))

			# Slip-angle based tyre model (simplified Pacejka "magic formula").
			# Lateral force depends on slip ANGLE, not raw sideways speed, and can never exceed
			# the tyre's friction limit (mu * load). Peak grip at ~8 deg, gentle falloff beyond it,
			# so slides are progressive and catchable instead of snapping the car around.
			var slip_angle: float = atan2(lateral_vel, maxf(absf(forward_vel), 3.0))
			# Loose ground (grass, dirt, sand) gives way: the tyre needs a bigger slip angle for its (lower)
			# grip, so the car visibly slides and the tail steps out sooner than on tarmac.
			var loose: bool = SURFACE_ROLLING_DRAG.has(surface)
			var magic: float = sin(1.55 * atan((10.0 if not loose else (9.0 if offroad_tires else 7.75)) * slip_angle))
			if loose and i >= 2 and not offroad_tires:
				grip_mult *= 0.965
			# Front tyres get a little extra cornering grip: a more neutral balance, so the car turns in
			# at speed instead of washing wide (understeer). Clamped by the friction circle below.
			# The bias eases off a little at very high speed to keep the car stable flat-out.
			var bias: float = lerpf(front_lateral_bias, 1.06, clampf((speed_now - 50.0) / 35.0, 0.0, 1.0))
			var lat_grip: float = grip_mult * (bias if i < 2 else 1.0)
			var lateral_force_mag: float = -magic * lat_grip * normal_force
			# Never push harder than needed to cancel this wheel's sideways velocity in one step (no jitter at low speed).
			var stop_force: float = absf(lateral_vel) * (mass * 0.25) / maxf(delta, 0.001)
			lateral_force_mag = clampf(lateral_force_mag, -stop_force, stop_force)
			var lateral_force: Vector3 = wheel_right * lateral_force_mag

			var is_front: bool = (i < 2)
			var brake_factor: float = brake_bias_front if is_front else (1.0 - brake_bias_front)
			var total_brake_torque: float = _brake_input * brake_torque_max * brake_factor
			if line_lock:
				total_brake_torque = 0.0 if is_front else _brake_input * handbrake_torque_max
			if is_front == hb_front: # rear axle, or the front one in a burnout
				total_brake_torque += _handbrake_input * handbrake_torque_max
			var engine_brake_only: bool = total_brake_torque <= 0.0
			total_brake_torque += engine_drag[i]

			# Friction circle: grip is shared between accelerating/braking and cornering.
			# Cornering gets priority: drive/brake grip is trimmed first (keeping at least 35% of the
			# grip for it), so the car still turns on throttle at speed instead of ploughing straight.
			var total_grip: float = lat_grip * normal_force
			var long_room: float = maxf(sqrt(maxf(total_grip * total_grip - lateral_force_mag * lateral_force_mag, 0.0)), total_grip * 0.35)
			# FWD line lock: the braked rear tyres alone can't hold back grippy driven fronts, so the car
			# would just crawl forward. Spinning tyres grip far less: let the fronts break loose.
			if line_lock and _is_driven(i):
				long_room *= 0.3

			# --- Per-wheel spin & tyre longitudinal force (one solve covers drive, wheelspin,
			# engine braking, braking and lock-up) ---
			# 1) Engine torque and brakes act on this wheel's own spin.
			var w_roll: float = forward_vel / r_tyre # spin of a wheel rolling without slip
			# Traction control, like a real one: never send this wheel more torque than its tyre can
			# put on the road right now (load x grip, less what cornering already uses). More power
			# then means more acceleration up to the grip limit - never a power LOSS (the old slip-
			# based cut threw away up to 90% of the power once a big engine started spinning).
			if tcs_enabled and not burnout and _is_driven(i) and drive_torques[i] != 0.0:
				# like a real TCS it lets a little wheelspin through (~15% of the speed, at least 2.5 m/s)
				# before cutting back to the grip limit, so hard launches still chirp and leave marks
				var spin_now: float = absf(wheel_angular_velocity[i] * r_tyre - forward_vel)
				var t_lim: float = long_room * r_tyre * (1.35 if spin_now < maxf(2.5, absf(forward_vel) * 0.15) else 1.0)
				if absf(drive_torques[i]) > t_lim:
					drive_torques[i] = signf(drive_torques[i]) * t_lim
			var w_pred: float = wheel_angular_velocity[i] + drive_torques[i] / inertia * delta
			w_pred = move_toward(w_pred, 0.0, total_brake_torque / inertia * delta) # brakes can stop a wheel, not reverse it
			# 2) Force the tyre must put on the road to keep the wheel rolling with the road:
			var fx_needed: float = inertia * (w_pred - w_roll) / (r_tyre * delta)
			# A wheel the brake has stopped (slow or standing): the brake must hold the CAR, not just
			# the wheel. Static friction - up to the brake's capacity, then the tyre's grip below -
			# cancels this wheel's share of the car's motion and of any drive torque, so the car
			# stops and stays put, also on a ramp. (Before, only the force to stop the light wheel
			# itself was used, so at low speed the brakes and the handbrake did almost nothing.)
			if total_brake_torque > 0.0 and absf(w_pred) < 0.001:
				var brake_cap: float = total_brake_torque / r_tyre
				var drive_f: float = drive_torques[i] / r_tyre
				var stop_f: float = mass * forward_vel / delta / float(maxi(n_braked, 1))
				var hold_f: float = drive_f + clampf(-(stop_f + drive_f), -brake_cap, brake_cap)
				if absf(hold_f) > absf(fx_needed):
					fx_needed = hold_f
			var long_mag: float = 0.0
			if absf(fx_needed) <= long_room:
				long_mag = fx_needed # tyre grips: wheel rolls with the road
				wheel_angular_velocity[i] = w_roll
			elif abs_enabled and not engine_brake_only and fx_needed * forward_vel < 0.0 and not (is_handbrake_active and not is_front):
				long_mag = signf(fx_needed) * long_room # ABS: brake right at the grip limit, never lock
				wheel_angular_velocity[i] = w_roll
			else:
				# Tyre slips (wheelspin or locked wheel): kinetic friction in the direction of slip,
				# and the wheel keeps its own speed.
				# A tyre only just past its limit keeps nearly all its grip; a wildly spinning or
				# locked one drops to ~90% (dry asphalt). A flat 90% made any excess torque spin up to the limiter.
				var slip_v: float = absf(w_pred * r_tyre - forward_vel)
				long_mag = signf(fx_needed) * long_room * lerpf(1.0, 0.9, clampf(slip_v / 15.0, 0.0, 1.0))
				var vsx: float = w_pred * r_tyre - forward_vel
				if i >= 2 and not tcs_enabled and engine_brake_only and vsx * signf(forward_vel + 0.01) > 0.0:
					# Rear tyre spinning under power: a sliding tyre's friction points against its total
					# slip (spin + sideways), so the spin eats the side grip and the rear steps out
					# (power oversteer). TCS on keeps the rear in check; front tyres and braking keep the
					# cornering-first sharing above.
					var vs: float = sqrt(vsx * vsx + lateral_vel * lateral_vel)
					var mu_n: float = total_grip * lerpf(1.0, 0.9, clampf(vs / 15.0, 0.0, 1.0))
					long_mag = mu_n * vsx / maxf(vs, 0.001)
					var side_max: float = mu_n * absf(lateral_vel) / maxf(vs, 0.001)
					lateral_force_mag = clampf(lateral_force_mag, -side_max, side_max)
					lateral_force = wheel_right * lateral_force_mag
				wheel_angular_velocity[i] = w_pred - long_mag * r_tyre * delta / inertia
				if slipping_now and _clutch_torque > 0.0 and _is_driven(i):
					wheel_angular_velocity[i] = _cap_to_engine(wheel_angular_velocity[i], active_gear_ratio)
			# for the tyre effects (marks, smoke, flying grass)
			wheel_contact_pos[i] = result.position
			wheel_contact_normal[i] = n_contact
			wheel_long_slip[i] = wheel_angular_velocity[i] * r_tyre - forward_vel
			wheel_lat_slip[i] = lateral_vel
			var combined: float = sqrt(long_mag * long_mag + lateral_force_mag * lateral_force_mag)
			if combined > total_grip and combined > 0.001:
				var scale_f: float = total_grip / combined
				long_mag *= scale_f
				lateral_force = lateral_force * scale_f
			# Soft ground (grass, dirt, sand) drags the tyre back: extra rolling resistance
			var rr: float = float(SURFACE_ROLLING_DRAG.get(surface, 0.0)) * (0.5 if offroad_tires else 1.0)
			long_mag -= rr * normal_force * clampf(forward_vel, -1.0, 1.0)
			var longitudinal_force: Vector3 = wheel_forward * long_mag

			# Apply normal spring force upward at axle mount
			# along the contact normal: straight up on flat ground, up-and-back against an edge
			apply_force(n_contact * normal_force, mount_pos - global_position)

			# Drive/brake force at the contact patch: gives real weight transfer (rear squats when
			# accelerating, nose dives when braking). Safe now that it's capped by tyre grip.
			var contact_rel: Vector3 = result.position - global_position
			apply_force(longitudinal_force, contact_rel)

			# Cornering force applied a bit above the road (towards the roll centre) so the body
			# rolls naturally but tall cars don't trip over themselves at speed.
			var com_world: Vector3 = global_transform * center_of_mass
			var com_height: float = maxf((com_world - result.position).dot(up_vec), 0.0)
			apply_force(lateral_force, contact_rel + up_vec * com_height * 0.4)

		else:
			wheel_is_grounded[i] = false
			wheel_compression[i] = 0.0
			wheel_slip_lateral[i] = 0.0
			_prev_raw_compression[i] = 0.0
			# Wheel in the air: spins freely from engine torque, slowed by brakes & bearing drag
			wheel_angular_velocity[i] += drive_torques[i] / inertia * delta
			var air_brake: float = _brake_input * brake_torque_max * (brake_bias_front if i < 2 else 1.0 - brake_bias_front)
			if i >= 2:
				air_brake += _handbrake_input * handbrake_torque_max
			air_brake += engine_drag[i]
			wheel_angular_velocity[i] = move_toward(wheel_angular_velocity[i], 0.0, air_brake / inertia * delta)
			wheel_angular_velocity[i] *= (1.0 - 0.3 * delta)
			if slipping_now and _clutch_torque > 0.0 and _is_driven(i):
				wheel_angular_velocity[i] = _cap_to_engine(wheel_angular_velocity[i], active_gear_ratio)

	# Anti-roll bars: push the more-compressed side UP and the extended side DOWN to resist body roll.
	# (The sign used to be inverted, which made the bars add roll and tipped tall cars over.)
	# Only acts while both wheels of the axle touch the ground.
	if wheel_is_grounded[0] and wheel_is_grounded[1]:
		var front_roll_diff: float = (wheel_compression[0] - wheel_compression[1]) * anti_roll_stiffness
		apply_force(up_vec * front_roll_diff, (global_transform * wheel_offsets[0]) - global_position)
		apply_force(-up_vec * front_roll_diff, (global_transform * wheel_offsets[1]) - global_position)

	if wheel_is_grounded[2] and wheel_is_grounded[3]:
		var rear_roll_diff: float = (wheel_compression[2] - wheel_compression[3]) * anti_roll_stiffness
		apply_force(up_vec * rear_roll_diff, (global_transform * wheel_offsets[2]) - global_position)
		apply_force(-up_vec * rear_roll_diff, (global_transform * wheel_offsets[3]) - global_position)

# How much faster (m/s at the tread) a wheel spins than the road under it.
func _wheel_spin_speed(i: int) -> float:
	if not wheel_is_grounded[i]:
		return 0.0
	var fwd: float = linear_velocity.dot(global_transform.basis.z)
	return absf(wheel_angular_velocity[i] * tire_radius - fwd)

func _update_wheel_visuals(delta: float) -> void:
	if wheel_mounts.is_empty():
		return
	for i in range(wheel_mounts.size()):
		var mount: Node3D = wheel_mounts[i]
		if mount == null:
			continue

		var mount_offset: Vector3 = wheel_offsets[i]

		# CALCULATE EXACT WHEEL Y POSITION:
		# Lock wheel bottom exactly to the ground collision contact point!
		if wheel_is_grounded[i]:
			var local_contact: Vector3 = global_transform.affine_inverse() * wheel_contact_point[i]
			var contact_target_y: float = local_contact.y + tire_radius
			var min_y: float = mount_offset.y - (suspension_rest_length + suspension_travel)
			var max_y: float = mount_offset.y + 0.10
			var target_local_y: float = clampf(contact_target_y, min_y, max_y)
			mount.position.y = lerpf(mount.position.y, target_local_y, delta * 45.0)
		else:
			var target_local_y: float = mount_offset.y - suspension_rest_length
			mount.position.y = lerpf(mount.position.y, target_local_y, delta * 15.0)

		mount.position.x = mount_offset.x
		mount.position.z = mount_offset.z
		if i < _coilovers.size():
			# coil-over from a fixed point on the chassis down to this wheel's hub: it stretches and
			# compresses with this wheel alone, so every wheel visibly works on its own
			var sd: float = signf(mount_offset.x)
			var top := Vector3(mount_offset.x - sd * 0.38, mount_offset.y - suspension_rest_length + 0.62, mount_offset.z)
			var bot: Vector3 = mount.position + Vector3(-sd * 0.14, 0.04, 0.0)
			var along: Vector3 = top - bot
			var y: Vector3 = along.normalized()
			var x: Vector3 = y.cross(Vector3.FORWARD).normalized()
			(_coilovers[i] as MeshInstance3D).transform = Transform3D(Basis(x, y * along.length(), x.cross(y)), (top + bot) * 0.5)

		# Steer (Y) on Mount node (Negative when A is pressed, pointing Left!)
		var steer_angle: float = deg_to_rad(_current_steer_angle) if i < 2 else 0.0
		var camber_angle: float = deg_to_rad(camber_angle_front_deg if i < 2 else camber_angle_rear_deg) * (1.0 if i % 2 == 0 else -1.0)
		mount.rotation.y = steer_angle
		mount.rotation.z = camber_angle
		mount.rotation.x = 0.0

		# Wheel Rolling (X) ONLY on RollNode
		# Forward in this world coordinate system is +Z, so rolling forward rotates positively around +X!
		if i < wheel_rolls.size() and wheel_rolls[i] != null:
			wheel_rolls[i].rotation.x += wheel_angular_velocity[i] * delta * (tire_radius / front_wheel_r if (i < 2 and front_wheel_r > 0.0) else 1.0)

	_update_dynamic_links()

	# Tail lights: dim running lights, brighter the harder the brake pedal is pressed
	for m in _brake_light_mats:
		m.emission_energy_multiplier = _tail_base + 7.0 * _brake_input

# Place the car on the ground at a map location, facing yaw_deg (0 = +Z), standing still.
# Find an open, level spot for the car at (or near) `target`: not on a roof, a plane, a ramp or a
# lamp post, and with room for the car. Searches outwards in rings if the exact point is taken.
# Returns the ground point to stand on (Vector3.INF if nothing was found).
func find_open_spot(target: Vector3, yaw: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(absf(wheel_offsets[0].x) * 2.0 + 1.0, 2.6), 1.6, maxf(absf(wheel_offsets[0].z) * 2.0 + 2.2, 5.0))
	for radius in [0.0, 6.0, 12.0, 20.0, 30.0, 45.0]:
		var steps: int = 1 if radius == 0.0 else 12
		for k in range(steps):
			var a: float = TAU * float(k) / float(steps)
			var p := Vector3(target.x + cos(a) * radius, 0.0, target.z + sin(a) * radius)
			if absf(p.x) > 1470.0 or absf(p.z) > 1470.0:
				continue
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 150.0, p + Vector3.DOWN * 30.0)
			q.exclude = [get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty() or absf(hit.normal.y) < 0.78: # up to ~38° (hill flanks are fine)
				continue
			# high surfaces are only fine if they are natural ground (hills), not roofs or ramps
			var surf: String = str(hit.collider.get_meta("surface", "")) if hit.collider else ""
			if hit.position.y > 1.0 and not surf in ["grass", "dirt", "sand"]:
				continue
			var sq := PhysicsShapeQueryParameters3D.new()
			sq.shape = box
			# the room check follows the slope (a level box would "hit" any hillside)
			var n_up: Vector3 = hit.normal if hit.normal.y > 0.0 else -hit.normal
			var slope_basis := Basis(Quaternion(Vector3.UP, n_up)) * Basis(Vector3.UP, yaw)
			sq.transform = Transform3D(slope_basis, hit.position + n_up * 1.05)
			sq.exclude = [get_rid()]
			if space.intersect_shape(sq, 1).is_empty():
				return hit.position
	return Vector3.INF

func teleport_to(ground_pos: Vector3, yaw_deg: float) -> void:
	var spot: Vector3 = find_open_spot(ground_pos, deg_to_rad(yaw_deg))
	var ground_y: float = ground_pos.y
	if spot != Vector3.INF:
		ground_pos = spot
		ground_y = spot.y
	else:
		var up_probe := PhysicsRayQueryParameters3D.create(ground_pos + Vector3.UP * 60.0, ground_pos + Vector3.DOWN * 20.0)
		up_probe.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(up_probe)
		ground_y = hit.position.y if hit else ground_pos.y
	# Stand the car on the slope it lands on (tilted with the ground). Placed level on a hillside,
	# its uphill wheels started inside the ground and the car got stuck on its belly.
	var n_up: Vector3 = Vector3.UP
	var nq := PhysicsRayQueryParameters3D.create(Vector3(ground_pos.x, ground_y + 2.0, ground_pos.z), Vector3(ground_pos.x, ground_y - 2.0, ground_pos.z))
	nq.exclude = [get_rid()]
	var nhit: Dictionary = get_world_3d().direct_space_state.intersect_ray(nq)
	if nhit and absf(nhit.normal.y) > 0.5:
		n_up = nhit.normal if nhit.normal.y > 0.0 else -nhit.normal
	var b := Basis(Quaternion(Vector3.UP, n_up)) * Basis(Vector3.UP, deg_to_rad(yaw_deg))
	global_transform = Transform3D(b, Vector3(ground_pos.x, ground_y, ground_pos.z) + n_up * (tire_radius + suspension_rest_length + 0.15))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_teleport_xform = global_transform
	_teleport_pending = true
	_prev_body_pos = Vector3.INF
	_dir_change_armed = true
	current_rpm = idle_rpm
	_engage_gear_now(1) # neutral after a teleport: no creeping away
	_reset_turbo_boost()
	for i in range(4):
		wheel_angular_velocity[i] = 0.0
		_prev_raw_compression[i] = 0.0
	var timer: Node = get_tree().get_first_node_in_group("lap_timer")
	if timer:
		timer.cancel()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _teleport_pending:
		_teleport_pending = false
		state.transform = _teleport_xform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO

func reset_vehicle() -> void:
	global_transform = _initial_transform
	global_position += Vector3.UP * maxf(tire_radius + suspension_rest_length - DEFAULT_RIDE, 0.0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_prev_body_pos = Vector3.INF
	_dir_change_armed = true
	current_rpm = idle_rpm
	_engage_gear_now(1) # neutral; also cancels a gear change that was in progress
	_reset_turbo_boost()
	for i in range(4):
		wheel_angular_velocity[i] = 0.0
		_prev_raw_compression[i] = 0.0

# Fresh boost: no cooldown left over (car change, teleport, reset)
func _reset_turbo_boost() -> void:
	turbo_boost_bar = 0.0
	turbo_boost_active = false
	turbo_boost_timer = 0.0
	turbo_boost_cooldown_timer = 0.0
	turbo_boost_ready = true

# Recover (R / gamepad Y): put the car back on its wheels right where it is, dropped from a
# little above the ground (never high), facing the way it was heading. Can be pressed again and
# again - no cooldown. If the spot is blocked (e.g. wedged against a wall) it uses the nearest
# open spot.
func repair_vehicle() -> void:
	var fwd: Vector3 = global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.2: # nose straight up/down: use the roof direction instead
		fwd = global_transform.basis.y
		fwd.y = 0.0
	var yaw: float = atan2(fwd.x, fwd.z) if fwd.length() > 0.01 else 0.0
	var space := get_world_3d().direct_space_state
	var p: Vector3 = global_position
	# ground straight below the car (start just above it so a roof overhead is not picked)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 40.0)
	q.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	var ground: Vector3 = hit.position if hit else Vector3(p.x, 0.0, p.z)
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(absf(wheel_offsets[0].x) * 2.0 + 0.6, 2.2), 1.4, maxf(absf(wheel_offsets[0].z) * 2.0 + 1.6, 4.4))
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = box
	sq.transform = Transform3D(Basis(Vector3.UP, yaw), ground + Vector3.UP * 1.3)
	sq.exclude = [get_rid()]
	if not space.intersect_shape(sq, 1).is_empty():
		var spot: Vector3 = find_open_spot(ground, yaw)
		if spot != Vector3.INF:
			ground = spot
	global_transform = Transform3D(Basis(Vector3.UP, yaw), ground + Vector3.UP * (tire_radius + suspension_rest_length + 1.5))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_prev_body_pos = Vector3.INF
	for i in range(4):
		_prev_raw_compression[i] = 0.0

# Where does this (round) tyre touch the world? A fan of rays in the wheel's plane (from straight
# down to 45° forward and back) finds the point that lifts the hub highest. A single straight-down
# ray only "saw" a kerb, block or ramp once the wheel was on top of it, so the car slammed into
# their edges; now the tyre rolls up onto them like a real wheel.
# Returns {} or {position, hub_dist (mount -> hub along -up), normal (contact -> hub), collider}.
const WHEEL_RAY_ANGLES: Array[float] = [0.0, 0.40, -0.40, 0.78, -0.78] # radians
func _wheel_contact(space: PhysicsDirectSpaceState3D, mount: Vector3, up: Vector3, fwd: Vector3, right: Vector3, length: float, r: float) -> Dictionary:
	var best: Dictionary = {}
	var best_s: float = INF
	for a in WHEEL_RAY_ANGLES:
		var d: Vector3 = (-up * cos(a) + fwd * sin(a)).normalized()
		var q := PhysicsRayQueryParameters3D.create(mount, mount + d * (length / maxf(cos(a), 0.5)))
		q.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		# Only surfaces a tyre can stand or climb on (up to ~63°). A vertical wall used to count as
		# "ground" for the angled rays: it lifted the wheel, so two wheels could drive a truck straight
		# up a wall. Walls are now left to the collision shapes, like in reality.
		# (abs: some ground meshes report their face normal pointing down)
		# (the monster truck is the exception: it is meant to climb walls, see _monster_wall_climb)
		if absf(hit.normal.y) < 0.45 and (not is_monster or hit.collider.has_meta("no_climb")):
			continue
		var tt: float = (hit.position - mount).length()
		var side: float = tt * sin(absf(a))
		if side >= r:
			continue # passes beside the tyre circle
		# hub distance at which the circle first touches this point
		var s: float = tt * cos(a) - sqrt(r * r - side * side)
		if s < best_s:
			best_s = s
			best = {"position": hit.position, "hub_dist": s, "collider": hit.collider}
	if best.is_empty():
		return best
	var hub: Vector3 = mount - up * best_s
	var n: Vector3 = hub - best.position
	best["normal"] = n.normalized() if n.length() > 0.01 else up
	if best["normal"].dot(up) < 0.2:
		best["normal"] = (best["normal"] + up * 0.2).normalized() # never push the car sideways only
	return best

# While the clutch / torque converter slips, it can only drag the wheels up to the engine's own
# speed (through the gearing) - never faster. Without this, spinning or airborne wheels ran away
# and pulled the engine far past its limiter.
func _cap_to_engine(w: float, ratio: float) -> float:
	if ratio == 0.0:
		return w
	var w_eng: float = current_rpm / (60.0 / TAU) / (absf(ratio) * final_drive_ratio)
	if w * signf(ratio) > w_eng:
		return w_eng * signf(ratio)
	return w
