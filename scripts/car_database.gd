extends RefCounted
class_name CarDatabase
# Every car in the game with its engine options. Brand & model names are deliberately altered.
#
# The first six entries are the original sandbox cars ("legacy": their suspension presets and hand-built
# bodies stay in vehicle_controller.gd). Index order must not change: lap records and the
# engine-sound profile are keyed by it.
#
# Realistic engines describe a real torque curve instead of the legacy "hp" formula:
#   hp            - peak power (PS)
#   torque        - peak torque (Nm), flat between tq_from and tq_to (turbo plateau)
#   power_rpm     - rpm of peak power
#   idle / limiter / max_rpm
#   fuel          - "benzin" or "dizel" (sound & torque shape)
#   turbo         - max boost (bar), 0 = naturally aspirated
#   gears         - [R, N, 1st, 2nd, ...] ratios, final - final drive
#   cyl           - cylinder count, mass_add - engine weight difference (kg)
#   trans         - automatic type: "tc" torque converter (default) or "dct" dual clutch
#   drag          - air drag override (0.5 * rho * Cd * A), final drives allow for the tyre size
#   grip          - tyre grip override (e.g. wide performance tyres)

# Shared per-class chassis setups (override _apply_sedan's defaults); hypercars are mid-engined
const SPORT_SETUP: Dictionary = {"tire_grip_factor": 1.25, "downforce_coefficient": 0.3, "spring_stiffness": 60000.0, "damper_bump": 4500.0,
	"damper_rebound": 6200.0, "anti_roll_stiffness": 14000.0, "brake_bias_front": 0.62, "max_steer_angle_deg": 34.0, "shift_delay_seconds": 0.10}
const HYPER_SETUP: Dictionary = {"center_of_mass": Vector3(0.0, -0.15, -0.20), "tire_grip_factor": 1.38, "downforce_coefficient": 0.8, "spring_stiffness": 80000.0, "damper_bump": 5000.0,
	"damper_rebound": 7000.0, "anti_roll_stiffness": 18000.0, "brake_bias_front": 0.58, "max_steer_angle_deg": 32.0, "shift_delay_seconds": 0.06}
const OFFROAD_SETUP: Dictionary = {"offroad_tires": true, "suspension_rest_length": 0.32, "suspension_travel": 0.25, "anti_roll_stiffness": 9000.0,
	"camera_scale": 1.15, "max_steer_angle_deg": 36.0, "tire_grip_factor": 1.0}
const CUP_SETUP: Dictionary = {"downforce_coefficient": 0.9, "tire_grip_factor": 1.35, "suspension_rest_length": 0.18, "suspension_travel": 0.10,
	"spring_stiffness": 70000.0, "damper_bump": 4500.0, "damper_rebound": 6000.0, "anti_roll_stiffness": 16000.0,
	"brake_bias_front": 0.60, "engine_inertia": 0.12, "max_steer_angle_deg": 30.0}

