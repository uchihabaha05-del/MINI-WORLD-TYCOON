extends Node3D

# MINI WORLD TYCOON — Milestone 1: first explorable city blockout.
# Lightweight procedural meshes keep the scene suitable for Android.

const GRASS := Color("#78ad68")
const GRASS_DARK := Color("#65965b")
const ROAD := Color("#343b43")
const SIDEWALK := Color("#c8c5b9")
const LINE := Color("#f5e7a4")
const WALLS: Array[Color] = [
	Color("#f0c9a5"), Color("#d6e0e7"), Color("#e8dcae"),
	Color("#c9d9c0"), Color("#d9c8e8"), Color("#e8bdb8")
]
const WINDOW := Color("#8fc7d9")

func _ready() -> void:
	_build_ground()
	_build_roads()
	_build_shop()
	_build_city_buildings()
	_build_park()
	_build_street_details()

func _build_ground() -> void:
	_box(self, Vector3(110, 0.5, 110), Vector3(0, -0.3, 0), GRASS, "CityGround")
	# Subtle green plots outside the central streets.
	for x in [-42.0, 42.0]:
		for z in [-42.0, 42.0]:
			_box(self, Vector3(22, 0.08, 22), Vector3(x, -0.01, z), GRASS_DARK, "GreenPlot")

func _build_roads() -> void:
	# Two main streets form a simple, readable city grid.
	_box(self, Vector3(110, 0.12, 9), Vector3(0, 0.02, 0), ROAD, "MainRoadEastWest")
	_box(self, Vector3(9, 0.13, 110), Vector3(0, 0.03, 0), ROAD, "MainRoadNorthSouth")

	# Secondary streets on the outer blocks.
	for z in [-30.0, 30.0]:
		_box(self, Vector3(110, 0.1, 6), Vector3(0, 0.015, z), ROAD, "SideRoad")
	for x in [-30.0, 30.0]:
		_box(self, Vector3(6, 0.1, 110), Vector3(x, 0.015, 0), ROAD, "SideRoad")

	# Sidewalk strips beside the main streets.
	for side in [-1.0, 1.0]:
		_box(self, Vector3(110, 0.18, 2.0), Vector3(0, 0.12, side * 5.7), SIDEWALK, "MainSidewalk")
		_box(self, Vector3(2.0, 0.18, 110), Vector3(side * 5.7, 0.12, 0), SIDEWALK, "MainSidewalk")

	# Dashed centre lines.
	for i in range(-9, 10):
		var p := float(i) * 5.5
		_box(self, Vector3(2.8, 0.025, 0.16), Vector3(p, 0.105, 0), LINE, "RoadMarking")
		_box(self, Vector3(0.16, 0.025, 2.8), Vector3(0, 0.11, p), LINE, "RoadMarking")

	# Crosswalk stripes at the central intersection.
	for i in range(5):
		var offset := -2.0 + float(i) * 1.0
		_box(self, Vector3(0.55, 0.035, 5.5), Vector3(offset, 0.12, 7.2), Color.WHITE, "Crosswalk")
		_box(self, Vector3(5.5, 0.035, 0.55), Vector3(7.2, 0.12, offset), Color.WHITE, "Crosswalk")

func _build_shop() -> void:
	var shop := Node3D.new()
	shop.name = "PlayerShop"
	shop.position = Vector3(-15, 0, -15)
	add_child(shop)

	# Main shop body and contrasting roof.
	_box(shop, Vector3(17, 7, 12), Vector3(0, 3.5, 0), Color("#f1dfc4"), "ShopBuilding")
	_box(shop, Vector3(18, 0.65, 13), Vector3(0, 7.25, 0), Color("#b85f49"), "ShopRoof")
	_box(shop, Vector3(17.2, 1.15, 0.25), Vector3(0, 5.8, 6.12), Color("#e8a85e"), "ShopFacadeBand")

	# Glass storefront facing the main road.
	for x in [-5.5, -2.0, 2.0, 5.5]:
		_box(shop, Vector3(2.8, 3.7, 0.16), Vector3(x, 2.7, 6.16), WINDOW, "StoreWindow")
		_box(shop, Vector3(0.12, 3.9, 0.2), Vector3(x + 1.48, 2.7, 6.12), Color("#f7f0e3"), "WindowFrame")
	_box(shop, Vector3(2.2, 4.0, 0.22), Vector3(0, 2.7, 6.18), Color("#79b7c9"), "EntranceDoor")

	var sign := Label3D.new()
	sign.name = "ShopSign"
	sign.text = "MINI MARKET"
	sign.font_size = 64
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 6.25, 6.35)
	sign.modulate = Color("#fff7df")
	shop.add_child(sign)

	# Loading bay and delivery crates.
	_box(shop, Vector3(5.0, 2.4, 0.25), Vector3(-5.8, 1.2, -6.15), Color("#b5a18b"), "LoadingDoor")
	for i in range(3):
		_box(shop, Vector3(1.0, 0.9, 1.0), Vector3(6.0 + float(i) * 1.2, 0.45, -4.2), Color("#b87945"), "DeliveryCrate")

