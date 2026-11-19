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
const WINDOW := Color("#344b58")

var _material_cache: Dictionary = {}

func _ready() -> void:
	_build_ground()
	_build_roads()
	_build_shop()
	_build_city_buildings()
	_build_park()
	_build_street_details()
	_build_roadside_furniture()
	_build_outer_districts()

func _build_ground() -> void:
	_box(self, Vector3(220, 0.5, 220), Vector3(0, -0.3, 0), GRASS, "CityGround")
	# Subtle green plots outside the central streets.
	for x in [-42.0, 42.0]:
		for z in [-42.0, 42.0]:
			_box(self, Vector3(22, 0.08, 22), Vector3(x, -0.01, z), GRASS_DARK, "GreenPlot")

func _build_roads() -> void:
	# Two main streets form a simple, readable city grid.
	_box(self, Vector3(220, 0.12, 9), Vector3(0, 0.02, 0), ROAD, "MainRoadEastWest")
	_box(self, Vector3(9, 0.13, 220), Vector3(0, 0.03, 0), ROAD, "MainRoadNorthSouth")

	# Secondary streets on the outer blocks.
	for z in [-30.0, 30.0]:
		_box(self, Vector3(220, 0.1, 6), Vector3(0, 0.015, z), ROAD, "SideRoad")
	for x in [-30.0, 30.0]:
		_box(self, Vector3(6, 0.1, 220), Vector3(x, 0.015, 0), ROAD, "SideRoad")

	# Continuous sidewalks and raised curbs beside the secondary streets.
	for z in [-30.0, 30.0]:
		for side in [-1.0, 1.0]:
			_box(self, Vector3(220, 0.16, 1.5), Vector3(0, 0.11, z + side * 3.75), SIDEWALK, "SideRoadSidewalk")
			_box(self, Vector3(220, 0.22, 0.18), Vector3(0, 0.17, z + side * 3.05), Color("#aaa99f"), "SideRoadCurb")
	for x in [-30.0, 30.0]:
		for side in [-1.0, 1.0]:
			_box(self, Vector3(1.5, 0.16, 220), Vector3(x + side * 3.75, 0.11, 0), SIDEWALK, "SideRoadSidewalk")
			_box(self, Vector3(0.18, 0.22, 220), Vector3(x + side * 3.05, 0.17, 0), Color("#aaa99f"), "SideRoadCurb")

	# Broken centre markings on the secondary roads.
	for i in range(-9, 10):
		var mark_pos := float(i) * 5.5
		for z in [-30.0, 30.0]:
			_box(self, Vector3(2.5, 0.025, 0.12), Vector3(mark_pos, 0.09, z), LINE, "SideRoadMarking")
		for x in [-30.0, 30.0]:
			_box(self, Vector3(0.12, 0.025, 2.5), Vector3(x, 0.09, mark_pos), LINE, "SideRoadMarking")

	# Zebra crossings at the four outer road junctions.
	for junction in [-30.0, 30.0]:
		for i in range(5):
			var stripe := -2.0 + float(i) * 1.0
			_box(self, Vector3(0.45, 0.03, 4.8), Vector3(stripe, 0.12, junction + 4.0), Color.WHITE, "SideCrosswalk")
			_box(self, Vector3(4.8, 0.03, 0.45), Vector3(junction + 4.0, 0.12, stripe), Color.WHITE, "SideCrosswalk")

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

	var building_sign := Label3D.new()
	building_building_sign.name = "ShopSign"
	building_sign.text = "MINI MARKET"
	building_sign.font_size = 64
	building_sign.pixel_size = 0.012
	building_sign.position = Vector3(0, 6.25, 6.35)
	building_sign.modulate = Color("#fff7df")
	shop.add_child(building_sign)

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

	# Main volume, roof cap and subtle facade bands.
	_box(building, size, Vector3(0, size.y * 0.5, 0), wall_color, "BuildingBody")
	_box(building, Vector3(size.x + 0.9, 0.55, size.z + 0.9), Vector3(0, size.y + 0.28, 0), roof_color, "FlatRoof")
	_box(building, Vector3(size.x + 0.35, 0.28, 0.24), Vector3(0, 0.35, size.z * 0.5 + 0.12), Color("#f4eee3"), "FrontBaseTrim")
	_box(building, Vector3(size.x + 0.35, 0.24, 0.24), Vector3(0, size.y - 0.55, size.z * 0.5 + 0.12), Color("#f4eee3"), "FrontTopTrim")

	var floors := maxi(1, int(size.y / 3.2))
	for floor_index in range(floors):
		var y := 1.8 + float(floor_index) * 3.0
		for x_index in range(3):
			var x := -size.x * 0.3 + float(x_index) * size.x * 0.3
			_box(building, Vector3(2.0, 1.55, 0.16), Vector3(x, y, size.z * 0.5 + 0.09), Color("#344b58"), "FrontGlass")
			_box(building, Vector3(2.12, 0.12, 0.2), Vector3(x, y - 0.84, size.z * 0.5 + 0.1), Color("#f3eadc"), "WindowSill")
			_box(building, Vector3(0.12, 1.72, 0.2), Vector3(x - 1.08, y, size.z * 0.5 + 0.1), Color("#f3eadc"), "WindowFrame")
			_box(building, Vector3(0.12, 1.72, 0.2), Vector3(x + 1.08, y, size.z * 0.5 + 0.1), Color("#f3eadc"), "WindowFrame")

			# Balconies make apartment blocks read differently from offices.
			if building_name.begins_with("Apartments"):
				_box(building, Vector3(2.45, 0.16, 1.0), Vector3(x, y - 0.92, size.z * 0.5 + 0.55), Color("#b9c4c7"), "BalconyFloor")
				_box(building, Vector3(2.45, 0.12, 0.1), Vector3(x, y - 0.25, size.z * 0.5 + 1.0), Color("#e8ece9"), "BalconyRail")
				for rail_x in [-1.0, -0.5, 0.0, 0.5, 1.0]:
					_box(building, Vector3(0.055, 0.62, 0.055), Vector3(x + rail_x, y - 0.58, size.z * 0.5 + 1.0), Color("#e8ece9"), "BalconyBar")

		# Recessed-looking side windows add depth to the street-facing side.
		for side_index in range(2):
			var side_z := -size.z * 0.22 + float(side_index) * size.z * 0.44
			_box(building, Vector3(0.14, 1.45, 1.8), Vector3(size.x * 0.5 + 0.08, y, side_z), Color("#344b58"), "SideGlass")
			_box(building, Vector3(0.18, 1.62, 0.12), Vector3(size.x * 0.5 + 0.1, y, side_z - 0.96), Color("#f3eadc"), "SideWindowFrame")
			_box(building, Vector3(0.18, 1.62, 0.12), Vector3(size.x * 0.5 + 0.1, y, side_z + 0.96), Color("#f3eadc"), "SideWindowFrame")

	# Roof parapet and small ventilation units.
	for edge in [-1.0, 1.0]:
		_box(building, Vector3(size.x + 0.2, 0.45, 0.22), Vector3(0, size.y + 0.72, edge * size.z * 0.5), Color("#e8e4dc"), "RoofParapet")
		_box(building, Vector3(0.22, 0.45, size.z), Vector3(edge * size.x * 0.5, size.y + 0.72, 0), Color("#e8e4dc"), "RoofParapet")
	_box(building, Vector3(2.0, 0.75, 1.5), Vector3(-size.x * 0.25, size.y + 0.95, -size.z * 0.18), Color("#aeb8bc"), "RoofVent")
	_box(building, Vector3(1.4, 0.55, 1.2), Vector3(size.x * 0.22, size.y + 0.85, -size.z * 0.18), Color("#aeb8bc"), "RoofVent")

	# A simple entrance gives each building a readable ground-floor frontage.
	_box(building, Vector3(1.8, 2.5, 0.2), Vector3(0, 1.25, size.z * 0.5 + 0.13), Color("#344b58"), "EntranceDoor")
	_box(building, Vector3(2.6, 0.22, 1.0), Vector3(0, 2.65, size.z * 0.5 + 0.55), roof_color, "EntranceAwning")

	var label := Label3D.new()
	label.name = "BuildingSign"
	label.text = building_name.replace("_", " ").to_upper()
	label.font_size = 30
	label.pixel_size = 0.009
	label.position = Vector3(0, size.y + 1.35, size.z * 0.5 + 0.3)
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


