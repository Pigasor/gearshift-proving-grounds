extends RefCounted
class_name BodyBuilder
# Builds a car body procedurally from real dimensions and a per-model style.
# The side silhouette (bumper - hood - windscreen - roof - rear window - boot) is extruded across
# the width; nose, tail and glasshouse are tapered. Each style adds the model's own recognisable
# details: grille, headlight & tail-light graphics, DRL signature, spoiler, chrome, pillars.
# Car axes: +Z forward, +X left, origin = wheel mount height. Returns the tail-light materials
# (the car makes them glow when braking).

var _parent: Node3D
var _brake_mats: Array[StandardMaterial3D] = []
var exhausts: Array[Vector3] = [] # tailpipe tips drawn on this body (the car puts its smoke there)

# Silhouette: lengths are fractions of the car length from the front bumper, heights in metres
# above the ground. hood = bumper -> windscreen base, ws = windscreen run, roof = flat roof run,
# rw = rear window run (rest = boot / deck). taper_f / taper_r = plan-view rounding of nose / tail,
# tumble = glasshouse width at the roof (fraction), spoiler = "none" | "lip" | "duck" | "wing" | "hoop".
const STYLES: Dictionary = {
	# Hyundai Accent Blue (RB): raked screen, coupe-like roof arc, rising beltline, high short boot
	"accent": { "hood": 0.235, "ws": 0.185, "roof": 0.25, "rw": 0.17, "nose": 0.64, "cowl": 0.84, "belt": 0.99,
		"deck": 1.01, "taper_f": 0.13, "taper_r": 0.08, "tumble": 0.70, "spoiler": "lip" },
	# Fiat Egea / Tipo sedan: upright, boxy, long flat roof, long boot
	"egea": { "hood": 0.215, "ws": 0.150, "roof": 0.33, "rw": 0.12, "nose": 0.71, "cowl": 0.90, "belt": 0.99,
		"deck": 1.02, "taper_f": 0.07, "taper_r": 0.05, "tumble": 0.78, "spoiler": "none" },
	# Honda Civic FC sedan: low nose, long hood, fastback roof sloping into a short ducktail boot
	"civic": { "hood": 0.255, "ws": 0.190, "roof": 0.17, "rw": 0.27, "nose": 0.57, "cowl": 0.80, "belt": 0.95,
		"deck": 0.94, "taper_f": 0.14, "taper_r": 0.09, "tumble": 0.66, "spoiler": "duck" },
	# Renault Megane IV sedan: sculpted, mid-height, rounded tail
	"megane": { "hood": 0.240, "ws": 0.175, "roof": 0.25, "rw": 0.17, "nose": 0.65, "cowl": 0.86, "belt": 0.97,
		"deck": 0.99, "taper_f": 0.11, "taper_r": 0.08, "tumble": 0.72, "spoiler": "lip" },
	# Tofas Sahin (Fiat 131 based): three-box, upright screen, flat hood, flat roof, long flat boot
	"sahin": { "hood": 0.265, "ws": 0.125, "roof": 0.30, "rw": 0.10, "nose": 0.72, "cowl": 0.85, "belt": 0.91,
		"deck": 0.92, "taper_f": 0.03, "taper_r": 0.02, "tumble": 0.80, "spoiler": "none" },
	# Nissan GT-R R35: tall muscular coupe, C-pillar "shark fin", high tail, small wing
	"gtr": { "hood": 0.285, "ws": 0.165, "roof": 0.17, "rw": 0.22, "nose": 0.66, "cowl": 0.86, "belt": 0.98,
		"deck": 1.04, "taper_f": 0.12, "taper_r": 0.05, "tumble": 0.68, "spoiler": "wing" },
	# Toyota Supra A80: long low curvy nose, bubble cabin, big hoop wing
	"supra": { "hood": 0.330, "ws": 0.170, "roof": 0.14, "rw": 0.19, "nose": 0.55, "cowl": 0.79, "belt": 0.90,
		"deck": 0.93, "taper_f": 0.16, "taper_r": 0.10, "tumble": 0.66, "spoiler": "hoop" },
	# Dodge Challenger: long, flat, boxy muscle car
	"challenger": { "hood": 0.320, "ws": 0.145, "roof": 0.20, "rw": 0.15, "nose": 0.82, "cowl": 0.97, "belt": 1.02,
		"deck": 1.03, "taper_f": 0.04, "taper_r": 0.03, "tumble": 0.80, "spoiler": "lip" },
	# Bugatti Chiron: mid-engine, very low, cabin forward, long engine cover
	"chiron": { "hood": 0.270, "ws": 0.170, "roof": 0.10, "rw": 0.30, "nose": 0.50, "cowl": 0.72, "belt": 0.84,
		"deck": 0.93, "taper_f": 0.15, "taper_r": 0.06, "tumble": 0.64, "spoiler": "flat" },
}

