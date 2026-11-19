extends Node3D

# MINI WORLD TYCOON — Milestone 11: residential population and city life.
const BASE_POPULATION := 36
const RESIDENTS_PER_APARTMENT_LEVEL := 12
const MAX_VISIBLE_RESIDENTS := 5
const LIFE_TICK := 20.0

var manager: Node
var population := BASE_POPULATION
var happiness := 70
var civic_demand_bonus := 0
var population_label: Label
var life_timer: Timer
var visible_residents: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var resident_total := 0

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	_create_hud()
	_recalculate_population()
	_spawn_resident_group()
	_start_life_timer()

func get_population() -> int:
	return population

func get_happiness() -> int:
	return happiness

func get_demand_bonus() -> int:
	return mini(8, int(population / 30.0) + civic_demand_bonus)

func _recalculate_population() -> void:
	population = BASE_POPULATION
	if manager != null:
		for plot in manager.get("plots"):
			if String(plot.get("building", "")) == "Апартаменты":
				population += RESIDENTS_PER_APARTMENT_LEVEL * int(plot.get("level", 1))
	population_label.text = "Жители: %d   •   Счастье: %d%%\nСпрос города: +%d монет к продаже" % [population, happiness, get_demand_bonus()]

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CityLifeHUD"
	layer.layer = 3
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(650, 198)
	panel.custom_minimum_size = Vector2(290, 58)
	layer.add_child(panel)
	population_label = Label.new()
	population_label.add_theme_font_size_override("font_size", 17)
	panel.add_child(population_label)

func _start_life_timer() -> void:
	life_timer = Timer.new()
	life_timer.wait_time = LIFE_TICK
	life_timer.autostart = true
	life_timer.timeout.connect(_on_city_tick)
	add_child(life_timer)

func _on_city_tick() -> void:
	_recalculate_population()
	var apartment_count := maxi(0, (population - BASE_POPULATION) / RESIDENTS_PER_APARTMENT_LEVEL)
	if apartment_count > 0:
		happiness = mini(100, happiness + 1)
	else:
		happiness = maxi(45, happiness - 1)
	_refresh_hud()
	_spawn_resident_group()

func _refresh_hud() -> void:
	population_label.text = "Жители: %d   •   Счастье: %d%%\nСпрос города: +%d монет к продаже" % [population, happiness, get_demand_bonus()]

func _spawn_resident_group() -> void:
	for resident in visible_residents:
		if is_instance_valid(resident):
			resident.queue_free()
	visible_residents.clear()
	for i in range(MAX_VISIBLE_RESIDENTS):
		var resident := _make_resident(i)
		visible_residents.append(resident)
		_walk_resident(resident, i)

func _make_resident(index: int) -> Node3D:
	resident_total += 1
	var resident := Node3D.new()
	resident.name = "CityResident_%d" % resident_total
	var start_positions := [
		Vector3(-8, 0, 14), Vector3(8, 0, 14),
		Vector3(-34, 0, 18), Vector3(34, 0, -18),
		Vector3(0, 0, 34)
	]
	resident.position = start_positions[index % start_positions.size()]
	add_child(resident)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.45
	body.mesh = capsule
	body.position.y = 0.73
	body.material_override = _material(Color("#547da3") if index % 2 == 0 else Color("#b77b55"))
	resident.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.21
	sphere.height = 0.42
	head.mesh = sphere
	head.position.y = 1.62
	head.material_override = _material(Color("#e4b894"))
	resident.add_child(head)
	return resident

func _walk_resident(resident: Node3D, index: int) -> void:
	var routes := [
		[Vector3(-8, 0, 14), Vector3(-8, 0, 7), Vector3(0, 0, 7), Vector3(8, 0, 14)],
		[Vector3(8, 0, 14), Vector3(8, 0, 7), Vector3(0, 0, 7), Vector3(-8, 0, 14)],
		[Vector3(-34, 0, 18), Vector3(-20, 0, 18), Vector3(-8, 0, 14)],
		[Vector3(34, 0, -18), Vector3(20, 0, -18), Vector3(8, 0, 14)],
		[Vector3(0, 0, 34), Vector3(0, 0, 20), Vector3(8, 0, 14)]
	]
	var route: Array = routes[index % routes.size()]
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_LINEAR)
	for point in route:
		tween.tween_property(resident, "position", point, 3.5)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
