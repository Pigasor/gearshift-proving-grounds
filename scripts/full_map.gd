extends CanvasLayer
# Big map (M): the whole proving ground seen from above, north up. The game pauses while it is
# open (nothing happens to the car while you look around).
#   Double click - teleport the car there (and close the map)
#   Mouse wheel - zoom, right/middle drag - pan, M / ESC - close
# The top-down view is rendered by an orthographic camera in a SubViewport that only exists while
# the map is open, so it costs nothing while driving.

var vehicle: Node3D

const WORLD_SPAN: float = 3000.0 # metres shown across at the widest zoom
const AREAS: Array = [
	["APRON / PADDOCK", Vector2(225, -620)],
	["HANGARLAR", Vector2(235, -1100)],
	["PİST 18", Vector2(0, -1180)],
	["PİST 36", Vector2(0, 1180)],
	["YARIŞ PİSTİ", Vector2(-330, 30)],
	["DRİFT ALANI", Vector2(250, -220)],
	["STUNT PARKI", Vector2(170, 300)],
	["OFF-ROAD", Vector2(540, 420)],
	["TEPE PARKI", Vector2(-800, 0)],
	["OTOYOL HALKASI", Vector2(0, 1330)],
	["SÜSPANSİYON YOLU", Vector2(-75, -110)],
]

var _root: Control
var _map_rect: TextureRect
var _overlay: Control
var _vp: SubViewport
var _cam: Camera3D
var _span: float = WORLD_SPAN
var _center: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _hint: Label

func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("full_map")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_map_rect = TextureRect.new()
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_rect.gui_input.connect(_on_map_input)
	_root.add_child(_map_rect)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_root.add_child(_overlay)
	var title := Label.new()
	title.text = "🗺  HARİTA  —  OYUN DURAKLATILDI"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	title.position = Vector2(24, 16)
	_root.add_child(title)
	_hint = Label.new()
	_hint.text = "Çift tık: oraya ışınlan   ·   Tekerlek: yakınlaştır   ·   Sağ tık sürükle: kaydır   ·   M / ESC: kapat"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 24
	_hint.offset_top = -36
	_root.add_child(_hint)

func is_open() -> bool:
	return _root.visible

func open() -> void:
	if vehicle == null:
		return
	_span = WORLD_SPAN
	_center = Vector2(0, 0)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1400, 1400)
	_vp.positional_shadow_atlas_size = 0
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 1.0
	_cam.far = 2000.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.18, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.8
	_cam.environment = env
	_vp.add_child(_cam)
	_map_rect.texture = _vp.get_texture()
	_update_camera()
	_layout()
	_root.visible = true
	get_tree().paused = true

func close() -> void:
	_root.visible = false
	_map_rect.texture = null
	if _vp:
		_vp.queue_free()
		_vp = null
	get_tree().paused = false
	get_viewport().gui_release_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("full_map", false, true):
		var menu: Node = get_tree().get_first_node_in_group("settings_menu")
		if menu and menu.call("is_open"):
			return
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open() and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _process(_d: float) -> void:
	if is_open():
		_layout()
		_overlay.queue_redraw()

# Square map, as big as the screen allows
func _layout() -> void:
	var vs: Vector2 = _root.get_viewport_rect().size
	var side: float = minf(vs.x - 48.0, vs.y - 110.0)
	_map_rect.position = Vector2((vs.x - side) * 0.5, 60.0)
	_map_rect.size = Vector2(side, side)
	_overlay.position = Vector2.ZERO
	_overlay.size = vs

func _update_camera() -> void:
	_span = clampf(_span, 150.0, WORLD_SPAN)
	var half: float = WORLD_SPAN * 0.5
	var lim: float = half - _span * 0.5
	_center = Vector2(clampf(_center.x, -lim - 200.0, lim + 200.0), clampf(_center.y, -lim - 200.0, lim + 200.0))
	_cam.size = _span
	# north (-Z) up: screen right = +X, screen up = -Z, camera looks straight down
	_cam.global_transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3(_center.x, 900.0, _center.y))

func _world_to_screen(p: Vector2) -> Vector2:
	var uv: Vector2 = (p - _center) / _span + Vector2(0.5, 0.5)
	return _map_rect.position + uv * _map_rect.size

