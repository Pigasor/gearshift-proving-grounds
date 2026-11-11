class_name MapBuilder
extends Node3D

func _ready() -> void:
	_load_textured_materials()
	_build_floor_and_perimeter()
	_build_mega_highway()
	_build_nascar_oval()
	AirportBuilder.new().build(self) # runway, taxiways, apron, terminal, tower, hangars, planes
	_build_grand_prix_circuit()
	_build_drift_arena()
	_build_stunt_superpark()
	_build_offroad_dunes()
	_build_suspension_zone()
	_build_hill_park()
	_build_mountain()
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
	var base_y: float = 0.035

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
		sh_in.append(Vector3(shi.x, 0.02, shi.y))
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
	var y: float = 0.04 # track surface just above the grass (was 0.08: the edge lines looked raised)
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
				kl_in.append(left[k] + Vector3(0, 0.01, 0))
				kl_out.append(left[k] + across * 1.6 + Vector3(0, 0.01, 0))
				kr_in.append(right[k] + Vector3(0, 0.01, 0))
				kr_out.append(right[k] - across * 1.6 + Vector3(0, 0.01, 0))
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

# --- NASCAR OVAL (south-east, inside the highway ring) ---
# A 1-mile (~1.6 km) oval like Dover: 360 m straights, 140 m radius turns banked 24 deg, straights
# banked 8 deg, flat apron inside, concrete wall and an earth bank outside. Raced anti-clockwise
# (left turns): on the south straight the cars head +X.
const OVAL_CENTER := Vector2(620, 930)
const OVAL_STRAIGHT: float = 360.0
const OVAL_RADIUS: float = 140.0
const OVAL_WIDTH: float = 18.0

