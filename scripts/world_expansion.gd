extends RefCounted
class_name WorldExpansion
# The map's three new 3 km tiles (the original proving ground is the north-west one):
#   east       - an F1 circuit (~5 km) with pit garages and a grandstand
#   south      - a Le Mans style endurance circuit (~7.8 km): long Hunaudieres straight with two
#                chicanes, Mulsanne corner, Indianapolis / Arnage, Porsche curves, Ford chicane,
#                the bridge over the Dunlop curve
#   south-east - a 24 deg banked superspeedway (~3.7 km)
# Two-lane country roads join them to the highway ring, and the countryside around them gets
# rolling hills, woods, farm fields, a village and a wind farm. Built at load by MapBuilder.

const CELL: float = 10.0 # occupancy grid: roads, tracks, buildings, hills (keeps trees & hills off them)
const ROAD_Y: float = 0.045

const F1_START := Vector3(2470, 0, 300) # cars head +X
const F1_POINTS: Array[Vector2] = [
	Vector2(2300, 300), Vector2(2700, 300), Vector2(3150, 300), Vector2(3300, 330), Vector2(3340, 420), Vector2(3290, 500),
	Vector2(3330, 600), Vector2(3450, 640), Vector2(3600, 600), Vector2(3700, 480), Vector2(3720, 300), Vector2(3700, 50),
	Vector2(3700, -250), Vector2(3680, -450), Vector2(3610, -520), Vector2(3530, -480), Vector2(3520, -380), Vector2(3500, -250),
	Vector2(3420, -180), Vector2(3250, -200), Vector2(3000, -250), Vector2(2700, -300), Vector2(2550, -320), Vector2(2450, -280),
	Vector2(2420, -200), Vector2(2350, -150), Vector2(2250, -60), Vector2(2210, 40), Vector2(2250, 120), Vector2(2230, 200),
	Vector2(2255, 268),
]
const LM_START := Vector3(-1100, 0, 2950) # cars head -Z (north)
const LM_POINTS: Array[Vector2] = [
	Vector2(-1100, 3300), Vector2(-1100, 2900), Vector2(-1100, 2500), Vector2(-1100, 2200), Vector2(-1085, 2090), Vector2(-1040, 2010),
	Vector2(-1010, 1975), Vector2(-1030, 1930), Vector2(-1000, 1880), Vector2(-1020, 1820), Vector2(-980, 1760), Vector2(-920, 1730),
	Vector2(-850, 1720), Vector2(-560, 1797), Vector2(-289, 1869), Vector2(-241, 1881), Vector2(-194, 1894), Vector2(-147, 1917), Vector2(-93, 1910),
	Vector2(-48, 1933), Vector2(1, 1946), Vector2(49, 1958), Vector2(339, 2035), Vector2(387, 2048), Vector2(436, 2061),
	Vector2(481, 2083), Vector2(535, 2077), Vector2(581, 2099), Vector2(629, 2112), Vector2(677, 2125), Vector2(890, 2181), Vector2(1083, 2232),
	Vector2(1180, 2262), Vector2(1230, 2285), Vector2(1255, 2330), Vector2(1240, 2390), Vector2(1180, 2600), Vector2(1100, 2850),
	Vector2(1020, 3100), Vector2(960, 3300), Vector2(930, 3400), Vector2(950, 3460), Vector2(925, 3520), Vector2(880, 3560),
	Vector2(820, 3570), Vector2(600, 3580), Vector2(300, 3620), Vector2(100, 3660), Vector2(0, 3720), Vector2(-120, 3730),
	Vector2(-240, 3700), Vector2(-360, 3740), Vector2(-480, 3800), Vector2(-600, 3800), Vector2(-700, 3770), Vector2(-800, 3760),
	Vector2(-870, 3742), Vector2(-930, 3762), Vector2(-1000, 3735), Vector2(-1060, 3690), Vector2(-1090, 3600), Vector2(-1100, 3480),
]
const SS_CENTER := Vector2(3000, 3000)
const SS_STRAIGHT: float = 1000.0
const SS_RADIUS: float = 320.0
const SS_WIDTH: float = 24.0

