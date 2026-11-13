extends RefCounted
class_name BodyBuilder
# Builds a car body procedurally from real dimensions and a per-model style.
# The side silhouette (bumper - hood - windscreen - roof - rear window - boot) is extruded across
# the width; nose, tail and glasshouse are tapered. Each style adds the model's own recognisable
# details: grille, headlight & tail-light graphics, DRL signature, spoiler, chrome, pillars.
# Car axes: +Z forward, +X left, origin = wheel mount height. Returns the tail-light materials
# (the car makes them glow when braking).

var _parent: Node3D
var _brake_mats: Array[StandardMaterial3D] = []
var exhausts: Array[Vector3] = [] # tailpipe tips drawn on this body (the car puts its smoke there)
var exhaust_up: bool = false # true: vertical stack (tractor), smoke goes up

# Silhouette: lengths are fractions of the car length from the front bumper, heights in metres
# above the ground. hood = bumper -> windscreen base, ws = windscreen run, roof = flat roof run,
# rw = rear window run (rest = boot / deck). taper_f / taper_r = plan-view rounding of nose / tail,
# tumble = glasshouse width at the roof (fraction), spoiler = "none" | "lip" | "duck" | "wing" | "hoop".
const STYLES: Dictionary = {
	# Hyundai Accent Blue (RB): raked screen, coupe-like roof arc, rising beltline, high short boot
	"accent": { "hood": 0.235, "ws": 0.185, "roof": 0.25, "rw": 0.17, "nose": 0.64, "cowl": 0.84, "belt": 0.99,
		"deck": 1.01, "taper_f": 0.13, "taper_r": 0.08, "tumble": 0.70, "spoiler": "lip" },
	# Fiat Egea / Tipo sedan: upright, boxy, long flat roof, long boot
	"egea": { "hood": 0.215, "ws": 0.150, "roof": 0.33, "rw": 0.12, "nose": 0.71, "cowl": 0.90, "belt": 0.99,
		"deck": 1.02, "taper_f": 0.07, "taper_r": 0.05, "tumble": 0.78, "spoiler": "none" },
	# Honda Civic FC sedan: low nose, long hood, fastback roof sloping into a short ducktail boot
	"civic": { "hood": 0.255, "ws": 0.190, "roof": 0.17, "rw": 0.27, "nose": 0.57, "cowl": 0.80, "belt": 0.95,
		"deck": 0.94, "taper_f": 0.14, "taper_r": 0.09, "tumble": 0.66, "spoiler": "duck" },
	# Renault Megane IV sedan: sculpted, mid-height, rounded tail
	"megane": { "hood": 0.240, "ws": 0.175, "roof": 0.25, "rw": 0.17, "nose": 0.65, "cowl": 0.86, "belt": 0.97,
		"deck": 0.99, "taper_f": 0.11, "taper_r": 0.08, "tumble": 0.72, "spoiler": "lip" },
	# Tofas Sahin (Fiat 131 based): three-box, upright screen, flat hood, flat roof, long flat boot
	"sahin": { "hood": 0.265, "ws": 0.125, "roof": 0.30, "rw": 0.10, "nose": 0.72, "cowl": 0.85, "belt": 0.91,
		"deck": 0.92, "taper_f": 0.03, "taper_r": 0.02, "tumble": 0.80, "spoiler": "none" },
	# NASCAR Next Gen Cup car: low splitter nose, long hood, fastback, tall rear spoiler blade
	"cup": { "hood": 0.33, "ws": 0.17, "roof": 0.16, "rw": 0.20, "nose": 0.50, "cowl": 0.78, "belt": 0.88,
		"deck": 0.92, "taper_f": 0.10, "taper_r": 0.05, "tumble": 0.68, "spoiler": "blade" },
	# Tractor and buggy are built from parts (_build_tractor / _build_buggy); hood/cowl here only
	# place the hood camera
	"tractor": { "hood": 0.69, "ws": 0.1, "roof": 0.1, "rw": 0.05, "nose": 1.6, "cowl": 1.95, "belt": 2.0,
		"deck": 1.5, "taper_f": 0.0, "taper_r": 0.0, "tumble": 0.9, "spoiler": "none" },
	"buggy": { "hood": 0.39, "ws": 0.1, "roof": 0.2, "rw": 0.1, "nose": 0.9, "cowl": 0.95, "belt": 1.1,
		"deck": 1.0, "taper_f": 0.0, "taper_r": 0.0, "tumble": 0.9, "spoiler": "none" },
	# Nissan GT-R R35: tall muscular coupe, C-pillar "shark fin", high tail, small wing
	"gtr": { "hood": 0.285, "ws": 0.165, "roof": 0.17, "rw": 0.22, "nose": 0.66, "cowl": 0.86, "belt": 0.98,
		"deck": 1.04, "taper_f": 0.12, "taper_r": 0.05, "tumble": 0.68, "spoiler": "wing" },
	# Toyota Supra A80: long low curvy nose, bubble cabin, big hoop wing
	"supra": { "hood": 0.330, "ws": 0.170, "roof": 0.14, "rw": 0.19, "nose": 0.55, "cowl": 0.79, "belt": 0.90,
		"deck": 0.93, "taper_f": 0.16, "taper_r": 0.10, "tumble": 0.66, "spoiler": "hoop" },
	# Dodge Challenger: long, flat, boxy muscle car
	"challenger": { "hood": 0.320, "ws": 0.145, "roof": 0.20, "rw": 0.15, "nose": 0.82, "cowl": 0.97, "belt": 1.02,
		"deck": 1.03, "taper_f": 0.04, "taper_r": 0.03, "tumble": 0.80, "spoiler": "lip" },
	# Bugatti Chiron: mid-engine, very low, cabin forward, long engine cover
	"chiron": { "hood": 0.270, "ws": 0.170, "roof": 0.10, "rw": 0.30, "nose": 0.50, "cowl": 0.72, "belt": 0.84,
		"deck": 0.93, "taper_f": 0.15, "taper_r": 0.06, "tumble": 0.64, "spoiler": "flat" },
	# Ford F-150 Raptor based trophy truck: tall nose, upright cab, short open bed
	"trophy": { "hood": 0.31, "ws": 0.12, "roof": 0.17, "rw": 0.03, "nose": 1.02, "cowl": 1.22, "belt": 1.30,
		"deck": 1.28, "taper_f": 0.04, "taper_r": 0.02, "tumble": 0.86, "spoiler": "none" },
	# ---- Added cars, each shaped after photos of the real model ----
	# Porsche 911 (992): short front trunk, long fastback sloping to a short tail
	"porsche": { "hood": 0.26, "ws": 0.17, "roof": 0.12, "rw": 0.33, "nose": 0.58, "cowl": 0.80, "belt": 0.90,
		"deck": 0.93, "taper_f": 0.18, "taper_r": 0.10, "tumble": 0.64, "spoiler": "none" },
	# BMW M4 (G82): long hood, coupe roof, short high boot
	"m4": { "hood": 0.30, "ws": 0.17, "roof": 0.17, "rw": 0.18, "nose": 0.68, "cowl": 0.88, "belt": 0.98,
		"deck": 1.02, "taper_f": 0.10, "taper_r": 0.06, "tumble": 0.68, "spoiler": "lip" },
	# Nissan Z (RZ34): very long hood, cabin far back, fastback to a stubby tail
	"zed": { "hood": 0.34, "ws": 0.16, "roof": 0.11, "rw": 0.27, "nose": 0.58, "cowl": 0.80, "belt": 0.90,
		"deck": 0.92, "taper_f": 0.14, "taper_r": 0.08, "tumble": 0.64, "spoiler": "none" },
	# Ford Mustang (S650): long flat hood, fastback roof, short squared tail
	"mustang": { "hood": 0.33, "ws": 0.16, "roof": 0.14, "rw": 0.22, "nose": 0.74, "cowl": 0.93, "belt": 1.00,
		"deck": 1.00, "taper_f": 0.08, "taper_r": 0.05, "tumble": 0.70, "spoiler": "lip" },
	# Chevrolet Camaro (6th gen): high beltline, chopped low glasshouse, short deck
	"camaro": { "hood": 0.33, "ws": 0.14, "roof": 0.16, "rw": 0.17, "nose": 0.74, "cowl": 0.95, "belt": 1.04,
		"deck": 1.04, "taper_f": 0.07, "taper_r": 0.05, "tumble": 0.74, "spoiler": "duck" },
	# Pontiac Firebird Trans Am '77: very long hood, short cabin, long flat deck with a ducktail
	"transam": { "hood": 0.37, "ws": 0.14, "roof": 0.17, "rw": 0.12, "nose": 0.70, "cowl": 0.90, "belt": 0.95,
		"deck": 0.96, "taper_f": 0.05, "taper_r": 0.03, "tumble": 0.74, "spoiler": "duck" },
	# Jeep Wrangler (JL): flat upright screen, long boxy roof, vertical tailgate
	"wrangler": { "hood": 0.27, "ws": 0.10, "roof": 0.52, "rw": 0.04, "nose": 0.95, "cowl": 1.12, "belt": 1.20,
		"deck": 1.20, "taper_f": 0.02, "taper_r": 0.02, "tumble": 0.93, "spoiler": "none" },
	# Toyota Land Cruiser 70 wagon: tall flat-sided box
	"landcruiser": { "hood": 0.24, "ws": 0.10, "roof": 0.55, "rw": 0.03, "nose": 1.02, "cowl": 1.20, "belt": 1.27,
		"deck": 1.27, "taper_f": 0.02, "taper_r": 0.01, "tumble": 0.94, "spoiler": "none" },
	# Polaris RZR: built from parts (_build_utv)
	"utv": { "hood": 0.30, "ws": 0.1, "roof": 0.3, "rw": 0.1, "nose": 0.85, "cowl": 0.95, "belt": 1.0,
		"deck": 1.0, "taper_f": 0.0, "taper_r": 0.0, "tumble": 0.9, "spoiler": "none" },
	# Koenigsegg Jesko: low wedge, teardrop cabin, long engine deck, swan-neck wing
	"jesko": { "hood": 0.27, "ws": 0.16, "roof": 0.10, "rw": 0.30, "nose": 0.50, "cowl": 0.72, "belt": 0.84,
		"deck": 0.96, "taper_f": 0.16, "taper_r": 0.06, "tumble": 0.62, "spoiler": "none" },
	# McLaren P1: very low curved nose, bubble canopy, tail rising to an active wing
	"p1": { "hood": 0.25, "ws": 0.18, "roof": 0.08, "rw": 0.33, "nose": 0.46, "cowl": 0.70, "belt": 0.80,
		"deck": 0.94, "taper_f": 0.20, "taper_r": 0.10, "tumble": 0.60, "spoiler": "none" },
	# LaFerrari: drooping nose with a centre prow, high muscular tail
	"laferrari": { "hood": 0.28, "ws": 0.17, "roof": 0.09, "rw": 0.30, "nose": 0.45, "cowl": 0.74, "belt": 0.82,
		"deck": 0.98, "taper_f": 0.20, "taper_r": 0.06, "tumble": 0.60, "spoiler": "none" },
	# Toyota Corolla (E210) sedan: low wide nose, fastback-like roof into a short boot
	"corolla": { "hood": 0.25, "ws": 0.19, "roof": 0.19, "rw": 0.23, "nose": 0.60, "cowl": 0.82, "belt": 0.95,
		"deck": 0.98, "taper_f": 0.14, "taper_r": 0.09, "tumble": 0.67, "spoiler": "lip" },
	# VW Passat (B8) sedan: long, flat, formal, crisp horizontal lines
	"passat": { "hood": 0.24, "ws": 0.17, "roof": 0.27, "rw": 0.15, "nose": 0.70, "cowl": 0.89, "belt": 1.00,
		"deck": 1.02, "taper_f": 0.08, "taper_r": 0.06, "tumble": 0.74, "spoiler": "lip" },
	# Dacia Logan (3rd gen): tall, upright, short overhangs
	"logan": { "hood": 0.24, "ws": 0.17, "roof": 0.26, "rw": 0.15, "nose": 0.74, "cowl": 0.92, "belt": 1.02,
		"deck": 1.05, "taper_f": 0.09, "taper_r": 0.06, "tumble": 0.74, "spoiler": "none" },
	# Tofas Dogan SLX: Sahin body, raked nose and screen, smoother corners
	"dogan": { "hood": 0.265, "ws": 0.14, "roof": 0.29, "rw": 0.10, "nose": 0.68, "cowl": 0.84, "belt": 0.91,
		"deck": 0.93, "taper_f": 0.06, "taper_r": 0.03, "tumble": 0.78, "spoiler": "none" },
	# Fiat 131 / Murat 131 (1974): squared three-box, upright screen, flat boot
	"murat131": { "hood": 0.27, "ws": 0.13, "roof": 0.29, "rw": 0.10, "nose": 0.73, "cowl": 0.86, "belt": 0.92,
		"deck": 0.93, "taper_f": 0.02, "taper_r": 0.02, "tumble": 0.82, "spoiler": "none" },
	# Renault 12: long sloping nose, flat roof, long boot tapering to a point
	"toros": { "hood": 0.27, "ws": 0.15, "roof": 0.26, "rw": 0.12, "nose": 0.64, "cowl": 0.84, "belt": 0.93,
		"deck": 0.95, "taper_f": 0.06, "taper_r": 0.13, "tumble": 0.78, "spoiler": "none" },
	# Chevrolet Monte Carlo SS Aerocoupe '87 stock car: long hood, formal roof, big bubble back glass
	"montecarlo": { "hood": 0.36, "ws": 0.16, "roof": 0.14, "rw": 0.21, "nose": 0.66, "cowl": 0.88, "belt": 0.95,
		"deck": 0.97, "taper_f": 0.05, "taper_r": 0.04, "tumble": 0.72, "spoiler": "lip" },
	# ---- Third batch ----
	# Porsche Taycan: very low nose between raised front wings, long cab-forward fastback
	"taycan": { "hood": 0.25, "ws": 0.19, "roof": 0.15, "rw": 0.24, "nose": 0.62, "cowl": 0.84, "belt": 0.92,
		"deck": 0.93, "taper_f": 0.15, "taper_r": 0.08, "tumble": 0.63, "spoiler": "none",
		"cowl_f": 0.27, "deck_f": 0.82, "profile": [[0, 0.6], [0.03, 0.67], [0.1, 0.74], [0.2, 0.81], [0.27, 0.87], [0.36, 1.16], [0.44, 1.35], [0.5, 1.38], [0.6, 1.34], [0.7, 1.2], [0.8, 1.02], [0.84, 0.97], [0.93, 0.95], [0.98, 0.93], [1, 0.86]] },
	# Tesla Model S: smooth grille-less nose, long liftback roof
	"models": { "hood": 0.24, "ws": 0.20, "roof": 0.16, "rw": 0.24, "nose": 0.66, "cowl": 0.86, "belt": 0.95,
		"deck": 0.98, "taper_f": 0.15, "taper_r": 0.08, "tumble": 0.66, "spoiler": "lip",
		"cowl_f": 0.28, "deck_f": 0.86, "profile": [[0, 0.58], [0.03, 0.67], [0.12, 0.77], [0.22, 0.85], [0.28, 0.9], [0.37, 1.2], [0.46, 1.4], [0.53, 1.43], [0.63, 1.4], [0.74, 1.24], [0.86, 1.02], [0.93, 1.0], [0.98, 0.97], [1, 0.9]] },
	# Tesla Model 3: short hood, big glass arc, short high boot
	"model3": { "hood": 0.23, "ws": 0.21, "roof": 0.17, "rw": 0.20, "nose": 0.62, "cowl": 0.84, "belt": 0.96,
		"deck": 0.99, "taper_f": 0.16, "taper_r": 0.09, "tumble": 0.66, "spoiler": "lip",
		"cowl_f": 0.27, "deck_f": 0.8, "profile": [[0, 0.56], [0.03, 0.66], [0.14, 0.77], [0.24, 0.86], [0.27, 0.88], [0.37, 1.22], [0.46, 1.41], [0.53, 1.44], [0.62, 1.41], [0.71, 1.25], [0.8, 1.04], [0.88, 1.02], [0.97, 1.0], [1, 0.92]] },
	# TOGG T10X: tall C-SUV, short hood, long roof, steep tailgate
	"togg": { "hood": 0.24, "ws": 0.15, "roof": 0.44, "rw": 0.10, "nose": 0.92, "cowl": 1.08, "belt": 1.14,
		"deck": 1.12, "taper_f": 0.08, "taper_r": 0.05, "tumble": 0.78, "spoiler": "lip",
		"cowl_f": 0.25, "deck_f": 0.93, "profile": [[0, 0.86], [0.03, 0.97], [0.12, 1.04], [0.22, 1.09], [0.25, 1.11], [0.33, 1.42], [0.41, 1.63], [0.47, 1.68], [0.7, 1.67], [0.82, 1.62], [0.88, 1.52], [0.93, 1.24], [0.97, 1.18], [1, 1.08]] },
	# Pagani Huayra: drooping nose, teardrop canopy, long rounded tail
	"huayra": { "hood": 0.27, "ws": 0.17, "roof": 0.10, "rw": 0.30, "nose": 0.52, "cowl": 0.74, "belt": 0.84,
		"deck": 0.92, "taper_f": 0.18, "taper_r": 0.09, "tumble": 0.60, "spoiler": "none",
		"cowl_f": 0.3, "deck_f": 0.68, "profile": [[0, 0.4], [0.04, 0.5], [0.12, 0.61], [0.22, 0.71], [0.3, 0.78], [0.38, 0.98], [0.46, 1.14], [0.52, 1.17], [0.58, 1.15], [0.64, 1.08], [0.68, 1.02], [0.8, 0.97], [0.92, 0.95], [0.98, 0.92], [1, 0.84]] },
	# Fiat 126 (Serce): tiny two-box, stubby front boot, tall round roof, engine in the tail
	"serce": { "hood": 0.17, "ws": 0.14, "roof": 0.38, "rw": 0.10, "nose": 0.70, "cowl": 0.80, "belt": 0.86,
		"deck": 0.84, "taper_f": 0.09, "taper_r": 0.08, "tumble": 0.80, "spoiler": "none",
		"cowl_f": 0.21, "deck_f": 0.8, "profile": [[0, 0.58], [0.03, 0.68], [0.1, 0.74], [0.18, 0.77], [0.21, 0.8], [0.29, 1.12], [0.36, 1.3], [0.42, 1.33], [0.64, 1.32], [0.7, 1.24], [0.78, 0.98], [0.81, 0.92], [0.92, 0.87], [0.98, 0.85], [1, 0.79]] },
	# Tofas Kartal: the Sahin with a long estate roof and an upright tailgate
	"kartal": { "hood": 0.25, "ws": 0.13, "roof": 0.52, "rw": 0.04, "nose": 0.72, "cowl": 0.85, "belt": 0.92,
		"deck": 0.92, "taper_f": 0.03, "taper_r": 0.02, "tumble": 0.82, "spoiler": "none",
		"cowl_f": 0.27, "deck_f": 0.985, "profile": [[0, 0.7], [0.03, 0.78], [0.14, 0.82], [0.25, 0.85], [0.27, 0.86], [0.34, 1.22], [0.39, 1.38], [0.44, 1.42], [0.92, 1.41], [0.95, 1.34], [0.985, 0.96], [1, 0.92]] },
	# Chevrolet Bel Air '57: long flat hood, pillarless hardtop, long deck ending in tail fins
	"belair": { "hood": 0.29, "ws": 0.15, "roof": 0.26, "rw": 0.10, "nose": 0.82, "cowl": 0.96, "belt": 1.0,
		"deck": 0.98, "taper_f": 0.04, "taper_r": 0.02, "tumble": 0.80, "spoiler": "none",
		"cowl_f": 0.31, "deck_f": 0.7, "profile": [[0, 0.84], [0.03, 0.92], [0.15, 0.96], [0.28, 0.98], [0.31, 1.0], [0.37, 1.32], [0.41, 1.48], [0.46, 1.52], [0.61, 1.5], [0.65, 1.36], [0.7, 1.04], [0.8, 1.01], [0.92, 1.0], [0.98, 1.02], [1, 0.95]] },
	# Dodge Charger '69: "coke bottle", very long hood, short roof, tunnelled back glass, long deck
	"charger69": { "hood": 0.34, "ws": 0.14, "roof": 0.15, "rw": 0.15, "nose": 0.76, "cowl": 0.92, "belt": 0.97,
		"deck": 0.97, "taper_f": 0.03, "taper_r": 0.03, "tumble": 0.74, "spoiler": "none",
		"cowl_f": 0.36, "deck_f": 0.68, "profile": [[0, 0.76], [0.03, 0.85], [0.18, 0.9], [0.33, 0.93], [0.36, 0.95], [0.42, 1.2], [0.47, 1.33], [0.51, 1.35], [0.6, 1.33], [0.64, 1.22], [0.68, 1.0], [0.8, 0.99], [0.95, 0.98], [1, 0.93]] },
	# Shelby GT500 '67: long hood, fastback sloping into a ducktail
	"gt500": { "hood": 0.33, "ws": 0.15, "roof": 0.12, "rw": 0.23, "nose": 0.74, "cowl": 0.90, "belt": 0.94,
		"deck": 0.96, "taper_f": 0.06, "taper_r": 0.04, "tumble": 0.72, "spoiler": "duck",
		"cowl_f": 0.36, "deck_f": 0.86, "profile": [[0, 0.7], [0.03, 0.81], [0.18, 0.86], [0.33, 0.89], [0.36, 0.9], [0.43, 1.17], [0.49, 1.29], [0.53, 1.31], [0.58, 1.29], [0.7, 1.16], [0.86, 0.98], [0.94, 0.99], [0.98, 1.01], [1, 0.95]] },
	# Mercedes-Benz S 600 (W140): big formal three-box saloon, tall glasshouse
	"s600": { "hood": 0.27, "ws": 0.16, "roof": 0.27, "rw": 0.13, "nose": 0.74, "cowl": 0.92, "belt": 1.0,
		"deck": 1.02, "taper_f": 0.05, "taper_r": 0.05, "tumble": 0.78, "spoiler": "none",
		"cowl_f": 0.29, "deck_f": 0.79, "profile": [[0, 0.72], [0.03, 0.84], [0.15, 0.9], [0.26, 0.94], [0.29, 0.95], [0.36, 1.26], [0.42, 1.45], [0.47, 1.49], [0.66, 1.47], [0.71, 1.36], [0.79, 1.05], [0.88, 1.06], [0.97, 1.04], [1, 0.97]] },
	# Range Rover Sport (L494): tall clamshell hood, sloping roof, floating black roof
	"rrsport": { "hood": 0.24, "ws": 0.13, "roof": 0.47, "rw": 0.10, "nose": 0.98, "cowl": 1.12, "belt": 1.2,
		"deck": 1.18, "taper_f": 0.07, "taper_r": 0.05, "tumble": 0.80, "spoiler": "lip",
		"cowl_f": 0.25, "deck_f": 0.955, "profile": [[0, 0.96], [0.03, 1.08], [0.14, 1.14], [0.23, 1.17], [0.25, 1.18], [0.32, 1.5], [0.39, 1.74], [0.45, 1.8], [0.75, 1.77], [0.86, 1.71], [0.91, 1.58], [0.955, 1.28], [0.98, 1.22], [1, 1.14]] },
}

