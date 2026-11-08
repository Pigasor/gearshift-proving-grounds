extends Control
# Round mini map in the bottom-left corner: a second, low-resolution orthographic camera looks down
# on the car (heading-up, so "up" on the map is always where the car points).
# The "minimap" action (default N) switches between the close view and a wide view of the area.

var vehicle: Node3D

const MAP_SIZE := [190.0, 340.0] # on-screen diameter (close, wide)
const SPAN := [240.0, 1300.0] # metres shown across (close, wide)

var _wide: bool = false
var _vp: SubViewport
var _cam: Camera3D
var _tex: TextureRect
var _overlay: Control
var _span: float = 240.0

const CIRCLE_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, vec3(0.07, 0.09, 0.13), smoothstep(0.91, 0.94, r));
	c.a = 0.92 * (1.0 - smoothstep(0.985, 1.0, r));
	COLOR = c;
}
"""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vp = SubViewport.new()
	_vp.size = Vector2i(256, 256)
	_vp.positional_shadow_atlas_size = 0
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 1.0
	_cam.far = 1500.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.22, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.7
	_cam.environment = env
	_vp.add_child(_cam)

	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CIRCLE_SHADER
	mat.shader = sh
	_tex.material = mat
	add_child(_tex)

	# Car arrow + labels drawn on top of the map image
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	var gs0: Node = get_node_or_null("/root/GameSettings")
	if gs0:
		gs0.input_device_changed.connect(func(_d: String): _overlay.queue_redraw()) # label shows that device's button
	_apply_size()

func _apply_size() -> void:
	var d: float = MAP_SIZE[1 if _wide else 0]
	# Bottom-left corner, just above the key help line
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16.0
	offset_right = 16.0 + d
	offset_top = -34.0 - d
	offset_bottom = -34.0
	size = Vector2(d, d)
	_tex.position = Vector2.ZERO
	_tex.size = size
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	_vp.size = Vector2i(384, 384) if _wide else Vector2i(256, 256)
	_overlay.queue_redraw()

# Gamepad: right stick click (R3) switches close / wide view
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_STICK:
		_wide = not _wide
		_apply_size()

func _process(delta: float) -> void:
	if vehicle == null:
		return
	if Input.is_action_just_pressed("minimap"):
		_wide = not _wide
		_apply_size()

	# Close view zooms out a little with speed so you can see what's coming
	var speed_kmh: float = float(vehicle.get("current_speed_kmh"))
	var target_span: float = SPAN[1] if _wide else SPAN[0] + clampf(speed_kmh, 0.0, 300.0) * 0.6
	_span = lerpf(_span, target_span, clampf(delta * 4.0, 0.0, 1.0))
	_cam.size = _span

	# Heading-up camera straight above the car
	var fwd: Vector3 = vehicle.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var cam_y: Vector3 = fwd # top of the map = where the car points
	var cam_z: Vector3 = Vector3.UP # camera looks down (-Z)
	var cam_x: Vector3 = cam_y.cross(cam_z)
	_cam.global_transform = Transform3D(Basis(cam_x, cam_y, cam_z), vehicle.global_position + Vector3.UP * 600.0)

func _draw_overlay() -> void:
	var c: Vector2 = size * 0.5
	var s: float = 7.0 if not _wide else 8.0
	var pts := PackedVector2Array([c + Vector2(0, -s * 1.5), c + Vector2(s, s), c + Vector2(0, s * 0.45), c + Vector2(-s, s)])
	_overlay.draw_colored_polygon(pts, Color(1.0, 0.82, 0.15))
	pts.append(pts[0])
	_overlay.draw_polyline(pts, Color(0, 0, 0, 0.8), 1.5, true)
	var font: Font = get_theme_default_font()
	var key: String = "N"
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs:
		var keys: Array = gs.bindings.get("minimap", [])
		key = OS.get_keycode_string(keys[0]) if keys.size() > 0 else "-"
		if gs.input_device == "gamepad":
			key = "R3" # right stick click
	var label: String = key + tr(": Geniş" if not _wide else ": Yakın")
	_overlay.draw_string(font, Vector2(c.x - 26, size.y - 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.9, 1.0, 0.85))
