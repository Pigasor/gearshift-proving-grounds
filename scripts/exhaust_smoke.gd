class_name ExhaustSmoke
extends CPUParticles3D
# Exhaust smoke from the tailpipe: a faint haze at idle that thickens with revs and throttle.
# Diesels puff darker soot under load. Particles live in world space, so they trail behind.

var vehicle: Node

func _ready() -> void:
	amount = 60
	lifetime = 1.3
	local_coords = false
	direction = Vector3(0.0, 0.15, -1.0) # out of the pipe, backwards (car forward is +Z)
	spread = 14.0
	gravity = Vector3(0.0, 0.7, 0.0) # warm gas rises a little
	damping_min = 1.5
	damping_max = 2.5
	scale_amount_min = 0.7
	scale_amount_max = 1.1
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(1.0, 1.8))
	scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	color_ramp = fade
	# soft round puff
	var puff := Gradient.new()
	puff.set_color(0, Color(1, 1, 1, 1))
	puff.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = puff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.32)
	quad.material = mat
	mesh = quad

func _process(_delta: float) -> void:
	if vehicle == null:
		return
	var idle: float = float(vehicle.get("idle_rpm"))
	var lim: float = maxf(float(vehicle.get("limiter_rpm")), idle + 1.0)
	var revs: float = clampf((float(vehicle.get("current_rpm")) - idle) / (lim - idle), 0.0, 1.0)
	var thr: float = float(vehicle.get("pedal_throttle"))
	var load: float = clampf(revs * 0.6 + thr * revs * 0.6, 0.0, 1.0)
	initial_velocity_min = 1.2 + 4.0 * revs
	initial_velocity_max = 2.0 + 6.0 * revs
	if str(vehicle.get("engine_fuel")) == "dizel":
		var c: float = lerpf(0.55, 0.16, thr)
		color = Color(c, c, c, 0.10 + 0.55 * thr * (0.4 + revs))
	else:
		color = Color(0.86, 0.86, 0.88, 0.035 + 0.3 * load)