var paint: StandardMaterial3D
var glass: StandardMaterial3D
var black: StandardMaterial3D
var chrome: StandardMaterial3D
var head: StandardMaterial3D
var drl: StandardMaterial3D
var tail: StandardMaterial3D
var amber: StandardMaterial3D
var plate: StandardMaterial3D
var lens: StandardMaterial3D

# Key stations (filled in build)
var L: float
var W: float
var H: float
var wb: float
var zf: float
var zr: float
var g: float
var hw: float
var s: Dictionary
var cowl_z: float
var ws_top_z: float
var roof_rear_z: float
var deck_z: float
var taper: Callable
var tire_rad: float = 0.3
var car_number: String = "24" # race number on stock cars
var _prof: PackedVector2Array = PackedVector2Array() # traced top silhouette (z, height), front to back

# Height of the traced silhouette at z
func _prof_h(z: float) -> float:
	if _prof.is_empty():
		return 0.0
	if z >= _prof[0].x:
		return _prof[0].y
	for k in range(_prof.size() - 1):
		if z >= _prof[k + 1].x:
			return lerpf(_prof[k].y, _prof[k + 1].y, (_prof[k].x - z) / maxf(_prof[k].x - _prof[k + 1].x, 0.001))
	return _prof[_prof.size() - 1].y
var tractor_kind: String = "jd" # tractor brand details (see _build_tractor)
var trim_col: Color = Color(0.98, 0.82, 0.08) # tractor stripe / badge / trim colour
var front_r_vis: float = 0.7 # tractor front wheel radius (visual)

func build(parent: Node3D, b: Dictionary, ground_y: float, tire_r: float) -> Array[StandardMaterial3D]:
	_parent = parent
	_brake_mats.clear()
	exhausts.clear()
	s = STYLES.get(str(b.get("style", "accent")), STYLES["accent"])
	L = float(b["length"])
	W = float(b["width"])
	H = float(b["height"])
	wb = float(b["wheelbase"])
	zf = wb * 0.5 + float(b["front_overhang"])
	zr = zf - L
	g = ground_y
	hw = W * 0.5 - 0.02
	tire_rad = tire_r
	car_number = str(b.get("number", "24"))
	tractor_kind = str(b.get("tractor", "jd"))
	trim_col = b.get("trim", Color(0.98, 0.82, 0.08))
	front_r_vis = float(b.get("setup", {}).get("front_wheel_r", tire_r))
	_make_materials(b["color"])

	cowl_z = zf - L * float(s["hood"])
	ws_top_z = cowl_z - L * float(s["ws"])
	roof_rear_z = ws_top_z - L * float(s["roof"])
	deck_z = roof_rear_z - L * float(s["rw"])
	exhaust_up = false
	match str(b.get("style", "")):
		"tractor":
			_build_tractor(tire_r)
			return _brake_mats
		"buggy":
			_build_buggy(tire_r)
			return _brake_mats
		"utv":
			_build_utv(tire_r)
			return _brake_mats
	var nose_h: float = float(s["nose"])
	var cowl_h: float = float(s["cowl"])
	var belt_h: float = float(s["belt"])
	var deck_h: float = float(s["deck"])
	# A style traced from side photos gives the whole top silhouette ("profile": [fraction of the
	# length from the front, height], front bumper to rear bumper) and where the glass starts / ends
	_prof = PackedVector2Array()
	if s.has("profile"):
		for q in s["profile"]:
			_prof.append(Vector2(zf - L * float(q[0]), float(q[1])))
		cowl_z = zf - L * float(s["cowl_f"])
		deck_z = zf - L * float(s["deck_f"])
		var top: float = 0.0
		for q in _prof:
			top = maxf(top, q.y)
		var first: bool = true
		for q in _prof: # the roof: from the first to the last point near the top
			if q.y >= top - 0.06:
				if first:
					ws_top_z = q.x
					first = false
				roof_rear_z = q.x
		nose_h = _prof_h(zf - 0.05)
		cowl_h = _prof_h(cowl_z)
		deck_h = _prof_h(zr + 0.08)
	var tf: float = float(s["taper_f"])
	var trr: float = float(s["taper_r"])

	# --- Lower body: side profile with wheel arches ---
	var arch_r: float = tire_r + 0.06
	var lower := PackedVector2Array()
	lower.append(Vector2(zf - 0.10, 0.20))
	lower.append(Vector2(zf - 0.01, 0.32))
	lower.append(Vector2(zf + 0.01, 0.48))
	if _prof.is_empty():
		lower.append(Vector2(zf - 0.05, nose_h - 0.03))
		lower.append(Vector2(zf - 0.28, nose_h + 0.05))
		lower.append(Vector2(lerpf(zf, cowl_z, 0.6), lerpf(nose_h + 0.05, cowl_h, 0.75)))
		lower.append(Vector2(cowl_z, cowl_h))
		lower.append(Vector2(deck_z, belt_h))
		lower.append(Vector2(deck_z - 0.12, deck_h))
		lower.append(Vector2(zr + 0.07, deck_h + (0.03 if str(s["spoiler"]) == "duck" else -0.01)))
		lower.append(Vector2(zr, deck_h - 0.12))
	else:
		# traced silhouette: hood / nose, the beltline under the glass, then boot / tail
		for q in _prof:
			if q.x > cowl_z + 0.01:
				lower.append(Vector2(minf(q.x, zf - 0.02), q.y))
		lower.append(Vector2(cowl_z, cowl_h))
		lower.append(Vector2(deck_z, belt_h))
		for q in _prof:
			if q.x < deck_z - 0.01:
				lower.append(Vector2(maxf(q.x, zr + 0.02), q.y))
	lower.append(Vector2(zr - 0.01, 0.48))
	lower.append(Vector2(zr + 0.05, 0.24))
	# Keep the upper outline clear of the wheel arches (a low nose / short hood could dip into
	# the arch, the outline then crossed itself and the whole side panel was not drawn)
	var n_top: int = lower.size()
	for k in range(1, n_top - 1):
		var p: Vector2 = lower[k]
		for zc in [-wb * 0.5, wb * 0.5]:
			var dz: float = p.x - zc
			if absf(dz) < arch_r + 0.05:
				var arch_top: float = tire_r + sqrt(maxf((arch_r + 0.05) * (arch_r + 0.05) - dz * dz, 0.0))
				if p.y < arch_top + 0.04:
					lower[k] = Vector2(p.x, arch_top + 0.04)
	_append_arch(lower, -wb * 0.5, tire_r, arch_r)
	_append_arch(lower, wb * 0.5, tire_r, arch_r)
	taper = func(z: float, y: float) -> float:
		var t: float = 1.0 - tf * smoothstep(zf - 0.65, zf + 0.02, z) - trr * smoothstep(zr + 0.5, zr - 0.02, z)
		t *= 1.0 - 0.045 * smoothstep(0.55, belt_h, y)
		return hw * t
	# bottom & wheel-arch skin (every edge after the rear bumper) is black, like a real underbody
	var under_edges: Array = []
	for k in range(n_top - 1, lower.size()):
		under_edges.append(k)
	_extrude(lower, taper, paint, black, under_edges)

	# --- Glasshouse (slightly arched roof) ---
	var tumble: float = float(s["tumble"])
	var gh := PackedVector2Array([
		Vector2(cowl_z - 0.02, cowl_h),
		Vector2(ws_top_z, H - 0.05),
		Vector2(ws_top_z - 0.15, H - 0.01),
		Vector2(lerpf(ws_top_z, roof_rear_z, 0.5), H),
		Vector2(roof_rear_z + 0.12, H - 0.015),
		Vector2(roof_rear_z, H - 0.06),
		Vector2(deck_z + 0.02, belt_h),
	])
	var glass_edges: Array = [0, 5]
	if not _prof.is_empty():
		# windscreen = edges up to the roof's front end, rear window = edges after its back end
		gh = PackedVector2Array([Vector2(cowl_z - 0.02, cowl_h)])
		for q in _prof:
			if q.x < cowl_z - 0.03 and q.x > deck_z + 0.03:
				gh.append(q)
		gh.append(Vector2(deck_z + 0.02, belt_h))
		glass_edges = []
		for k in range(gh.size() - 1):
			if gh[k + 1].x >= ws_top_z - 0.01 or gh[k].x <= roof_rear_z + 0.01:
				glass_edges.append(k)
	var gh_taper := func(z: float, y: float) -> float:
		var k: float = clampf((y - cowl_h) / maxf(H - cowl_h, 0.1), 0.0, 1.0)
		return taper.call(z, belt_h) * lerpf(0.95, tumble, k)
	_extrude(gh, gh_taper, paint, glass, glass_edges)
	var win_polys: Array = Geometry2D.offset_polygon(gh, -0.06)
	for side in [-1.0, 1.0]:
		for poly in win_polys:
			_side_panel(poly, gh_taper, side, 0.006, glass)
		# B-pillar (black)
		var b_z: float = lerpf(ws_top_z, roof_rear_z, 0.95 if str(b.get("style")) in ["chiron", "jesko", "p1", "laferrari", "huayra"] else 0.5)
		var b_y: float = (belt_h + H) * 0.5
		_box(Vector3(side * (gh_taper.call(b_z, b_y) + 0.009), g + b_y, b_z), Vector3(0.02, H - belt_h - 0.08, 0.10), black)

	# --- Common details: mirrors, door handles, sills, underbody, plates ---
	for side in [-1.0, 1.0]:
		_box(Vector3(side * (hw + 0.08), g + cowl_h + 0.12, cowl_z - 0.25), Vector3(0.15, 0.10, 0.10), paint)
		_box(Vector3(side * (hw + 0.025), g + cowl_h + 0.10, cowl_z - 0.25), Vector3(0.05, 0.05, 0.05), black)
		_box(Vector3(side * (taper.call(cowl_z - 0.9, 0.8) + 0.008), g + belt_h - 0.14, cowl_z - 0.95), Vector3(0.015, 0.03, 0.15), chrome)
	_box(Vector3(0, g + 0.175, (zf + zr) * 0.5), Vector3(hw * 1.9, 0.03, L - 0.3), black) # below the floor skin (they used to z-fight)
	_box(Vector3(0, g + 0.30, zr + 0.03), Vector3(taper.call(zr + 0.1, 0.4) * 1.8, 0.08, 0.06), black)

	# --- The model's own face & tail ---
	match str(b.get("style", "accent")):
		"accent": _details_accent(nose_h, deck_h)
		"egea": _details_egea(nose_h, deck_h)
		"sahin": _details_sahin(nose_h, deck_h)
		"cup": _details_cup(nose_h, deck_h, str(b.get("face", "chevy")))
		"civic": _details_civic(nose_h, deck_h)
		"megane": _details_megane(nose_h, deck_h)
		"gtr": _details_gtr(nose_h, deck_h)
		"supra": _details_supra(nose_h, deck_h)
		"challenger": _details_challenger(nose_h, deck_h)
		"chiron": _details_chiron(nose_h, deck_h)
		"porsche": _details_porsche(nose_h, deck_h)
		"trophy": _details_trophy(nose_h, deck_h)
		"m4": _details_m4(nose_h, deck_h)
		"zed": _details_zed(nose_h, deck_h)
		"mustang": _details_mustang(nose_h, deck_h)
		"camaro": _details_camaro(nose_h, deck_h)
		"transam": _details_transam(nose_h, deck_h)
		"wrangler": _details_wrangler(nose_h, deck_h)
		"landcruiser": _details_landcruiser(nose_h, deck_h)
		"jesko": _details_jesko(nose_h, deck_h)
		"p1": _details_p1(nose_h, deck_h)
		"laferrari": _details_laferrari(nose_h, deck_h)
		"corolla": _details_corolla(nose_h, deck_h)
		"passat": _details_passat(nose_h, deck_h)
		"logan": _details_logan(nose_h, deck_h)
		"dogan": _details_dogan(nose_h, deck_h)
		"murat131": _details_murat131(nose_h, deck_h)
		"toros": _details_toros(nose_h, deck_h)
		"montecarlo": _details_montecarlo(nose_h, deck_h)
		"taycan": _details_taycan(nose_h, deck_h)
		"models": _details_models(nose_h, deck_h)
		"model3": _details_model3(nose_h, deck_h)
		"togg": _details_togg(nose_h, deck_h)
		"huayra": _details_huayra(nose_h, deck_h)
		"serce": _details_serce(nose_h, deck_h)
		"kartal": _details_kartal(nose_h, deck_h)
		"belair": _details_belair(nose_h, deck_h)
		"charger69": _details_charger69(nose_h, deck_h)
		"gt500": _details_gt500(nose_h, deck_h)
		"s600": _details_s600(nose_h, deck_h)
		"rrsport": _details_rrsport(nose_h, deck_h)
	if exhausts.is_empty() and not b.get("ev", false): # models without their own tips (EVs have none): one pipe under the left of the bumper
		_pipe(Vector3(-hw * 0.55, g + 0.26, zr - 0.02), 0.032)
	_spoiler(str(s["spoiler"]), deck_h)
	return _brake_mats