func _screen_to_world(s: Vector2) -> Vector2:
	var uv: Vector2 = (s - _map_rect.position) / _map_rect.size
	return _center + (uv - Vector2(0.5, 0.5)) * _span

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse: Vector2 = _map_rect.position + event.position
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				# zoom around the mouse cursor
				var before: Vector2 = _screen_to_world(mouse)
				_span *= 0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
				_span = clampf(_span, 150.0, WORLD_SPAN)
				var after: Vector2 = _center + ((mouse - _map_rect.position) / _map_rect.size - Vector2(0.5, 0.5)) * _span
				_center += before - after
				_update_camera()
			MOUSE_BUTTON_LEFT:
				if event.double_click: # double click so a stray click never moves the car
					_teleport_to(_screen_to_world(mouse))
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = true
	elif event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_center -= event.relative / _map_rect.size * _span
		_update_camera()

func _teleport_to(w: Vector2) -> void:
	if absf(w.x) > 1480.0 or absf(w.y) > 1480.0:
		return # outside the boundary walls
	var fwd: Vector3 = vehicle.global_transform.basis.z
	var yaw: float = rad_to_deg(atan2(fwd.x, fwd.z))
	vehicle.teleport_to(Vector3(w.x, 0.0, w.y), yaw)
	var cam: Node = vehicle.get_parent().get_node_or_null("CameraController")
	if cam:
		cam.set("_orbit_yaw", deg_to_rad(yaw))
		cam.global_position = vehicle.global_position + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 2.5, -7.0)
	close()

func _draw_overlay() -> void:
	if vehicle == null:
		return
	var font: Font = _root.get_theme_default_font()
	var r := Rect2(_map_rect.position, _map_rect.size)
	_overlay.draw_rect(r, Color(0.3, 0.6, 1.0, 0.8), false, 2.0)
	# area names
	for a in AREAS:
		var sp: Vector2 = _world_to_screen(a[1])
		if r.has_point(sp):
			var size: int = 15
			var area_name: String = tr(a[0])
			var w: float = font.get_string_size(area_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			_overlay.draw_string_outline(font, sp - Vector2(w * 0.5, 0), area_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85))
			_overlay.draw_string(font, sp - Vector2(w * 0.5, 0), area_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1))
	# the car: arrow pointing where it faces
	var cp: Vector2 = _world_to_screen(Vector2(vehicle.global_position.x, vehicle.global_position.z))
	if r.has_point(cp):
		var f3: Vector3 = vehicle.global_transform.basis.z
		var d: Vector2 = Vector2(f3.x, f3.z).normalized()
		var side := Vector2(-d.y, d.x)
		var s: float = 11.0
		var pts := PackedVector2Array([cp + d * s * 1.6, cp - d * s + side * s, cp - d * s * 0.4, cp - d * s - side * s])
		_overlay.draw_colored_polygon(pts, Color(1.0, 0.82, 0.15))
		pts.append(pts[0])
		_overlay.draw_polyline(pts, Color(0, 0, 0), 2.0, true)
	# hovered point: where a click would teleport
	var m: Vector2 = _overlay.get_local_mouse_position()
	if r.has_point(m):
		_overlay.draw_circle(m, 6.0, Color(1, 1, 1, 0.5))
		var wp: Vector2 = _screen_to_world(m)
		_overlay.draw_string(font, m + Vector2(12, -10), tr("çift tık: ışınlan (%.0f, %.0f)") % [wp.x, wp.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	# scale bar (always 100 m / 500 m)
	var bar_m: float = 500.0 if _span > 1200.0 else 100.0
	var bar_px: float = bar_m / _span * r.size.x
	var bp := Vector2(r.position.x + 16, r.end.y - 20)
	_overlay.draw_line(bp, bp + Vector2(bar_px, 0), Color(1, 1, 1), 3.0)
	_overlay.draw_string(font, bp + Vector2(0, -8), "%d m" % int(bar_m), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
	# north arrow
	var na := Vector2(r.end.x - 30, r.position.y + 36)
	_overlay.draw_colored_polygon(PackedVector2Array([na + Vector2(0, -16), na + Vector2(8, 8), na + Vector2(-8, 8)]), Color(1, 1, 1))
	_overlay.draw_string(font, na + Vector2(-6, 26), tr("K"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
