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
	add_to_group("settings_menu")
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
	# Steering wheel wizard waiting for a button
	if _det_kind.ends_with("_btn") and event is InputEventJoypadButton and event.pressed \
			and event.device == int(GameSettings.get_value("wheel_device")):
		GameSettings.set_value("wheel_" + _det_kind, event.button_index)
		_finish_detect("✔ Buton %d atandı" % event.button_index)
		get_viewport().set_input_as_handled()
		return
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
		var big_map: Node = get_tree().get_first_node_in_group("full_map")
		if big_map and big_map.call("is_open"):
			return # ESC closes the big map first
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

	# KONUMLAR (teleport)
	var loc := _new_tab("Konumlar")
	var places: Array = [
		["🅿️  Apron / Paddock (başlangıç)", Vector3(185, 0, -510), 180.0],
		["🛫  Pist 18 başı (kuzey)", Vector3(0, 0, -1125), 0.0],
		["🚦  Drag Start Çizgisi", Vector3(0, 0, -1096), 0.0],
		["🛬  Pist 36 başı (güney)", Vector3(0, 0, 1125), 180.0],
		["🏠  Hangarlar", Vector3(235, 0, -1045), 180.0],
		["🏁  Yarış Pisti (start çizgisi)", Vector3(-200, 0, -255), 0.0],
		["🛣️  Otoyol Halkası", Vector3(0, 0, 1300), 90.0],
		["🌀  Drift Alanı", Vector3(250, 0, -300), 0.0],
		["🚀  Stunt Parkı", Vector3(150, 0, 40), 0.0],
		["🏜️  Off-road Alanı", Vector3(480, 0, 60), 0.0],
		["⛰️  Tepe Parkı", Vector3(-800, 0, -380), 0.0],
		["🔧  Süspansiyon Test Yolu", Vector3(-75, 0, -235), 0.0],
	]
	for p in places:
		_label(loc, p[0])
		var go := Button.new()
		go.text = "Işınlan"
		go.custom_minimum_size = Vector2(160, 34)
		go.size_flags_horizontal = Control.SIZE_SHRINK_END
		go.pressed.connect(_teleport.bind(p[1], p[2]))
		loc.add_child(go)

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
	_build_wheel_section(k)

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
	tip.text = "Tıkla → yeni tuşa bas (ESC: iptal) · Sağ tık: tuşu kaldır · Araç seçimi: TAB (garaj) · ESC: bu menü"
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	b.add_child(tip)
	_refresh_bindings()

	_tabs.current_tab = clampi(current, 0, _tabs.get_tab_count() - 1)

# ---------------- Steering wheel set ----------------
# Detect wizard: the player moves the wheel / presses a pedal or button, we find which axis or
# button it is (and the pedal's rest & fully-pressed values). No per-brand presets needed.
var _det_kind: String = "" # steer / throttle / brake / clutch / shift_up_btn / shift_down_btn / handbrake_btn
var _det_base: Array = []
var _det_axis: int = -1
var _det_extreme: float = 0.0
var _det_timer: float = 0.0
var _det_hold: float = 0.0
var _wheel_labels: Dictionary = {} # kind -> Label showing the current assignment
var _wheel_status: Label
var _wheel_live: Label

const WHEEL_ROWS: Array = [
	["steer", "Direksiyon Ekseni", "Direksiyonu SAĞA çevir"],
	["throttle", "Gaz Pedalı", "Gaz pedalına SONUNA KADAR bas ve tut"],
	["brake", "Fren Pedalı", "Fren pedalına SONUNA KADAR bas ve tut"],
	["clutch", "Debriyaj Pedalı (isteğe bağlı)", "Debriyaja SONUNA KADAR bas ve tut"],
	["shift_up_btn", "Vites Yükselt (kulakçık)", "Vites yükseltme butonuna bas"],
	["shift_down_btn", "Vites Düşür (kulakçık)", "Vites düşürme butonuna bas"],
	["handbrake_btn", "El Freni Butonu (isteğe bağlı)", "El freni olarak kullanılacak butona bas"],
	["handbrake", "El Freni Kolu - analog (isteğe bağlı)", "El freni kolunu SONUNA KADAR çek ve tut"],
	["h1_btn", "H Vites Kolu: 1. vites", "Vites kolunu 1. vitese tak"],
	["h2_btn", "H Vites Kolu: 2. vites", "Vites kolunu 2. vitese tak"],
	["h3_btn", "H Vites Kolu: 3. vites", "Vites kolunu 3. vitese tak"],
	["h4_btn", "H Vites Kolu: 4. vites", "Vites kolunu 4. vitese tak"],
	["h5_btn", "H Vites Kolu: 5. vites", "Vites kolunu 5. vitese tak"],
	["h6_btn", "H Vites Kolu: 6. vites", "Vites kolunu 6. vitese tak"],
	["h7_btn", "H Vites Kolu: 7. vites (varsa)", "Vites kolunu 7. vitese tak"],
	["hr_btn", "H Vites Kolu: Geri (R)", "Vites kolunu geri vitese tak"],
]