func _build_nascar_oval() -> void:
	var base_y: float = 0.04
	var turn_bank: float = deg_to_rad(14.0) # outer edge ~4.5 m up (24 deg towered 8 m over the apron)
	var straight_bank: float = deg_to_rad(4.0)
	var ce := OVAL_CENTER + Vector2(OVAL_STRAIGHT * 0.5, 0.0) # east turn centre
	var cw := OVAL_CENTER - Vector2(OVAL_STRAIGHT * 0.5, 0.0) # west turn centre
	# centre-line samples: [position xz, outward normal xz, bank]
	var samples: Array = []
	for half in [[ce, -90.0, 90.0, Vector2(0, 1)], [cw, 90.0, 270.0, Vector2(0, -1)]]:
		var c: Vector2 = half[0]
		var steps: int = 120
		for s in range(steps + 1):
			var t: float = float(s) / float(steps)
			var a: float = deg_to_rad(lerpf(half[1], half[2], t))
			var n := Vector2(cos(a), sin(a))
			# bank rolls in over the first and last 20% of the turn (no sudden twist)
			var k: float = smoothstep(0.0, 0.2, t) * smoothstep(1.0, 0.8, t)
			samples.append([c + n * OVAL_RADIUS, n, lerpf(straight_bank, turn_bank, k)])
		# straight to the other turn
		var sn: Vector2 = half[3]
		var p0: Vector2 = c + sn * OVAL_RADIUS
		var p1: Vector2 = (cw if c == ce else ce) + sn * OVAL_RADIUS
		for s in range(1, 24):
			samples.append([p0.lerp(p1, float(s) / 24.0), sn, straight_bank])
	samples.append(samples[0])

	var road_in: Array[Vector3] = []
	var road_out: Array[Vector3] = []
	var apron_in: Array[Vector3] = []
	var wall_top: Array[Vector3] = []
	var bank_out: Array[Vector3] = []
	var line_a: Array[Vector3] = []
	var line_b: Array[Vector3] = []
	var dist: Array[float] = []
	var acc: float = 0.0
	for i in range(samples.size()):
		var p: Vector2 = samples[i][0]
		var n: Vector2 = samples[i][1]
		if i > 0:
			acc += p.distance_to(samples[i - 1][0])
		dist.append(acc)
		var pin: Vector2 = p - n * OVAL_WIDTH * 0.5
		var pout: Vector2 = p + n * OVAL_WIDTH * 0.5
		var out_y: float = base_y + OVAL_WIDTH * tan(samples[i][2])
		var vin := Vector3(pin.x, base_y, pin.y)
		var vout := Vector3(pout.x, out_y, pout.y)
		road_in.append(vin)
		road_out.append(vout)
		var ap: Vector2 = pin - n * 9.0
		apron_in.append(Vector3(ap.x, base_y, ap.y))
		wall_top.append(vout + Vector3.UP * 1.2)
		var bo: Vector2 = pout + n * (4.0 + out_y * 1.6) # earth bank behind the raised outer wall
		bank_out.append(Vector3(bo.x, -0.05, bo.y))
		# white line along the inside edge of the racing surface
		line_a.append(vin.lerp(vout, 0.03) + Vector3.UP * 0.008)
		line_b.append(vin.lerp(vout, 0.05) + Vector3.UP * 0.008)

	# plain racing asphalt (the highway texture has lane lines), the apron a different shade
	var mat_oval: StandardMaterial3D = mat_track.duplicate() as StandardMaterial3D
	mat_oval.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_bank: StandardMaterial3D = mat_grass.duplicate() as StandardMaterial3D
	mat_bank.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_wall: StandardMaterial3D = mat_concrete_wall.duplicate() as StandardMaterial3D
	mat_wall.cull_mode = BaseMaterial3D.CULL_DISABLED

	var road_faces := PackedVector3Array()
	_add_strip(road_in, road_out, dist, 0.0, 1.0, 1.0 / 18.0, mat_oval, road_faces, 8)
	_add_strip(apron_in, road_in, dist, 0.0, 0.5, 1.0 / 18.0, mat_asphalt, road_faces)
	_add_collision_body(road_faces, "asphalt")
	var wall_faces := PackedVector3Array()
	_add_strip(road_out, wall_top, dist, 0.0, 1.0, 1.0 / 6.0, mat_wall, wall_faces)
	_add_collision_body(wall_faces, "concrete")
	var bank_faces := PackedVector3Array()
	_add_strip(wall_top, bank_out, dist, 0.0, 0.5, 1.0 / 12.0, mat_bank, bank_faces)
	_add_collision_body(bank_faces, "grass")
	var unused := PackedVector3Array()
	_add_strip(line_a, line_b, dist, 0.0, 1.0, 0.1, mat_road_white, unused)

	# start / finish line across the south straight
	var sx: float = OVAL_CENTER.x
	var zin: float = OVAL_CENTER.y + OVAL_RADIUS - OVAL_WIDTH * 0.5
	var zout: float = OVAL_CENTER.y + OVAL_RADIUS + OVAL_WIDTH * 0.5
	var y_out: float = base_y + OVAL_WIDTH * tan(straight_bank)
	var sl: Array[Vector3] = [Vector3(sx - 0.6, base_y + 0.02, zin), Vector3(sx + 0.6, base_y + 0.02, zin)]
	var sr: Array[Vector3] = [Vector3(sx - 0.6, y_out + 0.02, zout), Vector3(sx + 0.6, y_out + 0.02, zout)]
	_add_strip(sl, sr, [0.0, 1.2] as Array[float], 0.0, 1.0, 1.0, mat_road_white, unused)
	_build_oval_stands()

