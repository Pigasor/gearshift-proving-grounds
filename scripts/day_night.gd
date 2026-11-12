extends Node
# Day / night cycle: moves the sun (and a moon), colours the sky, dims the ambient light and fog,
# and switches the lamp posts / floodlights on after dusk. The time is set in Settings > Görüntü
# (Saat); with the cycle on it keeps running from there (one day = "day_length" minutes).

const DAY_MINUTES: Array[float] = [10.0, 24.0, 48.0]
var hour: float = 12.0
var _applied_hour: float = -1.0 # last Settings value, so other settings don't reset the clock
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _dark: int = -1 # lamp state last applied (-1 = not yet)

# day / sunset / night colours: [sky top, sky horizon, ground horizon, ambient]
const DAY := [Color(0.24, 0.44, 0.82), Color(0.72, 0.8, 0.88), Color(0.65, 0.72, 0.76), Color(0.72, 0.78, 0.85)]
const DUSK := [Color(0.22, 0.25, 0.48), Color(0.95, 0.55, 0.32), Color(0.55, 0.4, 0.32), Color(0.75, 0.55, 0.45)]
const NIGHT := [Color(0.012, 0.018, 0.045), Color(0.05, 0.065, 0.11), Color(0.03, 0.035, 0.05), Color(0.32, 0.38, 0.55)]

func _ready() -> void:
	var main: Node = get_parent()
	_sun = main.get_node_or_null("SunLight") as DirectionalLight3D
	var we := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment
		if _env.sky:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_moon = DirectionalLight3D.new()
	_moon.name = "MoonLight"
	_moon.light_color = Color(0.6, 0.7, 1.0)
	_moon.shadow_enabled = false
	main.add_child.call_deferred(_moon)
	apply_settings()

# Called from GameSettings.apply_scene (any setting changed): only a new "time_of_day" moves the clock
func apply_settings() -> void:
	var h: float = float(GameSettings.get_value("time_of_day"))
	if h != _applied_hour:
		_applied_hour = h
		hour = h
	_dark = -1 # re-apply the floodlight setting

func _process(delta: float) -> void:
	if bool(GameSettings.get_value("day_cycle")):
		var minutes: float = DAY_MINUTES[clampi(int(GameSettings.get_value("day_length")), 0, DAY_MINUTES.size() - 1)]
		hour = fmod(hour + delta * 24.0 / (minutes * 60.0), 24.0)
	_update_sky()

func _update_sky() -> void:
	# sun: rises in the east at 6, highest (62 deg) at 12, sets in the west at 18
	var day_ang: float = (hour - 6.0) / 12.0 * PI
	var sin_e: float = sin(day_ang) * sin(deg_to_rad(62.0))
	var e: float = asin(sin_e)
	var az: float = day_ang # 0 = east (+X) .. PI = west
	var to_sun := Vector3(cos(az) * cos(e), sin_e, -0.35 * cos(e)).normalized()
	var day_k: float = smoothstep(-0.06, 0.18, sin_e) # 0 night .. 1 day
	var dusk_k: float = clampf(1.0 - absf(sin_e) / 0.22, 0.0, 1.0) # around sunrise / sunset
	if _sun:
		_sun.visible = day_k > 0.01
		if _sun.visible:
			_sun.global_basis = Basis.looking_at(-to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
		_sun.light_energy = day_k
		_sun.light_color = Color(1.0, 0.62, 0.38).lerp(Color(1, 1, 1), smoothstep(0.05, 0.4, sin_e))
	if _moon and _moon.is_inside_tree():
		var to_moon := Vector3(-to_sun.x, maxf(-to_sun.y, 0.35), -to_sun.z).normalized()
		_moon.global_basis = Basis.looking_at(-to_moon, Vector3.UP)
		_moon.light_energy = 0.12 * (1.0 - day_k)
		_moon.visible = day_k < 0.99
	var cols: Array = []
	for i in 4:
		var c: Color = (NIGHT[i] as Color).lerp(DAY[i], day_k)
		cols.append(c.lerp(DUSK[i], dusk_k * 0.8))
	if _sky:
		_sky.sky_top_color = cols[0]
		_sky.sky_horizon_color = cols[1]
		_sky.ground_horizon_color = cols[2]
		_sky.ground_bottom_color = Color(0.15, 0.17, 0.19) * lerpf(0.15, 1.0, day_k)
	if _env:
		_env.ambient_light_color = cols[3]
		_env.ambient_light_energy = lerpf(0.08, 1.0, day_k)
		_env.fog_light_color = cols[1]
		_env.tonemap_exposure = lerpf(1.2, 1.05, day_k)
	# lamp posts and stadium floodlights: on from dusk to dawn (if enabled in Settings > Grafik)
	var dark: int = 1 if day_k < 0.5 else 0
	if dark != _dark:
		_dark = dark
		var on: bool = dark == 1 and bool(GameSettings.get_value("floodlights"))
		for l in get_tree().get_nodes_in_group("floodlights"):
			(l as Node3D).visible = on

# Settings shows the running clock (whole hours) instead of the hour it was set to
func sync_to_settings() -> void:
	_applied_hour = floorf(hour)
	GameSettings.values["time_of_day"] = _applied_hour

func is_dark() -> bool:
	return _dark == 1