# ------------------------------------------------------------------ materials
func _make_materials(color: Color) -> void:
	paint = StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.55
	paint.roughness = 0.26
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.8
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass = StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.07, 0.10)
	glass.metallic = 0.7
	glass.roughness = 0.06
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	black = StandardMaterial3D.new()
	black.albedo_color = Color(0.035, 0.035, 0.04)
	black.roughness = 0.55
	chrome = StandardMaterial3D.new()
	chrome.albedo_color = Color(0.86, 0.87, 0.9)
	chrome.metallic = 0.95
	chrome.roughness = 0.1
	head = _glow(Color(0.95, 0.97, 1.0), 1.6)
	drl = _glow(Color(0.9, 0.95, 1.0), 4.0)
	amber = _glow(Color(1.0, 0.55, 0.1), 1.2)
	tail = StandardMaterial3D.new()
	tail.albedo_color = Color(0.55, 0.02, 0.02)
	tail.emission_enabled = true
	tail.emission = Color(1.0, 0.04, 0.03)
	tail.emission_energy_multiplier = 1.2
	_brake_mats.append(tail)
	lens = StandardMaterial3D.new()
	lens.albedo_color = Color(0.15, 0.16, 0.18)
	lens.metallic = 0.6
	lens.roughness = 0.1
	plate = StandardMaterial3D.new()
	plate.albedo_color = Color(0.92, 0.92, 0.9)

func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

# Front / rear helpers: width at the face, and positions on it
func _fw(y: float) -> float:
	return taper.call(zf - 0.08, y)
func _rw(y: float) -> float:
	return taper.call(zr + 0.08, y)
func _front(x: float, y: float, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, inset: float = 0.0) -> void:
	_box(Vector3(x, g + y, zf + 0.012 - inset), size, mat, rot)
func _rear(x: float, y: float, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, inset: float = 0.0) -> void:
	_box(Vector3(x, g + y, zr - 0.006 + inset), size, mat, rot)
func _plates(front_y: float, rear_y: float) -> void:
	_front(0, front_y, Vector3(0.52, 0.11, 0.01), plate)
	_rear(0, rear_y, Vector3(0.52, 0.11, 0.01), plate)

# ------------------------------------------------------------------ per-model details
func _details_sahin(nose_h: float, deck_h: float) -> void:
	# black grille band between big rectangular headlights, amber corner indicators, thick black
	# bumpers, wide red + amber tail-light blocks on a flat boot panel
	var fw: float = _fw(nose_h - 0.12)
	_front(0, nose_h - 0.13, Vector3((fw - 0.38) * 2.0, 0.17, 0.03), black) # grille between the headlights
	for k in range(3):
		_front(0, nose_h - 0.08 - k * 0.05, Vector3(0.62, 0.014, 0.035), chrome, Vector3.ZERO, -0.01)
	_front(0, 0.40, Vector3(fw * 2.0 + 0.04, 0.13, 0.07), black) # bumper
	_rear(0, 0.40, Vector3(_rw(0.4) * 2.0 + 0.04, 0.13, 0.07), black)
	var rw: float = _rw(deck_h - 0.15)
	for sd in [-1.0, 1.0]:
		# lamps sit side by side with small gaps: overlapping coplanar boxes flicker (z-fighting)
		_front(sd * (fw - 0.22), nose_h - 0.13, Vector3(0.31, 0.15, 0.04), head)
		_front(sd * (fw - 0.035), nose_h - 0.13, Vector3(0.05, 0.13, 0.04), amber)
		_rear(sd * (rw - 0.27), deck_h - 0.17, Vector3(0.35, 0.17, 0.04), tail)
		_rear(sd * (rw - 0.045), deck_h - 0.17, Vector3(0.08, 0.17, 0.04), amber)
	_box(Vector3(0, g + 0.40, zf + 0.05), Vector3(0.52, 0.11, 0.01), plate) # front plate on the bumper
	_rear(0, deck_h - 0.20, Vector3(0.52, 0.11, 0.01), plate)

func rw_span(margin: float) -> float:
	return maxf(_rw(0.8) * 2.0 - margin * 2.0, 0.2)

func _spoiler(kind: String, deck_h: float) -> void:
	var w: float = _rw(deck_h) * 1.8
	match kind:
		"lip":
			_box(Vector3(0, g + deck_h + 0.015, zr + 0.10), Vector3(w * 0.9, 0.03, 0.10), paint)
		"duck":
			_box(Vector3(0, g + deck_h + 0.04, zr + 0.09), Vector3(w * 0.95, 0.04, 0.12), paint, Vector3(-8, 0, 0))
		"blade": # NASCAR: tall flat spoiler across the tail, leaning back
			_box(Vector3(0, g + deck_h + 0.10, zr + 0.10), Vector3(w * 0.98, 0.22, 0.02), black, Vector3(-20, 0, 0))
		"wing":
			for sd in [-1.0, 1.0]:
				_box(Vector3(sd * w * 0.32, g + deck_h + 0.09, zr + 0.22), Vector3(0.05, 0.18, 0.10), paint)
			_box(Vector3(0, g + deck_h + 0.19, zr + 0.20), Vector3(w * 0.85, 0.04, 0.26), paint, Vector3(-5, 0, 0))
		"hoop":
			for sd in [-1.0, 1.0]:
				_box(Vector3(sd * w * 0.44, g + deck_h + 0.16, zr + 0.25), Vector3(0.07, 0.32, 0.16), paint, Vector3(-12, 0, 0))
			_box(Vector3(0, g + deck_h + 0.33, zr + 0.19), Vector3(w * 0.95, 0.05, 0.24), paint, Vector3(-6, 0, 0))
		"flat":
			_box(Vector3(0, g + deck_h + 0.02, zr + 0.35), Vector3(w * 0.9, 0.025, 0.40), black)

# ------------------------------------------------------------------ shape helpers
func _append_arch(poly: PackedVector2Array, zc: float, yc: float, r: float) -> void:
	poly.append(Vector2(zc - r, 0.20))
	for k in range(13):
		var a: float = PI - PI * float(k) / 12.0
		poly.append(Vector2(zc + cos(a) * r, yc + sin(a) * r))
	poly.append(Vector2(zc + r, 0.20))

# Extrude a side profile (z, y) across the car; edges in glass_edges get glass_mat.
func _extrude(poly: PackedVector2Array, half_width: Callable, side_mat: Material, glass_mat: Material, glass_edges: Array) -> void:
	for side in [-1.0, 1.0]:
		_side_panel(poly, half_width, side, 0.0, side_mat)
	var st_a := SurfaceTool.new()
	st_a.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_a.set_smooth_group(0xFFFFFFFF)
	var st_b := SurfaceTool.new()
	st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_b.set_smooth_group(0xFFFFFFFF)
	var n: int = poly.size()
	for i in range(n):
		var p0: Vector2 = poly[i]
		var p1: Vector2 = poly[(i + 1) % n]
		var w0: float = half_width.call(p0.x, p0.y)
		var w1: float = half_width.call(p1.x, p1.y)
		var a := Vector3(-w0, g + p0.y, p0.x)
		var b := Vector3(w0, g + p0.y, p0.x)
		var c := Vector3(w1, g + p1.y, p1.x)
		var d := Vector3(-w1, g + p1.y, p1.x)
		var st: SurfaceTool = st_b if glass_edges.has(i) else st_a
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
	st_a.generate_normals()
	_mesh(st_a.commit(), side_mat)
	if not glass_edges.is_empty():
		st_b.generate_normals()
		_mesh(st_b.commit(), glass_mat)

func _side_panel(poly: PackedVector2Array, half_width: Callable, side: float, push: float, mat: Material) -> void:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var out_n := Vector3(side, 0.0, 0.0)
	st.set_normal(out_n)
	for t in range(0, idx.size(), 3):
		var v: Array[Vector3] = []
		for k in range(3):
			var p: Vector2 = poly[idx[t + k]]
			v.append(Vector3(side * (half_width.call(p.x, p.y) + push), g + p.y, p.x))
		if (v[1] - v[0]).cross(v[2] - v[0]).dot(out_n) > 0.0:
			v = [v[0], v[2], v[1]]
		for vert in v:
			st.add_vertex(vert)
	_mesh(st.commit(), mat)

# Flat hexagon on the front face (Hyundai-style grille)
func _hex(c: Vector3, w: float, h: float, mat: Material) -> void:
	var pts: Array[Vector2] = [Vector2(-w * 0.5, 0), Vector2(-w * 0.38, h * 0.5), Vector2(w * 0.38, h * 0.5), Vector2(w * 0.5, 0), Vector2(w * 0.38, -h * 0.5), Vector2(-w * 0.38, -h * 0.5)]
	_front_poly(c, pts, mat)

# Bugatti-style horseshoe grille (rounded, narrow at the bottom)
func _horseshoe(c: Vector3) -> void:
	var pts: Array[Vector2] = []
	for k in range(13):
		var a: float = PI * float(k) / 12.0
		pts.append(Vector2(cos(a) * 0.22, sin(a) * 0.14 + 0.04))
	pts.append(Vector2(-0.14, -0.14))
	pts.append(Vector2(0.14, -0.14))
	_front_poly(c, pts, chrome)
	_front_poly(c + Vector3(0, 0, 0.004), pts.map(func(p: Vector2) -> Vector2: return p * 0.82), black)

func _front_poly(c: Vector3, pts: Array, mat: Material) -> void:
	var poly := PackedVector2Array(pts)
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	for t in range(0, idx.size(), 3):
		var v: Array[Vector3] = []
		for k in range(3):
			var p: Vector2 = poly[idx[t + k]]
			v.append(c + Vector3(p.x, p.y, 0.0))
		if (v[1] - v[0]).cross(v[2] - v[0]).dot(Vector3(0, 0, 1)) > 0.0:
			v = [v[0], v[2], v[1]]
		for vert in v:
			st.add_vertex(vert)
	_mesh(st.commit(), mat)

# Round lamp facing backwards (-Z): a short cylinder
func _ring(c: Vector3, r: float, mat: Material) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.05
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = c
	mi.rotation_degrees = Vector3(90, 0, 0)
	_parent.add_child(mi)

func _cyl_back(c: Vector3, r: float, _mat: Material) -> void:
	_pipe(c, r)

# Exhaust tip pointing backwards: an open chrome tube (seen from inside too) with a dark, recessed
# inside, so it reads as a real pipe instead of a solid chrome disc.
func _pipe(c: Vector3, r: float) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = r
	tube.bottom_radius = r
	tube.height = 0.16
	tube.radial_segments = 20
	tube.cap_top = false
	tube.cap_bottom = false
	var pipe_mat: StandardMaterial3D = chrome.duplicate()
	pipe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = tube
	mi.material_override = pipe_mat
	mi.position = c + Vector3(0, 0, 0.06) # sticks out ~2 cm, the rest hides in the bumper
	mi.rotation_degrees = Vector3(90, 0, 0)
	_parent.add_child(mi)
	var soot := CylinderMesh.new()
	soot.top_radius = r * 0.9
	soot.bottom_radius = r * 0.9
	soot.height = 0.01
	soot.radial_segments = 20
	var inner := MeshInstance3D.new()
	inner.mesh = soot
	inner.material_override = black
	inner.position = c + Vector3(0, 0, 0.05)
	inner.rotation_degrees = Vector3(90, 0, 0)
	_parent.add_child(inner)
	exhausts.append(c)