# Country roads (control points; they start just inside the ring's outer edge / end at a paddock)
const ROADS: Array = [
	[Vector2(1309, 500), Vector2(1600, 520), Vector2(1950, 480), Vector2(2250, 430), Vector2(2345, 400)], # ring -> F1 paddock
	[Vector2(2600, 412), Vector2(2560, 900), Vector2(2400, 1500), Vector2(2150, 2200), Vector2(1900, 2700), Vector2(1850, 2905)], # F1 -> oval car park
	[Vector2(MapBuilder.RING_EXIT_X, 1309), Vector2(1000, 1480), Vector2(1380, 1650), Vector2(1450, 2000), Vector2(1480, 2500), Vector2(1600, 2850), Vector2(1755, 2980)], # ring -> village -> oval
	[Vector2(-1309, 800), Vector2(-1380, 880), Vector2(-1410, 1100), Vector2(-1400, 1600), Vector2(-1360, 2200), Vector2(-1280, 2650), Vector2(-1250, 2905)], # ring -> Le Mans paddock
]

var mb: MapBuilder
var _occ: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _road_pts: Array = [] # dense centre lines of the roads (village / props placement)
var _mat_line: StandardMaterial3D
var _mat_shoulder: StandardMaterial3D

func build(map: MapBuilder) -> void:
	mb = map
	_rng.seed = 4242
	_mat_line = mb.mat_road_white.duplicate() as StandardMaterial3D
	_mat_line.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_shoulder = mb.mat_dirt_dunes.duplicate() as StandardMaterial3D
	_mat_shoulder.cull_mode = BaseMaterial3D.CULL_DISABLED
	_f1()
	_lemans()
	_superspeedway()
	for r in ROADS:
		_road_pts.append(_road(r, 10.0))
	_village()
	_wind_farm()
	_hills()
	_fields()
	_forest()

# ------------------------------------------------------------------ occupancy grid
func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

func _mark(p: Vector2, r: float) -> void:
	var c0: Vector2i = _cell(p - Vector2(r, r))
	var c1: Vector2i = _cell(p + Vector2(r, r))
	for i in range(c0.x, c1.x + 1):
		for j in range(c0.y, c1.y + 1):
			if Vector2((i + 0.5) * CELL, (j + 0.5) * CELL).distance_to(p) <= r + CELL * 0.71:
				_occ[Vector2i(i, j)] = true

func _mark_line(pts: Array, r: float) -> void:
	for p in pts:
		_mark(p, r)

func _mark_rect(c: Vector2, half: Vector2) -> void:
	var c0: Vector2i = _cell(c - half)
	var c1: Vector2i = _cell(c + half)
	for i in range(c0.x, c1.x + 1):
		for j in range(c0.y, c1.y + 1):
			_occ[Vector2i(i, j)] = true

# Free for scenery: inside the new tiles (not the original proving ground), away from the walls
# and nothing built there
func _free(p: Vector2, r: float = 0.0) -> bool:
	if p.x < 1500.0 + 40.0 and p.y < 1500.0 + 40.0:
		return false
	if p.x < MapBuilder.WORLD_MIN.x + 60.0 + r or p.x > MapBuilder.WORLD_MAX.x - 60.0 - r or p.y < MapBuilder.WORLD_MIN.y + 60.0 + r or p.y > MapBuilder.WORLD_MAX.y - 60.0 - r:
		return false
	if r <= 0.0:
		return not _occ.has(_cell(p))
	var c0: Vector2i = _cell(p - Vector2(r, r))
	var c1: Vector2i = _cell(p + Vector2(r, r))
	for i in range(c0.x, c1.x + 1):
		for j in range(c0.y, c1.y + 1):
			if _occ.has(Vector2i(i, j)) and Vector2((i + 0.5) * CELL, (j + 0.5) * CELL).distance_to(p) <= r:
				return false
	return true

