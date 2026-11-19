extends Node3D

# MINI WORLD TYCOON — Milestone 1: stylized shop blockout.
# All geometry is procedural so the prototype stays lightweight on Android.

const PRODUCT_COLORS: Array[Color] = [
	Color("#ef6c63"), Color("#f2c14e"), Color("#62b6cb"),
	Color("#8acb88"), Color("#b18bd1"), Color("#f09c5a")
]

func _ready() -> void:
	_build_shop()
	_setup_camera()

func _build_shop() -> void:
	var shop := Node3D.new()
	shop.name = "ShopInterior"
	add_child(shop)

	var wall := Color("#f2e8d5")
	var trim := Color("#d5a45f")
	var wood := Color("#b87945")
	var dark := Color("#34495e")
	var glass := Color(0.55, 0.82, 0.94, 0.32)

	# Warm perimeter walls; front remains open so the interior is easy to see.
	_box(shop, Vector3(18.0, 5.2, 0.28), Vector3(0, 2.6, -6.85), wall, "BackWall")
	_box(shop, Vector3(0.28, 5.2, 13.7), Vector3(-8.85, 2.6, 0), wall, "LeftWall")
	_box(shop, Vector3(0.28, 5.2, 13.7), Vector3(8.85, 2.6, 0), wall, "RightWall")
	_box(shop, Vector3(6.7, 5.2, 0.28), Vector3(-5.55, 2.6, 6.85), wall, "FrontLeft")
	_box(shop, Vector3(6.7, 5.2, 0.28), Vector3(5.55, 2.6, 6.85), wall, "FrontRight")
	_box(shop, Vector3(4.4, 0.35, 0.25), Vector3(0, 4.65, 6.85), trim, "EntranceHeader")
	_box(shop, Vector3(0.16, 4.2, 0.12), Vector3(-2.15, 2.2, 6.68), glass, "GlassDoorLeft")
	_box(shop, Vector3(0.16, 4.2, 0.12), Vector3(2.15, 2.2, 6.68), glass, "GlassDoorRight")

	# Decorative wall trim and shop sign.
	_box(shop, Vector3(10.0, 0.22, 0.18), Vector3(0, 4.9, -6.64), trim, "BackTrim")
	var sign := Label3D.new()
	sign.name = "ShopSign"
	sign.text = "MINI  MARKET"
	sign.font_size = 72
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 4.05, -6.58)
	sign.modulate = Color("#fff4d6")
	shop.add_child(sign)

	# Three double-sided gondola shelving units.
	_make_shelf(shop, Vector3(-5.7, 0, -1.0), wood, trim, 1)
	_make_shelf(shop, Vector3(-1.9, 0, -1.0), wood, trim, 2)
	_make_shelf(shop, Vector3(1.9, 0, -1.0), wood, trim, 3)

	# Wall display shelf at the back.
	_make_wall_shelf(shop, Vector3(5.9, 0, -4.8), wood, trim)

	# Checkout counter near the entrance, leaving a clear central aisle.
	_box(shop, Vector3(2.8, 1.05, 1.25), Vector3(5.65, 0.55, 3.65), Color("#d99b5b"), "CheckoutCounter")
	_box(shop, Vector3(2.85, 0.12, 1.3), Vector3(5.65, 1.12, 3.65), Color("#f5d7a1"), "CounterTop")
	_box(shop, Vector3(0.72, 0.22, 0.48), Vector3(5.55, 1.29, 3.55), dark, "RegisterBase")
	_box(shop, Vector3(0.62, 0.38, 0.12), Vector3(5.55, 1.55, 3.35), Color("#83c9bd"), "RegisterScreen")
	_box(shop, Vector3(0.65, 0.035, 0.42), Vector3(5.55, 1.28, 4.05), Color("#273746"), "Scanner")

	# Small promotional display beside the entrance.
	_box(shop, Vector3(1.2, 0.9, 0.9), Vector3(-6.1, 0.45, 4.3), Color("#f2c14e"), "PromoTable")
	_box(shop, Vector3(1.25, 0.12, 0.95), Vector3(-6.1, 0.94, 4.3), Color("#fff0bd"), "PromoTop")
	for i in range(4):
		_box(shop, Vector3(0.22, 0.32, 0.22), Vector3(-6.48 + i * 0.25, 1.16, 4.3), PRODUCT_COLORS[i], "PromoProduct")

	# Ceiling lights.
	for x in [-5.5, -1.8, 1.8, 5.5]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 4.55, -0.5)
		lamp.light_color = Color("#fff0cf")
		lamp.light_energy = 0.65
		lamp.omni_range = 7.0
		shop.add_child(lamp)
		_box(shop, Vector3(1.25, 0.08, 0.42), Vector3(x, 5.0, -0.5), Color("#fff8e7"), "CeilingLamp")

func _make_shelf(parent: Node3D, origin: Vector3, wood: Color, trim: Color, seed: int) -> void:
	var rack := Node3D.new()
	rack.name = "GondolaShelf_%d" % seed
	rack.position = origin
	parent.add_child(rack)
	for x in [-0.58, 0.58]:
		for z in [-2.0, 2.0]:
			_box(rack, Vector3(0.12, 2.85, 0.12), Vector3(x, 1.45, z), trim, "Upright")
	for level in range(3):
		var y := 0.55 + float(level) * 0.88
		_box(rack, Vector3(1.28, 0.13, 4.35), Vector3(0, y, 0), wood, "ShelfBoard")
		_box(rack, Vector3(1.3, 0.08, 0.08), Vector3(0, y + 0.11, 2.13), trim, "ShelfLip")
		for item in range(7):
			var z := -1.75 + float(item) * 0.55
			var color_index := (item + level * 2 + seed) % PRODUCT_COLORS.size()
			var h := 0.34 + float((item + seed) % 3) * 0.08
			_box(rack, Vector3(0.34, h, 0.34), Vector3(0, y + 0.12 + h * 0.5, z), PRODUCT_COLORS[color_index], "Product")
	_box(rack, Vector3(1.42, 0.18, 4.55), Vector3(0, 2.95, 0), trim, "TopCap")

func _make_wall_shelf(parent: Node3D, origin: Vector3, wood: Color, trim: Color) -> void:
	var rack := Node3D.new()
	rack.name = "WallShelf"
	rack.position = origin
	parent.add_child(rack)
	for level in range(3):
		var y := 0.75 + float(level) * 1.0
		_box(rack, Vector3(0.9, 0.12, 3.0), Vector3(0, y, 0), wood, "WallShelfBoard")
		for item in range(5):
			var z := -1.15 + float(item) * 0.57
			_box(rack, Vector3(0.38, 0.48, 0.38), Vector3(-0.05, y + 0.3, z), PRODUCT_COLORS[(item + level) % PRODUCT_COLORS.size()], "WallProduct")

func _box(parent: Node3D, box_size: Vector3, pos: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = box_size
	instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = material
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance

func _setup_camera() -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera:
		camera.position = Vector3(0, 10.5, 17.5)
		camera.look_at(Vector3(0, 1.4, 0), Vector3.UP)
		camera.fov = 58.0