var paint: StandardMaterial3D
var glass: StandardMaterial3D
var black: StandardMaterial3D
var chrome: StandardMaterial3D
var head: StandardMaterial3D
var drl: StandardMaterial3D
var tail: StandardMaterial3D
var amber: StandardMaterial3D
var plate: StandardMaterial3D
var lens: StandardMaterial3D

# Key stations (filled in build)
var L: float
var W: float
var H: float
var wb: float
var zf: float
var zr: float
var g: float
var hw: float
var s: Dictionary
var cowl_z: float
var ws_top_z: float
var roof_rear_z: float
var deck_z: float
var taper: Callable

func build(parent: Node3D, b: Dictionary, ground_y: float, tire_r: float) -> Array[StandardMaterial3D]:
	_parent = parent
	_brake_mats.clear()
	exhausts.clear()
	s = STYLES.get(str(b.get("style", "accent")), STYLES["accent"])
	L = float(b["length"])
	W = float(b["width"])
	H = float(b["height"])
	wb = float(b["wheelbase"])
	zf = wb * 0.5 + float(b["front_overhang"])
	zr = zf - L
	g = ground_y
	hw = W * 0.5 - 0.02
	_make_materials(b["color"])

	cowl_z = zf - L * float(s["hood"])
	ws_top_z = cowl_z - L * float(s["ws"])
	roof_rear_z = ws_top_z - L * float(s["roof"])
	deck_z = roof_rear_z - L * float(s["rw"])
	var nose_h: float = float(s["nose"])
	var cowl_h: float = float(s["cowl"])
	var belt_h: float = float(s["belt"])
	var deck_h: float = float(s["deck"])
	var tf: float = float(s["taper_f"])
	var trr: float = float(s["taper_r"])

	# --- Lower body: side profile with wheel arches ---
	var arch_r: float = tire_r + 0.06
	var lower := PackedVector2Array()
	lower.append(Vector2(zf - 0.10, 0.20))
	lower.append(Vector2(zf - 0.01, 0.32))
	lower.append(Vector2(zf + 0.01, 0.48))
	lower.append(Vector2(zf - 0.05, nose_h - 0.03))
	lower.append(Vector2(zf - 0.28, nose_h + 0.05))
	lower.append(Vector2(lerpf(zf, cowl_z, 0.6), lerpf(nose_h + 0.05, cowl_h, 0.75)))
	lower.append(Vector2(cowl_z, cowl_h))
	lower.append(Vector2(deck_z, belt_h))
	lower.append(Vector2(deck_z - 0.12, deck_h))
	lower.append(Vector2(zr + 0.07, deck_h + (0.03 if str(s["spoiler"]) == "duck" else -0.01)))
	lower.append(Vector2(zr, deck_h - 0.12))
	lower.append(Vector2(zr - 0.01, 0.48))
	lower.append(Vector2(zr + 0.05, 0.24))
	# Keep the upper outline clear of the wheel arches (a low nose / short hood could dip into
	# the arch, the outline then crossed itself and the whole side panel was not drawn)
	var n_top: int = lower.size()
	for k in range(1, n_top - 1):
		var p: Vector2 = lower[k]
		for zc in [-wb * 0.5, wb * 0.5]:
			var dz: float = p.x - zc
			if absf(dz) < arch_r + 0.05:
				var arch_top: float = tire_r + sqrt(maxf((arch_r + 0.05) * (arch_r + 0.05) - dz * dz, 0.0))
				if p.y < arch_top + 0.04:
					lower[k] = Vector2(p.x, arch_top + 0.04)
	_append_arch(lower, -wb * 0.5, tire_r, arch_r)
	_append_arch(lower, wb * 0.5, tire_r, arch_r)
	taper = func(z: float, y: float) -> float:
		var t: float = 1.0 - tf * smoothstep(zf - 0.65, zf + 0.02, z) - trr * smoothstep(zr + 0.5, zr - 0.02, z)
		t *= 1.0 - 0.045 * smoothstep(0.55, belt_h, y)
		return hw * t
	# bottom & wheel-arch skin (every edge after the rear bumper) is black, like a real underbody
	var under_edges: Array = []
	for k in range(n_top - 1, lower.size()):
		under_edges.append(k)
	_extrude(lower, taper, paint, black, under_edges)

	# --- Glasshouse (slightly arched roof) ---
	var tumble: float = float(s["tumble"])
	var gh := PackedVector2Array([
		Vector2(cowl_z - 0.02, cowl_h),
		Vector2(ws_top_z, H - 0.05),
		Vector2(ws_top_z - 0.15, H - 0.01),
		Vector2(lerpf(ws_top_z, roof_rear_z, 0.5), H),
		Vector2(roof_rear_z + 0.12, H - 0.015),
		Vector2(roof_rear_z, H - 0.06),
		Vector2(deck_z + 0.02, belt_h),
	])
	var gh_taper := func(z: float, y: float) -> float:
		var k: float = clampf((y - cowl_h) / maxf(H - cowl_h, 0.1), 0.0, 1.0)
		return taper.call(z, belt_h) * lerpf(0.95, tumble, k)
	_extrude(gh, gh_taper, paint, glass, [0, 5])
	var win_polys: Array = Geometry2D.offset_polygon(gh, -0.06)
	for side in [-1.0, 1.0]:
		for poly in win_polys:
			_side_panel(poly, gh_taper, side, 0.006, glass)
		# B-pillar (black)
		var b_z: float = lerpf(ws_top_z, roof_rear_z, 0.5 if str(b.get("style")) != "chiron" else 0.95)
		var b_y: float = (belt_h + H) * 0.5
		_box(Vector3(side * (gh_taper.call(b_z, b_y) + 0.009), g + b_y, b_z), Vector3(0.02, H - belt_h - 0.08, 0.10), black)

	# --- Common details: mirrors, door handles, sills, underbody, plates ---
	for side in [-1.0, 1.0]:
		_box(Vector3(side * (hw + 0.08), g + cowl_h + 0.12, cowl_z - 0.25), Vector3(0.15, 0.10, 0.10), paint)
		_box(Vector3(side * (hw + 0.025), g + cowl_h + 0.10, cowl_z - 0.25), Vector3(0.05, 0.05, 0.05), black)
		_box(Vector3(side * (taper.call(cowl_z - 0.9, 0.8) + 0.008), g + belt_h - 0.14, cowl_z - 0.95), Vector3(0.015, 0.03, 0.15), chrome)
		_box(Vector3(side * (hw - 0.02), g + 0.24, 0.0), Vector3(0.04, 0.06, wb - arch_r * 2.0 - 0.05), black)
	_box(Vector3(0, g + 0.175, (zf + zr) * 0.5), Vector3(hw * 1.9, 0.03, L - 0.3), black) # below the floor skin (they used to z-fight)
	_box(Vector3(0, g + 0.30, zr + 0.03), Vector3(taper.call(zr + 0.1, 0.4) * 1.8, 0.08, 0.06), black)

	# --- The model's own face & tail ---
	match str(b.get("style", "accent")):
		"accent": _details_accent(nose_h, deck_h)
		"egea": _details_egea(nose_h, deck_h)
		"sahin": _details_sahin(nose_h, deck_h)
		"civic": _details_civic(nose_h, deck_h)
		"megane": _details_megane(nose_h, deck_h)
		"gtr": _details_gtr(nose_h, deck_h)
		"supra": _details_supra(nose_h, deck_h)
		"challenger": _details_challenger(nose_h, deck_h)
		"chiron": _details_chiron(nose_h, deck_h)
	if exhausts.is_empty(): # models without their own tips: one pipe under the left of the bumper
		_pipe(Vector3(-hw * 0.55, g + 0.26, zr - 0.02), 0.032)
	_spoiler(str(s["spoiler"]), deck_h)
	return _brake_mats

