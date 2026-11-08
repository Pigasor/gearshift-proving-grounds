class_name MapBuilder
extends Node3D

func _ready() -> void:
	_load_textured_materials()
	_build_floor_and_perimeter()
	_build_mega_highway()
	AirportBuilder.new().build(self) # runway, taxiways, apron, terminal, tower, hangars, planes
	_build_grand_prix_circuit()
	_build_drift_arena()
	_build_stunt_superpark()
	_build_offroad_dunes()
	_build_suspension_zone()
	_build_hill_park()
	_build_environment_props()

# --- Textured Materials ---
var mat_grass: StandardMaterial3D
var mat_asphalt: StandardMaterial3D
var mat_road_asphalt: StandardMaterial3D
var mat_track: StandardMaterial3D
var mat_kerb_striped: StandardMaterial3D
var mat_concrete_wall: StandardMaterial3D
var mat_dirt_dunes: StandardMaterial3D
var mat_metal_blue: StandardMaterial3D
var mat_ramp_orange: StandardMaterial3D
var mat_sand: StandardMaterial3D
var mat_road_white: StandardMaterial3D
var mat_road_yellow: StandardMaterial3D
var mat_barrier_red: StandardMaterial3D

# Surface type of a map material (the car reads it under each wheel for grip)
func _surface_for(mat: Material) -> String:
	var sm := mat as StandardMaterial3D
	if sm == null:
		return "asphalt"
	if mat == mat_kerb_striped:
		return "kerb"
	if mat == mat_concrete_wall:
		return "concrete"
	if mat == mat_sand:
		return "sand"
	if sm.albedo_texture != null and mat_grass and sm.albedo_texture == mat_grass.albedo_texture:
		return "grass"
	if sm.albedo_texture != null and mat_dirt_dunes and sm.albedo_texture == mat_dirt_dunes.albedo_texture:
		return "dirt"
	return "asphalt"

func _load_tex(path: String) -> Texture2D:
	# Load the IMPORTED texture (works in exported builds; the raw .png isn't shipped there).
	# Mipmaps are enabled in the .import settings so distant ground doesn't shimmer.
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			return tex
	# Fallback (e.g. textures just regenerated and not imported yet)
	var img := Image.load_from_file(path)
	if img:
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img)
	return null

func _load_textured_materials() -> void:
	var tex_grass: Texture2D = _load_tex("res://textures/grass_albedo.png")
	var tex_asphalt: Texture2D = _load_tex("res://textures/asphalt_albedo.png")
	var tex_road: Texture2D = _load_tex("res://textures/road_asphalt.png")
	var tex_curb: Texture2D = _load_tex("res://textures/curb_striped.png")
	var tex_concrete: Texture2D = _load_tex("res://textures/concrete_wall.png")
	var tex_dirt: Texture2D = _load_tex("res://textures/dirt_albedo.png")

	# 1. Natural Grass Landscape (Triplanar mapping prevents any UV stretching)
	mat_grass = StandardMaterial3D.new()
	mat_grass.albedo_texture = tex_grass
	mat_grass.uv1_triplanar = true
	mat_grass.uv1_world_triplanar = true
	mat_grass.uv1_scale = Vector3(0.08, 0.08, 0.08)
	mat_grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_grass.roughness = 0.92

	# 2. Realistic Dark Asphalt (World Triplanar)
	mat_asphalt = StandardMaterial3D.new()
	mat_asphalt.albedo_texture = tex_asphalt
	mat_asphalt.uv1_triplanar = true
	mat_asphalt.uv1_world_triplanar = true
	mat_asphalt.uv1_scale = Vector3(0.2, 0.2, 0.2)
	mat_asphalt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_asphalt.roughness = 0.82

	# 3. Highway Striped Road
	mat_road_asphalt = StandardMaterial3D.new()
	mat_road_asphalt.albedo_texture = tex_road
	mat_road_asphalt.uv1_scale = Vector3(1, 140, 1)
	mat_road_asphalt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_road_asphalt.roughness = 0.78

	# 4. Racing Track Tarmac (World Triplanar)
	mat_track = StandardMaterial3D.new()
	mat_track.albedo_texture = tex_asphalt
	mat_track.albedo_color = Color(0.82, 0.83, 0.86)
	mat_track.uv1_triplanar = true
	mat_track.uv1_world_triplanar = true
	mat_track.uv1_scale = Vector3(0.18, 0.18, 0.18)
	mat_track.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_track.roughness = 0.75

	# 5. Red & White Striped Racing Curbs
	mat_kerb_striped = StandardMaterial3D.new()
	mat_kerb_striped.albedo_texture = tex_curb
	mat_kerb_striped.uv1_scale = Vector3(1, 8, 1)
	mat_kerb_striped.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_kerb_striped.roughness = 0.65

	# 6. Concrete Barrier Walls (World Triplanar)
	mat_concrete_wall = StandardMaterial3D.new()
	mat_concrete_wall.albedo_texture = tex_concrete
	mat_concrete_wall.uv1_triplanar = true
	mat_concrete_wall.uv1_world_triplanar = true
	mat_concrete_wall.uv1_scale = Vector3(0.22, 0.22, 0.22)
	mat_concrete_wall.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_concrete_wall.roughness = 0.72

	# 7. Off-road Dirt / Sand / Shoulders (World Triplanar)
	mat_dirt_dunes = StandardMaterial3D.new()
	mat_dirt_dunes.albedo_texture = tex_dirt
	mat_dirt_dunes.uv1_triplanar = true
	mat_dirt_dunes.uv1_world_triplanar = true
	mat_dirt_dunes.uv1_scale = Vector3(0.12, 0.12, 0.12)
	mat_dirt_dunes.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_dirt_dunes.roughness = 0.94

	# Accents
	mat_metal_blue = StandardMaterial3D.new()
	mat_metal_blue.albedo_color = Color(0.12, 0.32, 0.65)
	mat_metal_blue.metallic = 0.7
	mat_metal_blue.roughness = 0.3

	mat_ramp_orange = StandardMaterial3D.new()
	mat_ramp_orange.albedo_color = Color(0.96, 0.42, 0.08)
	mat_ramp_orange.metallic = 0.4
	mat_ramp_orange.roughness = 0.35

	mat_sand = StandardMaterial3D.new()
	mat_sand.albedo_color = Color(0.76, 0.66, 0.48)
	mat_sand.roughness = 0.95

	mat_road_white = StandardMaterial3D.new()
	mat_road_white.albedo_color = Color(0.95, 0.95, 0.98)
	mat_road_white.roughness = 0.35

	mat_road_yellow = StandardMaterial3D.new()
	mat_road_yellow.albedo_color = Color(0.98, 0.78, 0.08)
	mat_road_yellow.roughness = 0.35

	mat_barrier_red = StandardMaterial3D.new()
	mat_barrier_red.albedo_color = Color(0.85, 0.14, 0.14)
	mat_barrier_red.roughness = 0.4