# Grandstands along both straights of the oval, packed with fans (one MultiMesh for bodies and one
# for heads: thousands of people for the cost of two draw calls)
func _build_oval_stands() -> void:
	var rows: int = 10
	var depth: float = 2.6
	var rise: float = 1.4
	var length: float = 300.0
	var seat: float = 0.9
	var x0: float = OVAL_CENTER.x - length * 0.5
	var bodies: Array[Transform3D] = []
	var body_cols: Array[Color] = []
	var heads: Array[Transform3D] = []
	var head_cols: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var shirts: Array = [Color(0.85, 0.1, 0.1), Color(0.1, 0.3, 0.85), Color(0.95, 0.8, 0.1), Color(0.95, 0.95, 0.95),
		Color(0.1, 0.1, 0.12), Color(0.1, 0.6, 0.25), Color(0.95, 0.45, 0.05), Color(0.55, 0.2, 0.7)]
	var skins: Array = [Color(0.96, 0.8, 0.66), Color(0.85, 0.64, 0.48), Color(0.6, 0.42, 0.3), Color(0.38, 0.26, 0.18)]
	# south stand (cars pass on the start / finish straight) faces -Z, north stand faces +Z
	for side in [[OVAL_CENTER.y + OVAL_RADIUS + OVAL_WIDTH * 0.5 + 13.0, 1.0], [OVAL_CENTER.y - OVAL_RADIUS - OVAL_WIDTH * 0.5 - 13.0, -1.0]]:
		var zf: float = side[0]
		var s: float = side[1]
		for k in range(rows):
			var top: float = 1.5 + k * rise
			var zc: float = zf + s * (k + 0.5) * depth
			_create_static_box(Vector3(OVAL_CENTER.x, top * 0.5, zc), Vector3(length, top, depth), mat_concrete_wall)
			var n: int = int(length / seat)
			for j in range(n):
				if rng.randf() < 0.18:
					continue # an empty seat
				var x: float = x0 + (j + 0.5) * seat + rng.randf_range(-0.1, 0.1)
				var z: float = zc - s * 0.3
				var face := Basis(Vector3.UP, 0.0 if s < 0.0 else PI) # look at the track
				bodies.append(Transform3D(face.scaled(Vector3(0.5, 0.75, 0.32)), Vector3(x, top + 0.4, z)))
				body_cols.append(shirts[rng.randi() % shirts.size()])
				heads.append(Transform3D(face.scaled(Vector3(0.24, 0.26, 0.24)), Vector3(x, top + 0.92, z)))
				head_cols.append(skins[rng.randi() % skins.size()])
		# roof over the upper rows and a big sign on the main stand
		var roof_y: float = 1.5 + rows * rise + 4.0
		_create_static_box(Vector3(OVAL_CENTER.x, roof_y, zf + s * rows * depth * 0.6), Vector3(length + 4.0, 0.4, rows * depth * 0.75), mat_metal_blue)
		for px in range(-3, 4):
			_create_static_box(Vector3(OVAL_CENTER.x + px * 49.0, roof_y * 0.5, zf + s * (rows * depth + 0.3)), Vector3(0.6, roof_y, 0.6), mat_concrete_wall)
		if s > 0.0:
			var sign := Label3D.new()
			sign.text = "GEARSHIFT SPEEDWAY"
			sign.font_size = 260
			sign.pixel_size = 0.05
			sign.modulate = Color(1.0, 0.85, 0.1)
			sign.outline_size = 30
			sign.position = Vector3(OVAL_CENTER.x, roof_y + 4.5, zf + s * rows * depth * 0.6 - 4.0)
			sign.rotation_degrees = Vector3(0, 180, 0) # faces the track (-Z)
			add_child(sign)
	_add_crowd(bodies, body_cols)
	_add_crowd(heads, head_cols)

