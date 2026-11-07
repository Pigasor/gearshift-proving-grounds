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

# Wheels Visualizer
@onready var bar_wheel_fl: ProgressBar = $HUD/WheelsDisplay/VBox/HBoxFront/WheelFL
@onready var bar_wheel_fr: ProgressBar = $HUD/WheelsDisplay/VBox/HBoxFront/WheelFR
@onready var bar_wheel_rl: ProgressBar = $HUD/WheelsDisplay/VBox/HBoxRear/WheelRL
@onready var bar_wheel_rr: ProgressBar = $HUD/WheelsDisplay/VBox/HBoxRear/WheelRR

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
var car_names: Array[String] = [
	"🏎️ Apex GT-R (1)",
	"🏁 Venom V8 Muscle (2)",
	"🚙 Titan 4x4 Trophy (3)",
	"⚡ Phantom Hypercar (4)",
	"🔥 Toyota Supra R-MK4 (5)",
	"👹 Goliath Canavar 4x4 (6)"
]

func _ready() -> void:
	panel_tuning.visible = false
	# Top bar buttons must never keep keyboard focus: otherwise Space (handbrake) or Enter
	# "clicks" the last pressed button again, e.g. Reset, and the car suddenly stops.
	for btn in [btn_quick_car, btn_quick_tuning, btn_quick_gear_mode, btn_quick_slowmo, btn_quick_camera, btn_quick_reset]:
		if btn:
			btn.focus_mode = Control.FOCUS_NONE
	_setup_options()
	_sync_tuning_sliders_from_vehicle()

	# Pause / settings menu (ESC)
	var menu := CanvasLayer.new()
	menu.set_script(load("res://scripts/settings_menu.gd"))
	menu.name = "SettingsMenu"
	menu.set("ui_manager", self)
	get_parent().add_child.call_deferred(menu)
	GameSettings.apply_scene_start.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	# Garage menu (rebindable, default TAB). ESC / gamepad Start open the pause & settings menu.
	if event.is_action_pressed("toggle_tuning", false, true):
		toggle_tuning_panel()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_RIGHT:
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

func _process(_delta: float) -> void:
	if vehicle == null:
		return
	_update_hud()

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

	btn_quick_gear_mode.text = "🕹️ " + ("OTOMATİK" if vehicle.is_automatic else "MANUEL (F/V)")

	# Current vehicle button label
	var v_type: int = int(vehicle.current_vehicle_type) if "current_vehicle_type" in vehicle else 0
	btn_quick_car.text = car_names[clampi(v_type, 0, car_names.size() - 1)]

	# RPM
	progress_rpm.min_value = vehicle.idle_rpm * 0.5
	progress_rpm.max_value = vehicle.max_rpm
	progress_rpm.value = vehicle.current_rpm
	label_rpm.text = "%4.0f RPM" % vehicle.current_rpm
	if vehicle.is_limiter_active:
		progress_rpm.modulate = Color(1.0, 0.15, 0.15)
	else:
		progress_rpm.modulate = Color(1.0, 1.0, 1.0)

	# Pedals
	progress_clutch.value = vehicle.clutch_pedal * 100.0
	# Read the pedals from the car (covers keyboard AND analog gamepad triggers, by how hard they're pressed)
	progress_throttle.value = vehicle.pedal_throttle * 100.0
	progress_brake.value = vehicle.pedal_brake * 100.0

	# Turbo & Shift Turbo Boost Display
	if "turbo_boost_active" in vehicle and vehicle.turbo_boost_active:
		label_turbo.text = "🔥 TURBO AKTİF! (%1.1fs) +%1.2f BAR" % [vehicle.turbo_boost_timer, vehicle.turbo_boost_bar]
		label_turbo.modulate = Color(1.0, 0.45, 0.1) # Glowing fiery orange
	elif "turbo_boost_cooldown_timer" in vehicle and vehicle.turbo_boost_cooldown_timer > 0.0:
		label_turbo.text = "⏳ SOĞUMA: %1.1fs (+%1.2f BAR)" % [vehicle.turbo_boost_cooldown_timer, vehicle.turbo_boost_bar]
		label_turbo.modulate = Color(0.65, 0.72, 0.85) # Cooldown blue-gray
	elif vehicle.turbo_enabled:
		label_turbo.text = "⚡ TURBO [SHIFT]: HAZIR (+%1.2f BAR)" % vehicle.turbo_boost_bar
		label_turbo.modulate = Color(0.25, 0.95, 1.0) # Electric neon cyan
	else:
		label_turbo.text = "⚡ NITRO [SHIFT]: HAZIR"
		label_turbo.modulate = Color(0.25, 0.95, 1.0)

	label_gforce.text = "G-LAT: %+1.2f G  |  G-LONG: %+1.2f G" % [vehicle.g_force_lateral, vehicle.g_force_longitudinal]

	# Handbrake & Slowmo
	label_handbrake.visible = vehicle.is_handbrake_active
	label_slowmo.visible = (Engine.time_scale < 0.9)

	# 4 Wheels Compression
	if vehicle.wheel_compression.size() >= 4 and vehicle.suspension_travel > 0.0:
		bar_wheel_fl.value = (vehicle.wheel_compression[0] / vehicle.suspension_travel) * 100.0
		bar_wheel_fr.value = (vehicle.wheel_compression[1] / vehicle.suspension_travel) * 100.0
		bar_wheel_rl.value = (vehicle.wheel_compression[2] / vehicle.suspension_travel) * 100.0
		bar_wheel_rr.value = (vehicle.wheel_compression[3] / vehicle.suspension_travel) * 100.0

func _setup_options() -> void:
	option_car_select.clear()
	for i in range(car_names.size()):
		option_car_select.add_item(car_names[i], i)

	option_drivetrain.clear()
	option_drivetrain.add_item("RWD (Arkadan İtiş)", 0)
	option_drivetrain.add_item("AWD (4 Çeker)", 1)
	option_drivetrain.add_item("FWD (Önden Çeker)", 2)

func _sync_tuning_sliders_from_vehicle() -> void:
	if vehicle == null:
		return

	if "current_vehicle_type" in vehicle:
		option_car_select.selected = int(vehicle.current_vehicle_type)

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
	if vehicle and vehicle.has_method("apply_vehicle_preset"):
		vehicle.apply_vehicle_preset(index)
		_sync_tuning_sliders_from_vehicle()

func _cycle_next_car() -> void:
	if vehicle and vehicle.has_method("apply_vehicle_preset"):
		var next_type: int = (int(vehicle.current_vehicle_type) + 1) % car_names.size()
		vehicle.apply_vehicle_preset(next_type)
		_sync_tuning_sliders_from_vehicle()

func _cycle_prev_car() -> void:
	if vehicle and vehicle.has_method("apply_vehicle_preset"):
		var prev_type: int = (int(vehicle.current_vehicle_type) - 1 + car_names.size()) % car_names.size()
		vehicle.apply_vehicle_preset(prev_type)
		_sync_tuning_sliders_from_vehicle()

func _on_btn_quick_car_pressed() -> void:
	_cycle_next_car()

func _on_slider_hp_value_changed(val: float) -> void:
	vehicle.peak_horsepower = val
	label_hp_val.text = "%d HP" % int(val)

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
