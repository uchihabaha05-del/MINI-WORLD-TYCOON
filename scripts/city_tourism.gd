extends Node3D

# MINI WORLD TYCOON — Tourism & visitor economy.
# Tourists explore landmarks and become real shop customers.

const VISITOR_INTERVAL := 12.0
const MAX_ACTIVE_VISITORS := 8
const VISITOR_TRAVEL_TIME := 10.0
const CAMPAIGN_BASE_COST := 450
const SAVE_PATH := "user://city_tourism.cfg"
const LANDMARKS: Array[Dictionary] = [
	{"name": "Центральный парк", "position": Vector3(16, 0, 43), "kind": "park"},
	{"name": "MINI MARKET", "position": Vector3(-15, 0, -8), "kind": "shop"},
	{"name": "Городская площадь", "position": Vector3(-15, 0, -3), "kind": "plaza"}
]
const TOURIST_COLORS: Array[Color] = [
	Color("#d66e55"), Color("#4e91b8"), Color("#d6a64e"),
	Color("#7a70b5"), Color("#5b9a78"), Color("#d58ca5")
]

var manager: Node
var city_life: Node
var development: Node
var store: Node
var spawn_timer: Timer
var ui_timer: Timer
var panel_layer: CanvasLayer
var tourism_panel: PanelContainer
var summary_label: Label
var status_label: Label
var campaign_button: Button
var active_visitors: Array[Node3D] = []
var tourism_level := 0
var tourism_rating := 35
var total_visitors := 0
var satisfied_visitors := 0
var disappointed_visitors := 0
var tourist_sales := 0
var tourist_revenue := 0
var repeat_visitors := 0
var last_visit_day := -1
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	city_life = get_parent().get_node_or_null("CityPopulation")
	development = get_parent().get_node_or_null("CityDevelopment")
	store = get_parent().get_node_or_null("StoreGameplay")
	_load_state()
	_create_tourist_kiosk()
	_create_hud()
	_start_timers()
	_refresh_ui()

func _process(_delta: float) -> void:
	for i in range(active_visitors.size() - 1, -1, -1):
		if not is_instance_valid(active_visitors[i]):
			active_visitors.remove_at(i)

func _create_hud() -> void:
	panel_layer = CanvasLayer.new()
	panel_layer.name = "TourismHUD"
	panel_layer.layer = 9
	panel_layer.add_to_group("city_dashboard_panels")
	add_child(panel_layer)
	tourism_panel = PanelContainer.new()
	tourism_panel.position = Vector2(650, 430)
	tourism_panel.custom_minimum_size = Vector2(315, 205)
	tourism_panel.visible = false
	panel_layer.add_child(tourism_panel)
	var content := VBoxContainer.new()
	tourism_panel.add_child(content)
	var title := Label.new()
	title.text = "🧳 ТУРИЗМ И ГОСТИ"
	title.add_theme_font_size_override("font_size", 19)
	content.add_child(title)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	campaign_button = Button.new()
	campaign_button.pressed.connect(_upgrade_campaign)
	content.add_child(campaign_button)
	var toggle := Button.new()
	toggle.text = "Закрыть"
	toggle.pressed.connect(func() -> void: tourism_panel.visible = false)
	content.add_child(toggle)
	var open_button := Button.new()
	open_button.text = "🧳 Туризм"
	open_button.position = Vector2(18, 82)
	open_button.pressed.connect(func() -> void:
		tourism_panel.visible = not tourism_panel.visible
		_refresh_ui()
	)
	panel_layer.add_child(open_button)

func _create_tourist_kiosk() -> void:
	var kiosk := Node3D.new()
	kiosk.name = "TouristInformationKiosk"
	kiosk.position = Vector3(-25, 0, -5)
	add_child(kiosk)
	_box(kiosk, Vector3(2.2, 2.3, 0.55), Vector3(0, 1.15, 0), Color("#376b78"), "KioskBody")
	_box(kiosk, Vector3(2.35, 0.16, 0.68), Vector3(0, 2.38, 0), Color("#e5bd68"), "KioskRoof")
	var sign := Label3D.new()
	sign.text = "TOURIST INFO"
	sign.font_size = 28
	sign.pixel_size = 0.01
	sign.position = Vector3(0, 1.45, 0.3)
	sign.modulate = Color.WHITE
	kiosk.add_child(sign)
	_box(kiosk, Vector3(0.9, 0.65, 0.08), Vector3(0, 0.65, 0.3), Color("#a9d4d8"), "CityMapScreen")

func _start_timers() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = VISITOR_INTERVAL
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_spawn_tourist)
	add_child(spawn_timer)
	ui_timer = Timer.new()
	ui_timer.wait_time = 3.0
	ui_timer.autostart = true
	ui_timer.timeout.connect(_refresh_ui)
	add_child(ui_timer)

func _get_attraction_score() -> int:
	var score := 25 + tourism_level * 8
	if city_life != null:
		if city_life.has_method("get_happiness"):
			score += int(city_life.call("get_happiness")) / 8
		if city_life.has_method("get_city_loyalty"):
			score += int(city_life.call("get_city_loyalty")) / 12
	if development != null and development.has_method("get_completed_count"):
		score += int(development.call("get_completed_count")) * 4
	if manager != null and manager.has_method("_count_buildings"):
		score += int(manager.call("_count_buildings")) * 3
	return clampi(score, 0, 100)

