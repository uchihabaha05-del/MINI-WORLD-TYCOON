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
	_build_traffic_lights()
	_detail_shop_entrance()
	_apply_visual_refresh()
	_build_market_plaza()
	_build_shop_interior_details()
	_build_road_markings_upgrade()

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

	# Open-roof walk-in market: a floor, solid side/rear walls and a clear front entrance.
	_box(shop, Vector3(17, 0.35, 12), Vector3(0, 0.0, 0), Color("#d9d4c8"), "ShopFloor")
	_box(shop, Vector3(17, 7, 0.45), Vector3(0, 3.5, -5.78), Color("#f1dfc4"), "ShopRearWall")
	_box(shop, Vector3(0.45, 7, 11.6), Vector3(-8.28, 3.5, 0), Color("#f1dfc4"), "ShopLeftWall")
	_box(shop, Vector3(0.45, 7, 11.6), Vector3(8.28, 3.5, 0), Color("#f1dfc4"), "ShopRightWall")
	_add_static_box_collision(shop, Vector3(17, 7, 0.45), Vector3(0, 3.5, -5.78), "ShopRearCollision")
	_add_static_box_collision(shop, Vector3(0.45, 7, 11.6), Vector3(-8.28, 3.5, 0), "ShopLeftCollision")
	_add_static_box_collision(shop, Vector3(0.45, 7, 11.6), Vector3(8.28, 3.5, 0), "ShopRightCollision")
	# Roof rim frames the interior while leaving it visible from the elevated game camera.
	_box(shop, Vector3(18, 0.55, 0.65), Vector3(0, 7.1, -6.1), Color("#b85f49"), "ShopRearRoofRim")
	_box(shop, Vector3(0.65, 0.55, 13), Vector3(-8.65, 7.1, 0), Color("#b85f49"), "ShopLeftRoofRim")
	_box(shop, Vector3(0.65, 0.55, 13), Vector3(8.65, 7.1, 0), Color("#b85f49"), "ShopRightRoofRim")
	_box(shop, Vector3(17.2, 1.15, 0.25), Vector3(0, 5.8, 6.12), Color("#e8a85e"), "ShopFacadeBand")
	# Front glazing is split into two broad windows and narrow corner panels; centre stays open.
	for x in [-6.2, 6.2]:
		_box(shop, Vector3(4.1, 3.7, 0.16), Vector3(x, 2.7, 6.16), WINDOW, "StoreWindow")
		_box(shop, Vector3(0.12, 3.9, 0.2), Vector3(x + (2.1 if x < 0 else -2.1), 2.7, 6.12), Color("#f7f0e3"), "WindowFrame")
	_box(shop, Vector3(2.0, 0.16, 0.35), Vector3(0, 0.12, 6.1), Color("#b8a68e"), "EntranceThreshold")
	_box(shop, Vector3(0.12, 3.7, 0.16), Vector3(-1.15, 2.7, 6.12), Color("#f7f0e3"), "DoorFrame")
	_box(shop, Vector3(0.12, 3.7, 0.16), Vector3(1.15, 2.7, 6.12), Color("#f7f0e3"), "DoorFrame")
	_box(shop, Vector3(2.1, 0.16, 0.16), Vector3(0, 4.55, 6.12), Color("#f7f0e3"), "DoorFrame")

	var building_sign := Label3D.new()
	building_sign.name = "ShopSign"
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
	_add_static_box_collision(building, size, Vector3(0, size.y * 0.5, 0), "BuildingCollision")
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
	_add_static_cylinder_collision(parent, 0.28, 1.8, pos + Vector3(0, 0.9, 0), "TreeTrunkCollision")

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

