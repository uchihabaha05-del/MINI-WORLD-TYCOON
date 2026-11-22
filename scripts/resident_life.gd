extends Node3D

# MINI WORLD TYCOON — Milestone 34: autonomous resident routines and daily city life.
const RESIDENT_COUNT := 12
const DECISION_INTERVAL := 8.0
const DAY_LENGTH_SECONDS := 240.0
const WALK_SPEED := 3.2
const SHOP_SPEND_MIN := 2
const SHOP_SPEND_MAX := 7

var manager: Node
var city_life: Node
var transport: Node
var decision_timer: Timer
var hud_label: Label
var residents: Array[Node3D] = []
var home_positions: Array[Vector3] = []
var resident_tweens: Dictionary = {}
var resident_activity: Array[String] = []
var resident_mood: Array[int] = []
var resident_wallet: Array[int] = []
var resident_visits: Array[int] = []
var resident_jobs: Array[String] = []
var rng := RandomNumberGenerator.new()
var day_clock := 0.0
var total_shop_visits := 0
var total_work_shifts := 0
var total_park_visits := 0
var total_bus_trips := 0
var total_money_spent := 0
var day_number := 1

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	city_life = get_parent().get_node_or_null("CityPopulation")
	transport = get_parent().get_node_or_null("PublicTransport")
	_create_residents()
	_load_state()
	_create_hud()
	_start_decision_timer()
	_refresh_hud()

func _process(delta: float) -> void:
	day_clock += delta
	if day_clock >= DAY_LENGTH_SECONDS:
		day_clock = fposmod(day_clock, DAY_LENGTH_SECONDS)
		day_number += 1
		_save_state()
		_refresh_hud()
	for i in range(residents.size()):
		var resident := residents[i]
		if not is_instance_valid(resident):
			continue
		var phase := day_clock * 2.1 + float(i) * 0.7
		var swing := sin(phase) * 0.24
		var left := resident.get_node_or_null("LegLeft") as Node3D
		var right := resident.get_node_or_null("LegRight") as Node3D
		if left != null and right != null:
			left.rotation.x = swing
			right.rotation.x = -swing

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ResidentLifeHUD"
	layer.add_to_group("city_dashboard_panels")
	layer.visible = false
	layer.layer = 11
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(330, 365)
	panel.custom_minimum_size = Vector2(300, 120)
	layer.add_child(panel)
	hud_label = Label.new()
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(hud_label)

func _create_residents() -> void:
	var jobs := ["Продавец", "Повар", "Учитель", "Врач", "Мастер", "Водитель"]
	var colors := [Color("#4d86b5"), Color("#b66c59"), Color("#6b9b75"), Color("#9b79b5"), Color("#c39a4f"), Color("#548e99")]
	for i in range(RESIDENT_COUNT):
		var home := Vector3(-88.0 + float(i % 4) * 12.0, 0, -78.0 + float(i / 4) * 12.0)
		home_positions.append(home)
		resident_activity.append("Дома")
		resident_mood.append(rng.randi_range(60, 90))
		resident_wallet.append(rng.randi_range(20, 70))
		resident_visits.append(0)
		resident_jobs.append(jobs[i % jobs.size()])
		var citizen := Node3D.new()
		citizen.name = "AutonomousResident_%02d" % (i + 1)
		citizen.position = home
		add_child(citizen)
		_create_citizen_mesh(citizen, colors[i % colors.size()], i)
		residents.append(citizen)

func _create_citizen_mesh(citizen: Node3D, color: Color, index: int) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.28
	body_mesh.height = 1.35
	body.mesh = body_mesh
	body.position.y = 0.68
	body.material_override = _mat(color)
	citizen.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	head.mesh = head_mesh
	head.position.y = 1.55
	head.material_override = _mat(Color("#e5b995"))
	citizen.add_child(head)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegLeft" if side < 0.0 else "LegRight"
		leg.position = Vector3(side * 0.12, 0.38, 0)
		citizen.add_child(leg)
		var leg_mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.09
		capsule.height = 0.62
		leg_mesh.mesh = capsule
		leg_mesh.position.y = -0.18
		leg_mesh.material_override = _mat(Color("#344452"))
		leg.add_child(leg_mesh)
	var label := Label3D.new()
	label.text = "ЖИТЕЛЬ %02d" % (index + 1)
	label.font_size = 18
	label.pixel_size = 0.012
	label.position.y = 2.0
	citizen.add_child(label)

