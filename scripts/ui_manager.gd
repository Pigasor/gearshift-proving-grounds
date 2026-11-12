class_name UIManager
extends CanvasLayer

@export var vehicle: Node3D

# HUD Elements
@onready var label_speed: Label = $HUD/MarginContainer/VBoxTelemetry/HBoxSpeed/LabelSpeedValue
@onready var label_gear: Label = $HUD/MarginContainer/VBoxTelemetry/HBoxGear/LabelGearValue
@onready var progress_rpm: ProgressBar = $HUD/MarginContainer/VBoxTelemetry/ProgressRPM
@onready var label_rpm: Label = $HUD/MarginContainer/VBoxTelemetry/ProgressRPM/LabelRPM
@onready var progress_clutch: ProgressBar = $HUD/MarginContainer/VBoxTelemetry/HBoxPedals/ProgressClutch
@onready var progress_throttle: ProgressBar = $HUD/MarginContainer/VBoxTelemetry/HBoxPedals/ProgressThrottle
@onready var progress_brake: ProgressBar = $HUD/MarginContainer/VBoxTelemetry/HBoxPedals/ProgressBrake
@onready var label_turbo: Label = $HUD/MarginContainer/VBoxTelemetry/LabelTurbo
@onready var label_gforce: Label = $HUD/MarginContainer/VBoxTelemetry/LabelGForce
@onready var label_slowmo: Label = $HUD/LabelSlowMo
@onready var label_handbrake: Label = $HUD/LabelHandbrake

# Quick Action Buttons
@onready var btn_quick_car: Button = $HUD/TopBar/BtnQuickCar
@onready var btn_quick_tuning: Button = $HUD/TopBar/BtnQuickTuning
@onready var btn_quick_gear_mode: Button = $HUD/TopBar/BtnQuickGearMode
@onready var btn_quick_slowmo: Button = $HUD/TopBar/BtnQuickSlowMo
@onready var btn_quick_camera: Button = $HUD/TopBar/BtnQuickCamera
@onready var btn_quick_reset: Button = $HUD/TopBar/BtnQuickReset

# Tuning Menu
@onready var panel_tuning: PanelContainer = $TuningPanel
@onready var option_car_select: OptionButton = $TuningPanel/MarginContainer/VBoxTuning/Grid/OptionCarSelect
@onready var slider_hp: HSlider = $TuningPanel/MarginContainer/VBoxTuning/Grid/SliderHP
@onready var label_hp_val: Label = $TuningPanel/MarginContainer/VBoxTuning/Grid/LabelHPVal
@onready var slider_turbo: HSlider = $TuningPanel/MarginContainer/VBoxTuning/Grid/SliderTurbo
@onready var label_turbo_val: Label = $TuningPanel/MarginContainer/VBoxTuning/Grid/LabelTurboVal
@onready var slider_susp_stiff: HSlider = $TuningPanel/MarginContainer/VBoxTuning/Grid/SliderSuspStiff
@onready var label_susp_stiff_val: Label = $TuningPanel/MarginContainer/VBoxTuning/Grid/LabelSuspStiffVal
@onready var slider_susp_damp: HSlider = $TuningPanel/MarginContainer/VBoxTuning/Grid/SliderSuspDamp
@onready var label_susp_damp_val: Label = $TuningPanel/MarginContainer/VBoxTuning/Grid/LabelSuspDampVal
@onready var slider_camber: HSlider = $TuningPanel/MarginContainer/VBoxTuning/Grid/SliderCamber
@onready var label_camber_val: Label = $TuningPanel/MarginContainer/VBoxTuning/Grid/LabelCamberVal
@onready var slider_grip: HSlider = $TuningPanel/MarginContainer/VBoxTuning/Grid/SliderGrip
@onready var label_grip_val: Label = $TuningPanel/MarginContainer/VBoxTuning/Grid/LabelGripVal
@onready var option_drivetrain: OptionButton = $TuningPanel/MarginContainer/VBoxTuning/Grid/OptionDrivetrain
@onready var check_abs: CheckBox = $TuningPanel/MarginContainer/VBoxTuning/GridAssists/CheckABS
@onready var check_tcs: CheckBox = $TuningPanel/MarginContainer/VBoxTuning/GridAssists/CheckTCS
@onready var check_auto_trans: CheckBox = $TuningPanel/MarginContainer/VBoxTuning/GridAssists/CheckAutoTrans

