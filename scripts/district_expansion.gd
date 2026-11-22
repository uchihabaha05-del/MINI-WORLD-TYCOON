extends Node3D

# MINI WORLD TYCOON — District expansion: four unlockable economic neighbourhoods.
const SAVE_PATH := "user://district_expansion.cfg"
const TICK_SECONDS := 10.0
const DISTRICTS: Array[Dictionary] = [
	{"name": "Жилой квартал", "kind": "residential", "cost": 1600, "income": 35, "population": 36, "demand": 2, "position": Vector3(0, 0, 78), "color": Color("#8daecb"), "accent": Color("#e9c58e"), "description": "Новые дома, семьи и постоянные покупатели"},
	{"name": "Торговый центр", "kind": "commercial", "cost": 2200, "income": 50, "population": 8, "demand": 3, "position": Vector3(78, 0, 0), "color": Color("#d59b62"), "accent": Color("#f0d58d"), "description": "Магазины, витрины и поток покупателей"},
	{"name": "Промышленный район", "kind": "industrial", "cost": 2800, "income": 65, "population": 6, "demand": 2, "position": Vector3(-78, 0, 0), "color": Color("#87979b"), "accent": Color("#d7a76b"), "description": "Складские корпуса и рабочие места"},
	{"name": "Зона отдыха", "kind": "leisure", "cost": 1900, "income": 45, "population": 8, "demand": 2, "position": Vector3(0, 0, -78), "color": Color("#79a96d"), "accent": Color("#e7c77e"), "description": "Сквер, кафе и места для прогулок"}
]

var manager: Node
var unlocked: Array[bool] = [false, false, false, false]
var district_levels: Array[int] = [0, 0, 0, 0]
var buttons: Array[Button] = []
var upgrade_buttons: Array[Button] = []
var event_label: Label
var event_timer: Timer
var event_end_timer: Timer
var event_multiplier := 1.0
var event_name := "Обычный день"
var summary_label: Label
var status_label: Label
var income_timer: Timer

func _ready() -> void:
	manager = get_parent().get_node_or_null("TycoonManager")
	_load_state()
	_build_all_districts()
	_create_hud()
	_refresh_hud()
	_start_district_events()
	income_timer = Timer.new()
	income_timer.wait_time = TICK_SECONDS
	income_timer.autostart = true
	income_timer.timeout.connect(_collect_district_income)
	add_child(income_timer)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DistrictExpansionHUD"
	layer.layer = 12
	layer.visible = false
	layer.add_to_group("city_dashboard_panels")
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 112)
	panel.custom_minimum_size = Vector2(320, 260)
	panel.size = Vector2(320, 260)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 245)
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var title := Label.new()
	title.text = "🧭 РАСШИРЕНИЕ ГОРОДА"
	title.add_theme_font_size_override("font_size", 19)
	content.add_child(title)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	for i in range(DISTRICTS.size()):
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_unlock_district.bind(i))
		buttons.append(button)
		content.add_child(button)
		var upgrade := Button.new()
		upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade.pressed.connect(_upgrade_district.bind(i))
		upgrade_buttons.append(upgrade)
		content.add_child(upgrade)
	event_label = Label.new()
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(event_label)

func _build_all_districts() -> void:
	for i in range(DISTRICTS.size()):
		_build_district_visual(i)