# ------------------------------------------------------------------ materials
func _make_materials(color: Color) -> void:
	paint = StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.55
	paint.roughness = 0.26
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.8
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass = StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.07, 0.10)
	glass.metallic = 0.7
	glass.roughness = 0.06
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	black = StandardMaterial3D.new()
	black.albedo_color = Color(0.035, 0.035, 0.04)
	black.roughness = 0.55
	chrome = StandardMaterial3D.new()
	chrome.albedo_color = Color(0.86, 0.87, 0.9)
	chrome.metallic = 0.95
	chrome.roughness = 0.1
	head = _glow(Color(0.95, 0.97, 1.0), 1.6)
	drl = _glow(Color(0.9, 0.95, 1.0), 4.0)
	amber = _glow(Color(1.0, 0.55, 0.1), 1.2)
	tail = StandardMaterial3D.new()
	tail.albedo_color = Color(0.55, 0.02, 0.02)
	tail.emission_enabled = true
	tail.emission = Color(1.0, 0.04, 0.03)
	tail.emission_energy_multiplier = 1.2
	_brake_mats.append(tail)
	lens = StandardMaterial3D.new()
	lens.albedo_color = Color(0.15, 0.16, 0.18)
	lens.metallic = 0.6
	lens.roughness = 0.1
	plate = StandardMaterial3D.new()
	plate.albedo_color = Color(0.92, 0.92, 0.9)

