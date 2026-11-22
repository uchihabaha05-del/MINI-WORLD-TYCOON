extends Node3D

# MINI WORLD TYCOON — Milestone 32: six municipal services and city incidents.
const SAVE_PATH := "user://city_services.cfg"
const SERVICE_TICK := 30.0
const INCIDENT_INTERVAL := 90.0
const MAX_LEVEL := 3
const SERVICE_NAMES := ["Полиция", "Пожарная служба", "Больница", "Школа", "Служба чистоты", "Парки"]
const SERVICE_ICONS := ["🚓", "🚒", "🏥", "🏫", "🧹", "🌳"]
const SERVICE_COLORS := [
	Color("#4777a8"), Color("#c95c4f"), Color("#73a6b5"),
	Color("#d7b45d"), Color("#8b9b73"), Color("#5e9a69")
]
const SERVICE_POSITIONS := [
	Vector3(-91, 0, -18), Vector3(-91, 0, 18),
	Vector3(91, 0, -18), Vector3(91, 0, 18),
	Vector3(-18, 0, 91), Vector3(18, 0, 91)
]
const BASE_COSTS := [500, 550, 600, 450, 400, 450]
const BASE_UPKEEP := [5, 6, 6, 4, 3, 3]

var manager: Node
var city_life: Node
var levels: Array[int] = [0, 0, 0, 0, 0, 0]
var buttons: Array[Button] = []
var service_label: Label
var incident_label: Label
var status_label: Label
var service_timer: Timer
var incident_timer: Timer
var rng := RandomNumberGenerator.new()
var total_upkeep_paid := 0
var incidents_resolved := 0
var incidents_missed := 0
var active_incident := ""
var active_incident_time := 0
var service_quality := 0

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	city_life = get_parent().get_node_or_null("CityPopulation")
	_load_state()
	_create_facilities()
	_create_hud()
	_recalculate_quality()
	_start_timers()
	_refresh_hud()

func _create_facilities() -> void:
	for i in range(SERVICE_NAMES.size()):
		var facility := Node3D.new()
		facility.name = "MunicipalFacility_%d" % i
		facility.position = SERVICE_POSITIONS[i]
		add_child(facility)
		var base := MeshInstance3D.new()
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(8.0, 0.35, 7.0)
		base.mesh = base_mesh
		base.position.y = 0.18
		base.material_override = _material(Color("#68777b"))
		facility.add_child(base)
		var building := MeshInstance3D.new()
		var building_mesh := BoxMesh.new()
		building_mesh.size = Vector3(5.0, 4.0 + float(levels[i]), 4.5)
		building.mesh = building_mesh
		building.position.y = 2.2 + float(levels[i]) * 0.5
		building.material_override = _material(SERVICE_COLORS[i])
		facility.add_child(building)
		var roof := MeshInstance3D.new()
		var roof_mesh := BoxMesh.new()
		roof_mesh.size = Vector3(5.5, 0.35, 5.0)
		roof.mesh = roof_mesh
		roof.position.y = 4.35 + float(levels[i])
		roof.material_override = _material(Color("#414e58"))
		facility.add_child(roof)
		var sign := Label3D.new()
		sign.text = SERVICE_ICONS[i] + " " + SERVICE_NAMES[i].to_upper()
		sign.font_size = 24
		sign.pixel_size = 0.012
		sign.position.y = 6.0 + float(levels[i])
		facility.add_child(sign)
		facility.set_meta("service_index", i)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CityServicesHUD"
	layer.add_to_group("city_dashboard_panels")
	layer.visible = false
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -330
	panel.offset_right = -14
	panel.offset_top = 205
	panel.offset_bottom = 590
	panel.custom_minimum_size = Vector2(300, 370)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var title := Label.new()
	title.text = "🏙 ГОРОДСКИЕ СЛУЖБЫ"
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)
	service_label = Label.new()
	service_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(service_label)
	incident_label = Label.new()
	incident_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(incident_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	for i in range(SERVICE_NAMES.size()):
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_upgrade_service.bind(i))
		buttons.append(button)
		content.add_child(button)

func _start_timers() -> void:
	service_timer = Timer.new()
	service_timer.wait_time = SERVICE_TICK
	service_timer.autostart = true
	service_timer.timeout.connect(_service_tick)
	add_child(service_timer)
	incident_timer = Timer.new()
	incident_timer.wait_time = INCIDENT_INTERVAL
	incident_timer.autostart = true
	incident_timer.timeout.connect(_try_city_incident)
	add_child(incident_timer)

