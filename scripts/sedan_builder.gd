extends RefCounted
class_name SedanBuilder
# Builds a family-sedan body procedurally from real dimensions (CarDatabase "body").
# The side silhouette (bumper - hood - windscreen - roof - rear window - boot) is extruded across
# the car's width; the nose, tail and glasshouse are tapered so it reads as a real car, not a box.
# Car axes: +Z forward, +X left, origin = wheel mount height. Returns the tail-light materials.

var _parent: Node3D
var _brake_mats: Array[StandardMaterial3D] = []

# Per-model silhouette (fractions of the length) and details
const STYLES: Dictionary = {
	"accent": { "hood": 0.235, "ws": 0.165, "roof": 0.29, "rw": 0.15, "nose": 0.66, "cowl": 0.86, "belt": 0.94, "deck": 0.96, "lamp_w": 0.40, "tail": "wide" },
	"egea":   { "hood": 0.230, "ws": 0.170, "roof": 0.29, "rw": 0.15, "nose": 0.68, "cowl": 0.88, "belt": 0.97, "deck": 0.99, "lamp_w": 0.46, "tail": "wide" },
	"civic":  { "hood": 0.240, "ws": 0.175, "roof": 0.25, "rw": 0.21, "nose": 0.62, "cowl": 0.84, "belt": 0.93, "deck": 0.95, "lamp_w": 0.44, "tail": "bar" },
	"megane": { "hood": 0.235, "ws": 0.170, "roof": 0.28, "rw": 0.16, "nose": 0.66, "cowl": 0.86, "belt": 0.95, "deck": 0.97, "lamp_w": 0.42, "tail": "c_shape" },
}

