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

const CARS: Array = [
	# Real-world figures (power, torque curve, gearbox, final drive, kerb weight, rev limits and
	# factory speed limiters). "mass" replaces the body's base mass; "vmax" (km/h) = electronic
	# top-speed limiter, if the real car has one.
	{ "id": "gtr", "name": "Nisson GT-Arr R35", "class": "Sport", "legacy": 0,
		"body": { "length": 4.71, "width": 1.90, "height": 1.37, "front_overhang": 0.98, "color": Color(0.55, 0.04, 0.05), "style": "gtr" },
		"engines": [{ "label": "3.8 V6 Twin-Turbo - 570 HP", "cyl": 6, "fuel": "benzin", "hp": 570.0, "torque": 637.0,
			"tq_from": 3300.0, "tq_to": 5800.0, "power_rpm": 6800.0, "idle": 750.0, "limiter": 7100.0, "max_rpm": 7400.0,
			"turbo": 1.1, "gears": [-3.38, 0.0, 4.06, 2.30, 1.60, 1.25, 1.00, 0.80], "final": 3.38, "mass": 1750.0, "shift": 0.15, "trans": "dct" }] },
	{ "id": "challenger", "name": "Dodgy Challenjer SRT", "class": "Muscle", "legacy": 1,
		"body": { "length": 5.03, "width": 1.92, "height": 1.45, "front_overhang": 1.12, "color": Color(0.30, 0.08, 0.42), "style": "challenger" },
		"engines": [{ "label": "6.2 V8 Supercharged - 717 HP", "cyl": 8, "fuel": "benzin", "hp": 717.0, "torque": 881.0,
			"tq_from": 3000.0, "tq_to": 4800.0, "power_rpm": 6000.0, "idle": 700.0, "limiter": 6200.0, "max_rpm": 6500.0,
			"turbo": 0.0, "gears": [-3.30, 0.0, 4.71, 3.14, 2.10, 1.67, 1.29, 1.00, 0.84, 0.67], "final": 2.62, "mass": 2000.0, "shift": 0.20, "drag": 0.53, "grip": 1.25 }] },
	{ "id": "raptor", "name": "Forde Raptar Trophy", "class": "Off-Road", "legacy": 2,
		"engines": [{ "label": "6.2 V8 Race - 800 HP", "cyl": 8, "fuel": "benzin", "hp": 800.0, "torque": 760.0,
			"tq_from": 4000.0, "tq_to": 5000.0, "power_rpm": 6500.0, "idle": 950.0, "limiter": 7000.0, "max_rpm": 7300.0,
			"turbo": 0.0, "gears": [-2.08, 0.0, 2.48, 1.48, 1.00], "final": 5.00, "mass": 2700.0, "shift": 0.30 }] },
	{ "id": "chiron", "name": "Bugotti Shiron", "class": "Hyper", "legacy": 3,
		"body": { "length": 4.54, "width": 2.04, "height": 1.21, "front_overhang": 0.92, "color": Color(0.06, 0.18, 0.55), "style": "chiron" },
		"engines": [{ "label": "8.0 W16 Quad-Turbo - 1500 HP", "cyl": 16, "fuel": "benzin", "hp": 1500.0, "torque": 1600.0,
			"tq_from": 2000.0, "tq_to": 6000.0, "power_rpm": 6700.0, "idle": 850.0, "limiter": 6800.0, "max_rpm": 7100.0,
			"turbo": 1.8, "gears": [-3.40, 0.0, 3.69, 2.27, 1.59, 1.23, 1.00, 0.82, 0.68], "final": 2.83, "mass": 1995.0,
			"vmax": 420.0, "shift": 0.10, "trans": "dct" }] },
	{ "id": "supra", "name": "Toyoda Supro A80", "class": "Sport", "legacy": 4, "classic": true,
		"body": { "length": 4.52, "width": 1.81, "height": 1.27, "front_overhang": 0.95, "color": Color(0.95, 0.40, 0.04), "style": "supra" },
		"engines": [
			{ "label": "3.0 2JZ-GTE Tuned - 680 HP", "cyl": 6, "fuel": "benzin", "hp": 680.0, "torque": 800.0,
				"tq_from": 4500.0, "tq_to": 6500.0, "power_rpm": 7000.0, "idle": 850.0, "limiter": 7600.0, "max_rpm": 7900.0,
				"turbo": 1.6, "gears": [-3.28, 0.0, 3.83, 2.36, 1.69, 1.31, 1.00, 0.79], "final": 3.27, "mass": 1520.0, "shift": 0.22, "drag": 0.47 },
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
	{ "id": "egea", "name": "Fiatt Egeya Sedan", "class": "Sedan",
		"body": { "length": 4.53, "width": 1.79, "height": 1.49, "wheelbase": 2.64, "track": 1.54,
			"front_overhang": 0.88, "tire_r": 0.31, "mass": 1145.0, "cd_area": 0.44,
			"color": Color(0.92, 0.92, 0.93), "style": "egea" },
		"engines": [
			{ "label": "1.4 Fire Petrol - 95 HP", "cyl": 4, "fuel": "benzin", "hp": 95.0, "torque": 127.0,
				"tq_from": 4500.0, "tq_to": 4500.0, "power_rpm": 6000.0, "idle": 800.0, "limiter": 6300.0, "max_rpm": 6600.0,
				"turbo": 0.0, "gears": [-3.91, 0.0, 3.91, 2.24, 1.52, 1.16, 0.95], "final": 4.07, "mass_add": 0.0 },
			{ "label": "1.3 MultiJet Diesel - 95 HP", "cyl": 4, "fuel": "dizel", "hp": 95.0, "torque": 200.0,
				"tq_from": 1500.0, "tq_to": 2750.0, "power_rpm": 3750.0, "idle": 800.0, "limiter": 4800.0, "max_rpm": 5200.0,
				"turbo": 1.2, "gears": [-3.82, 0.0, 3.91, 2.12, 1.27, 0.86, 0.66], "final": 3.83, "mass_add": 75.0 },
			{ "label": "1.6 MultiJet Diesel - 120 HP", "cyl": 4, "fuel": "dizel", "hp": 120.0, "torque": 320.0,
				"tq_from": 1750.0, "tq_to": 2500.0, "power_rpm": 3750.0, "idle": 800.0, "limiter": 4800.0, "max_rpm": 5200.0,
				"turbo": 1.4, "gears": [-3.71, 0.0, 4.15, 2.12, 1.36, 0.97, 0.76, 0.62], "final": 3.29, "mass_add": 145.0 },
		] },
	{ "id": "civic", "name": "Hondo Sivic Sedan", "class": "Sedan",
		"body": { "length": 4.65, "width": 1.80, "height": 1.42, "wheelbase": 2.70, "track": 1.55,
			"front_overhang": 0.92, "tire_r": 0.31, "mass": 1275.0, "cd_area": 0.40,
			"color": Color(0.55, 0.05, 0.07), "style": "civic" },
		"engines": [
			{ "label": "1.6 i-VTEC Petrol - 125 HP", "cyl": 4, "fuel": "benzin", "hp": 125.0, "torque": 152.0,
				"tq_from": 4300.0, "tq_to": 4300.0, "power_rpm": 6500.0, "idle": 750.0, "limiter": 6800.0, "max_rpm": 7100.0,
				"turbo": 0.0, "gears": [-3.60, 0.0, 3.64, 2.08, 1.36, 1.02, 0.83, 0.69], "final": 4.11, "mass_add": 0.0 },
			{ "label": "1.5 VTEC Turbo Petrol - 182 HP", "cyl": 4, "fuel": "benzin", "hp": 182.0, "torque": 220.0,
				"tq_from": 1700.0, "tq_to": 5500.0, "power_rpm": 5500.0, "idle": 750.0, "limiter": 6500.0, "max_rpm": 6800.0,
				"turbo": 1.2, "gears": [-3.60, 0.0, 3.64, 2.08, 1.36, 1.02, 0.83, 0.69], "final": 4.35, "mass_add": 35.0 },
		] },
	{ "id": "megane", "name": "Renolt Megan Sedan", "class": "Sedan",
		"body": { "length": 4.63, "width": 1.81, "height": 1.44, "wheelbase": 2.71, "track": 1.56,
			"front_overhang": 0.90, "tire_r": 0.31, "mass": 1265.0, "cd_area": 0.42,
			"color": Color(0.33, 0.35, 0.38), "style": "megane" },
		"engines": [
			{ "label": "1.3 TCe Petrol - 140 HP", "cyl": 4, "fuel": "benzin", "hp": 140.0, "torque": 240.0,
				"tq_from": 1600.0, "tq_to": 3500.0, "power_rpm": 5000.0, "idle": 750.0, "limiter": 6000.0, "max_rpm": 6300.0,
				"turbo": 1.3, "gears": [-3.55, 0.0, 3.73, 2.05, 1.32, 0.97, 0.76, 0.63], "final": 4.13, "mass_add": 0.0 },
			{ "label": "1.5 dCi Diesel - 115 HP", "cyl": 4, "fuel": "dizel", "hp": 115.0, "torque": 260.0,
				"tq_from": 1750.0, "tq_to": 2750.0, "power_rpm": 3750.0, "idle": 800.0, "limiter": 4600.0, "max_rpm": 5000.0,
				"turbo": 1.3, "gears": [-3.55, 0.0, 3.73, 1.96, 1.23, 0.87, 0.67, 0.55], "final": 3.73, "mass_add": 40.0 },
		] },

	# --- Turkish classic (rear-wheel drive, carburettor engines, 5-speed) ---
	{ "id": "sahin", "name": "Tofash Sahin", "class": "Classic", "classic": true,
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