func _mesh(m: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	_parent.add_child(mi)

func _box(pos: Vector3, size: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	_parent.add_child(mi)

# ------------------------------------------------------------------ NASCAR, tractor, buggy
# face: "chevy" (Camaro: slim lamp decals, wide grille), "ford" (Mustang: trapezoid grille, tri-bar
# lamps and tail lights), "toyota" (Camry: big X-shaped grille, sharp slim lamps)
func _details_cup(nose_h: float, deck_h: float, face: String = "chevy") -> void:
	# race car: black splitter and grille decal, sticker headlights / tail lights, door and roof numbers
	var fw: float = _fw(nose_h - 0.1)
	_box(Vector3(0, g + 0.12, zf - 0.02), Vector3(W * 0.94, 0.04, 0.34), black) # splitter
	var rw: float = _rw(deck_h - 0.12)
	match face:
		"ford":
			_front_poly(Vector3(0, g + 0.36, zf + 0.012), [Vector2(-0.38, 0.12), Vector2(0.38, 0.12), Vector2(0.50, -0.12), Vector2(-0.50, -0.12)], black)
			for sd in [-1.0, 1.0]:
				_front(sd * (fw - 0.28), nose_h - 0.09, Vector3(0.38, 0.08, 0.02), head)
				for k in range(3):
					_front(sd * (fw - 0.12 - k * 0.06), nose_h - 0.16, Vector3(0.025, 0.09, 0.025), drl)
					_rear(sd * (rw - 0.14 - k * 0.11), deck_h - 0.14, Vector3(0.05, 0.13, 0.02), tail)
		"toyota":
			_front(0, 0.33, Vector3(1.05, 0.20, 0.02), black)
			for sd in [-1.0, 1.0]:
				_front(sd * 0.28, 0.33, Vector3(0.62, 0.035, 0.025), paint, Vector3(0, 0, sd * 28), -0.003)
				_front(sd * (fw - 0.26), nose_h - 0.08, Vector3(0.42, 0.05, 0.02), head, Vector3(0, 0, sd * -8))
				_rear(sd * (rw - 0.3), deck_h - 0.12, Vector3(0.46, 0.05, 0.02), tail)
		_:
			_front(0, 0.34, Vector3(1.0, 0.16, 0.02), black)
			for sd in [-1.0, 1.0]:
				_front(sd * (fw - 0.28), nose_h - 0.09, Vector3(0.38, 0.09, 0.02), head)
				_rear(sd * (rw - 0.3), deck_h - 0.13, Vector3(0.42, 0.08, 0.02), tail)
	for sd in [-1.0, 1.0]:
		_number(car_number, Vector3(sd * (hw + 0.025), g + 0.62, -0.15), Vector3(0, sd * 90.0, 0), 160)
	_number(car_number, Vector3(0, g + H + 0.012, (ws_top_z + roof_rear_z) * 0.5), Vector3(-90, 180, 0), 140)

func _number(text: String, pos: Vector3, rot_deg: Vector3, size_px: int) -> void:
	var l := Label3D.new()
	l.text = text
	if ResourceLoader.exists("res://assets/fonts/game_font.tres"):
		l.font = load("res://assets/fonts/game_font.tres")
	l.font_size = size_px
	l.pixel_size = 0.004
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0, 0, 0)
	l.outline_size = 24
	l.double_sided = false
	l.shaded = true
	l.position = pos
	l.rotation_degrees = rot_deg
	_parent.add_child(l)

# Upright cylinder (exhaust stack, posts)
func _cyl(pos: Vector3, r: float, h: float, mat: Material) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	_parent.add_child(mi)

# Tube from a to b (roll cage, shocks)
func _tube(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var d: Vector3 = b - a
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = d.length()
	cm.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	var y: Vector3 = d.normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	_parent.add_child(mi)

# Farm tractor: long narrow hood over the engine, glass cab over the big rear wheels, wide rear
# fenders, front weights, vertical exhaust stack. Rear wheels have tire_r (the small front ones are
# drawn by the car, see front_wheel_r).
func _build_tractor(tire_r: float) -> void:
	# Sized from the body (the John Deere 6R is the 1.0 scale); `tractor_kind` picks the brand's
	# details: "jd" John Deere, "mf" Massey Ferguson, "nh" New Holland, "fendt", "fiat" (no cab)
	var kh: float = H / 3.05
	var kw: float = W / 2.55
	var zfa: float = wb * 0.5 # front axle
	var zra: float = -wb * 0.5 # rear axle
	var tw: float = float(STYLES["tractor"]["cowl"]) * kh # hood top height
	var cab_f: float = cowl_z
	var cab_r: float = cab_f - 1.6 * kh
	var cab_z: float = (cab_f + cab_r) * 0.5
	var trim := _glow(trim_col, 0.0)
	var dark := _glow(Color(0.12, 0.12, 0.13), 0.0)
	var open_seat: bool = tractor_kind == "fiat"
	var hw2: float = 0.475 * kw # hood half width
	_box(Vector3(0, g + 0.95 * kh, (cab_f + zf) * 0.5 - 0.3), Vector3(0.8 * kw, 0.6 * kh, zf - cab_f + 0.4), dark) # engine block / frame
	_box(Vector3(0, g + 1.6 * kh, (cab_f + zf - 0.25) * 0.5), Vector3(hw2 * 2.0, tw - 1.25 * kh, zf - 0.25 - cab_f), paint) # hood
	var hood_mid: float = 1.6 * kh
	var hood_top: float = tw
	match tractor_kind:
		"mf": # dark grey lower bonnet, silver triple-triangle badge, headlights in the grille
			_box(Vector3(0, g + hood_mid - (tw - 1.25 * kh) * 0.3, (cab_f + zf - 0.25) * 0.5), Vector3(hw2 * 2.0 + 0.02, (tw - 1.25 * kh) * 0.4, zf - 0.3 - cab_f), trim)
			_box(Vector3(0, g + hood_top - 0.12, zf - 0.205), Vector3(0.2, 0.18, 0.02), chrome)
		"nh": # white stripe, "cat's eye" lamps high on the grille
			for sd in [-1.0, 1.0]:
				_box(Vector3(sd * (hw2 + 0.01), g + hood_mid, (cab_f + zf - 0.25) * 0.5), Vector3(0.02, 0.08, zf - 0.6 - cab_f), trim)
				_box(Vector3(sd * 0.22 * kw, g + hood_top - 0.1, zf - 0.21), Vector3(0.3, 0.07, 0.04), drl)
		"fendt": # dark lower bonnet and frame, big grille, red rims (body "rim")
			_box(Vector3(0, g + hood_mid - (tw - 1.25 * kh) * 0.25, (cab_f + zf - 0.25) * 0.5), Vector3(hw2 * 2.0 + 0.02, (tw - 1.25 * kh) * 0.5, zf - 0.3 - cab_f), trim)
			_box(Vector3(0, g + hood_top - 0.1, zf - 0.205), Vector3(0.5, 0.07, 0.02), chrome)
		"fiat": # white grille surround and badge
			_box(Vector3(0, g + hood_mid, zf - 0.21), Vector3(hw2 * 2.0 + 0.02, (tw - 1.25 * kh) * 0.9, 0.03), trim)
		_: # John Deere: yellow stripe along the hood, leaping-deer badge
			for sd in [-1.0, 1.0]:
				_box(Vector3(sd * (hw2 + 0.01), g + hood_top - 0.18, (cab_f + zf - 0.25) * 0.5), Vector3(0.02, 0.06, zf - 0.6 - cab_f), trim)
			_box(Vector3(0, g + hood_top - 0.12, zf - 0.205), Vector3(0.22, 0.16, 0.02), trim)
	_box(Vector3(0, g + hood_mid - 0.05, zf - 0.23), Vector3(hw2 * 1.8, (tw - 1.25 * kh) * 0.6, 0.04), black) # grille
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * (hw2 + 0.005), g + hood_mid - 0.1, (cab_f + zf) * 0.5 - 0.1), Vector3(0.02, 0.35 * kh, (zf - cab_f) * 0.55), black) # hood side vents
		_box(Vector3(sd * 0.3 * kw, g + hood_top - 0.17, zf - 0.22), Vector3(0.2, 0.1, 0.05), head)
	if not open_seat:
		_box(Vector3(0, g + 0.82 * kh, zf - 0.12), Vector3(1.1 * kw, 0.45 * kh, 0.5), dark) # front weights
	_box(Vector3(0, g + front_r_vis * 0.9, zfa), Vector3(hw * 1.5, 0.18, 0.22), black) # front axle
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * hw * 0.75, g + front_r_vis * 2.0 + 0.1, zfa), Vector3(0.5 * kw, 0.05, front_r_vis * 2.0), paint, Vector3(0, 0, sd * -8.0)) # front fenders
	if open_seat:
		# classic open tractor: seat over the gearbox, big steering wheel, roll bar behind the seat
		_box(Vector3(0, g + 1.1 * kh, cab_z), Vector3(0.75, 0.35, 1.4 * kh), dark) # gearbox / platform
		_box(Vector3(0, g + 1.45 * kh, cab_z - 0.25), Vector3(0.45, 0.08, 0.42), black) # seat
		_box(Vector3(0, g + 1.7 * kh, cab_z - 0.45), Vector3(0.45, 0.4, 0.06), black, Vector3(-10, 0, 0)) # backrest
		_box(Vector3(0, g + 1.9 * kh, cab_f - 0.1), Vector3(0.45, 0.05, 0.45), black, Vector3(-35, 0, 0)) # steering wheel
		_tube(Vector3(0, g + 1.3 * kh, cab_f + 0.15), Vector3(0, g + 1.88 * kh, cab_f - 0.08), 0.03, black)
		for sx in [-1.0, 1.0]:
			_tube(Vector3(sx * 0.6, g + tire_r * 2.0, cab_r + 0.25), Vector3(sx * 0.6, g + H - 0.05, cab_r + 0.25), 0.045, black)
		_tube(Vector3(-0.6, g + H - 0.05, cab_r + 0.25), Vector3(0.6, g + H - 0.05, cab_r + 0.25), 0.045, black)
	else:
		# cab: floor, four posts, glass all round, roof with work lights
		var cw: float = 0.84 * kw
		_box(Vector3(0, g + 1.45 * kh, cab_z), Vector3(cw * 2.08, 0.15, 1.65 * kh), black)
		for sx in [-1.0, 1.0]:
			for z in [cab_f, cab_r]:
				_box(Vector3(sx * cw, g + 2.25 * kh, z), Vector3(0.08, 1.5 * kh, 0.08), trim if tractor_kind in ["mf", "fendt"] else black)
		_box(Vector3(0, g + 2.25 * kh, cab_f), Vector3(cw * 1.9, 1.4 * kh, 0.03), glass)
		_box(Vector3(0, g + 2.25 * kh, cab_r), Vector3(cw * 1.9, 1.4 * kh, 0.03), glass)
		for sx in [-1.0, 1.0]:
			_box(Vector3(sx * cw, g + 2.25 * kh, cab_z), Vector3(0.03, 1.4 * kh, 1.52 * kh), glass)
		_box(Vector3(0, g + 3.02 * kh, cab_z), Vector3(cw * 2.32, 0.12, 1.85 * kh), paint if tractor_kind != "nh" else trim) # roof
		for sx in [-1.0, 1.0]:
			_box(Vector3(sx * 0.6 * kw, g + 2.94 * kh, cab_f + 0.05), Vector3(0.18, 0.1, 0.06), head) # work lights
		_box(Vector3(0, g + 1.8 * kh, cab_z - 0.2), Vector3(0.5, 0.5, 0.5), black) # seat
		_box(Vector3(0, g + 2.05 * kh, cab_f - 0.35), Vector3(0.35, 0.06, 0.35), black, Vector3(-40, 0, 0)) # steering wheel
	# rear fenders over the big wheels, steps / tanks, hitch, lights
	for sx in [-1.0, 1.0]:
		var fx: float = sx * (hw * 0.75)
		_box(Vector3(fx, g + tire_r * 2.0 + 0.12, zra), Vector3(0.8 * kw, 0.07, tire_r * 2.15), paint)
		_box(Vector3(sx * 0.62 * kw, g + tire_r + 0.75 * kh, zra), Vector3(0.05, 0.75 * kh, tire_r * 2.15), paint)
		if not open_seat:
			_box(Vector3(sx * 0.82 * kw, g + 1.0 * kh, cab_f + 0.15), Vector3(0.3, 0.5 * kh, 0.7), black) # tanks / steps
		_box(Vector3(fx, g + tire_r * 2.0 + 0.05, zra - tire_r * 1.05), Vector3(0.14, 0.1, 0.05), tail)
	_box(Vector3(0, g + 0.8 * kh, zra - 0.75 * kh), Vector3(1.0 * kw, 0.15, 0.4), black) # 3-point hitch
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 0.4 * kw, g + 0.75 * kh, zra - 1.05 * kh), Vector3(0.08, 0.08, 0.7 * kh), black)
	# exhaust stack in front of the cab
	var ex := Vector3(0.38 * kw, g + 2.55 * kh, cab_f + 0.12)
	if open_seat:
		ex = Vector3(0.25, g + hood_top + 0.45, zf - 0.6)
	_cyl(ex, 0.07 * kw, 1.3 * kh if not open_seat else 0.9, dark)
	exhausts.append(ex + Vector3(0, (1.3 * kh if not open_seat else 0.9) * 0.5, 0))
	exhaust_up = true

# Dune buggy (tube-frame, like an Ariel Nomad): low yellow side pods and nose with black stripes,
# round headlights, tube bumper, roll cage with yellow braces, exposed engine at the back.
# The red coilovers are added by the car (they follow each wheel's suspension).
func _build_buggy(_tire_r: float) -> void:
	var cage := _glow(Color(0.07, 0.07, 0.08), 0.0)
	var yellow := paint
	var engine := _glow(Color(0.35, 0.36, 0.38), 0.0)
	var zfa: float = wb * 0.5
	var zra: float = -wb * 0.5
	var fy: float = g + 0.42 # frame rail height
	# lower frame: side rails and cross members
	for sd in [-1.0, 1.0]:
		_tube(Vector3(sd * 0.5, fy, zf - 0.35), Vector3(sd * 0.5, fy, zr + 0.35), 0.04, cage)
	for z in [zf - 0.35, 0.6, -0.6, zr + 0.35]:
		_tube(Vector3(-0.5, fy, z), Vector3(0.5, fy, z), 0.035, cage)
	_box(Vector3(0, fy - 0.03, 0), Vector3(1.0, 0.03, wb), black) # floor pan
	# yellow tub: side pods + nose (with two black stripes) + headlights
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * 0.6, g + 0.72, 0.15), Vector3(0.24, 0.5, 1.7), yellow)
		_cyl_z(Vector3(sd * 0.42, g + 0.86, zf - 0.08), 0.1, 0.08, head)
		_cyl_z(Vector3(sd * 0.42, g + 0.86, zf - 0.13), 0.12, 0.05, cage)
	_box(Vector3(0, g + 0.78, zf - 0.55), Vector3(1.25, 0.32, 1.05), yellow, Vector3(-9, 0, 0))
	for sx in [-0.14, 0.14]:
		_box(Vector3(sx, g + 0.95, zf - 0.55), Vector3(0.1, 0.02, 1.06), black, Vector3(-9, 0, 0))
	# tube front bumper / nerf bar
	_tube(Vector3(-0.55, g + 0.62, zf + 0.02), Vector3(0.55, g + 0.62, zf + 0.02), 0.04, cage)
	_tube(Vector3(-0.45, g + 0.42, zf + 0.06), Vector3(0.45, g + 0.42, zf + 0.06), 0.04, cage)
	for sx in [-0.45, 0.45]:
		_tube(Vector3(sx, g + 0.42, zf + 0.06), Vector3(sx, g + 0.62, zf + 0.02), 0.035, cage)
	# cockpit: two seats and a steering wheel
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * 0.27, g + 0.62, -0.35), Vector3(0.44, 0.22, 0.48), black)
		_box(Vector3(sd * 0.27, g + 0.95, -0.62), Vector3(0.44, 0.65, 0.1), black, Vector3(-12, 0, 0))
	_box(Vector3(-0.27, g + 1.0, 0.25), Vector3(0.32, 0.32, 0.04), black, Vector3(-35, 0, 0))
	# roll cage: main hoop behind the seats, A-pillars, roof rails, rear braces
	var top_y: float = g + 1.5
	var hoop_z: float = -0.78
	var front_z: float = 0.35
	for sd in [-1.0, 1.0]:
		var x: float = sd * 0.55
		_tube(Vector3(x, fy, hoop_z), Vector3(x * 0.92, top_y, hoop_z), 0.04, cage) # main hoop leg
		_tube(Vector3(x, g + 0.85, 0.85), Vector3(x * 0.92, top_y, front_z), 0.04, cage) # A-pillar
		_tube(Vector3(x * 0.92, top_y, front_z), Vector3(x * 0.92, top_y, hoop_z), 0.04, cage) # roof rail
		_tube(Vector3(x * 0.92, top_y, hoop_z), Vector3(sd * 0.45, fy + 0.2, zr + 0.3), 0.035, cage) # rear brace
		_tube(Vector3(sd * 0.2, top_y - 0.02, hoop_z - 0.02), Vector3(sd * 0.2, g + 0.75, hoop_z - 0.02), 0.03, yellow) # yellow brace
	_tube(Vector3(-0.51, top_y, hoop_z), Vector3(0.51, top_y, hoop_z), 0.04, cage)
	_tube(Vector3(-0.51, top_y, front_z), Vector3(0.51, top_y, front_z), 0.04, cage)
	_tube(Vector3(-0.55, g + 0.9, hoop_z), Vector3(0.55, g + 0.9, hoop_z), 0.035, cage)
	_box(Vector3(0, top_y + 0.06, front_z), Vector3(1.0, 0.06, 0.12), cage) # roof lamp bar with four round spots
	for k in range(4):
		_cyl_z(Vector3(-0.36 + k * 0.24, top_y + 0.13, front_z + 0.04), 0.075, 0.08, cage)
		_cyl_z(Vector3(-0.36 + k * 0.24, top_y + 0.13, front_z + 0.085), 0.06, 0.02, head)
	_box(Vector3(0, g + 0.52, zf + 0.10), Vector3(0.08, 0.06, 0.12), _glow(Color(0.85, 0.08, 0.05), 0.0)) # tow eye
	# exposed engine and the rear frame around it
	_box(Vector3(0, g + 0.72, zra + 0.25), Vector3(0.62, 0.45, 0.55), engine)
	_box(Vector3(0.18, g + 1.0, zra + 0.25), Vector3(0.18, 0.12, 0.4), black) # intake
	_tube(Vector3(-0.5, g + 0.95, zr + 0.3), Vector3(0.5, g + 0.95, zr + 0.3), 0.035, cage)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * 0.45, g + 0.95, zr + 0.28), Vector3(0.14, 0.07, 0.04), tail)
	_pipe(Vector3(-0.25, g + 0.62, zr + 0.22), 0.045)

# Disc facing forward (+Z): headlights
func _cyl_z(pos: Vector3, r: float, h: float, mat: Material) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	_parent.add_child(mi)

# ------------------------------------------------------------------ added cars (after photos)
# Height of the hood's top surface at z (follows the lower body outline from the nose to the cowl)
func _hood_y(z: float) -> float:
	if not _prof.is_empty():
		return _prof_h(z)
	var nose_h: float = float(s["nose"])
	var cowl_h: float = float(s["cowl"])
	var pts: Array = [Vector2(zf - 0.28, nose_h + 0.05), Vector2(lerpf(zf, cowl_z, 0.6), lerpf(nose_h + 0.05, cowl_h, 0.75)), Vector2(cowl_z, cowl_h)]
	if z >= pts[0].x:
		return pts[0].y
	for k in range(pts.size() - 1):
		if z >= pts[k + 1].x:
			return lerpf(pts[k].y, pts[k + 1].y, (pts[k].x - z) / maxf(pts[k].x - pts[k + 1].x, 0.01))
	return cowl_h

# Flat oval lamp facing forward (+Z) at c, radii rx / ry, tilted by rot (degrees)
func _oval(c: Vector3, rx: float, ry: float, depth: float, mat: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = depth
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.basis = Basis.from_euler(rot * PI / 180.0) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(rx, 1.0, ry))
	mi.position = c
	_parent.add_child(mi)

func _splitter() -> void:
	_box(Vector3(0, g + 0.11, zf - 0.04), Vector3(W * 0.92, 0.03, 0.34), black)

# Porsche 911 Turbo S: frog-eye oval headlights on the front wings, three bumper intakes,
# wide rear haunches, full-width light bar, louvred engine lid, raised Turbo wing, quad pipes
func _details_porsche(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h)
	for sd in [-1.0, 1.0]:
		_oval(Vector3(sd * (fw - 0.30), g + _hood_y(zf - 0.38) + 0.035, zf - 0.34), 0.13, 0.15, 0.04, lens, Vector3(-55, 0, 0))
		_oval(Vector3(sd * (fw - 0.30), g + _hood_y(zf - 0.38) + 0.05, zf - 0.33), 0.10, 0.12, 0.04, head, Vector3(-55, 0, 0))
		_front(sd * (fw - 0.24), 0.33, Vector3(0.30, 0.14, 0.03), black)
		_front(sd * (fw - 0.24), 0.43, Vector3(0.26, 0.025, 0.035), drl)
		_box(Vector3(sd * (taper.call(-wb * 0.5, 0.7) + 0.03), g + 0.70, -wb * 0.5 + 0.05), Vector3(0.08, 0.32, 1.3), paint)
		for k in range(2):
			_pipe(Vector3(sd * (0.40 + k * 0.13), g + 0.27, zr - 0.01), 0.04)
	_front(0, 0.33, Vector3(0.50, 0.12, 0.03), black)
	var rw: float = _rw(deck_h - 0.1)
	_rear(0, deck_h - 0.10, Vector3(rw * 1.9, 0.045, 0.03), tail)
	for k in range(6):
		_box(Vector3(0, g + deck_h + 0.012, zr + 0.24 + k * 0.06), Vector3(0.7, 0.012, 0.03), black)
	_box(Vector3(0, g + deck_h + 0.11, zr + 0.22), Vector3(rw * 1.6, 0.03, 0.22), paint)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * 0.40, g + deck_h + 0.055, zr + 0.24), Vector3(0.04, 0.09, 0.08), black)
	_rear(0, 0.32, Vector3(_rw(0.3) * 1.6, 0.10, 0.04), black)
	_plates(0.26, deck_h - 0.30)

# BMW M4: huge upright twin-kidney grille, slim angular headlights, big corner intakes,
# carbon roof, L-shaped tail lights, quad pipes
func _details_m4(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.6)
	for sd in [-1.0, 1.0]:
		_front(sd * 0.17, nose_h - 0.19, Vector3(0.30, 0.44, 0.03), chrome, Vector3.ZERO, -0.004)
		_front(sd * 0.17, nose_h - 0.19, Vector3(0.25, 0.39, 0.035), black, Vector3.ZERO, -0.008)
		for k in range(4):
			_front(sd * 0.17, nose_h - 0.34 + k * 0.1, Vector3(0.25, 0.012, 0.04), lens, Vector3.ZERO, -0.012)
		_swept_lamp(sd, nose_h - 0.07, 0.32, 0.07, 0.40, head)
		_front(sd * (fw - 0.20), nose_h - 0.115, Vector3(0.28, 0.02, 0.035), drl)
		_front(sd * (fw - 0.15), 0.32, Vector3(0.26, 0.22, 0.03), black)
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.22), deck_h - 0.11, Vector3(0.40, 0.08, 0.04), tail)
		_rear(sd * (rw - 0.06), deck_h - 0.19, Vector3(0.08, 0.16, 0.04), tail)
		for k in range(2):
			_pipe(Vector3(sd * (0.38 + k * 0.12), g + 0.27, zr - 0.01), 0.045)
	_box(Vector3(0, g + H + 0.004, (ws_top_z + roof_rear_z) * 0.5), Vector3(hw * 1.1, 0.01, ws_top_z - roof_rear_z + 0.2), black)
	_rear(0, 0.30, Vector3(_rw(0.3) * 1.4, 0.10, 0.04), black)
	_plates(0.22, deck_h - 0.32)