var is_tuning_open: bool = false
var speed_mph: bool = false # set from Settings
@onready var label_speed_unit: Label = get_node_or_null("HUD/MarginContainer/VBoxTelemetry/HBoxSpeed/LabelSpeedUnit")
var option_engine: OptionButton # engine variants of the selected car (built in code)
var _rpm_fill: StyleBoxFlat # own copy of the rev bar fill, recoloured per zone
var _rpm_bands: Array = [] # yellow / red zone strips under the rev bar
var _flip_label: Label # "car is upside down - press R" (after a second on its roof / side)
var _flip_t: float = 0.0
var _lights_label: Label # which lights are on

func _ready() -> void:
	panel_tuning.visible = false
	# Top bar buttons must never keep keyboard focus: otherwise Space (handbrake) or Enter
	# "clicks" the last pressed button again, e.g. Reset, and the car suddenly stops.
	for btn in [btn_quick_car, btn_quick_tuning, btn_quick_gear_mode, btn_quick_slowmo, btn_quick_camera, btn_quick_reset]:
		if btn:
			btn.focus_mode = Control.FOCUS_NONE
	_setup_options()
	_build_garage_layout()
	_style_top_bar()
	_sync_tuning_sliders_from_vehicle()

	# Pause / settings menu (ESC)
	var menu := CanvasLayer.new()
	menu.set_script(load("res://scripts/settings_menu.gd"))
	menu.name = "SettingsMenu"
	menu.set("ui_manager", self)
	get_parent().add_child.call_deferred(menu)
	# Big map (M) - added after the menu so it sees M / ESC first
	var big_map := CanvasLayer.new()
	big_map.set_script(load("res://scripts/full_map.gd"))
	big_map.name = "FullMap"
	big_map.set("vehicle", vehicle)
	get_parent().add_child.call_deferred(big_map)
	var day_night := Node.new()
	day_night.set_script(load("res://scripts/day_night.gd"))
	day_night.name = "DayNight"
	get_parent().add_child.call_deferred(day_night)
	GameSettings.apply_scene_start.call_deferred()

	_flip_label = Label.new()
	_flip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_flip_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_flip_label.anchor_top = 0.2 # upper part of the screen, clear of the car
	_flip_label.anchor_bottom = 0.2
	_flip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flip_label.add_theme_font_size_override("font_size", 24)
	_flip_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_flip_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_flip_label.add_theme_constant_override("outline_size", 8)
	_flip_label.visible = false
	$HUD.add_child(_flip_label)
	_lights_label = Label.new()
	_lights_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lights_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	label_turbo.get_parent().add_child(_lights_label)
	label_turbo.get_parent().move_child(_lights_label, label_turbo.get_index())

	# Mini map (bottom-left); N switches close / wide view
	var minimap := Control.new()
	minimap.set_script(load("res://scripts/minimap.gd"))
	minimap.name = "Minimap"
	minimap.set("vehicle", vehicle)
	$HUD.add_child(minimap)

# Tab is also Godot's "next control" key: while the garage is open it must close the garage
# instead of walking through its sliders.
func _input(event: InputEvent) -> void:
	if is_tuning_open and event.is_action_pressed("toggle_tuning", false, true):
		toggle_tuning_panel()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Garage menu (rebindable, default TAB). ESC / gamepad Start open the pause & settings menu.
	if event.is_action_pressed("toggle_tuning", false, true):
		toggle_tuning_panel()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP:
			toggle_tuning_panel()
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			_cycle_next_car()
		elif event.button_index == JOY_BUTTON_DPAD_LEFT:
			_cycle_prev_car()

func toggle_tuning_panel() -> void:
	is_tuning_open = !is_tuning_open
	panel_tuning.visible = is_tuning_open
	if vehicle:
		vehicle.set("input_blocked", is_tuning_open) # park the car while tuning
	if is_tuning_open:
		_sync_tuning_sliders_from_vehicle()
	else:
		# Drop focus from sliders/checkboxes so arrow keys & Space go back to driving.
		get_viewport().gui_release_focus()