func _build_wheel_section(k: GridContainer) -> void:
	var head := Label.new()
	head.text = "🎮  DİREKSİYON SETİ"
	head.add_theme_font_size_override("font_size", 19)
	head.add_theme_color_override("font_color", COL_ACCENT)
	k.add_child(head)
	k.add_child(Control.new())
	_add_check(k, "Direksiyon Seti Kullan", "wheel_enabled")

	# Device list (connected joypads, by their real id)
	_label(k, "Cihaz")
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		ob.add_item("(bağlı cihaz yok)")
		ob.disabled = true
	for i in range(pads.size()):
		ob.add_item("%d: %s" % [pads[i], Input.get_joy_name(pads[i])], pads[i])
		if pads[i] == int(GameSettings.get_value("wheel_device")):
			ob.selected = i
	ob.item_selected.connect(func(idx: int): GameSettings.set_value("wheel_device", ob.get_item_id(idx)))
	k.add_child(ob)
	_add_slider(k, "Direksiyon Dönüş Açısı (uçtan uca)", "wheel_range", 180.0, 1080.0, 10.0, 1.0, "°")
	_add_check(k, "Direksiyon Yönünü Ters Çevir", "wheel_steer_invert")

	_wheel_labels.clear()
	for row in WHEEL_ROWS:
		_label(k, row[1])
		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val := Label.new()
		val.custom_minimum_size = Vector2(170, 0)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(val)
		_wheel_labels[row[0]] = val
		var det := Button.new()
		det.text = "Algıla"
		det.custom_minimum_size = Vector2(110, 32)
		det.pressed.connect(_start_wheel_detect.bind(row[0], row[2]))
		hb.add_child(det)
		var clr := Button.new()
		clr.text = "Kaldır"
		clr.custom_minimum_size = Vector2(90, 32)
		clr.pressed.connect(func():
			var key: String = "wheel_" + (row[0] if str(row[0]).ends_with("_btn") else row[0] + "_axis")
			GameSettings.set_value(key, -1)
			_refresh_wheel_labels())
		hb.add_child(clr)
		k.add_child(hb)

	_wheel_status = Label.new()
	_wheel_status.add_theme_font_size_override("font_size", 16)
	_wheel_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	k.add_child(_wheel_status)
	_wheel_live = Label.new()
	_wheel_live.add_theme_font_size_override("font_size", 15)
	k.add_child(_wheel_live)
	_note(k, "Algıla'ya bas, ekrandaki talimatı uygula (8 sn). Pedallar bırakılmış hâldeyken başla. H vites kolu manuel modda çalışır: kol boştayken araç boşta (N) olur; debriyaj pedalı tanımlıysa vitesi debriyaja basarak değiştir. Kuvvet geri bildirimi (FFB) şu an desteklenmiyor: Godot motoru bunu yerleşik olarak sağlamıyor.")
	_refresh_wheel_labels()

func _refresh_wheel_labels() -> void:
	for row in WHEEL_ROWS:
		var kind: String = row[0]
		var lab: Label = _wheel_labels.get(kind)
		if lab == null:
			continue
		if kind.ends_with("_btn"):
			var b: int = int(GameSettings.get_value("wheel_" + kind))
			lab.text = "—" if b < 0 else "Buton %d" % b
		else:
			var a: int = int(GameSettings.get_value("wheel_" + kind + "_axis"))
			lab.text = "—" if a < 0 else "Eksen %d" % a

func _start_wheel_detect(kind: String, prompt: String) -> void:
	var dev: int = int(GameSettings.get_value("wheel_device"))
	if not Input.get_connected_joypads().has(dev):
		_wheel_status.text = "⚠ Seçili cihaz bağlı değil."
		return
	_det_kind = kind
	_det_base.clear()
	for a in range(10):
		_det_base.append(Input.get_joy_axis(dev, a))
	_det_axis = -1
	_det_extreme = 0.0
	_det_timer = 8.0
	_det_hold = 0.0
	_wheel_status.text = "▶ " + prompt + " …"