func build(parent: Node3D, b: Dictionary, ground_y: float, tire_r: float) -> Array[StandardMaterial3D]:
	_parent = parent
	_brake_mats.clear()
	var st_def: Dictionary = STYLES.get(str(b.get("style", "accent")), STYLES["accent"])
	var L: float = float(b["length"])
	var W: float = float(b["width"])
	var H: float = float(b["height"])
	var wb: float = float(b["wheelbase"])
	var zf: float = wb * 0.5 + float(b["front_overhang"])
	var zr: float = zf - L
	var g: float = ground_y
	var hw: float = W * 0.5 - 0.02

	var paint := StandardMaterial3D.new()
	paint.albedo_color = b["color"]
	paint.metallic = 0.55
	paint.roughness = 0.28
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.8
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.07, 0.10)
	glass.metallic = 0.7
	glass.roughness = 0.06
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.04, 0.04, 0.045)
	black.roughness = 0.6
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.85, 0.86, 0.88)
	chrome.metallic = 0.95
	chrome.roughness = 0.12
	var head := StandardMaterial3D.new()
	head.albedo_color = Color(0.95, 0.97, 1.0)
	head.emission_enabled = true
	head.emission = Color(0.9, 0.95, 1.0)
	head.emission_energy_multiplier = 1.6
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.55, 0.02, 0.02)
	tail.emission_enabled = true
	tail.emission = Color(1.0, 0.04, 0.03)
	tail.emission_energy_multiplier = 1.2
	_brake_mats.append(tail)
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.92, 0.92, 0.9)
	plate.roughness = 0.5

	# --- Key stations along the car ---
	var cowl_z: float = zf - L * float(st_def["hood"])
	var ws_top_z: float = cowl_z - L * float(st_def["ws"])
	var roof_rear_z: float = ws_top_z - L * float(st_def["roof"])
	var deck_z: float = roof_rear_z - L * float(st_def["rw"])
	var nose_h: float = float(st_def["nose"])
	var cowl_h: float = float(st_def["cowl"])
	var belt_h: float = float(st_def["belt"])
	var deck_h: float = float(st_def["deck"])

	# --- Lower body: side profile with wheel arches cut out ---
	var arch_r: float = tire_r + 0.06
	var lower := PackedVector2Array()
	lower.append(Vector2(zf - 0.08, 0.22))
	lower.append(Vector2(zf, 0.34))
	lower.append(Vector2(zf + 0.01, 0.50))
	lower.append(Vector2(zf - 0.05, nose_h - 0.02))
	lower.append(Vector2(zf - 0.30, nose_h + 0.06))
	lower.append(Vector2(cowl_z + 0.25, cowl_h - 0.03))
	lower.append(Vector2(cowl_z, cowl_h))
	lower.append(Vector2(deck_z, belt_h))
	lower.append(Vector2(deck_z - 0.15, deck_h))
	lower.append(Vector2(zr + 0.06, deck_h - 0.01))
	lower.append(Vector2(zr, deck_h - 0.12))
	lower.append(Vector2(zr - 0.01, 0.50))
	lower.append(Vector2(zr + 0.04, 0.26))
	_append_arch(lower, -wb * 0.5, tire_r, arch_r)
	_append_arch(lower, wb * 0.5, tire_r, arch_r)
	var taper := func(z: float, y: float) -> float:
		# plan-view rounding of nose and tail, slight tumblehome above the shoulder
		var t: float = 1.0 - 0.10 * smoothstep(zf - 0.55, zf + 0.02, z) - 0.07 * smoothstep(zr + 0.45, zr - 0.02, z)
		t *= 1.0 - 0.04 * smoothstep(0.55, belt_h, y)
		return hw * t
	_extrude(lower, g, taper, paint, paint, [])

	# --- Glasshouse ---
	var gh := PackedVector2Array([
		Vector2(cowl_z - 0.02, cowl_h),
		Vector2(ws_top_z, H - 0.05),
		Vector2(ws_top_z - 0.18, H),
		Vector2(roof_rear_z + 0.15, H - 0.01),
		Vector2(roof_rear_z, H - 0.06),
		Vector2(deck_z + 0.02, belt_h),
	])
	var gh_taper := func(z: float, y: float) -> float:
		var k: float = clampf((y - cowl_h) / maxf(H - cowl_h, 0.1), 0.0, 1.0)
		return taper.call(z, belt_h) * lerpf(0.94, 0.72, k)
	# edge 0 windscreen and edge 4 rear window are glass, the rest is the painted roof
	_extrude(gh, g, gh_taper, paint, glass, [0, 4])
	# Side windows: the glasshouse side, inset to leave the pillars painted
	var win_polys: Array = Geometry2D.offset_polygon(gh, -0.06)
	for side in [-1.0, 1.0]:
		for poly in win_polys:
			_side_panel(poly, g, gh_taper, side, 0.006, glass)
		# B-pillar
		var b_z: float = lerpf(ws_top_z, roof_rear_z, 0.48)
		var b_y: float = (belt_h + H) * 0.5
		var bw: float = gh_taper.call(b_z, b_y)
		_box(Vector3(side * (bw + 0.008), g + b_y, b_z), Vector3(0.02, H - belt_h - 0.08, 0.09), black)

	# --- Details ---
	var lamp_w: float = float(st_def["lamp_w"])
	var front_w: float = taper.call(zf - 0.1, 0.6)
	for side in [-1.0, 1.0]:
		# headlights
		_box(Vector3(side * (front_w - lamp_w * 0.5 - 0.04), g + nose_h - 0.07, zf - 0.07), Vector3(lamp_w, 0.10, 0.10), head, Vector3(0, -side * 12.0, 0))
		# mirrors
		_box(Vector3(side * (hw + 0.09), g + cowl_h + 0.12, cowl_z - 0.22), Vector3(0.16, 0.10, 0.09), paint)
		# door handles
		_box(Vector3(side * (taper.call(cowl_z - 0.9, 0.8) + 0.008), g + 0.80, cowl_z - 0.95), Vector3(0.015, 0.03, 0.14), chrome)
		_box(Vector3(side * (taper.call(roof_rear_z, 0.8) + 0.008), g + 0.80, roof_rear_z + 0.1), Vector3(0.015, 0.03, 0.14), chrome)
		# side skirt
		_box(Vector3(side * (hw - 0.02), g + 0.24, 0.0), Vector3(0.04, 0.06, wb - arch_r * 2.0 - 0.05), black)
	var rear_w: float = taper.call(zr + 0.1, 0.8)
	match str(st_def["tail"]):
		"bar": # full-width light bar
			_box(Vector3(0, g + deck_h - 0.10, zr + 0.01), Vector3(rear_w * 1.9, 0.07, 0.06), tail)
		"c_shape":
			for side in [-1.0, 1.0]:
				_box(Vector3(side * (rear_w - 0.22), g + deck_h - 0.10, zr + 0.01), Vector3(0.40, 0.05, 0.06), tail)
				_box(Vector3(side * (rear_w - 0.04), g + deck_h - 0.18, zr + 0.03), Vector3(0.05, 0.20, 0.06), tail)
		_:
			for side in [-1.0, 1.0]:
				_box(Vector3(side * (rear_w - 0.24), g + deck_h - 0.12, zr + 0.01), Vector3(0.44, 0.13, 0.06), tail)
	# grille, lower intake, bumpers' black lower lips
	_box(Vector3(0, g + nose_h - 0.20, zf + 0.004), Vector3(front_w * 0.95, 0.14, 0.04), black)
	_box(Vector3(0, g + 0.30, zf - 0.02), Vector3(front_w * 1.2, 0.10, 0.06), black)
	_box(Vector3(0, g + 0.26, zr + 0.02), Vector3(rear_w * 1.8, 0.08, 0.06), black)
	# number plates (white EU size)
	_box(Vector3(0, g + 0.42, zf + 0.025), Vector3(0.52, 0.11, 0.01), plate)
	_box(Vector3(0, g + deck_h - 0.28, zr - 0.006), Vector3(0.52, 0.11, 0.01), plate)
	# underbody (so the car isn't hollow when seen from low angles)
	_box(Vector3(0, g + 0.23, (zf + zr) * 0.5), Vector3(hw * 1.9, 0.04, L - 0.3), black)
	return _brake_mats

