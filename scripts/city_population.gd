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
var civic_happiness_bonus := 0
var population_label: Label
var life_timer: Timer
var visible_residents: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var resident_total := 0
var happy_customer_count := 0
var disappointed_customer_count := 0
var city_loyalty := 65
var city_event_multiplier := 1.0
var city_event_name := "Обычный день"
var event_timer: Timer
var event_end_timer: Timer

func _ready() -> void:
	rng.randomize()
	_load_city_state()
	manager = get_parent().get_node_or_null("TycoonManager")
	_create_hud()
	_recalculate_population()
	_spawn_resident_group()
	_start_life_timer()
	_start_city_events()

func _load_city_state() -> void:
	var config := ConfigFile.new()
	if config.load("user://city_life.cfg") != OK:
		return
	happiness = clampi(int(config.get_value("city", "happiness", 70)), 35, 100)
	city_loyalty = clampi(int(config.get_value("city", "loyalty", 65)), 20, 100)
	happy_customer_count = maxi(0, int(config.get_value("city", "happy_customers", 0)))
	disappointed_customer_count = maxi(0, int(config.get_value("city", "disappointed_customers", 0)))

func _save_city_state() -> void:
	var config := ConfigFile.new()
	config.set_value("city", "happiness", happiness)
	config.set_value("city", "loyalty", city_loyalty)
	config.set_value("city", "happy_customers", happy_customer_count)
	config.set_value("city", "disappointed_customers", disappointed_customer_count)
	config.save("user://city_life.cfg")

func get_population() -> int:
	return population

func get_happiness() -> int:
	return happiness

func get_city_loyalty() -> int:
	return city_loyalty

func get_city_event_multiplier() -> float:
	return city_event_multiplier

func get_city_event_name() -> String:
	return city_event_name

func get_customer_capacity() -> int:
	return clampi(4 + int(population / 45.0) + int(happiness / 40.0), 4, 12)

func get_customer_interval_multiplier() -> float:
	var loyalty_factor := 0.85 + float(city_loyalty) / 400.0
	return clampf(loyalty_factor, 0.9, 1.1)

func get_demand_bonus() -> int:
	return mini(8, int(population / 30.0) + civic_demand_bonus)

func get_business_demand(business_type: String) -> int:
	var demand := 55 + int(maxi(0, population - BASE_POPULATION) / 8.0)
	var city_services := get_parent().get_node_or_null("CityServices")
	if city_services != null and city_services.has_method("get_service_quality"):
		demand += int(float(city_services.call("get_service_quality")) * 0.05)
	demand += int(round(float(happiness - 70) * 0.35))
	demand += int(round(float(city_loyalty - 65) * 0.15))
	match business_type:
		"Кафе":
			if population >= 60:
				demand += 8
			else:
				demand -= 4
		"Ресторан":
			if population >= 90:
				demand += 14
			else:
				demand -= 10
		"Мастерская":
			demand += 6
		"Магазин", "MINI MARKET":
			demand += 5
	var same_type_count := 0
	if manager != null:
		for plot in manager.get("plots"):
			if String(plot.get("building", "")) == business_type:
				same_type_count += 1
	demand -= maxi(0, same_type_count - 1) * 12
	return clampi(demand, 20, 100)

func get_business_demand_multiplier(business_type: String) -> float:
	return 0.75 + float(get_business_demand(business_type)) / 200.0

func record_customer_result(success: bool) -> void:
	if success:
		happy_customer_count += 1
		happiness = mini(100, happiness + 1)
		city_loyalty = mini(100, city_loyalty + 1)
	else:
		disappointed_customer_count += 1
		happiness = maxi(35, happiness - 3)
		city_loyalty = maxi(20, city_loyalty - 2)
	_save_city_state()
	_refresh_hud()


func _recalculate_population() -> void:
	population = BASE_POPULATION
	if manager != null:
		for plot in manager.get("plots"):
			if String(plot.get("building", "")) == "Апартаменты":
				population += RESIDENTS_PER_APARTMENT_LEVEL * int(plot.get("level", 1))
	_refresh_hud()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.add_to_group("city_dashboard_panels")
	layer.visible = false
	layer.name = "CityLifeHUD"
	layer.layer = 3
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(650, 198)
	panel.custom_minimum_size = Vector2(310, 116)
	layer.add_child(panel)
	population_label = Label.new()
	population_label.add_theme_font_size_override("font_size", 17)
	panel.add_child(population_label)

func _start_city_events() -> void:
	event_timer = Timer.new()
	event_timer.wait_time = 75.0
	event_timer.autostart = true
	event_timer.timeout.connect(_trigger_city_event)
	add_child(event_timer)
	event_end_timer = Timer.new()
	event_end_timer.one_shot = true
	event_end_timer.timeout.connect(_finish_city_event)
	add_child(event_end_timer)

func _trigger_city_event() -> void:
	var events := [
		{"name": "Ярмарка выходного дня", "multiplier": 1.25, "happiness": 2},
		{"name": "Городской фестиваль", "multiplier": 1.4, "happiness": 3},
		{"name": "Тихий торговый день", "multiplier": 0.9, "happiness": 0}
	]
	var event: Dictionary = events[rng.randi_range(0, events.size() - 1)]
	city_event_name = String(event["name"])
	city_event_multiplier = float(event["multiplier"])
	happiness = mini(100, happiness + int(event["happiness"]))
	event_end_timer.start(35.0)
	_save_city_state()
	_refresh_hud()

func _finish_city_event() -> void:
	city_event_name = "Обычный день"
	city_event_multiplier = 1.0
	_refresh_hud()

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
		happiness = maxi(45 + civic_happiness_bonus, happiness - 1)
	_save_city_state()
	_refresh_hud()
	_spawn_resident_group()

func _refresh_hud() -> void:
	if population_label == null:
		return
	population_label.text = "Жители: %d • Счастье: %d%% • Лояльность: %d%%\nСобытие: %s (x%.2f)\nСпрос +%d • Магазины %d • Кафе %d • Рестораны %d\n😊 Довольны: %d • 😟 Недовольны: %d" % [population, happiness, city_loyalty, city_event_name, city_event_multiplier, get_demand_bonus(), get_business_demand("Магазин"), get_business_demand("Кафе"), get_business_demand("Ресторан"), happy_customer_count, disappointed_customer_count]

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