func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

# Front / rear helpers: width at the face, and positions on it
func _fw(y: float) -> float:
	return taper.call(zf - 0.08, y)
func _rw(y: float) -> float:
	return taper.call(zr + 0.08, y)
func _front(x: float, y: float, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, inset: float = 0.0) -> void:
	_box(Vector3(x, g + y, zf + 0.012 - inset), size, mat, rot)
func _rear(x: float, y: float, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, inset: float = 0.0) -> void:
	_box(Vector3(x, g + y, zr - 0.006 + inset), size, mat, rot)
func _plates(front_y: float, rear_y: float) -> void:
	_front(0, front_y, Vector3(0.52, 0.11, 0.01), plate)
	_rear(0, rear_y, Vector3(0.52, 0.11, 0.01), plate)

# ------------------------------------------------------------------ per-model details
func _details_accent(nose_h: float, deck_h: float) -> void:
	# hexagonal lower grille + slim chrome upper grille, swept-back headlights, fog lamps
	_hex(Vector3(0, g + 0.40, zf + 0.012), 0.95, 0.30, black)
	_front(0, 0.40, Vector3(0.80, 0.02, 0.02), chrome)
	_front(0, nose_h - 0.12, Vector3(0.62, 0.06, 0.03), chrome, Vector3.ZERO, 0.03)
	var fw: float = _fw(0.6)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * (fw - 0.26), g + nose_h - 0.06, zf - 0.13), Vector3(0.50, 0.11, 0.28), head, Vector3(-8, sd * -28, sd * -6))
		_box(Vector3(sd * (fw - 0.16), g + 0.36, zf - 0.005), Vector3(0.16, 0.08, 0.04), head)
		# tail light: outer piece on the corner + inner piece on the boot lid
		var rw: float = _rw(deck_h - 0.1)
		_box(Vector3(sd * (rw - 0.16), g + deck_h - 0.13, zr + 0.05), Vector3(0.36, 0.15, 0.12), tail, Vector3(0, sd * 22, 0))
		_rear(sd * (rw - 0.42), deck_h - 0.10, Vector3(0.22, 0.09, 0.03), tail)
		_box(Vector3(sd * (taper.call(0.0, 0.7) + 0.006), g + 0.72, 0.0), Vector3(0.012, 0.025, L * 0.55), lens) # character line
	_rear(0, deck_h - 0.10, Vector3(0.40, 0.03, 0.02), chrome)
	_plates(0.30, deck_h - 0.28)

func _details_egea(nose_h: float, deck_h: float) -> void:
	# wide chrome-bar grille between large rectangular headlights, trapezoid lower grille
	var fw: float = _fw(0.6)
	for k in range(3):
		_front(0, nose_h - 0.09 - k * 0.045, Vector3(0.78, 0.022, 0.03), chrome, Vector3.ZERO, 0.02)
	_front(0, 0.38, Vector3(0.95, 0.20, 0.03), black)
	_front(0, 0.47, Vector3(0.95, 0.02, 0.035), chrome)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * (fw - 0.25), g + nose_h - 0.09, zf - 0.04), Vector3(0.44, 0.16, 0.10), head, Vector3(-6, sd * -12, 0))
		_box(Vector3(sd * (fw - 0.12), g + 0.33, zf - 0.005), Vector3(0.14, 0.06, 0.04), head)
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.22), deck_h - 0.13, Vector3(0.40, 0.13, 0.05), tail)
	_rear(0, deck_h - 0.13, Vector3(rw_span(0.36), 0.035, 0.03), chrome)
	# chrome window surround line
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * (taper.call((cowl_z + deck_z) * 0.5, float(s["belt"])) + 0.01), g + float(s["belt"]) + 0.005, (cowl_z + deck_z) * 0.5), Vector3(0.012, 0.02, cowl_z - deck_z), chrome)
	_plates(0.30, deck_h - 0.30)