func _build_city_buildings() -> void:
	_build_building(Vector3(17, 0, -16), Vector3(14, 10, 13), WALLS[1], "Bakery", Color("#d18a55"))
	_build_building(Vector3(17, 0, 16), Vector3(13, 14, 13), WALLS[2], "Apartments_A", Color("#b7a0d4"))
	_build_building(Vector3(-17, 0, 17), Vector3(14, 9, 13), WALLS[3], "Cafe", Color("#c57b55"))
	_build_building(Vector3(43, 0, -15), Vector3(16, 17, 14), WALLS[4], "Apartments_B", Color("#8ca9c4"))
	_build_building(Vector3(-43, 0, 15), Vector3(16, 12, 14), WALLS[0], "Office", Color("#6c9e9a"))
	_build_building(Vector3(43, 0, 16), Vector3(15, 8, 13), WALLS[5], "FlowerShop", Color("#bd7892"))

func _build_building(origin: Vector3, size: Vector3, wall_color: Color, building_name: String, roof_color: Color) -> void:
	var building := Node3D.new()
	building.name = building_name
	building.position = origin
	add_child(building)

	_box(building, size, Vector3(0, size.y * 0.5, 0), wall_color, "BuildingBody")
	_box(building, Vector3(size.x + 0.7, 0.55, size.z + 0.7), Vector3(0, size.y + 0.28, 0), roof_color, "FlatRoof")

	var floors := maxi(1, int(size.y / 3.2))
	for floor_index in range(floors):
		var y := 1.8 + float(floor_index) * 3.0
		for x_index in range(3):
			var x := -size.x * 0.3 + float(x_index) * size.x * 0.3
			_box(building, Vector3(1.65, 1.35, 0.12), Vector3(x, y, size.z * 0.5 + 0.07), WINDOW, "FrontWindow")
			_box(building, Vector3(0.12, 1.5, 0.16), Vector3(x + 0.88, y, size.z * 0.5 + 0.08), Color("#f5eadb"), "WindowFrame")

	var label := Label3D.new()
	label.text = building_name.replace("_", " ")
	label.font_size = 30
	label.pixel_size = 0.009
	label.position = Vector3(0, size.y + 1.1, size.z * 0.5 + 0.3)
	label.modulate = Color("#ffffff")
	building.add_child(label)

func _build_park() -> void:
	var park := Node3D.new()
	park.name = "CentralPark"
	park.position = Vector3(16, 0, 43)
	add_child(park)

	_box(park, Vector3(28, 0.12, 19), Vector3.ZERO, Color("#86bd70"), "ParkGrass")
	_box(park, Vector3(24, 0.08, 2.2), Vector3(0, 0.1, 0), SIDEWALK, "ParkPath")
	_box(park, Vector3(2.2, 0.08, 15), Vector3(0, 0.11, 0), SIDEWALK, "ParkPath")
	for x in [-10.0, -4.0, 4.0, 10.0]:
		_tree(park, Vector3(x, 0, -6))
		_tree(park, Vector3(x, 0, 6))
	_box(park, Vector3(2.0, 0.55, 0.65), Vector3(-5, 0.35, 0), Color("#a8794f"), "ParkBench")
	_box(park, Vector3(2.0, 0.55, 0.65), Vector3(6, 0.35, 0), Color("#a8794f"), "ParkBench")

func _build_street_details() -> void:
	for x in [-24.0, 24.0]:
		for z in [-24.0, 24.0]:
			_tree(self, Vector3(x, 0, z))
	for x in [-10.0, 10.0]:
		_lamp(self, Vector3(x, 0, 7.0))
		_lamp(self, Vector3(x, 0, -7.0))
	for z in [-10.0, 10.0]:
		_lamp(self, Vector3(7.0, 0, z))
		_lamp(self, Vector3(-7.0, 0, z))

func _tree(parent: Node3D, pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	trunk.name = "TreeTrunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 1.8
	trunk.mesh = trunk_mesh
	trunk.position = pos + Vector3(0, 0.9, 0)
	trunk.material_override = _material(Color("#805638"))
	parent.add_child(trunk)

	var crown := MeshInstance3D.new()
	crown.name = "TreeCrown"
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.15
	crown_mesh.height = 2.2
	crown.mesh = crown_mesh
	crown.position = pos + Vector3(0, 2.5, 0)
	crown.material_override = _material(Color("#4e8e53"))
	parent.add_child(crown)

func _lamp(parent: Node3D, pos: Vector3) -> void:
	var pole := MeshInstance3D.new()
	pole.name = "StreetLampPole"
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 4.2
	pole.mesh = pole_mesh
	pole.position = pos + Vector3(0, 2.1, 0)
	pole.material_override = _material(Color("#424b55"))
	parent.add_child(pole)
	_box(parent, Vector3(0.8, 0.16, 0.35), pos + Vector3(0, 4.2, 0), Color("#fff0bd"), "LampHead")

func _box(parent: Node3D, box_size: Vector3, pos: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