# Nissan Z: big rectangular mouth, twin half-moon lamps per side (240Z homage), full-width dark
# tail bar with red ends
func _details_zed(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.5)
	_front(0, 0.36, Vector3(fw * 1.35, 0.27, 0.03), black)
	for k in range(5):
		_front(0, 0.26 + k * 0.05, Vector3(fw * 1.3, 0.008, 0.035), lens, Vector3.ZERO, -0.004)
	for sd in [-1.0, 1.0]:
		for k in range(2):
			_oval(Vector3(sd * (fw - 0.15 - k * 0.20), g + nose_h - 0.02, zf - 0.17), 0.09, 0.055, 0.05, head, Vector3(-28, 0, 0))
		_front(sd * (fw - 0.22), nose_h - 0.10, Vector3(0.36, 0.02, 0.035), drl)
		_pipe(Vector3(sd * 0.42, g + 0.27, zr - 0.01), 0.05)
	var rw: float = _rw(deck_h - 0.1)
	_rear(0, deck_h - 0.12, Vector3(rw * 1.9, 0.08, 0.03), lens)
	for sd in [-1.0, 1.0]:
		_rear(sd * (rw - 0.18), deck_h - 0.12, Vector3(0.30, 0.06, 0.04), tail)
	_plates(0.24, deck_h - 0.30)

# Ford Mustang: trapezoid grille (wider at the bottom) with the pony, tri-bar LED headlights,
# hood vents, tri-bar tail lights on black panels, quad pipes
func _details_mustang(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.7)
	_front_poly(Vector3(0, g + nose_h - 0.18, zf + 0.012), [Vector2(-0.42, 0.12), Vector2(0.42, 0.12), Vector2(0.54, -0.15), Vector2(-0.54, -0.15)], black)
	_front(0, nose_h - 0.18, Vector3(0.10, 0.06, 0.04), chrome, Vector3.ZERO, -0.02)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.07, 0.34, 0.09, 0.32, head)
		for k in range(3):
			_front(sd * (fw - 0.10 - k * 0.07), nose_h - 0.14, Vector3(0.03, 0.12, 0.04), drl)
		_box(Vector3(sd * 0.32, g + _hood_y(cowl_z + 0.45) + 0.005, cowl_z + 0.45), Vector3(0.18, 0.02, 0.35), black, Vector3(-3, 0, 0))
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.25), deck_h - 0.15, Vector3(0.42, 0.18, 0.03), lens)
		for k in range(3):
			_rear(sd * (rw - 0.12 - k * 0.12), deck_h - 0.15, Vector3(0.06, 0.16, 0.04), tail)
		for k in range(2):
			_pipe(Vector3(sd * (0.45 + k * 0.13), g + 0.27, zr - 0.01), 0.045)
	_plates(0.30, deck_h - 0.36)

# Chevrolet Camaro: slim upper band with the headlights and the gold bow-tie bar, huge lower
# grille, corner DRLs, hood extractor, twin rectangular tail lights per side
func _details_camaro(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.7)
	var gold := _glow(Color(0.85, 0.68, 0.18), 0.3)
	_front(0, nose_h - 0.10, Vector3(fw * 1.9, 0.11, 0.03), black)
	_front(0, nose_h - 0.10, Vector3(0.16, 0.05, 0.04), gold, Vector3.ZERO, -0.005)
	_front(0, 0.37, Vector3(fw * 1.6, 0.26, 0.03), black)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.10, 0.34, 0.07, 0.30, head)
		_front(sd * (fw - 0.08), 0.42, Vector3(0.05, 0.16, 0.04), drl)
		var rw: float = _rw(deck_h - 0.1)
		for k in range(2):
			_rear(sd * (rw - 0.14 - k * 0.26), deck_h - 0.13, Vector3(0.22, 0.10, 0.04), tail)
		for k in range(2):
			_pipe(Vector3(sd * (0.42 + k * 0.13), g + 0.27, zr - 0.01), 0.045)
	_box(Vector3(0, g + _hood_y(cowl_z + 0.4) + 0.005, cowl_z + 0.4), Vector3(0.6, 0.02, 0.4), black, Vector3(-3, 0, 0))
	_plates(0.25, deck_h - 0.34)

# Pontiac Trans Am '77: split "beak" nose with quad square headlights in black pods, shaker
# scoop, the gold bird on the hood, gold pinstripes, T-tops, blacked-out tail panel
func _details_transam(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.6)
	var gold := _glow(Color(0.85, 0.66, 0.22), 0.25)
	_front(0, nose_h - 0.14, Vector3(0.10, 0.20, 0.04), paint, Vector3.ZERO, -0.03)
	for sd in [-1.0, 1.0]:
		_front(sd * (fw * 0.5 + 0.04), nose_h - 0.14, Vector3(fw - 0.12, 0.20, 0.03), black)
		for k in range(2):
			_front(sd * (fw - 0.18 - k * 0.24), nose_h - 0.14, Vector3(0.17, 0.15, 0.04), head, Vector3.ZERO, -0.003)
		_front(sd * 0.32, 0.36, Vector3(0.40, 0.10, 0.03), black)
		_pipe(Vector3(sd * 0.5, g + 0.25, zr - 0.01), 0.045)
	_box(Vector3(0, g + _hood_y(cowl_z + 0.55) + 0.07, cowl_z + 0.55), Vector3(0.42, 0.14, 0.55), black)
	var hz: float = (zf + cowl_z) * 0.5 + 0.15
	_box(Vector3(0, g + _hood_y(hz) + 0.006, hz), Vector3(0.18, 0.012, 0.5), gold)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * 0.30, g + _hood_y(hz + 0.05) + 0.006, hz + 0.05), Vector3(0.50, 0.012, 0.20), gold, Vector3(0, sd * 20, 0))
		_box(Vector3(sd * 0.25, g + H + 0.005, (ws_top_z + roof_rear_z) * 0.5), Vector3(0.38, 0.012, (ws_top_z - roof_rear_z) * 0.8), glass)
	var rw: float = _rw(deck_h - 0.1)
	_rear(0, deck_h - 0.15, Vector3(rw * 1.9, 0.18, 0.03), lens)
	for sd in [-1.0, 1.0]:
		_rear(sd * (rw - 0.35), deck_h - 0.15, Vector3(0.6, 0.12, 0.04), tail)
	_plates(0.26, deck_h - 0.34)

# Jeep Wrangler: seven-slot grille between round headlights, black fender flares, steel bumpers
# with red tow hooks, black hardtop, spare wheel on the tailgate, vertical tail lights
func _details_wrangler(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.2)
	var red := _glow(Color(0.8, 0.05, 0.05), 0.0)
	for k in range(7):
		_front(-0.30 + k * 0.10, nose_h - 0.22, Vector3(0.055, 0.30, 0.03), black, Vector3.ZERO, -0.005)
	for sd in [-1.0, 1.0]:
		_oval(Vector3(sd * 0.56, g + nose_h - 0.21, zf + 0.02), 0.135, 0.135, 0.04, black)
		_oval(Vector3(sd * 0.56, g + nose_h - 0.21, zf + 0.03), 0.11, 0.11, 0.04, head)
		for zc in [wb * 0.5, -wb * 0.5]:
			_box(Vector3(sd * (hw + 0.03), g + tire_rad * 2.0 + 0.10, zc), Vector3(0.18, 0.05, 1.05), black)
			_box(Vector3(sd * (hw + 0.03), g + tire_rad * 1.55, zc + 0.55), Vector3(0.18, 0.05, 0.4), black, Vector3(60, 0, 0))
			_box(Vector3(sd * (hw + 0.03), g + tire_rad * 1.55, zc - 0.55), Vector3(0.18, 0.05, 0.4), black, Vector3(-60, 0, 0))
		_front(sd * 0.36, 0.44, Vector3(0.05, 0.09, 0.12), red, Vector3.ZERO, -0.03)
		_rear(sd * (_rw(0.9) - 0.05), 0.92, Vector3(0.08, 0.30, 0.05), tail)
		_box(Vector3(sd * (hw + 0.05), g + 0.38, 0.0), Vector3(0.12, 0.04, wb - 0.9), black)
	_front(0, 0.44, Vector3(fw * 2.0 + 0.12, 0.17, 0.12), black)
	_box(Vector3(0, g + H + 0.012, (ws_top_z + roof_rear_z) * 0.5), Vector3(hw * 2.0 * 0.955 * float(s["tumble"]) - 0.06, 0.03, ws_top_z - roof_rear_z), black)
	_cyl_z(Vector3(0, g + 0.98, zr - 0.18), tire_rad * 0.95, 0.25, black)
	_cyl_z(Vector3(0, g + 0.98, zr - 0.31), tire_rad * 0.5, 0.02, chrome)
	_rear(0, 0.44, Vector3(_rw(0.4) * 2.0, 0.15, 0.10), black)
	_pipe(Vector3(-0.5, g + 0.32, zr - 0.02), 0.04)

# Toyota Land Cruiser 70: horizontal-slat grille, round headlights in square chrome bezels, big
# chrome bumper, snorkel up the right A-pillar, side steps, spare wheel on the rear door
func _details_landcruiser(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.2)
	_front(0, nose_h - 0.22, Vector3(fw * 2.0 - 0.1, 0.34, 0.02), black)
	for k in range(4):
		_front(0, nose_h - 0.34 + k * 0.08, Vector3(0.80, 0.03, 0.035), chrome, Vector3.ZERO, -0.004)
	for sd in [-1.0, 1.0]:
		_front(sd * (fw - 0.20), nose_h - 0.22, Vector3(0.30, 0.30, 0.03), chrome, Vector3.ZERO, -0.004)
		_oval(Vector3(sd * (fw - 0.20), g + nose_h - 0.22, zf + 0.03), 0.11, 0.11, 0.04, head)
		_front(sd * (fw - 0.04), nose_h - 0.36, Vector3(0.07, 0.06, 0.04), amber)
		_rear(sd * (_rw(0.6) - 0.06), 0.62, Vector3(0.10, 0.22, 0.05), tail)
		_box(Vector3(sd * (hw + 0.06), g + 0.40, 0.0), Vector3(0.14, 0.03, wb - 0.8), black)
	_front(0, 0.46, Vector3(fw * 2.0 + 0.14, 0.18, 0.14), chrome)
	_cyl(Vector3(-(hw + 0.07), g + float(s["cowl"]) + 0.30, cowl_z - 0.02), 0.06, 1.0, black)
	_box(Vector3(-(hw + 0.07), g + float(s["cowl"]) + 0.82, cowl_z + 0.06), Vector3(0.14, 0.12, 0.22), black)
	_cyl_z(Vector3(0.25, g + 1.05, zr - 0.18), tire_rad * 0.95, 0.25, black)
	_cyl_z(Vector3(0.25, g + 1.05, zr - 0.31), tire_rad * 0.5, 0.02, chrome)
	_rear(0, 0.44, Vector3(_rw(0.4) * 2.0 + 0.08, 0.16, 0.12), black)
	_pipe(Vector3(-0.55, g + 0.34, zr - 0.02), 0.04)

# Koenigsegg Jesko: big lower intake with a splitter and canards, thin headlight strips, side
# intakes, round corner tail lamps, swan-neck wing, centre exhaust over a huge diffuser
func _details_jesko(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.4)
	_front(0, 0.26, Vector3(fw * 1.7, 0.16, 0.03), black)
	_splitter()
	for sd in [-1.0, 1.0]:
		_hood_strip(sd * (fw - 0.22), zf - 0.24, 0.28, 0.05, 0.02, drl)
		_hood_strip(sd * (fw - 0.22), zf - 0.30, 0.26, 0.06, 0.015, lens)
		_box(Vector3(sd * (fw - 0.04), g + 0.30, zf - 0.06), Vector3(0.14, 0.025, 0.12), black, Vector3(0, 0, sd * 15))
		_box(Vector3(sd * (taper.call(roof_rear_z, 0.6) + 0.006), g + 0.62, roof_rear_z - 0.1), Vector3(0.02, 0.30, 0.55), black)
		var rw: float = _rw(deck_h - 0.15)
		_ring(Vector3(sd * (rw - 0.18), g + deck_h - 0.17, zr - 0.01), 0.09, tail)
		_box(Vector3(sd * 0.35, g + deck_h + 0.25, zr + 0.36), Vector3(0.04, 0.52, 0.10), black, Vector3(15, 0, 0))
	_box(Vector3(0, g + deck_h + 0.50, zr + 0.30), Vector3(_rw(deck_h) * 1.95, 0.04, 0.38), paint, Vector3(-6, 0, 0))
	_rear(0, 0.30, Vector3(_rw(0.3) * 1.7, 0.20, 0.06), black)
	_pipe(Vector3(0, g + 0.52, zr - 0.01), 0.06)

# McLaren P1: "swoosh"-shaped headlights, deep side intakes, raised active wing on stays, thin
# C-shaped tail light fangs, open mesh tail with a big centre exhaust
func _details_p1(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.4)
	_front(0, 0.25, Vector3(fw * 1.6, 0.13, 0.03), black)
	_splitter()
	for sd in [-1.0, 1.0]:
		_hood_strip(sd * (fw - 0.22), zf - 0.20, 0.32, 0.26, 0.02, lens)
		_hood_strip(sd * (fw - 0.26), zf - 0.22, 0.22, 0.04, 0.03, drl)
		_hood_strip(sd * (fw - 0.13), zf - 0.15, 0.04, 0.14, 0.03, drl)
		_box(Vector3(sd * (taper.call(roof_rear_z + 0.2, 0.5) + 0.006), g + 0.55, roof_rear_z + 0.1), Vector3(0.02, 0.32, 0.7), black)
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.06), deck_h - 0.15, Vector3(0.05, 0.20, 0.04), tail)
		_rear(sd * (rw - 0.18), deck_h - 0.06, Vector3(0.22, 0.04, 0.04), tail)
		_box(Vector3(sd * 0.40, g + deck_h + 0.12, zr + 0.20), Vector3(0.04, 0.24, 0.08), black)
	_box(Vector3(0, g + deck_h + 0.25, zr + 0.18), Vector3(_rw(deck_h) * 1.9, 0.035, 0.34), paint, Vector3(-10, 0, 0))
	_rear(0, 0.42, Vector3(_rw(0.4) * 1.6, 0.30, 0.04), lens)
	_pipe(Vector3(0, g + 0.62, zr - 0.01), 0.08)

# LaFerrari: centre nose prow between two big intakes, slim headlights swept high up the wings,
# door scoops, twin round tail lamps per side, active spoiler, triple centre exhaust
func _details_laferrari(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.35)
	_box(Vector3(0, g + nose_h - 0.06, zf - 0.16), Vector3(0.40, 0.14, 0.40), paint, Vector3(8, 0, 0))
	_splitter()
	for sd in [-1.0, 1.0]:
		_front(sd * (fw * 0.55), 0.26, Vector3(0.45, 0.20, 0.03), black)
		_hood_strip(sd * (fw - 0.18), zf - 0.38, 0.12, 0.36, 0.02, head)
		_box(Vector3(sd * (taper.call(cowl_z - 0.8, 0.5) + 0.006), g + 0.48, cowl_z - 0.9), Vector3(0.02, 0.26, 0.8), black)
		var rw: float = _rw(deck_h - 0.12)
		for k in range(2):
			_ring(Vector3(sd * (rw - 0.16 - k * 0.22), g + deck_h - 0.14, zr - 0.01), 0.07, tail)
	_box(Vector3(0, g + deck_h + 0.04, zr + 0.12), Vector3(_rw(deck_h) * 1.8, 0.05, 0.16), black, Vector3(-15, 0, 0))
	_rear(0, 0.30, Vector3(_rw(0.3) * 1.7, 0.18, 0.06), black)
	for k in range(3):
		_pipe(Vector3((k - 1) * 0.12, g + 0.45, zr - 0.01), 0.045)

# Toyota Corolla: huge trapezoid lower grille, thin upper slot, slim swept headlights, wide tail
# lights joined by a black strip
func _details_corolla(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.55)
	_front_poly(Vector3(0, g + 0.36, zf + 0.012), [Vector2(-0.36, 0.14), Vector2(0.36, 0.14), Vector2(0.62, -0.13), Vector2(-0.62, -0.13)], black)
	_front(0, nose_h - 0.10, Vector3(0.70, 0.04, 0.03), black)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.07, 0.34, 0.07, 0.48, head)
		_front(sd * (fw - 0.22), nose_h - 0.115, Vector3(0.30, 0.015, 0.035), drl)
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.25), deck_h - 0.10, Vector3(0.46, 0.07, 0.04), tail)
	_rear(0, deck_h - 0.10, Vector3(rw_span(0.5), 0.05, 0.03), lens)
	_plates(0.33, deck_h - 0.30)

# VW Passat: wide grille of chrome bars running into the headlights, round logo, chrome lower trims,
# horizontal tail lights, chrome strip across the boot
func _details_passat(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.6)
	_front(0, nose_h - 0.11, Vector3(fw * 1.2, 0.16, 0.03), black)
	for k in range(4):
		_front(0, nose_h - 0.17 + k * 0.04, Vector3(fw * 1.25, 0.012, 0.035), chrome, Vector3.ZERO, -0.003)
	_oval(Vector3(0, g + nose_h - 0.11, zf + 0.03), 0.065, 0.065, 0.02, chrome)
	_front(0, 0.36, Vector3(0.8, 0.16, 0.03), black)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.11, 0.34, 0.11, 0.25, head)
		_front(sd * (fw - 0.12), 0.32, Vector3(0.2, 0.04, 0.03), chrome)
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.24), deck_h - 0.11, Vector3(0.44, 0.10, 0.04), tail)
		_pipe(Vector3(sd * 0.48, g + 0.26, zr - 0.01), 0.04)
	_rear(0, deck_h - 0.11, Vector3(rw_span(0.42), 0.025, 0.03), chrome)
	_plates(0.24, deck_h - 0.30)

