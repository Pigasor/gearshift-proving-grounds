extends Node
# Global settings (autoload "GameSettings"): stores every option, saves to user://settings.cfg,
# rebuilds the key bindings and applies display / graphics / audio / control settings.

const SAVE_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160)
]
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144, 165, 240] # 0 = unlimited

# Rebindable actions: [action, Turkish label, default physical keys]
const ACTIONS: Array = [
	["throttle", "Gaz", [KEY_W, KEY_UP]],
	["brake", "Fren / Geri", [KEY_S, KEY_DOWN]],
	["steer_left", "Sola Dön", [KEY_A, KEY_LEFT]],
	["steer_right", "Sağa Dön", [KEY_D, KEY_RIGHT]],
	["handbrake", "El Freni", [KEY_SPACE]],
	["turbo", "Turbo Boost", [KEY_SHIFT]],
	["gear_up", "Vites Yükselt", [KEY_E, KEY_F]],
	["gear_down", "Vites Düşür", [KEY_Q, KEY_V]],
	["toggle_transmission", "Otomatik / Manuel", [KEY_G]],
	["camera_view", "Kamera Değiştir", [KEY_C]],
	["slow_mo", "Ağır Çekim", [KEY_T]],
	["toggle_tuning", "Garaj Menüsü", [KEY_TAB]],
	["repair", "Aracı Düzelt", [KEY_R]],
	["reset_car", "Başlangıca Dön", [KEY_ENTER]],
	["minimap", "Mini Harita Yakın / Geniş", [KEY_N]],
	["full_map", "Büyük Harita", [KEY_M]],
	["lights", "Farlar (Park / Kısa)", [KEY_L]],
	["high_beam", "Uzun Far", [KEY_K]],
]

var defaults: Dictionary = {
	"language": "", # "" = pick from the system language on first start ("tr" or "en")
	# Display
	"window_mode": 1, # 0 windowed, 1 borderless fullscreen, 2 exclusive fullscreen
	"resolution": 0,
	"vsync": 1, # 0 off, 1 on, 2 adaptive
	"max_fps": 0,
	"render_scale": 1.0,
	"fov": 74.0,
	"speed_fov": true,
	"brightness": 1.0,
	"hud_visible": true,
	"telemetry_visible": true,
	"speed_mph": false,
	# Graphics
	"quality_preset": 2, # 0 low, 1 medium, 2 high, 3 ultra, 4 custom
	"shadows": 2, # 0 off, 1 low, 2 medium, 3 high
	"msaa": 1, # 0 off, 1 2x, 2 4x, 3 8x
	"fxaa": false,
	"taa": false,
	"ssao": false,
	"glow": true,
	"fog": true,
	"draw_distance": 3000.0,
	"floodlights": true,
	"time_of_day": 12.0, # hour the clock is set to (Settings > Görüntü)
	"day_cycle": true, # the clock keeps running
	"day_length": 1, # index into DayNight.DAY_MINUTES (10 / 24 / 48 min)
	"car_engines": {}, # car index (as text) -> engine index last picked for it in the garage
	# Audio
	"master_volume": 0.8,
	"mute": false,
	# Controls
	"steer_sensitivity": 1.0,
	"joy_deadzone": 0.08,
	"mouse_sensitivity": 0.004,
	"invert_camera_y": false,
	"vibration": true,
	"default_automatic": true,
	# Steering wheel set (racing wheel + pedals). Axes/buttons are found by the detect wizard.
	"wheel_enabled": false,
	"wheel_device": 0,
	"wheel_range": 900.0, # wheel rotation lock-to-lock (degrees)
	"wheel_steer_axis": 0,
	"wheel_steer_invert": false,
	"wheel_throttle_axis": -1, "wheel_throttle_rest": 1.0, "wheel_throttle_full": -1.0,
	"wheel_brake_axis": -1, "wheel_brake_rest": 1.0, "wheel_brake_full": -1.0,
	"wheel_clutch_axis": -1, "wheel_clutch_rest": 1.0, "wheel_clutch_full": -1.0,
	"wheel_shift_up_btn": -1,
	"wheel_shift_down_btn": -1,
	"wheel_handbrake_btn": -1,
	"wheel_handbrake_axis": -1, "wheel_handbrake_rest": 1.0, "wheel_handbrake_full": -1.0, # analog handbrake lever
	# H-pattern shifter: one button per gear (manual mode; no button pressed = neutral)
	"wheel_h1_btn": -1, "wheel_h2_btn": -1, "wheel_h3_btn": -1, "wheel_h4_btn": -1,
	"wheel_h5_btn": -1, "wheel_h6_btn": -1, "wheel_h7_btn": -1, "wheel_hr_btn": -1,
}

var values: Dictionary = {}
var bindings: Dictionary = {} # action -> Array of physical keycodes (max 2)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	values = defaults.duplicate(true)
	_reset_bindings()
	_register_translations()
	_load()
	apply_input_map()
	apply_language()
	apply_window()
	apply_audio()