const CARS: Array = [
	# Real-world figures (power, torque curve, gearbox, final drive, kerb weight, rev limits and
	# factory speed limiters). "mass" replaces the body's base mass; "vmax" (km/h) = electronic
	# top-speed limiter, if the real car has one.
	{ "id": "gtr", "name": "Nisson GT-R R35", "class": "Sport", "legacy": 0,
		"body": { "length": 4.71, "width": 1.90, "height": 1.37, "front_overhang": 0.98, "color": Color(0.55, 0.04, 0.05), "style": "gtr" },
		"engines": [{ "label": "3.8 V6 Twin-Turbo - 570 HP", "cyl": 6, "fuel": "benzin", "hp": 570.0, "torque": 637.0,
			"tq_from": 3300.0, "tq_to": 5800.0, "power_rpm": 6800.0, "idle": 750.0, "limiter": 7100.0, "max_rpm": 7400.0,
			"turbo": 1.1, "gears": [-3.38, 0.0, 4.06, 2.30, 1.60, 1.25, 1.00, 0.80], "final": 3.38, "mass": 1750.0, "shift": 0.15, "trans": "dct",
				"tune": {"drag_coefficient*": 1.431, "perf_mult": 1.431, "tire_grip_factor*": 1.431} }] },
	{ "id": "challenger", "name": "Dodgy Challenger SRT Hellcat", "class": "Muscle", "legacy": 1,
		"body": { "length": 5.03, "width": 1.92, "height": 1.45, "front_overhang": 1.12, "color": Color(0.30, 0.08, 0.42), "style": "challenger" },
		"engines": [{ "label": "6.2 V8 Supercharged - 717 HP", "cyl": 8, "fuel": "benzin", "hp": 717.0, "torque": 881.0,
			"tq_from": 3000.0, "tq_to": 4800.0, "power_rpm": 6000.0, "idle": 700.0, "limiter": 6200.0, "max_rpm": 6500.0,
			"turbo": 0.0, "gears": [-3.30, 0.0, 4.71, 3.14, 2.10, 1.67, 1.29, 1.00, 0.84, 0.67], "final": 2.62, "mass": 2000.0, "shift": 0.20, "drag": 0.53, "grip": 1.25,
				"tune": {"drag_coefficient*": 1.404, "perf_mult": 1.404, "tire_grip_factor*": 1.404} }] },
	{ "id": "raptor", "name": "Forde F-150 Raptor Trophy", "class": "Off-Road", "legacy": 2,
		"body": { "length": 4.6, "width": 2.0, "height": 1.85, "front_overhang": 0.95, "color": Color(0.95, 0.45, 0.05), "style": "trophy" },
		"engines": [{ "label": "6.2 V8 Race - 800 HP", "cyl": 8, "fuel": "benzin", "hp": 800.0, "torque": 760.0,
			"tq_from": 4000.0, "tq_to": 5000.0, "power_rpm": 6500.0, "idle": 950.0, "limiter": 7000.0, "max_rpm": 7300.0,
			"turbo": 0.0, "gears": [-2.08, 0.0, 2.48, 1.48, 1.00], "final": 5.00, "mass": 2700.0, "shift": 0.30 }] },
	{ "id": "chiron", "name": "Bugotti Chiron", "class": "Hyper", "legacy": 3,
		"body": { "length": 4.54, "width": 2.04, "height": 1.21, "front_overhang": 0.92, "color": Color(0.06, 0.18, 0.55), "style": "chiron" },
		"engines": [{ "label": "8.0 W16 Quad-Turbo - 1500 HP", "cyl": 16, "fuel": "benzin", "hp": 1500.0, "torque": 1600.0,
			"tq_from": 2000.0, "tq_to": 6000.0, "power_rpm": 6700.0, "idle": 850.0, "limiter": 6800.0, "max_rpm": 7100.0,
			"turbo": 1.8, "gears": [-3.40, 0.0, 3.69, 2.27, 1.59, 1.23, 1.00, 0.82, 0.68], "final": 2.83, "mass": 1995.0,
			"vmax": 420.0, "shift": 0.10, "trans": "dct",
				"tune": {"drag_coefficient*": 0.947, "perf_mult": 0.947} }] },
	{ "id": "supra", "name": "Toyoda Supra A80", "class": "Sport", "legacy": 4, "classic": true,
		"body": { "length": 4.52, "width": 1.81, "height": 1.27, "front_overhang": 0.95, "color": Color(0.95, 0.40, 0.04), "style": "supra" },
		"engines": [
			{ "label": "3.0 2JZ-GTE Tuned - 680 HP", "cyl": 6, "fuel": "benzin", "hp": 680.0, "torque": 800.0,
				"tq_from": 4500.0, "tq_to": 6500.0, "power_rpm": 7000.0, "idle": 850.0, "limiter": 7600.0, "max_rpm": 7900.0,
				"turbo": 1.6, "gears": [-3.28, 0.0, 3.83, 2.36, 1.69, 1.31, 1.00, 0.79], "final": 3.27, "mass": 1520.0, "shift": 0.22, "drag": 0.47,
				"tune": {"drag_coefficient*": 1.289, "perf_mult": 1.289, "tire_grip_factor*": 1.289} },
			{ "label": "3.0 2JZ-GTE Stock - 320 HP", "cyl": 6, "fuel": "benzin", "hp": 320.0, "torque": 427.0,
				"tq_from": 3200.0, "tq_to": 4400.0, "power_rpm": 5600.0, "idle": 750.0, "limiter": 6800.0, "max_rpm": 7200.0,
				"turbo": 0.85, "gears": [-3.28, 0.0, 3.83, 2.36, 1.69, 1.31, 1.00, 0.79], "final": 3.27, "mass": 1490.0,
				"vmax": 250.0, "shift": 0.25 },
		] },
	{ "id": "goliath", "name": "Goliath Monster 4x4", "class": "Monster", "legacy": 5, "classic": true,
		"engines": [{ "label": "9.0 V8 Supercharged - 1500 HP", "cyl": 8, "fuel": "benzin", "hp": 1500.0, "torque": 1900.0,
			"tq_from": 4000.0, "tq_to": 5500.0, "power_rpm": 6500.0, "idle": 1100.0, "limiter": 7000.0, "max_rpm": 7300.0,
			"turbo": 0.0, "gears": [-2.20, 0.0, 2.20, 1.45, 1.00], "final": 16.85, "mass": 5400.0, "shift": 0.35,
			"vmax": 130.0 }] }, # 3-speed; top speed set so a flat-out run jumps the stunt-park gap ramp to ramp

	# --- Family sedans (front-wheel drive) ---
	{ "id": "accent", "name": "Hunday Assent Blau", "class": "Sedan",
		"body": { "length": 4.37, "width": 1.70, "height": 1.46, "wheelbase": 2.57, "track": 1.49,
			"front_overhang": 0.86, "tire_r": 0.30, "mass": 1120.0, "cd_area": 0.41,
			"color": Color(0.10, 0.22, 0.52), "style": "accent" },
		"engines": [
			{ "label": "1.4 MPI Petrol - 100 HP", "cyl": 4, "fuel": "benzin", "hp": 100.0, "torque": 133.0,
				"tq_from": 4000.0, "tq_to": 4000.0, "power_rpm": 6000.0, "idle": 800.0, "limiter": 6500.0, "max_rpm": 6800.0,
				"turbo": 0.0, "gears": [-3.58, 0.0, 3.77, 2.04, 1.29, 0.95, 0.76, 0.64], "final": 4.27, "mass_add": 0.0 },
			{ "label": "1.6 CRDi Diesel - 136 HP", "cyl": 4, "fuel": "dizel", "hp": 136.0, "torque": 300.0,
				"tq_from": 1900.0, "tq_to": 2750.0, "power_rpm": 4000.0, "idle": 780.0, "limiter": 4600.0, "max_rpm": 5000.0,
				"turbo": 1.4, "gears": [-3.58, 0.0, 3.64, 1.96, 1.19, 0.84, 0.66, 0.55], "final": 3.45, "mass_add": 110.0 },
		] },
	{ "id": "egea", "name": "Fiatt Egea Sedan", "class": "Sedan",
		"body": { "length": 4.53, "width": 1.79, "height": 1.49, "wheelbase": 2.64, "track": 1.54,
			"front_overhang": 0.88, "tire_r": 0.31, "mass": 1145.0, "cd_area": 0.44,
			"color": Color(0.92, 0.92, 0.93), "style": "egea" },
		"engines": [
			{ "label": "1.4 Fire Petrol - 95 HP", "cyl": 4, "fuel": "benzin", "hp": 95.0, "torque": 127.0,
				"tq_from": 4500.0, "tq_to": 4500.0, "power_rpm": 6000.0, "idle": 800.0, "limiter": 6300.0, "max_rpm": 6600.0,
				"turbo": 0.0, "gears": [-3.91, 0.0, 3.91, 2.24, 1.52, 1.16, 0.95], "final": 4.07, "mass_add": 0.0,
				"tune": {"drag_coefficient*": 1.109, "perf_mult": 1.109, "tire_grip_factor*": 1.109} },
			{ "label": "1.3 MultiJet Diesel - 95 HP", "cyl": 4, "fuel": "dizel", "hp": 95.0, "torque": 200.0,
				"tq_from": 1500.0, "tq_to": 2750.0, "power_rpm": 3750.0, "idle": 800.0, "limiter": 4800.0, "max_rpm": 5200.0,
				"turbo": 1.2, "gears": [-3.82, 0.0, 3.91, 2.12, 1.27, 0.86, 0.66], "final": 3.83, "mass_add": 75.0 },
			{ "label": "1.6 MultiJet Diesel - 120 HP", "cyl": 4, "fuel": "dizel", "hp": 120.0, "torque": 320.0,
				"tq_from": 1750.0, "tq_to": 2500.0, "power_rpm": 3750.0, "idle": 800.0, "limiter": 4800.0, "max_rpm": 5200.0,
				"turbo": 1.4, "gears": [-3.71, 0.0, 4.15, 2.12, 1.36, 0.97, 0.76, 0.62], "final": 3.29, "mass_add": 145.0 },
		] },
	{ "id": "civic", "name": "Hondo Civic Sedan", "class": "Sedan",
		"body": { "length": 4.65, "width": 1.80, "height": 1.42, "wheelbase": 2.70, "track": 1.55,
			"front_overhang": 0.92, "tire_r": 0.31, "mass": 1275.0, "cd_area": 0.40,
			"color": Color(0.55, 0.05, 0.07), "style": "civic" },
		"engines": [
			{ "label": "1.6 i-VTEC Petrol - 125 HP", "cyl": 4, "fuel": "benzin", "hp": 125.0, "torque": 152.0,
				"tq_from": 4300.0, "tq_to": 4300.0, "power_rpm": 6500.0, "idle": 750.0, "limiter": 6800.0, "max_rpm": 7100.0,
				"turbo": 0.0, "gears": [-3.60, 0.0, 3.64, 2.08, 1.36, 1.02, 0.83, 0.69], "final": 4.11, "mass_add": 0.0, "vtec": 4800.0,
				"tune": {"drag_coefficient*": 1.195, "perf_mult": 1.195, "tire_grip_factor*": 1.195} },
			{ "label": "1.5 VTEC Turbo Petrol - 182 HP", "cyl": 4, "fuel": "benzin", "hp": 182.0, "torque": 220.0,
				"tq_from": 1700.0, "tq_to": 5500.0, "power_rpm": 5500.0, "idle": 750.0, "limiter": 6500.0, "max_rpm": 6800.0,
				"turbo": 1.2, "gears": [-3.60, 0.0, 3.64, 2.08, 1.36, 1.02, 0.83, 0.69], "final": 4.35, "mass_add": 35.0 },
			# the legendary high-revving DOHC VTEC (Civic Type R EK9), swapped in: the cams change over at 5700 rpm
			{ "label": "1.6 B16B DOHC VTEC - 185 HP", "cyl": 4, "fuel": "benzin", "hp": 185.0, "torque": 160.0,
				"tq_from": 7300.0, "tq_to": 7500.0, "power_rpm": 8200.0, "idle": 850.0, "limiter": 8600.0, "max_rpm": 8900.0,
				"turbo": 0.0, "gears": [-3.0, 0.0, 3.23, 2.10, 1.58, 1.21, 0.94, 0.78], "final": 4.4, "mass_add": -10.0, "vtec": 5700.0 },
		] },
	{ "id": "megane", "name": "Renolt Megane Sedan", "class": "Sedan",
		"body": { "length": 4.63, "width": 1.81, "height": 1.44, "wheelbase": 2.71, "track": 1.56,
			"front_overhang": 0.90, "tire_r": 0.31, "mass": 1265.0, "cd_area": 0.42,
			"color": Color(0.33, 0.35, 0.38), "style": "megane" },
		"engines": [
			{ "label": "1.3 TCe Petrol - 140 HP", "cyl": 4, "fuel": "benzin", "hp": 140.0, "torque": 240.0,
				"tq_from": 1600.0, "tq_to": 3500.0, "power_rpm": 5000.0, "idle": 750.0, "limiter": 6000.0, "max_rpm": 6300.0,
				"turbo": 1.3, "gears": [-3.55, 0.0, 3.73, 2.05, 1.32, 0.97, 0.76, 0.63], "final": 4.13, "mass_add": 0.0,
				"tune": {"drag_coefficient*": 1.005, "perf_mult": 0.908} },
			{ "label": "1.5 dCi Diesel - 115 HP", "cyl": 4, "fuel": "dizel", "hp": 115.0, "torque": 260.0,
				"tq_from": 1750.0, "tq_to": 2750.0, "power_rpm": 3750.0, "idle": 800.0, "limiter": 4600.0, "max_rpm": 5000.0,
				"turbo": 1.3, "gears": [-3.55, 0.0, 3.73, 1.96, 1.23, 0.87, 0.67, 0.55], "final": 3.73, "mass_add": 40.0 },
		] },

	# --- Turkish classic (rear-wheel drive, carburettor engines, 5-speed) ---
	{ "id": "sahin", "name": "Tofask Sahin", "class": "Classic", "classic": true,
		"body": { "length": 4.24, "width": 1.65, "height": 1.39, "wheelbase": 2.45, "track": 1.37,
			"front_overhang": 0.82, "tire_r": 0.30, "mass": 980.0, "cd_area": 0.53, "drive": "RWD",
			"color": Color(0.70, 0.08, 0.07), "style": "sahin" },
		"engines": [
			{ "label": "1.6 Petrol - 83 HP", "cyl": 4, "fuel": "benzin", "hp": 83.0, "torque": 124.0,
				"tq_from": 3000.0, "tq_to": 3400.0, "power_rpm": 5800.0, "idle": 850.0, "limiter": 6200.0, "max_rpm": 6500.0,
				"turbo": 0.0, "gears": [-3.24, 0.0, 3.61, 2.05, 1.36, 1.00, 0.83], "final": 3.91, "mass_add": 0.0 },
			{ "label": "1.4 Petrol - 70 HP", "cyl": 4, "fuel": "benzin", "hp": 70.0, "torque": 106.0,
				"tq_from": 2900.0, "tq_to": 3200.0, "power_rpm": 5600.0, "idle": 850.0, "limiter": 6000.0, "max_rpm": 6300.0,
				"turbo": 0.0, "gears": [-3.24, 0.0, 3.61, 2.05, 1.36, 1.00, 0.83], "final": 4.10, "mass_add": -15.0 },
		] },

	# --- NASCAR Next Gen Cup car: pushrod V8, 5-speed sequential, rear-wheel drive, racing slicks ---
	{ "id": "cup", "name": "Chevrolay Camaro ZL1 Cup", "class": "Stock Car",
		"body": { "length": 5.04, "width": 2.03, "height": 1.29, "wheelbase": 2.80, "track": 1.75,
			"front_overhang": 1.05, "tire_r": 0.34, "mass": 1542.0, "cd_area": 0.48, "drive": "RWD",
			"color": Color(0.98, 0.76, 0.05), "style": "cup",
			"setup": {"downforce_coefficient": 0.9, "tire_grip_factor": 1.35, "suspension_rest_length": 0.18, "suspension_travel": 0.10,
				"spring_stiffness": 70000.0, "damper_bump": 4500.0, "damper_rebound": 6000.0, "anti_roll_stiffness": 16000.0,
				"brake_bias_front": 0.60, "engine_inertia": 0.12, "max_steer_angle_deg": 30.0} },
		"engines": [
			{ "label": "5.86 V8 Cup - 670 HP", "cyl": 8, "fuel": "benzin", "hp": 670.0, "torque": 585.0,
				"tq_from": 6500.0, "tq_to": 7500.0, "power_rpm": 8800.0, "idle": 1300.0, "limiter": 9500.0, "max_rpm": 9800.0,
				"turbo": 0.0, "gears": [-2.85, 0.0, 2.80, 1.95, 1.45, 1.17, 1.00], "final": 3.88, "trans": "dct", "shift": 0.10, "sound": "v8_race",
				"tune": {"drag_coefficient*": 1.489, "perf_mult": 1.489, "tire_grip_factor*": 1.489} },
			{ "label": "5.86 V8 Superspeedway - 510 HP", "cyl": 8, "fuel": "benzin", "hp": 510.0, "torque": 470.0,
				"tq_from": 6000.0, "tq_to": 7000.0, "power_rpm": 8500.0, "idle": 1300.0, "limiter": 9500.0, "max_rpm": 9800.0,
				"turbo": 0.0, "gears": [-2.85, 0.0, 2.80, 1.95, 1.45, 1.17, 1.00], "final": 3.30, "trans": "dct", "shift": 0.10, "sound": "v8_race" },
		] },
	# --- Farm tractor: big 6-cylinder diesel, 4WD, small front wheels, 42 km/h ---
	{ "id": "tractor", "name": "John Dear 6R 155", "class": "Tractor",
		"body": { "length": 4.95, "width": 2.55, "height": 3.05, "wheelbase": 2.76, "track": 1.95,
			"front_overhang": 1.55, "tire_r": 1.03, "mass": 7000.0, "cd_area": 1.6, "drive": "AWD",
			"color": Color(0.21, 0.49, 0.18), "style": "tractor", 
			"ground_clearance": 0.55, # clears the rocks on the mountain trail
			"setup": {"front_wheel_r": 0.72, "offroad_tires": true, "suspension_rest_length": 0.28, "suspension_travel": 0.14,
				"camera_scale": 1.6, "max_steer_angle_deg": 45.0, "wheel_inertia": 40.0, "engine_inertia": 1.2,
				"anti_roll_stiffness": 30000.0, "brake_bias_front": 0.4, "shift_delay_seconds": 0.4, "tire_grip_factor": 0.95} },
		"engines": [
			{ "label": "6.8 PowerTech Diesel - 155 HP", "cyl": 6, "fuel": "dizel", "hp": 155.0, "torque": 680.0,
				"tq_from": 1400.0, "tq_to": 1700.0, "power_rpm": 2100.0, "idle": 850.0, "limiter": 2300.0, "max_rpm": 2400.0,
				"turbo": 1.4, "gears": [-4.5, 0.0, 6.0, 4.2, 3.0, 2.15, 1.55, 1.12], "final": 16.2, "vmax": 42.0, "sound": "i6_diesel_big" },
		] },
	# --- Dune buggy (tube frame): Honda 2.4, four-wheel drive (it has to climb the mountain trail), 750 kg ---
	{ "id": "buggy", "name": "Arial Nomad", "class": "Off-Road",
		"body": { "length": 3.2, "width": 1.85, "height": 1.45, "wheelbase": 2.32, "track": 1.6,
			"front_overhang": 0.45, "tire_r": 0.37, "mass": 750.0, "cd_area": 0.75, "drive": "AWD",
			"color": Color(0.96, 0.74, 0.06), "style": "buggy", "coilovers": true, "ground_clearance": 0.42,
			"setup": {"offroad_tires": true, "suspension_rest_length": 0.35, "suspension_travel": 0.32, "spring_stiffness": 22000.0,
				"damper_bump": 1800.0, "damper_rebound": 2600.0, "anti_roll_stiffness": 4000.0, "camera_scale": 1.0,
				"max_steer_angle_deg": 36.0, "brake_bias_front": 0.6, "shift_delay_seconds": 0.12, "tire_grip_factor": 1.05} },
		"engines": [
			{ "label": "2.4 i-VTEC - 235 HP", "cyl": 4, "fuel": "benzin", "hp": 235.0, "torque": 300.0,
				"tq_from": 4300.0, "tq_to": 5200.0, "power_rpm": 7200.0, "idle": 900.0, "limiter": 7400.0, "max_rpm": 7700.0,
				"turbo": 0.0, "gears": [-3.0, 0.0, 3.27, 2.13, 1.52, 1.16, 0.92, 0.74], "final": 5.9, "vmax": 201.0, "trans": "dct",
				"tune": {"drag_coefficient*": 1.19, "perf_mult": 1.19, "tire_grip_factor*": 1.19} },
		] },

	# ======== Added cars (3 per class), appended so older indices keep their lap records ========
	# --- Sport ---
	{ "id": "porsche", "name": "Porshe 911 Turbo S", "class": "Sport",
		"body": { "length": 4.54, "width": 1.90, "height": 1.30, "wheelbase": 2.45, "track": 1.60,
			"front_overhang": 0.92, "tire_r": 0.34, "mass": 1640.0, "cd_area": 0.43, "drive": "AWD",
			"color": Color(0.74, 0.75, 0.77), "style": "porsche",
			"setup": {"center_of_mass": Vector3(0.0, -0.15, -0.30), # engine behind the rear axle
				"tire_grip_factor": 1.25, "downforce_coefficient": 0.3, "spring_stiffness": 60000.0, "damper_bump": 4500.0,
				"damper_rebound": 6200.0, "anti_roll_stiffness": 14000.0, "brake_bias_front": 0.62, "max_steer_angle_deg": 34.0, "shift_delay_seconds": 0.10} },
		"engines": [
			{ "label": "3.7 Flat-6 Twin-Turbo - 650 HP", "cyl": 6, "fuel": "benzin", "hp": 650.0, "torque": 800.0,
				"tq_from": 2500.0, "tq_to": 4000.0, "power_rpm": 6750.0, "idle": 800.0, "limiter": 7200.0, "max_rpm": 7500.0,
				"turbo": 1.2, "gears": [-3.42, 0.0, 4.89, 3.17, 2.15, 1.56, 1.18, 0.94, 0.76, 0.61], "final": 3.59, "vmax": 330.0, "trans": "dct", "sound": "gtr",
				"tune": {"drag_coefficient*": 1.24, "perf_mult": 1.24, "tire_grip_factor*": 1.24} },
		] },
	{ "id": "m4", "name": "BMV M4 Competition", "class": "Sport",
		"body": { "length": 4.79, "width": 1.89, "height": 1.39, "wheelbase": 2.86, "track": 1.62,
			"front_overhang": 0.90, "tire_r": 0.34, "mass": 1725.0, "cd_area": 0.44, "drive": "RWD",
			"color": Color(0.05, 0.33, 0.28), "style": "m4", "setup": SPORT_SETUP },
		"engines": [
			{ "label": "3.0 I6 Twin-Turbo - 510 HP", "cyl": 6, "fuel": "benzin", "hp": 510.0, "torque": 650.0,
				"tq_from": 2750.0, "tq_to": 5500.0, "power_rpm": 6250.0, "idle": 750.0, "limiter": 7200.0, "max_rpm": 7400.0,
				"turbo": 1.7, "gears": [-3.99, 0.0, 5.00, 3.20, 2.14, 1.72, 1.31, 1.00, 0.82, 0.64], "final": 3.15, "vmax": 290.0, "sound": "i6_jz",
				"tune": {"drag_coefficient*": 1.248, "perf_mult": 1.248, "tire_grip_factor*": 1.248} },
		] },
	{ "id": "zed", "name": "Nisson Z Nismo", "class": "Sport",
		"body": { "length": 4.38, "width": 1.85, "height": 1.31, "wheelbase": 2.55, "track": 1.58,
			"front_overhang": 0.88, "tire_r": 0.33, "mass": 1610.0, "cd_area": 0.42, "drive": "RWD",
			"color": Color(0.95, 0.78, 0.10), "style": "zed", "setup": SPORT_SETUP },
		"engines": [
			{ "label": "3.0 V6 Twin-Turbo - 420 HP", "cyl": 6, "fuel": "benzin", "hp": 420.0, "torque": 520.0,
				"tq_from": 2000.0, "tq_to": 5200.0, "power_rpm": 6400.0, "idle": 750.0, "limiter": 7000.0, "max_rpm": 7300.0,
				"turbo": 1.1, "gears": [-3.30, 0.0, 5.42, 3.20, 2.07, 1.67, 1.29, 1.00, 0.86, 0.73, 0.62], "final": 3.13, "vmax": 250.0, "sound": "gtr",
				"tune": {"drag_coefficient*": 1.233, "perf_mult": 1.233, "tire_grip_factor*": 1.233} },
		] },
	# --- Muscle (rear-wheel drive V8s) ---
	{ "id": "mustang", "name": "Forde Mustang GT", "class": "Muscle",
		"body": { "length": 4.81, "width": 1.92, "height": 1.38, "wheelbase": 2.72, "track": 1.60,
			"front_overhang": 0.98, "tire_r": 0.34, "mass": 1750.0, "cd_area": 0.47, "drive": "RWD",
			"color": Color(0.08, 0.20, 0.55), "style": "mustang",
			"setup": {"tire_grip_factor": 1.15, "downforce_coefficient": 0.1, "spring_stiffness": 48000.0, "damper_bump": 3800.0, "damper_rebound": 5200.0,
				"anti_roll_stiffness": 11000.0, "brake_bias_front": 0.62, "shift_delay_seconds": 0.18} },
		"engines": [
			{ "label": "5.0 V8 Coyote - 486 HP", "cyl": 8, "fuel": "benzin", "hp": 486.0, "torque": 567.0,
				"tq_from": 4250.0, "tq_to": 4900.0, "power_rpm": 7250.0, "idle": 750.0, "limiter": 7500.0, "max_rpm": 7700.0,
				"turbo": 0.0, "gears": [-4.87, 0.0, 4.70, 2.99, 2.15, 1.80, 1.52, 1.28, 1.00, 0.85, 0.69, 0.64], "final": 3.15, "vmax": 250.0, "sound": "v8_cross",
				"tune": {"drag_coefficient*": 1.25, "perf_mult": 1.25, "tire_grip_factor*": 1.25} },
		] },
	{ "id": "camaro", "name": "Chevrolay Camaro ZL1", "class": "Muscle",
		"body": { "length": 4.78, "width": 1.90, "height": 1.35, "wheelbase": 2.81, "track": 1.60,
			"front_overhang": 0.95, "tire_r": 0.34, "mass": 1795.0, "cd_area": 0.45, "drive": "RWD",
			"color": Color(0.85, 0.30, 0.04), "style": "camaro",
			"setup": {"tire_grip_factor": 1.25, "downforce_coefficient": 0.15, "spring_stiffness": 52000.0, "damper_bump": 4000.0, "damper_rebound": 5500.0,
				"anti_roll_stiffness": 12000.0, "brake_bias_front": 0.62, "shift_delay_seconds": 0.16} },
		"engines": [
			{ "label": "6.2 V8 Supercharged - 659 HP", "cyl": 8, "fuel": "benzin", "hp": 659.0, "torque": 881.0,
				"tq_from": 3600.0, "tq_to": 4500.0, "power_rpm": 6400.0, "idle": 700.0, "limiter": 6500.0, "max_rpm": 6700.0,
				"turbo": 0.0, "gears": [-4.87, 0.0, 4.70, 2.99, 2.15, 1.80, 1.52, 1.28, 1.00, 0.85, 0.69, 0.64], "final": 2.85, "sound": "v8_sc",
				"tune": {"drag_coefficient*": 1.747, "perf_mult": 1.332, "tire_grip_factor*": 1.332} },
		] },
	{ "id": "transam", "name": "Pontiak Trans Am 1977", "class": "Muscle", "classic": true,
		"body": { "length": 4.99, "width": 1.87, "height": 1.28, "wheelbase": 2.75, "track": 1.55,
			"front_overhang": 1.05, "tire_r": 0.34, "mass": 1660.0, "cd_area": 0.55, "drive": "RWD",
			"color": Color(0.04, 0.04, 0.05), "style": "transam", 
			"setup": {"tire_grip_factor": 0.95, "max_steer_angle_deg": 35.0} },
		"engines": [
			{ "label": "6.6 V8 - 200 HP", "cyl": 8, "fuel": "benzin", "hp": 200.0, "torque": 441.0,
				"tq_from": 2400.0, "tq_to": 2800.0, "power_rpm": 3600.0, "idle": 700.0, "limiter": 4800.0, "max_rpm": 5000.0,
				"turbo": 0.0, "gears": [-2.08, 0.0, 2.52, 1.52, 1.00], "final": 3.23, "sound": "v8_cross",
				"tune": {"drag_coefficient*": 0.938, "perf_mult": 0.938} },
		] },
	# --- Off-road (four-wheel drive, off-road tyres, high ground clearance) ---
	{ "id": "wrangler", "name": "Jeap Wrangler Rubicon", "class": "Off-Road",
		"body": { "length": 4.33, "width": 1.89, "height": 1.85, "wheelbase": 2.46, "track": 1.60,
			"front_overhang": 0.70, "tire_r": 0.40, "mass": 2050.0, "cd_area": 0.75, "drive": "AWD",
			"color": Color(0.20, 0.33, 0.15), "style": "wrangler", "ground_clearance": 0.40, "setup": OFFROAD_SETUP },
		"engines": [
			{ "label": "3.6 V6 Pentastar - 285 HP", "cyl": 6, "fuel": "benzin", "hp": 285.0, "torque": 353.0,
				"tq_from": 4800.0, "tq_to": 4800.0, "power_rpm": 6400.0, "idle": 700.0, "limiter": 6500.0, "max_rpm": 6700.0,
				"turbo": 0.0, "gears": [-3.53, 0.0, 4.71, 3.14, 2.10, 1.67, 1.29, 1.00, 0.84, 0.67], "final": 4.10, "vmax": 180.0, "sound": "v6",
				"tune": {"drag_coefficient*": 0.949, "perf_mult": 0.949} },
		] },
	{ "id": "landcruiser", "name": "Toyoda Land Cruiser 70", "class": "Off-Road",
		"body": { "length": 5.20, "width": 1.87, "height": 1.94, "wheelbase": 2.98, "track": 1.55,
			"front_overhang": 0.85, "tire_r": 0.40, "mass": 2350.0, "cd_area": 0.85, "drive": "AWD",
			"color": Color(0.95, 0.95, 0.92), "style": "landcruiser", "ground_clearance": 0.38, "setup": OFFROAD_SETUP },
		"engines": [
			{ "label": "4.5 V8 Diesel - 205 HP", "cyl": 8, "fuel": "dizel", "hp": 205.0, "torque": 430.0,
				"tq_from": 1200.0, "tq_to": 3200.0, "power_rpm": 3400.0, "idle": 700.0, "limiter": 3800.0, "max_rpm": 4000.0,
				"turbo": 1.3, "gears": [-4.53, 0.0, 4.53, 2.53, 1.53, 1.00, 0.80], "final": 3.91, "sound": "v8_diesel",
				"tune": {"drag_coefficient*": 1.617} },
		] },
	{ "id": "rzr", "name": "Polaros RZR Turbo", "class": "Off-Road",
		"body": { "length": 3.30, "width": 1.85, "height": 1.60, "wheelbase": 2.45, "track": 1.62,
			"front_overhang": 0.45, "tire_r": 0.40, "mass": 780.0, "cd_area": 0.80, "drive": "AWD",
			"color": Color(0.85, 0.10, 0.10), "style": "utv", "coilovers": true, "ground_clearance": 0.42,
			"setup": {"offroad_tires": true, "suspension_rest_length": 0.36, "suspension_travel": 0.34, "spring_stiffness": 23000.0,
				"damper_bump": 1900.0, "damper_rebound": 2700.0, "anti_roll_stiffness": 4000.0, "camera_scale": 1.0,
				"max_steer_angle_deg": 36.0, "brake_bias_front": 0.6, "shift_delay_seconds": 0.12, "tire_grip_factor": 1.05} },
		"engines": [
			{ "label": "1.0 Turbo - 181 HP", "cyl": 3, "fuel": "benzin", "hp": 181.0, "torque": 205.0,
				"tq_from": 5500.0, "tq_to": 7000.0, "power_rpm": 7800.0, "idle": 1200.0, "limiter": 8200.0, "max_rpm": 8500.0,
				"turbo": 1.2, "gears": [-3.0, 0.0, 3.0, 1.9, 1.3, 1.0], "final": 8.2, "vmax": 130.0, "trans": "dct", "sound": "i3_turbo",
				"tune": {"drag_coefficient*": 1.06, "perf_mult": 1.06, "tire_grip_factor*": 1.06} },
		] },
	# --- Hypercars ---
	{ "id": "jesko", "name": "Koenigseg Jesko", "class": "Hyper",
		"body": { "length": 4.61, "width": 2.03, "height": 1.21, "wheelbase": 2.70, "track": 1.70,
			"front_overhang": 0.95, "tire_r": 0.35, "mass": 1420.0, "cd_area": 0.55, "drive": "RWD",
			"color": Color(0.95, 0.95, 0.97), "style": "jesko", "setup": HYPER_SETUP },
		"engines": [
			{ "label": "5.0 V8 Twin-Turbo - 1600 HP", "cyl": 8, "fuel": "benzin", "hp": 1600.0, "torque": 1500.0,
				"tq_from": 3500.0, "tq_to": 6500.0, "power_rpm": 7800.0, "idle": 850.0, "limiter": 8500.0, "max_rpm": 8800.0,
				"turbo": 1.8, "gears": [-3.0, 0.0, 3.20, 2.43, 1.92, 1.57, 1.30, 1.10, 0.95, 0.83, 0.73], "final": 2.85, "trans": "dct", "sound": "v8_tt",
				"tune": {"drag_coefficient*": 1.25, "perf_mult": 1.25, "tire_grip_factor*": 1.25} },
		] },
	{ "id": "p1", "name": "McLaran P1", "class": "Hyper",
		"body": { "length": 4.59, "width": 1.95, "height": 1.19, "wheelbase": 2.67, "track": 1.65,
			"front_overhang": 0.98, "tire_r": 0.34, "mass": 1490.0, "cd_area": 0.52, "drive": "RWD",
			"color": Color(1.0, 0.50, 0.0), "style": "p1", "setup": HYPER_SETUP },
		"engines": [
			{ "label": "3.8 V8 Twin-Turbo Hybrid - 916 HP", "cyl": 8, "fuel": "benzin", "hp": 916.0, "torque": 900.0,
				"tq_from": 3000.0, "tq_to": 7000.0, "power_rpm": 7300.0, "idle": 850.0, "limiter": 8000.0, "max_rpm": 8300.0,
				"turbo": 1.4, "gears": [-3.0, 0.0, 3.98, 2.61, 1.91, 1.48, 1.16, 0.94, 0.73], "final": 3.31, "vmax": 350.0, "trans": "dct", "sound": "v8_tt",
				"tune": {"drag_coefficient*": 1.162, "perf_mult": 1.162, "tire_grip_factor*": 1.162} },
		] },
	{ "id": "laferrari", "name": "Ferraro LaFerrari", "class": "Hyper",
		"body": { "length": 4.70, "width": 1.99, "height": 1.12, "wheelbase": 2.65, "track": 1.70,
			"front_overhang": 1.00, "tire_r": 0.35, "mass": 1585.0, "cd_area": 0.50, "drive": "RWD",
			"color": Color(0.80, 0.02, 0.03), "style": "laferrari", "setup": HYPER_SETUP },
		"engines": [
			{ "label": "6.3 V12 Hybrid - 963 HP", "cyl": 12, "fuel": "benzin", "hp": 963.0, "torque": 900.0,
				"tq_from": 5000.0, "tq_to": 6750.0, "power_rpm": 9000.0, "idle": 1000.0, "limiter": 9250.0, "max_rpm": 9500.0,
				"turbo": 0.0, "gears": [-3.0, 0.0, 3.08, 2.19, 1.63, 1.29, 1.03, 0.84, 0.69], "final": 4.44, "vmax": 350.0, "trans": "dct", "sound": "v12",
				"tune": {"drag_coefficient*": 1.355, "perf_mult": 1.355, "tire_grip_factor*": 1.355} },
		] },
	# --- Monster trucks: Goliath's chassis (wall climbing, long-travel suspension) in their own paint ---
	{ "id": "gravedigger", "name": "Grave Digga", "class": "Monster", "legacy": 5, "classic": true, "paint": Color(0.06, 0.07, 0.06), "monster": "gravedigger", "bang": "goliath",
		"engines": [{ "label": "9.4 V8 Supercharged - 1500 HP", "cyl": 8, "fuel": "benzin", "hp": 1500.0, "torque": 1950.0,
			"tq_from": 4000.0, "tq_to": 5500.0, "power_rpm": 6500.0, "idle": 1100.0, "limiter": 7000.0, "max_rpm": 7300.0,
			"turbo": 0.0, "gears": [-2.20, 0.0, 2.20, 1.45, 1.00], "final": 16.85, "mass": 5400.0, "shift": 0.35, "vmax": 130.0, "sound": "v8_big" }] },
	{ "id": "maxd", "name": "Maxx-D", "class": "Monster", "legacy": 5, "classic": true, "paint": Color(0.70, 0.72, 0.76), "monster": "maxd", "bang": "goliath",
		"engines": [{ "label": "9.0 V8 Supercharged - 1600 HP", "cyl": 8, "fuel": "benzin", "hp": 1600.0, "torque": 2000.0,
			"tq_from": 4200.0, "tq_to": 5700.0, "power_rpm": 6700.0, "idle": 1100.0, "limiter": 7200.0, "max_rpm": 7500.0,
			"turbo": 0.0, "gears": [-2.20, 0.0, 2.20, 1.45, 1.00], "final": 16.85, "mass": 5300.0, "shift": 0.35, "vmax": 135.0, "sound": "v8_big" }] },
	{ "id": "eltoro", "name": "El Toro Loko", "class": "Monster", "legacy": 5, "classic": true, "paint": Color(0.05, 0.05, 0.06), "monster": "eltoro", "bang": "goliath",
		"engines": [{ "label": "9.0 V8 Supercharged - 1450 HP", "cyl": 8, "fuel": "benzin", "hp": 1450.0, "torque": 1850.0,
			"tq_from": 3800.0, "tq_to": 5400.0, "power_rpm": 6400.0, "idle": 1100.0, "limiter": 6900.0, "max_rpm": 7200.0,
			"turbo": 0.0, "gears": [-2.20, 0.0, 2.20, 1.45, 1.00], "final": 16.85, "mass": 5500.0, "shift": 0.35, "vmax": 128.0, "sound": "v8_big" }] },
	# --- Family sedans ---
	{ "id": "corolla", "name": "Toyoda Corolla Sedan", "class": "Sedan",
		"body": { "length": 4.63, "width": 1.78, "height": 1.46, "wheelbase": 2.70, "track": 1.53,
			"front_overhang": 0.92, "tire_r": 0.31, "mass": 1270.0, "cd_area": 0.40,
			"color": Color(0.70, 0.72, 0.75), "style": "corolla" },
		"engines": [
			{ "label": "1.6 Valvematic Petrol - 132 HP", "cyl": 4, "fuel": "benzin", "hp": 132.0, "torque": 160.0,
				"tq_from": 5200.0, "tq_to": 5200.0, "power_rpm": 6400.0, "idle": 750.0, "limiter": 6600.0, "max_rpm": 6900.0,
				"turbo": 0.0, "gears": [-3.58, 0.0, 3.54, 1.91, 1.31, 1.03, 0.82, 0.69], "final": 4.29, "mass_add": 0.0,
				"tune": {"drag_coefficient*": 1.298, "perf_mult": 1.053, "tire_grip_factor*": 1.053} },
			{ "label": "1.4 D-4D Diesel - 90 HP", "cyl": 4, "fuel": "dizel", "hp": 90.0, "torque": 205.0,
				"tq_from": 1800.0, "tq_to": 2800.0, "power_rpm": 3800.0, "idle": 800.0, "limiter": 4600.0, "max_rpm": 5000.0,
				"turbo": 1.2, "gears": [-3.58, 0.0, 3.55, 1.91, 1.19, 0.82, 0.62, 0.52], "final": 3.94, "mass_add": 60.0 },
		] },
	{ "id": "passat", "name": "Volksvagen Passat Sedan", "class": "Sedan",
		"body": { "length": 4.78, "width": 1.83, "height": 1.48, "wheelbase": 2.79, "track": 1.58,
			"front_overhang": 0.93, "tire_r": 0.32, "mass": 1450.0, "cd_area": 0.42,
			"color": Color(0.10, 0.15, 0.30), "style": "passat" },
		"engines": [
			{ "label": "1.5 TSI Petrol - 150 HP", "cyl": 4, "fuel": "benzin", "hp": 150.0, "torque": 250.0,
				"tq_from": 1500.0, "tq_to": 3500.0, "power_rpm": 5000.0, "idle": 750.0, "limiter": 6200.0, "max_rpm": 6500.0,
				"turbo": 1.2, "gears": [-3.75, 0.0, 3.76, 2.27, 1.52, 1.06, 0.82, 0.69, 0.56], "final": 4.12, "mass_add": 0.0, "trans": "dct",
				"tune": {"drag_coefficient*": 1.049, "perf_mult": 1.049, "tire_grip_factor*": 1.049} },
			{ "label": "2.0 TDI Diesel - 150 HP", "cyl": 4, "fuel": "dizel", "hp": 150.0, "torque": 360.0,
				"tq_from": 1600.0, "tq_to": 2750.0, "power_rpm": 3500.0, "idle": 800.0, "limiter": 4800.0, "max_rpm": 5100.0,
				"turbo": 1.5, "gears": [-3.75, 0.0, 3.56, 2.53, 1.59, 0.94, 0.70, 0.55], "final": 3.65, "mass_add": 90.0, "trans": "dct" },
		] },
	{ "id": "logan", "name": "Dacya Logan", "class": "Sedan",
		"body": { "length": 4.40, "width": 1.73, "height": 1.52, "wheelbase": 2.63, "track": 1.49,
			"front_overhang": 0.82, "tire_r": 0.30, "mass": 1000.0, "cd_area": 0.44,
			"color": Color(0.75, 0.40, 0.15), "style": "logan" },
		"engines": [
			{ "label": "1.0 SCe Petrol - 75 HP", "cyl": 3, "fuel": "benzin", "hp": 75.0, "torque": 95.0,
				"tq_from": 3500.0, "tq_to": 3500.0, "power_rpm": 6300.0, "idle": 800.0, "limiter": 6500.0, "max_rpm": 6800.0,
				"turbo": 0.0, "gears": [-3.55, 0.0, 3.73, 2.05, 1.32, 0.97, 0.76], "final": 4.50, "mass_add": 0.0,
				"tune": {"drag_coefficient*": 0.95, "perf_mult": 1.117, "tire_grip_factor*": 1.117} },
			{ "label": "1.5 dCi Diesel - 90 HP", "cyl": 4, "fuel": "dizel", "hp": 90.0, "torque": 220.0,
				"tq_from": 1750.0, "tq_to": 2500.0, "power_rpm": 4000.0, "idle": 800.0, "limiter": 4600.0, "max_rpm": 5000.0,
				"turbo": 1.2, "gears": [-3.55, 0.0, 3.73, 1.96, 1.23, 0.85, 0.66], "final": 3.73, "mass_add": 70.0 },
		] },
	# --- Classics (Turkish roads of the '70s-'90s) ---
	{ "id": "dogan", "name": "Tofask Dogan SLX", "class": "Classic", "classic": true,
		"body": { "length": 4.24, "width": 1.65, "height": 1.39, "wheelbase": 2.45, "track": 1.37,
			"front_overhang": 0.82, "tire_r": 0.30, "mass": 1000.0, "cd_area": 0.52, "drive": "RWD",
			"color": Color(0.20, 0.35, 0.60), "style": "dogan" },
		"engines": [
			{ "label": "1.6 i.e. Petrol - 86 HP", "cyl": 4, "fuel": "benzin", "hp": 86.0, "torque": 128.0,
				"tq_from": 3000.0, "tq_to": 3600.0, "power_rpm": 5800.0, "idle": 850.0, "limiter": 6200.0, "max_rpm": 6500.0,
				"turbo": 0.0, "gears": [-3.24, 0.0, 3.61, 2.05, 1.36, 1.00, 0.83], "final": 3.91, "mass_add": 0.0 },
		] },
	{ "id": "murat131", "name": "Murat 131 Mirafiori", "class": "Classic", "classic": true,
		"body": { "length": 4.26, "width": 1.65, "height": 1.38, "wheelbase": 2.49, "track": 1.37,
			"front_overhang": 0.80, "tire_r": 0.30, "mass": 1010.0, "cd_area": 0.53, "drive": "RWD",
			"color": Color(0.90, 0.87, 0.78), "style": "murat131" },
		"engines": [
			{ "label": "1.6 Petrol - 96 HP", "cyl": 4, "fuel": "benzin", "hp": 96.0, "torque": 128.0,
				"tq_from": 3800.0, "tq_to": 3800.0, "power_rpm": 6000.0, "idle": 850.0, "limiter": 6300.0, "max_rpm": 6600.0,
				"turbo": 0.0, "gears": [-3.24, 0.0, 3.67, 2.10, 1.36, 1.00, 0.86], "final": 3.90, "mass_add": 0.0 },
		] },
	{ "id": "toros", "name": "Renolt 12 Toros", "class": "Classic", "classic": true,
		"body": { "length": 4.40, "width": 1.64, "height": 1.43, "wheelbase": 2.44, "track": 1.31,
			"front_overhang": 0.85, "tire_r": 0.30, "mass": 900.0, "cd_area": 0.55, "drive": "FWD",
			"color": Color(0.82, 0.72, 0.30), "style": "toros" },
		"engines": [
			{ "label": "1.4 Petrol - 66 HP", "cyl": 4, "fuel": "benzin", "hp": 66.0, "torque": 105.0,
				"tq_from": 3000.0, "tq_to": 3000.0, "power_rpm": 5500.0, "idle": 850.0, "limiter": 5900.0, "max_rpm": 6200.0,
				"turbo": 0.0, "gears": [-3.08, 0.0, 3.61, 2.26, 1.48, 1.03], "final": 3.78, "mass_add": 0.0 },
		] },
	# --- Stock cars ---
	{ "id": "mustangcup", "name": "Forde Mustang Dark Horse Cup", "class": "Stock Car",
		"body": { "length": 5.04, "width": 2.03, "height": 1.29, "wheelbase": 2.80, "track": 1.75,
			"front_overhang": 1.05, "tire_r": 0.34, "mass": 1542.0, "cd_area": 0.48, "drive": "RWD",
			"color": Color(0.05, 0.25, 0.65), "style": "cup", "face": "ford", "number": "57", "setup": CUP_SETUP },
		"engines": [
			{ "label": "5.86 V8 Cup - 670 HP", "cyl": 8, "fuel": "benzin", "hp": 670.0, "torque": 585.0,
				"tq_from": 6500.0, "tq_to": 7500.0, "power_rpm": 8800.0, "idle": 1300.0, "limiter": 9500.0, "max_rpm": 9800.0,
				"turbo": 0.0, "gears": [-2.85, 0.0, 2.80, 1.95, 1.45, 1.17, 1.00], "final": 3.88, "trans": "dct", "shift": 0.10, "sound": "v8_race",
				"tune": {"drag_coefficient*": 1.489, "perf_mult": 1.489, "tire_grip_factor*": 1.489} },
		] },
	{ "id": "camrycup", "name": "Toyoda Camry XSE Cup", "class": "Stock Car",
		"body": { "length": 5.04, "width": 2.03, "height": 1.29, "wheelbase": 2.80, "track": 1.75,
			"front_overhang": 1.05, "tire_r": 0.34, "mass": 1542.0, "cd_area": 0.48, "drive": "RWD",
			"color": Color(0.85, 0.08, 0.08), "style": "cup", "face": "toyota", "number": "86", "setup": CUP_SETUP },
		"engines": [
			{ "label": "5.86 V8 Cup - 670 HP", "cyl": 8, "fuel": "benzin", "hp": 670.0, "torque": 585.0,
				"tq_from": 6500.0, "tq_to": 7500.0, "power_rpm": 8800.0, "idle": 1300.0, "limiter": 9500.0, "max_rpm": 9800.0,
				"turbo": 0.0, "gears": [-2.85, 0.0, 2.80, 1.95, 1.45, 1.17, 1.00], "final": 3.88, "trans": "dct", "shift": 0.10, "sound": "v8_race",
				"tune": {"drag_coefficient*": 1.489, "perf_mult": 1.489, "tire_grip_factor*": 1.489} },
		] },
	{ "id": "montecarlo", "name": "Chevrolay Monte Carlo 1987 Stock", "class": "Stock Car", "classic": true,
		"body": { "length": 5.10, "width": 1.83, "height": 1.30, "wheelbase": 2.79, "track": 1.55,
			"front_overhang": 1.08, "tire_r": 0.34, "mass": 1590.0, "cd_area": 0.52, "drive": "RWD",
			"color": Color(0.95, 0.95, 0.95), "style": "montecarlo", "number": "33",
			"setup": {"downforce_coefficient": 0.4, "tire_grip_factor": 1.2, "suspension_rest_length": 0.18, "suspension_travel": 0.10,
				"spring_stiffness": 60000.0, "damper_bump": 4000.0, "damper_rebound": 5500.0, "anti_roll_stiffness": 15000.0,
				"brake_bias_front": 0.60, "engine_inertia": 0.14, "max_steer_angle_deg": 30.0} },
		"engines": [
			{ "label": "5.8 V8 - 650 HP", "cyl": 8, "fuel": "benzin", "hp": 650.0, "torque": 600.0,
				"tq_from": 6500.0, "tq_to": 7500.0, "power_rpm": 8000.0, "idle": 1100.0, "limiter": 8500.0, "max_rpm": 8800.0,
				"turbo": 0.0, "gears": [-2.80, 0.0, 2.20, 1.64, 1.28, 1.00], "final": 3.70, "sound": "v8_race",
				"tune": {"drag_coefficient*": 1.422, "final_drive_ratio*": 0.889, "perf_mult": 1.422, "tire_grip_factor*": 1.422} },
		] },
	# ======== Third batch ========
	# --- Electric cars: motor straight on the wheels (one or two fixed ratios), full torque from 0 rpm ---
	{ "id": "taycan", "name": "Porshe Taycan Turbo S", "class": "Electric",
		"body": { "length": 4.96, "width": 1.97, "height": 1.38, "wheelbase": 2.90, "track": 1.68,
			"front_overhang": 0.92, "tire_r": 0.35, "mass": 2295.0, "cd_area": 0.42, "drive": "AWD", "ev": true,
			"color": Color(0.80, 0.82, 0.84), "style": "taycan",
			"setup": {"tire_grip_factor": 1.25, "downforce_coefficient": 0.25, "spring_stiffness": 75000.0, "damper_bump": 5500.0,
				"damper_rebound": 7500.0, "anti_roll_stiffness": 16000.0, "brake_bias_front": 0.62, "max_steer_angle_deg": 34.0,
				"shift_delay_seconds": 0.10, "center_of_mass": Vector3(0.0, -0.22, 0.0)} },
		"engines": [
			{ "label": "Dual Motor - 761 HP", "cyl": 0, "fuel": "elektrik", "hp": 761.0, "torque": 1050.0,
				"tq_from": 0.0, "tq_to": 5500.0, "power_rpm": 9000.0, "idle": 1.0, "limiter": 16000.0, "max_rpm": 16500.0,
				"turbo": 0.0, "gears": [-15.0, 0.0, 15.0, 8.05], "final": 1.0, "vmax": 260.0, "trans": "dct", "sound": "ev",
				"tune": {"drag_coefficient*": 0.941, "perf_mult": 0.941} },
		] },
	{ "id": "models", "name": "Tezla Model S Plaid", "class": "Electric",
		"body": { "length": 5.02, "width": 1.96, "height": 1.43, "wheelbase": 2.96, "track": 1.66,
			"front_overhang": 0.95, "tire_r": 0.35, "mass": 2162.0, "cd_area": 0.38, "drive": "AWD", "ev": true,
			"color": Color(0.08, 0.15, 0.40), "style": "models",
			"setup": {"tire_grip_factor": 1.22, "downforce_coefficient": 0.15, "spring_stiffness": 70000.0, "damper_bump": 5200.0,
				"damper_rebound": 7200.0, "anti_roll_stiffness": 15000.0, "brake_bias_front": 0.62, "center_of_mass": Vector3(0.0, -0.22, 0.0)} },
		"engines": [
			{ "label": "Tri Motor - 1020 HP", "cyl": 0, "fuel": "elektrik", "hp": 1020.0, "torque": 1420.0,
				"tq_from": 0.0, "tq_to": 6500.0, "power_rpm": 10000.0, "idle": 1.0, "limiter": 20000.0, "max_rpm": 20500.0,
				"turbo": 0.0, "gears": [-8.2, 0.0, 8.2], "final": 1.0, "vmax": 322.0, "trans": "dct", "sound": "ev",
				"tune": {"drag_coefficient*": 1.176, "perf_mult": 1.176, "tire_grip_factor*": 1.176} },
		] },
	{ "id": "model3", "name": "Tezla Model 3 Performance", "class": "Electric",
		"body": { "length": 4.72, "width": 1.85, "height": 1.44, "wheelbase": 2.88, "track": 1.58,
			"front_overhang": 0.85, "tire_r": 0.34, "mass": 1910.0, "cd_area": 0.36, "drive": "AWD", "ev": true,
			"color": Color(0.94, 0.94, 0.95), "style": "model3",
			"setup": {"tire_grip_factor": 1.15, "spring_stiffness": 60000.0, "damper_bump": 4500.0, "damper_rebound": 6200.0,
				"anti_roll_stiffness": 13000.0, "center_of_mass": Vector3(0.0, -0.22, 0.0)} },
		"engines": [
			{ "label": "Dual Motor - 460 HP", "cyl": 0, "fuel": "elektrik", "hp": 460.0, "torque": 741.0,
				"tq_from": 0.0, "tq_to": 6000.0, "power_rpm": 9000.0, "idle": 1.0, "limiter": 18000.0, "max_rpm": 18500.0,
				"turbo": 0.0, "gears": [-9.0, 0.0, 9.0], "final": 1.0, "vmax": 262.0, "trans": "dct", "sound": "ev",
				"tune": {"drag_coefficient*": 1.137, "perf_mult": 1.137, "tire_grip_factor*": 1.137} },
		] },
	{ "id": "togg", "name": "Tog T10X", "class": "Electric",
		"body": { "length": 4.60, "width": 1.89, "height": 1.68, "wheelbase": 2.89, "track": 1.62,
			"front_overhang": 0.84, "tire_r": 0.37, "mass": 2050.0, "cd_area": 0.55, "drive": "RWD", "ev": true,
			"color": Color(0.12, 0.22, 0.42), "style": "togg",
			"setup": {"suspension_rest_length": 0.28, "anti_roll_stiffness": 12000.0, "camera_scale": 1.1, "center_of_mass": Vector3(0.0, -0.20, -0.05)} },
		"engines": [
			{ "label": "V1 RWD - 218 HP", "cyl": 0, "fuel": "elektrik", "hp": 218.0, "torque": 350.0,
				"tq_from": 0.0, "tq_to": 5500.0, "power_rpm": 8000.0, "idle": 1.0, "limiter": 15000.0, "max_rpm": 15500.0,
				"turbo": 0.0, "gears": [-9.6, 0.0, 9.6], "final": 1.0, "vmax": 185.0, "trans": "dct", "sound": "ev", "mass_add": 0.0,
				"tune": {"drag_coefficient*": 1.136, "perf_mult": 1.136, "tire_grip_factor*": 1.136} },
			{ "label": "V2 4MATIC - 435 HP", "cyl": 0, "fuel": "elektrik", "hp": 435.0, "torque": 700.0,
				"tq_from": 0.0, "tq_to": 5500.0, "power_rpm": 8000.0, "idle": 1.0, "limiter": 15000.0, "max_rpm": 15500.0,
				"turbo": 0.0, "gears": [-9.6, 0.0, 9.6], "final": 1.0, "vmax": 185.0, "trans": "dct", "sound": "ev", "mass_add": 150.0, "drive": "AWD" },
		] },
	# --- Pagani Huayra: twin-turbo V12, carbon chassis ---
	{ "id": "huayra", "name": "Paganni Huayra", "class": "Hyper",
		"body": { "length": 4.61, "width": 2.04, "height": 1.17, "wheelbase": 2.80, "track": 1.70,
			"front_overhang": 0.88, "tire_r": 0.35, "mass": 1350.0, "cd_area": 0.48, "drive": "RWD",
			"color": Color(0.62, 0.64, 0.67), "style": "huayra", "setup": HYPER_SETUP },
		"engines": [
			{ "label": "6.0 V12 Twin-Turbo - 730 HP", "cyl": 12, "fuel": "benzin", "hp": 730.0, "torque": 1000.0,
				"tq_from": 2250.0, "tq_to": 4500.0, "power_rpm": 5800.0, "idle": 850.0, "limiter": 6500.0, "max_rpm": 6800.0,
				"turbo": 1.3, "gears": [-2.9, 0.0, 3.15, 2.13, 1.57, 1.21, 0.96, 0.78, 0.65], "final": 3.5, "vmax": 383.0, "trans": "dct", "sound": "v12_tt",
				"tune": {"drag_coefficient*": 0.799, "perf_mult": 1.036, "tire_grip_factor*": 1.036} },
		] },
	# --- Classics: the tiny Serce (Fiat 126, rear engine) and the Tofask Kartal estate ---
	{ "id": "serce", "name": "Fiatt Serce", "class": "Classic", "classic": true,
		"body": { "length": 3.05, "width": 1.38, "height": 1.33, "wheelbase": 1.84, "track": 1.14,
			"front_overhang": 0.55, "tire_r": 0.27, "mass": 600.0, "cd_area": 0.42, "drive": "RWD",
			"color": Color(0.18, 0.42, 0.75), "style": "serce",
			"setup": {"center_of_mass": Vector3(0.0, -0.10, -0.40), "max_steer_angle_deg": 38.0, "anti_roll_stiffness": 4000.0} },
		"engines": [
			{ "label": "0.65 2-Cyl Petrol - 24 HP", "cyl": 2, "fuel": "benzin", "hp": 24.0, "torque": 39.0,
				"tq_from": 3400.0, "tq_to": 3400.0, "power_rpm": 5000.0, "idle": 900.0, "limiter": 5500.0, "max_rpm": 5800.0,
				"turbo": 0.0, "gears": [-3.30, 0.0, 3.25, 2.07, 1.30, 0.87], "final": 4.33, "mass_add": 0.0, "sound": "i2_small",
				"tune": {"drag_coefficient*": 0.75, "final_drive_ratio*": 1.18, "perf_mult": 1.35} },
		] },
	{ "id": "kartal", "name": "Tofask Kartal", "class": "Classic", "classic": true,
		"body": { "length": 4.27, "width": 1.65, "height": 1.42, "wheelbase": 2.45, "track": 1.37,
			"front_overhang": 0.82, "tire_r": 0.30, "mass": 1060.0, "cd_area": 0.56, "drive": "RWD",
			"color": Color(0.72, 0.06, 0.08), "style": "kartal" },
		"engines": [
			{ "label": "1.6 Petrol - 83 HP", "cyl": 4, "fuel": "benzin", "hp": 83.0, "torque": 124.0,
				"tq_from": 3000.0, "tq_to": 3400.0, "power_rpm": 5800.0, "idle": 850.0, "limiter": 6200.0, "max_rpm": 6500.0,
				"turbo": 0.0, "gears": [-3.24, 0.0, 3.61, 2.05, 1.36, 1.00, 0.83], "final": 3.91, "mass_add": 0.0 },
		] },
	# --- American classics ---
	{ "id": "belair", "name": "Chevrolay Bel Air 1957", "class": "US Classic", "classic": true,
		"body": { "length": 5.06, "width": 1.86, "height": 1.52, "wheelbase": 2.92, "track": 1.48,
			"front_overhang": 0.92, "tire_r": 0.34, "mass": 1550.0, "cd_area": 0.62, "drive": "RWD",
			"color": Color(0.62, 0.86, 0.80), "style": "belair",
			"setup": {"tire_grip_factor": 0.85, "spring_stiffness": 30000.0, "damper_bump": 2200.0, "damper_rebound": 3000.0, "max_steer_angle_deg": 36.0} },
		"engines": [
			{ "label": "4.6 V8 Fuel Injection - 283 HP", "cyl": 8, "fuel": "benzin", "hp": 283.0, "torque": 393.0,
				"tq_from": 4000.0, "tq_to": 4400.0, "power_rpm": 6200.0, "idle": 650.0, "limiter": 6400.0, "max_rpm": 6600.0,
				"turbo": 0.0, "gears": [-1.82, 0.0, 1.82, 1.00], "final": 3.55, "sound": "v8_cross",
				"tune": {"drag_coefficient*": 1.763} },
		] },
	{ "id": "charger69", "name": "Dodgy Charger R/T 1969", "class": "US Classic", "classic": true,
		"body": { "length": 5.28, "width": 1.95, "height": 1.35, "wheelbase": 2.97, "track": 1.58,
			"front_overhang": 1.05, "tire_r": 0.34, "mass": 1750.0, "cd_area": 0.58, "drive": "RWD",
			"color": Color(0.03, 0.03, 0.035), "style": "charger69",
			"setup": {"tire_grip_factor": 0.90, "spring_stiffness": 36000.0, "damper_bump": 2600.0, "damper_rebound": 3500.0} },
		"engines": [
			{ "label": "7.2 V8 440 Magnum - 375 HP", "cyl": 8, "fuel": "benzin", "hp": 375.0, "torque": 651.0,
				"tq_from": 3000.0, "tq_to": 3400.0, "power_rpm": 4600.0, "idle": 700.0, "limiter": 5200.0, "max_rpm": 5400.0,
				"turbo": 0.0, "gears": [-2.20, 0.0, 2.45, 1.45, 1.00], "final": 3.23, "sound": "v8_cross",
				"tune": {"drag_coefficient*": 1.074, "perf_mult": 1.074, "tire_grip_factor*": 1.074} },
		] },
	{ "id": "gt500", "name": "Shelbi GT500 1967", "class": "US Classic", "classic": true,
		"body": { "length": 4.70, "width": 1.80, "height": 1.31, "wheelbase": 2.74, "track": 1.48,
			"front_overhang": 0.92, "tire_r": 0.33, "mass": 1520.0, "cd_area": 0.54, "drive": "RWD",
			"color": Color(0.06, 0.24, 0.14), "style": "gt500",
			"setup": {"tire_grip_factor": 0.92, "spring_stiffness": 38000.0, "damper_bump": 2800.0, "damper_rebound": 3800.0} },
		"engines": [
			{ "label": "7.0 V8 428 - 355 HP", "cyl": 8, "fuel": "benzin", "hp": 355.0, "torque": 569.0,
				"tq_from": 3000.0, "tq_to": 3400.0, "power_rpm": 5400.0, "idle": 700.0, "limiter": 5800.0, "max_rpm": 6000.0,
				"turbo": 0.0, "gears": [-2.32, 0.0, 2.32, 1.69, 1.29, 1.00], "final": 3.25, "sound": "v8_cross",
				"tune": {"drag_coefficient*": 1.12, "perf_mult": 1.117, "tire_grip_factor*": 1.117} },
		] },
	# --- Luxury ---
	{ "id": "s600", "name": "Mercedez-Benz S 600 W140", "class": "Luxury",
		"body": { "length": 5.11, "width": 1.89, "height": 1.49, "wheelbase": 3.04, "track": 1.60,
			"front_overhang": 0.92, "tire_r": 0.33, "mass": 2240.0, "cd_area": 0.48, "drive": "RWD",
			"color": Color(0.03, 0.03, 0.04), "style": "s600",
			"setup": {"spring_stiffness": 52000.0, "damper_bump": 3800.0, "damper_rebound": 5200.0, "anti_roll_stiffness": 12000.0} },
		"engines": [
			{ "label": "6.0 V12 - 394 HP", "cyl": 12, "fuel": "benzin", "hp": 394.0, "torque": 570.0,
				"tq_from": 3800.0, "tq_to": 3800.0, "power_rpm": 5200.0, "idle": 600.0, "limiter": 6000.0, "max_rpm": 6200.0,
				"turbo": 0.0, "gears": [-3.16, 0.0, 3.87, 2.25, 1.44, 1.00, 0.83], "final": 2.65, "vmax": 250.0, "sound": "v12_lux",
				"tune": {"drag_coefficient*": 1.092, "perf_mult": 1.092, "tire_grip_factor*": 1.092} },
		] },
	{ "id": "rrsport", "name": "Rainge Rover Sport 2018", "class": "Luxury",
		"body": { "length": 4.88, "width": 1.98, "height": 1.80, "wheelbase": 2.92, "track": 1.69,
			"front_overhang": 0.90, "tire_r": 0.39, "mass": 2310.0, "cd_area": 0.62, "drive": "AWD",
			"color": Color(0.04, 0.04, 0.05), "style": "rrsport", "ground_clearance": 0.28,
			"setup": {"suspension_rest_length": 0.30, "suspension_travel": 0.20, "spring_stiffness": 62000.0, "damper_bump": 4600.0,
				"damper_rebound": 6400.0, "anti_roll_stiffness": 16000.0, "camera_scale": 1.12, "max_steer_angle_deg": 36.0} },
		"engines": [
			{ "label": "5.0 V8 Supercharged - 525 HP", "cyl": 8, "fuel": "benzin", "hp": 525.0, "torque": 625.0,
				"tq_from": 2500.0, "tq_to": 5500.0, "power_rpm": 6000.0, "idle": 650.0, "limiter": 6500.0, "max_rpm": 6800.0,
				"turbo": 0.0, "gears": [-3.30, 0.0, 4.71, 3.14, 2.10, 1.67, 1.29, 1.00, 0.84, 0.67], "final": 3.54, "vmax": 225.0, "sound": "v8_sc", "mass_add": 0.0,
				"tune": {"drag_coefficient*": 0.924, "perf_mult": 0.924} },
			{ "label": "3.0 SDV6 Diesel - 306 HP", "cyl": 6, "fuel": "dizel", "hp": 306.0, "torque": 700.0,
				"tq_from": 1500.0, "tq_to": 1750.0, "power_rpm": 4000.0, "idle": 650.0, "limiter": 4500.0, "max_rpm": 4800.0,
				"turbo": 1.6, "gears": [-3.30, 0.0, 4.71, 3.14, 2.10, 1.67, 1.29, 1.00, 0.84, 0.67], "final": 3.31, "vmax": 225.0, "mass_add": -40.0, "sound": "v6_diesel" },
		] },
	# ======== More tractors ========
	{ "id": "mf8s", "name": "Masey Fergusson 8S.265", "class": "Tractor",
		"body": { "length": 5.3, "width": 2.55, "height": 3.15, "wheelbase": 2.97, "track": 2.0,
			"front_overhang": 1.6, "tire_r": 1.03, "mass": 9500.0, "cd_area": 1.7, "drive": "AWD",
			"color": Color(0.78, 0.07, 0.06), "style": "tractor", "trim": Color(0.2, 0.2, 0.22),
			"tractor": "mf", "ground_clearance": 0.55,
			"setup": {"front_wheel_r": 0.8, "offroad_tires": true, "suspension_rest_length": 0.28, "suspension_travel": 0.15,
				"camera_scale": 1.65, "max_steer_angle_deg": 45.0, "wheel_inertia": 45.0, "engine_inertia": 1.3,
				"anti_roll_stiffness": 32000.0, "brake_bias_front": 0.4, "shift_delay_seconds": 0.35, "tire_grip_factor": 0.95} },
		"engines": [
			{ "label": "7.4 AGCO Power Diesel - 265 HP", "cyl": 6, "fuel": "dizel", "hp": 265.0, "torque": 1180.0,
				"tq_from": 1300.0, "tq_to": 1500.0, "power_rpm": 1950.0, "idle": 800.0, "limiter": 2200.0, "max_rpm": 2300.0,
				"turbo": 1.6, "gears": [-4.5, 0.0, 6.0, 4.2, 3.0, 2.15, 1.55, 1.12, 0.92], "final": 16.2, "vmax": 50.0, "sound": "i6_diesel_big" },
		] },
	{ "id": "nht7", "name": "New Holand T7.315", "class": "Tractor",
		"body": { "length": 5.25, "width": 2.55, "height": 3.15, "wheelbase": 2.99, "track": 2.0,
			"front_overhang": 1.55, "tire_r": 1.0, "mass": 9000.0, "cd_area": 1.7, "drive": "AWD",
			"color": Color(0.05, 0.25, 0.62), "style": "tractor", "trim": Color(0.92, 0.92, 0.9),
			"tractor": "nh", "ground_clearance": 0.55,
			"setup": {"front_wheel_r": 0.78, "offroad_tires": true, "suspension_rest_length": 0.28, "suspension_travel": 0.15,
				"camera_scale": 1.65, "max_steer_angle_deg": 45.0, "wheel_inertia": 42.0, "engine_inertia": 1.25,
				"anti_roll_stiffness": 32000.0, "brake_bias_front": 0.4, "shift_delay_seconds": 0.35, "tire_grip_factor": 0.95} },
		"engines": [
			{ "label": "6.7 FPT NEF Diesel - 313 HP", "cyl": 6, "fuel": "dizel", "hp": 313.0, "torque": 1282.0,
				"tq_from": 1400.0, "tq_to": 1500.0, "power_rpm": 1900.0, "idle": 800.0, "limiter": 2200.0, "max_rpm": 2300.0,
				"turbo": 1.7, "gears": [-4.5, 0.0, 6.0, 4.2, 3.0, 2.15, 1.55, 1.12, 0.92], "final": 16.0, "vmax": 50.0, "sound": "i6_diesel_big" },
		] },
	{ "id": "fendt1050", "name": "Fendd 1050 Vario", "class": "Tractor",
		"body": { "length": 6.2, "width": 2.75, "height": 3.6, "wheelbase": 3.3, "track": 2.1,
			"front_overhang": 1.8, "tire_r": 1.15, "mass": 14000.0, "cd_area": 2.0, "drive": "AWD",
			"color": Color(0.42, 0.62, 0.12), "style": "tractor", "trim": Color(0.2, 0.21, 0.22),
			"tractor": "fendt", "ground_clearance": 0.6,
			"setup": {"front_wheel_r": 1.0, "offroad_tires": true, "suspension_rest_length": 0.3, "suspension_travel": 0.16,
				"camera_scale": 1.85, "max_steer_angle_deg": 42.0, "wheel_inertia": 60.0, "engine_inertia": 1.6,
				"anti_roll_stiffness": 45000.0, "brake_bias_front": 0.45, "shift_delay_seconds": 0.2, "tire_grip_factor": 0.95} },
		"engines": [
			{ "label": "12.4 MAN Diesel - 517 HP", "cyl": 6, "fuel": "dizel", "hp": 517.0, "torque": 2400.0,
				"tq_from": 1100.0, "tq_to": 1500.0, "power_rpm": 1700.0, "idle": 700.0, "limiter": 1900.0, "max_rpm": 2000.0,
				"turbo": 1.8, "gears": [-4.5, 0.0, 5.2, 3.6, 2.6, 1.9, 1.4, 1.05, 0.82], "final": 14.5, "vmax": 60.0, "sound": "i6_diesel_big" },
		] },
	# Turkish classic: no cab, small front wheels, rear drive only
	{ "id": "fiat480", "name": "Fiatt 480 Special", "class": "Tractor", "classic": true,
		"body": { "length": 3.45, "width": 1.75, "height": 2.25, "wheelbase": 2.05, "track": 1.4,
			"front_overhang": 0.85, "tire_r": 0.7, "mass": 2100.0, "cd_area": 1.2, "drive": "RWD",
			"color": Color(0.85, 0.2, 0.08), "style": "tractor", "trim": Color(0.92, 0.9, 0.85),
			"tractor": "fiat", "ground_clearance": 0.45,
			"setup": {"front_wheel_r": 0.38, "offroad_tires": true, "suspension_rest_length": 0.24, "suspension_travel": 0.12,
				"camera_scale": 1.3, "max_steer_angle_deg": 42.0, "wheel_inertia": 18.0, "engine_inertia": 0.9,
				"anti_roll_stiffness": 18000.0, "brake_bias_front": 0.3, "shift_delay_seconds": 0.5, "tire_grip_factor": 0.9} },
		"engines": [
			{ "label": "2.5 Diesel - 48 HP", "cyl": 4, "fuel": "dizel", "hp": 48.0, "torque": 160.0,
				"tq_from": 1400.0, "tq_to": 1600.0, "power_rpm": 2250.0, "idle": 700.0, "limiter": 2400.0, "max_rpm": 2500.0,
				"turbo": 0.0, "gears": [-5.0, 0.0, 7.5, 5.0, 3.4, 2.3, 1.5], "final": 15.0, "vmax": 26.0, "sound": "i4_diesel" },
		] },
	# ======== Ford Focus ========
	{ "id": "focus", "name": "Forde Focus Sedan", "class": "Sedan",
		"body": { "length": 4.65, "width": 1.83, "height": 1.47, "wheelbase": 2.70, "track": 1.57,
			"front_overhang": 0.92, "tire_r": 0.32, "mass": 1320.0, "cd_area": 0.41,
			"color": Color(0.1, 0.25, 0.55), "style": "focus" },
		"engines": [
			{ "label": "1.5 EcoBoost Petrol - 150 HP", "cyl": 3, "fuel": "benzin", "hp": 150.0, "torque": 240.0,
				"tq_from": 1600.0, "tq_to": 4000.0, "power_rpm": 6000.0, "idle": 750.0, "limiter": 6500.0, "max_rpm": 6800.0,
				"turbo": 1.1, "gears": [-3.82, 0.0, 3.73, 2.05, 1.36, 1.03, 0.82, 0.69], "final": 3.82, "mass_add": 0.0, "sound": "i3_turbo",
				"tune": {"drag_coefficient*": 1.082, "perf_mult": 0.948} },
			{ "label": "1.5 EcoBlue Diesel - 120 HP", "cyl": 4, "fuel": "dizel", "hp": 120.0, "torque": 300.0,
				"tq_from": 1750.0, "tq_to": 2250.0, "power_rpm": 3600.0, "idle": 800.0, "limiter": 4800.0, "max_rpm": 5000.0,
				"turbo": 1.4, "gears": [-3.82, 0.0, 3.73, 2.05, 1.30, 0.97, 0.76, 0.62], "final": 3.39, "mass_add": 45.0 },
		] },
]