func _start_decision_timer() -> void:
	decision_timer = Timer.new()
	decision_timer.wait_time = DECISION_INTERVAL
	decision_timer.autostart = true
	decision_timer.timeout.connect(_update_resident_routines)
	add_child(decision_timer)
	_update_resident_routines()

func _update_resident_routines() -> void:
	var phase := day_clock / DAY_LENGTH_SECONDS
	for i in range(residents.size()):
		var activity := _choose_activity(i, phase)
		var destination := _destination_for(i, activity)
		var changed_activity := resident_activity[i] != activity
		resident_activity[i] = activity
		if changed_activity or residents[i].global_position.distance_to(destination) > 1.5:
			_move_resident(i, destination, activity)
	_save_state()
	_refresh_hud()

func _choose_activity(index: int, phase: float) -> String:
	if phase < 0.18:
		return "На работе" if index % 3 != 0 else "Дома"
	if phase < 0.48:
		if index % 4 == 0:
			return "В магазине"
		return "На работе"
	if phase < 0.68:
		match index % 4:
			0: return "В парке"
			1: return "В магазине"
			2: return "На остановке"
			_: return "На работе"
	if phase < 0.86:
		return "В парке" if index % 3 == 0 else "В магазине"
	return "Дома"

func _destination_for(index: int, activity: String) -> Vector3:
	match activity:
		"Дома":
			return home_positions[index]
		"В парке":
			if resident_activity[index] != activity:
				total_park_visits += 1
			return [Vector3(-45, 0, 55), Vector3(45, 0, 55), Vector3(0, 0, 72)][index % 3]
		"На остановке":
			if resident_activity[index] != activity:
				total_bus_trips += 1
				if transport != null and transport.has_method("register_commuters"):
					transport.call("register_commuters", 1)
			return [Vector3(-30, 0, -8), Vector3(30, 0, -8), Vector3(30, 0, 8), Vector3(-30, 0, 8)][index % 4]
		"В магазине":
			if resident_activity[index] != activity:
				total_shop_visits += 1
				resident_visits[index] += 1
				_spend_at_business(index)
			return _get_business_destination(index)
		_:
			if resident_activity[index] != activity:
				total_work_shifts += 1
			return _get_business_destination(index)

func _get_business_destination(index: int) -> Vector3:
	var choices: Array[Vector3] = []
	if manager != null:
		var plots: Array = manager.get("plots")
		for plot in plots:
			if String(plot.get("building", "")).is_empty():
				continue
			var area := plot.get("area") as Node3D
			if area != null:
				choices.append(area.global_position + Vector3(0, 0, 6.0))
	if choices.is_empty():
		return Vector3(-15.0 + float(index % 4) * 10.0, 0, -8.0 + float(index % 3) * 8.0)
	return choices[index % choices.size()]

func _spend_at_business(index: int) -> void:
	var amount := mini(resident_wallet[index], rng.randi_range(SHOP_SPEND_MIN, SHOP_SPEND_MAX))
	if amount <= 0:
		resident_mood[index] = maxi(25, resident_mood[index] - 2)
		return
	resident_wallet[index] -= amount
	total_money_spent += amount
	resident_mood[index] = mini(100, resident_mood[index] + 2)
	if manager != null:
		manager.set("cash", int(manager.get("cash")) + amount)
		manager.call("_save_game")
		manager.call("_refresh_ui")
	if city_life != null and city_life.has_method("record_customer_result"):
		city_life.call("record_customer_result", true)