func _details_sahin(nose_h: float, deck_h: float) -> void:
	# black grille band between big rectangular headlights, amber corner indicators, thick black
	# bumpers, wide red + amber tail-light blocks on a flat boot panel
	var fw: float = _fw(nose_h - 0.12)
	_front(0, nose_h - 0.13, Vector3((fw - 0.38) * 2.0, 0.17, 0.03), black) # grille between the headlights
	for k in range(3):
		_front(0, nose_h - 0.08 - k * 0.05, Vector3(0.62, 0.014, 0.035), chrome, Vector3.ZERO, -0.01)
	_front(0, 0.40, Vector3(fw * 2.0 + 0.04, 0.13, 0.07), black) # bumper
	_rear(0, 0.40, Vector3(_rw(0.4) * 2.0 + 0.04, 0.13, 0.07), black)
	var rw: float = _rw(deck_h - 0.15)
	for sd in [-1.0, 1.0]:
		# lamps sit side by side with small gaps: overlapping coplanar boxes flicker (z-fighting)
		_front(sd * (fw - 0.22), nose_h - 0.13, Vector3(0.31, 0.15, 0.04), head)
		_front(sd * (fw - 0.035), nose_h - 0.13, Vector3(0.05, 0.13, 0.04), amber)
		_rear(sd * (rw - 0.27), deck_h - 0.17, Vector3(0.35, 0.17, 0.04), tail)
		_rear(sd * (rw - 0.045), deck_h - 0.17, Vector3(0.08, 0.17, 0.04), amber)
	_box(Vector3(0, g + 0.40, zf + 0.05), Vector3(0.52, 0.11, 0.01), plate) # front plate on the bumper
	_rear(0, deck_h - 0.20, Vector3(0.52, 0.11, 0.01), plate)

func _details_civic(nose_h: float, deck_h: float) -> void:
	# thin sharp headlights joined by a thick chrome "wing" bar, big black honeycomb grille and
	# corner intakes, boomerang (C) tail lights
	var fw: float = _fw(0.55)
	_front(0, nose_h - 0.09, Vector3(fw * 1.25, 0.05, 0.04), chrome, Vector3.ZERO, 0.03)
	_front(0, 0.38, Vector3(0.80, 0.22, 0.03), black)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * (fw - 0.25), g + nose_h - 0.06, zf - 0.12), Vector3(0.55, 0.07, 0.26), head, Vector3(-10, sd * -24, sd * -4))
		_box(Vector3(sd * (fw - 0.10), g + 0.34, zf - 0.03), Vector3(0.24, 0.20, 0.05), black, Vector3(0, 0, sd * 25))
		var rw: float = _rw(deck_h - 0.1)
		# boomerang: horizontal arm on the boot + vertical arm down the corner
		_rear(sd * (rw - 0.30), deck_h - 0.09, Vector3(0.48, 0.06, 0.04), tail)
		_box(Vector3(sd * (rw - 0.06), g + deck_h - 0.22, zr + 0.06), Vector3(0.10, 0.26, 0.10), tail, Vector3(0, sd * 25, 0))
	_rear(0, 0.32, Vector3(_rw(0.3) * 1.6, 0.10, 0.04), black) # diffuser
	for sd in [-1.0, 1.0]:
		_pipe(Vector3(sd * hw * 0.6, g + 0.24, zr - 0.02), 0.04) # 1.5 Turbo: twin tips
	_plates(0.28, deck_h - 0.30)

