extends SceneTree
var car: RigidBody3D
var f: int = 0
var t: float = 0.0
var phase: int = 0
var idx: int = 0
var s: String = ""
func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	idx = int(a[0])
	root.add_child(load("res://scenes/main.tscn").instantiate())
	car = root.find_child("Vehicle", true, false)
func _physics_process(d: float) -> bool:
	f += 1
	if f < 10: return false
	if f == 10:
		car.apply_car(idx, 0); car.is_automatic = true; car.tcs_enabled = true
		car.teleport_to(Vector3(-1500, 0, -2860), 0.0)
		return false
	t += d
	Input.action_release("throttle")
	if phase == 0:
		if t < 0.2: Input.action_press("throttle")
		if car.engine_running and t > 1.5: phase = 1; t = 0.0
		return false
	Input.action_press("throttle")
	if int(round(t * 60)) % 12 == 0:
		var spin: float = 0.0
		for i in 4: spin = maxf(spin, absf(car.wheel_angular_velocity[i] * car.tire_radius) - absf(car.linear_velocity.dot(car.global_transform.basis.z)))
		s += "\n t=%.1f v=%.0f g=%d rpm=%.0f clutch_slip=%s spin=%.1f tcs=%s ax=%.2fg" % [t, car.current_speed_kmh, car.current_gear - 1, car.current_rpm, car._clutch_slipping, spin, car.tcs_active, car.g_force_longitudinal]
	if t > 4.5:
		print(s); return true
	return false