func _process(delta: float) -> void:
	if vehicle == null:
		return
	_update_hud()
	# Upside down / on its side and (nearly) stopped for a second -> tell how to recover
	var b: Basis = vehicle.global_transform.basis
	if b.y.y < 0.3 and vehicle.current_speed_kmh < 20.0 and not vehicle.get("wall_climbing"):
		_flip_t += delta / maxf(Engine.time_scale, 0.05)
	else:
		_flip_t = 0.0
	_flip_label.visible = _flip_t > 1.0
	if _flip_label.visible:
		var k: String = "Y" if GameSettings.input_device == "gamepad" else _key("repair")
		_flip_label.text = tr("Araç devrildi! Düzeltmek için %s tuşuna bas") % k
	var hb: bool = vehicle.get("high_beam")
	var lm: int = int(vehicle.get("light_mode"))
	_lights_label.visible = hb or lm > 0
	_lights_label.text = tr("🔦 UZUN FAR") if hb else (tr("💡 KISA FAR") if lm == 2 else tr("🅿️ PARK LAMBALARI"))

func _update_hud() -> void:
	# Speed
	label_speed.text = "%3.0f" % (vehicle.current_speed_kmh * (0.621371 if speed_mph else 1.0))
	if label_speed_unit:
		label_speed_unit.text = " MPH" if speed_mph else " KM/H"

	# Gear & Transmission mode
	var mode_prefix: String = "[A] " if vehicle.is_automatic else "[M] "
	match vehicle.current_gear:
		0:
			label_gear.text = mode_prefix + "R"
			label_gear.modulate = Color(1.0, 0.35, 0.35)
		1:
			label_gear.text = mode_prefix + "N"
			label_gear.modulate = Color(0.8, 0.8, 0.8)
		_:
			label_gear.text = mode_prefix + str(vehicle.current_gear - 1)
			label_gear.modulate = Color(0.2, 0.85, 1.0)

	_update_control_hints()

	# Current vehicle button label
	btn_quick_car.text = "🚗 " + CarDatabase.display_name(int(vehicle.current_vehicle_type), int(vehicle.current_engine_index))

	# RPM
	progress_rpm.min_value = vehicle.idle_rpm * 0.5
	progress_rpm.max_value = vehicle.max_rpm
	progress_rpm.value = vehicle.current_rpm
	label_rpm.text = "%4.0f RPM" % vehicle.current_rpm
	# Shift zones from the car's own rev range: yellow = last 20% of the usable range below the
	# limiter, red = the last 250 rpm (the bar stays red there, not only during fuel-cut pulses).
	var red_from: float = vehicle.limiter_rpm - 250.0
	var yellow_from: float = vehicle.limiter_rpm - (vehicle.limiter_rpm - vehicle.idle_rpm) * 0.2
	if _rpm_fill == null:
		_rpm_fill = (progress_rpm.get_theme_stylebox("fill") as StyleBoxFlat).duplicate()
		progress_rpm.add_theme_stylebox_override("fill", _rpm_fill)
		_rpm_bands = [ColorRect.new(), ColorRect.new()]
		for k in 2:
			var band: ColorRect = _rpm_bands[k]
			band.color = Color(1.0, 0.8, 0.1, 0.9) if k == 0 else Color(1.0, 0.18, 0.15, 0.9)
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.anchor_top = 1.0
			band.anchor_bottom = 1.0
			band.offset_top = -4.0
			progress_rpm.add_child(band)
	var span: float = maxf(progress_rpm.max_value - progress_rpm.min_value, 1.0)
	var y0: float = clampf((yellow_from - progress_rpm.min_value) / span, 0.0, 1.0)
	var r0: float = clampf((red_from - progress_rpm.min_value) / span, 0.0, 1.0)
	(_rpm_bands[0] as ColorRect).anchor_left = y0
	(_rpm_bands[0] as ColorRect).anchor_right = r0
	(_rpm_bands[1] as ColorRect).anchor_left = r0
	(_rpm_bands[1] as ColorRect).anchor_right = 1.0
	if vehicle.is_limiter_active or vehicle.current_rpm >= red_from:
		_rpm_fill.bg_color = Color(1.0, 0.18, 0.15)
	elif vehicle.current_rpm >= yellow_from:
		_rpm_fill.bg_color = Color(1.0, 0.8, 0.1)
	else:
		_rpm_fill.bg_color = Color(0.15, 0.75, 1.0)

	# Pedals
	progress_clutch.value = vehicle.clutch_pedal * 100.0
	# Read the pedals from the car (covers keyboard AND analog gamepad triggers, by how hard they're pressed)
	progress_throttle.value = vehicle.pedal_throttle * 100.0
	progress_brake.value = vehicle.pedal_brake * 100.0

	# Turbo & Shift Turbo Boost Display
	if "turbo_boost_active" in vehicle and vehicle.turbo_boost_active:
		label_turbo.text = tr("🔥 TURBO AKTİF! (%1.1fs) +%1.2f BAR") % [vehicle.turbo_boost_timer, vehicle.turbo_boost_bar]
		label_turbo.modulate = Color(1.0, 0.45, 0.1) # Glowing fiery orange
	elif "turbo_boost_cooldown_timer" in vehicle and vehicle.turbo_boost_cooldown_timer > 0.0:
		label_turbo.text = tr("⏳ SOĞUMA: %1.1fs (+%1.2f BAR)") % [vehicle.turbo_boost_cooldown_timer, vehicle.turbo_boost_bar]
		label_turbo.modulate = Color(0.65, 0.72, 0.85) # Cooldown blue-gray
	elif vehicle.turbo_enabled:
		label_turbo.text = tr("⚡ TURBO [SHIFT]: HAZIR (+%1.2f BAR)") % vehicle.turbo_boost_bar
		label_turbo.modulate = Color(0.25, 0.95, 1.0) # Electric neon cyan
	else:
		label_turbo.text = tr("⚡ NITRO [SHIFT]: HAZIR")
		label_turbo.modulate = Color(0.25, 0.95, 1.0)

	label_gforce.text = "G-LAT: %+1.2f G  |  G-LONG: %+1.2f G" % [vehicle.g_force_lateral, vehicle.g_force_longitudinal]

	# Handbrake & Slowmo
	label_handbrake.visible = vehicle.is_handbrake_active
	label_slowmo.visible = (Engine.time_scale < 0.9)