func _details_megane(nose_h: float, deck_h: float) -> void:
	# C-shaped LED daytime lights around the headlights, grille with chrome bar and diamond logo,
	# slim horizontal tail lights joined by a chrome strip
	var fw: float = _fw(0.6)
	_front(0, nose_h - 0.12, Vector3(0.70, 0.13, 0.03), black, Vector3.ZERO, 0.02)
	_front(0, nose_h - 0.08, Vector3(0.74, 0.02, 0.035), chrome, Vector3.ZERO, 0.02)
	_front(0, nose_h - 0.12, Vector3(0.10, 0.10, 0.04), chrome, Vector3(0, 0, 45), 0.0)
	_front(0, 0.38, Vector3(0.90, 0.18, 0.03), black)
	for sd in [-1.0, 1.0]:
		var hx: float = sd * (fw - 0.24)
		_box(Vector3(hx, g + nose_h - 0.08, zf - 0.08), Vector3(0.40, 0.11, 0.16), head, Vector3(-8, sd * -16, 0))
		# the "C": a vertical stroke under the lamp plus a hook along its lower edge
		_box(Vector3(sd * (fw - 0.05), g + 0.42, zf - 0.03), Vector3(0.03, 0.22, 0.04), drl)
		_box(Vector3(sd * (fw - 0.14), g + 0.32, zf - 0.01), Vector3(0.18, 0.03, 0.04), drl)
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.28), deck_h - 0.11, Vector3(0.52, 0.07, 0.04), tail)
	_rear(0, deck_h - 0.11, Vector3(rw_span(0.5), 0.025, 0.03), chrome)
	_plates(0.28, deck_h - 0.30)

func _details_gtr(nose_h: float, deck_h: float) -> void:
	# big trapezoid grille, angular headlights, quad ROUND tail lights, quad exhausts, diffuser
	var fw: float = _fw(0.55)
	_front(0, 0.40, Vector3(0.80, 0.26, 0.03), black)
	_front(0, 0.53, Vector3(0.70, 0.02, 0.035), chrome)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * (fw - 0.25), g + nose_h - 0.05, zf - 0.14), Vector3(0.50, 0.10, 0.30), head, Vector3(-12, sd * -22, 0))
		_box(Vector3(sd * (fw - 0.12), g + 0.30, zf - 0.02), Vector3(0.22, 0.14, 0.04), black)
		var rw: float = _rw(deck_h - 0.1)
		for k in range(2):
			_ring(Vector3(sd * (rw - 0.18 - k * 0.27), g + deck_h - 0.16, zr - 0.01), 0.10, tail)
		_cyl_back(Vector3(sd * (0.35 + 0.0), g + 0.27, zr - 0.02), 0.05, chrome)
		_cyl_back(Vector3(sd * 0.47, g + 0.27, zr - 0.02), 0.05, chrome)
	_rear(0, 0.30, Vector3(_rw(0.3) * 1.5, 0.08, 0.05), black)
	_plates(0.33, deck_h - 0.34)

func _details_supra(nose_h: float, deck_h: float) -> void:
	# low round nose, slim headlights, small mouth, round tail lights in a dark lens
	var fw: float = _fw(0.5)
	_front(0, 0.30, Vector3(0.60, 0.10, 0.03), black)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * (fw - 0.25), g + nose_h - 0.03, zf - 0.16), Vector3(0.46, 0.08, 0.30), head, Vector3(-14, sd * -20, 0))
		_box(Vector3(sd * (fw - 0.12), g + 0.30, zf - 0.02), Vector3(0.16, 0.06, 0.04), amber)
	var rw2: float = _rw(deck_h - 0.1)
	_rear(0, deck_h - 0.17, Vector3(rw2 * 1.85, 0.20, 0.03), lens)
	for sd in [-1.0, 1.0]:
		for k in range(2):
			_ring(Vector3(sd * (rw2 - 0.20 - k * 0.28), g + deck_h - 0.17, zr - 0.02), 0.085, tail)
		_cyl_back(Vector3(sd * 0.45, g + 0.27, zr - 0.02), 0.055, chrome)
	_plates(0.27, deck_h - 0.36)

func _details_challenger(nose_h: float, deck_h: float) -> void:
	# full-width black grille with quad round headlights in it, power-bulge hood, full-width
	# rectangular tail-light bar
	var fw: float = _fw(0.7)
	_front(0, nose_h - 0.15, Vector3(fw * 1.9, 0.24, 0.03), black)
	for sd in [-1.0, 1.0]:
		for k in range(2):
			_ring(Vector3(sd * (fw - 0.16 - k * 0.24), g + nose_h - 0.15, zf + 0.02), 0.085, head)
		_box(Vector3(sd * (fw - 0.1), g + 0.36, zf - 0.005), Vector3(0.18, 0.06, 0.04), amber)
		_cyl_back(Vector3(sd * 0.55, g + 0.26, zr - 0.02), 0.06, chrome)
	_front(0, 0.38, Vector3(1.0, 0.12, 0.03), black)
	_box(Vector3(0, g + float(s["cowl"]) - 0.02, (zf + cowl_z) * 0.5 - 0.15), Vector3(0.55, 0.06, L * float(s["hood"]) * 0.7), paint) # hood bulge
	_rear(0, deck_h - 0.14, Vector3(_rw(deck_h - 0.1) * 1.9, 0.14, 0.04), tail)
	_rear(0, deck_h - 0.14, Vector3(0.40, 0.08, 0.05), black)
	_plates(0.30, deck_h - 0.34)