func get_value(key: String):
	return values.get(key, defaults.get(key))

func set_value(key: String, v) -> void:
	values[key] = v
	if key == "language":
		apply_language()
	if key == "quality_preset" and int(v) < 4:
		_apply_preset(int(v))
	elif key in ["shadows", "msaa", "ssao", "glow", "fxaa", "taa", "draw_distance"]:
		values["quality_preset"] = 4 # user tweaked something -> custom
	apply_window()
	apply_audio()
	apply_scene()
	save()

func _apply_preset(p: int) -> void:
	var presets: Array = [
		{"shadows": 1, "msaa": 0, "fxaa": true, "taa": false, "ssao": false, "glow": false, "draw_distance": 1200.0},
		{"shadows": 2, "msaa": 1, "fxaa": false, "taa": false, "ssao": false, "glow": true, "draw_distance": 2000.0},
		{"shadows": 2, "msaa": 1, "fxaa": false, "taa": false, "ssao": false, "glow": true, "draw_distance": 3000.0},
		{"shadows": 3, "msaa": 2, "fxaa": false, "taa": false, "ssao": true, "glow": true, "draw_distance": 4000.0},
	]
	for k in presets[p]:
		values[k] = presets[p][k]

func reset_to_defaults() -> void:
	values = defaults.duplicate(true)
	apply_language()
	_reset_bindings()
	apply_input_map()
	apply_window()
	apply_audio()
	apply_scene()
	save()

# ---------------- Key bindings ----------------
func _reset_bindings() -> void:
	bindings.clear()
	for a in ACTIONS:
		bindings[a[0]] = (a[2] as Array).duplicate()

func set_binding(action: String, slot: int, keycode: int) -> void:
	# A key can only do one thing: remove it from any other action first
	for other in bindings:
		var keys: Array = bindings[other]
		var idx: int = keys.find(keycode)
		if idx != -1 and not (other == action and idx == slot):
			keys.remove_at(idx)
	var list: Array = bindings[action]
	if slot < list.size():
		list[slot] = keycode
	else:
		list.append(keycode)
	apply_input_map()
	save()

func clear_binding(action: String, slot: int) -> void:
	var list: Array = bindings[action]
	if slot < list.size():
		list.remove_at(slot)
	apply_input_map()
	save()

func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)

# Rebuilds the InputMap from our bindings. Uses PHYSICAL key positions, so WASD stays where it is
# on any keyboard layout (e.g. Turkish Q / F).
func apply_input_map() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for kc in bindings.get(action, []):
			var ev := InputEventKey.new()
			ev.physical_keycode = kc
			InputMap.action_add_event(action, ev)

# ---------------- Display / audio ----------------
func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match int(get_value("window_mode")):
		0:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var res: Vector2i = RESOLUTIONS[clampi(int(get_value("resolution")), 0, RESOLUTIONS.size() - 1)]
			var screen: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			res = Vector2i(mini(res.x, screen.size.x), mini(res.y, screen.size.y))
			if DisplayServer.window_get_size() != res:
				DisplayServer.window_set_size(res)
				DisplayServer.window_set_position(screen.position + (screen.size - res) / 2)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	match int(get_value("vsync")):
		0: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		1: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		2: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
	Engine.max_fps = FPS_LIMITS[clampi(int(get_value("max_fps")), 0, FPS_LIMITS.size() - 1)]

func apply_audio() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	var vol: float = float(get_value("master_volume"))
	AudioServer.set_bus_mute(bus, bool(get_value("mute")) or vol <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(vol, 0.001)))