# Dacia Logan: slim horizontal grille with the chain-link logo, Y-shaped LED signatures front and
# rear, big black lower intake
func _details_logan(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.65)
	_front(0, nose_h - 0.10, Vector3(fw * 1.3, 0.10, 0.03), black)
	for sd in [-1.0, 1.0]:
		_front(sd * 0.05, nose_h - 0.10, Vector3(0.08, 0.04, 0.04), chrome, Vector3.ZERO, -0.005)
	_front(0, 0.38, Vector3(0.9, 0.2, 0.03), black)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * (fw - 0.20), g + nose_h - 0.10, zf - 0.06), Vector3(0.36, 0.10, 0.12), lens)
		_front(sd * (fw - 0.24), nose_h - 0.075, Vector3(0.14, 0.025, 0.04), drl, Vector3(0, 0, sd * 35), 0.02)
		_front(sd * (fw - 0.13), nose_h - 0.075, Vector3(0.14, 0.025, 0.04), drl, Vector3(0, 0, sd * -35), 0.02)
		_front(sd * (fw - 0.185), nose_h - 0.14, Vector3(0.025, 0.09, 0.04), drl, Vector3.ZERO, 0.02)
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.2), deck_h - 0.12, Vector3(0.32, 0.13, 0.03), lens)
		_rear(sd * (rw - 0.26), deck_h - 0.095, Vector3(0.13, 0.025, 0.04), tail, Vector3(0, 0, sd * -35))
		_rear(sd * (rw - 0.15), deck_h - 0.095, Vector3(0.13, 0.025, 0.04), tail, Vector3(0, 0, sd * 35))
		_rear(sd * (rw - 0.205), deck_h - 0.155, Vector3(0.025, 0.08, 0.04), tail)
	_plates(0.30, deck_h - 0.32)

# Tofas Dogan SLX: flush wrap-around headlights with amber corners, slim slatted black grille,
# body-colour bumpers with a black rubbing strip, wide ribbed tail-light band
func _details_dogan(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.12)
	var gw: float = maxf((fw - 0.44) * 2.0, 0.3)
	_front(0, nose_h - 0.12, Vector3(gw, 0.12, 0.03), black)
	for k in range(4):
		_front(0, nose_h - 0.165 + k * 0.03, Vector3(gw, 0.008, 0.035), lens, Vector3.ZERO, -0.003)
	var rw: float = _rw(deck_h - 0.15)
	for sd in [-1.0, 1.0]:
		_front(sd * (fw - 0.24), nose_h - 0.12, Vector3(0.36, 0.13, 0.04), head)
		_box(Vector3(sd * (fw - 0.02), g + nose_h - 0.12, zf - 0.10), Vector3(0.05, 0.12, 0.2), amber)
		_rear(sd * (rw - 0.27), deck_h - 0.16, Vector3(0.42, 0.14, 0.04), tail)
		for k in range(3):
			_rear(sd * (rw - 0.27), deck_h - 0.205 + k * 0.045, Vector3(0.42, 0.008, 0.045), lens)
	_front(0, 0.40, Vector3(fw * 2.0 + 0.04, 0.13, 0.06), paint)
	_front(0, 0.42, Vector3(fw * 2.0 + 0.05, 0.03, 0.07), black)
	_rear(0, 0.40, Vector3(_rw(0.4) * 2.0 + 0.04, 0.13, 0.06), paint)
	_rear(0, 0.42, Vector3(_rw(0.4) * 2.0 + 0.05, 0.03, 0.07), black)
	_box(Vector3(0, g + 0.37, zf + 0.06), Vector3(0.52, 0.11, 0.01), plate)
	_rear(0, deck_h - 0.22, Vector3(0.52, 0.11, 0.01), plate)

# Murat 131: quad round headlights around a black grille with chrome bars, thin chrome bumpers,
# rectangular red + amber tail lights
func _details_murat131(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.12)
	_front(0, nose_h - 0.12, Vector3(fw * 2.0 - 0.05, 0.18, 0.03), black)
	for k in range(3):
		_front(0, nose_h - 0.17 + k * 0.05, Vector3(0.5, 0.012, 0.035), chrome, Vector3.ZERO, -0.003)
	var rw: float = _rw(deck_h - 0.15)
	for sd in [-1.0, 1.0]:
		for k in range(2):
			_oval(Vector3(sd * (fw - 0.13 - k * 0.21), g + nose_h - 0.12, zf + 0.025), 0.075, 0.075, 0.04, head)
		_front(sd * (fw - 0.06), 0.43, Vector3(0.10, 0.05, 0.04), amber)
		_rear(sd * (rw - 0.18), deck_h - 0.17, Vector3(0.30, 0.14, 0.04), tail)
		_rear(sd * (rw - 0.04), deck_h - 0.17, Vector3(0.06, 0.14, 0.04), amber)
	_front(0, 0.38, Vector3(fw * 2.0 + 0.06, 0.07, 0.08), chrome)
	_rear(0, 0.38, Vector3(_rw(0.4) * 2.0 + 0.06, 0.07, 0.08), chrome)
	_box(Vector3(0, g + 0.30, zf + 0.03), Vector3(0.52, 0.11, 0.01), plate)
	_rear(0, deck_h - 0.30, Vector3(0.52, 0.11, 0.01), plate)

# Renault 12 Toros: wide black band with rectangular headlights at the ends and the diamond in the
# middle, thin chrome bumpers, tall vertical tail lights on a long pointed boot
func _details_toros(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.1)
	_front(0, nose_h - 0.11, Vector3(fw * 2.0 - 0.04, 0.17, 0.03), black)
	for sd in [-1.0, 1.0]:
		_front(sd * (fw - 0.20), nose_h - 0.11, Vector3(0.34, 0.14, 0.04), head)
		_front(sd * (fw - 0.02), nose_h - 0.11, Vector3(0.04, 0.12, 0.04), amber)
		_rear(sd * (_rw(deck_h - 0.2) - 0.08), deck_h - 0.22, Vector3(0.14, 0.28, 0.04), tail)
	_front(0, nose_h - 0.11, Vector3(0.09, 0.09, 0.045), chrome, Vector3(0, 0, 45), -0.003)
	_front(0, 0.38, Vector3(fw * 2.0 + 0.04, 0.06, 0.07), chrome)
	_rear(0, 0.38, Vector3(_rw(0.4) * 2.0 + 0.04, 0.06, 0.07), chrome)
	_box(Vector3(0, g + 0.30, zf + 0.03), Vector3(0.52, 0.11, 0.01), plate)
	_rear(0, deck_h - 0.28, Vector3(0.52, 0.11, 0.01), plate)

# Chevrolet Monte Carlo SS '87 stock car: deep air dam, egg-crate grille between quad rectangular
# headlights, door and roof numbers, wide tail lights
func _details_montecarlo(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.1)
	_front(0, 0.26, Vector3(fw * 2.0, 0.22, 0.05), black)
	_front(0, nose_h - 0.13, Vector3(0.62, 0.20, 0.03), chrome)
	for i in range(5):
		_front(-0.24 + i * 0.12, nose_h - 0.13, Vector3(0.012, 0.17, 0.035), black, Vector3.ZERO, -0.004)
	for j in range(3):
		_front(0, nose_h - 0.19 + j * 0.06, Vector3(0.58, 0.012, 0.035), black, Vector3.ZERO, -0.004)
	var rw: float = _rw(deck_h - 0.12)
	for sd in [-1.0, 1.0]:
		for k in range(2):
			_front(sd * (0.40 + k * 0.20), nose_h - 0.13, Vector3(0.17, 0.11, 0.04), head)
		_rear(sd * (rw - 0.3), deck_h - 0.14, Vector3(0.48, 0.10, 0.03), tail)
		_number(car_number, Vector3(sd * (hw + 0.025), g + 0.62, -0.15), Vector3(0, sd * 90.0, 0), 160)
	_number(car_number, Vector3(0, g + H + 0.012, (ws_top_z + roof_rear_z) * 0.5), Vector3(-90, 180, 0), 140)

# Polaris RZR (UTV): angular bodywork on a tube frame, slim LED headlights, half doors, roll cage
# with a roof panel and LED bar, cargo bed at the back
func _build_utv(_tire_r: float) -> void:
	var cage := _glow(Color(0.07, 0.07, 0.08), 0.0)
	var zfa: float = wb * 0.5
	var zra: float = -wb * 0.5
	var fy: float = g + 0.45
	for sd in [-1.0, 1.0]:
		_tube(Vector3(sd * 0.55, fy, zf - 0.3), Vector3(sd * 0.55, fy, zr + 0.3), 0.04, cage)
	for z in [zf - 0.3, 0.5, -0.5, zr + 0.3]:
		_tube(Vector3(-0.55, fy, z), Vector3(0.55, fy, z), 0.035, cage)
	_box(Vector3(0, fy - 0.03, 0), Vector3(1.1, 0.03, wb), black)
	# angular hood and front fascia with slim LED headlights
	_box(Vector3(0, g + 0.84, zfa - 0.05), Vector3(1.30, 0.26, 1.15), paint, Vector3(-14, 0, 0))
	_box(Vector3(0, g + 0.68, zf - 0.15), Vector3(1.15, 0.34, 0.32), black, Vector3(18, 0, 0))
	_box(Vector3(0, g + 0.47, zf - 0.20), Vector3(0.9, 0.04, 0.5), black, Vector3(-20, 0, 0)) # skid plate
	_tube(Vector3(-0.5, g + 0.62, zf + 0.02), Vector3(0.5, g + 0.62, zf + 0.02), 0.035, cage)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * 0.40, g + 0.80, zf - 0.07), Vector3(0.36, 0.04, 0.06), drl, Vector3(0, 0, sd * 12))
		_box(Vector3(sd * 0.40, g + 0.74, zf - 0.07), Vector3(0.30, 0.05, 0.06), head)
		# fenders over the wheels
		for zc in [zfa, zra]:
			_box(Vector3(sd * 0.74, g + 0.98, zc), Vector3(0.42, 0.05, 0.95), paint, Vector3(0, 0, sd * -12))
			_box(Vector3(sd * 0.74, g + 0.82, zc + 0.5), Vector3(0.40, 0.05, 0.35), paint, Vector3(55, 0, sd * -12))
			_box(Vector3(sd * 0.74, g + 0.82, zc - 0.5), Vector3(0.40, 0.05, 0.35), paint, Vector3(-55, 0, sd * -12))
		# half doors
		_box(Vector3(sd * 0.62, g + 0.72, -0.05), Vector3(0.05, 0.36, 1.05), paint)
	# seats and steering wheel
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * 0.28, g + 0.66, -0.30), Vector3(0.44, 0.20, 0.48), black)
		_box(Vector3(sd * 0.28, g + 1.00, -0.58), Vector3(0.44, 0.65, 0.1), black, Vector3(-10, 0, 0))
	_box(Vector3(0.28, g + 1.02, 0.28), Vector3(0.32, 0.32, 0.04), black, Vector3(-35, 0, 0))
	# roll cage with roof panel and LED bar
	var top_y: float = g + 1.62
	for sd in [-1.0, 1.0]:
		var x: float = sd * 0.6
		_tube(Vector3(x, fy, -0.82), Vector3(x * 0.95, top_y, -0.82), 0.04, cage)
		_tube(Vector3(x, g + 0.9, 0.62), Vector3(x * 0.95, top_y, 0.25), 0.04, cage)
		_tube(Vector3(x * 0.95, top_y, 0.25), Vector3(x * 0.95, top_y, -0.82), 0.04, cage)
	_box(Vector3(0, top_y + 0.04, -0.28), Vector3(1.2, 0.04, 1.1), black)
	_box(Vector3(0, top_y + 0.05, 0.28), Vector3(0.9, 0.08, 0.08), black)
	_box(Vector3(0, top_y + 0.05, 0.325), Vector3(0.84, 0.05, 0.01), drl)
	# cargo bed and tail lights
	_box(Vector3(0, g + 0.92, zra - 0.05), Vector3(1.15, 0.06, 0.8), black)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * 0.56, g + 1.05, zra - 0.05), Vector3(0.05, 0.24, 0.8), paint)
		_box(Vector3(sd * 0.42, g + 0.98, zr + 0.12), Vector3(0.16, 0.05, 0.04), tail)
	_box(Vector3(0, g + 1.05, zr + 0.15), Vector3(1.15, 0.24, 0.05), paint)
	_box(Vector3(0, g + 0.72, zra + 0.2), Vector3(0.6, 0.35, 0.45), _glow(Color(0.35, 0.36, 0.38), 0.0))
	_pipe(Vector3(-0.3, g + 0.65, zr + 0.18), 0.045)

# ------------------------------------------------------------------ lamp helpers
# A headlight that wraps round the corner of the nose: a piece on the front face plus one running
# back along the wing, both lying on the body (rotated boxes used to stick out of the sides).
func _swept_lamp(sd: float, y: float, w: float, h: float, side: float, mat: Material) -> void:
	var fw: float = _fw(y)
	_front(sd * (fw - w * 0.5 - 0.015), y, Vector3(w, h, 0.03), mat)
	if side > 0.0:
		var zc: float = zf - 0.07 - side * 0.5
		_box(Vector3(sd * (taper.call(zc, y) + 0.004), g + y, zc), Vector3(0.02, h * 0.85, side), mat)

# A flat piece lying on the sloping hood / nose at (x, z): lamps on a long low nose, stripes, panels
func _hood_strip(x: float, z: float, w: float, l: float, th: float, mat: Material) -> void:
	var y0: float = _hood_y(z + l * 0.5)
	var y1: float = _hood_y(z - l * 0.5)
	var ang: float = atan2(y1 - y0, l)
	_box(Vector3(x, g + (y0 + y1) * 0.5 + th * 0.5 + 0.004, z), Vector3(w, th, l), mat, Vector3(rad_to_deg(ang), 0, 0))

# ------------------------------------------------------------------ original cars, redone after photos
func _details_accent(nose_h: float, deck_h: float) -> void:
	# Hyundai Accent Blue (RB): hexagonal lower grille, slim chrome upper grille, long swept headlights,
	# fog lamps, wrap-round tail lights, rising character line
	_hex(Vector3(0, g + 0.40, zf + 0.012), 0.95, 0.30, black)
	_front(0, 0.40, Vector3(0.80, 0.02, 0.02), chrome)
	_front(0, nose_h - 0.12, Vector3(0.62, 0.06, 0.03), chrome, Vector3.ZERO, 0.03)
	var fw: float = _fw(0.6)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.08, 0.30, 0.10, 0.45, head)
		_front(sd * (fw - 0.16), 0.36, Vector3(0.14, 0.07, 0.035), head)
		var rw: float = _rw(deck_h - 0.1)
		_swept_rear(sd, deck_h - 0.13, 0.30, 0.13, 0.30, tail)
		_rear(sd * (rw - 0.40), deck_h - 0.10, Vector3(0.20, 0.08, 0.03), tail)
		_box(Vector3(sd * (taper.call(0.0, 0.7) + 0.006), g + 0.72, 0.0), Vector3(0.012, 0.025, L * 0.55), lens)
	_rear(0, deck_h - 0.10, Vector3(0.40, 0.03, 0.02), chrome)
	_plates(0.30, deck_h - 0.28)

# Tail light wrapping round the rear corner (rear face + side piece)
func _swept_rear(sd: float, y: float, w: float, h: float, side: float, mat: Material) -> void:
	var rw: float = _rw(y)
	_rear(sd * (rw - w * 0.5 - 0.015), y, Vector3(w, h, 0.03), mat)
	if side > 0.0:
		var zc: float = zr + 0.07 + side * 0.5
		_box(Vector3(sd * (taper.call(zc, y) + 0.004), g + y, zc), Vector3(0.02, h * 0.85, side), mat)

func _details_egea(nose_h: float, deck_h: float) -> void:
	# Fiat Egea / Tipo sedan: wide chrome-barred grille with the FIAT badge between large headlights,
	# trapezoid lower grille with a chrome lip, horizontal tail lights joined by a chrome bar
	var fw: float = _fw(0.6)
	_front(0, nose_h - 0.12, Vector3(0.80, 0.15, 0.03), black)
	for k in range(3):
		_front(0, nose_h - 0.09 - k * 0.045, Vector3(0.78, 0.022, 0.03), chrome, Vector3.ZERO, -0.004)
	_front(0, nose_h - 0.12, Vector3(0.20, 0.06, 0.04), chrome, Vector3.ZERO, -0.01)
	_front(0, 0.38, Vector3(0.95, 0.20, 0.03), black)
	_front(0, 0.47, Vector3(0.95, 0.02, 0.035), chrome)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.10, 0.40, 0.15, 0.30, head)
		_front(sd * (fw - 0.12), 0.33, Vector3(0.14, 0.06, 0.04), head)
		_swept_rear(sd, deck_h - 0.13, 0.38, 0.13, 0.22, tail)
	_rear(0, deck_h - 0.13, Vector3(rw_span(0.36), 0.035, 0.03), chrome)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * (taper.call((cowl_z + deck_z) * 0.5, float(s["belt"])) + 0.01), g + float(s["belt"]) + 0.005, (cowl_z + deck_z) * 0.5), Vector3(0.012, 0.02, cowl_z - deck_z), chrome)
	_plates(0.30, deck_h - 0.30)