func _details_chiron(nose_h: float, deck_h: float) -> void:
	# horseshoe grille, quad-LED headlight strips, side "C" line, full-width rear light bar,
	# huge centre exhaust & diffuser
	var fw: float = _fw(0.45)
	_horseshoe(Vector3(0, g + 0.36, zf + 0.012))
	for sd in [-1.0, 1.0]:
		for k in range(4):
			_box(Vector3(sd * (fw - 0.16 - k * 0.07), g + nose_h - 0.04, zf - 0.15 - k * 0.02), Vector3(0.05, 0.04, 0.18), drl, Vector3(-10, 0, 0))
		_box(Vector3(sd * (fw - 0.12), g + 0.28, zf - 0.03), Vector3(0.40, 0.14, 0.04), black)
		# the signature C-line on the side
		var cx: float = sd * (taper.call(cowl_z - 0.8, 0.6) + 0.01)
		_box(Vector3(cx, g + 0.62, cowl_z - 0.55), Vector3(0.02, 0.06, 1.05), chrome)
		_box(Vector3(cx, g + 0.42, cowl_z - 1.05), Vector3(0.02, 0.42, 0.06), chrome)
	_rear(0, deck_h - 0.12, Vector3(_rw(deck_h) * 1.92, 0.05, 0.04), tail)
	_rear(0, 0.34, Vector3(_rw(0.3) * 1.7, 0.18, 0.06), black)
	_box(Vector3(0, g + 0.50, zr + 0.02), Vector3(0.80, 0.14, 0.05), black)
	_pipe(Vector3(0, g + 0.50, zr - 0.01), 0.07) # the big centre pipe
	_plates(0.24, 0.62)

func rw_span(margin: float) -> float:
	return maxf(_rw(0.8) * 2.0 - margin * 2.0, 0.2)

func _spoiler(kind: String, deck_h: float) -> void:
	var w: float = _rw(deck_h) * 1.8
	match kind:
		"lip":
			_box(Vector3(0, g + deck_h + 0.015, zr + 0.10), Vector3(w * 0.9, 0.03, 0.10), paint)
		"duck":
			_box(Vector3(0, g + deck_h + 0.04, zr + 0.09), Vector3(w * 0.95, 0.04, 0.12), paint, Vector3(-8, 0, 0))
		"wing":
			for sd in [-1.0, 1.0]:
				_box(Vector3(sd * w * 0.32, g + deck_h + 0.09, zr + 0.22), Vector3(0.05, 0.18, 0.10), paint)
			_box(Vector3(0, g + deck_h + 0.19, zr + 0.20), Vector3(w * 0.85, 0.04, 0.26), paint, Vector3(-5, 0, 0))
		"hoop":
			for sd in [-1.0, 1.0]:
				_box(Vector3(sd * w * 0.44, g + deck_h + 0.16, zr + 0.25), Vector3(0.07, 0.32, 0.16), paint, Vector3(-12, 0, 0))
			_box(Vector3(0, g + deck_h + 0.33, zr + 0.19), Vector3(w * 0.95, 0.05, 0.24), paint, Vector3(-6, 0, 0))
		"flat":
			_box(Vector3(0, g + deck_h + 0.02, zr + 0.35), Vector3(w * 0.9, 0.025, 0.40), black)

# ------------------------------------------------------------------ shape helpers
func _append_arch(poly: PackedVector2Array, zc: float, yc: float, r: float) -> void:
	poly.append(Vector2(zc - r, 0.20))
	for k in range(13):
		var a: float = PI - PI * float(k) / 12.0
		poly.append(Vector2(zc + cos(a) * r, yc + sin(a) * r))
	poly.append(Vector2(zc + r, 0.20))