const CAR_GROUPS: Array = [["Sedan", "Sedan"], ["Classic", "Classic"], ["Sport", "Sport"], ["Muscle", "Muscle"],
	["Stock Car", "NASCAR"], ["Hyper", "Hypercar"], ["Off-Road", "Off-Road"], ["Monster", "Monster Truck"], ["Tractor", "Tractor"]]

func _setup_options() -> void:
	# Cars grouped by class under separator headings; the item id is the car index.
	option_car_select.clear()
	for grp in CAR_GROUPS:
		var first: bool = true
		for i in range(CarDatabase.count()):
			var c: Dictionary = CarDatabase.car(i)
			if c["class"] != grp[0]:
				continue
			if first:
				option_car_select.add_separator(grp[1])
				first = false
			option_car_select.add_item(c["name"], i)

	# Engine choice row (label | dropdown | spacer) right under the car row of the 3-column grid
	if option_engine == null:
		var grid: GridContainer = option_car_select.get_parent()
		var lbl := Label.new()
		lbl.text = "Motor:"
		option_engine = OptionButton.new()
		option_engine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_engine.item_selected.connect(_on_option_engine_selected)
		var spacer := Control.new()
		var at: int = option_car_select.get_index() + 2
		for n in [lbl, option_engine, spacer]:
			grid.add_child(n)
			grid.move_child(n, at)
			at += 1

	option_drivetrain.clear()
	option_drivetrain.add_item("RWD (Arkadan İtiş)", 0)
	option_drivetrain.add_item("AWD (4 Çeker)", 1)
	option_drivetrain.add_item("FWD (Önden Çeker)", 2)

const ACCENT := Color(0.2, 0.65, 1.0)
var garage_tabs: TabContainer
var label_car_stats: Label