func _add_crowd(xforms: Array[Transform3D], cols: Array[Color]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	box.material = mat
	mm.mesh = box
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

# --- MOUNTAIN (north-west, between the hill park and the highway ring) ---
# A 110 m mountain. A two-lane road winds round it to the summit (a logarithmic spiral: its radius
# shrinks as it climbs, so the grade stays ~9% all the way instead of getting steeper near the
# top), with a crash barrier on the drop side. Straight up the west face runs a steep dirt trail
# (~24 deg) for the monster truck and the buggy, littered with rocks, bushes and fallen trees.
const MTN_CENTER := Vector2(-800, -880)
const MTN_H: float = 110.0
const MTN_R0: float = 290.0 # foot of the mountain (and where the road starts)
const MTN_R1: float = 60.0 # summit plateau
const MTN_TURN: float = 8.6 # radians the road winds round (~1.4 turns)
const MTN_ROAD_W: float = 9.0
const MTN_TRAIL_ANGLE: float = PI # the steep trail climbs the west face

var _mtn_noise: FastNoiseLite

# Road radius at spiral angle th (0 at the foot, MTN_TURN at the top), with a gentle wiggle
func _mtn_road_r(th: float) -> float:
	var a: float = MTN_TURN / log(MTN_R0 / MTN_R1)
	var fade: float = sin(clampf(th / MTN_TURN, 0.0, 1.0) * PI)
	return MTN_R0 * exp(-th / a) + 6.0 * sin(th * 2.3) * fade

# Height profile of the mountain at radius r: a straight 25 deg cone with a rounded foot (no kink
# where the meadow meets the slope). The road (a log spiral) lies on it at a steady ~9% grade.
func _mtn_cone(r: float) -> float:
	var u: float = clampf((MTN_R0 - r) / (MTN_R0 - MTN_R1), 0.0, 1.0)
	return MTN_H * (u * u / 0.2 if u < 0.1 else u - 0.05)

# Road height at spiral angle th: the cone height under the un-wiggled spiral (always climbing)
func _mtn_road_h(th: float) -> float:
	var a: float = MTN_TURN / log(MTN_R0 / MTN_R1)
	return _mtn_cone(MTN_R0 * exp(-th / a))

# Natural ground height (cone + rough noise) at distance r from the centre
func _mtn_natural(x: float, z: float, r: float) -> float:
	var u: float = clampf((MTN_R0 - r) / (MTN_R0 - MTN_R1), 0.0, 1.0)
	var rough: float = sin(u * PI) # no bumps at the foot or on the summit plateau
	# the steep trail is rough but drivable: much smaller bumps along it
	var phi: float = atan2(z - MTN_CENTER.y, x - MTN_CENTER.x)
	var off_trail: float = absf(angle_difference(phi, MTN_TRAIL_ANGLE)) * r
	rough *= lerpf(0.25, 1.0, clampf((off_trail - 6.0) / 20.0, 0.0, 1.0))
	return _mtn_cone(r) + _mtn_noise.get_noise_2d(x, z) * 3.0 * rough

# Height of the mountain at (x, z): natural slope, cut flat where the road passes
# (returns [height, distance to the road centre line, road height there])
func _mtn_height(x: float, z: float) -> Array:
	var d := Vector2(x, z) - MTN_CENTER
	var r: float = d.length()
	var nat: float = _mtn_natural(x, z, r)
	var phi: float = fposmod(atan2(d.y, d.x), TAU)
	var best: float = 1e9
	var road_h: float = 0.0
	for k in range(3):
		var th: float = phi + TAU * k
		if th > MTN_TURN:
			break
		var dist: float = absf(r - _mtn_road_r(th))
		if dist < best:
			best = dist
			road_h = _mtn_road_h(th)
	var h: float = nat
	var inner: float = MTN_ROAD_W * 0.5 + 1.5
	if best < inner:
		h = road_h - 0.1
	elif best < inner + 12.0:
		h = lerpf(road_h - 0.1, nat, smoothstep(0.0, 1.0, (best - inner) / 12.0))
	return [h, best, road_h]

func _build_mountain() -> void:
	_mtn_noise = FastNoiseLite.new()
	_mtn_noise.seed = 77
	_mtn_noise.frequency = 0.02
	_mtn_noise.fractal_octaves = 3
	# 1) terrain grid (only cells on the mountain; the meadow around it is the ground itself)
	var n: int = 168
	var ext: float = MTN_R0 + 15.0
	var step: float = ext * 2.0 / n
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for j in range(n + 1):
		for i in range(n + 1):
			var x: float = MTN_CENTER.x - ext + i * step
			var z: float = MTN_CENTER.y - ext + j * step
			var r: float = Vector2(x, z).distance_to(MTN_CENTER)
			hs[j * (n + 1) + i] = (_mtn_height(x, z)[0] as float) if r < MTN_R0 + 4.0 else -0.4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for j in range(n):
		for i in range(n):
			var cx: float = MTN_CENTER.x - ext + (i + 0.5) * step
			var cz: float = MTN_CENTER.y - ext + (j + 0.5) * step
			if Vector2(cx, cz).distance_to(MTN_CENTER) > MTN_R0 + 6.0:
				continue
			var p00 := Vector3(MTN_CENTER.x - ext + i * step, hs[j * (n + 1) + i], MTN_CENTER.y - ext + j * step)
			var p10 := Vector3(p00.x + step, hs[j * (n + 1) + i + 1], p00.z)
			var p01 := Vector3(p00.x, hs[(j + 1) * (n + 1) + i], p00.z + step)
			var p11 := Vector3(p00.x + step, hs[(j + 1) * (n + 1) + i + 1], p00.z + step)
			for tri in [[p00, p10, p01], [p10, p11, p01]]:
				var nrm: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
				for v in tri:
					st.set_normal(nrm)
					st.set_uv(Vector2(v.x, v.z) / 8.0)
					st.add_vertex(v)
					faces.append(v)
	var mat_mtn: StandardMaterial3D = mat_grass.duplicate() as StandardMaterial3D
	mat_mtn.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh_i := MeshInstance3D.new()
	mesh_i.mesh = st.commit()
	mesh_i.material_override = mat_mtn
	add_child(mesh_i)
	_add_collision_body(faces, "grass")

	# 2) the winding road + crash barrier on the outer (drop) side
	var road_in: Array[Vector3] = []
	var road_out: Array[Vector3] = []
	var rail_top: Array[Vector3] = []
	var dist: Array[float] = []
	var acc: float = 0.0
	var samples: int = 900
	for s in range(samples + 1):
		var th: float = MTN_TURN * float(s) / samples
		var r: float = _mtn_road_r(th)
		var dir := Vector2(cos(th), sin(th))
		var c: Vector2 = MTN_CENTER + dir * r
		var y: float = _mtn_road_h(th)
		var pin: Vector2 = c - dir * MTN_ROAD_W * 0.5
		var pout: Vector2 = c + dir * MTN_ROAD_W * 0.5
		if s > 0:
			acc += Vector2(road_in[-1].x, road_in[-1].z).distance_to(pin)
		dist.append(acc)
		road_in.append(Vector3(pin.x, y, pin.y))
		road_out.append(Vector3(pout.x, y, pout.y))
		rail_top.append(Vector3(pout.x, y + 0.8, pout.y))
	var mat_mroad: StandardMaterial3D = mat_road_asphalt.duplicate() as StandardMaterial3D
	mat_mroad.uv1_scale = Vector3(1, 1, 1)
	mat_mroad.cull_mode = BaseMaterial3D.CULL_DISABLED
	var road_faces := PackedVector3Array()
	_add_strip(road_in, road_out, dist, 0.0, 1.0, 1.0 / 96.0, mat_mroad, road_faces, 2)
	_add_collision_body(road_faces, "asphalt")
	var mat_rail: StandardMaterial3D = mat_concrete_wall.duplicate() as StandardMaterial3D
	mat_rail.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rail_faces := PackedVector3Array()
	# the barrier stops where the steep trail crosses the road, so trail drivers can get through
	var seg_in: Array[Vector3] = []
	var seg_top: Array[Vector3] = []
	var seg_d: Array[float] = []
	for s in range(samples + 1):
		var th: float = MTN_TURN * float(s) / samples
		var gap: bool = absf(angle_difference(th, MTN_TRAIL_ANGLE)) * _mtn_road_r(th) < 6.0
		if not gap:
			seg_in.append(road_out[s]); seg_top.append(rail_top[s]); seg_d.append(dist[s])
		if (gap or s == samples) and seg_in.size() > 1:
			_add_strip(seg_in, seg_top, seg_d, 0.0, 1.0, 1.0 / 4.0, mat_rail, rail_faces)
			seg_in = []; seg_top = []; seg_d = []
		elif gap:
			seg_in = []; seg_top = []; seg_d = []
	_add_collision_body(rail_faces, "concrete")

	# 3) the steep trail: a dirt strip straight up the west face, then its obstacles
	var t_in: Array[Vector3] = []
	var t_out: Array[Vector3] = []
	var t_d: Array[float] = []
	var tdir := Vector2(cos(MTN_TRAIL_ANGLE), sin(MTN_TRAIL_ANGLE))
	var tside := Vector2(-tdir.y, tdir.x)
	var r_t: float = MTN_R0 + 12.0
	while r_t > MTN_R1 - 10.0:
		var c: Vector2 = MTN_CENTER + tdir * r_t
		var a: Vector2 = c - tside * 3.2
		var b: Vector2 = c + tside * 3.2
		t_in.append(Vector3(a.x, (_mtn_height(a.x, a.y)[0] as float) + 0.06, a.y))
		t_out.append(Vector3(b.x, (_mtn_height(b.x, b.y)[0] as float) + 0.06, b.y))
		t_d.append(MTN_R0 + 12.0 - r_t)
		r_t -= 2.0
	var trail_faces := PackedVector3Array()
	_add_strip(t_in, t_out, t_d, 0.0, 1.0, 1.0 / 6.0, mat_dirt_dunes, trail_faces, 3)
	_add_collision_body(trail_faces, "dirt")
	_mtn_obstacles(tdir, tside)

	# 4) summit: flag and sign
	var top := Vector3(MTN_CENTER.x, MTN_H, MTN_CENTER.y)
	_create_static_box(top + Vector3(0, 5.0, 0), Vector3(0.25, 10.0, 0.25), mat_concrete_wall)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.05, 1.6, 2.6)
	flag.mesh = fm
	flag.material_override = mat_ramp_orange
	flag.position = top + Vector3(0, 9.0, 1.3)
	add_child(flag)
	var sign := Label3D.new()
	sign.text = "ZİRVE  ·  110 m"
	sign.font_size = 160
	sign.pixel_size = 0.03
	sign.outline_size = 24
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = top + Vector3(0, 12.5, 0)
	add_child(sign)