# Extrude a side profile (z, y) across the car; edges in glass_edges get glass_mat.
func _extrude(poly: PackedVector2Array, half_width: Callable, side_mat: Material, glass_mat: Material, glass_edges: Array) -> void:
	for side in [-1.0, 1.0]:
		_side_panel(poly, half_width, side, 0.0, side_mat)
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
		var st: SurfaceTool = st_b if glass_edges.has(i) else st_a
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
	st_a.generate_normals()
	_mesh(st_a.commit(), side_mat)
	if not glass_edges.is_empty():
		st_b.generate_normals()
		_mesh(st_b.commit(), glass_mat)

func _side_panel(poly: PackedVector2Array, half_width: Callable, side: float, push: float, mat: Material) -> void:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var out_n := Vector3(side, 0.0, 0.0)
	st.set_normal(out_n)
	for t in range(0, idx.size(), 3):
		var v: Array[Vector3] = []
		for k in range(3):
			var p: Vector2 = poly[idx[t + k]]
			v.append(Vector3(side * (half_width.call(p.x, p.y) + push), g + p.y, p.x))
		if (v[1] - v[0]).cross(v[2] - v[0]).dot(out_n) > 0.0:
			v = [v[0], v[2], v[1]]
		for vert in v:
			st.add_vertex(vert)
	_mesh(st.commit(), mat)

# Flat hexagon on the front face (Hyundai-style grille)
func _hex(c: Vector3, w: float, h: float, mat: Material) -> void:
	var pts: Array[Vector2] = [Vector2(-w * 0.5, 0), Vector2(-w * 0.38, h * 0.5), Vector2(w * 0.38, h * 0.5), Vector2(w * 0.5, 0), Vector2(w * 0.38, -h * 0.5), Vector2(-w * 0.38, -h * 0.5)]
	_front_poly(c, pts, mat)

# Bugatti-style horseshoe grille (rounded, narrow at the bottom)
func _horseshoe(c: Vector3) -> void:
	var pts: Array[Vector2] = []
	for k in range(13):
		var a: float = PI * float(k) / 12.0
		pts.append(Vector2(cos(a) * 0.22, sin(a) * 0.14 + 0.04))
	pts.append(Vector2(-0.14, -0.14))
	pts.append(Vector2(0.14, -0.14))
	_front_poly(c, pts, chrome)
	_front_poly(c + Vector3(0, 0, 0.004), pts.map(func(p: Vector2) -> Vector2: return p * 0.82), black)

func _front_poly(c: Vector3, pts: Array, mat: Material) -> void:
	var poly := PackedVector2Array(pts)
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	for t in range(0, idx.size(), 3):
		var v: Array[Vector3] = []
		for k in range(3):
			var p: Vector2 = poly[idx[t + k]]
			v.append(c + Vector3(p.x, p.y, 0.0))
		if (v[1] - v[0]).cross(v[2] - v[0]).dot(Vector3(0, 0, 1)) > 0.0:
			v = [v[0], v[2], v[1]]
		for vert in v:
			st.add_vertex(vert)
	_mesh(st.commit(), mat)

# Round lamp facing backwards (-Z): a short cylinder
func _ring(c: Vector3, r: float, mat: Material) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.05
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = c
	mi.rotation_degrees = Vector3(90, 0, 0)
	_parent.add_child(mi)

func _cyl_back(c: Vector3, r: float, _mat: Material) -> void:
	_pipe(c, r)

# Exhaust tip pointing backwards: an open chrome tube (seen from inside too) with a dark, recessed
# inside, so it reads as a real pipe instead of a solid chrome disc.
func _pipe(c: Vector3, r: float) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = r
	tube.bottom_radius = r
	tube.height = 0.16
	tube.radial_segments = 20
	tube.cap_top = false
	tube.cap_bottom = false
	var pipe_mat: StandardMaterial3D = chrome.duplicate()
	pipe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = tube
	mi.material_override = pipe_mat
	mi.position = c + Vector3(0, 0, 0.06) # sticks out ~2 cm, the rest hides in the bumper
	mi.rotation_degrees = Vector3(90, 0, 0)
	_parent.add_child(mi)
	var soot := CylinderMesh.new()
	soot.top_radius = r * 0.9
	soot.bottom_radius = r * 0.9
	soot.height = 0.01
	soot.radial_segments = 20
	var inner := MeshInstance3D.new()
	inner.mesh = soot
	inner.material_override = black
	inner.position = c + Vector3(0, 0, 0.05)
	inner.rotation_degrees = Vector3(90, 0, 0)
	_parent.add_child(inner)
	exhausts.append(c)

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