# ------------------------------------------------------------------ circuits
func _f1() -> void:
	var pts: Array[Vector2] = mb.build_circuit(F1_POINTS, F1_START, 15.0, "F1 PİSTİ", "laps_f1", 12)
	_mark_line(pts, 40.0)
	# pit garages south of the start / finish straight behind a pit wall, paddock tarmac, grandstand opposite
	mb._create_static_box(Vector3(2600, 0.025, 365), Vector3(520, 0.05, 110), mb.mat_asphalt)
	mb._create_static_box(Vector3(2660, 0.6, 310.5), Vector3(320, 1.2, 0.6), mb.mat_concrete_wall)
	_garages(Vector3(2660, 0, 330), Vector3(1, 0, 0), Vector3(0, 0, -1), 300.0, "GEARSHIFT GRAND PRIX")
	_stand(Vector3(2650, 0, 280.5), Vector3(-0.0, 0, -1), 500.0, 12, "F1")
	_mark_rect(Vector2(2600, 340), Vector2(270, 90))
	_mark_rect(Vector2(2650, 265), Vector2(260, 30))

func _lemans() -> void:
	var pts: Array[Vector2] = mb.build_circuit(LM_POINTS, LM_START, 14.0, "LE MANS PİSTİ", "laps_lemans", 14)
	_mark_line(pts, 40.0)
	# pits west of the main straight, grandstand east of it
	mb._create_static_box(Vector3(-1206, 0.025, 3200), Vector3(188, 0.05, 600), mb.mat_asphalt)
	mb._create_static_box(Vector3(-1110, 0.6, 3210), Vector3(0.6, 1.2, 420), mb.mat_concrete_wall)
	_garages(Vector3(-1126, 0, 3210), Vector3(0, 0, 1), Vector3(1, 0, 0), 400.0, "24 HEURES GEARSHIFT")
	_stand(Vector3(-1081, 0, 3200), Vector3(1, 0, 0), 500.0, 12, "LE MANS")
	_mark_rect(Vector2(-1206, 3200), Vector2(100, 310))
	_mark_rect(Vector2(-1066, 3200), Vector2(25, 260))
	# the bridge over the Dunlop curve
	var bi: int = 0
	for i in range(pts.size()):
		if pts[i].distance_to(Vector2(-1062, 2048)) < pts[bi].distance_to(Vector2(-1062, 2048)):
			bi = i
	var t: Vector2 = (pts[mini(bi + 1, pts.size() - 1)] - pts[maxi(bi - 1, 0)]).normalized()
	var yaw: float = rad_to_deg(atan2(t.x, t.y))
	var rot := Basis(Vector3.UP, deg_to_rad(yaw))
	var c := Vector3(pts[bi].x, 0, pts[bi].y)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.1)
	for sd in [-1.0, 1.0]:
		mb._create_static_box(c + rot * Vector3(sd * 13.0, 4.0, 0), Vector3(2.0, 8.0, 4.0), mb.mat_concrete_wall, Vector3(0, yaw, 0))
	mb._create_static_box(c + rot * Vector3(0, 8.6, 0), Vector3(30.0, 1.2, 4.0), mb.mat_concrete_wall, Vector3(0, yaw, 0))
	mb._create_static_box(c + rot * Vector3(0, 9.9, 0), Vector3(30.0, 1.4, 3.0), red, Vector3(0, yaw, 0))
	for face in [-1.0, 1.0]:
		var sign := Label3D.new()
		sign.text = "GEARSHIFT"
		sign.font_size = 160
		sign.pixel_size = 0.02
		sign.modulate = Color(1, 0.92, 0.2)
		sign.outline_size = 16
		sign.transform = Transform3D(rot * Basis(Vector3.UP, 0.0 if face > 0.0 else PI), c + rot * Vector3(0, 9.9, face * 1.55))
		mb.add_child(sign)

func _superspeedway() -> void:
	mb.build_oval(SS_CENTER, SS_STRAIGHT, SS_RADIUS, SS_WIDTH, 24.0, 5.0, "GEARSHIFT SUPERSPEEDWAY", 600.0, 14)
	_mark_rect(SS_CENTER, Vector2(SS_STRAIGHT * 0.5 + SS_RADIUS + 70.0, SS_RADIUS + 110.0))
	# car park west of the track (the roads from the F1 circuit and from the ring end here)
	mb._create_static_box(Vector3(1850, 0.025, 2980), Vector3(200, 0.05, 160), mb.mat_asphalt)
	for k in range(9):
		mb._create_marking(Vector3(1770 + k * 20.0, 0.055, 2980), Vector3(0.2, 0.01, 60.0), mb.mat_road_white)
	_mark_rect(Vector2(1850, 2980), Vector2(110, 90))

