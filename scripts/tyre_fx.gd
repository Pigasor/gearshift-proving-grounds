class_name TyreFX
extends Node3D
# Tyre effects from the car's per-wheel contact data (vehicle_controller: wheel_contact_pos,
# wheel_long_slip = wheelspin m/s, wheel_lat_slip = sideways slide m/s, wheel_surface):
# - skid marks: flat strips laid where a spinning, locked or sliding tyre passes - black rubber on
#   tarmac, dark crushed tracks on grass, ruts on dirt / sand (one MultiMesh, oldest marks reused)
# - tyre smoke on hard ground (burnouts, wheelspin, drifts)
# - grass / earth / sand thrown back off a spinning tyre, the way the tyre turns

var vehicle: Node
const MAX_MARKS: int = 6000
const MARK_STEP: float = 0.25 # metres between mark segments
const MARK_LIFE: float = 300.0 # marks fade out over the last 30 s of their 5 minutes
const MARK_FADE: float = 30.0
var _born := PackedFloat32Array()
var _cols := PackedColorArray()
var _oldest: int = 0
var _live: int = 0
var _clock: float = 0.0
var _sweep_t: float = 0.0
var _mm: MultiMesh
var _next: int = 0
var _last: Array = [null, null, null, null] # last mark point per wheel (Vector3), null = not marking
var _smoke: Array[GPUParticles3D] = []
var _debris: Array[GPUParticles3D] = []
const HARD: Array = ["asphalt", "concrete", "kerb"]
const MARK_COLOR: Dictionary = {"grass": Color(0.16, 0.22, 0.07), "dirt": Color(0.22, 0.15, 0.08), "sand": Color(0.45, 0.36, 0.22)}
const DEBRIS_COLOR: Dictionary = {"grass": Color(0.25, 0.55, 0.12), "dirt": Color(0.36, 0.25, 0.14), "sand": Color(0.78, 0.66, 0.44)}

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.disable_receive_shadows = false
	plane.material = mat
	_mm.mesh = plane
	_mm.instance_count = MAX_MARKS
	_mm.visible_instance_count = 0
	_born.resize(MAX_MARKS)
	_cols.resize(MAX_MARKS)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.layers = 2 # render layer 2: the map cameras leave it out
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(MapBuilder.WORLD_MIN.x - 100.0, -50, MapBuilder.WORLD_MIN.y - 100.0), Vector3(MapBuilder.WORLD_MAX.x - MapBuilder.WORLD_MIN.x + 200.0, 500, MapBuilder.WORLD_MAX.y - MapBuilder.WORLD_MIN.y + 200.0)) # marks are all over the map
	add_child(mmi)
	for i in 4:
		_smoke.append(_make_smoke())
		_debris.append(_make_debris())