func _build_roadside_furniture() -> void:
	# Waste bins near pedestrian corners.
	for pos in [
		Vector3(-8.0, 0, -8.0), Vector3(8.0, 0, 8.0),
		Vector3(-8.0, 0, 8.0), Vector3(8.0, 0, -8.0),
		Vector3(-26.0, 0, -26.0), Vector3(26.0, 0, 26.0)
	]:
		_trash_bin(self, pos)

	# Short protective bollards around selected sidewalk corners.
	for x in [-8.0, 8.0]:
		for z in [-8.0, 8.0]:
			_bollard(self, Vector3(x, 0, z))

	# Street-name signs at the central junction.
	_street_sign(self, Vector3(-7.2, 0, -7.2), "MAIN ST")
	_street_sign(self, Vector3(7.2, 0, 7.2), "MARKET ST")

	# A few extra trees soften the edges of the outer blocks.
	for x in [-42.0, 42.0]:
		for z in [-23.0, 23.0]:
			_tree(self, Vector3(x, 0, z))

func _trash_bin(parent: Node3D, pos: Vector3) -> void:
	_box(parent, Vector3(0.72, 0.95, 0.68), pos + Vector3(0, 0.48, 0), Color("#4d6870"), "StreetTrashBin")
	_box(parent, Vector3(0.82, 0.12, 0.76), pos + Vector3(0, 1.0, 0), Color("#34474d"), "TrashBinLid")
	_box(parent, Vector3(0.38, 0.08, 0.04), pos + Vector3(0, 0.68, 0.36), Color("#d8e2dc"), "TrashBinSlot")