func _upgrade_service(service_id: int) -> void:
	if service_id < 0 or service_id >= levels.size() or levels[service_id] >= MAX_LEVEL:
		return
	if manager == null:
		return
	var cost := BASE_COSTS[service_id] * (levels[service_id] + 1)
	var balance := int(manager.get("cash"))
	if balance < cost:
		status_label.text = "Не хватает %d монет для улучшения службы." % (cost - balance)
		return
	manager.set("cash", balance - cost)
	levels[service_id] += 1
	_rebuild_facility(service_id)
	_recalculate_quality()
	_save_state()
	manager.call("_save_game")
	manager.call("_refresh_ui")
	status_label.text = "%s улучшена до уровня %d!" % [SERVICE_NAMES[service_id], levels[service_id]]
	_refresh_hud()

func _rebuild_facility(service_id: int) -> void:
	var old := get_node_or_null("MunicipalFacility_%d" % service_id)
	if old != null:
		old.queue_free()
	var facility := Node3D.new()
	facility.name = "MunicipalFacility_%d" % service_id
	facility.position = SERVICE_POSITIONS[service_id]
	add_child(facility)
	var height := 4.0 + float(levels[service_id])
	_box(facility, Vector3(8.0, 0.35, 7.0), Vector3(0, 0.18, 0), Color("#68777b"))
	_box(facility, Vector3(5.0, height, 4.5), Vector3(0, height * 0.5 + 0.35, 0), SERVICE_COLORS[service_id])
	_box(facility, Vector3(5.5, 0.35, 5.0), Vector3(0, height + 0.55, 0), Color("#414e58"))
	var sign := Label3D.new()
	sign.text = SERVICE_ICONS[service_id] + " " + SERVICE_NAMES[service_id].to_upper() + " • " + str(levels[service_id])
	sign.font_size = 24
	sign.pixel_size = 0.012
	sign.position.y = height + 2.0
	facility.add_child(sign)

func _recalculate_quality() -> void:
	var total := 0
	for level in levels:
		total += level
	service_quality = int(round(float(total) / float(levels.size()) * 100.0 / float(MAX_LEVEL)))
	service_quality = clampi(service_quality, 0, 100)

func get_service_quality() -> int:
	return service_quality

func get_business_service_multiplier() -> float:
	return 1.0 + float(levels[3]) * 0.025 + float(levels[4]) * 0.02

func get_public_safety() -> int:
	return levels[0] * 20 + levels[1] * 10

func get_healthcare_quality() -> int:
	return levels[2] * 33

func get_education_quality() -> int:
	return levels[3] * 33

func get_cleanliness_quality() -> int:
	return levels[4] * 33

func get_park_quality() -> int:
	return levels[5] * 33

func _service_tick() -> void:
	if manager == null:
		return
	var upkeep := 0
	for i in range(levels.size()):
		upkeep += levels[i] * BASE_UPKEEP[i]
	var balance := int(manager.get("cash"))
	if upkeep > 0 and balance >= upkeep:
		manager.set("cash", balance - upkeep)
		total_upkeep_paid += upkeep
		status_label.text = "Городские службы получили финансирование: −%d монет." % upkeep
		if city_life != null and service_quality >= 35:
			city_life.set("happiness", mini(100, int(city_life.get("happiness")) + 1))
			city_life.set("city_loyalty", mini(100, int(city_life.get("city_loyalty")) + 1))
			if city_life.has_method("_save_city_state"):
				city_life.call("_save_city_state")
			if city_life.has_method("_refresh_hud"):
				city_life.call("_refresh_hud")
	elif upkeep > 0:
		status_label.text = "Недостаточно средств на содержание служб: нужно %d." % upkeep
		if city_life != null:
			city_life.set("happiness", maxi(35, int(city_life.get("happiness")) - 1))
			if city_life.has_method("_save_city_state"):
				city_life.call("_save_city_state")
	_save_state()
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_refresh_hud()