func _sb(bg: Color, border: Color, radius: int, bottom_only: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	if bottom_only:
		sb.border_width_bottom = 3
	else:
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb

# What each garage setting does (one per grid row, then ABS / TCS / automatic), shown on hover
const HELP: Array = [
	"Sürmek istediğin araç. Araçlar sınıflarına göre gruplanmıştır.",
	"Seçili aracın motor seçeneği: gücü, torku, vites kutusunu ve sesini değiştirir.",
	"Motorun beygir gücü (HP). Tork da aynı oranda değişir: daha fazla güç daha hızlı hızlanma ve daha yüksek son hız, ama daha fazla patinaj demek.",
	"Turbonun en yüksek basıncı (bar). Yüksek basınç devir arttıkça daha fazla tork verir ama turbo gecikmesi de artar. 0 = turbosuz.",
	"Süspansiyon yaylarının sertliği. Sert yay: virajda daha az yatma ve keskin tepki, ama tümseklerde sert ve zıplayan sürüş. Yumuşak yay: arazide ve tümseklerde daha konforlu.",
	"Amortisörlerin yayın hareketini frenleme gücü. Az sönümleme: araba tümsekten sonra salınır, zıplar. Fazla sönümleme: sert ve tepkili, ama tümsekleri iyi yutmaz.",
	"Ön tekerlerin önden bakınca içe yatma açısı (eksi = tekerin üstü içeri). Biraz eksi kamber virajda lastiğin yere tam basmasını sağlar ve viraj tutuşunu artırır; fazlası düz yolda fren ve çekiş tutuşunu azaltır.",
	"Lastiklerin yol tutuş katsayısı. 1.00 = normal yol lastiği; yüksek = yarış lastiği, düşük = kaygan ya da yıpranmış lastik.",
	"Motor gücünün hangi tekerlere gittiği. RWD: arkadan itiş (gazla arkası kayar), FWD: önden çekiş (dengeli, önden kayar), AWD: dört çeker (en iyi çekiş).",
	"ABS: sert frende tekerlerin kilitlenmesini önler, böylece fren yaparken direksiyon hâkimiyeti kaybolmaz.",
	"Çekiş kontrolü: gaza basınca tekerlerin patinaj yapmasını engeller. Kapalıyken güçlü arabalar patinaj çeker ve gazla arkadan kayar.",
	"Açıkken vitesler otomatik değişir. Kapalıyken vitesleri sen değiştirirsin (E/Q, RB/LB ya da kulakçıklar).",
]

# Puts a grey round "?" after a garage control; hovering it shows what the setting does.
# Returns the box now holding both (it takes the control's place in its container).
func _add_help(ctrl: Control, text: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var parent: Node = ctrl.get_parent()
	var idx: int = ctrl.get_index()
	parent.add_child(box)
	parent.move_child(box, idx)
	ctrl.reparent(box)
	var q: Label = preload("res://scripts/help_tip.gd").new()
	q.text = "?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.custom_minimum_size = Vector2(22, 22)
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	q.add_theme_font_size_override("font_size", 14)
	q.add_theme_color_override("font_color", Color(0.12, 0.13, 0.15))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.62, 0.65, 0.7)
	sb.set_corner_radius_all(11)
	q.add_theme_stylebox_override("normal", sb)
	q.mouse_filter = Control.MOUSE_FILTER_STOP # needed for the hover tooltip
	q.mouse_default_cursor_shape = Control.CURSOR_HELP
	q.tooltip_text = text # auto-translated like the other labels
	box.add_child(q)
	return box

# Garage: header with the car's figures + one tab per area (Car / Engine / Suspension / Driving),
# so new cars and upgrades (e.g. Stage 1 software) each get their own place.
func _build_garage_layout() -> void:
	var vbox: VBoxContainer = option_car_select.get_parent().get_parent()
	var grid: GridContainer = option_car_select.get_parent()
	var title: Label = vbox.get_node("LabelTitle")
	panel_tuning.offset_left = -350.0
	panel_tuning.offset_right = 350.0
	panel_tuning.offset_top = -170.0 # grows to fit its content
	panel_tuning.offset_bottom = 170.0

	var header := HBoxContainer.new()
	vbox.add_child(header)
	vbox.move_child(header, 0)
	title.reparent(header)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_car_stats = Label.new()
	label_car_stats.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	label_car_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(label_car_stats)

	garage_tabs = TabContainer.new()
	garage_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	garage_tabs.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.09, 0.12, 1.0), Color(0.2, 0.3, 0.42), 8))
	garage_tabs.add_theme_stylebox_override("tab_selected", _sb(Color(0.12, 0.18, 0.26), ACCENT, 6, true))
	garage_tabs.add_theme_stylebox_override("tab_unselected", _sb(Color(0.06, 0.07, 0.09), Color(0, 0, 0, 0), 6, true))
	garage_tabs.add_theme_stylebox_override("tab_hovered", _sb(Color(0.1, 0.14, 0.2), Color(0.3, 0.45, 0.6), 6, true))
	garage_tabs.add_theme_color_override("font_selected_color", Color(1, 1, 1))
	garage_tabs.add_theme_color_override("font_unselected_color", Color(0.6, 0.67, 0.75))
	vbox.add_child(garage_tabs)
	vbox.move_child(garage_tabs, 1)

	# The old grid holds rows of 3 (label | control | value): car, engine, hp, turbo, springs,
	# dampers, camber, grip, drivetrain. Move them row by row into the tabs.
	var rows: Array = []
	var kids: Array = grid.get_children()
	for i in range(0, kids.size(), 3):
		rows.append(kids.slice(i, i + 3))
	var pages: Array = [["🚗 Araç", 0, 2], ["⚙️ Motor", 2, 4], ["🔧 Süspansiyon", 4, 8], ["🛡️ Sürüş", 8, 9]]
	for p in pages:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 14)
		var g := GridContainer.new()
		g.columns = 3
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_theme_constant_override("h_separation", 14)
		g.add_theme_constant_override("v_separation", 12)
		page.add_child(g)
		for r in range(int(p[1]), int(p[2])):
			for n in rows[r]:
				n.reparent(g)
			_add_help(rows[r][0], HELP[r]).custom_minimum_size.x = 170 # same column widths on every tab
			(rows[r][1] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(rows[r][2] as Control).custom_minimum_size.x = 110
		garage_tabs.add_child(page)
		garage_tabs.set_tab_title(garage_tabs.get_tab_count() - 1, p[0])
	check_abs.get_parent().reparent(garage_tabs.get_child(3))
	for k in 3:
		_add_help([check_abs, check_tcs, check_auto_trans][k], HELP[9 + k])
	vbox.get_node("HSeparator").queue_free()
	grid.queue_free()

# Top bar: one dark strip; the car button stands out and opens the garage's car list.
func _style_top_bar() -> void:
	var bar: HBoxContainer = btn_quick_car.get_parent()
	var strip := PanelContainer.new()
	var sb := _sb(Color(0.05, 0.06, 0.08, 0.86), Color(0.2, 0.35, 0.5, 0.7), 10)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	strip.add_theme_stylebox_override("panel", sb)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centre := CenterContainer.new() # keeps the strip centred whatever its width
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.get_parent().add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	centre.offset_top = 10
	centre.add_child(strip)
	bar.reparent(strip)
	bar.add_theme_constant_override("separation", 4)
	for btn in [btn_quick_tuning, btn_quick_gear_mode, btn_quick_slowmo, btn_quick_camera, btn_quick_reset]:
		btn.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 7))
		btn.add_theme_stylebox_override("hover", _sb(Color(0.14, 0.2, 0.28), Color(0.3, 0.5, 0.7), 7))
		btn.add_theme_stylebox_override("pressed", _sb(Color(0.1, 0.3, 0.5), ACCENT, 7))
		btn.add_theme_color_override("font_color", Color(0.82, 0.87, 0.93))
	btn_quick_car.add_theme_stylebox_override("normal", _sb(Color(0.08, 0.22, 0.36), ACCENT, 7))
	btn_quick_car.add_theme_stylebox_override("hover", _sb(Color(0.12, 0.3, 0.48), ACCENT, 7))
	btn_quick_car.add_theme_stylebox_override("pressed", _sb(Color(0.12, 0.3, 0.48), ACCENT, 7))
	var sep := VSeparator.new()
	bar.add_child(sep)
	bar.move_child(sep, btn_quick_car.get_index() + 1)