func _process(delta: float) -> void:
	if not is_open() or _wheel_live == null or not is_instance_valid(_wheel_live):
		return
	var dev: int = int(GameSettings.get_value("wheel_device"))
	var connected: bool = Input.get_connected_joypads().has(dev)
	# Live readout of the configured controls (handy to check the calibration)
	if connected:
		var cfg: Dictionary = GameSettings.wheel_config()
		var parts: PackedStringArray = []
		var sa: int = int(cfg.get("steer_axis", -1))
		if sa >= 0:
			parts.append("Direksiyon %+.0f°" % (Input.get_joy_axis(dev, sa) * (-1.0 if cfg.get("steer_invert", false) else 1.0) * float(cfg.get("range", 900.0)) * 0.5))
		for p in ["throttle", "brake", "clutch", "handbrake"]:
			var ax: int = int(cfg.get(p + "_axis", -1))
			if ax >= 0:
				var rest: float = float(cfg.get(p + "_rest", 1.0))
				var full: float = float(cfg.get(p + "_full", -1.0))
				var v: float = clampf((Input.get_joy_axis(dev, ax) - rest) / (full - rest), 0.0, 1.0) if absf(full - rest) > 0.05 else 0.0
				parts.append("%s %%%d" % [{"throttle": "Gaz", "brake": "Fren", "clutch": "Debriyaj", "handbrake": "El freni"}[p], roundi(v * 100.0)])
		_wheel_live.text = "Canlı: " + "  ·  ".join(parts) if parts.size() > 0 else ""
	if _det_kind == "" or _det_kind.ends_with("_btn"):
		if _det_kind != "":
			_det_timer -= delta
			if _det_timer <= 0.0:
				_det_kind = ""
				_wheel_status.text = "⏱ Süre doldu, buton algılanamadı."
		return
	_det_timer -= delta
	if not connected or _det_timer <= 0.0:
		_det_kind = ""
		_wheel_status.text = "⏱ Süre doldu, hareket algılanamadı."
		return
	# Find the axis that moved most from where it was when "Algıla" was pressed
	var best: int = -1
	var best_d: float = 0.0
	for a in range(10):
		var d: float = Input.get_joy_axis(dev, a) - float(_det_base[a])
		if absf(d) > absf(best_d):
			best_d = d
			best = a
	if _det_kind == "steer":
		if absf(best_d) > 0.3:
			GameSettings.set_value("wheel_steer_axis", best)
			GameSettings.set_value("wheel_steer_invert", best_d < 0.0) # turned right -> must read positive
			_finish_detect("✔ Direksiyon: eksen %d" % best)
		return
	# Pedals: wait until one axis moved clearly, follow it to its extreme, then save rest/full
	if _det_axis < 0 and absf(best_d) > 0.5:
		_det_axis = best
	if _det_axis >= 0:
		var v: float = Input.get_joy_axis(dev, _det_axis)
		var base: float = float(_det_base[_det_axis])
		if absf(v - base) >= absf(_det_extreme - base):
			_det_extreme = v
		_det_hold += delta
		if _det_hold > 0.8:
			GameSettings.set_value("wheel_" + _det_kind + "_axis", _det_axis)
			GameSettings.set_value("wheel_" + _det_kind + "_rest", base)
			GameSettings.set_value("wheel_" + _det_kind + "_full", _det_extreme)
			_finish_detect("✔ %s: eksen %d (bırakılmış %.2f → basılı %.2f)" % [_det_kind, _det_axis, base, _det_extreme])

func _finish_detect(msg: String) -> void:
	_det_kind = ""
	_wheel_status.text = msg + " — pedalı / direksiyonu bırakabilirsin."
	_refresh_wheel_labels()

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

func _teleport(pos: Vector3, yaw: float) -> void:
	var car: Node = get_tree().current_scene.get_node_or_null("Vehicle")
	if car:
		car.teleport_to(pos, yaw)
		var cam: Node = get_tree().current_scene.get_node_or_null("CameraController")
		if cam:
			cam.set("_orbit_yaw", deg_to_rad(yaw))
			cam.global_position = car.global_position + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 2.5, -7.0)
	close()

func _on_defaults() -> void:
	GameSettings.reset_to_defaults()
	_build_tabs()
