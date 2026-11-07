extends CanvasLayer
# ESC pause & settings menu. Built in code; every change is applied and saved immediately
# through the GameSettings autoload.

var ui_manager: Node

var _root: Control
var _tabs: TabContainer
var _capture_action: String = ""
var _capture_slot: int = -1
var _bind_buttons: Dictionary = {} # "action:slot" -> Button

const COL_ACCENT := Color(0.25, 0.65, 1.0)

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_frame()
	_root.visible = false

# ---------------- Open / close ----------------
func is_open() -> bool:
	return _root.visible

func open() -> void:
	_build_tabs()
	_root.visible = true
	get_tree().paused = true

func close() -> void:
	_cancel_capture()
	_root.visible = false
	get_tree().paused = false
	get_viewport().gui_release_focus() # so Space/Enter don't press menu buttons while driving

func _input(event: InputEvent) -> void:
	# Waiting for a key to bind
	if _capture_action != "" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_cancel_capture()
		else:
			var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			GameSettings.set_binding(_capture_action, _capture_slot, kc)
			_capture_action = ""
			_refresh_bindings()
		get_viewport().set_input_as_handled()
		return

	var esc: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if esc or start:
		if is_open():
			close()
		elif ui_manager and ui_manager.get("is_tuning_open"):
			ui_manager.toggle_tuning_panel() # ESC first closes the garage menu
		else:
			open()
		get_viewport().set_input_as_handled()

# ---------------- Layout ----------------
func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb

func _build_frame() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 640)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.05, 0.07, 0.97), Color(0.2, 0.6, 1.0, 0.85), 12))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⏸  DURAKLATILDI  —  AYARLAR"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_ACCENT)
	vbox.add_child(title)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 17)
	vbox.add_child(_tabs)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	vbox.add_child(bottom)
	_add_button(bottom, "▶  Devam Et", close)
	_add_button(bottom, "🔄  Aracı Başlangıca Al", _on_reset_car)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	_add_button(bottom, "↺  Varsayılanlara Dön", _on_defaults)
	_add_button(bottom, "✖  Oyundan Çık", func(): get_tree().quit())