func _build_district_visual(index: int) -> void:
	var data: Dictionary = DISTRICTS[index]
	var root := Node3D.new()
	root.name = "ExpansionDistrict_%d" % index
	root.position = data["position"]
	add_child(root)
	var unlocked_now: bool = unlocked[index]
	_box(root, Vector3(15.0, 0.16, 15.0), Vector3(0, 0.08, 0), Color("#8c9b79") if unlocked_now else Color("#69766a"), "DistrictBase")
	_box(root, Vector3(10.5, 0.12, 2.0), Vector3(0, 0.19, 0), Color("#c8c2ad"), "DistrictWalkway")
	_box(root, Vector3(2.0, 0.13, 10.5), Vector3(0, 0.2, 0), Color("#c8c2ad"), "DistrictWalkway")
	if unlocked_now:
		var main_height := 5.5 + float(district_levels[index]) * 0.8
		if String(data["kind"]) == "residential":
			main_height = 9.0
		elif String(data["kind"]) == "industrial":
			main_height = 6.5
		_box(root, Vector3(5.2, main_height, 4.8), Vector3(-2.4, main_height * 0.5 + 0.2, -2.0), data["color"], "DistrictMainBuilding")
		_box(root, Vector3(5.5, 0.35, 5.1), Vector3(-2.4, main_height + 0.4, -2.0), data["accent"], "DistrictRoof")
		_box(root, Vector3(2.2, 2.0, 0.12), Vector3(-2.4, 2.1, 0.48), Color("#456879"), "DistrictWindow")
		_box(root, Vector3(3.8, 2.6, 3.5), Vector3(3.1, 1.5, 2.8), data["accent"], "DistrictAnnex")
		_box(root, Vector3(4.0, 0.25, 3.7), Vector3(3.1, 2.9, 2.8), Color("#53636a"), "DistrictAnnexRoof")
		for x in [-6.0, 6.0]:
			_cylinder(root, Vector3(x, 1.0, -5.8), 0.16, 2.0, Color("#76543b"), "DistrictTreeTrunk")
			_sphere(root, Vector3(x, 2.25, -5.8), 1.15, Color("#4d8953"), "DistrictTreeCanopy")
			_box(root, Vector3(1.8, 0.16, 0.65), Vector3(x, 0.65, 5.6), Color("#936b48"), "DistrictBench")
		for x in [-5.8, 5.8]:
			_cylinder(root, Vector3(x, 2.0, 0), 0.07, 4.0, Color("#46545b"), "DistrictLampPole")
			_sphere(root, Vector3(x, 4.0, 0), 0.28, Color("#ffe2a1"), "DistrictLamp")
	var sign := Label3D.new()
	sign.name = "DistrictSign"
	sign.text = String(data["name"]).to_upper() + " • УР. %d" % district_levels[index] if unlocked_now else "РАЙОН ЗАКРЫТ"
	sign.font_size = 34
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 5.4 if unlocked_now else 2.0, -7.0)
	sign.modulate = Color("#fff2cf") if unlocked_now else Color("#d4d9d2")
	root.add_child(sign)

func _upgrade_district(index: int) -> void:
	if index < 0 or index >= DISTRICTS.size() or not unlocked[index] or manager == null:
		return
	var level := district_levels[index]
	if level >= 3:
		status_label.text = "Этот район уже достиг максимального уровня."
		return
	var cost := 850 + index * 180 + level * 950
	var cash := int(manager.get("cash"))
	if cash < cost:
		status_label.text = "Для улучшения нужно ещё %d монет." % (cost - cash)
		return
	manager.set("cash", cash - cost)
	district_levels[index] = level + 1
	var old_visual := get_node_or_null("ExpansionDistrict_%d" % index)
	if old_visual != null:
		old_visual.queue_free()
	_build_district_visual(index)
	_save_state()
	if manager.has_method("_save_game"):
		manager.call("_save_game")
	if manager.has_method("_refresh_ui"):
		manager.call("_refresh_ui")
	status_label.text = "Район «%s» улучшен до уровня %d!" % [DISTRICTS[index]["name"], district_levels[index]]
	_refresh_hud()

func _start_district_events() -> void:
	event_timer = Timer.new()
	event_timer.wait_time = 75.0
	event_timer.autostart = true
	event_timer.timeout.connect(_trigger_district_event)
	add_child(event_timer)
	event_end_timer = Timer.new()
	event_end_timer.one_shot = true
	event_end_timer.timeout.connect(_finish_district_event)
	add_child(event_end_timer)

func _trigger_district_event() -> void:
	var events: Array[Dictionary] = [
		{"name": "Городская ярмарка", "multiplier": 1.35, "duration": 35.0},
		{"name": "Поток туристов", "multiplier": 1.5, "duration": 25.0},
		{"name": "День местных производителей", "multiplier": 1.25, "duration": 45.0},
		{"name": "Спокойный день", "multiplier": 0.9, "duration": 30.0}
	]
	var event: Dictionary = events[randi_range(0, events.size() - 1)]
	event_name = String(event["name"])
	event_multiplier = float(event["multiplier"])
	event_end_timer.start(float(event["duration"]))
	_refresh_hud()

func _finish_district_event() -> void:
	event_name = "Обычный день"
	event_multiplier = 1.0
	_refresh_hud()

func _unlock_district(index: int) -> void:
	if index < 0 or index >= DISTRICTS.size() or unlocked[index] or manager == null:
		return
	var cost := int(DISTRICTS[index]["cost"])
	var cash := int(manager.get("cash"))
	if cash < cost:
		status_label.text = "Не хватает %d монет для открытия района." % (cost - cash)
		return
	manager.set("cash", cash - cost)
	unlocked[index] = true
	var old_visual := get_node_or_null("ExpansionDistrict_%d" % index)
	if old_visual != null:
		old_visual.queue_free()
	_build_district_visual(index)
	_save_state()
	if manager.has_method("_save_game"):
		manager.call("_save_game")
	if manager.has_method("_refresh_ui"):
		manager.call("_refresh_ui")
	var data: Dictionary = DISTRICTS[index]
	status_label.text = "Открыт район «%s»! Теперь он приносит %d монет каждые 10 секунд." % [data["name"], data["income"]]
	_refresh_hud()