func _make_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 2.2
	p.local_coords = false
	p.fixed_fps = 60
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.layers = 2
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 30, 60))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.inherit_velocity_ratio = 0.3
	pm.gravity = Vector3(0, 0.6, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -30.0
	pm.angular_velocity_max = 30.0
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	pm.scale_curve = FxTex.curve([Vector2(0.0, 0.4), Vector2(1.0, 3.0)], 3.0)
	pm.color = Color(0.9, 0.9, 0.92, 0.7)
	pm.color_ramp = FxTex.ramp([0.0, 0.08, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.5
	pm.turbulence_noise_scale = 4.0
	p.process_material = pm
	p.draw_pass_1 = FxTex.smoke_mesh(1.1)
	p.top_level = true
	add_child(p)
	return p

func _make_debris() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 0.9
	p.local_coords = false
	p.fixed_fps = 60
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.layers = 2
	p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 20, 40))
	var pm := ParticleProcessMaterial.new()
	pm.spread = 25.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.angle_max = 360.0
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = FxTex.ramp([0.0, 0.8, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.process_material = pm
	# small tumbling bits (clumps of grass / earth)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = FxTex.smoke()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	q.material = m
	p.draw_pass_1 = q
	p.top_level = true
	add_child(p)
	return p

func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	_clock += delta
	_sweep_t -= delta
	if _sweep_t <= 0.0:
		_sweep_t = 0.5
		_expire_marks()
	var body := vehicle as RigidBody3D
	var fwd: Vector3 = body.global_transform.basis.z
	var r_scale: float = clampf(float(vehicle.get("tire_radius")) / 0.32, 0.8, 2.8)
	for i in 4:
		var grounded: bool = vehicle.wheel_is_grounded[i]
		var spin: float = vehicle.wheel_long_slip[i]
		var lat: float = vehicle.wheel_lat_slip[i]
		var speed: float = body.linear_velocity.length()
		var surf: String = vehicle.wheel_surface[i]
		var hard: bool = surf in HARD
		# sliding sideways: past ~7 deg of slip and over 2.5 m/s (normal cornering stays clean)
		var side: float = maxf(absf(lat) - 2.5, 0.0) if absf(lat) > speed * 0.12 else 0.0
		var k: float = clampf((maxf(absf(spin) - 2.0, 0.0) + side) / 8.0, 0.0, 1.0)
		var p: Vector3 = vehicle.wheel_contact_pos[i]
		var n: Vector3 = vehicle.wheel_contact_normal[i]
		# --- skid marks ---
		if grounded and k > 0.0:
			if _last[i] == null or (_last[i] as Vector3).distance_to(p) > 3.0:
				_last[i] = p
			elif (_last[i] as Vector3).distance_to(p) >= MARK_STEP:
				_add_mark(_last[i], p, n, 0.24 * r_scale, k, surf)
				_last[i] = p
		else:
			_last[i] = null
		# --- tyre smoke on hard ground ---
		var sm: GPUParticles3D = _smoke[i]
		sm.emitting = grounded and hard and k > 0.12
		if sm.emitting:
			sm.global_position = p + n * 0.2
			sm.amount_ratio = clampf(k * 1.3, 0.15, 1.0)
		# --- grass / dirt / sand thrown back the way the tyre turns ---
		var db: GPUParticles3D = _debris[i]
		db.emitting = grounded and not hard and (absf(spin) > 1.5 or side > 0.0)
		if db.emitting:
			db.global_position = p + n * 0.1
			db.amount_ratio = clampf(0.25 + k, 0.25, 1.0)
			var pm := db.process_material as ParticleProcessMaterial
			var throw_dir: Vector3 = -fwd * signf(spin) if absf(spin) > 1.5 else -body.global_transform.basis.x * signf(lat)
			pm.direction = (throw_dir + n * 0.8).normalized()
			pm.initial_velocity_max = 4.0 + minf(absf(spin), 12.0) * 0.6
			pm.color = DEBRIS_COLOR.get(surf, Color(0.36, 0.25, 0.14))

# One mark segment from a to b, lying on the ground (a hair above it)
func _add_mark(a: Vector3, b: Vector3, n: Vector3, width: float, k: float, surf: String) -> void:
	var along: Vector3 = b - a
	var len: float = along.length()
	if len < 0.001:
		return
	var z: Vector3 = along / len
	var x: Vector3 = n.cross(z).normalized()
	var basis := Basis(x * width, n, z * (len + 0.04))
	_mm.set_instance_transform(_next, Transform3D(basis, (a + b) * 0.5 + n * 0.015))
	var c: Color = MARK_COLOR.get(surf, Color(0.04, 0.04, 0.045))
	c.a = 0.2 + 0.5 * k
	_mm.set_instance_color(_next, c)
	_born[_next] = _clock
	_cols[_next] = c
	if _live == MAX_MARKS:
		_oldest = (_oldest + 1) % MAX_MARKS # buffer full: this one replaced the oldest
	else:
		_live += 1
	_next = (_next + 1) % MAX_MARKS
	if _mm.visible_instance_count < MAX_MARKS:
		_mm.visible_instance_count += 1 # grows until full, then the oldest marks are reused

# Marks are laid in time order (ring buffer): from the oldest one on, fade those in their last
# 30 s and remove those older than 5 minutes
func _expire_marks() -> void:
	var i: int = _oldest
	var k: int = 0
	while k < _live:
		var age: float = _clock - _born[i]
		if age < MARK_LIFE - MARK_FADE:
			break
		if age >= MARK_LIFE:
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			_oldest = (_oldest + 1) % MAX_MARKS
			_live -= 1
			i = _oldest
			continue
		var c: Color = _cols[i]
		c.a *= (MARK_LIFE - age) / MARK_FADE
		_mm.set_instance_color(i, c)
		i = (i + 1) % MAX_MARKS
		k += 1