func _create_static_box(pos: Vector3, size: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	body.set_meta("surface", _surface_for(mat)) # tyre grip depends on it

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mesh_inst.mesh = mesh
	body.add_child(mesh_inst)

	add_child(body)
	return body

# Painted road markings: visual only. As physics boxes they stuck out ~1.5 cm above the road
# and every dash was a small ledge the car bumped into.
func _create_marking(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mesh_inst.mesh = mesh
	mesh_inst.position = pos
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_inst)

# --- 1. REALISTIC NATURAL GRASS TERRAIN & PERIMETER ---
func _build_floor_and_perimeter() -> void:
	# Main meadow grass terrain (3200m x 3200m) with triplanar mapping
	_create_static_box(Vector3(0, -1.0, 0), Vector3(3200, 2.0, 3200), mat_grass)

	# Concrete boundary walls (1500m out in all 4 directions)
	var boundary: float = 1500.0
	var wall_h: float = 4.0
	var wall_t: float = 2.5
	_create_static_box(Vector3(0, wall_h * 0.5, boundary), Vector3(boundary * 2.0, wall_h, wall_t), mat_concrete_wall)
	_create_static_box(Vector3(0, wall_h * 0.5, -boundary), Vector3(boundary * 2.0, wall_h, wall_t), mat_concrete_wall)
	_create_static_box(Vector3(boundary, wall_h * 0.5, 0), Vector3(wall_t, wall_h, boundary * 2.0), mat_concrete_wall)
	_create_static_box(Vector3(-boundary, wall_h * 0.5, 0), Vector3(wall_t, wall_h, boundary * 2.0), mat_concrete_wall)

# --- 3. MEGA HIGHWAY RING (2.6km x 2.6km With Real Road Textures) ---
func _build_mega_highway() -> void:
	# One continuous road ribbon: 4 straights joined by rounded, smoothly banked corners.
	# (It used to be separate boxes: the road texture was stretched/shifted by the box UVs,
	# the straights overlapped at the corners (flickering) and the banked corners were tilted
	# boxes sticking out of the ground.)
	var hw_w: float = 24.0
	var d: float = 1300.0
	var corner_r: float = 180.0
	var max_bank_deg: float = 8.0
	var base_y: float = 0.07

	# Centre-line samples: [position xz, outward normal xz, bank angle]
	var samples: Array = []
	var cs: Array = [ # corner centres with start/end angles, followed by the straight after them
		[Vector2(d - corner_r, d - corner_r), 90.0, 0.0],
		[Vector2(d - corner_r, -(d - corner_r)), 0.0, -90.0],
		[Vector2(-(d - corner_r), -(d - corner_r)), -90.0, -180.0],
		[Vector2(-(d - corner_r), d - corner_r), 180.0, 90.0],
	]
	for k in range(4):
		var c: Vector2 = cs[k][0]
		var a0: float = deg_to_rad(cs[k][1])
		var a1: float = deg_to_rad(cs[k][2])
		# Fine steps + a bank that eases in/out (sin^2: no sudden twist where the corner starts).
		# Coarse steps with a fast-changing bank made twisted quads whose diagonal formed a ~6 cm
		# ridge every 7 m, so cars hopped through the corners.
		var corner_steps: int = 140
		for s in range(corner_steps + 1):
			var t: float = float(s) / float(corner_steps)
			var a: float = lerpf(a0, a1, t)
			var n := Vector2(cos(a), sin(a))
			samples.append([c + n * corner_r, n, deg_to_rad(max_bank_deg) * pow(sin(PI * t), 2.0)])
		# straight to the next corner
		var nk: int = (k + 1) % 4
		var end_c: Vector2 = cs[nk][0]
		var end_n := Vector2(cos(deg_to_rad(cs[nk][1])), sin(deg_to_rad(cs[nk][1])))
		var start_p: Vector2 = c + Vector2(cos(a1), sin(a1)) * corner_r
		var end_p: Vector2 = end_c + end_n * corner_r
		var straight_steps: int = 16
		for s in range(1, straight_steps):
			var t2: float = float(s) / float(straight_steps)
			samples.append([start_p.lerp(end_p, t2), end_n, 0.0])
	samples.append(samples[0]) # close the loop

	# Edge points
	var road_in: Array[Vector3] = []
	var road_out: Array[Vector3] = []
	var sh_in: Array[Vector3] = []
	var slope_out: Array[Vector3] = []
	var dist: Array[float] = []
	var acc: float = 0.0
	for i in range(samples.size()):
		var p: Vector2 = samples[i][0]
		var n: Vector2 = samples[i][1]
		var bank: float = samples[i][2]
		if i > 0:
			acc += p.distance_to(samples[i - 1][0])
		dist.append(acc)
		var pi_xz: Vector2 = p - n * hw_w * 0.5
		var po_xz: Vector2 = p + n * hw_w * 0.5
		var outer_y: float = base_y + hw_w * tan(bank)
		road_in.append(Vector3(pi_xz.x, base_y, pi_xz.y))
		road_out.append(Vector3(po_xz.x, outer_y, po_xz.y))
		var shi: Vector2 = pi_xz - n * 6.0
		sh_in.append(Vector3(shi.x, 0.045, shi.y))
		var so: Vector2 = po_xz + n * (6.0 + outer_y * 2.0) # earth embankment under raised outer edge
		slope_out.append(Vector3(so.x, -0.05, so.y))

	var mat_ribbon: StandardMaterial3D = mat_road_asphalt.duplicate() as StandardMaterial3D
	mat_ribbon.uv1_scale = Vector3(1, 1, 1)
	mat_ribbon.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_shoulder: StandardMaterial3D = mat_dirt_dunes.duplicate() as StandardMaterial3D
	mat_shoulder.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Road: u = 0..1 across the width (lane markings line up), v repeats every 96 m along it
	var road_faces := PackedVector3Array()
	_add_strip(road_in, road_out, dist, 0.0, 1.0, 1.0 / 96.0, mat_ribbon, road_faces, 8)
	var dirt_faces := PackedVector3Array()
	_add_strip(sh_in, road_in, dist, 0.0, 0.5, 1.0 / 12.0, mat_shoulder, dirt_faces)
	_add_strip(road_out, slope_out, dist, 0.0, 0.5, 1.0 / 12.0, mat_shoulder, dirt_faces)
	_add_collision_body(road_faces, "asphalt")
	_add_collision_body(dirt_faces, "dirt")

	# Concrete guardrails along the outer edge of the north & south straights
	var straight_len: float = (d - corner_r) * 2.0
	_create_static_box(Vector3(0, 0.8, d + 19.5), Vector3(straight_len, 1.4, 0.8), mat_concrete_wall)
	_create_static_box(Vector3(0, 0.8, -d - 19.5), Vector3(straight_len, 1.4, 0.8), mat_concrete_wall)

# Static trimesh body from collected faces, tagged with its surface type.
func _add_collision_body(faces: PackedVector3Array, surface: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("surface", surface)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body

# A textured strip between two edge polylines (visual mesh + collision faces).
# `cols` splits the strip across its width too, so a twisting (banked) surface stays smooth.
func _add_strip(left: Array[Vector3], right: Array[Vector3], dist: Array[float], u_left: float, u_right: float, v_scale: float, mat: Material, faces: PackedVector3Array, cols: int = 1) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = left.size()
	var row: int = cols + 1
	for i in range(count):
		var fwd: Vector3 = left[mini(i + 1, count - 1)] - left[maxi(i - 1, 0)]
		var across: Vector3 = right[i] - left[i]
		var n: Vector3 = across.cross(fwd).normalized()
		if n.y < 0.0:
			n = -n
		for c in range(row):
			var k: float = float(c) / float(cols)
			st.set_normal(n)
			st.set_uv(Vector2(lerpf(u_left, u_right, k), dist[i] * v_scale))
			st.add_vertex(left[i].lerp(right[i], k))
	# Godot draws clockwise triangles as the front face. Which index order is clockwise from above
	# depends on the strip's direction, so pick it from the first segment.
	var flip: bool = false
	if count > 1:
		flip = (left[1] - left[0]).cross(right[0] - left[0]).y > 0.0
	for i in range(count - 1):
		for c in range(cols):
			var a: int = i * row + c # this row, left column
			var b: int = a + 1 # this row, right column
			var a2: int = a + row # next row
			var b2: int = b + row
			var order: Array = [a, b, a2, b, b2, a2] if flip else [a, a2, b, b, a2, b2]
			for q in order:
				st.add_index(q)
			var k0: float = float(c) / float(cols)
			var k1: float = float(c + 1) / float(cols)
			var pa: Vector3 = left[i].lerp(right[i], k0)
			var pb: Vector3 = left[i].lerp(right[i], k1)
			var pa2: Vector3 = left[i + 1].lerp(right[i + 1], k0)
			var pb2: Vector3 = left[i + 1].lerp(right[i + 1], k1)
			for p in [pa, pb, pa2, pb, pb2, pa2]:
				faces.append(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)

# --- 5. GRAND PRIX CIRCUIT (West Sector) ---
# A real closed circuit (~3.3 km): smooth spline corners, kerbs on the corners, start/finish
# gantry and timing gates for lap times. Driven clockwise-ish, start line on the east straight.
const CIRCUIT_WIDTH: float = 14.0
const CIRCUIT_START := Vector3(-200, 0.0, -200) # start/finish line (car heads +Z)
const CIRCUIT_POINTS: Array[Vector2] = [
	Vector2(-200, -300), Vector2(-200, -80), Vector2(-200, 140), Vector2(-200, 380),
	Vector2(-218, 520), Vector2(-275, 590), Vector2(-355, 598), Vector2(-415, 555), Vector2(-432, 470),
	Vector2(-395, 395), Vector2(-320, 360), Vector2(-300, 285), Vector2(-340, 205), Vector2(-420, 160),
	Vector2(-455, 60), Vector2(-448, -60), Vector2(-390, -125), Vector2(-335, -185), Vector2(-360, -265),
	Vector2(-430, -335), Vector2(-455, -425), Vector2(-415, -505), Vector2(-330, -535), Vector2(-255, -505),
	Vector2(-212, -420),
]

func _build_grand_prix_circuit() -> void:
	var y: float = 0.08
	var half: float = CIRCUIT_WIDTH * 0.5
	# 1) Closed Catmull-Rom spline through the control points
	var pts: Array[Vector2] = []
	var n_cp: int = CIRCUIT_POINTS.size()
	var steps: int = 14
	for i in range(n_cp):
		var p0: Vector2 = CIRCUIT_POINTS[(i - 1 + n_cp) % n_cp]
		var p1: Vector2 = CIRCUIT_POINTS[i]
		var p2: Vector2 = CIRCUIT_POINTS[(i + 1) % n_cp]
		var p3: Vector2 = CIRCUIT_POINTS[(i + 2) % n_cp]
		for s in range(steps):
			var t: float = float(s) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	# Rotate the list so it starts at the sample nearest the start line
	var best_i: int = 0
	for i in range(pts.size()):
		if pts[i].distance_to(Vector2(CIRCUIT_START.x, CIRCUIT_START.z)) < pts[best_i].distance_to(Vector2(CIRCUIT_START.x, CIRCUIT_START.z)):
			best_i = i
	pts = pts.slice(best_i) + pts.slice(0, best_i)
	pts.append(pts[0]) # close the loop
	var count: int = pts.size()

	# 2) Edges, distance along the track and curvature
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var dist: Array[float] = []
	var curv: Array[float] = []
	var tangents: Array[Vector2] = []
	var acc: float = 0.0
	for i in range(count):
		var prev: Vector2 = pts[(i - 1 + count - 1) % (count - 1)]
		var next: Vector2 = pts[(i + 1) % (count - 1)] if i < count - 1 else pts[1]
		var tan: Vector2 = (next - prev).normalized()
		tangents.append(tan)
		var nrm := Vector2(-tan.y, tan.x)
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		dist.append(acc)
		left.append(Vector3(pts[i].x + nrm.x * half, y, pts[i].y + nrm.y * half))
		right.append(Vector3(pts[i].x - nrm.x * half, y, pts[i].y - nrm.y * half))
		var seg: float = maxf(prev.distance_to(next), 0.01)
		var t_prev: Vector2 = (pts[i] - prev).normalized()
		var t_next: Vector2 = (next - pts[i]).normalized()
		curv.append(absf(t_prev.angle_to(t_next)) / (seg * 0.5)) # 1 / radius

	# 3) Tarmac + painted white edge lines (visual)
	var track_faces := PackedVector3Array()
	_add_strip(left, right, dist, 0.0, 1.0, 1.0 / 20.0, mat_track, track_faces)
	_add_collision_body(track_faces, "asphalt")
	var unused := PackedVector3Array()
	var edge_l: Array[Vector3] = []
	var edge_r: Array[Vector3] = []
	var line_l: Array[Vector3] = []
	var line_r: Array[Vector3] = []
	var lift := Vector3(0, 0.006, 0)
	for i in range(count):
		var inward: Vector3 = (right[i] - left[i]).normalized()
		edge_l.append(left[i] + lift)
		edge_r.append(right[i] + lift)
		line_l.append(left[i] + inward * 0.35 + lift)
		line_r.append(right[i] - inward * 0.35 + lift)
	_add_strip(edge_l, line_l, dist, 0.0, 1.0, 0.1, mat_road_white, unused)
	_add_strip(line_r, edge_r, dist, 0.0, 1.0, 0.1, mat_road_white, unused)

	# 4) Red/white kerbs on both edges wherever the corner is tighter than ~220 m radius
	var kerb_faces := PackedVector3Array()
	var i0: int = -1
	for i in range(count + 1):
		var tight: bool = i < count and curv[i] > 1.0 / 220.0
		if tight and i0 == -1:
			i0 = maxi(i - 2, 0)
		elif not tight and i0 != -1:
			var i1: int = mini(i + 2, count)
			var kl_in: Array[Vector3] = []
			var kl_out: Array[Vector3] = []
			var kr_in: Array[Vector3] = []
			var kr_out: Array[Vector3] = []
			var kd: Array[float] = []
			for k in range(i0, i1):
				var across: Vector3 = (left[k] - right[k]).normalized()
				kl_in.append(left[k] + Vector3(0, 0.02, 0))
				kl_out.append(left[k] + across * 1.6 + Vector3(0, 0.02, 0))
				kr_in.append(right[k] + Vector3(0, 0.02, 0))
				kr_out.append(right[k] - across * 1.6 + Vector3(0, 0.02, 0))
				kd.append(dist[k])
			_add_strip(kl_in, kl_out, kd, 0.0, 1.0, 1.0 / 8.0, mat_kerb_striped, kerb_faces)
			_add_strip(kr_out, kr_in, kd, 0.0, 1.0, 1.0 / 8.0, mat_kerb_striped, kerb_faces)
			i0 = -1
	if kerb_faces.size() > 0:
		_add_collision_body(kerb_faces, "kerb")

	# 5) Start/finish line & gantry
	_create_marking(CIRCUIT_START + Vector3(0, y + 0.012, 0), Vector3(CIRCUIT_WIDTH, 0.01, 1.2), mat_road_white)
	_create_static_box(CIRCUIT_START + Vector3(-(half + 3.0), 3.5, 0), Vector3(0.8, 7.0, 0.8), mat_concrete_wall)
	_create_static_box(CIRCUIT_START + Vector3(half + 3.0, 3.5, 0), Vector3(0.8, 7.0, 0.8), mat_concrete_wall)
	_create_static_box(CIRCUIT_START + Vector3(0, 7.2, 0), Vector3(CIRCUIT_WIDTH + 7.0, 1.0, 1.0), mat_kerb_striped)

	# 6) Timing gates (gate 0 = start/finish) for the lap timer
	var timer := Node.new()
	timer.set_script(load("res://scripts/lap_timer.gd"))
	timer.name = "LapTimer"
	add_child(timer)
	var gate_count: int = 10
	for g in range(gate_count):
		var idx: int = int(float(g) / float(gate_count) * float(count - 1))
		var area := Area3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(CIRCUIT_WIDTH + 24.0, 10.0, 4.0)
		var col := CollisionShape3D.new()
		col.shape = shape
		area.add_child(col)
		var tan3 := Vector3(tangents[idx].x, 0, tangents[idx].y)
		area.transform = Transform3D(Basis.looking_at(-tan3, Vector3.UP), Vector3(pts[idx].x, 3.0, pts[idx].y))
		area.body_entered.connect(timer.on_gate.bind(g))
		add_child(area)
	timer.set("gate_count", gate_count)
	timer.set("track_length_m", dist[count - 1])

# --- 6. DRIFT ARENA & GYMKHANA (East Sector) ---
func _build_drift_arena() -> void:
	var d_center: Vector3 = Vector3(250, 0.03, -220)

	# 200m Textured Drift Pad
	_create_static_box(d_center, Vector3(200, 0.05, 200), mat_asphalt)
	_create_static_box(d_center, Vector3(224, 0.03, 224), mat_dirt_dunes)

	# Center Donut Pylon
	_create_static_box(d_center + Vector3(0, 3.0, 0), Vector3(4.0, 6.0, 4.0), mat_ramp_orange)

	# Donut Rings with kerb texturing
	var angles: Array[float] = [0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0, 330.0]
	for a in angles:
		var rad: float = deg_to_rad(a)
		var p1: Vector3 = d_center + Vector3(sin(rad) * 38.0, 0.4, cos(rad) * 38.0)
		_create_static_box(p1, Vector3(2.0, 0.8, 2.0), mat_kerb_striped)
		var p2: Vector3 = d_center + Vector3(sin(rad) * 85.0, 0.4, cos(rad) * 85.0)
		_create_static_box(p2, Vector3(2.5, 0.8, 2.5), mat_concrete_wall)

	# Shipping Containers for gymkhana
	_create_static_box(d_center + Vector3(-55, 2.2, -45), Vector3(16, 4.4, 4.5), mat_metal_blue)
	_create_static_box(d_center + Vector3(55, 2.2, 45), Vector3(16, 4.4, 4.5), mat_ramp_orange)

# --- 7. STUNT SUPERPARK (Mega Ramps, Loop, Gap Jumps) ---
func _build_stunt_superpark() -> void:
	var s_x: float = 150.0

	# All ramps are curved kickers rising towards +Z (the way you arrive from the stunt-park spawn).
	# They used to be tilted boxes: a hard kink from flat to 15-34° that the car slammed into,
	# and the first one even faced the wrong way (a 4 m wall).
	# Ramp 1: 15° warm-up kicker
	_create_kicker(Vector3(s_x, 0, 80), 1.0, 16.0, 15.0, 2.5, mat_metal_blue)
	# Ramp 2: 25° high-flyer
	_create_kicker(Vector3(s_x, 0, 215), 1.0, 18.0, 25.0, 6.0, mat_ramp_orange)
	# Ramp 3: gap jump - two identical 30° / 9 m ramps facing each other over a sand pit
	_create_kicker(Vector3(s_x + 55, 0, 380), 1.0, 20.0, 30.0, 9.0, mat_ramp_orange)
	_create_static_box(Vector3(s_x + 55, 0.04, 455), Vector3(26, 0.06, 40), mat_sand)
	_create_kicker(Vector3(s_x + 55, 0, 545), -1.0, 22.0, 30.0, 9.0, mat_metal_blue) # same as the orange one: jumps work both ways
	# (The floating wall-ride slab and the odd-angled corkscrew ramp were removed.)

# --- 8. OFF-ROAD & DESERT DUNES PARK (East-North Sector) ---
func _build_offroad_dunes() -> void:
	var off_center: Vector3 = Vector3(480, 0.03, 300)

	# 700m x 700m Textured Dirt Park
	_create_static_box(off_center, Vector3(700, 0.06, 700), mat_dirt_dunes)

	# Rolling dirt mounds (real bumpy hills; they used to be tilted 80 m boxes floating half in the air)
	var dunes: Array = [
		[Vector3(380, 0, 170), 34.0, 4.5], [Vector3(590, 0, 330), 38.0, 6.0], [Vector3(420, 0, 450), 30.0, 5.0],
		[Vector3(570, 0, 530), 36.0, 4.0], [Vector3(300, 0, 380), 28.0, 3.5], [Vector3(660, 0, 160), 32.0, 5.5],
	]
	for i in range(dunes.size()):
		_create_hill(dunes[i][0], dunes[i][1], dunes[i][2], mat_dirt_dunes, 40 + i)

	# Off-road table-top jump: sits ON the ground (it used to float 1.7 m up, so a car falling off
	# its edge got stuck underneath it), with a take-off ramp and a landing ramp
	var tt: Vector3 = Vector3(off_center.x, 0.0, off_center.z)
	var top_h: float = 3.0
	var table_len: float = 30.0
	_create_static_box(tt + Vector3(0, top_h * 0.5, 0), Vector3(20, top_h, table_len), mat_dirt_dunes)
	# curved ramps up onto both ends (no hard kink at the bottom)
	var k_run: float = top_h / tan(deg_to_rad(18.0) * 0.5)
	_create_kicker(tt + Vector3(0, 0, -table_len * 0.5 - k_run), 1.0, 20.0, 18.0, top_h, mat_dirt_dunes)
	_create_kicker(tt + Vector3(0, 0, table_len * 0.5 + k_run), -1.0, 20.0, 18.0, top_h, mat_dirt_dunes)

# --- 9. SUSPENSION TEST ZONE (Between Runway and Circuit) ---
func _build_suspension_zone() -> void:
	var susp_x: float = -75.0
	var susp_z_start: float = -220.0

	_create_static_box(Vector3(susp_x, 0.03, susp_z_start + 100), Vector3(16, 0.05, 230), mat_asphalt)

	# 20 Washboard Metal Bumps
	for i in range(20):
		var b_z: float = susp_z_start + i * 9.0
		var b_h: float = 0.16 + (i * 0.015)
		var mat_b: Material = mat_kerb_striped if (i % 2 == 0) else mat_metal_blue
		_create_static_box(Vector3(susp_x, b_h * 0.5, b_z), Vector3(15.5, b_h, 1.5), mat_b)

	# Stepped Curbs
	_create_static_box(Vector3(susp_x - 5.0, 0.22, susp_z_start + 195), Vector3(5.0, 0.4, 28.0), mat_concrete_wall)
	_create_static_box(Vector3(susp_x + 5.0, 0.22, susp_z_start + 205), Vector3(5.0, 0.4, 28.0), mat_kerb_striped)

# --- 9b. HILL CLIMB PARK (West, centre X: -800) - small, medium & high smooth hills ---
const HILL_PARK_CENTER: Vector3 = Vector3(-800, 0, 0)

func _build_hill_park() -> void:
	var c: Vector3 = HILL_PARK_CENTER
	# Dirt base so the park reads as an off-road zone (2 cm high, harmless edge for the wheels)
	_create_static_box(c + Vector3(0, -0.0, 0), Vector3(560, 0.04, 820), mat_dirt_dunes)

	var mat_hill_grass: StandardMaterial3D = mat_grass.duplicate() as StandardMaterial3D
	mat_hill_grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_hill_dirt: StandardMaterial3D = mat_dirt_dunes.duplicate() as StandardMaterial3D
	mat_hill_dirt.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Row 1 - SMALL bumps / mounds (1.5-2.5 m high, ~10-15 deg slopes): z = -320
	for i in range(8):
		var x: float = -200.0 + i * 57.0
		var z: float = -320.0 + (25.0 if i % 2 == 0 else -25.0)
		_create_hill(c + Vector3(x, 0, z), 11.0 + (i % 3) * 2.0, 1.5 + (i % 3) * 0.5, mat_hill_grass, i)

	# Row 2 - MEDIUM hills (5-7 m high, ~18-22 deg slopes): z = -140
	var med_heights: Array[float] = [5.0, 6.0, 7.0, 6.0, 5.5]
	for i in range(5):
		_create_hill(c + Vector3(-200.0 + i * 100.0, 0, -140.0), 26.0, med_heights[i], mat_hill_grass, 10 + i)

	# Row 3 - HIGH hills (14 / 18 / 24 m, up to ~30 deg) - monster truck territory: z = +130
	_create_hill(c + Vector3(-170.0, 0, 130.0), 46.0, 14.0, mat_hill_dirt, 20)
	_create_hill(c + Vector3(0.0, 0, 150.0), 52.0, 18.0, mat_hill_dirt, 21)
	_create_hill(c + Vector3(175.0, 0, 130.0), 64.0, 24.0, mat_hill_dirt, 22)

	# Row 4 - Rolling twin-peak ridge for jumps between crests: z = +320
	_create_hill(c + Vector3(-60.0, 0, 320.0), 30.0, 8.0, mat_hill_grass, 30)
	_create_hill(c + Vector3(-15.0, 0, 330.0), 28.0, 9.0, mat_hill_grass, 31)
	_create_hill(c + Vector3(40.0, 0, 320.0), 30.0, 7.0, mat_hill_grass, 32)

# Natural-looking hill: irregular outline, rolling noise across the surface and a few bumps /
# ledges on the slopes and top. Mesh + exact trimesh collision, so each wheel follows every bump.
func _create_hill(center: Vector3, radius: float, height: float, mat: Material, seed_i: int = 0) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1337 + seed_i * 101
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + seed_i * 31
	var ph1: float = rng.randf() * TAU
	var ph2: float = rng.randf() * TAU
	var stretch: float = rng.randf_range(0.85, 1.15) # slightly oval
	var bump_amp: float = 0.25 + 0.03 * height # rolling unevenness
	# Distinct bumps ("cikintilar"): [x, z, width, height]
	var lumps: Array = []
	for k in range(3 + int(radius / 12.0)):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf_range(0.0, 0.7) * radius
		lumps.append([cos(a) * d, sin(a) * d, rng.randf_range(4.0, 7.0), rng.randf_range(0.3, 0.45 + 0.022 * height)])

	var extent: float = radius * 1.25
	var n: int = clampi(int(extent * 2.0 / 1.6), 16, 110) # grid cells per side (~1.6 m)
	var cell: float = extent * 2.0 / float(n)
	var row: int = n + 1
	var heights := PackedFloat32Array()
	heights.resize(row * row)
	for j in range(row):
		for i in range(row):
			var lx: float = -extent + i * cell
			var lz: float = -extent + j * cell
			var h: float = -0.06 # outside: just under the grass
			var r: float = sqrt(lx * lx + (lz / stretch) * (lz / stretch))
			var ang: float = atan2(lz, lx)
			var r_eff: float = radius * (1.0 + 0.13 * sin(3.0 * ang + ph1) + 0.07 * sin(5.0 * ang + ph2))
			var t: float = r / r_eff
			if t < 1.0:
				var env: float = 1.0 - t * t # bumps fade out towards the edge
				h += height * 0.5 * (1.0 + cos(PI * t))
				h += noise.get_noise_2d(center.x + lx, center.z + lz) * bump_amp * env
				for L in lumps:
					var dx: float = lx - L[0]
					var dz: float = lz - L[1]
					h += L[3] * exp(-(dx * dx + dz * dz) / (L[2] * L[2])) * env
				h = maxf(h, -0.06)
			heights[j * row + i] = h

	# Vertices with smooth normals from the height grid
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(row):
		for i in range(row):
			var hl: float = heights[j * row + maxi(i - 1, 0)]
			var hr: float = heights[j * row + mini(i + 1, n)]
			var hd: float = heights[maxi(j - 1, 0) * row + i]
			var hu: float = heights[mini(j + 1, n) * row + i]
			st.set_normal(Vector3(hl - hr, 2.0 * cell, hd - hu).normalized())
			var p := Vector3(-extent + i * cell, heights[j * row + i], -extent + j * cell)
			st.set_uv(Vector2(p.x, p.z) * 0.1)
			st.add_vertex(p)
	var faces := PackedVector3Array()
	for j in range(n):
		for i in range(n):
			var a0: int = j * row + i
			var quad: Array[int] = [a0, a0 + 1, a0 + row, a0 + 1, a0 + row + 1, a0 + row] # clockwise = front face in Godot
			for q in quad:
				st.add_index(q)
				faces.append(Vector3(-extent + (q % row) * cell, heights[q], -extent + (q / row) * cell))

	var body := StaticBody3D.new()
	body.position = center
	body.set_meta("surface", _surface_for(mat))
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

# --- 10. FLOODLIGHT TOWERS & PIT BUILDINGS ---
func _build_environment_props() -> void:
	# (The masts that stood beside the old drag strip are gone: the runway has its own edge lights,
	# and the apron has flood-light masts - see AirportBuilder.)
	var light_positions: Array[Vector3] = [
		Vector3(250, 0, -120), Vector3(250, 0, -320),
		Vector3(-220, 0, -250), Vector3(-220, 0, 250),
		Vector3(180, 0, 160),  Vector3(180, 0, 330), # beside the ramp lane, not in it
		Vector3(480, 0, 150),  Vector3(480, 0, 450)
	]

	for pos in light_positions:
		_create_static_box(pos + Vector3(0, 9.0, 0), Vector3(0.6, 18.0, 0.6), mat_concrete_wall)
		_create_static_box(pos + Vector3(0, 17.8, 0), Vector3(3.2, 0.5, 0.8), mat_metal_blue)

		var light: OmniLight3D = OmniLight3D.new()
		light.position = pos + Vector3(0, 17.0, 0)
		light.light_color = Color(1.0, 0.95, 0.88)
		light.light_energy = 3.5
		light.omni_range = 75.0
		light.add_to_group("floodlights") # can be switched off in Settings > Grafik
		add_child(light)

# Curved kicker ramp: starts flush with the ground at `base` and bends up along a circular arc to
# `angle_deg` at height `height`, running along +Z (dir = 1) or -Z (dir = -1). Solid (top, sides,
# vertical back face) with matching trimesh collision, so wheels roll smoothly onto it.
func _create_kicker(base: Vector3, dir: float, width: float, angle_deg: float, height: float, mat: Material) -> void:
	var th_end: float = deg_to_rad(angle_deg)
	var run: float = height / tan(th_end * 0.5)
	var radius: float = run / sin(th_end)
	var segs: int = 24
	var prof: Array[Vector2] = [] # (distance along, height)
	for k in range(segs + 1):
		var th: float = th_end * float(k) / float(segs)
		prof.append(Vector2(radius * sin(th), radius * (1.0 - cos(th))))
	var hw: float = width * 0.5
	var faces := PackedVector3Array()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		for v in [a, b, c]:
			st.add_vertex(v)
			faces.append(v)
	var P := func(p: Vector2, x: float) -> Vector3:
		return base + Vector3(x, p.y, p.x * dir)
	for k in range(segs):
		var a0: Vector2 = prof[k]
		var a1: Vector2 = prof[k + 1]
		# top
		tri.call(P.call(a0, -hw), P.call(a1, -hw), P.call(a1, hw))
		tri.call(P.call(a0, -hw), P.call(a1, hw), P.call(a0, hw))
		# sides (down to the ground)
		for x in [-hw, hw]:
			var g0: Vector3 = base + Vector3(x, 0.0, a0.x * dir)
			var g1: Vector3 = base + Vector3(x, 0.0, a1.x * dir)
			tri.call(g0, P.call(a0, x), P.call(a1, x))
			tri.call(g0, P.call(a1, x), g1)
	# vertical back face at the lip
	var e: Vector2 = prof[segs]
	var gl: Vector3 = base + Vector3(-hw, 0.0, e.x * dir)
	var gr: Vector3 = base + Vector3(hw, 0.0, e.x * dir)
	tri.call(gl, P.call(e, -hw), P.call(e, hw))
	tri.call(gl, P.call(e, hw), gr)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m2: Material = mat
	if mat is StandardMaterial3D:
		m2 = (mat as StandardMaterial3D).duplicate()
		(m2 as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m2
	add_child(mi)
	_add_collision_body(faces, _surface_for(mat))
