class_name FxTex
extends RefCounted
# Shared particle textures and materials, built once at runtime (no image files needed).

static var _smoke: Texture2D
static var _soft: Texture2D

# Wispy smoke puff: layered noise inside a soft round falloff, so every particle looks like a
# little cloud instead of a flat disc. Particles spin and grow, which hides the repetition.
static func smoke() -> Texture2D:
	if _smoke == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.05
		n.fractal_octaves = 4
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d: float = Vector2(x - 63.5, y - 63.5).length() / 64.0
				var fall: float = clampf(1.0 - d, 0.0, 1.0)
				fall = fall * fall * (3.0 - 2.0 * fall)
				var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
				var a: float = clampf(fall * (0.25 + 1.1 * v) - 0.1, 0.0, 1.0)
				var c: float = 0.8 + 0.2 * v
				img.set_pixel(x, y, Color(c, c, c, a))
		_smoke = ImageTexture.create_from_image(img)
	return _smoke

# Plain soft dot (flames, sparks)
static func soft() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_soft = t
	return _soft

# Billboard smoke quad: soft where it meets the ground (proximity fade)
static func smoke_mesh(size: float) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = smoke()
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # lit by the blue sky it turned bluish grey
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = m
	return q

# Curve 0..1 over the particle's life as a texture (ParticleProcessMaterial wants textures)
static func curve(points: Array, max_value: float = 1.0) -> CurveTexture:
	var c := Curve.new()
	c.max_value = max_value
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t

static func ramp(offsets: Array, colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
