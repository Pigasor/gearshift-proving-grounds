extends CanvasLayer
# Car picker (the car button on the top bar): every car as a card, filtered by class (left) and by a
# search box (type part of the name, Enter takes the first match). The game pauses while it is open.
# Car names are never translated (same in every language).

var ui: Node # UIManager: _switch_car(), CAR_GROUPS
var vehicle: Node

const ACCENT := Color(0.2, 0.65, 1.0)
const CLASS_COLORS: Dictionary = {
	"Sedan": Color(0.55, 0.7, 0.85), "Classic": Color(0.85, 0.6, 0.3), "US Classic": Color(0.9, 0.45, 0.35),
	"Sport": Color(0.95, 0.3, 0.3), "Muscle": Color(0.95, 0.55, 0.15), "Electric": Color(0.3, 0.9, 0.6),
	"Luxury": Color(0.8, 0.7, 0.95), "Stock Car": Color(1.0, 0.8, 0.2), "Hyper": Color(0.85, 0.3, 0.95),
	"Off-Road": Color(0.55, 0.75, 0.3), "Monster": Color(0.6, 0.85, 0.25), "Tractor": Color(0.4, 0.75, 0.35),
}

var _root: Control
var _grid: GridContainer
var _search: LineEdit
var _classes: VBoxContainer
var _count: Label
var _scroll: ScrollContainer
var _class: String = "" # "" = every class
var _first_card: Button = null

func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("car_picker")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.07, 0.1, 0.97), Color(0.2, 0.4, 0.6), 12, 16))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.06
	panel.anchor_right = 0.94
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.93
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	# header: title, search, count, close
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var title := Label.new()
	title.text = "🚗  ARAÇ SEÇ"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	head.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = "🔍  Ara (ör. porshe, v8, 4x4)..."
	_search.custom_minimum_size = Vector2(380, 40)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.add_theme_font_size_override("font_size", 18)
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _refresh())
	_search.text_submitted.connect(func(_t: String) -> void:
		if _first_card:
			_first_card.pressed.emit())
	head.add_child(_search)
	_count = Label.new()
	_count.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	head.add_child(_count)
	var close_btn := Button.new()
	close_btn.text = "✕  Kapat (ESC)"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	# body: class list | cards
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	var cs := ScrollContainer.new()
	cs.custom_minimum_size = Vector2(210, 0)
	cs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(cs)
	_classes = VBoxContainer.new()
	_classes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_classes.add_theme_constant_override("separation", 4)
	cs.add_child(_classes)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)
	_scroll.resized.connect(_fit_columns)

func is_open() -> bool:
	return _root.visible

func open() -> void:
	_class = ""
	_search.text = ""
	_build_classes()
	_refresh()
	_root.visible = true
	_fit_columns()
	get_tree().paused = true
	_search.grab_focus.call_deferred()

func close() -> void:
	_root.visible = false
	get_tree().paused = false
	get_viewport().gui_release_focus()

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()

func _fit_columns() -> void:
	if _scroll:
		_grid.columns = clampi(int(_scroll.size.x / 290.0), 2, 5)

func _build_classes() -> void:
	for c in _classes.get_children():
		c.queue_free()
	var counts: Dictionary = {}
	for i in range(CarDatabase.count()):
		var k: String = CarDatabase.car(i)["class"]
		counts[k] = int(counts.get(k, 0)) + 1
	_class_button("", tr("Tümü"), CarDatabase.count(), ACCENT)
	for grp in ui.CAR_GROUPS:
		if counts.has(grp[0]):
			_class_button(grp[0], grp[1], counts[grp[0]], CLASS_COLORS.get(grp[0], ACCENT))