# Pit garages: a long two-storey block, roller doors facing the track, glass on the top floor
func _garages(c: Vector3, along: Vector3, to_track: Vector3, length: float, title: String) -> void:
	var yaw: float = rad_to_deg(atan2(along.x, along.z)) + 90.0 # local X along the building
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.93, 0.95)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.09, 0.11)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.25, 0.4, 0.55)
	glass.metallic = 0.6
	glass.roughness = 0.1
	mb._create_static_box(c + Vector3(0, 4.0, 0), Vector3(length, 8.0, 18.0), white, Vector3(0, yaw, 0))
	var n: int = int(length / 15.0)
	for k in range(n):
		var off: float = -length * 0.5 + (k + 0.5) * length / n
		_vis_box(c + along * off + to_track * 9.05 + Vector3(0, 2.6, 0), Vector3(10.0, 5.0, 0.12), dark, yaw)
	_vis_box(c + to_track * 9.05 + Vector3(0, 6.6, 0), Vector3(length - 4.0, 1.8, 0.12), glass, yaw)
	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 220
	sign.pixel_size = 0.04
	sign.modulate = Color(1.0, 0.85, 0.1)
	sign.outline_size = 24
	var face_yaw: float = atan2(to_track.x, to_track.z)
	sign.transform = Transform3D(Basis(Vector3.UP, face_yaw), c + Vector3(0, 10.5, 0) + to_track * 6.0)
	mb.add_child(sign)