# Chrome rim design per car (same index as CARS, append a new one with every new car; all different).
# k: spoke (straight), turbine (swept + twisted blades), twin (spoke pairs), y (Y-spokes), mesh (cross-laced),
#    dish (holes), steel (pressed steel look), slot (radial slots), aero (swept slots), snowflake,
#    moon (dome hubcap), bead (beadlock), tractor
# n: spokes / holes, w: spoke width, sw: sweep (in spoke pitches), cc: concave depth, lug: wheel nuts (1 = centre lock)
const RIMS: Array = [
	{"k": "twin", "n": 6, "w": 0.026},                         # 0 GT-R
	{"k": "y", "n": 5, "w": 0.04, "cc": 0.04},                 # 1 Hellcat
	{"k": "bead", "n": 6, "lug": 6},                           # 2 F-150 Raptor Trophy
	{"k": "turbine", "n": 10, "w": 0.03, "sw": 0.3, "cc": 0.03}, # 3 Chiron
	{"k": "spoke", "n": 5, "w": 0.055},                        # 4 Supra
	{"k": "bead", "n": 8, "lug": 8},                           # 5 Goliath
	{"k": "spoke", "n": 6, "w": 0.032, "lug": 4},              # 6 Accent
	{"k": "twin", "n": 5, "w": 0.024, "lug": 4},               # 7 Egea
	{"k": "turbine", "n": 5, "w": 0.045, "sw": 0.3},           # 8 Civic
	{"k": "spoke", "n": 7, "w": 0.035, "cc": 0.02, "lug": 4},  # 9 Megane
	{"k": "slot", "n": 8, "lug": 4},                           # 10 Sahin
	{"k": "steel", "n": 0, "lug": 1},                          # 11 Camaro Cup
	{"k": "tractor", "n": 8},                                  # 12 John Deere
	{"k": "twin", "n": 4, "w": 0.03, "lug": 4},                # 13 Nomad
	{"k": "spoke", "n": 10, "w": 0.022, "cc": 0.03, "lug": 1}, # 14 911 Turbo S
	{"k": "y", "n": 6, "w": 0.035},                            # 15 M4
	{"k": "spoke", "n": 9, "w": 0.028},                        # 16 Z Nismo
	{"k": "spoke", "n": 5, "w": 0.04, "sw": 0.2},              # 17 Mustang GT
	{"k": "twin", "n": 7, "w": 0.022, "cc": 0.02},             # 18 Camaro ZL1
	{"k": "snowflake", "n": 8},                                # 19 Trans Am
	{"k": "dish", "n": 5, "lug": 5},                           # 20 Wrangler
	{"k": "slot", "n": 6, "lug": 6},                           # 21 Land Cruiser 70
	{"k": "bead", "n": 7, "lug": 4},                           # 22 RZR
	{"k": "turbine", "n": 12, "w": 0.02, "sw": 0.5, "cc": 0.03, "lug": 1}, # 23 Jesko
	{"k": "spoke", "n": 8, "w": 0.025, "sw": 0.12, "lug": 1},  # 24 P1
	{"k": "y", "n": 7, "w": 0.03, "cc": 0.04},                 # 25 LaFerrari
	{"k": "bead", "n": 10, "lug": 8},                          # 26 Grave Digga
	{"k": "bead", "n": 12, "lug": 10},                         # 27 Maxx-D
	{"k": "bead", "n": 5, "lug": 8},                           # 28 El Toro Loko
	{"k": "turbine", "n": 8, "w": 0.03, "sw": 0.15},           # 29 Corolla
	{"k": "mesh", "n": 8, "w": 0.016},                         # 30 Passat
	{"k": "steel", "n": 6, "lug": 4},                          # 31 Logan
	{"k": "moon", "n": 0},                                     # 32 Dogan SLX
	{"k": "dish", "n": 12, "lug": 4},                          # 33 Murat 131
	{"k": "steel", "n": 4, "lug": 4},                          # 34 R12 Toros
	{"k": "slot", "n": 10, "lug": 1},                          # 35 Mustang Cup
	{"k": "steel", "n": 8, "lug": 1},                          # 36 Camry Cup
	{"k": "steel", "n": 0, "lug": 5},                          # 37 Monte Carlo
	{"k": "turbine", "n": 7, "w": 0.06, "sw": 0.2},            # 38 Taycan
	{"k": "aero", "n": 6},                                     # 39 Model S
	{"k": "turbine", "n": 9, "w": 0.035, "sw": 0.25},          # 40 Model 3
	{"k": "twin", "n": 9, "w": 0.018},                         # 41 TOGG
	{"k": "turbine", "n": 14, "w": 0.018, "sw": 0.4, "cc": 0.02, "lug": 1}, # 42 Huayra
	{"k": "moon", "n": 6},                                     # 43 Serce
	{"k": "dish", "n": 6, "lug": 4},                           # 44 Kartal
	{"k": "moon", "n": 3},                                     # 45 Bel Air (spinner)
	{"k": "slot", "n": 5, "lug": 5},                           # 46 Charger R/T (Magnum 500)
	{"k": "spoke", "n": 10, "w": 0.03, "lug": 5},              # 47 GT500
	{"k": "dish", "n": 8, "lug": 5},                           # 48 S 600
	{"k": "mesh", "n": 5, "w": 0.024},                         # 49 Range Rover Sport
	{"k": "tractor", "n": 10},                                 # 50 MF 8S
	{"k": "tractor", "n": 12},                                 # 51 New Holland T7
	{"k": "tractor", "n": 6},                                  # 52 Fendt 1050
	{"k": "tractor", "n": 4},                                  # 53 Fiat 480
	{"k": "turbine", "n": 6, "w": 0.04, "sw": 0.15, "lug": 4}, # 54 Focus
]