func _bollard(parent: Node3D, pos: Vector3) -> void:
	var post := MeshInstance3D.new()
	post.name = "SidewalkBollard"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.16
	mesh.height = 0.8
	post.mesh = mesh
	post.position = pos + Vector3(0, 0.4, 0)
	post.material_override = _material(Color("#d7d0bd"))
	parent.add_child(post)

func _street_sign(parent: Node3D, pos: Vector3, sign_text: String) -> void:
	var pole := MeshInstance3D.new()
	pole.name = "StreetSignPole"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.06
	mesh.height = 2.5
	pole.mesh = mesh
	pole.position = pos + Vector3(0, 1.25, 0)
	pole.material_override = _material(Color("#53616a"))
	parent.add_child(pole)
	_box(parent, Vector3(2.2, 0.62, 0.12), pos + Vector3(0, 2.35, 0), Color("#386d59"), "StreetNamePlate")
	var label := Label3D.new()
	label.text = sign_text
	label.font_size = 24
	label.pixel_size = 0.008
	label.position = pos + Vector3(0, 2.35, 0.09)
	label.modulate = Color.WHITE
	parent.add_child(label)

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
	var key := color.to_html()
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	_material_cache[key] = material
	return material

func _build_outer_districts() -> void:
	# Two additional ring roads open the map into a larger four-district city.
	for axis in [-1.0, 1.0]:
		var road_offset: float = float(axis) * 66.0
		_box(self, Vector3(220, 0.14, 7), Vector3(0, 0.025, road_offset), ROAD, "OuterDistrictRoad")
		_box(self, Vector3(7, 0.14, 220), Vector3(road_offset, 0.025, 0), ROAD, "OuterDistrictRoad")
		for side in [-1.0, 1.0]:
			_box(self, Vector3(220, 0.15, 1.4), Vector3(0, 0.12, road_offset + side * 4.2), SIDEWALK, "OuterDistrictSidewalk")
			_box(self, Vector3(1.4, 0.15, 220), Vector3(road_offset + side * 4.2, 0.12, 0), SIDEWALK, "OuterDistrictSidewalk")
	for i in range(4):
		var x := -88.0 + float(i) * 58.0
		_build_building(Vector3(x, 0, -88), Vector3(18, 13, 15), WALLS[i % WALLS.size()], "NorthDistrict_%d" % i, Color("#8199aa"))
		_build_building(Vector3(x, 0, 88), Vector3(18, 16, 15), WALLS[(i + 2) % WALLS.size()], "SouthDistrict_%d" % i, Color("#b58b68"))
	for i in range(4):
		var z := -48.0 + float(i) * 32.0
		_tree(self, Vector3(-96, 0, z))
		_tree(self, Vector3(96, 0, z))
		_lamp(self, Vector3(-70, 0, z))
		_lamp(self, Vector3(70, 0, z))
	# Small landscaped squares make the new districts visually distinct.
	for center in [Vector3(-78, 0, 0), Vector3(78, 0, 0), Vector3(0, 0, -78), Vector3(0, 0, 78)]:
		_box(self, Vector3(13, 0.12, 13), center, GRASS_DARK, "DistrictGreen")
		_tree(self, center + Vector3(-4, 0, -4))
		_tree(self, center + Vector3(4, 0, 4))