# Visual-only box rotated about Y (doors, windows, trim)
func _vis_box(pos: Vector3, size: Vector3, mat: Material, yaw_deg: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	mb.add_child(mi)
	return mi

# Grandstand: `front` = middle of the front row (the side by the track), rows step up going `away`
# (an axis direction), packed with fans (two MultiMeshes), roof and a sign
func _stand(front: Vector3, away: Vector3, length: float, rows: int, sign_text: String) -> void:
	var along_x: bool = absf(away.z) > 0.5
	var depth: float = 2.6
	var rise: float = 1.4
	var bodies: Array[Transform3D] = []
	var body_cols: Array[Color] = []
	var heads: Array[Transform3D] = []
	var head_cols: Array[Color] = []
	var shirts: Array = [Color(0.85, 0.1, 0.1), Color(0.1, 0.3, 0.85), Color(0.95, 0.8, 0.1), Color(0.95, 0.95, 0.95),
		Color(0.1, 0.1, 0.12), Color(0.1, 0.6, 0.25), Color(0.95, 0.45, 0.05), Color(0.55, 0.2, 0.7)]
	var skins: Array = [Color(0.96, 0.8, 0.66), Color(0.85, 0.64, 0.48), Color(0.6, 0.42, 0.3), Color(0.38, 0.26, 0.18)]
	var side: Vector3 = Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var face := Basis(Vector3.UP, atan2(-away.x, -away.z))
	for k in range(rows):
		var top: float = 1.5 + k * rise
		var cc: Vector3 = front + away * (k + 0.5) * depth
		mb._create_static_box(cc + Vector3(0, top * 0.5, 0), Vector3(length, top, depth) if along_x else Vector3(depth, top, length), mb.mat_concrete_wall)
		for j in range(int(length / 0.9)):
			if _rng.randf() < 0.2:
				continue
			var p: Vector3 = cc + side * (-length * 0.5 + (j + 0.5) * 0.9) - away * 0.3
			bodies.append(Transform3D(face.scaled(Vector3(0.5, 0.75, 0.32)), p + Vector3(0, top + 0.4, 0)))
			body_cols.append(shirts[_rng.randi() % shirts.size()])
			heads.append(Transform3D(face.scaled(Vector3(0.24, 0.26, 0.24)), p + Vector3(0, top + 0.92, 0)))
			head_cols.append(skins[_rng.randi() % skins.size()])
	var roof_y: float = 1.5 + rows * rise + 4.0
	var rc: Vector3 = front + away * rows * depth * 0.6
	mb._create_static_box(rc + Vector3(0, roof_y, 0), Vector3(length + 4.0, 0.4, rows * depth * 0.75) if along_x else Vector3(rows * depth * 0.75, 0.4, length + 4.0), mb.mat_metal_blue)
	for px in range(-3, 4):
		mb._create_static_box(front + away * (rows * depth + 0.3) + side * px * length / 6.1 + Vector3(0, roof_y * 0.5, 0), Vector3(0.6, roof_y, 0.6), mb.mat_concrete_wall)
	var sign := Label3D.new()
	sign.text = sign_text
	sign.font_size = 260
	sign.pixel_size = 0.05
	sign.modulate = Color(1.0, 0.85, 0.1)
	sign.outline_size = 30
	sign.transform = Transform3D(face, rc + Vector3(0, roof_y + 4.5, 0) - away * 4.0)
	mb.add_child(sign)
	mb._add_crowd(bodies, body_cols)
	mb._add_crowd(heads, head_cols)

# ------------------------------------------------------------------ roads
# Dense Catmull-Rom samples (~`spacing` m apart) through the control points
func _spline(ctrl: Array, spacing: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var n: int = ctrl.size()
	for i in range(n - 1):
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		var steps: int = maxi(2, ceili(p1.distance_to(p2) / spacing))
		for s in range(steps):
			var t: float = float(s) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	pts.append(ctrl[n - 1])
	return pts

# Two-lane country road: tarmac, white edge lines, dashed centre line, dirt shoulders, street lamps
# and reflector posts. Returns the centre-line samples.
func _road(ctrl: Array, width: float) -> Array[Vector2]:
	var pts: Array[Vector2] = _spline(ctrl, 4.0)
	var half: float = width * 0.5
	var count: int = pts.size()
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var sh_l: Array[Vector3] = []
	var sh_r: Array[Vector3] = []
	var el0: Array[Vector3] = []
	var el1: Array[Vector3] = []
	var er0: Array[Vector3] = []
	var er1: Array[Vector3] = []
	var dist: Array[float] = []
	var nrms: Array[Vector2] = []
	var acc: float = 0.0
	for i in range(count):
		var t: Vector2 = (pts[mini(i + 1, count - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nm := Vector2(-t.y, t.x)
		nrms.append(nm)
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		dist.append(acc)
		var p: Vector2 = pts[i]
		left.append(_v3(p + nm * half, ROAD_Y))
		right.append(_v3(p - nm * half, ROAD_Y))
		sh_l.append(_v3(p + nm * (half + 1.8), -0.03))
		sh_r.append(_v3(p - nm * (half + 1.8), -0.03))
		el0.append(_v3(p + nm * (half - 0.25), ROAD_Y + 0.006))
		el1.append(_v3(p + nm * (half - 0.4), ROAD_Y + 0.006))
		er0.append(_v3(p - nm * (half - 0.4), ROAD_Y + 0.006))
		er1.append(_v3(p - nm * (half - 0.25), ROAD_Y + 0.006))
	var road_faces := PackedVector3Array()
	mb._add_strip(left, right, dist, 0.0, 1.0, 1.0 / 20.0, mb.mat_track, road_faces, 2)
	mb._add_collision_body(road_faces, "asphalt")
	var dirt_faces := PackedVector3Array()
	mb._add_strip(sh_l, left, dist, 0.0, 0.5, 1.0 / 12.0, _mat_shoulder, dirt_faces)
	mb._add_strip(right, sh_r, dist, 0.0, 0.5, 1.0 / 12.0, _mat_shoulder, dirt_faces)
	mb._add_collision_body(dirt_faces, "dirt")
	var unused := PackedVector3Array()
	mb._add_strip(el0, el1, dist, 0.0, 1.0, 0.1, _mat_line, unused)
	mb._add_strip(er0, er1, dist, 0.0, 1.0, 0.1, _mat_line, unused)
	# dashed centre line: 4 m dash every 12 m, one mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(count - 1):
		if fmod(dist[i], 12.0) >= 4.0:
			continue
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var w: Vector2 = nrms[i] * 0.075
		for q in [a + w, a - w, b + w, a - w, b - w, b + w]:
			st.add_vertex(_v3(q, ROAD_Y + 0.006))
	var dash := MeshInstance3D.new()
	dash.mesh = st.commit()
	dash.material_override = _mat_line
	dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mb.add_child(dash)
	# street lamps (alternating sides, every ~70 m) and white reflector posts (every 40 m both sides)
	var lamp_d: float = 20.0
	var lamp_side: float = 1.0
	var post_x: Array[Transform3D] = []
	var post_d: float = 0.0
	for i in range(count):
		if dist[i] >= lamp_d and dist[i] < acc - 20.0:
			var lp: Vector2 = pts[i] + nrms[i] * lamp_side * (half + 4.0)
			mb._street_lamp(_v3(lp, 0.0), -nrms[i] * lamp_side)
			lamp_side = -lamp_side
			lamp_d += 70.0
		if dist[i] >= post_d:
			for sd in [-1.0, 1.0]:
				post_x.append(Transform3D(Basis().scaled(Vector3(0.12, 1.0, 0.12)), _v3(pts[i] + nrms[i] * sd * (half + 2.4), 0.5)))
			post_d += 40.0
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.95, 0.95, 0.95)
	mb._mtn_multimesh(BoxMesh.new(), post_x, [] as Array[Color], post_mat)
	_mark_line(pts, half + 9.0)
	return pts

func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)

# ------------------------------------------------------------------ countryside
# Houses with red tiled roofs both sides of the road through the village, and a small mosque
func _village() -> void:
	var road: Array = _road_pts[2]
	var walls: Array = [Color(0.95, 0.92, 0.84), Color(0.93, 0.85, 0.7), Color(0.85, 0.88, 0.9), Color(0.96, 0.8, 0.68), Color(0.9, 0.9, 0.86)]
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.68, 0.22, 0.12)
	roof_mat.roughness = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.13, 0.16)
	var acc: float = 0.0
	var next_d: float = 0.0
	var side: float = 1.0
	var placed: int = 0
	var houses: Array = []
	for i in range(1, road.size() - 1):
		acc += (road[i] as Vector2).distance_to(road[i - 1])
		var p: Vector2 = road[i]
		if p.y < 1950.0 or p.y > 2750.0 or acc < next_d:
			continue
		var t: Vector2 = ((road[i + 1] as Vector2) - (road[i - 1] as Vector2)).normalized()
		var nm := Vector2(-t.y, t.x)
		for sd in [side, -side]:
			var hc: Vector2 = p + nm * sd * (30.0 + _rng.randf_range(0.0, 6.0))
			if _occ_free_house(hc):
				houses.append([hc, rad_to_deg(atan2(t.x, t.y)), walls[_rng.randi() % walls.size()]])
				placed += 1
				break
		side = -side
		next_d = acc + _rng.randf_range(26.0, 40.0)
	for h in houses:
		var hc: Vector2 = h[0]
		var yaw: float = h[1]
		var wm := StandardMaterial3D.new()
		wm.albedo_color = h[2]
		var w: float = _rng.randf_range(8.0, 11.0)
		var dpt: float = _rng.randf_range(9.0, 12.0)
		var ht: float = 3.2 if _rng.randf() < 0.5 else 6.0
		var c := _v3(hc, 0.0)
		mb._create_static_box(c + Vector3(0, ht * 0.5, 0), Vector3(w, ht, dpt), wm, Vector3(0, yaw, 0))
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(w + 0.8, 2.6, dpt + 0.8)
		roof.mesh = pm
		roof.material_override = roof_mat
		roof.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw + 90.0)), c + Vector3(0, ht + 1.3, 0))
		mb.add_child(roof)
		var rot := Basis(Vector3.UP, deg_to_rad(yaw))
		for sx in [-1.0, 1.0]:
			for fl in range(int(ht / 3.0)):
				_vis_box(c + rot * Vector3(sx * (w * 0.5 + 0.03), 1.7 + fl * 2.8, 0), Vector3(0.1, 1.2, 1.4), dark, yaw)
		_mark(hc, 12.0)
	# mosque on a free spot near the middle of the village
	for k in range(60):
		var p: Vector2 = road[int(road.size() * 0.5)] + Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-90.0, 90.0))
		if _free(p, 22.0):
			_mosque(p)
			_mark(p, 24.0)
			break