func _details_civic(nose_h: float, deck_h: float) -> void:
	# Honda Civic (10th gen) sedan: thin sharp headlights joined by the thick chrome "wing" bar, big
	# black honeycomb grille with corner intakes, boomerang (C) tail lights
	var fw: float = _fw(0.55)
	_front(0, nose_h - 0.09, Vector3(fw * 1.25, 0.05, 0.04), chrome, Vector3.ZERO, 0.03)
	_front(0, 0.38, Vector3(0.80, 0.22, 0.03), black)
	for k in range(4):
		_front(0, 0.30 + k * 0.05, Vector3(0.76, 0.008, 0.035), lens, Vector3.ZERO, -0.004)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.075, 0.36, 0.07, 0.48, head)
		_front(sd * (fw - 0.22), nose_h - 0.12, Vector3(0.26, 0.015, 0.035), drl)
		_box(Vector3(sd * (fw - 0.10), g + 0.34, zf - 0.03), Vector3(0.24, 0.20, 0.05), black, Vector3(0, 0, sd * 25))
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.30), deck_h - 0.09, Vector3(0.48, 0.06, 0.04), tail)
		_swept_rear(sd, deck_h - 0.22, 0.10, 0.24, 0.18, tail)
	_rear(0, 0.32, Vector3(_rw(0.3) * 1.6, 0.10, 0.04), black)
	for sd in [-1.0, 1.0]:
		_pipe(Vector3(sd * hw * 0.6, g + 0.24, zr - 0.02), 0.04)
	_plates(0.28, deck_h - 0.30)

func _details_megane(nose_h: float, deck_h: float) -> void:
	# Renault Megane IV sedan: C-shaped LED lights around the headlights, grille with a chrome bar and
	# the diamond, slim horizontal tail lights joined by a chrome strip
	var fw: float = _fw(0.6)
	_front(0, nose_h - 0.12, Vector3(0.70, 0.13, 0.03), black, Vector3.ZERO, 0.02)
	_front(0, nose_h - 0.08, Vector3(0.74, 0.02, 0.035), chrome, Vector3.ZERO, 0.02)
	_front(0, nose_h - 0.12, Vector3(0.10, 0.10, 0.04), chrome, Vector3(0, 0, 45), 0.0)
	_front(0, 0.38, Vector3(0.90, 0.18, 0.03), black)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.085, 0.34, 0.10, 0.32, head)
		_box(Vector3(sd * (fw - 0.05), g + 0.42, zf - 0.03), Vector3(0.03, 0.22, 0.04), drl)
		_box(Vector3(sd * (fw - 0.14), g + 0.32, zf - 0.01), Vector3(0.18, 0.03, 0.04), drl)
		_swept_rear(sd, deck_h - 0.11, 0.50, 0.07, 0.25, tail)
	_rear(0, deck_h - 0.11, Vector3(rw_span(0.5), 0.025, 0.03), chrome)
	_plates(0.28, deck_h - 0.30)

func _details_gtr(nose_h: float, deck_h: float) -> void:
	# Nissan GT-R R35: big inverted-trapezoid mesh grille in a chrome frame, boomerang headlights with
	# an LED strip under them, corner intakes, front-wing vents, hood ridges, quad ROUND tail lights,
	# quad exhausts and a diffuser
	var fw: float = _fw(0.55)
	_front_poly(Vector3(0, g + 0.42, zf + 0.012), [Vector2(-0.43, 0.13), Vector2(0.43, 0.13), Vector2(0.31, -0.15), Vector2(-0.31, -0.15)], chrome)
	_front_poly(Vector3(0, g + 0.42, zf + 0.016), [Vector2(-0.39, 0.11), Vector2(0.39, 0.11), Vector2(0.28, -0.13), Vector2(-0.28, -0.13)], black)
	for k in range(3):
		_front(0, 0.34 + k * 0.06, Vector3(0.62 - (2 - k) * 0.08, 0.008, 0.04), lens, Vector3.ZERO, -0.01)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.07, 0.34, 0.09, 0.42, head)
		_front(sd * (fw - 0.18), nose_h - 0.14, Vector3(0.22, 0.02, 0.035), drl)
		_front(sd * (fw - 0.10), 0.30, Vector3(0.22, 0.16, 0.03), black)
		var vz: float = wb * 0.5 - 0.72
		_box(Vector3(sd * (taper.call(vz, 0.7) + 0.006), g + 0.68, vz), Vector3(0.02, 0.14, 0.30), black)
		_hood_strip(sd * 0.30, (zf + cowl_z) * 0.5 - 0.1, 0.05, (zf - cowl_z) * 0.6, 0.025, paint)
		var rw: float = _rw(deck_h - 0.1)
		for k in range(2):
			_ring(Vector3(sd * (rw - 0.18 - k * 0.27), g + deck_h - 0.16, zr - 0.01), 0.10, tail)
		_cyl_back(Vector3(sd * 0.35, g + 0.27, zr - 0.02), 0.05, chrome)
		_cyl_back(Vector3(sd * 0.47, g + 0.27, zr - 0.02), 0.05, chrome)
	_rear(0, 0.30, Vector3(_rw(0.3) * 1.5, 0.08, 0.05), black)
	_plates(0.25, deck_h - 0.34)

func _details_supra(nose_h: float, deck_h: float) -> void:
	# Toyota Supra A80: long low round nose with big oval headlight clusters (three round lamps each in a
	# dark lens), small oval mouth with fog lamps, round tail lights in a full-width dark lens
	var fw: float = _fw(0.5)
	_front(0, 0.30, Vector3(0.64, 0.12, 0.03), black)
	for sd in [-1.0, 1.0]:
		var lz: float = zf - 0.24
		_oval(Vector3(sd * (fw - 0.27), g + _hood_y(lz) + 0.02, lz), 0.22, 0.15, 0.03, lens, Vector3(-72, 0, 0))
		for k in range(3):
			var kz: float = lz + 0.06 - k * 0.06
			_oval(Vector3(sd * (fw - 0.39 + k * 0.12), g + _hood_y(kz) + 0.04, kz), 0.045, 0.045, 0.03, head, Vector3(-72, 0, 0))
		_front(sd * (fw - 0.12), 0.30, Vector3(0.16, 0.06, 0.04), amber)
	var rw2: float = _rw(deck_h - 0.1)
	_rear(0, deck_h - 0.17, Vector3(rw2 * 1.85, 0.20, 0.03), lens)
	for sd in [-1.0, 1.0]:
		for k in range(2):
			_ring(Vector3(sd * (rw2 - 0.20 - k * 0.28), g + deck_h - 0.17, zr - 0.02), 0.085, tail)
		_cyl_back(Vector3(sd * 0.45, g + 0.27, zr - 0.02), 0.055, chrome)
	_plates(0.27, deck_h - 0.36)

func _details_challenger(nose_h: float, deck_h: float) -> void:
	# Dodge Challenger SRT Hellcat: full-width black grille with quad round headlights (the inner
	# left one is the "air catcher" intake), hood scoop with twin heat extractors, fender scoops, front
	# splitter, racetrack full-width tail-light ring
	var fw: float = _fw(0.7)
	_front(0, nose_h - 0.15, Vector3(fw * 1.9, 0.24, 0.03), black)
	for sd in [-1.0, 1.0]:
		for k in range(2):
			var intake: bool = sd > 0.0 and k == 1
			_ring(Vector3(sd * (fw - 0.16 - k * 0.24), g + nose_h - 0.15, zf + 0.02), 0.085, lens if intake else head)
		_box(Vector3(sd * (fw - 0.1), g + 0.36, zf - 0.005), Vector3(0.18, 0.06, 0.04), amber)
		_cyl_back(Vector3(sd * 0.55, g + 0.26, zr - 0.02), 0.06, chrome)
		_box(Vector3(sd * (taper.call(wb * 0.5 - 0.7, 0.7) + 0.006), g + 0.70, wb * 0.5 - 0.7), Vector3(0.02, 0.12, 0.25), black)
		_hood_strip(sd * 0.36, cowl_z + 0.55, 0.20, 0.30, 0.02, black)
	_front(0, 0.38, Vector3(1.0, 0.12, 0.03), black)
	_splitter()
	_hood_strip(0, (zf + cowl_z) * 0.5 - 0.15, 0.55, L * float(s["hood"]) * 0.7, 0.06, paint)
	_hood_strip(0, (zf + cowl_z) * 0.5 + 0.15, 0.30, 0.25, 0.08, black)
	_rear(0, deck_h - 0.14, Vector3(_rw(deck_h - 0.1) * 1.9, 0.14, 0.04), tail)
	_rear(0, deck_h - 0.14, Vector3(_rw(deck_h - 0.1) * 1.75, 0.08, 0.045), lens)
	_plates(0.30, deck_h - 0.34)

func _details_chiron(nose_h: float, deck_h: float) -> void:
	# Bugatti Chiron: two-tone (dark nose and hood), horseshoe grille, quad-LED headlight strips, the big
	# chrome C-line on the side, central roof spine and roof scoop, full-width rear light bar, huge
	# centre exhaust & diffuser
	var fw: float = _fw(0.45)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.035, 0.045)
	dark.metallic = 0.6
	dark.roughness = 0.25
	_hood_strip(0, (zf + cowl_z) * 0.5, fw * 1.75, (zf - cowl_z) * 0.9, 0.012, dark)
	_horseshoe(Vector3(0, g + 0.36, zf + 0.012))
	for sd in [-1.0, 1.0]:
		for k in range(4):
			var kz: float = zf - 0.15 - k * 0.02
			_box(Vector3(sd * (fw - 0.16 - k * 0.07), g + _hood_y(kz) - 0.01, kz), Vector3(0.05, 0.04, 0.18), drl, Vector3(-10, 0, 0))
		_box(Vector3(sd * (fw - 0.12), g + 0.28, zf - 0.03), Vector3(0.40, 0.14, 0.04), black)
		var cx: float = sd * (taper.call(cowl_z - 0.8, 0.6) + 0.01)
		_box(Vector3(cx, g + 0.62, cowl_z - 0.55), Vector3(0.02, 0.06, 1.05), chrome)
		_box(Vector3(cx, g + 0.42, cowl_z - 1.05), Vector3(0.02, 0.42, 0.06), chrome)
		_box(Vector3(sd * (taper.call(cowl_z - 1.25, 0.5) + 0.006), g + 0.45, cowl_z - 1.25), Vector3(0.02, 0.30, 0.30), black)
	_box(Vector3(0, g + H + 0.02, (ws_top_z + deck_z) * 0.5), Vector3(0.05, 0.05, ws_top_z - deck_z), paint)
	_box(Vector3(0, g + H - 0.02, roof_rear_z - 0.15), Vector3(0.40, 0.10, 0.30), black)
	_rear(0, deck_h - 0.12, Vector3(_rw(deck_h) * 1.92, 0.05, 0.04), tail)
	_rear(0, 0.34, Vector3(_rw(0.3) * 1.7, 0.18, 0.06), black)
	_box(Vector3(0, g + 0.50, zr + 0.02), Vector3(0.80, 0.14, 0.05), black)
	_pipe(Vector3(0, g + 0.50, zr - 0.01), 0.07)
	_plates(0.24, 0.62)

# Ford F-150 Raptor based Baja trophy truck: black grille with the four big letters between C-clamp
# LED headlights, tube bumper with an LED bar, huge fender flares, roof light bar, roll cage and a
# spare wheel in the open bed
func _details_trophy(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.2)
	_front(0, nose_h - 0.22, Vector3(fw * 2.0 - 0.15, 0.36, 0.03), black)
	for k in range(4):
		_front(-0.33 + k * 0.22, nose_h - 0.22, Vector3(0.14, 0.18, 0.04), paint, Vector3.ZERO, -0.005)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.16, 0.24, 0.12, 0.25, head)
		_front(sd * (fw - 0.06), nose_h - 0.24, Vector3(0.025, 0.22, 0.04), drl)
		for zc in [wb * 0.5, -wb * 0.5]:
			_box(Vector3(sd * (hw + 0.06), g + tire_rad * 2.0 + 0.12, zc), Vector3(0.22, 0.06, 1.25), black)
			_box(Vector3(sd * (hw + 0.06), g + tire_rad * 1.5, zc + 0.66), Vector3(0.22, 0.06, 0.5), black, Vector3(60, 0, 0))
			_box(Vector3(sd * (hw + 0.06), g + tire_rad * 1.5, zc - 0.66), Vector3(0.22, 0.06, 0.5), black, Vector3(-60, 0, 0))
		_rear(sd * (_rw(deck_h - 0.2) - 0.06), deck_h - 0.22, Vector3(0.08, 0.26, 0.05), tail)
	var cage := _glow(Color(0.07, 0.07, 0.08), 0.0)
	_tube(Vector3(-0.75, g + 0.50, zf + 0.12), Vector3(0.75, g + 0.50, zf + 0.12), 0.05, cage)
	_tube(Vector3(-0.55, g + 0.75, zf + 0.10), Vector3(0.55, g + 0.75, zf + 0.10), 0.04, cage)
	_box(Vector3(0, g + 0.76, zf + 0.14), Vector3(0.9, 0.06, 0.04), drl)
	_box(Vector3(0, g + H + 0.06, ws_top_z - 0.05), Vector3(1.4, 0.08, 0.10), black)
	_box(Vector3(0, g + H + 0.06, ws_top_z - 0.005), Vector3(1.32, 0.05, 0.01), drl)
	# open bed: floor, spare wheel lying in it, roll bars over the cab and down to the tail
	_box(Vector3(0, g + deck_h + 0.01, (deck_z + zr) * 0.5), Vector3(hw * 1.7, 0.02, deck_z - zr - 0.1), black)
	_cyl(Vector3(0, g + deck_h + 0.14, (deck_z + zr) * 0.5), tire_rad * 0.95, 0.26, black)
	for sd in [-1.0, 1.0]:
		_tube(Vector3(sd * 0.6, g + H, roof_rear_z), Vector3(sd * 0.6, g + deck_h, zr + 0.2), 0.04, cage)
	_tube(Vector3(-0.6, g + H, roof_rear_z), Vector3(0.6, g + H, roof_rear_z), 0.04, cage)
	_pipe(Vector3(0.6, g + 0.45, zr - 0.02), 0.06)

# ------------------------------------------------------------------ third batch (after photos)
# Porsche Taycan: no grille, slim headlights on the raised wings with the four-point LED
# signature, big vertical air curtains, full-width rear light bar, black diffuser (no pipes)
func _details_taycan(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.5)
	for sd in [-1.0, 1.0]:
		var lz: float = zf - 0.22
		_hood_strip(sd * (fw - 0.24), lz, 0.30, 0.22, 0.03, lens)
		for k in range(4):
			_hood_strip(sd * (fw - 0.24) + (0.05 if k % 2 == 0 else -0.05), lz + (0.04 if k < 2 else -0.04), 0.06, 0.03, 0.04, drl)
		_front(sd * (fw - 0.10), 0.36, Vector3(0.10, 0.24, 0.03), black)
	_front(0, 0.30, Vector3(fw * 1.2, 0.08, 0.03), black)
	var rw: float = _rw(deck_h - 0.1)
	_rear(0, deck_h - 0.10, Vector3(rw * 1.94, 0.05, 0.035), tail)
	_rear(0, deck_h - 0.16, Vector3(rw * 1.6, 0.05, 0.03), lens)
	_rear(0, 0.30, Vector3(_rw(0.3) * 1.6, 0.12, 0.05), black)
	_roof_cap(glass)
	_plates(0.42, deck_h - 0.32)

# Tesla Model S Plaid: smooth nose cone with the T badge, slim swept headlights, small lower
# intake, glass roof, black trim, swept tail lights
func _details_models(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.6)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.06, 0.30, 0.07, 0.42, head)
		_front(sd * (fw - 0.10), 0.34, Vector3(0.14, 0.12, 0.03), black)
		_swept_rear(sd, deck_h - 0.10, 0.36, 0.08, 0.30, tail)
	_front(0, nose_h - 0.06, Vector3(0.08, 0.06, 0.035), chrome)
	_front(0, 0.33, Vector3(0.62, 0.10, 0.03), black)
	_roof_cap(glass)
	_rear(0, 0.30, Vector3(_rw(0.3) * 1.4, 0.08, 0.04), black)
	_plates(0.40, deck_h - 0.30)

# Tesla Model 3 (Highland): smooth low nose, very slim headlights, black glass roof, C-shaped
# tail lights, no grille
func _details_model3(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.55)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.05, 0.30, 0.045, 0.45, head)
		_front(sd * (fw - 0.08), 0.32, Vector3(0.10, 0.06, 0.03), black)
		var rw: float = _rw(deck_h - 0.1)
		_rear(sd * (rw - 0.20), deck_h - 0.09, Vector3(0.34, 0.035, 0.04), tail)
		_rear(sd * (rw - 0.05), deck_h - 0.13, Vector3(0.04, 0.10, 0.04), tail)
	_front(0, nose_h - 0.05, Vector3(0.07, 0.05, 0.035), chrome)
	_front(0, 0.30, Vector3(0.56, 0.06, 0.03), black)
	_roof_cap(glass)
	_plates(0.38, deck_h - 0.28)