# Applies everything that lives in the game scene (camera, lights, environment, HUD, car).
func apply_scene() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var main: Node = tree.current_scene
	var vp: Viewport = get_viewport()

	# Render resolution & anti-aliasing
	var scale: float = float(get_value("render_scale"))
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][clampi(int(get_value("msaa")), 0, 3)]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if bool(get_value("fxaa")) else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = bool(get_value("taa"))

	# Shadows
	var sun := main.get_node_or_null("SunLight") as DirectionalLight3D
	var shadow_q: int = int(get_value("shadows"))
	if sun:
		sun.shadow_enabled = shadow_q > 0
		sun.directional_shadow_max_distance = [0.0, 200.0, 400.0, 650.0][shadow_q]
	if shadow_q > 0:
		RenderingServer.directional_shadow_atlas_set_size([0, 1024, 2048, 4096][shadow_q], true)
		RenderingServer.directional_soft_shadow_filter_set_quality([0, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][shadow_q])

	# Environment effects & brightness
	var we := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment
		env.ssao_enabled = bool(get_value("ssao"))
		env.glow_enabled = bool(get_value("glow"))
		env.fog_enabled = bool(get_value("fog"))
		env.adjustment_enabled = true
		env.adjustment_brightness = float(get_value("brightness"))

	# Camera
	var cam_ctrl: Node = main.get_node_or_null("CameraController")
	if cam_ctrl:
		cam_ctrl.set("base_fov", float(get_value("fov")))
		cam_ctrl.set("speed_fov_effect", bool(get_value("speed_fov")))
		cam_ctrl.set("mouse_sensitivity", float(get_value("mouse_sensitivity")))
		cam_ctrl.set("invert_y", bool(get_value("invert_camera_y")))
		var cam := cam_ctrl.get_node_or_null("Camera3D") as Camera3D
		if cam:
			cam.far = float(get_value("draw_distance"))

	# Time of day (also switches the floodlights / lamp posts on at night)
	var dn: Node = main.get_node_or_null("DayNight")
	if dn:
		dn.apply_settings()

	# HUD
	var ui: Node = main.get_node_or_null("UIManager")
	if ui:
		var hud := ui.get_node_or_null("HUD") as Control
		if hud:
			hud.visible = bool(get_value("hud_visible"))
		ui.set("speed_mph", bool(get_value("speed_mph")))
	var stats := main.get_node_or_null("CanvasLayerStats") as CanvasLayer
	if stats:
		stats.visible = bool(get_value("telemetry_visible"))

	# Car controls
	var car: Node = main.get_node_or_null("Vehicle")
	if car:
		car.set("steer_sensitivity", float(get_value("steer_sensitivity")))
		car.set("joy_deadzone", float(get_value("joy_deadzone")))
		car.set("wheel_cfg", wheel_config())

# Steering-wheel settings as one dictionary for the car
func wheel_config() -> Dictionary:
	var d: Dictionary = {}
	for k in defaults:
		if str(k).begins_with("wheel_"):
			d[str(k).trim_prefix("wheel_")] = get_value(k)
	return d

# Called once when the game scene starts (also sets the default gearbox mode)
func apply_scene_start() -> void:
	apply_scene()
	# Windows sets the window icon so early that the taskbar button often keeps the generic
	# default icon; setting it again once the window is up makes the taskbar pick it up.
	if OS.get_name() == "Windows":
		get_tree().create_timer(1.0).timeout.connect(func() -> void: DisplayServer.set_native_icon("res://assets/icon.ico"))
	var car: Node = get_tree().current_scene.get_node_or_null("Vehicle") if get_tree().current_scene else null
	if car:
		car.set("is_automatic", bool(get_value("default_automatic")))

# ---------------- Save / load ----------------
func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	for a in bindings:
		cfg.set_value("bindings", a, bindings[a])
	cfg.set_value("meta", "bindings_version", 2)
	cfg.set_value("meta", "display_version", 2)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in defaults:
		if cfg.has_section_key("settings", k):
			values[k] = cfg.get_value("settings", k)
	for a in ACTIONS:
		if cfg.has_section_key("bindings", a[0]):
			bindings[a[0]] = cfg.get_value("bindings", a[0])
	# v2: M opens the big map now; the gearbox toggle moved from M to G
	if int(cfg.get_value("meta", "bindings_version", 1)) < 2:
		var tt: Array = bindings.get("toggle_transmission", [])
		var mi: int = tt.find(KEY_M)
		if mi != -1:
			tt[mi] = KEY_G
		for a in bindings:
			if a != "full_map":
				(bindings[a] as Array).erase(KEY_M)
		bindings["full_map"] = [KEY_M]
	# display v2: the game starts fullscreen at the monitor's own resolution (old saves were windowed)
	if int(cfg.get_value("meta", "display_version", 1)) < 2:
		values["window_mode"] = 1

# ---------------- Language ----------------
# Source texts are Turkish; English comes from I18n.EN. (Fallback locale is "tr" in
# project.godot, so a missing English text shows the Turkish one rather than nothing.)
func _register_translations() -> void:
	var t := Translation.new()
	t.locale = "en"
	for k in I18n.EN:
		t.add_message(k, I18n.EN[k])
	TranslationServer.add_translation(t)

func current_language() -> String:
	var lang: String = str(get_value("language"))
	if lang == "":
		lang = "tr" if OS.get_locale_language() == "tr" else "en" # first start: follow the system
	return lang

func apply_language() -> void:
	TranslationServer.set_locale(current_language())

# ---------------- Active input device ----------------
# Which controls the player is using right now, so the HUD shows the matching hints:
# "keyboard", "gamepad" or "wheel". Switches on the first real input from another device.
signal input_device_changed(device: String)
var input_device: String = "keyboard"

func _input(event: InputEvent) -> void:
	var dev: String = ""
	if event is InputEventKey and event.pressed:
		dev = "keyboard"
	elif event is InputEventJoypadButton and event.pressed:
		dev = _joy_kind(event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		dev = _joy_kind(event.device)
	if dev != "" and dev != input_device:
		input_device = dev
		input_device_changed.emit(dev)

func _joy_kind(device: int) -> String:
	if bool(get_value("wheel_enabled")) and device == int(get_value("wheel_device")):
		return "wheel"
	return "gamepad"