func _occ_free_house(c: Vector2) -> bool:
	return _free(c, 8.0)

func _mosque(p: Vector2) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.93, 0.92, 0.88)
	var lead := StandardMaterial3D.new()
	lead.albedo_color = Color(0.45, 0.5, 0.55)
	lead.metallic = 0.5
	lead.roughness = 0.4
	var c := _v3(p, 0.0)
	mb._create_static_box(c + Vector3(0, 4.0, 0), Vector3(16, 8, 16), stone)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 7.0
	sm.height = 7.0
	sm.is_hemisphere = true
	dome.mesh = sm
	dome.material_override = lead
	dome.position = c + Vector3(0, 8.0, 0)
	mb.add_child(dome)
	var mp: Vector3 = c + Vector3(10.5, 0, -6.0)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.9
	shaft.bottom_radius = 1.1
	shaft.height = 26.0
	var mi := MeshInstance3D.new()
	mi.mesh = shaft
	mi.material_override = stone
	mi.position = mp + Vector3(0, 13.0, 0)
	mb.add_child(mi)
	mb._create_static_box(mp + Vector3(0, 13.0, 0), Vector3(1.8, 26.0, 1.8), stone).visible = false
	var balcony := CylinderMesh.new()
	balcony.top_radius = 1.6
	balcony.bottom_radius = 1.3
	balcony.height = 0.8
	var bi := MeshInstance3D.new()
	bi.mesh = balcony
	bi.material_override = stone
	bi.position = mp + Vector3(0, 19.0, 0)
	mb.add_child(bi)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 5.0
	var ci := MeshInstance3D.new()
	ci.mesh = cone
	ci.material_override = lead
	ci.position = mp + Vector3(0, 28.5, 0)
	mb.add_child(ci)