func _try_city_incident() -> void:
	if active_incident != "":
		return
	var incidents := [
		{"name": "Небольшое происшествие", "service": 0, "penalty": 2, "reward": 70},
		{"name": "Задымление в районе", "service": 1, "penalty": 3, "reward": 85},
		{"name": "Вспышка простуды", "service": 2, "penalty": 2, "reward": 75},
		{"name": "Проблемы в школе", "service": 3, "penalty": 1, "reward": 60},
		{"name": "Грязная улица", "service": 4, "penalty": 2, "reward": 65},
		{"name": "Повреждённый парк", "service": 5, "penalty": 1, "reward": 55}
	]
	var incident: Dictionary = incidents[rng.randi_range(0, incidents.size() - 1)]
	active_incident = String(incident["name"])
	active_incident_time = 25
	var required_service := int(incident["service"])
	var service_level := levels[required_service]
	var success_chance := 0.35 + float(service_level) * 0.2
	if rng.randf() <= success_chance:
		_resolve_incident(int(incident["reward"]))
	else:
		incident_label.text = "⚠ %s • службе нужно %d сек. на устранение" % [active_incident, active_incident_time]
		var response_timer := get_tree().create_timer(float(active_incident_time))
		response_timer.timeout.connect(_miss_incident.bind(int(incident["penalty"])))
	_refresh_hud()

func _resolve_incident(reward: int) -> void:
	active_incident = ""
	incidents_resolved += 1
	_save_state()
	if manager != null:
		manager.set("cash", int(manager.get("cash")) + reward)
		manager.call("_save_game")
		manager.call("_refresh_ui")
	incident_label.text = "✓ Городская служба быстро устранила проблему! +%d монет." % reward
	_refresh_hud()

func _miss_incident(penalty: int) -> void:
	if active_incident == "":
		return
	active_incident = ""
	incidents_missed += 1
	_save_state()
	if city_life != null:
		city_life.set("happiness", maxi(35, int(city_life.get("happiness")) - penalty))
		city_life.set("city_loyalty", maxi(20, int(city_life.get("city_loyalty")) - 1))
		if city_life.has_method("_save_city_state"):
			city_life.call("_save_city_state")
		if city_life.has_method("_refresh_hud"):
			city_life.call("_refresh_hud")
	incident_label.text = "⚠ Город не справился с проблемой. Счастье −%d." % penalty
	_refresh_hud()

func _refresh_hud() -> void:
	if service_label == null:
		return
	service_label.text = "Качество служб: %d/100\nРешено проблем: %d • Пропущено: %d\nСодержание: %d монет / 30 сек. • Всего: %d" % [
		service_quality, incidents_resolved, incidents_missed, _get_upkeep(), total_upkeep_paid
	]
	if active_incident == "":
		incident_label.text = "Городские происшествия: спокойно"
	for i in range(levels.size()):
		var next_cost := BASE_COSTS[i] * (levels[i] + 1)
		buttons[i].disabled = levels[i] >= MAX_LEVEL or manager == null or int(manager.get("cash")) < next_cost
		buttons[i].text = "%s %s • ур. %d/%d • улучшить: %d" % [
			SERVICE_ICONS[i], SERVICE_NAMES[i], levels[i], MAX_LEVEL, next_cost
		] if levels[i] < MAX_LEVEL else "%s %s • МАКСИМУМ" % [SERVICE_ICONS[i], SERVICE_NAMES[i]]

func _get_upkeep() -> int:
	var total := 0
	for i in range(levels.size()):
		total += levels[i] * BASE_UPKEEP[i]
	return total

func _save_state() -> void:
	var config := ConfigFile.new()
	for i in range(levels.size()):
		config.set_value("services", "level_%d" % i, levels[i])
	config.set_value("stats", "total_upkeep_paid", total_upkeep_paid)
	config.set_value("stats", "incidents_resolved", incidents_resolved)
	config.set_value("stats", "incidents_missed", incidents_missed)
	config.save(SAVE_PATH)

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for i in range(levels.size()):
		levels[i] = clampi(int(config.get_value("services", "level_%d" % i, 0)), 0, MAX_LEVEL)
	total_upkeep_paid = maxi(0, int(config.get_value("stats", "total_upkeep_paid", 0)))
	incidents_resolved = maxi(0, int(config.get_value("stats", "incidents_resolved", 0)))
	incidents_missed = maxi(0, int(config.get_value("stats", "incidents_missed", 0)))

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos
	part.material_override = _material(color)
	parent.add_child(part)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
