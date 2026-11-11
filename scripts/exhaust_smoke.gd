class_name ExhaustSmoke
extends GPUParticles3D
# Exhaust smoke from one tailpipe, GPU particles:
# - each puff is a noisy, soft-edged smoke sprite that spins, grows and drifts in turbulence
#   (the usual "noise texture + turbulence + soft particles" look of game engines' smoke demos)
# - puffs inherit most of the car's velocity and are emitted along the path the pipe moved
#   through between frames (interpolate), so the plume is one continuous stream at any speed
# - idle and low revs: barely a haze; it thickens with revs and throttle; diesels go dark under load
# - turbo boost (Shift) and upshift backfires shoot a flame out of the pipe

var vehicle: Node
var flame: GPUParticles3D
var pipe_pos: Vector3 # tip of the pipe (car-local)
var pipe_dir: Vector3 = Vector3(0.0, 0.15, -1.0) # out of the pipe (car forward is +Z)
var share: float = 1.0 # 1 / number of pipes on the car
var _pop_t: float = 0.0
var _pm: ParticleProcessMaterial

func _ready() -> void:
	position = pipe_pos
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	amount = maxi(int(70.0 * share), 24)
	lifetime = 1.8
	local_coords = false
	fixed_fps = 60
	interpolate = true
	visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 40, 80))
	_pm = ParticleProcessMaterial.new()
	_pm.direction = pipe_dir
	_pm.spread = 8.0
	_pm.initial_velocity_min = 1.5
	_pm.initial_velocity_max = 3.0
	_pm.inherit_velocity_ratio = 0.8 # the car's wake carries the gas along
	_pm.gravity = Vector3(0.0, 0.45, 0.0) # warm gas rises
	_pm.damping_min = 0.8
	_pm.damping_max = 1.6
	_pm.angle_min = 0.0
	_pm.angle_max = 360.0
	_pm.angular_velocity_min = -50.0
	_pm.angular_velocity_max = 50.0
	_pm.scale_min = 0.6
	_pm.scale_max = 1.0
	_pm.scale_curve = FxTex.curve([Vector2(0.0, 0.25), Vector2(0.4, 1.2), Vector2(1.0, 2.6)], 3.0)
	_pm.color_ramp = FxTex.ramp([0.0, 0.1, 0.5, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_pm.turbulence_enabled = true
	_pm.turbulence_noise_strength = 2.0
	_pm.turbulence_noise_scale = 3.0
	_pm.turbulence_influence_min = 0.05
	_pm.turbulence_influence_max = 0.15
	process_material = _pm
	draw_pass_1 = FxTex.smoke_mesh(0.45)
	amount_ratio = 0.1
	_make_flame()

func _make_flame() -> void:
	flame = GPUParticles3D.new()
	flame.amount = 32
	flame.lifetime = 0.14
	flame.local_coords = true # stays on the pipe at any speed
	flame.emitting = false
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.fixed_fps = 60
	var pm := ParticleProcessMaterial.new()
	pm.direction = pipe_dir
	pm.spread = 6.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	pm.scale_curve = FxTex.curve([Vector2(0.0, 1.0), Vector2(1.0, 0.3)])
	pm.color_ramp = FxTex.ramp([0.0, 0.35, 1.0], [Color(0.55, 0.7, 1.0, 1.0), Color(1.0, 0.65, 0.2, 0.9), Color(1.0, 0.35, 0.05, 0.0)])
	flame.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = FxTex.soft()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat
	flame.draw_pass_1 = quad
	add_child(flame)

# Backfire: a short bang of flame (upshift in the red zone)
func backfire() -> void:
	_pop_t = 0.09

func _process(delta: float) -> void:
	if vehicle == null:
		return
	var body := vehicle as RigidBody3D
	var idle: float = float(vehicle.get("idle_rpm"))
	var lim: float = maxf(float(vehicle.get("limiter_rpm")), idle + 1.0)
	var revs: float = clampf((float(vehicle.get("current_rpm")) - idle) / (lim - idle), 0.0, 1.0)
	var thr: float = float(vehicle.get("pedal_throttle"))
	var kmh: float = body.linear_velocity.length() * 3.6
	# idle and low revs: only a faint haze; smoke builds from ~30% of the rev range and with throttle
	var k: float = smoothstep(0.3, 1.0, revs) * (0.35 + 0.65 * thr)
	var wind: float = lerpf(1.0, 0.6, clampf((kmh - 20.0) / 80.0, 0.0, 1.0)) # thins out with speed
	amount_ratio = clampf(0.12 + 0.88 * k, 0.0, 1.0)
	_pm.initial_velocity_min = 1.2 + 3.0 * revs
	_pm.initial_velocity_max = 2.4 + 5.0 * revs
	if str(vehicle.get("engine_fuel")) == "dizel":
		var c: float = lerpf(0.6, 0.12, thr * revs)
		_pm.color = Color(c, c, c, (0.10 + 0.55 * k) * wind)
	else:
		_pm.color = Color(0.78, 0.79, 0.82, (0.06 + 0.5 * k) * wind)

	_pop_t -= delta
	var popping: bool = _pop_t > 0.0
	flame.emitting = bool(vehicle.get("turbo_boost_active")) or popping
	var fpm := flame.process_material as ParticleProcessMaterial
	fpm.direction = pipe_dir
	fpm.scale_min = 1.6 if popping else 0.8
	fpm.scale_max = 2.2 if popping else 1.2
