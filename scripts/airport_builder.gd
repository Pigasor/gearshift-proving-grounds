extends RefCounted
class_name AirportBuilder
# The proving ground sits on a (closed) airfield, like real test tracks on old airports:
#  - Runway 18/36 (45 m x 2.3 km) with ICAO-style markings and edge / threshold / approach lights.
#    The drag-race distance marks are painted on it.
#  - Parallel taxiway A with five link taxiways and holding-position markings.
#  - Concrete apron with a terminal + jet bridges, control tower, three drive-in hangars and parked
#    aircraft, apron flood-light masts and a windsock.
# Axes: -Z = north. Everything is built with MapBuilder's helpers so surfaces/grip work as usual.

const RW_W: float = 45.0
const RW_Z0: float = -1150.0 # north threshold (runway 18)
const RW_Z1: float = 1150.0 # south threshold (runway 36)
const TWY_X: float = 100.0
const TWY_W: float = 23.0
const APRON_X0: float = TWY_X + TWY_W * 0.5 # west edge = taxiway edge
const APRON_X1: float = 340.0
const APRON_Z0: float = -1070.0
const APRON_Z1: float = -430.0
const STANDS_Z: Array[float] = [-920.0, -810.0, -700.0, -590.0]
const DRAG_START_Z: float = -1090.0

var mb: Node3D
var mat_runway: StandardMaterial3D
var mat_apron: StandardMaterial3D
var mat_light_white: StandardMaterial3D
var mat_light_green: StandardMaterial3D
var mat_light_red: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_white_paint: StandardMaterial3D
var mat_dark: StandardMaterial3D
var _font: Font

func build(map_builder: Node3D) -> void:
	mb = map_builder
	_materials()
	_runway()
	_taxiways()
	_apron()
	_terminal_and_tower()
	_hangars()
	_aircraft()
	_extras()

func _materials() -> void:
	mat_runway = (mb.mat_asphalt as StandardMaterial3D).duplicate()
	mat_runway.albedo_color = Color(0.78, 0.78, 0.8)
	mat_apron = (mb.mat_concrete_wall as StandardMaterial3D).duplicate()
	mat_apron.uv1_scale = Vector3(0.05, 0.05, 0.05) # big concrete slabs with joints
	mat_apron.albedo_color = Color(0.92, 0.92, 0.9)
	mat_light_white = _emissive(Color(1.0, 0.97, 0.85), 3.0)
	mat_light_green = _emissive(Color(0.2, 1.0, 0.35), 3.0)
	mat_light_red = _emissive(Color(1.0, 0.12, 0.08), 3.0)
	mat_glass = StandardMaterial3D.new()
	mat_glass.albedo_color = Color(0.25, 0.42, 0.55)
	mat_glass.metallic = 0.8
	mat_glass.roughness = 0.08
	mat_white_paint = StandardMaterial3D.new()
	mat_white_paint.albedo_color = Color(0.93, 0.94, 0.96)
	mat_white_paint.metallic = 0.3
	mat_white_paint.roughness = 0.35
	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.12, 0.13, 0.15)
	mat_dark.roughness = 0.6
	if ResourceLoader.exists("res://fonts/game_font.tres"):
		_font = load("res://fonts/game_font.tres")