# TOGG T10X: tall hexagonal grille with the tulip pattern, a light bar joining the slim headlights,
# black wheel-arch cladding, roof rails, full-width tail-light bar
func _details_togg(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.2)
	_front(0, nose_h - 0.30, Vector3(1.15, 0.42, 0.03), black) # grille
	for k in range(13):
		_front(-0.54 + k * 0.09, nose_h - 0.30, Vector3(0.025, 0.40, 0.04), chrome, Vector3.ZERO, -0.005)
	_front(0, nose_h - 0.07, Vector3(fw * 1.9, 0.025, 0.035), drl) # light bar
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.10, 0.28, 0.06, 0.35, head)
		_front(sd * (fw - 0.12), 0.40, Vector3(0.22, 0.20, 0.03), black) # corner intakes
		for zc in [wb * 0.5, -wb * 0.5]:
			_box(Vector3(sd * (hw + 0.01), g + tire_rad * 2.0 + 0.05, zc), Vector3(0.05, 0.06, tire_rad * 2.4), black)
		_box(Vector3(sd * (taper.call(0.0, 0.42) + 0.01), g + 0.42, 0.0), Vector3(0.03, 0.14, wb - 0.9), black) # sill cladding
		_box(Vector3(sd * hw * 0.78, g + H + 0.025, (ws_top_z + roof_rear_z) * 0.5), Vector3(0.04, 0.04, ws_top_z - roof_rear_z), black)
		_rear(sd * (_rw(deck_h) - 0.14), deck_h - 0.10, Vector3(0.26, 0.08, 0.04), tail)
	_rear(0, deck_h - 0.08, Vector3(_rw(deck_h) * 1.9, 0.025, 0.035), tail)
	_box(Vector3(0, g + H - 0.02, roof_rear_z - 0.05), Vector3(hw * 1.5, 0.05, 0.3), paint) # roof spoiler
	_front(0, 0.36, Vector3(fw * 1.7, 0.16, 0.04), black)
	_rear(0, 0.38, Vector3(_rw(0.4) * 1.9, 0.18, 0.05), black)
	_plates(0.50, deck_h - 0.34)

# Pagani Huayra: twin stacked oval headlights per side on the nose, carbon centre with a red
# stripe, four active flaps, quad pipes in a centre circle, round tail lamps
func _details_huayra(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(0.45)
	var carbon := _glow(Color(0.06, 0.06, 0.07), 0.0)
	var red := _glow(Color(0.85, 0.05, 0.05), 0.2)
	_hood_strip(0, (zf + cowl_z) * 0.5, 0.5, (zf - cowl_z) * 0.85, 0.01, carbon)
	_hood_strip(0.08, (zf + cowl_z) * 0.5, 0.06, (zf - cowl_z) * 0.85, 0.02, red)
	for sd in [-1.0, 1.0]:
		for k in range(2):
			var lz: float = zf - 0.18 - k * 0.16
			_oval(Vector3(sd * (fw - 0.22), g + _hood_y(lz) + 0.02, lz), 0.07, 0.09, 0.04, head, Vector3(-60, 0, 0))
		_front(sd * (fw - 0.16), 0.30, Vector3(0.36, 0.16, 0.03), black)
		_box(Vector3(sd * 0.75, g + deck_h + 0.02, zr + 0.35), Vector3(0.35, 0.02, 0.25), paint, Vector3(-12, 0, 0))
		_hood_strip(sd * 0.55, zf - 0.55, 0.30, 0.22, 0.02, paint)
		_ring(Vector3(sd * (_rw(deck_h) - 0.22), g + deck_h - 0.14, zr - 0.01), 0.07, tail)
	_rear(0, 0.42, Vector3(0.42, 0.30, 0.04), black)
	for k in range(4):
		var a: float = PI * 0.25 + k * PI * 0.5
		_pipe(Vector3(cos(a) * 0.08, g + 0.44 + sin(a) * 0.08, zr - 0.02), 0.04)
	_rear(0, 0.26, Vector3(_rw(0.3) * 1.6, 0.10, 0.06), black)
	_plates(0.22, 0.62)

# Fiat 126 (Serce): plain smooth front with a chrome bar and badge, square headlights, thin chrome
# bumpers, louvred engine lid at the back, small tail lights, pipe under the tail
func _details_serce(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.12)
	for sd in [-1.0, 1.0]:
		_front(sd * (fw - 0.14), nose_h - 0.14, Vector3(0.17, 0.12, 0.04), head)
		_front(sd * (fw - 0.06), 0.44, Vector3(0.07, 0.04, 0.04), amber)
		_rear(sd * (_rw(deck_h - 0.15) - 0.09), deck_h - 0.16, Vector3(0.14, 0.10, 0.04), tail)
	_front(0, nose_h - 0.10, Vector3(0.36, 0.02, 0.035), chrome)
	_front(0, nose_h - 0.14, Vector3(0.06, 0.04, 0.04), chrome)
	_front(0, 0.36, Vector3(fw * 2.0 + 0.04, 0.04, 0.06), chrome)
	_rear(0, 0.36, Vector3(_rw(0.4) * 2.0 + 0.04, 0.04, 0.06), chrome)
	for k in range(6):
		_rear(0, deck_h - 0.24 - k * 0.035, Vector3(0.50, 0.012, 0.035), black)
	_pipe(Vector3(-0.30, g + 0.26, zr - 0.01), 0.025)
	_box(Vector3(0, g + 0.31, zf + 0.03), Vector3(0.40, 0.09, 0.01), plate)
	_rear(0, 0.48, Vector3(0.40, 0.09, 0.01), plate)

# Tofas Kartal: the Sahin face and bumpers, roof rails, tall tail lights beside the tailgate
func _details_kartal(nose_h: float, deck_h: float) -> void:
	_details_sahin(nose_h, deck_h)
	for sd in [-1.0, 1.0]:
		_box(Vector3(sd * hw * 0.80, g + H + 0.025, (ws_top_z + roof_rear_z) * 0.5 - 0.1), Vector3(0.035, 0.035, ws_top_z - roof_rear_z - 0.2), black)

# Chevrolet Bel Air '57: full-width chrome grille and bumper with "Dagmar" bullets, hooded round
# headlights, twin hood spears, white roof, chrome side spear with a gold-anodised panel,
# chrome-edged tail fins with round lamps
func _details_belair(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.15)
	var white := _glow(Color(0.94, 0.94, 0.90), 0.0)
	var gold := _glow(Color(0.80, 0.68, 0.40), 0.1)
	_front(0, nose_h - 0.20, Vector3(fw * 2.0 - 0.10, 0.20, 0.03), black)
	for k in range(4):
		_front(0, nose_h - 0.28 + k * 0.05, Vector3(fw * 2.0 - 0.14, 0.015, 0.035), chrome, Vector3.ZERO, -0.003)
	_front(0, 0.40, Vector3(fw * 2.0 + 0.10, 0.12, 0.10), chrome)
	for sd in [-1.0, 1.0]:
		_oval(Vector3(sd * (fw - 0.14), g + nose_h - 0.08, zf + 0.01), 0.10, 0.10, 0.06, chrome)
		_oval(Vector3(sd * (fw - 0.14), g + nose_h - 0.08, zf + 0.03), 0.08, 0.08, 0.04, head)
		_cyl_z(Vector3(sd * 0.40, g + 0.40, zf + 0.10), 0.06, 0.12, chrome)
		_hood_strip(sd * 0.22, (zf + cowl_z) * 0.5 + 0.2, 0.03, 0.45, 0.02, chrome)
		var sx: float = sd * (taper.call(-0.6, 0.7) + 0.008)
		_box(Vector3(sx, g + 0.70, -0.4), Vector3(0.02, 0.025, wb * 0.9), chrome)
		_box(Vector3(sd * (taper.call(-wb * 0.5 - 0.35, 0.8) + 0.008), g + 0.80, -wb * 0.5 - 0.35), Vector3(0.015, 0.10, 0.9), gold)
		var fx: float = sd * (_rw(deck_h) - 0.06)
		_box(Vector3(fx, g + deck_h + 0.05, zr + 0.45), Vector3(0.10, 0.10, 0.9), paint, Vector3(-6, 0, 0))
		_box(Vector3(fx, g + deck_h + 0.105, zr + 0.45), Vector3(0.11, 0.015, 0.9), chrome, Vector3(-6, 0, 0))
		_ring(Vector3(fx, g + deck_h - 0.02, zr - 0.01), 0.06, tail)
	_roof_cap(white)
	_rear(0, 0.42, Vector3(_rw(0.4) * 2.0 + 0.08, 0.14, 0.10), chrome)
	_box(Vector3(0, g + 0.38, zf + 0.10), Vector3(0.52, 0.11, 0.01), plate)
	_rear(0, deck_h - 0.20, Vector3(0.52, 0.11, 0.01), plate)

# Dodge Charger R/T '69: full-width black grille split in the middle with hidden headlights, thin
# chrome bumpers, twin hood bulges, black vinyl roof, white stripe round the tail, split rectangular
# tail lights on a black panel
func _details_charger69(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.12)
	var white := _glow(Color(0.9, 0.9, 0.88), 0.0)
	_front(0, nose_h - 0.14, Vector3(fw * 2.0, 0.25, 0.025), chrome, Vector3.ZERO, 0.004)
	_front(0, nose_h - 0.14, Vector3(fw * 2.0 - 0.04, 0.22, 0.03), black)
	_front(0, nose_h - 0.14, Vector3(0.05, 0.22, 0.04), chrome, Vector3.ZERO, -0.003)
	for k in range(6):
		_front(0, nose_h - 0.22 + k * 0.03, Vector3(fw * 2.0 - 0.12, 0.006, 0.035), lens, Vector3.ZERO, -0.003)
	_front(0, 0.42, Vector3(fw * 2.0 + 0.06, 0.07, 0.08), chrome)
	_rear(0, 0.42, Vector3(_rw(0.4) * 2.0 + 0.06, 0.07, 0.08), chrome)
	var rw: float = _rw(deck_h - 0.12)
	_rear(0, deck_h - 0.13, Vector3(rw * 1.95, 0.16, 0.03), black)
	for sd in [-1.0, 1.0]:
		_hood_strip(sd * 0.30, (zf + cowl_z) * 0.5, 0.22, (zf - cowl_z) * 0.6, 0.025, paint)
		_hood_strip(sd * 0.30, (zf + cowl_z) * 0.5 - 0.25, 0.14, 0.12, 0.03, black)
		_rear(sd * (rw - 0.22), deck_h - 0.13, Vector3(0.34, 0.09, 0.04), tail)
		_rear(sd * (rw - 0.60), deck_h - 0.13, Vector3(0.30, 0.09, 0.04), tail)
		_pipe(Vector3(sd * 0.45, g + 0.30, zr - 0.02), 0.045)
		_box(Vector3(sd * (_rw(deck_h - 0.05) + 0.004), g + deck_h - 0.05, zr + 0.45), Vector3(0.02, 0.06, 0.9), white)
	_roof_cap(black)
	_box(Vector3(0, g + deck_h + 0.006, zr + 0.25), Vector3(rw * 1.7, 0.012, 0.06), white)
	_box(Vector3(0, g + 0.38, zf + 0.08), Vector3(0.52, 0.11, 0.01), plate)
	_rear(0, 0.56, Vector3(0.52, 0.11, 0.01), plate)

# Shelby GT500 '67: wide black mesh mouth with the two high beams in the middle, round headlights
# at the corners, hood scoop, white Le Mans stripes over hood, roof and deck, side scoops,
# full-width tail lights, ducktail
func _details_gt500(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.12)
	var white := _glow(Color(0.94, 0.94, 0.92), 0.0)
	_front(0, nose_h - 0.16, Vector3(fw * 2.0 - 0.06, 0.24, 0.03), black)
	for sd in [-1.0, 1.0]:
		_oval(Vector3(sd * (fw - 0.14), g + nose_h - 0.15, zf + 0.025), 0.085, 0.085, 0.04, head)
		_oval(Vector3(sd * 0.12, g + nose_h - 0.15, zf + 0.025), 0.07, 0.07, 0.04, head)
		_hood_strip(sd * 0.14, (zf + cowl_z) * 0.5, 0.20, zf - cowl_z, 0.012, white)
		_box(Vector3(sd * 0.14, g + H + 0.006, (ws_top_z + roof_rear_z) * 0.5), Vector3(0.20, 0.012, ws_top_z - roof_rear_z + 0.25), white)
		_box(Vector3(sd * 0.14, g + deck_h + 0.03, zr + 0.25), Vector3(0.20, 0.012, 0.45), white)
		var vz: float = -wb * 0.5 + 0.55
		_box(Vector3(sd * (taper.call(vz, 0.75) + 0.02), g + 0.75, vz), Vector3(0.05, 0.12, 0.25), black)
		_box(Vector3(sd * (taper.call(0.0, 0.40) + 0.006), g + 0.38, 0.0), Vector3(0.012, 0.035, wb - 2.0 * tire_rad - 0.3), white)
		_pipe(Vector3(sd * 0.42, g + 0.28, zr - 0.02), 0.045)
	_hood_strip(0, cowl_z + 0.55, 0.36, 0.40, 0.07, paint)
	_hood_strip(0, cowl_z + 0.74, 0.32, 0.02, 0.06, black)
	_front(0, 0.42, Vector3(fw * 2.0 + 0.04, 0.05, 0.07), chrome)
	_rear(0, deck_h - 0.12, Vector3(_rw(deck_h - 0.1) * 1.9, 0.12, 0.035), tail)
	_rear(0, 0.42, Vector3(_rw(0.4) * 2.0 + 0.04, 0.05, 0.07), chrome)
	_box(Vector3(0, g + 0.30, zf + 0.03), Vector3(0.52, 0.11, 0.01), plate)
	_rear(0, deck_h - 0.30, Vector3(0.52, 0.11, 0.01), plate)

# Mercedes-Benz S 600 (W140): upright chrome grille with the star on top, wide rectangular
# headlights with the indicators outboard, grey lower cladding with a rubbing strip, big ribbed
# tail lights, chrome strip on the boot, twin pipes
func _details_s600(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.12)
	var grey := _glow(Color(0.22, 0.23, 0.25), 0.0)
	_front(0, nose_h - 0.13, Vector3(0.44, 0.24, 0.05), chrome, Vector3.ZERO, -0.01)
	_front(0, nose_h - 0.14, Vector3(0.38, 0.19, 0.06), black, Vector3.ZERO, -0.012)
	for k in range(5):
		_front(-0.16 + k * 0.08, nose_h - 0.14, Vector3(0.015, 0.19, 0.065), chrome, Vector3.ZERO, -0.013)
	_cyl(Vector3(0, g + nose_h + 0.03, zf - 0.04), 0.04, 0.05, chrome)
	for sd in [-1.0, 1.0]:
		_front(sd * (fw - 0.30), nose_h - 0.12, Vector3(0.36, 0.15, 0.04), head)
		_swept_lamp(sd, nose_h - 0.12, 0.10, 0.15, 0.20, amber)
		_box(Vector3(sd * (taper.call(0.0, 0.45) + 0.006), g + 0.45, 0.0), Vector3(0.02, 0.18, wb - 2.0 * tire_rad - 0.3), grey)
		_box(Vector3(sd * (taper.call(0.0, 0.52) + 0.02), g + 0.52, 0.0), Vector3(0.02, 0.03, wb - 2.0 * tire_rad - 0.3), black)
		var rw: float = _rw(deck_h - 0.15)
		_swept_rear(sd, deck_h - 0.16, 0.48, 0.18, 0.22, tail)
		for k in range(5):
			_rear(sd * (rw - 0.255), deck_h - 0.24 + k * 0.04, Vector3(0.48, 0.008, 0.04), lens)
		_pipe(Vector3(sd * 0.52, g + 0.26, zr - 0.01), 0.045)
	_front(0, 0.40, Vector3(fw * 2.0 + 0.04, 0.20, 0.06), grey)
	_rear(0, 0.40, Vector3(_rw(0.4) * 2.0 + 0.04, 0.20, 0.06), grey)
	_rear(0, deck_h - 0.05, Vector3(0.70, 0.02, 0.03), chrome)
	_box(Vector3(0, g + 0.34, zf + 0.04), Vector3(0.52, 0.11, 0.01), plate)
	_rear(0, deck_h - 0.30, Vector3(0.52, 0.11, 0.01), plate)

# Range Rover Sport (L494): wide black mesh grille between slim headlights with an LED blade, front
# door side vents, floating black roof, slim tail lights, quad pipes, black lower trim
func _details_rrsport(nose_h: float, deck_h: float) -> void:
	var fw: float = _fw(nose_h - 0.15)
	_front(0, nose_h - 0.13, Vector3(fw * 2.0 - 0.80, 0.15, 0.03), black)
	for r in range(3):
		for c in range(8):
			_front(-0.28 + c * 0.08, nose_h - 0.18 + r * 0.05, Vector3(0.04, 0.025, 0.035), lens, Vector3(0, 0, 45), -0.003)
	for sd in [-1.0, 1.0]:
		_swept_lamp(sd, nose_h - 0.12, 0.36, 0.09, 0.45, lens)
		_front(sd * (fw - 0.22), nose_h - 0.09, Vector3(0.32, 0.02, 0.035), drl)
		_front(sd * (fw - 0.16), 0.45, Vector3(0.26, 0.18, 0.03), black)
		var vz: float = wb * 0.5 - 0.55
		_box(Vector3(sd * (taper.call(vz, 0.85) + 0.006), g + 0.85, vz), Vector3(0.02, 0.06, 0.32), black)
		_box(Vector3(sd * (taper.call(vz, 0.85) + 0.012), g + 0.85, vz), Vector3(0.02, 0.012, 0.30), chrome)
		_swept_rear(sd, deck_h - 0.08, 0.36, 0.07, 0.40, tail)
		for k in range(2):
			_pipe(Vector3(sd * (0.48 + k * 0.12), g + 0.40, zr - 0.02), 0.045)
		_box(Vector3(sd * (hw - 0.01), g + 0.36, 0.0), Vector3(0.04, 0.10, wb - 0.9), black)
	_roof_cap(black)
	_front(0, 0.40, Vector3(fw * 1.2, 0.12, 0.04), black)
	_rear(0, 0.42, Vector3(_rw(0.4) * 1.9, 0.16, 0.05), black)
	_plates(0.58, deck_h - 0.32)

# Panel lying on the flat part of the roof (glass roof, vinyl top, two-tone paint)
func _roof_cap(mat: Material) -> void:
	var zc: float = (ws_top_z + roof_rear_z) * 0.5
	var w: float = taper.call(zc, float(s["belt"])) * float(s["tumble"]) * 2.0 - 0.08
	_box(Vector3(0, g + H + 0.004, zc), Vector3(w, 0.012, maxf(ws_top_z - roof_rear_z - 0.05, 0.2)), mat)
