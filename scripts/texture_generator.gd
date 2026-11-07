@tool
extends SceneTree

func _init() -> void:
	print("--- GENERATING ULTRA-REALISTIC HIGH-RES TEXTURES ---")
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("textures"):
		dir.make_dir("textures")

	_generate_asphalt()
	_generate_natural_grass()
	_generate_curbs()
	_generate_concrete()
	_generate_road_lines()
	_generate_dirt()
	print("--- ALL TEXTURES GENERATED SUCCESSFULLY ---")
	quit()

func _generate_asphalt() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.08
	noise.fractal_octaves = 4

	var fine_noise := FastNoiseLite.new()
	fine_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	fine_noise.frequency = 0.25

	# Seamless noise: the texture tiles with no visible seams on the road
	var n_img := noise.get_seamless_image(1024, 1024)
	var s_img := fine_noise.get_seamless_image(1024, 1024)
	var img := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	for y in range(1024):
		for x in range(1024):
			var n := 0.2 + n_img.get_pixel(x, y).r * 0.6
			var stone := 0.2 + s_img.get_pixel(x, y).r * 0.6
			var grain := (randf() - 0.5) * 0.05
			# Realistic dark anthracite tarmac with stone aggregates
			var base := clampf(0.16 + n * 0.06 + stone * 0.04 + grain, 0.12, 0.26)
			# Slight cool mineral tint
			img.set_pixel(x, y, Color(base * 0.98, base, base * 1.02, 1.0))
	img.save_png("res://textures/asphalt_albedo.png")
	print("Saved 1024x1024 asphalt_albedo.png")

func _generate_natural_grass() -> void:
	var macro_noise := FastNoiseLite.new()
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	macro_noise.frequency = 0.015
	macro_noise.fractal_octaves = 4

	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.frequency = 0.08
	detail_noise.fractal_octaves = 3

	var m_img := macro_noise.get_seamless_image(1024, 1024)
	var d_img := detail_noise.get_seamless_image(1024, 1024)
	var img := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	for y in range(1024):
		for x in range(1024):
			var m := 0.2 + m_img.get_pixel(x, y).r * 0.6
			var d := 0.2 + d_img.get_pixel(x, y).r * 0.6
			var blade := (randf() - 0.5) * 0.04

			# NATURAL COUNTRYSIDE MEADOW (Subdued olive, earthy moss, warm muted undertones)
			# Never bright, never radioactive lime green!
			var green := clampf(0.22 + m * 0.10 + d * 0.06 + blade, 0.16, 0.35)
			var red := green * 0.76  # Earthy soil undertone
			var blue := green * 0.42 # Desaturated natural field foliage
			img.set_pixel(x, y, Color(red, green, blue, 1.0))
	img.save_png("res://textures/grass_albedo.png")
	print("Saved 1024x1024 natural grass_albedo.png")

func _generate_curbs() -> void:
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	for y in range(512):
		for x in range(512):
			# Diagonal racing stripes
			var stripe := int((x + y) / 64) % 2 # 512 px = 4 full periods -> tiles seamlessly
			var col: Color
			if stripe == 0:
				# FIA Racing Red
				col = Color(0.80, 0.12, 0.12, 1.0)
			else:
				# Curb White with slight warm grey tint
				col = Color(0.92, 0.92, 0.90, 1.0)
			# Subtle texture wear on kerb
			var wear := (randf() - 0.5) * 0.05
			img.set_pixel(x, y, Color(clampf(col.r + wear, 0, 1), clampf(col.g + wear, 0, 1), clampf(col.b + wear, 0, 1), 1.0))
	img.save_png("res://textures/curb_striped.png")
	print("Saved 512x512 curb_striped.png")

func _generate_concrete() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.03

	var n_img := noise.get_seamless_image(1024, 1024)
	var img := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	for y in range(1024):
		for x in range(1024):
			var n := 0.2 + n_img.get_pixel(x, y).r * 0.6
			var val := clampf(0.50 + n * 0.12 + (randf() - 0.5) * 0.03, 0.38, 0.65)
			# Wall panel construction joints every 256px
			if x % 256 < 3 or y % 512 < 3:
				val *= 0.68
			img.set_pixel(x, y, Color(val, val * 0.98, val * 0.96, 1.0))
	img.save_png("res://textures/concrete_wall.png")
	print("Saved 1024x1024 concrete_wall.png")

func _generate_road_lines() -> void:
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	for y in range(512):
		for x in range(512):
			var asphalt_dark := 0.18 + (randf() - 0.5) * 0.03
			var col := Color(asphalt_dark, asphalt_dark * 1.01, asphalt_dark * 1.02, 1.0)
			# Yellow double center divider (lanes 2 & 3)
			if (x >= 248 and x <= 252) or (x >= 260 and x <= 264):
				col = Color(0.95, 0.78, 0.08, 1.0)
			# Solid white outer boundary lines
			if (x >= 20 and x <= 28) or (x >= 484 and x <= 492):
				col = Color(0.92, 0.93, 0.95, 1.0)
			# Dashed white lane dividers (lanes 1-2 and 3-4)
			var is_dash := (y % 64) < 36
			if is_dash:
				if (x >= 134 and x <= 140) or (x >= 372 and x <= 378):
					col = Color(0.90, 0.91, 0.93, 1.0)
			img.set_pixel(x, y, col)
	img.save_png("res://textures/road_asphalt.png")
	print("Saved 512x512 road_asphalt.png")

func _generate_dirt() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.04
	noise.fractal_octaves = 4

	var n_img := noise.get_seamless_image(1024, 1024)
	var img := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	for y in range(1024):
		for x in range(1024):
			var n := 0.2 + n_img.get_pixel(x, y).r * 0.6
			var brown := clampf(0.36 + n * 0.18 + (randf() - 0.5) * 0.04, 0.24, 0.55)
			img.set_pixel(x, y, Color(brown, brown * 0.78, brown * 0.54, 1.0))
	img.save_png("res://textures/dirt_albedo.png")
	print("Saved 1024x1024 dirt_albedo.png")