func _update_car_stats() -> void:
	if label_car_stats:
		label_car_stats.text = "%d HP  ·  %d Nm  ·  %d kg  ·  %s" % [int(vehicle.peak_horsepower), int(vehicle.torque_peak_nm), int(vehicle.mass), vehicle.drivetrain_mode]

func _sync_tuning_sliders_from_vehicle() -> void:
	if vehicle == null:
		return
	_update_car_stats.call_deferred()

	var car_i: int = int(vehicle.current_vehicle_type)
	option_car_select.selected = option_car_select.get_item_index(car_i)
	if option_engine:
		option_engine.clear()
		var engines: Array = CarDatabase.car(car_i)["engines"]
		for e in range(engines.size()):
			option_engine.add_item(str(engines[e]["label"]), e)
		option_engine.selected = int(vehicle.current_engine_index)
		option_engine.disabled = engines.size() < 2

	# Ranges wide enough for every car (Hypercar 1150 HP, Monster Truck 1500 HP / stiff springs).
	# Values are set WITHOUT firing value_changed, so syncing never clamps & writes back into the car
	# (the HP slider used to cap the Hypercar at 1000 HP whenever the menu opened).
	slider_hp.max_value = maxf(2000.0, vehicle.peak_horsepower)
	slider_susp_stiff.max_value = maxf(90000.0, vehicle.spring_stiffness)
	slider_susp_damp.max_value = maxf(14000.0, vehicle.damper_bump)

	slider_hp.set_value_no_signal(vehicle.peak_horsepower)
	label_hp_val.text = "%d HP" % int(vehicle.peak_horsepower)

	slider_turbo.set_value_no_signal(vehicle.turbo_max_boost_bar)
	label_turbo_val.text = "%1.1f BAR" % vehicle.turbo_max_boost_bar

	slider_susp_stiff.set_value_no_signal(vehicle.spring_stiffness)
	label_susp_stiff_val.text = "%d N/m" % int(vehicle.spring_stiffness)

	slider_susp_damp.set_value_no_signal(vehicle.damper_bump)
	label_susp_damp_val.text = "%d Ns/m" % int(vehicle.damper_bump)

	slider_camber.set_value_no_signal(vehicle.camber_angle_front_deg)
	label_camber_val.text = "%1.1f°" % vehicle.camber_angle_front_deg

	slider_grip.set_value_no_signal(vehicle.tire_grip_factor)
	label_grip_val.text = "%1.2f" % vehicle.tire_grip_factor

	match vehicle.drivetrain_mode:
		"RWD": option_drivetrain.selected = 0
		"AWD": option_drivetrain.selected = 1
		"FWD": option_drivetrain.selected = 2

	check_abs.button_pressed = vehicle.abs_enabled
	check_tcs.button_pressed = vehicle.tcs_enabled
	check_auto_trans.button_pressed = vehicle.is_automatic

