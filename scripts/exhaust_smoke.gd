class_name ExhaustSmoke
extends CPUParticles3D
# Exhaust smoke from one tailpipe: a faint haze at idle that thickens with revs and throttle;
# diesels puff darker soot under load. Particles live in world space but start with most of the
# car's speed (the wake drags the gas along) and are spread over the distance the car covered
# since the last frame, so the plume stays continuous at any speed instead of a row of dots.
# Turbo boost (Shift) and upshift backfires shoot a flame out of the pipe.

var vehicle: Node
var flame: CPUParticles3D
var pipe_pos: Vector3 # tip of the pipe (car-local)
var pipe_dir: Vector3 = Vector3(0.0, 0.15, -1.0) # out of the pipe (car forward is +Z)
var share: float = 1.0 # 1 / number of pipes on the car
var _pop_t: float = 0.0

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # alpha-blended puffs would cast solid black discs
	preprocess = 1.3 # run one lifetime up front: never-emitted particle slots render as black discs (Godot 4.3)
	amount = maxi(int(200.0 * share), 100)
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
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
	grow.max_value = 2.0
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
	_make_flame(tex)
	restart() # applies the preprocess now that every setting is in place

func _make_flame(tex: Texture2D) -> void:
	flame = CPUParticles3D.new()
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.amount = 40
	flame.lifetime = 0.14
	flame.local_coords = true # stays on the pipe at any speed
	flame.emitting = false
	flame.visible = false
	flame.preprocess = 0.14
	flame.direction = Vector3(0, 0, -1)
	flame.spread = 6.0
	flame.gravity = Vector3.ZERO
	flame.initial_velocity_min = 6.0
	flame.initial_velocity_max = 9.0
	flame.scale_amount_min = 0.8
	flame.scale_amount_max = 1.2
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.3))
	flame.scale_amount_curve = shrink
	var heat := Gradient.new() # blue core -> orange -> gone
	heat.set_color(0, Color(0.55, 0.7, 1.0, 1.0))
	heat.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	heat.add_point(0.35, Color(1.0, 0.65, 0.2, 0.9))
	flame.color_ramp = heat
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat
	flame.mesh = quad
	add_child(flame)

# Backfire: a short bang of flame (upshift at high revs)
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
	var load: float = clampf(revs * 0.6 + thr * revs * 0.6, 0.0, 1.0)
	var fwd_v: float = body.linear_velocity.dot(body.global_transform.basis.z)
	var spd: float = absf(fwd_v)
	# at speed the puffs settle far apart behind the car: a shorter life keeps the trail short and dense
	lifetime = lerpf(1.3, 0.45, clampf(spd / 30.0, 0.0, 1.0))
	var puff: float = lerpf(1.0, 2.5, clampf(spd / 40.0, 0.0, 1.0)) # bigger puffs at speed overlap into a streak
	scale_amount_min = 0.7 * puff
	scale_amount_max = 1.1 * puff
	# gas leaves the pipe and is carried along by the wake (85% of the car's speed), then slows
	var v: Vector3 = pipe_dir.normalized() * (1.2 + 4.0 * revs) + Vector3(0.0, 0.0, fwd_v * 0.85)
	direction = v.normalized() if v.length() > 0.01 else pipe_dir
	initial_velocity_min = v.length() * 0.92
	initial_velocity_max = v.length() * 1.08
	spread = lerpf(14.0, 2.0, clampf(spd / 15.0, 0.0, 1.0))
	damping_min = maxf(1.5, spd * 1.0)
	damping_max = maxf(2.5, spd * 1.6)
	# this frame's puffs fill the stretch the pipe moved through since the last frame
	var half: float = maxf(spd * delta * 0.5, 0.005)
	emission_box_extents = Vector3(0.01, 0.01, half)
	position = pipe_pos - Vector3(0.0, 0.0, half * signf(fwd_v))
	var wind: float = lerpf(1.0, 0.5, clampf((spd * 3.6 - 20.0) / 80.0, 0.0, 1.0)) # thins out with speed
	if str(vehicle.get("engine_fuel")) == "dizel":
		var c: float = lerpf(0.55, 0.16, thr)
		color = Color(c, c, c, (0.05 + 0.3 * thr * (0.4 + revs)) * wind)
	else:
		color = Color(0.86, 0.86, 0.88, (0.012 + 0.2 * load) * wind) # many faint puffs: a smooth plume

	_pop_t -= delta
	var popping: bool = _pop_t > 0.0
	flame.emitting = bool(vehicle.get("turbo_boost_active")) or popping
	flame.visible = flame.emitting # never-emitted CPU particles render as a black square
	flame.position = pipe_pos - position # the flame sits on the pipe itself
	flame.direction = pipe_dir
	flame.scale_amount_min = 1.6 if popping else 0.8
	flame.scale_amount_max = 2.2 if popping else 1.2
