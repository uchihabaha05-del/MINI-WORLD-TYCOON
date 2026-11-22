extends Node3D

# MINI WORLD TYCOON — Milestone 13: bus routes and passenger stops.
const BUS_INTERVAL := 22.0
const BUS_TRAVEL_TIME := 16.0
const FARE := 4
const MAX_PASSENGERS := 8

var manager: Node
var bus: Node3D
var timer: Timer
var status_label: Label
var passengers_waiting := 0
var passengers_served := 0
var total_fares := 0
var current_stop := 1
var stop_positions: Array[Vector3] = [
	Vector3(-30, 0, -8.0),
	Vector3(30, 0, -8.0),
	Vector3(30, 0, 8.0),
	Vector3(-30, 0, 8.0)
]

func _ready() -> void:
	manager = get_parent().get_node_or_null("TycoonManager")
	_create_bus_stops()
	_create_hud()
	_create_bus()
	_start_timer()
	_update_status()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PublicTransportHUD"
	layer.layer = 3
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(650, 295)
	panel.custom_minimum_size = Vector2(290, 64)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(status_label)

func _create_bus_stops() -> void:
	for i in range(stop_positions.size()):
		var stop := Node3D.new()
		stop.name = "BusStop_%d" % (i + 1)
		stop.position = stop_positions[i]
		add_child(stop)
		_box(stop, Vector3(2.2, 0.12, 1.1), Vector3.ZERO, Color("#58666d"), "Platform")
		_box(stop, Vector3(0.12, 2.5, 0.12), Vector3(-0.8, 1.25, 0), Color("#47545c"), "Post")
		_box(stop, Vector3(1.8, 1.0, 0.1), Vector3(0, 2.0, 0), Color("#3e8194"), "BusStopSign")
		var sign := Label3D.new()
		sign.text = "BUS %d" % (i + 1)
		sign.font_size = 26
		sign.pixel_size = 0.012
		sign.position = Vector3(0, 2.05, 0.08)
		sign.modulate = Color.WHITE
		stop.add_child(sign)
		_box(stop, Vector3(1.7, 0.08, 0.7), Vector3(0, 0.75, 0), Color("#9aa7aa"), "BenchSeat")
		_box(stop, Vector3(1.7, 0.65, 0.1), Vector3(0, 1.05, -0.28), Color("#9aa7aa"), "BenchBack")

func _create_bus() -> void:
	bus = Node3D.new()
	bus.name = "CityBus"
	bus.position = stop_positions[0]
	add_child(bus)
	_box(bus, Vector3(6.5, 2.3, 2.25), Vector3(0, 1.45, 0), Color("#e8c64e"), "BusBody")
	_box(bus, Vector3(4.8, 0.85, 2.28), Vector3(-0.35, 2.95, 0), Color("#5d8999"), "BusWindows")
	_box(bus, Vector3(1.0, 1.5, 2.3), Vector3(2.7, 1.8, 0), Color("#d9e8e8"), "DriverCab")
	for x in [-2.2, 2.2]:
		for z in [-1.18, 1.18]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.48
			mesh.bottom_radius = 0.48
			mesh.height = 0.18
			wheel.mesh = mesh
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, 0.55, z)
			wheel.material_override = _mat(Color("#20262b"))
			bus.add_child(wheel)
	var route_sign := Label3D.new()
	route_sign.text = "CITY BUS • 01"
	route_sign.font_size = 24
	route_sign.pixel_size = 0.012
	route_sign.position = Vector3(0, 3.6, 0)
	bus.add_child(route_sign)

func _start_timer() -> void:
	timer = Timer.new()
	timer.wait_time = BUS_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_bus_departure)
	add_child(timer)

func register_commuters(count: int) -> void:
	passengers_waiting = mini(MAX_PASSENGERS, passengers_waiting + maxi(0, count))
	_update_status()

func _bus_departure() -> void:
	passengers_waiting = mini(MAX_PASSENGERS, passengers_waiting + randi_range(1, 3))
	_update_status()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(bus, "position", stop_positions[1], BUS_TRAVEL_TIME / 3.0)
	tween.tween_callback(_bus_stop_arrival.bind(1))
	tween.tween_property(bus, "position", stop_positions[2], BUS_TRAVEL_TIME / 3.0)
	tween.tween_callback(_bus_stop_arrival.bind(2))
	tween.tween_property(bus, "position", stop_positions[3], BUS_TRAVEL_TIME / 3.0)
	tween.tween_callback(_bus_stop_arrival.bind(3))
	tween.tween_property(bus, "position", stop_positions[0], BUS_TRAVEL_TIME / 3.0)
	tween.tween_callback(_bus_stop_arrival.bind(0))

func _bus_stop_arrival(stop_index: int) -> void:
	current_stop = stop_index + 1
	if passengers_waiting > 0:
		var boarded := mini(passengers_waiting, randi_range(1, 3))
		passengers_waiting -= boarded
		passengers_served += boarded
		var fare_income := boarded * FARE
		total_fares += fare_income
		if manager != null:
			manager.set("cash", int(manager.get("cash")) + fare_income)
			manager.call("_save_game")
			manager.call("_refresh_ui")
	_update_status()

func _update_status() -> void:
	if status_label:
		status_label.text = "🚌 Маршрут 01 • остановка %d/4\nОжидают: %d  •  перевезено: %d\nДоход от билетов: %d монет" % [
			current_stop, passengers_waiting, passengers_served, total_fares
		]

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
	material.roughness = 0.75
	return material
