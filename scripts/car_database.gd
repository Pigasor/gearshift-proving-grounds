extends RefCounted
class_name CarDatabase
# Every car in the game with its engine options. Brand & model names are deliberately altered.
#
# The first six entries are the original sandbox cars ("legacy": their tuned presets and hand-built
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

const CARS: Array = [
	{ "id": "gtr", "name": "Nisan GT-Er R35", "class": "Spor", "legacy": 0,
		"engines": [{ "label": "3.8 V6 Biturbo - 565 HP", "legacy": true, "cyl": 6, "fuel": "benzin" }] },
	{ "id": "challenger", "name": "Doç Çelincır SRT", "class": "Muscle", "legacy": 1,
		"engines": [{ "label": "6.2 V8 Kompresörlü - 707 HP", "legacy": true, "cyl": 8, "fuel": "benzin" }] },
	{ "id": "raptor", "name": "Fort Raptır Trophy", "class": "Arazi", "legacy": 2,
		"engines": [{ "label": "6.2 V8 Yarış - 600 HP", "legacy": true, "cyl": 8, "fuel": "benzin" }] },
	{ "id": "chiron", "name": "Buqatti Şiron", "class": "Hiper", "legacy": 3,
		"engines": [{ "label": "8.0 W16 Quad-Turbo - 1150 HP", "legacy": true, "cyl": 16, "fuel": "benzin" }] },
	{ "id": "supra", "name": "Toyoda Süpra A80", "class": "Spor", "legacy": 4, "classic": true,
		"engines": [
			{ "label": "3.0 2JZ-GTE Modifiyeli - 680 HP", "legacy": true, "cyl": 6, "fuel": "benzin" },
			{ "label": "3.0 2JZ-GTE Stok - 320 HP", "cyl": 6, "fuel": "benzin", "hp": 320.0, "torque": 427.0,
				"tq_from": 3200.0, "tq_to": 4400.0, "power_rpm": 5600.0, "idle": 750.0, "limiter": 6800.0, "max_rpm": 7200.0,
				"turbo": 0.85, "gears": [-3.77, 0.0, 3.83, 2.36, 1.69, 1.31, 1.00, 0.79], "final": 3.27, "mass_add": -60.0 },
		] },
	{ "id": "goliath", "name": "Goliath Canavar 4x4", "class": "Canavar", "legacy": 5, "classic": true,
		"engines": [{ "label": "8.4 V8 Kompresörlü - 1500 HP", "legacy": true, "cyl": 8, "fuel": "benzin" }] },

	# --- Family sedans (front-wheel drive) ---
	{ "id": "accent", "name": "Hunday Assent Blau", "class": "Sedan",
		"body": { "length": 4.37, "width": 1.70, "height": 1.46, "wheelbase": 2.57, "track": 1.49,
			"front_overhang": 0.86, "tire_r": 0.30, "mass": 1120.0, "cd_area": 0.41,
			"color": Color(0.10, 0.22, 0.52), "style": "accent" },
		"engines": [
			{ "label": "1.4 MPI Benzin - 100 HP", "cyl": 4, "fuel": "benzin", "hp": 100.0, "torque": 133.0,
				"tq_from": 4000.0, "tq_to": 4000.0, "power_rpm": 6000.0, "idle": 800.0, "limiter": 6500.0, "max_rpm": 6800.0,
				"turbo": 0.0, "gears": [-3.58, 0.0, 3.77, 2.04, 1.29, 0.95, 0.76, 0.64], "final": 4.27, "mass_add": 0.0 },
			{ "label": "1.6 CRDi Dizel - 136 HP", "cyl": 4, "fuel": "dizel", "hp": 136.0, "torque": 300.0,
				"tq_from": 1900.0, "tq_to": 2750.0, "power_rpm": 4000.0, "idle": 780.0, "limiter": 4600.0, "max_rpm": 5000.0,
				"turbo": 1.4, "gears": [-3.58, 0.0, 3.64, 1.96, 1.19, 0.84, 0.66, 0.55], "final": 3.45, "mass_add": 110.0 },
		] },
	{ "id": "egea", "name": "Fiyat Egeya Sedan", "class": "Sedan",
		"body": { "length": 4.53, "width": 1.79, "height": 1.49, "wheelbase": 2.64, "track": 1.54,
			"front_overhang": 0.88, "tire_r": 0.31, "mass": 1145.0, "cd_area": 0.44,
			"color": Color(0.80, 0.80, 0.82), "style": "egea" },
		"engines": [
			{ "label": "1.4 Fire Benzin - 95 HP", "cyl": 4, "fuel": "benzin", "hp": 95.0, "torque": 127.0,
				"tq_from": 4500.0, "tq_to": 4500.0, "power_rpm": 6000.0, "idle": 800.0, "limiter": 6300.0, "max_rpm": 6600.0,
				"turbo": 0.0, "gears": [-3.91, 0.0, 3.91, 2.24, 1.52, 1.16, 0.95], "final": 4.07, "mass_add": 0.0 },
			{ "label": "1.3 MultiJet Dizel - 95 HP", "cyl": 4, "fuel": "dizel", "hp": 95.0, "torque": 200.0,
				"tq_from": 1500.0, "tq_to": 2750.0, "power_rpm": 3750.0, "idle": 800.0, "limiter": 4800.0, "max_rpm": 5200.0,
				"turbo": 1.2, "gears": [-3.82, 0.0, 3.91, 2.12, 1.27, 0.86, 0.66], "final": 3.83, "mass_add": 75.0 },
			{ "label": "1.6 MultiJet Dizel - 120 HP", "cyl": 4, "fuel": "dizel", "hp": 120.0, "torque": 320.0,
				"tq_from": 1750.0, "tq_to": 2500.0, "power_rpm": 3750.0, "idle": 800.0, "limiter": 4800.0, "max_rpm": 5200.0,
				"turbo": 1.4, "gears": [-3.71, 0.0, 4.15, 2.12, 1.36, 0.97, 0.76, 0.62], "final": 3.29, "mass_add": 145.0 },
		] },
	{ "id": "civic", "name": "Honde Sivik Sedan", "class": "Sedan",
		"body": { "length": 4.65, "width": 1.80, "height": 1.42, "wheelbase": 2.70, "track": 1.55,
			"front_overhang": 0.92, "tire_r": 0.31, "mass": 1275.0, "cd_area": 0.40,
			"color": Color(0.55, 0.05, 0.07), "style": "civic" },
		"engines": [
			{ "label": "1.6 i-VTEC Benzin - 125 HP", "cyl": 4, "fuel": "benzin", "hp": 125.0, "torque": 152.0,
				"tq_from": 4300.0, "tq_to": 4300.0, "power_rpm": 6500.0, "idle": 750.0, "limiter": 6800.0, "max_rpm": 7100.0,
				"turbo": 0.0, "gears": [-3.60, 0.0, 3.64, 2.08, 1.36, 1.02, 0.83, 0.69], "final": 4.11, "mass_add": 0.0 },
			{ "label": "1.5 VTEC Turbo Benzin - 182 HP", "cyl": 4, "fuel": "benzin", "hp": 182.0, "torque": 220.0,
				"tq_from": 1700.0, "tq_to": 5500.0, "power_rpm": 5500.0, "idle": 750.0, "limiter": 6500.0, "max_rpm": 6800.0,
				"turbo": 1.2, "gears": [-3.60, 0.0, 3.64, 2.08, 1.36, 1.02, 0.83, 0.69], "final": 4.35, "mass_add": 35.0 },
		] },
	{ "id": "megane", "name": "Reno Megan Sedan", "class": "Sedan",
		"body": { "length": 4.63, "width": 1.81, "height": 1.44, "wheelbase": 2.71, "track": 1.56,
			"front_overhang": 0.90, "tire_r": 0.31, "mass": 1265.0, "cd_area": 0.42,
			"color": Color(0.85, 0.35, 0.06), "style": "megane" },
		"engines": [
			{ "label": "1.3 TCe Benzin - 140 HP", "cyl": 4, "fuel": "benzin", "hp": 140.0, "torque": 240.0,
				"tq_from": 1600.0, "tq_to": 3500.0, "power_rpm": 5000.0, "idle": 750.0, "limiter": 6000.0, "max_rpm": 6300.0,
				"turbo": 1.3, "gears": [-3.55, 0.0, 3.73, 2.05, 1.32, 0.97, 0.76, 0.63], "final": 4.13, "mass_add": 0.0 },
			{ "label": "1.5 dCi Dizel - 115 HP", "cyl": 4, "fuel": "dizel", "hp": 115.0, "torque": 260.0,
				"tq_from": 1750.0, "tq_to": 2750.0, "power_rpm": 3750.0, "idle": 800.0, "limiter": 4600.0, "max_rpm": 5000.0,
				"turbo": 1.3, "gears": [-3.55, 0.0, 3.73, 1.96, 1.23, 0.87, 0.67, 0.55], "final": 3.73, "mass_add": 40.0 },
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
