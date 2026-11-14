extends SceneTree
# Calibrates cars to real 0-100 / top speed: repeats a flat-out run on the runway and adjusts
#   k  -> engine torque & power (and tyre grip when k > 1)     for 0-100
#   c  -> drag (power-limited top speed) / fd -> final drive (when it tops out on the limiter)
# args: "id:t100:vmax,id:t100:vmax,..."  (t100 0 = don't care, vmax 0 = don't care)
var car: RigidBody3D
var f: int = 0
var jobs: Array = []
var j: int = 0
var it: int = 0
var k: float = 1.0
var c: float = 1.0
var fd: float = 1.0
var phase: int = 0
var t: float = 0.0
var t100: float = -1.0
var vmax: float = 0.0
var vmax_t: float = 0.0
var rpm_at_vmax: float = 0.0
var gear_at_vmax: int = 0
var base: Dictionary = {}

func _initialize() -> void:
	for s in OS.get_cmdline_user_args()[0].split(","):
		var p: PackedStringArray = s.split(":")
		jobs.append([int(p[0]), float(p[1]), float(p[2])])
	root.add_child(load("res://scenes/main.tscn").instantiate())
	car = root.find_child("Vehicle", true, false)

func _start() -> void:
	car.apply_car(jobs[j][0], 0)
	if it == 0:
		base = {"tq": car.torque_peak_nm, "hp": car.peak_horsepower, "grip": car.tire_grip_factor, "drag": car.drag_coefficient, "fd": car.final_drive_ratio}
	car.torque_peak_nm = base["tq"] * k
	car.peak_horsepower = base["hp"] * k
	car.tire_grip_factor = base["grip"] * maxf(k, 1.0)
	car.drag_coefficient = base["drag"] * c
	car.final_drive_ratio = base["fd"] * fd
	car.is_automatic = true
	car.tcs_enabled = true
	car.teleport_to(Vector3(-1500, 0, -2860), 0.0)
	phase = 0
	t = 0.0
	t100 = -1.0
	vmax = 0.0
	vmax_t = 0.0

func _physics_process(d: float) -> bool:
	f += 1
	if f < 10:
		return false
	if f == 10:
		_start()
		return false
	t += d
	Input.action_release("throttle")
	if phase == 0:
		if t < 0.2:
			Input.action_press("throttle")
		if car.engine_running and t > 1.5:
			phase = 1
			t = 0.0
		return false
	Input.action_press("throttle")
	var kmh: float = car.linear_velocity.dot(car.global_transform.basis.z) * 3.6
	if kmh >= 100.0 and t100 < 0.0:
		t100 = t
	if kmh > vmax + 0.3:
		vmax = kmh
		vmax_t = t
		rpm_at_vmax = car.current_rpm
		gear_at_vmax = car.current_gear
	if car.global_position.z > 400.0:
		var xf: Transform3D = car.global_transform
		xf.origin.z -= 3000.0
		car.global_transform = xf
	var target_t: float = jobs[j][1]
	var target_v: float = jobs[j][2]
	# 0-100 only: stop once past 100
	var done: bool = (t - vmax_t > 8.0) or t > 150.0 or (target_v <= 0.0 and t100 > 0.0)
	if not done:
		return false
	var ok_t: bool = target_t <= 0.0 or (t100 > 0.0 and absf(t100 - target_t) / target_t < 0.04)
	var limited: bool = car.speed_limit_kmh > 0.0 and vmax > car.speed_limit_kmh - 4.0
	var on_limiter: bool = gear_at_vmax == car.gear_ratios.size() - 1 and rpm_at_vmax > car.limiter_rpm - 250.0
	var ok_v: bool = target_v <= 0.0 or absf(vmax - target_v) / target_v < 0.025 or (limited and target_v >= car.speed_limit_kmh - 4.0)
	print("  car %d it %d k %.3f c %.3f fd %.3f -> 0-100 %.2f (%.2f)  vmax %.0f (%.0f)%s%s" % [jobs[j][0], it, k, c, fd, t100, target_t, vmax, target_v, " limiter" if on_limiter else "", " capped" if limited else ""])
	if (ok_t and ok_v) or it >= 6:
		var tune: Dictionary = {}
		if absf(k - 1.0) > 0.005:
			tune["torque_peak_nm*"] = snappedf(k, 0.001)
			tune["peak_horsepower*"] = snappedf(k, 0.001)
			if k > 1.0:
				tune["tire_grip_factor*"] = snappedf(k, 0.001)
		if absf(c - 1.0) > 0.005:
			tune["drag_coefficient*"] = snappedf(c, 0.001)
		if absf(fd - 1.0) > 0.005:
			tune["final_drive_ratio*"] = snappedf(fd, 0.001)
		print("TUNE|%d|%s|%.2f|%.0f" % [jobs[j][0], JSON.stringify(tune), t100, vmax])
		j += 1
		it = 0
		k = 1.0
		c = 1.0
		fd = 1.0
		if j >= jobs.size():
			return true
		_start()
		return false
	it += 1
	if not ok_t and t100 > 0.0:
		k *= clampf(pow(t100 / target_t, 1.1), 0.6, 1.8)
		# more power means more top speed: keep the drag in step
		c *= clampf(pow(t100 / target_t, 1.1), 0.6, 1.8)
	if not ok_v and not limited:
		if on_limiter and vmax < target_v:
			fd *= vmax / target_v # longer gearing
		else:
			c *= clampf(pow(vmax / target_v, 3.0), 0.4, 2.5)
	_start()
	return false