# Wheel arch cut-out: from the rear of the arch, over the top, to the front (z grows forwards).
func _append_arch(poly: PackedVector2Array, zc: float, yc: float, r: float) -> void:
	poly.append(Vector2(zc - r, 0.22))
	for k in range(13):
		var a: float = PI - PI * float(k) / 12.0
		poly.append(Vector2(zc + cos(a) * r, yc + sin(a) * r))
	poly.append(Vector2(zc + r, 0.22))

# Extrude a side profile (z, y) across the car: both side panels + the skin between them.
# half_width(z, y) gives the panel's distance from the centre line at each profile point.
# Edges listed in glass_edges get glass_mat, all other faces side_mat.
func _extrude(poly: PackedVector2Array, g: float, half_width: Callable, side_mat: Material, glass_mat: Material, glass_edges: Array) -> void:
	var alt_edges: Array = glass_edges
	for side in [-1.0, 1.0]:
		_side_panel(poly, g, half_width, side, 0.0, side_mat)
	var st_a := SurfaceTool.new()
	st_a.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_a.set_smooth_group(0xFFFFFFFF)
	var st_b := SurfaceTool.new()
	st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_b.set_smooth_group(0xFFFFFFFF)
	var n: int = poly.size()
	for i in range(n):
		var p0: Vector2 = poly[i]
		var p1: Vector2 = poly[(i + 1) % n]
		var w0: float = half_width.call(p0.x, p0.y)
		var w1: float = half_width.call(p1.x, p1.y)
		var a := Vector3(-w0, g + p0.y, p0.x)
		var b := Vector3(w0, g + p0.y, p0.x)
		var c := Vector3(w1, g + p1.y, p1.x)
		var d := Vector3(-w1, g + p1.y, p1.x)
		var st: SurfaceTool = st_b if alt_edges.has(i) else st_a
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
	st_a.generate_normals()
	_mesh(st_a.commit(), side_mat)
	if not alt_edges.is_empty():
		st_b.generate_normals()
		_mesh(st_b.commit(), glass_mat)

func _side_panel(poly: PackedVector2Array, g: float, half_width: Callable, side: float, push: float, mat: Material) -> void:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The panel is almost flat: one outward normal keeps the paint even (no triangle facets)
	var out_n := Vector3(side, 0.0, 0.0)
	st.set_normal(out_n)
	for t in range(0, idx.size(), 3):
		var v: Array[Vector3] = []
		for k in range(3):
			var p: Vector2 = poly[idx[t + k]]
			v.append(Vector3(side * (half_width.call(p.x, p.y) + push), g + p.y, p.x))
		# Godot's front face is clockwise seen from outside: order each triangle so it faces out
		if (v[1] - v[0]).cross(v[2] - v[0]).dot(out_n) > 0.0:
			v = [v[0], v[2], v[1]]
		for vert in v:
			st.add_vertex(vert)
	_mesh(st.commit(), mat)

func _mesh(m: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	_parent.add_child(mi)

func _box(pos: Vector3, size: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	_parent.add_child(mi)