func _add_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _new_tab(title: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(grid)
	_tabs.add_child(scroll)
	return grid

func _label(grid: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(360, 0)
	grid.add_child(l)

func _add_option(grid: Node, text: String, key: String, items: Array, rebuild: bool = false) -> void:
	_label(grid, text)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		ob.add_item(str(it))
	var v = GameSettings.get_value(key)
	ob.selected = (1 if v else 0) if typeof(v) == TYPE_BOOL else int(v)
	ob.item_selected.connect(func(idx: int):
		GameSettings.set_value(key, (idx == 1) if typeof(GameSettings.defaults[key]) == TYPE_BOOL else idx)
		if rebuild:
			_build_tabs.call_deferred())
	grid.add_child(ob)

func _add_check(grid: Node, text: String, key: String) -> void:
	_label(grid, text)
	var cb := CheckButton.new()
	cb.button_pressed = bool(GameSettings.get_value(key))
	cb.toggled.connect(func(on: bool): GameSettings.set_value(key, on))
	grid.add_child(cb)

# Slider showing value * display_mult with a unit suffix
func _add_slider(grid: Node, text: String, key: String, min_v: float, max_v: float, step: float, display_mult: float, suffix: String) -> void:
	_label(grid, text)
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value = float(GameSettings.get_value(key))
	var val := Label.new()
	val.custom_minimum_size = Vector2(80, 0)
	val.text = "%d%s" % [roundi(s.value * display_mult), suffix]
	s.value_changed.connect(func(v: float):
		val.text = "%d%s" % [roundi(v * display_mult), suffix]
		GameSettings.set_value(key, v))
	hb.add_child(s)
	hb.add_child(val)
	grid.add_child(hb)

func _note(grid: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	l.custom_minimum_size = Vector2(360, 0)
	grid.add_child(l)
	grid.add_child(Control.new())

# ---------------- Tabs ----------------
func _build_tabs() -> void:
	var current: int = _tabs.current_tab if _tabs.get_tab_count() > 0 else 0
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_bind_buttons.clear()

	# GÖRÜNTÜ
	var g := _new_tab("Görüntü")
	_add_option(g, "Pencere Modu", "window_mode", ["Pencere", "Tam Ekran (Kenarlıksız)", "Tam Ekran (Özel)"])
	var res_names: Array = []
	for r in GameSettings.RESOLUTIONS:
		res_names.append("%d × %d" % [r.x, r.y])
	_add_option(g, "Çözünürlük (pencere modunda)", "resolution", res_names)
	_add_option(g, "Dikey Senkronizasyon (V-Sync)", "vsync", ["Kapalı", "Açık", "Uyarlamalı"])
	var fps_names: Array = []
	for f in GameSettings.FPS_LIMITS:
		fps_names.append("Sınırsız" if f == 0 else str(f) + " FPS")
	_add_option(g, "FPS Sınırı", "max_fps", fps_names)
	_add_slider(g, "Render Ölçeği (düşük = daha fazla FPS)", "render_scale", 0.5, 1.0, 0.05, 100.0, " %")
	_add_slider(g, "Görüş Açısı (FOV)", "fov", 60.0, 100.0, 1.0, 1.0, "°")
	_add_check(g, "Hız Hissi Efekti (hızlanınca FOV genişler)", "speed_fov")
	_add_slider(g, "Parlaklık", "brightness", 0.5, 1.5, 0.05, 100.0, " %")
	_add_option(g, "Hız Birimi", "speed_mph", ["km/s", "mph"])
	_add_check(g, "Gösterge Paneli (HUD)", "hud_visible")
	_add_check(g, "Test Sahası Telemetrisi", "telemetry_visible")

	# GRAFİK
	var gr := _new_tab("Grafik")
	_add_option(gr, "Kalite Ön Ayarı", "quality_preset", ["Düşük", "Orta", "Yüksek", "Ultra", "Özel"], true)
	_add_option(gr, "Gölgeler", "shadows", ["Kapalı", "Düşük", "Orta", "Yüksek"], true)
	_add_option(gr, "Kenar Yumuşatma (MSAA)", "msaa", ["Kapalı", "2x", "4x", "8x"], true)
	_add_check(gr, "FXAA (hızlı kenar yumuşatma)", "fxaa")
	_add_check(gr, "TAA (zamansal kenar yumuşatma)", "taa")
	_add_check(gr, "Ortam Gölgelemesi (SSAO)", "ssao")
	_add_check(gr, "Parıltı Efekti (Glow)", "glow")
	_add_check(gr, "Atmosfer Sisi", "fog")
	_add_slider(gr, "Görüş Mesafesi", "draw_distance", 500.0, 4000.0, 100.0, 1.0, " m")
	_add_check(gr, "Projektör Işıkları", "floodlights")
	_note(gr, "İpucu: FPS düşükse önce Render Ölçeği'ni ve Gölgeler'i düşür.")

	# SES
	var s := _new_tab("Ses")
	_add_slider(s, "Ana Ses Seviyesi", "master_volume", 0.0, 1.0, 0.01, 100.0, " %")
	_add_check(s, "Sesi Kapat", "mute")

	# KONTROLLER
	var k := _new_tab("Kontroller")
	_add_slider(k, "Direksiyon Hızı (klavye)", "steer_sensitivity", 0.5, 2.0, 0.05, 100.0, " %")
	_add_slider(k, "Gamepad Ölü Bölge", "joy_deadzone", 0.02, 0.30, 0.01, 100.0, " %")
	_add_slider(k, "Kamera Fare Hassasiyeti", "mouse_sensitivity", 0.001, 0.010, 0.0005, 1000.0, "")
	_add_check(k, "Kamera Dikey Eksenini Ters Çevir", "invert_camera_y")
	_add_option(k, "Başlangıç Şanzımanı", "default_automatic", ["Manuel", "Otomatik"])
	_note(k, "Gamepad: Sol çubuk = direksiyon · RT = gaz · LT = fren · A/B = el freni · RB/LB = vites · Sol çubuk tık = turbo · X = kamera · Y = başlangıca dön · Select = otomatik/manuel · D-pad ◀▶ = araç · Start = bu menü")

	# ATAMALAR
	var b := _new_tab("Tuş Atamaları")
	b.columns = 3
	var h1 := Label.new(); h1.text = "Eylem"; b.add_child(h1)
	var h2 := Label.new(); h2.text = "Birincil Tuş"; b.add_child(h2)
	var h3 := Label.new(); h3.text = "İkincil Tuş"; b.add_child(h3)
	for h in [h1, h2, h3]:
		h.add_theme_color_override("font_color", COL_ACCENT)
	for a in GameSettings.ACTIONS:
		var action: String = a[0]
		var lab := Label.new()
		lab.text = a[1]
		lab.add_theme_font_size_override("font_size", 16)
		lab.custom_minimum_size = Vector2(300, 0)
		b.add_child(lab)
		for slot in range(2):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(220, 34)
			btn.pressed.connect(_start_capture.bind(action, slot))
			btn.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					GameSettings.clear_binding(action, slot)
					_refresh_bindings())
			_bind_buttons["%s:%d" % [action, slot]] = btn
			b.add_child(btn)
	var tip := Label.new()
	tip.text = "Tıkla → yeni tuşa bas (ESC: iptal) · Sağ tık: tuşu kaldır · 1–6: araç seçimi · ESC: bu menü"
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	b.add_child(tip)
	_refresh_bindings()

	_tabs.current_tab = clampi(current, 0, _tabs.get_tab_count() - 1)

func _refresh_bindings() -> void:
	for key in _bind_buttons:
		var parts: PackedStringArray = key.split(":")
		var keys: Array = GameSettings.bindings.get(parts[0], [])
		var slot: int = int(parts[1])
		var btn: Button = _bind_buttons[key]
		if parts[0] == _capture_action and slot == _capture_slot:
			btn.text = "… bir tuşa bas …"
		else:
			btn.text = GameSettings.key_name(keys[slot]) if slot < keys.size() else "—"

func _start_capture(action: String, slot: int) -> void:
	_capture_action = action
	_capture_slot = slot
	_refresh_bindings()

func _cancel_capture() -> void:
	if _capture_action != "":
		_capture_action = ""
		_refresh_bindings()

# ---------------- Buttons ----------------
func _on_reset_car() -> void:
	var car: Node = get_tree().current_scene.get_node_or_null("Vehicle")
	if car:
		car.reset_vehicle()
	close()

func _on_defaults() -> void:
	GameSettings.reset_to_defaults()
	_build_tabs()
