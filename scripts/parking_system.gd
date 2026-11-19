extends Node3D

# MINI WORLD TYCOON — Milestone 14: parking lots and occupancy.
const SLOT_COUNT := 16
const UPDATE_INTERVAL := 14.0
const MAX_OCCUPIED := 12

var occupied: Array[bool] = []
var parked_cars: Dictionary = {}
var status_label: Label
var timer: Timer
var rng := RandomNumberGenerator.new()
var arrivals := 0
var departures := 0

var slot_positions: Array[Vector3] = [
	Vector3(-21, 0, -36), Vector3(-11, 0, -36),
	Vector3(11, 0, -36), Vector3(21, 0, -36),
	Vector3(-21, 0, 36), Vector3(-11, 0, 36),
	Vector3(11, 0, 36), Vector3(21, 0, 36),
	Vector3(-82, 0, -55), Vector3(-72, 0, -55), Vector3(72, 0, -55), Vector3(82, 0, -55),
	Vector3(-82, 0, 55), Vector3(-72, 0, 55), Vector3(72, 0, 55), Vector3(82, 0, 55)
]

func _ready() -> void:
	rng.randomize()
	occupied.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		occupied[i] = false
	_create_hud()
	_create_parking_bays()
	_update_parking()
	_start_timer()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ParkingHUD"
	layer.layer = 3
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(650, 365)
	panel.custom_minimum_size = Vector2(290, 58)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(status_label)

func _create_parking_bays() -> void:
	for i in range(SLOT_COUNT):
		var pos: Vector3 = slot_positions[i]
		var bay := Node3D.new()
		bay.name = "ParkingBay_%d" % (i + 1)
		bay.position = pos
		add_child(bay)
		_box(bay, Vector3(7.0, 0.07, 3.8), Vector3.ZERO, Color("#6c7375"), "ParkingSurface")
		for x in [-3.2, 3.2]:
			_box(bay, Vector3(0.12, 0.035, 3.6), Vector3(x, 0.06, 0), Color("#f3e8c5"), "BayLine")
		_box(bay, Vector3(6.4, 0.035, 0.12), Vector3(0, 0.06, -1.75), Color("#f3e8c5"), "BayStopLine")

func _start_timer() -> void:
	timer = Timer.new()
	timer.wait_time = UPDATE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_update_parking)
	add_child(timer)

func _update_parking() -> void:
	var occupied_count := 0
	for value in occupied:
		if value:
			occupied_count += 1
	var target := rng.randi_range(2, MAX_OCCUPIED)
	if occupied_count < target:
		var free_slots: Array[int] = []
		for i in range(SLOT_COUNT):
			if not occupied[i]:
				free_slots.append(i)
		if not free_slots.is_empty():
			var slot_id: int = free_slots[rng.randi_range(0, free_slots.size() - 1)]
			_park_car(slot_id)
			arrivals += 1
	elif occupied_count > target:
		var full_slots: Array[int] = []
		for i in range(SLOT_COUNT):
			if occupied[i]:
				full_slots.append(i)
		if not full_slots.is_empty():
			var slot_id: int = full_slots[rng.randi_range(0, full_slots.size() - 1)]
			_remove_car(slot_id)
			departures += 1
	_refresh_hud()

func _park_car(slot_id: int) -> void:
	if occupied[slot_id]:
		return
	occupied[slot_id] = true
	var car := Node3D.new()
	car.name = "ParkedCar_%d" % slot_id
	car.position = slot_positions[slot_id]
	car.rotation_degrees.y = 90 if slot_id < 4 else -90
	add_child(car)
	var colors: Array[Color] = [Color("#c85d50"), Color("#4e83aa"), Color("#d8d9d3"), Color("#d1ae4c"), Color("#59666e")]
	var color: Color = colors[rng.randi_range(0, colors.size() - 1)]
	_box(car, Vector3(3.6, 0.9, 1.7), Vector3(0, 0.75, 0), color, "CarBody")
	_box(car, Vector3(1.9, 0.75, 1.5), Vector3(-0.2, 1.48, 0), Color("#9bbbc5"), "CarWindows")
	for x in [-1.15, 1.15]:
		for z in [-0.9, 0.9]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.34
			mesh.bottom_radius = 0.34
			mesh.height = 0.16
			wheel.mesh = mesh
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, 0.36, z)
			wheel.material_override = _mat(Color("#20262b"))
			car.add_child(wheel)
	parked_cars[slot_id] = car

func _remove_car(slot_id: int) -> void:
	occupied[slot_id] = false
	if parked_cars.has(slot_id):
		var car: Node3D = parked_cars[slot_id]
		if is_instance_valid(car):
			car.queue_free()
		parked_cars.erase(slot_id)

func _refresh_hud() -> void:
	var count := 0
	for value in occupied:
		if value:
			count += 1
	status_label.text = "🅿 Парковка: %d / %d мест занято\nЗаехало: %d  •  Выехало: %d" % [
		count, SLOT_COUNT, arrivals, departures
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
	material.roughness = 0.76
	return material