func _class_button(key: String, title: String, n: int, col: Color) -> void:
	var b := Button.new()
	b.text = "%s  (%d)" % [title, n]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_pressed = key == _class
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _sb(Color(0.09, 0.11, 0.15), Color(0, 0, 0, 0), 7, 10, col))
	b.add_theme_stylebox_override("hover", _sb(Color(0.14, 0.18, 0.25), col, 7, 10, col))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.12, 0.24, 0.38), col, 7, 10, col))
	b.add_theme_stylebox_override("hover_pressed", _sb(Color(0.14, 0.28, 0.44), col, 7, 10, col))
	b.pressed.connect(func() -> void:
		_class = key
		for c in _classes.get_children():
			(c as Button).button_pressed = c == b
		_refresh())
	_classes.add_child(b)

func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_first_card = null
	var q: String = _search.text.strip_edges().to_lower()
	var cur: int = int(vehicle.current_vehicle_type) if vehicle else -1
	var shown: int = 0
	for grp in ui.CAR_GROUPS: # cards in class order
		for i in range(CarDatabase.count()):
			var c: Dictionary = CarDatabase.car(i)
			if c["class"] != grp[0] or (_class != "" and c["class"] != _class):
				continue
			var en: Dictionary = CarDatabase.engine(i, 0)
			var info: String = "%s  ·  %d HP  ·  %s" % [grp[1], int(en.get("hp", 0)), _drive(c, en)]
			if q != "" and not (str(c["name"]) + " " + info + " " + str(en.get("label", ""))).to_lower().contains(q):
				continue
			var card := _card(i, c["name"], info, str(en.get("label", "")), CLASS_COLORS.get(c["class"], ACCENT), i == cur)
			if _first_card == null:
				_first_card = card
			shown += 1
	_count.text = tr("%d araç") % shown
	_scroll.scroll_vertical = 0

func _drive(c: Dictionary, en: Dictionary) -> String:
	if c.has("legacy"): # the six original cars set their drivetrain in the car itself
		return ["AWD", "RWD", "AWD", "AWD", "RWD", "AWD"][int(c["legacy"])]
	return str(en.get("drive", (c.get("body", {}) as Dictionary).get("drive", "FWD")))

func _card(idx: int, car_name: String, info: String, engine_label: String, col: Color, current: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(270, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	var border: Color = Color(1.0, 0.82, 0.2) if current else Color(0.18, 0.24, 0.32)
	b.add_theme_stylebox_override("normal", _sb(Color(0.09, 0.11, 0.15), border, 9, 12, col))
	b.add_theme_stylebox_override("hover", _sb(Color(0.13, 0.17, 0.24), col, 9, 12, col))
	b.add_theme_stylebox_override("focus", _sb(Color(0.13, 0.17, 0.24), col, 9, 12, col))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.1, 0.24, 0.38), ACCENT, 9, 12, col))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	v.offset_left = 18
	v.offset_top = 10
	v.offset_right = -10
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var name_l := Label.new()
	name_l.text = car_name
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED # names are the same in every language
	name_l.add_theme_font_size_override("font_size", 19)
	name_l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3) if current else Color(0.95, 0.97, 1.0))
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var info_l := Label.new()
	info_l.text = info
	info_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info_l.add_theme_font_size_override("font_size", 14)
	info_l.add_theme_color_override("font_color", col.lerp(Color(1, 1, 1), 0.35))
	info_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(info_l)
	var en_l := Label.new()
	en_l.text = engine_label.split(" - ")[0] + ("   ✓ " + tr("Şu an") if current else "")
	en_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	en_l.add_theme_font_size_override("font_size", 13)
	en_l.add_theme_color_override("font_color", Color(0.6, 0.66, 0.74))
	en_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	en_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(en_l)
	b.pressed.connect(func() -> void:
		close()
		ui._switch_car(idx))
	_grid.add_child(b)
	return b

func _sb(bg: Color, border: Color, radius: int, margin: int = 10, stripe: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border if border.a > 0.0 else stripe
	sb.set_border_width_all(2 if border.a > 0.0 else 0)
	if stripe.a > 0.0:
		sb.border_width_left = 6 # class colour stripe on the left edge
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	return sb
