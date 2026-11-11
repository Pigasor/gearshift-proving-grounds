class_name ExhaustSmoke
extends GPUParticles3D
# Exhaust at one tailpipe. Real exhaust gas is mostly invisible, so instead of a constant white cloud:
# - heat haze: the air right behind the pipe shimmers (screen distortion), even at idle
# - trail: thin grey wisps that only build up with revs and throttle (this node's particles)
# - puffs: a short dark puff on each throttle blip and gear change (and a black one from a diesel
#   under load; diesels also leave a sooty trail when floored)
# - flame: turbo boost (Shift) and upshift backfires

var vehicle: Node
var flame: GPUParticles3D
var pipe_pos: Vector3 # tip of the pipe (car-local)
var pipe_dir: Vector3 = Vector3(0.0, 0.15, -1.0) # out of the pipe (car forward is +Z)
var share: float = 1.0 # 1 / number of pipes on the car
var _pop_t: float = 0.0
var _pm: ParticleProcessMaterial
var _puff: GPUParticles3D
var _puff_pm: ParticleProcessMaterial
var _haze: MeshInstance3D
var _haze_mat: ShaderMaterial
var _prev_thr: float = 0.0
var _prev_gear: int = -1
var _puff_cool: float = 0.0

const HAZE_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
void vertex() {
	// face the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 c = UV - vec2(0.5);
	float fall = clamp(1.0 - length(c * vec2(2.0, 1.6)), 0.0, 1.0);
	float wob = sin(UV.y * 38.0 - TIME * 14.0) * cos(UV.x * 23.0 + TIME * 9.0);
	vec2 off = vec2(wob, sin(UV.x * 31.0 + TIME * 11.0)) * strength * fall * fall * 0.0035;
	ALBEDO = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	ALPHA = fall * step(0.001, strength);
}
"""

func _ready() -> void:
	position = pipe_pos
	layers = 2 # not on the map
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	amount = maxi(int(60.0 * share), 24)
	lifetime = 1.1
	local_coords = false
	fixed_fps = 60
	interpolate = true
	visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 40, 80))
	_pm = ParticleProcessMaterial.new()
	_pm.direction = pipe_dir
	_pm.spread = 6.0
	_pm.initial_velocity_min = 2.0
	_pm.initial_velocity_max = 3.5
	_pm.inherit_velocity_ratio = 0.85 # the car's wake carries the gas along
	_pm.gravity = Vector3(0.0, 0.3, 0.0)
	_pm.damping_min = 2.0
	_pm.damping_max = 3.0
	_pm.angle_max = 360.0
	_pm.angular_velocity_min = -40.0
	_pm.angular_velocity_max = 40.0
	_pm.scale_min = 0.7
	_pm.scale_max = 1.0
	_pm.scale_curve = FxTex.curve([Vector2(0.0, 0.3), Vector2(1.0, 2.2)], 3.0)
	_pm.color_ramp = FxTex.ramp([0.0, 0.15, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_pm.turbulence_enabled = true
	_pm.turbulence_noise_strength = 1.5
	_pm.turbulence_noise_scale = 2.5
	_pm.turbulence_influence_min = 0.05
	_pm.turbulence_influence_max = 0.12
	process_material = _pm
	draw_pass_1 = FxTex.smoke_mesh(0.35)
	amount_ratio = 0.0
	_make_puff()
	_make_haze()
	_make_flame()

# One-shot puff: a dozen darker blobs shot out of the pipe at once
func _make_puff() -> void:
	_puff = GPUParticles3D.new()
	_puff.layers = 2
	_puff.amount = 14
	_puff.lifetime = 1.3
	_puff.one_shot = true
	_puff.explosiveness = 0.85
	_puff.emitting = false
	_puff.local_coords = false
	_puff.fixed_fps = 60
	_puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puff.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 30, 60))
	_puff_pm = ParticleProcessMaterial.new()
	_puff_pm.direction = pipe_dir
	_puff_pm.spread = 14.0
	_puff_pm.initial_velocity_min = 3.0
	_puff_pm.initial_velocity_max = 6.0
	_puff_pm.inherit_velocity_ratio = 0.85
	_puff_pm.gravity = Vector3(0.0, 0.4, 0.0)
	_puff_pm.damping_min = 3.0
	_puff_pm.damping_max = 5.0
	_puff_pm.angle_max = 360.0
	_puff_pm.angular_velocity_min = -60.0
	_puff_pm.angular_velocity_max = 60.0
	_puff_pm.scale_min = 0.8
	_puff_pm.scale_max = 1.3
	_puff_pm.scale_curve = FxTex.curve([Vector2(0.0, 0.4), Vector2(0.3, 1.4), Vector2(1.0, 2.8)], 3.0)
	_puff_pm.color_ramp = FxTex.ramp([0.0, 0.06, 0.4, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	_puff.process_material = _puff_pm
	_puff.draw_pass_1 = FxTex.smoke_mesh(0.6)
	add_child(_puff)

func _make_haze() -> void:
	_haze = MeshInstance3D.new()
	_haze.layers = 2
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.6)
	_haze.mesh = q
	var sh := Shader.new()
	sh.code = HAZE_SHADER
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = sh
	_haze.material_override = _haze_mat
	_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_haze.position = pipe_dir.normalized() * 0.5 + Vector3(0, 0.08, 0)
	add_child(_haze)

func _make_flame() -> void:
	flame = GPUParticles3D.new()
	flame.layers = 2
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

# Backfire: a short bang of flame (upshift in the red zone) and a puff after it
func backfire() -> void:
	_pop_t = 0.09
	_fire_puff(1.0)

func _fire_puff(strength: float) -> void:
	if _puff_cool > 0.0:
		return
	_puff_cool = 0.35
	var diesel: bool = str(vehicle.get("engine_fuel")) == "dizel"
	var c: float = 0.1 if diesel else 0.3
	_puff_pm.color = Color(c, c, c, clampf((0.7 if diesel else 0.55) * strength, 0.0, 0.8))
	_puff.amount_ratio = clampf(0.5 + 0.5 * strength, 0.0, 1.0)
	_puff.restart()

func _process(delta: float) -> void:
	if vehicle == null:
		return
	var body := vehicle as RigidBody3D
	var idle: float = float(vehicle.get("idle_rpm"))
	var lim: float = maxf(float(vehicle.get("limiter_rpm")), idle + 1.0)
	var revs: float = clampf((float(vehicle.get("current_rpm")) - idle) / (lim - idle), 0.0, 1.0)
	var thr: float = float(vehicle.get("pedal_throttle"))
	var kmh: float = body.linear_velocity.length() * 3.6
	var diesel: bool = str(vehicle.get("engine_fuel")) == "dizel"
	_puff_cool -= delta

	# puffs: a stab of the throttle, or a gear change under load
	var gear: int = int(vehicle.get("current_gear"))
	if thr > 0.6 and _prev_thr < 0.25:
		_fire_puff(0.6 + 0.4 * revs)
	elif gear != _prev_gear and _prev_gear >= 2 and gear >= 2 and thr > 0.5:
		_fire_puff(0.8)
	_prev_thr = thr
	_prev_gear = gear

	# trail: nothing at idle, wisps from the upper half of the rev range with throttle
	var k: float = smoothstep(0.35, 1.0, revs) * thr
	var wind: float = lerpf(1.0, 0.55, clampf((kmh - 20.0) / 80.0, 0.0, 1.0)) # thins out with speed
	amount_ratio = clampf(k, 0.0, 1.0)
	emitting = k > 0.02
	_pm.initial_velocity_min = 2.0 + 3.0 * revs
	_pm.initial_velocity_max = 3.5 + 5.0 * revs
	if diesel:
		var c: float = lerpf(0.45, 0.1, k)
		_pm.color = Color(c, c, c, (0.15 + 0.5 * k) * wind)
	else:
		_pm.color = Color(0.62, 0.63, 0.66, (0.05 + 0.3 * k) * wind)

	# heat haze: stronger with revs and load, gone when the car is fast (the wake smears it out)
	_haze_mat.set_shader_parameter("strength", (0.5 + 0.8 * revs + 0.5 * thr) * clampf(1.0 - kmh / 90.0, 0.0, 1.0))

	_pop_t -= delta
	var popping: bool = _pop_t > 0.0
	flame.emitting = bool(vehicle.get("turbo_boost_active")) or popping
	var fpm := flame.process_material as ParticleProcessMaterial
	fpm.direction = pipe_dir
	fpm.scale_min = 1.6 if popping else 0.8
	fpm.scale_max = 2.2 if popping else 1.2