# --- Tuning UI Callbacks ---
func _on_option_car_select_item_selected(index: int) -> void:
	if vehicle:
		vehicle.apply_car(option_car_select.get_item_id(index), 0)
		_sync_tuning_sliders_from_vehicle()

func _on_option_engine_selected(index: int) -> void:
	if vehicle:
		vehicle.apply_car(int(vehicle.current_vehicle_type), index)
		_sync_tuning_sliders_from_vehicle()

func _cycle_next_car() -> void:
	if vehicle:
		vehicle.apply_car((int(vehicle.current_vehicle_type) + 1) % CarDatabase.count(), 0)
		_sync_tuning_sliders_from_vehicle()

func _cycle_prev_car() -> void:
	if vehicle:
		vehicle.apply_car((int(vehicle.current_vehicle_type) - 1 + CarDatabase.count()) % CarDatabase.count(), 0)
		_sync_tuning_sliders_from_vehicle()

func _on_btn_quick_car_pressed() -> void:
	# many cars to pick from: open the garage on its car tab instead of cycling one by one
	if not is_tuning_open:
		toggle_tuning_panel()
	garage_tabs.current_tab = 0

func _on_slider_hp_value_changed(val: float) -> void:
	if vehicle.use_torque_curve and vehicle.peak_horsepower > 0.0:
		vehicle.torque_peak_nm *= val / vehicle.peak_horsepower # tune power & torque together
	vehicle.peak_horsepower = val
	label_hp_val.text = "%d HP" % int(val)
	_update_car_stats()

func _on_slider_turbo_value_changed(val: float) -> void:
	vehicle.turbo_max_boost_bar = val
	label_turbo_val.text = "%1.1f BAR" % val

func _on_slider_susp_stiff_value_changed(val: float) -> void:
	vehicle.spring_stiffness = val
	label_susp_stiff_val.text = "%d N/m" % int(val)

func _on_slider_susp_damp_value_changed(val: float) -> void:
	vehicle.damper_bump = val
	vehicle.damper_rebound = val * 1.3
	label_susp_damp_val.text = "%d Ns/m" % int(val)

func _on_slider_camber_value_changed(val: float) -> void:
	vehicle.camber_angle_front_deg = val
	label_camber_val.text = "%1.1f°" % val

func _on_slider_grip_value_changed(val: float) -> void:
	vehicle.tire_grip_factor = val
	label_grip_val.text = "%1.2f" % val