func _emissive(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

# Painted marking on the runway/apron (visual only)
func _paint(x: float, z: float, sx: float, sz: float, mat: Material, y: float = 0.052) -> void:
	mb._create_marking(Vector3(x, y, z), Vector3(sx, 0.01, sz), mat)

# Text painted flat on the ground. up_dir_z: +1 = top of the text towards +Z
func _ground_text(text: String, pos: Vector3, size_px: int, up_dir_z: float, color: Color = Color(0.96, 0.96, 0.98)) -> void:
	var l := Label3D.new()
	l.text = text
	if _font:
		l.font = _font
	l.font_size = size_px
	l.pixel_size = 0.1
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation_degrees = Vector3(-90.0, 180.0 if up_dir_z > 0.0 else 0.0, 0.0)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mb.add_child(l)

func _visual(mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mb.add_child(mi)
	return mi

func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _cyl_mesh(r_top: float, r_bot: float, h: float, segs: int = 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	return c

# Static collider without a mesh (for parts whose look is built from other meshes)
func _collider(shape: Shape3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, surface: String = "concrete") -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	body.set_meta("surface", surface)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	mb.add_child(body)

func _box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s

# ------------------------------------------------------------------ RUNWAY 18/36
func _runway() -> void:
	var len: float = RW_Z1 - RW_Z0
	var zc: float = (RW_Z0 + RW_Z1) * 0.5
	mb._create_static_box(Vector3(0, 0.02, zc), Vector3(RW_W, 0.04, len), mat_runway)
	# paved shoulders
	for s in [-1.0, 1.0]:
		mb._create_static_box(Vector3(s * (RW_W * 0.5 + 3.75), 0.015, zc), Vector3(7.5, 0.03, len), mb.mat_track)
	# blast pads beyond both ends (yellow chevrons)
	for end in [-1.0, 1.0]:
		var zp: float = (RW_Z1 + 30.0) if end > 0.0 else (RW_Z0 - 30.0)
		mb._create_static_box(Vector3(0, 0.015, zp), Vector3(RW_W, 0.03, 60.0), mb.mat_track)
		for k in range(3):
			var zz: float = zp + end * (-18.0 + k * 18.0)
			for s in [-1.0, 1.0]:
				_paint(s * 10.0, zz, 18.0, 1.5, mb.mat_road_yellow, 0.04)

	var white: Material = mb.mat_road_white
	# edge lines & dashed centre line (30 m dash, 20 m gap)
	for s in [-1.0, 1.0]:
		_paint(s * (RW_W * 0.5 - 1.2), zc, 0.9, len, white)
	var z: float = RW_Z0 + 190.0
	while z < RW_Z1 - 190.0:
		_paint(0.0, z + 15.0, 0.9, 30.0, white)
		z += 50.0
	# thresholds: piano keys + threshold bar, designator numbers, touchdown & aiming-point marks
	for end in [-1.0, 1.0]: # -1 = north end (RWY 18), +1 = south end (RWY 36)
		var thr: float = RW_Z0 if end < 0.0 else RW_Z1
		var inward: float = -end # direction along the runway, from threshold into the runway
		_paint(0.0, thr + inward * 1.0, RW_W - 2.0, 1.8, white)
		for k in range(6):
			for s in [-1.0, 1.0]:
				_paint(s * (3.0 + k * 3.4), thr + inward * 22.0, 1.8, 30.0, white)
		_ground_text("18" if end < 0.0 else "36", Vector3(0.0, 0.06, thr + inward * 70.0), 110, inward)
		# touchdown zone bars (3, 2, 1 pairs at 150 / 300 / 450 m)
		var tdz: Array = [[150.0, 3], [300.0, 2], [450.0, 1]]
		for t in tdz:
			for b in range(int(t[1])):
				for s in [-1.0, 1.0]:
					_paint(s * (6.0 + b * 2.6), thr + inward * float(t[0]), 1.8, 22.5, white)
		# aiming point (two large blocks at 400 m)
		for s in [-1.0, 1.0]:
			_paint(s * 9.5, thr + inward * 400.0, 7.0, 48.0, white)
		# threshold lights (green across the end), runway-end lights (red) just behind
		for k in range(12):
			var lx: float = -RW_W * 0.5 + 1.5 + k * ((RW_W - 3.0) / 11.0)
			_visual(_box_mesh(Vector3(0.5, 0.3, 0.5)), mat_light_green, Vector3(lx, 0.15, thr - inward * 1.5), Vector3.ZERO, false)
			_visual(_box_mesh(Vector3(0.5, 0.3, 0.5)), mat_light_red, Vector3(lx, 0.15, thr - inward * 3.0), Vector3.ZERO, false)
		# approach light bars on poles, out beyond the end (stop before the highway)
		for k in range(4):
			var az: float = thr - inward * (65.0 + k * 18.0)
			_visual(_box_mesh(Vector3(0.2, 2.0 + k * 0.4, 0.2)), mat_dark, Vector3(0, 1.0 + k * 0.2, az))
			_visual(_box_mesh(Vector3(9.0, 0.25, 0.4)), mat_light_white, Vector3(0, 2.1 + k * 0.4, az), Vector3.ZERO, false)
	# edge lights every 60 m
	var ez: float = RW_Z0 + 30.0
	while ez < RW_Z1:
		for s in [-1.0, 1.0]:
			_visual(_box_mesh(Vector3(0.35, 0.35, 0.35)), mat_light_white, Vector3(s * (RW_W * 0.5 + 1.0), 0.18, ez), Vector3.ZERO, false)
		ez += 60.0

	# Drag-race distances from the drag start line (yellow lines across the runway + labels)
	var marks: Array = [[0.0, "DRAG START"], [201.17, "1/8 MILE"], [402.34, "1/4 MILE"], [804.67, "1/2 MILE"], [1609.34, "1 MILE"]]
	for m in marks:
		var mz: float = DRAG_START_Z + float(m[0])
		_paint(0.0, mz, RW_W - 4.0, 1.2 if float(m[0]) > 0.0 else 2.0, mb.mat_road_yellow, 0.055)
		_ground_text(str(m[1]), Vector3(-(RW_W * 0.5 + 3.8), 0.07, mz + 6.0), 28, 1.0, Color(0.98, 0.8, 0.1)) # above runway (0.04) and paint (0.057): no z-fighting

# ------------------------------------------------------------------ TAXIWAYS
func _taxiways() -> void:
	var z0: float = -1100.0
	var z1: float = 1100.0
	mb._create_static_box(Vector3(TWY_X, 0.02, (z0 + z1) * 0.5), Vector3(TWY_W, 0.04, z1 - z0), mb.mat_asphalt)
	_paint(TWY_X, (z0 + z1) * 0.5, 0.3, z1 - z0, mb.mat_road_yellow)
	for s in [-1.0, 1.0]:
		_paint(TWY_X + s * (TWY_W * 0.5 - 0.6), (z0 + z1) * 0.5, 0.2, z1 - z0, mb.mat_road_yellow)
	# link taxiways runway <-> taxiway A, with holding-position markings
	var links: Array[float] = [-1100.0, -600.0, 0.0, 600.0, 1100.0]
	var names: Array[String] = ["A1", "A2", "A3", "A4", "A5"]
	var x_from: float = RW_W * 0.5
	var x_to: float = TWY_X - TWY_W * 0.5
	for i in range(links.size()):
		var lz: float = links[i]
		mb._create_static_box(Vector3((x_from + x_to) * 0.5, 0.02, lz), Vector3(x_to - x_from + 2.0, 0.04, TWY_W), mb.mat_asphalt)
		_paint((x_from + x_to) * 0.5 + 6.0, lz, x_to - x_from - 10.0, 0.3, mb.mat_road_yellow)
		# hold short: two solid + two dashed lines, 30 m from the runway edge
		var hx: float = x_from + 30.0
		for k in range(2):
			_paint(hx + k * 0.9, lz, 0.3, TWY_W - 2.0, mb.mat_road_yellow, 0.055)
		for k in range(2):
			var dz: float = -TWY_W * 0.5 + 1.5
			while dz < TWY_W * 0.5 - 1.5:
				_paint(hx - 2.4 - k * 0.9, lz + dz + 0.75, 0.3, 1.5, mb.mat_road_yellow, 0.055)
				dz += 3.0
		_ground_text(names[i], Vector3(hx + 8.0, 0.06, lz), 60, -1.0, Color(0.98, 0.8, 0.1))
		# taxiway signs (yellow on black boards)
		_visual(_box_mesh(Vector3(0.3, 1.2, 2.6)), mat_dark, Vector3(hx, 0.6, lz + TWY_W * 0.5 + 3.0))

# ------------------------------------------------------------------ APRON
func _apron() -> void:
	var cx: float = (APRON_X0 + APRON_X1) * 0.5
	var cz: float = (APRON_Z0 + APRON_Z1) * 0.5
	mb._create_static_box(Vector3(cx, 0.03, cz), Vector3(APRON_X1 - APRON_X0, 0.06, APRON_Z1 - APRON_Z0), mat_apron)
	# apron edge line & stand lead-in lines with stop bars and numbers
	_paint(APRON_X0 + 4.0, cz, 0.3, APRON_Z1 - APRON_Z0 - 4.0, mb.mat_road_yellow, 0.07)
	for i in range(STANDS_Z.size()):
		var sz: float = STANDS_Z[i]
		_paint((APRON_X0 + 300.0) * 0.5, sz, 300.0 - APRON_X0, 0.3, mb.mat_road_yellow, 0.07)
		_paint(298.0, sz, 0.6, 8.0, mb.mat_road_yellow, 0.07)
		_ground_text(str(i + 11), Vector3(250.0, 0.075, sz + 10.0), 70, -1.0, Color(0.98, 0.8, 0.1))
	# parking box for cars (spawn area) in the north-east corner, white bays
	for b in range(8):
		var bz: float = -520.0 + b * 6.0
		_paint(160.0, bz, 10.0, 0.2, mb.mat_road_white, 0.07)
	_ground_text("PADDOCK", Vector3(185.0, 0.075, -540.0), 60, -1.0) # readable from the spawn (car faces -Z)
	# apron flood-light masts
	for p in [Vector3(125, 0, -1045), Vector3(330, 0, -1045), Vector3(125, 0, -445), Vector3(240, 0, -445)]:
		mb._create_static_box(p + Vector3(0, 12.0, 0), Vector3(0.8, 24.0, 0.8), mb.mat_concrete_wall)
		_visual(_box_mesh(Vector3(4.0, 1.0, 1.2)), mat_light_white, p + Vector3(0, 24.0, 0), Vector3.ZERO, false)
		var light := OmniLight3D.new()
		light.position = p + Vector3(0, 23.0, 0)
		light.light_color = Color(1.0, 0.95, 0.85)
		light.light_energy = 3.0
		light.omni_range = 90.0
		light.add_to_group("floodlights")
		mb.add_child(light)

# ------------------------------------------------------------------ TERMINAL & TOWER
func _terminal_and_tower() -> void:
	var tx: float = APRON_X1 + 20.0
	var tz0: float = -980.0
	var tz1: float = -540.0
	var tzc: float = (tz0 + tz1) * 0.5
	var tl: float = tz1 - tz0
	# concrete base + glass curtain wall + roof canopy
	mb._create_static_box(Vector3(tx, 2.0, tzc), Vector3(40.0, 4.0, tl), mb.mat_concrete_wall)
	mb._create_static_box(Vector3(tx, 9.0, tzc), Vector3(38.0, 10.0, tl - 2.0), mat_glass)
	mb._create_static_box(Vector3(tx - 2.0, 14.6, tzc), Vector3(46.0, 1.2, tl + 6.0), mat_white_paint)
	# vertical mullions on the apron side
	var mz: float = tz0 + 6.0
	while mz < tz1:
		_visual(_box_mesh(Vector3(0.4, 10.0, 0.4)), mat_white_paint, Vector3(tx - 19.2, 9.0, mz))
		mz += 8.0
	# name on the roof edge
	var sign := Label3D.new()
	sign.text = "GEARSHIFT AIRPORT"
	if _font:
		sign.font = _font
	sign.font_size = 72
	sign.pixel_size = 0.05
	sign.modulate = Color(0.1, 0.35, 0.75)
	sign.position = Vector3(tx - 23.1, 16.6, tzc)
	sign.rotation_degrees = Vector3(0, -90, 0)
	mb.add_child(sign)
	# jet bridges reaching to the stands
	for sz in STANDS_Z:
		mb._create_static_box(Vector3(tx - 30.0, 5.0, sz), Vector3(22.0, 3.2, 3.4), mat_glass)
		mb._create_static_box(Vector3(tx - 39.0, 2.0, sz), Vector3(1.0, 4.0, 1.0), mb.mat_concrete_wall)

	# Control tower: concrete shaft, glass cab, roof and antenna
	var tp := Vector3(390.0, 0.0, -430.0)
	var shaft := _cyl_mesh(3.6, 4.4, 40.0)
	_visual(shaft, mb.mat_concrete_wall, tp + Vector3(0, 20.0, 0))
	var cs := CylinderShape3D.new()
	cs.radius = 4.4
	cs.height = 40.0
	_collider(cs, tp + Vector3(0, 20.0, 0))
	_visual(_cyl_mesh(7.0, 5.0, 2.0), mb.mat_concrete_wall, tp + Vector3(0, 41.0, 0))
	_visual(_cyl_mesh(7.4, 6.6, 5.0, 16), mat_glass, tp + Vector3(0, 44.5, 0))
	_visual(_cyl_mesh(8.2, 7.6, 1.0), mat_white_paint, tp + Vector3(0, 47.5, 0))
	_visual(_box_mesh(Vector3(0.3, 8.0, 0.3)), mat_dark, tp + Vector3(0, 52.0, 0))
	_visual(_box_mesh(Vector3(0.6, 0.6, 0.6)), mat_light_red, tp + Vector3(0, 56.2, 0), Vector3.ZERO, false)
	# small ground building at the tower foot
	mb._create_static_box(tp + Vector3(-14.0, 3.0, 0), Vector3(16.0, 6.0, 12.0), mb.mat_concrete_wall)

# ------------------------------------------------------------------ HANGARS (drive-in)
func _hangars() -> void:
	# Open front towards the apron (north, -Z is behind). Walls & roof collide; cars can drive in.
	for i in range(3):
		var cx: float = 165.0 + i * 70.0
		var cz: float = -1100.0
		var w: float = 56.0
		var d: float = 60.0
		var h: float = 16.0
		var wall: Material = mb.mat_metal_blue if i != 1 else mb.mat_concrete_wall
		mb._create_static_box(Vector3(cx, h * 0.5, cz - d * 0.5), Vector3(w, h, 1.0), wall) # back
		mb._create_static_box(Vector3(cx - w * 0.5, h * 0.5, cz), Vector3(1.0, h, d), wall) # sides
		mb._create_static_box(Vector3(cx + w * 0.5, h * 0.5, cz), Vector3(1.0, h, d), wall)
		mb._create_static_box(Vector3(cx, h - 2.0, cz + d * 0.5), Vector3(w, 4.0, 1.0), wall) # door header
		# curved roof: a low arch made of panels (elliptical, 8 m rise over the walls)
		var segs: int = 12
		var rise: float = 8.0
		for k in range(segs):
			var a0: float = PI * float(k) / float(segs)
			var a1: float = PI * float(k + 1) / float(segs)
			var p0 := Vector2(-cos(a0) * w * 0.5, sin(a0) * rise)
			var p1 := Vector2(-cos(a1) * w * 0.5, sin(a1) * rise)
			var mid: Vector2 = (p0 + p1) * 0.5
			var seg_len: float = p0.distance_to(p1) + 0.15
			var ang: float = rad_to_deg(atan2(p1.y - p0.y, p1.x - p0.x))
			_visual(_box_mesh(Vector3(seg_len, 0.4, d + 1.0)), mat_white_paint, Vector3(cx + mid.x, h + mid.y, cz), Vector3(0, 0, ang))
		_collider(_box_shape(Vector3(w, 1.0, d)), Vector3(cx, h + 0.5, cz))
		# concrete floor inside + hangar number
		mb._create_static_box(Vector3(cx, 0.03, cz), Vector3(w - 2.0, 0.06, d - 1.0), mat_apron)
		var num := Label3D.new()
		num.text = "HANGAR %d" % (i + 1)
		if _font:
			num.font = _font
		num.font_size = 64
		num.pixel_size = 0.05
		num.modulate = Color(0.95, 0.95, 0.95)
		num.position = Vector3(cx, h - 2.0, cz + d * 0.5 + 0.6)
		mb.add_child(num)

# ------------------------------------------------------------------ PARKED AIRCRAFT
func _aircraft() -> void:
	var liveries: Array = [Color(0.85, 0.1, 0.12), Color(0.1, 0.35, 0.8), Color(0.95, 0.6, 0.05)]
	for i in range(3):
		_airliner(Vector3(262.0, 0.0, STANDS_Z[i]), liveries[i])
	_bizjet(Vector3(268.0, 0.0, STANDS_Z[3]))

# Narrow-body airliner (~38 m long, 34 m span) pointing +X (nose at the terminal)
func _airliner(base: Vector3, tail_color: Color) -> void:
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = tail_color
	tail_mat.roughness = 0.4
	var fy: float = 4.2
	var fus := _cyl_mesh(2.0, 2.0, 30.0)
	_visual(fus, mat_white_paint, base + Vector3(0, fy, 0), Vector3(0, 0, 90))
	var nose := _cyl_mesh(0.3, 2.0, 5.0)
	_visual(nose, mat_white_paint, base + Vector3(17.5, fy - 0.2, 0), Vector3(0, 0, -90))
	var tailcone := _cyl_mesh(0.4, 2.0, 7.0)
	_visual(tailcone, mat_white_paint, base + Vector3(-18.5, fy + 0.4, 0), Vector3(0, 0, 90))
	_visual(_box_mesh(Vector3(1.2, 0.5, 2.6)), mat_dark, base + Vector3(18.6, fy + 0.6, 0)) # cockpit windows
	for k in range(14): # cabin windows
		for s in [-1.0, 1.0]:
			_visual(_box_mesh(Vector3(0.35, 0.3, 0.05)), mat_dark, base + Vector3(12.0 - k * 1.8, fy + 0.6, s * 1.98))
	# wings (swept) + engines + winglets
	for s in [-1.0, 1.0]:
		_visual(_box_mesh(Vector3(5.5, 0.4, 15.5)), mat_white_paint, base + Vector3(-1.0, fy - 1.3, s * 9.5), Vector3(0, s * -22.0, 0))
		_visual(_box_mesh(Vector3(1.6, 2.2, 0.25)), tail_mat, base + Vector3(-5.6, fy - 0.2, s * 17.0), Vector3(0, 0, 0))
		_visual(_cyl_mesh(1.0, 1.0, 4.0), mat_dark, base + Vector3(2.0, fy - 2.4, s * 5.8), Vector3(0, 0, 90))
		_visual(_cyl_mesh(0.3, 0.3, 2.6), mat_dark, base + Vector3(-1.0, 1.3, s * 3.0)) # main gear
	_visual(_cyl_mesh(0.25, 0.25, 2.4), mat_dark, base + Vector3(15.0, 1.2, 0))  # nose gear
	# tail: fin + stabilisers in the livery colour
	_visual(_box_mesh(Vector3(5.0, 7.0, 0.4)), tail_mat, base + Vector3(-19.0, fy + 5.0, 0), Vector3(0, 0, -25))
	for s in [-1.0, 1.0]:
		_visual(_box_mesh(Vector3(3.0, 0.3, 6.0)), mat_white_paint, base + Vector3(-19.5, fy + 0.8, s * 3.6), Vector3(0, s * -20.0, 0))
	# collisions: fuselage, wings, tail, engines (cars can't drive through)
	_collider(_box_shape(Vector3(40.0, 4.0, 4.0)), base + Vector3(-0.5, fy, 0), Vector3.ZERO, "concrete")
	_collider(_box_shape(Vector3(5.5, 0.6, 33.0)), base + Vector3(-1.0, fy - 1.3, 0))
	for s in [-1.0, 1.0]:
		_collider(_box_shape(Vector3(4.0, 2.0, 2.0)), base + Vector3(2.0, fy - 2.4, s * 5.8))
		_collider(_box_shape(Vector3(0.6, 2.6, 0.6)), base + Vector3(-1.0, 1.3, s * 3.0))
	_collider(_box_shape(Vector3(0.5, 2.4, 0.5)), base + Vector3(15.0, 1.2, 0))

# Small business jet (~16 m), rear engines
func _bizjet(base: Vector3) -> void:
	var fy: float = 2.2
	_visual(_cyl_mesh(1.0, 1.0, 12.0), mat_white_paint, base + Vector3(0, fy, 0), Vector3(0, 0, 90))
	_visual(_cyl_mesh(0.15, 1.0, 3.0), mat_white_paint, base + Vector3(7.5, fy - 0.1, 0), Vector3(0, 0, -90))
	_visual(_cyl_mesh(0.2, 1.0, 3.0), mat_white_paint, base + Vector3(-7.5, fy + 0.2, 0), Vector3(0, 0, 90))
	_visual(_box_mesh(Vector3(0.8, 0.35, 1.4)), mat_dark, base + Vector3(7.0, fy + 0.4, 0))
	for s in [-1.0, 1.0]:
		_visual(_box_mesh(Vector3(2.6, 0.2, 7.0)), mat_white_paint, base + Vector3(0.0, fy - 0.6, s * 4.3), Vector3(0, s * -18.0, 0))
		_visual(_cyl_mesh(0.5, 0.5, 2.6), mat_dark, base + Vector3(-4.6, fy + 0.6, s * 1.5), Vector3(0, 0, 90))
	_visual(_box_mesh(Vector3(2.4, 3.2, 0.25)), mat_dark, base + Vector3(-8.0, fy + 2.0, 0), Vector3(0, 0, -30))
	_visual(_box_mesh(Vector3(1.6, 0.2, 5.0)), mat_white_paint, base + Vector3(-8.8, fy + 3.5, 0))
	_collider(_box_shape(Vector3(17.0, 2.2, 2.2)), base + Vector3(0, fy, 0))
	_collider(_box_shape(Vector3(2.6, 0.4, 15.0)), base + Vector3(0, fy - 0.6, 0))

# ------------------------------------------------------------------ EXTRAS
func _extras() -> void:
	# Windsock between runway and taxiway
	var wp := Vector3(60.0, 0.0, 250.0)
	_visual(_box_mesh(Vector3(0.2, 6.0, 0.2)), mat_dark, wp + Vector3(0, 3.0, 0))
	var sock_mat := StandardMaterial3D.new()
	sock_mat.albedo_color = Color(1.0, 0.45, 0.05)
	_visual(_cyl_mesh(0.25, 0.55, 3.2, 12), sock_mat, wp + Vector3(1.6, 5.8, 0), Vector3(0, 0, 80))
	# Airport perimeter road sign at the apron
	var s := Label3D.new()
	s.text = "◀ RUNWAY 18/36    APRON ▶"
	if _font:
		s.font = _font
	s.font_size = 48
	s.pixel_size = 0.04
	s.position = Vector3(APRON_X0 + 10.0, 3.0, -425.0)
	s.modulate = Color(1, 0.85, 0.2)
	mb.add_child(s)
	_visual(_box_mesh(Vector3(9.0, 1.6, 0.2)), mat_dark, Vector3(APRON_X0 + 10.0, 3.0, -425.12))
	_visual(_box_mesh(Vector3(0.2, 3.0, 0.2)), mat_dark, Vector3(APRON_X0 + 10.0, 1.2, -425.2))