# Wind farm: a grassy hill with a row of turbines (slowly turning rotors, red night lights)
func _wind_farm() -> void:
	var hill_c := Vector2(4080, 1850)
	var mat_hill: StandardMaterial3D = mb.mat_grass.duplicate() as StandardMaterial3D
	mat_hill.cull_mode = BaseMaterial3D.CULL_DISABLED
	mb._create_hill(_v3(hill_c, 0.0), 120.0, 22.0, mat_hill, 77)
	_mark(hill_c, 160.0)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.94, 0.95, 0.96)
	white.roughness = 0.5
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.1, 0.05)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.1, 0.05)
	red.emission_energy_multiplier = 4.0
	var spots: Array[Vector2] = [Vector2(3920, 1560), Vector2(4250, 1600), Vector2(3880, 2130), Vector2(4280, 2120), Vector2(4300, 1350), Vector2(3900, 2380), Vector2(4250, 2400)]
	for p in spots:
		if not _free(p, 20.0):
			continue
		_mark(p, 25.0)
		var c := _v3(p, 0.0)
		var tower := CylinderMesh.new()
		tower.top_radius = 1.2
		tower.bottom_radius = 2.2
		tower.height = 70.0
		var ti := MeshInstance3D.new()
		ti.mesh = tower
		ti.material_override = white
		ti.position = c + Vector3(0, 35.0, 0)
		mb.add_child(ti)
		mb._create_static_box(c + Vector3(0, 35.0, 0), Vector3(3.6, 70.0, 3.6), white).visible = false
		var head := Node3D.new()
		head.position = c + Vector3(0, 71.0, 0)
		head.rotation.y = deg_to_rad(-35.0) # all face the same wind
		mb.add_child(head)
		var nac := MeshInstance3D.new()
		var nm := BoxMesh.new()
		nm.size = Vector3(3.0, 3.2, 9.0)
		nac.mesh = nm
		nac.material_override = white
		head.add_child(nac)
		var lamp := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.5
		lm.height = 1.0
		lamp.mesh = lm
		lamp.material_override = red
		lamp.position = Vector3(0, 1.9, -3.5)
		head.add_child(lamp)
		var rotor := Node3D.new()
		rotor.position = Vector3(0, 0, 5.0)
		head.add_child(rotor)
		var hub := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 1.4
		hm.height = 2.8
		hub.mesh = hm
		hub.material_override = white
		rotor.add_child(hub)
		for k in range(3):
			var blade := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.6, 34.0, 0.3)
			blade.mesh = bm
			blade.material_override = white
			var a: float = TAU * k / 3.0
			blade.transform = Transform3D(Basis(Vector3(0, 0, 1), a), Vector3(-sin(a), cos(a), 0) * 17.5)
			rotor.add_child(blade)
		rotor.rotation.z = _rng.randf() * TAU
		var tw := mb.create_tween().set_loops()
		tw.tween_property(rotor, "rotation:z", rotor.rotation.z + TAU, _rng.randf_range(6.5, 8.5)).from(rotor.rotation.z)