func _spawn_tourist() -> void:
	if active_visitors.size() >= MAX_ACTIVE_VISITORS:
		return
	var attraction := _get_attraction_score()
	if rng.randi_range(0, 99) > attraction:
		return
	var destination_id := rng.randi_range(0, LANDMARKS.size() - 1)
	var visitor := _create_tourist_model()
	visitor.name = "Tourist_%d" % (total_visitors + 1)
	visitor.position = Vector3(-96, 0, rng.randf_range(-75.0, 75.0))
	add_child(visitor)
	active_visitors.append(visitor)
	var target: Vector3 = LANDMARKS[destination_id]["position"]
	var travel_time := VISITOR_TRAVEL_TIME * visitor.position.distance_to(target) / 115.0
	travel_time = clampf(travel_time, 6.0, 15.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(visitor, "position", target, travel_time)
	tween.tween_callback(_tourist_arrival.bind(visitor, destination_id))

func _create_tourist_model() -> Node3D:
	var visitor := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.45
	body.mesh = body_mesh
	body.position.y = 0.88
	body.material_override = _mat(TOURIST_COLORS[rng.randi_range(0, TOURIST_COLORS.size() - 1)])
	visitor.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.position.y = 1.78
	head.material_override = _mat(Color("#e5b995"))
	visitor.add_child(head)
	var bag := MeshInstance3D.new()
	var bag_mesh := BoxMesh.new()
	bag_mesh.size = Vector3(0.38, 0.46, 0.2)
	bag.mesh = bag_mesh
	bag.position = Vector3(-0.34, 1.05, -0.16)
	bag.material_override = _mat(Color("#8b684c"))
	visitor.add_child(bag)
	var tag := Label3D.new()
	tag.text = "ГОСТЬ"
	tag.font_size = 18
	tag.pixel_size = 0.009
	tag.position.y = 2.15
	visitor.add_child(tag)
	return visitor

func _tourist_arrival(visitor: Node3D, destination_id: int) -> void:
	if not is_instance_valid(visitor):
		return
	total_visitors += 1
	if rng.randf() < 0.18:
		repeat_visitors += 1
	var destination_kind := String(LANDMARKS[destination_id]["kind"])
	var was_satisfied := true
	if destination_kind == "shop" and store != null and store.has_method("serve_customer"):
		var cash_before := int(manager.get("cash")) if manager != null else 0
		was_satisfied = bool(store.call("serve_customer"))
		if was_satisfied:
			tourist_sales += 1
			satisfied_visitors += 1
			var cash_after := int(manager.get("cash")) if manager != null else cash_before
			tourist_revenue += maxi(0, cash_after - cash_before)
		else:
			disappointed_visitors += 1
	else:
		satisfied_visitors += 1
	if city_life != null and city_life.has_method("record_customer_result"):
		city_life.call("record_customer_result", was_satisfied)
	if was_satisfied:
		tourism_rating = mini(100, tourism_rating + 1)
	else:
		tourism_rating = maxi(0, tourism_rating - 2)
	visitor.queue_free()
	active_visitors.erase(visitor)
	_save_state()
	_refresh_ui()

func _upgrade_campaign() -> void:
	if manager == null:
		return
	if tourism_level >= 5:
		status_label.text = "Рекламная кампания уже достигла максимума"
		return
	var cost := CAMPAIGN_BASE_COST * (tourism_level + 1)
	if int(manager.get("cash")) < cost:
		status_label.text = "Не хватает %d монет на рекламу" % (cost - int(manager.get("cash")))
		return
	manager.set("cash", int(manager.get("cash")) - cost)
	tourism_level += 1
	tourism_rating = mini(100, tourism_rating + 5)
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_save_state()
	_refresh_ui()
	status_label.text = "Реклама запущена! Поток туристов увеличится"

func _refresh_ui() -> void:
	if summary_label == null:
		return
	var attraction := _get_attraction_score()
	summary_label.text = "Привлекательность: %d/100\nРейтинг туризма: %d/100\nГостей посетило: %d  •  Сейчас в пути: %d\nПокупки туристов: %d\nУдовлетворены: %d  •  Недовольны: %d\nПовторные визиты: %d" % [
		attraction, tourism_rating, total_visitors, active_visitors.size(),
		tourist_sales, satisfied_visitors, disappointed_visitors, repeat_visitors
	]
	var next_cost := CAMPAIGN_BASE_COST * (tourism_level + 1)
	campaign_button.text = "Улучшить рекламу — %d монет (%d/5)" % [next_cost, tourism_level]
	campaign_button.disabled = tourism_level >= 5 or manager == null or int(manager.get("cash")) < next_cost
	status_label.text = "Туристические покупки учитываются в кассе MINI MARKET"

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("tourism", "level", tourism_level)
	config.set_value("tourism", "rating", tourism_rating)
	config.set_value("stats", "visitors", total_visitors)
	config.set_value("stats", "satisfied", satisfied_visitors)
	config.set_value("stats", "disappointed", disappointed_visitors)
	config.set_value("stats", "sales", tourist_sales)
	config.set_value("stats", "revenue", tourist_revenue)
	config.set_value("stats", "repeat", repeat_visitors)
	config.save(SAVE_PATH)

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	tourism_level = clampi(int(config.get_value("tourism", "level", 0)), 0, 5)
	tourism_rating = clampi(int(config.get_value("tourism", "rating", 35)), 0, 100)
	total_visitors = maxi(0, int(config.get_value("stats", "visitors", 0)))
	satisfied_visitors = maxi(0, int(config.get_value("stats", "satisfied", 0)))
	disappointed_visitors = maxi(0, int(config.get_value("stats", "disappointed", 0)))
	tourist_sales = maxi(0, int(config.get_value("stats", "sales", 0)))
	tourist_revenue = maxi(0, int(config.get_value("stats", "revenue", 0)))
	repeat_visitors = maxi(0, int(config.get_value("stats", "repeat", 0)))

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