func _on_option_drivetrain_item_selected(index: int) -> void:
	match index:
		0: vehicle.drivetrain_mode = "RWD"
		1: vehicle.drivetrain_mode = "AWD"
		2: vehicle.drivetrain_mode = "FWD"
	_update_car_stats()

func _on_check_abs_toggled(button_pressed: bool) -> void:
	vehicle.abs_enabled = button_pressed

func _on_check_tcs_toggled(button_pressed: bool) -> void:
	vehicle.tcs_enabled = button_pressed

func _on_check_auto_trans_toggled(button_pressed: bool) -> void:
	vehicle.is_automatic = button_pressed

func _on_btn_quick_tuning_pressed() -> void:
	toggle_tuning_panel()

func _on_btn_quick_gear_mode_pressed() -> void:
	vehicle.is_automatic = !vehicle.is_automatic

func _on_btn_quick_slowmo_pressed() -> void:
	vehicle.toggle_slow_mo()

func _on_btn_quick_camera_pressed() -> void:
	var cam_ctrl = get_tree().root.find_child("CameraController", true, false)
	if cam_ctrl and cam_ctrl.has_method("cycle_mode"):
		cam_ctrl.cycle_mode()

func _on_btn_quick_reset_pressed() -> void:
	vehicle.reset_vehicle()

func _on_btn_close_tuning_pressed() -> void:
	toggle_tuning_panel()

# ---------------- Control hints for the device in use ----------------
# The top-bar buttons and the help line show the controls of whatever the player is using right
# now (keyboard - with their own key bindings -, gamepad or steering wheel).
func _key(action: String) -> String:
	var keys: Array = GameSettings.bindings.get(action, [])
	return GameSettings.key_name(keys[0]) if keys.size() > 0 else "—"

func _update_control_hints() -> void:
	var dev: String = GameSettings.input_device
	var help := get_node_or_null("HUD/LabelHelp") as Label
	var garage: String
	var slowmo: String
	var cam: String
	var reset: String
	var gears: String
	match dev:
		"gamepad":
			garage = "D-pad ▲"; slowmo = "D-pad ▼"; cam = "X"; reset = "Start"; gears = "RB/LB"
			if help:
				help.text = tr("RT/LT: Gaz/Fren  |  Sol çubuk: Direksiyon  |  A/B: El freni  |  RB/LB: Vites  |  L3: Turbo  |  Y: Düzelt  |  R3: Mini harita  |  Select: Oto/Manuel  |  D-pad ▲: Garaj  |  D-pad ◀▶: Araç  |  Start: Ayarlar")
		_:
			garage = _key("toggle_tuning"); slowmo = _key("slow_mo"); cam = _key("camera_view"); reset = _key("reset_car")
			gears = "%s/%s" % [_key("gear_up"), _key("gear_down")]
			if dev == "wheel":
				var cfg: Dictionary = GameSettings.wheel_config()
				gears = "H" if int(cfg.get("h1_btn", -1)) >= 0 else tr("Kulakçık")
				if help:
					help.text = tr("Pedallar: Gaz / Fren / Debriyaj  |  Kulakçık / H kolu: Vites  |  %s: Garaj  |  %s: Büyük harita  |  ESC: Ayarlar") % [garage, _key("full_map")]
			elif help:
				help.text = tr("%s/%s: Gaz/Fren  |  %s/%s: Direksiyon  |  %s: El freni  |  %s: Turbo  |  %s: Vites  |  %s: Oto/Manuel  |  %s: Garaj  |  %s: Mini harita  |  %s: Büyük harita  |  %s/%s: Far / Uzun far  |  ESC: Ayarlar") % [
					_key("throttle"), _key("brake"), _key("steer_left"), _key("steer_right"), _key("handbrake"), _key("turbo"),
					gears, _key("toggle_transmission"), garage, _key("minimap"), _key("full_map"), _key("lights"), _key("high_beam")]
	btn_quick_tuning.text = tr("🛠️ GARAJ (%s)") % garage
	btn_quick_slowmo.text = tr("⏳ AĞIR ÇEKİM (%s)") % slowmo
	btn_quick_camera.text = tr("🎥 KAMERA (%s)") % cam
	btn_quick_reset.text = tr("🔄 SIFIRLA (%s)") % reset
	btn_quick_gear_mode.text = "🕹️ " + (tr("OTOMATİK") if vehicle.is_automatic else tr("MANUEL (%s)") % gears)