# Fuel tank (litres) per car, same index as CARS (append one with every new car).
# Electric cars: battery capacity in kWh.
const TANKS: Array = [
	74, 70, 136, 100, 70, 110, 43, 50, 47, 50,      # 0-9   GT-R .. Megane
	45, 68, 250, 41, 67, 59, 62, 61, 72, 80,        # 10-19 Sahin .. Trans Am
	81, 130, 36, 72, 64, 86, 110, 110, 110, 50,     # 20-29 Wrangler .. Corolla
	66, 50, 45, 50, 50, 68, 68, 83, 93, 100,        # 30-39 Passat .. Model S (kWh)
	82, 88.5, 85, 21, 45, 76, 72, 64, 100, 105,     # 40-49 Model 3 (kWh), T10X (kWh) .. RR Sport
	430, 630, 800, 50, 52,                          # 50-54 MF 8S .. Focus
]

static func count() -> int:
	return CARS.size()

static func car(i: int) -> Dictionary:
	return CARS[clampi(i, 0, CARS.size() - 1)]

static func engine(i: int, e: int) -> Dictionary:
	var engines: Array = car(i)["engines"]
	return engines[clampi(e, 0, engines.size() - 1)]

static func display_name(i: int, e: int) -> String:
	var c: Dictionary = car(i)
	if (c["engines"] as Array).size() > 1:
		return "%s %s" % [c["name"], str(engine(i, e)["label"]).split(" - ")[0]]
	return c["name"]