func _move_resident(index: int, destination: Vector3, activity: String) -> void:
	var citizen := residents[index]
	if not is_instance_valid(citizen):
		return
	var key := str(index)
	if resident_tweens.has(key):
		var previous: Tween = resident_tweens[key]
		if is_instance_valid(previous):
			previous.kill()
	var distance := citizen.global_position.distance_to(destination)
	var duration := maxf(2.0, distance / WALK_SPEED)
	var tween := create_tween()
	resident_tweens[key] = tween
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(citizen, "global_position", destination, duration)
	tween.tween_callback(_resident_arrived.bind(index, activity))

func _resident_arrived(index: int, activity: String) -> void:
	if index < 0 or index >= residents.size():
		return
	if activity == "В парке":
		resident_mood[index] = mini(100, resident_mood[index] + 3)
	elif activity == "На работе":
		resident_wallet[index] = mini(100, resident_wallet[index] + 4)
	elif activity == "Дома":
		resident_mood[index] = mini(100, resident_mood[index] + 2)
	_refresh_hud()

func get_resident_count() -> int:
	return residents.size()

func get_average_resident_mood() -> int:
	if resident_mood.is_empty():
		return 0
	var total := 0
	for mood in resident_mood:
		total += mood
	return int(round(float(total) / float(resident_mood.size())))

func get_daily_shop_visits() -> int:
	return total_shop_visits

func _refresh_hud() -> void:
	if hud_label == null:
		return
	var home_count := 0
	var working_count := 0
	var shopping_count := 0
	var park_count := 0
	for activity in resident_activity:
		match activity:
			"Дома": home_count += 1
			"На работе": working_count += 1
			"В магазине": shopping_count += 1
			"В парке": park_count += 1
	hud_label.text = "🚶 ЖИЗНЬ ЖИТЕЛЕЙ • День %d\nДома: %d • Работа: %d • Магазины: %d • Парк: %d\nПокупок: %d • Потрачено: %d монет\nСреднее настроение: %d%% • Поездки к остановкам: %d" % [
		day_number, home_count, working_count, shopping_count, park_count,
		total_shop_visits, total_money_spent, get_average_resident_mood(), total_bus_trips
	]

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("life", "day_number", day_number)
	config.set_value("life", "total_shop_visits", total_shop_visits)
	config.set_value("life", "total_work_shifts", total_work_shifts)
	config.set_value("life", "total_park_visits", total_park_visits)
	config.set_value("life", "total_bus_trips", total_bus_trips)
	config.set_value("life", "total_money_spent", total_money_spent)
	for i in range(resident_mood.size()):
		config.set_value("residents", "mood_%d" % i, resident_mood[i])
		config.set_value("residents", "wallet_%d" % i, resident_wallet[i])
		config.set_value("residents", "visits_%d" % i, resident_visits[i])
	config.save("user://resident_life.cfg")

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load("user://resident_life.cfg") != OK:
		return
	day_number = maxi(1, int(config.get_value("life", "day_number", 1)))
	total_shop_visits = maxi(0, int(config.get_value("life", "total_shop_visits", 0)))
	total_work_shifts = maxi(0, int(config.get_value("life", "total_work_shifts", 0)))
	total_park_visits = maxi(0, int(config.get_value("life", "total_park_visits", 0)))
	total_bus_trips = maxi(0, int(config.get_value("life", "total_bus_trips", 0)))
	total_money_spent = maxi(0, int(config.get_value("life", "total_money_spent", 0)))
	for i in range(RESIDENT_COUNT):
		if i < resident_mood.size():
			resident_mood[i] = clampi(int(config.get_value("residents", "mood_%d" % i, resident_mood[i])), 20, 100)
		if i < resident_wallet.size():
			resident_wallet[i] = clampi(int(config.get_value("residents", "wallet_%d" % i, resident_wallet[i])), 0, 100)
		if i < resident_visits.size():
			resident_visits[i] = maxi(0, int(config.get_value("residents", "visits_%d" % i, 0)))

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
