extends Node3D

# MINI WORLD TYCOON — Milestone 12: lightweight road traffic.
const TRAFFIC_COUNT := 10
const ROAD_LIMIT := 100.0
const DRIVE_TIME := 34.0

var traffic_label: Label
var vehicles: Array[Node3D] = []

func _ready() -> void:
	_create_hud()
	_spawn_traffic()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrafficHUD"
	layer.layer = 3
	add_child(layer)
	traffic_label = Label.new()
	traffic_label.text = "Транспорт на дорогах: %d" % TRAFFIC_COUNT
	traffic_label.position = Vector2(18, 220)
	traffic_label.add_theme_font_size_override("font_size", 17)
	layer.add_child(traffic_label)

func _spawn_traffic() -> void:
	for i in range(TRAFFIC_COUNT):
		var is_vertical := i >= 4
		var lane := -1.35 if i % 2 == 0 else 1.35
		var vehicle := _make_vehicle(i)
		if i >= 6:
			var outer_lane := -1.35 if i % 2 == 0 else 1.35
			var outer_axis := 66.0 if i % 2 == 0 else -66.0
			if i % 2 == 0:
				vehicle.position = Vector3(-ROAD_LIMIT + float(i - 6) * 18.0, 0.0, outer_axis + outer_lane)
			else:
				vehicle.position = Vector3(outer_axis + outer_lane, 0.0, -ROAD_LIMIT + float(i - 6) * 18.0)
			vehicle.rotation_degrees.y = 90.0 if i % 2 == 0 else 0.0
		elif is_vertical:
			vehicle.position = Vector3(lane, 0.0, -ROAD_LIMIT + float(i - 4) * 17.0)
			vehicle.rotation_degrees.y = 90.0 if i % 2 == 0 else -90.0
		else:
			var road_z := -30.0 if i % 2 == 0 else 30.0
			vehicle.position = Vector3(-ROAD_LIMIT + float(i) * 19.0, 0.0, road_z + lane)
			vehicle.rotation_degrees.y = 90.0 if i % 2 == 0 else -90.0
		add_child(vehicle)
		vehicles.append(vehicle)
		_drive_vehicle(vehicle, is_vertical, i % 2 == 0)

func _make_vehicle(index: int) -> Node3D:
	var vehicle := Node3D.new()
	vehicle.name = "CityVehicle_%d" % (index + 1)
	var colors: Array[Color] = [
		Color("#d94f45"), Color("#e3c34f"), Color("#4e8dbb"),
		Color("#e6e8e8"), Color("#4d5964"), Color("#4d9b72")
	]
	_box(vehicle, Vector3(3.2, 0.85, 1.55), Vector3(0, 0.72, 0), colors[index], "VehicleBody")
	_box(vehicle, Vector3(1.65, 0.72, 1.35), Vector3(-0.15, 1.42, 0), Color("#9dc4d3"), "VehicleCabin")
	for x in [-1.0, 1.0]:
		for z in [-0.83, 0.83]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.34
			mesh.bottom_radius = 0.34
			mesh.height = 0.16
			wheel.mesh = mesh
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, 0.35, z)
			wheel.material_override = _mat(Color("#20262b"))
			vehicle.add_child(wheel)
	for z in [-0.52, 0.52]:
		_box(vehicle, Vector3(0.12, 0.22, 0.12), Vector3(1.62, 0.78, z), Color("#fff1b0"), "Headlight")
	return vehicle

func _drive_vehicle(vehicle: Node3D, vertical: bool, forward: bool) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_LINEAR)
	var start := vehicle.position
	var finish := start
	if vertical:
		finish.z = ROAD_LIMIT if forward else -ROAD_LIMIT
	else:
		finish.x = ROAD_LIMIT if forward else -ROAD_LIMIT
	tween.tween_property(vehicle, "position", finish, DRIVE_TIME)
	tween.tween_property(vehicle, "position", start, DRIVE_TIME)

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, node_name: String) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos
	part.material_override = _mat(color)
	parent.add_child(part)

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material