func _collect_district_income() -> void:
	if manager == null:
		return
	var income := get_income_bonus()
	if income <= 0:
		return
	manager.set("cash", int(manager.get("cash")) + income)
	if manager.has_method("_save_game"):
		manager.call("_save_game")
	if manager.has_method("_refresh_ui"):
		manager.call("_refresh_ui")
	_refresh_hud()

func get_income_bonus() -> int:
	var total := 0
	for i in range(DISTRICTS.size()):
		if unlocked[i]:
			total += roundi(float(DISTRICTS[i]["income"]) * (1.0 + float(district_levels[i]) * 0.35) * event_multiplier)
	return total

func get_population_bonus() -> int:
	var total := 0
	for i in range(DISTRICTS.size()):
		if unlocked[i]:
			total += int(DISTRICTS[i]["population"]) + district_levels[i] * 8
	return total

func get_demand_bonus() -> int:
	var total := 0
	for i in range(DISTRICTS.size()):
		if unlocked[i]:
			total += int(DISTRICTS[i]["demand"]) + district_levels[i]
	return total

func get_district_level(index: int) -> int:
	if index < 0 or index >= district_levels.size():
		return 0
	return district_levels[index]

func get_district_rating() -> int:
	var score := 0
	for i in range(unlocked.size()):
		if unlocked[i]:
			score += 15 + district_levels[i] * 7
	return mini(100, score)

func get_district_business_multiplier(business_type: String) -> float:
	var bonus := 0.0
	for i in range(DISTRICTS.size()):
		if not unlocked[i]:
			continue
		var kind := String(DISTRICTS[i]["kind"])
		if (kind == "commercial" and business_type in ["Магазин", "Кафе", "Ресторан"]) or (kind == "industrial" and business_type == "Мастерская") or (kind == "leisure" and business_type in ["Кафе", "Ресторан"]) or (kind == "residential" and business_type in ["Магазин", "Апартаменты"]):
			bonus += 0.04 + float(district_levels[i]) * 0.035
	return minf(0.3, bonus)

func get_unlocked_count() -> int:
	var total := 0
	for is_unlocked in unlocked:
		if is_unlocked:
			total += 1
	return total

func _refresh_hud() -> void:
	if summary_label == null:
		return
	var count := get_unlocked_count()
	summary_label.text = "Открыто районов: %d/4\nДоп. доход: +%d / 10 сек.\nНаселение: +%d • спрос: +%d\nРейтинг районов: %d/100" % [count, get_income_bonus(), get_population_bonus(), get_demand_bonus(), get_district_rating()]
	event_label.text = "Событие: %s • доход районов x%.2f" % [event_name, event_multiplier]
	for i in range(DISTRICTS.size()):
		var data: Dictionary = DISTRICTS[i]
		var button := buttons[i]
		button.disabled = unlocked[i] or manager == null or int(manager.get("cash")) < int(data["cost"])
		button.text = ("✓ " if unlocked[i] else "＋ ") + String(data["name"]) + (" • ур. %d" % district_levels[i] if unlocked[i] else " • %d монет" % int(data["cost"]))
		var level := district_levels[i]
		var upgrade_cost := 850 + i * 180 + level * 950
		upgrade_buttons[i].visible = unlocked[i]
		upgrade_buttons[i].disabled = level >= 3 or manager == null or int(manager.get("cash")) < upgrade_cost
		upgrade_buttons[i].text = "Улучшить %s · %d монет" % [String(data["name"]), upgrade_cost] if level < 3 else "✓ Максимальный уровень"

func _save_state() -> void:
	var config := ConfigFile.new()
	for i in range(unlocked.size()):
		config.set_value("districts", "unlocked_%d" % i, unlocked[i])
		config.set_value("districts", "level_%d" % i, district_levels[i])
	config.save(SAVE_PATH)

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for i in range(unlocked.size()):
		unlocked[i] = bool(config.get_value("districts", "unlocked_%d" % i, false))
		district_levels[i] = clampi(int(config.get_value("districts", "level_%d" % i, 0)), 0, 3)

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color)
	parent.add_child(instance)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color)
	parent.add_child(instance)

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color)
	parent.add_child(instance)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