# Rocks, fallen trees and bushes on the steep trail; trees and bushes on the slopes
func _mtn_obstacles(tdir: Vector2, tside: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.4, 0.37)
	rock_mat.roughness = 1.0
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.33, 0.22, 0.13)
	bark.roughness = 1.0
	var road_cross: float = _mtn_road_r(MTN_TRAIL_ANGLE) # where the trail crosses the road: keep clear
	# rocks (solid, half buried, random tilt)
	for k in range(46):
		var r: float = rng.randf_range(MTN_R1 + 5.0, MTN_R0 - 4.0)
		if absf(r - road_cross) < 11.0:
			continue
		var off: float = rng.randf_range(-3.4, 3.4)
		var p2: Vector2 = MTN_CENTER + tdir * r + tside * off
		var y: float = _mtn_height(p2.x, p2.y)[0]
		# in the wheel tracks: low, half-buried slabs you bump over; big boulders only along the edges
		var mid: bool = absf(off) < 2.6
		var sz := Vector3(rng.randf_range(0.5, 1.3), rng.randf_range(0.3, 0.5) if mid else rng.randf_range(0.5, 1.0), rng.randf_range(0.5, 1.2))
		var tilt: float = 8.0 if mid else 20.0
		_create_static_box(Vector3(p2.x, y + sz.y * (0.0 if mid else 0.3), p2.y), sz, rock_mat, Vector3(rng.randf_range(-tilt, tilt), rng.randf_range(0, 360), rng.randf_range(-tilt, tilt)))
	# fallen trees lying across the trail
	for r in [95.0, 128.0, 205.0, 232.0, 262.0]:
		var p2: Vector2 = MTN_CENTER + tdir * r + tside * rng.randf_range(-1.0, 1.0)
		var y: float = _mtn_height(p2.x, p2.y)[0]
		var rad: float = rng.randf_range(0.22, 0.32)
		var body := StaticBody3D.new()
		body.set_meta("surface", "dirt")
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = rad
		cyl.height = 8.0
		cs.shape = cyl
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rad * 0.8
		cm.bottom_radius = rad
		cm.height = 8.0
		mi.mesh = cm
		mi.material_override = bark
		body.add_child(mi)
		# lying flat across the trail (the cone is level in that direction), a little skewed
		var along := Vector3(tside.x, 0, tside.y).rotated(Vector3.UP, rng.randf_range(-0.3, 0.3))
		body.transform = Transform3D(Basis(Vector3.UP.cross(along).normalized(), along, Vector3.UP.cross(along).normalized().cross(along)).orthonormalized(), Vector3(p2.x, y + rad * 0.1, p2.y)) # half sunk in the earth: a hard bump, not a wall
		add_child(body)
	# bushes (visual) on the trail and slopes, trees (solid trunks) on the slopes
	var bush_x: Array[Transform3D] = []
	var bush_c: Array[Color] = []
	for k in range(420):
		var on_trail: bool = k < 70
		var r: float = rng.randf_range(MTN_R1, MTN_R0 - 3.0)
		var phi: float = MTN_TRAIL_ANGLE + (rng.randf_range(-4.0, 4.0) / r if on_trail else rng.randf_range(0.0, TAU))
		var p2: Vector2 = MTN_CENTER + Vector2(cos(phi), sin(phi)) * r
		var hinfo: Array = _mtn_height(p2.x, p2.y)
		if (hinfo[1] as float) < MTN_ROAD_W * 0.5 + 1.0:
			continue
		var s: float = rng.randf_range(0.6, 1.6)
		bush_x.append(Transform3D(Basis().scaled(Vector3(s * 1.3, s, s * 1.2)), Vector3(p2.x, (hinfo[0] as float) + s * 0.35, p2.y)))
		bush_c.append(Color(rng.randf_range(0.12, 0.3), rng.randf_range(0.32, 0.5), rng.randf_range(0.08, 0.16)))
	_mtn_multimesh(SphereMesh.new(), bush_x, bush_c)
	var trunk_x: Array[Transform3D] = []
	var crown_x: Array[Transform3D] = []
	var crown_c: Array[Color] = []
	for k in range(170):
		var r: float = rng.randf_range(MTN_R1 + 15.0, MTN_R0 - 8.0)
		var phi: float = rng.randf_range(0.0, TAU)
		if absf(angle_difference(phi, MTN_TRAIL_ANGLE)) * r < 14.0:
			continue
		var p2: Vector2 = MTN_CENTER + Vector2(cos(phi), sin(phi)) * r
		var hinfo: Array = _mtn_height(p2.x, p2.y)
		if (hinfo[1] as float) < MTN_ROAD_W * 0.5 + 6.0:
			continue
		var y: float = hinfo[0]
		var hgt: float = rng.randf_range(6.0, 10.0)
		trunk_x.append(Transform3D(Basis().scaled(Vector3(0.35, hgt * 0.45, 0.35)), Vector3(p2.x, y + hgt * 0.225, p2.y)))
		crown_x.append(Transform3D(Basis().scaled(Vector3(hgt * 0.35, hgt * 0.7, hgt * 0.35)), Vector3(p2.x, y + hgt * 0.45 + hgt * 0.35, p2.y)))
		crown_c.append(Color(0.1, rng.randf_range(0.3, 0.42), 0.12))
		_create_static_box(Vector3(p2.x, y + 1.5, p2.y), Vector3(0.5, 3.0, 0.5), bark).visible = false # solid trunk
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.6
	trunk_mesh.bottom_radius = 0.8
	trunk_mesh.height = 1.0
	_mtn_multimesh(trunk_mesh, trunk_x, [] as Array[Color], bark)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.0
	crown.height = 1.0
	_mtn_multimesh(crown, crown_x, crown_c)

func _mtn_multimesh(mesh: Mesh, xforms: Array[Transform3D], cols: Array[Color], mat: Material = null) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	else:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		mmi.material_override = m
	add_child(mmi)