func _add_static_box_collision(parent: Node3D, size: Vector3, pos: Vector3, node_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = pos
	body.add_child(shape_node)
	parent.add_child(body)

func _add_static_cylinder_collision(parent: Node3D, radius: float, height: float, pos: Vector3, node_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	shape_node.shape = shape
	shape_node.position = pos
	body.add_child(shape_node)
	parent.add_child(body)

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


func _detail_shop_entrance() -> void:
	var shop := get_node_or_null("PlayerShop") as Node3D
	if shop == null:
		return
	_box(shop, Vector3(13.8, 0.28, 1.25), Vector3(0, 4.85, 6.75), Color("#d65f4d"), "ShopAwning")
	for i in range(7):
		_box(shop, Vector3(0.12, 0.3, 1.28), Vector3(-6.0 + float(i) * 2.0, 4.85, 6.77), Color("#f4dfb8"), "AwningStripe")
	_box(shop, Vector3(0.07, 0.72, 0.07), Vector3(0.82, 2.65, 6.32), Color("#d7bd79"), "EntranceHandle")
	for x in [-6.0, 6.0]:
		_box(shop, Vector3(2.2, 0.5, 0.65), Vector3(x, 0.42, 6.9), Color("#8a6848"), "WindowDisplayPlinth")
		_box(shop, Vector3(1.7, 0.42, 0.45), Vector3(x, 0.88, 6.9), Color("#d7a15b"), "WindowDisplay")

func _build_traffic_lights() -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var signal_root := Node3D.new()
			signal_root.name = "TrafficSignal"
			signal_root.position = Vector3(sx * 6.5, 0, sz * 6.5)
			add_child(signal_root)
			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.07
			pole_mesh.bottom_radius = 0.1
			pole_mesh.height = 4.2
			pole.mesh = pole_mesh
			pole.position.y = 2.1
			pole.material_override = _material(Color("#46535a"))
			signal_root.add_child(pole)
			_box(signal_root, Vector3(0.62, 1.65, 0.48), Vector3(-sx * 0.22, 3.65, -sz * 0.15), Color("#20282d"), "SignalHousing")
			for light_index in range(3):
				var lamp := MeshInstance3D.new()
				lamp.name = ["SignalRed", "SignalAmber", "SignalGreen"][light_index]
				var sphere := SphereMesh.new()
				sphere.radius = 0.19
				sphere.height = 0.38
				lamp.mesh = sphere
				lamp.position = Vector3(-sx * 0.22, 4.15 - float(light_index) * 0.5, -sz * 0.15 - 0.26)
				var signal_material := StandardMaterial3D.new()
				signal_material.albedo_color = [Color("#ef4942"), Color("#f0bd43"), Color("#45c878")][light_index]
				signal_material.emission_enabled = true
				signal_material.emission = signal_material.albedo_color
				signal_material.emission_energy_multiplier = 0.65
				lamp.material_override = signal_material
				signal_root.add_child(lamp)


# VISUAL RESTART — replace the prototype blockout feel with a coherent modern town.
func _apply_visual_refresh() -> void:
	for child in get_children():
		if not child is Node3D:
			continue
		if child.name == "PlayerShop" or child.name == "CentralPark" or child.name == "TrafficSignal":
			continue
		if child.name.begins_with("Apartments") or child.name.begins_with("NorthDistrict") or child.name.begins_with("SouthDistrict") or child.name in ["Bakery", "Cafe", "Office", "FlowerShop"]:
			_add_architectural_finish(child as Node3D)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null:
			continue
		if mesh_node.name in ["FrontGlass", "SideGlass", "StoreWindow", "EntranceDoor"]:
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color("#477b91")
			glass.metallic = 0.28
			glass.roughness = 0.2
			glass.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			glass.emission_enabled = true
			glass.emission = Color("#244858")
			glass.emission_energy_multiplier = 0.12
			mesh_node.material_override = glass
		elif mesh_node.name == "LampHead":
			var glow := StandardMaterial3D.new()
			glow.albedo_color = Color("#ffe4a3")
			glow.emission_enabled = true
			glow.emission = Color("#ffc96e")
			glow.emission_energy_multiplier = 0.8
			mesh_node.material_override = glow

func _add_architectural_finish(building: Node3D) -> void:
	var body := building.get_node_or_null("BuildingBody") as MeshInstance3D
	if body == null:
		return
	var size: Vector3 = (body.mesh as BoxMesh).size
	var accent := Color("#f1e9db")
	var dark := Color("#344b58")
	# Strong vertical facade piers and a continuous upper cornice.
	for x in [-size.x * 0.48, size.x * 0.48]:
		_box(building, Vector3(0.32, size.y, 0.32), Vector3(x, size.y * 0.5, size.z * 0.5 + 0.2), accent, "FacadePier")
	_box(building, Vector3(size.x + 0.8, 0.32, 0.48), Vector3(0, size.y - 0.18, size.z * 0.5 + 0.2), accent, "FacadeCornice")
	# Ground-floor storefront bays and signage make each block legible at street level.
	_box(building, Vector3(size.x * 0.62, 2.35, 0.18), Vector3(0, 1.35, size.z * 0.5 + 0.22), dark, "GroundFloorShopfront")
	_box(building, Vector3(size.x * 0.68, 0.48, 0.28), Vector3(0, 2.85, size.z * 0.5 + 0.28), Color("#d9a66d"), "StorefrontCanopy")
	# Rooftop plant equipment and vents break up the flat roof silhouette.
	for i in range(2):
		var rx := -size.x * 0.22 + float(i) * size.x * 0.44
		_box(building, Vector3(1.5, 0.65, 1.2), Vector3(rx, size.y + 0.82, -size.z * 0.18), Color("#78858b"), "RooftopHVAC")
		_box(building, Vector3(1.62, 0.12, 1.32), Vector3(rx, size.y + 1.2, -size.z * 0.18), Color("#c1c8c8"), "RooftopHVACCap")

func _build_market_plaza() -> void:
	var plaza := Node3D.new()
	plaza.name = "MarketPlaza"
	plaza.position = Vector3(-15, 0, -6.8)
	add_child(plaza)
	_box(plaza, Vector3(23, 0.16, 7.5), Vector3(0, 0.02, 0), Color("#c9c7bc"), "MarketStonePaving")
	for x in [-9.0, -6.0, 6.0, 9.0]:
		_box(plaza, Vector3(1.8, 0.42, 1.5), Vector3(x, 0.28, 1.8), Color("#8b684c"), "PlanterBox")
		var shrub := MeshInstance3D.new()
		var shrub_mesh := SphereMesh.new()
		shrub_mesh.radius = 0.62
		shrub_mesh.height = 0.9
		shrub.mesh = shrub_mesh
		shrub.position = Vector3(x, 0.92, 1.8)
		shrub.material_override = _material(Color("#4e8b59"))
		plaza.add_child(shrub)
	for x in [-3.8, 3.8]:
		_box(plaza, Vector3(2.6, 0.18, 0.55), Vector3(x, 0.42, 2.0), Color("#80583c"), "PlazaBench")
		_box(plaza, Vector3(2.6, 0.12, 0.12), Vector3(x, 0.78, 2.22), Color("#d1b28a"), "BenchBack")
	# A framed pedestrian entrance path leads directly to the market door.
	for x in [-1.4, 1.4]:
		_box(plaza, Vector3(0.12, 0.035, 5.6), Vector3(x, 0.12, -0.1), Color("#eee8d9"), "WalkwayEdge")

func _build_road_markings_upgrade() -> void:
	# Turn the broad road grid into clearly marked, modern streets.
	for axis in [-1.0, 1.0]:
		for z in [-30.0, 30.0, -66.0, 66.0]:
			for side in [-1.0, 1.0]:
				_box(self, Vector3(5.0, 0.035, 0.16), Vector3(axis * 10.0, 0.13, z + side * 2.0), Color("#e9e7dc"), "StopLine")
		for x in [-30.0, 30.0, -66.0, 66.0]:
			for side in [-1.0, 1.0]:
				_box(self, Vector3(0.16, 0.035, 5.0), Vector3(x + side * 2.0, 0.13, axis * 10.0), Color("#e9e7dc"), "StopLine")
	# Decorative lane arrows at the main intersection.
	for p in [Vector3(-3.2, 0.15, -12), Vector3(3.2, 0.15, 12)]:
		_box(self, Vector3(1.8, 0.035, 0.18), p, Color("#f5f2e8"), "LaneArrowStem")
		_box(self, Vector3(0.18, 0.035, 1.0), p + Vector3(0, 0, -0.42), Color("#f5f2e8"), "LaneArrowHead")


func _build_shop_interior_details() -> void:
	var shop := get_node_or_null("PlayerShop") as Node3D
	if shop == null:
		return
	# Wall-mounted lighting and a branded back-wall panel.
	_box(shop, Vector3(6.8, 1.1, 0.16), Vector3(0, 5.35, -5.48), Color("#315d70"), "InteriorBrandPanel")
	var interior_sign := Label3D.new()
	interior_sign.text = "FRESH • DAILY • LOCAL"
	interior_sign.font_size = 28
	interior_sign.pixel_size = 0.012
	interior_sign.position = Vector3(0, 5.35, -5.36)
	interior_sign.modulate = Color("#fff4dc")
	shop.add_child(interior_sign)
	for x in [-5.8, -2.0, 2.0, 5.8]:
		_box(shop, Vector3(0.16, 0.12, 1.0), Vector3(x, 6.25, -2.2), Color("#e9d6ad"), "InteriorCeilingLight")
	# Checkout counter faces the open entrance.
	_box(shop, Vector3(3.2, 1.15, 1.2), Vector3(0, 0.72, 4.25), Color("#79553b"), "CheckoutCounter")
	_box(shop, Vector3(3.0, 0.12, 1.1), Vector3(0, 1.35, 4.25), Color("#d8c4a4"), "CheckoutTop")
	_box(shop, Vector3(0.75, 0.1, 0.52), Vector3(0.8, 1.47, 4.25), Color("#263a42"), "CheckoutTerminal")
	_box(shop, Vector3(0.42, 0.08, 0.32), Vector3(-0.8, 1.47, 4.25), Color("#6ba9b8"), "CheckoutScanner")
	# Fridges and wall shelving along the rear wall.
	for x in [-6.0, 6.0]:
		_box(shop, Vector3(1.5, 3.7, 1.5), Vector3(x, 1.85, -4.35), Color("#5d7580"), "Refrigerator")
		_box(shop, Vector3(1.22, 3.3, 0.08), Vector3(x, 1.85, -3.56), Color("#a8d1d8"), "FridgeGlass")
		for y in [0.9, 1.8, 2.7]:
			_box(shop, Vector3(1.25, 0.08, 0.18), Vector3(x, y, -3.48), Color("#e5e1d5"), "FridgeShelf")
	# Ceiling-free design is intentional: the player and shelves remain readable from the gameplay camera.