# Rolling grassy hills wherever there's room
func _hills() -> void:
	var mat_hill: StandardMaterial3D = mb.mat_grass.duplicate() as StandardMaterial3D
	mat_hill.cull_mode = BaseMaterial3D.CULL_DISABLED
	var made: int = 0
	for k in range(600):
		if made >= 24:
			break
		var p := Vector2(_rng.randf_range(-1450.0, 4450.0), _rng.randf_range(-1450.0, 4450.0))
		var r: float = _rng.randf_range(50.0, 130.0)
		if not _free(p, r * 1.35):
			continue
		mb._create_hill(_v3(p, 0.0), r, _rng.randf_range(5.0, 18.0), mat_hill, 200 + k)
		_mark(p, r * 1.35)
		made += 1

# Farm fields: wheat, ploughed earth, green crops (flat colour patches on the meadow)
func _fields() -> void:
	var cols: Array = [Color(0.86, 0.74, 0.36), Color(0.45, 0.33, 0.22), Color(0.36, 0.55, 0.2), Color(0.78, 0.66, 0.3), Color(0.5, 0.62, 0.25)]
	var made: int = 0
	for k in range(300):
		if made >= 26:
			break
		var p := Vector2(_rng.randf_range(-1450.0, 4450.0), _rng.randf_range(-1450.0, 4450.0))
		var size := Vector2(_rng.randf_range(90.0, 170.0), _rng.randf_range(140.0, 260.0))
		if not _free(p, size.length() * 0.5):
			continue
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[_rng.randi() % cols.size()]
		m.roughness = 1.0
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = size
		mi.mesh = pm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5)), _v3(p, 0.03))
		mb.add_child(mi)
		_mark(p, size.length() * 0.5)
		made += 1

# Woods: trees in noisy clusters on the free ground (solid trunks, MultiMesh crowns)
func _forest() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.0035
	var trunk_x: Array[Transform3D] = []
	var pine_x: Array[Transform3D] = []
	var pine_c: Array[Color] = []
	var leaf_x: Array[Transform3D] = []
	var leaf_c: Array[Color] = []
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 4.0, 0.6)
	var trunks := StaticBody3D.new()
	trunks.set_meta("surface", "dirt")
	mb.add_child(trunks)
	for k in range(140000):
		if trunk_x.size() >= 7000:
			break
		var p := Vector2(_rng.randf_range(-1450.0, 4450.0), _rng.randf_range(-1450.0, 4450.0))
		if noise.get_noise_2d(p.x, p.y) < 0.12 or not _free(p):
			continue
		var h: float = _rng.randf_range(7.0, 13.0)
		trunk_x.append(Transform3D(Basis().scaled(Vector3(0.35, h * 0.45, 0.35)), _v3(p, h * 0.225)))
		if _rng.randf() < 0.55:
			pine_x.append(Transform3D(Basis().scaled(Vector3(h * 0.32, h * 0.72, h * 0.32)), _v3(p, h * 0.45 + h * 0.36)))
			pine_c.append(Color(0.08, _rng.randf_range(0.26, 0.38), 0.1))
		else:
			leaf_x.append(Transform3D(Basis().scaled(Vector3(h * 0.5, h * 0.42, h * 0.5)), _v3(p, h * 0.62)))
			leaf_c.append(Color(_rng.randf_range(0.12, 0.25), _rng.randf_range(0.36, 0.5), _rng.randf_range(0.08, 0.15)))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = _v3(p, 2.0)
		trunks.add_child(cs)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.3, 0.2, 0.12)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.6
	trunk_mesh.bottom_radius = 0.8
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	mb._mtn_multimesh(trunk_mesh, trunk_x, [] as Array[Color], bark)
	var pine := CylinderMesh.new()
	pine.top_radius = 0.0
	pine.bottom_radius = 1.0
	pine.height = 1.0
	pine.radial_segments = 8
	mb._mtn_multimesh(pine, pine_x, pine_c)
	var leaf := SphereMesh.new()
	leaf.radial_segments = 10
	leaf.rings = 6
	mb._mtn_multimesh(leaf, leaf_x, leaf_c)
