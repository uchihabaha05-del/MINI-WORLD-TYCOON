extends Node3D

# MINI WORLD TYCOON — City industry network: professions, regional trade and cargo routes.
const DISTRICTS: Array[String] = ["Центр", "Северный район", "Южный район"]
const GOODS: Array[String] = ["Хлеб", "Напитки", "Снэки"]
const HUB_NAMES: Array[String] = ["Агроцентр", "Холодный склад", "Городской распределитель"]
const HUB_COSTS: Array[int] = [1100, 1450, 1900]
const HUB_POSITIONS: Array[Vector3] = [Vector3(-78, 0, 34), Vector3(78, 0, 34), Vector3(0, 0, -88)]
const DISTRICT_POSITIONS: Array[Vector3] = [Vector3(0, 0, 0), Vector3(-68, 0, -38), Vector3(68, 0, -38)]
const DISPATCH_COST := 35
const BASE_REWARD := 125
const SAVE_PATH := "user://city_industry_network.cfg"

var manager: Node
var residents: Node
var panel_layer: CanvasLayer
var summary_label: Label
var jobs_label: Label
var status_label: Label
var hub_labels: Array[Label] = []
var hub_buttons: Array[Button] = []
var dispatch_button: Button
var hubs: Array[bool] = [false, false, false]
var completed_shipments := 0
var failed_shipments := 0
var total_trade_revenue := 0
var total_trade_cost := 0
var active_shipments := 0
var shipment_cycle := 0
var profession_counts: Dictionary = {}
var hub_nodes: Array[Node3D] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	residents = get_parent().get_node_or_null("ResidentLife")
	_load_state()
	_create_hubs()
	_create_panel()
	_refresh_ui()

func _create_hubs() -> void:
	var colors: Array[Color] = [Color("#b78b55"), Color("#5795aa"), Color("#718b70")]
	for i in range(HUB_NAMES.size()):
		var hub := Node3D.new()
		hub.name = "IndustryHub_%d" % i
		hub.position = HUB_POSITIONS[i]
		add_child(hub)
		hub_nodes.append(hub)
		_add_box(hub, Vector3(10, 4.2, 8), Vector3(0, 2.1, 0), colors[i], "HubBuilding")
		_add_box(hub, Vector3(3.0, 2.3, 0.18), Vector3(0, 1.15, 4.08), Color("#34434a"), "HubDoor")
		for x in [-3.1, 3.1]:
			_add_box(hub, Vector3(1.5, 1.1, 0.12), Vector3(x, 3.0, 4.1), Color("#b9e1e8"), "HubWindow")
		var sign := Label3D.new()
		sign.text = HUB_NAMES[i]
		sign.font_size = 28
		sign.pixel_size = 0.012
		sign.position = Vector3(0, 4.8, 4.2)
		hub.add_child(sign)
		hub.visible = hubs[i]

func _create_panel() -> void:
	panel_layer = CanvasLayer.new()
	panel_layer.name = "CityIndustryNetworkHUD"
	panel_layer.layer = 12
	panel_layer.add_to_group("city_dashboard_panels")
	panel_layer.visible = false
	add_child(panel_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(640, 355)
	panel.custom_minimum_size = Vector2(350, 390)
	panel_layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var heading := Label.new()
	heading.text = "🏭 ПРОМЫШЛЕННАЯ СЕТЬ ГОРОДА"
	heading.add_theme_font_size_override("font_size", 19)
	content.add_child(heading)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary_label)
	jobs_label = Label.new()
	jobs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(jobs_label)
	var trade_heading := Label.new()
	trade_heading.text = "МЕЖРАЙОННАЯ ТОРГОВЛЯ"
	trade_heading.add_theme_font_size_override("font_size", 16)
	content.add_child(trade_heading)
	dispatch_button = Button.new()
	dispatch_button.pressed.connect(_dispatch_shipment)
	content.add_child(dispatch_button)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	var hub_heading := Label.new()
	hub_heading.text = "ЛОГИСТИЧЕСКИЕ ПРЕДПРИЯТИЯ"
	hub_heading.add_theme_font_size_override("font_size", 16)
	content.add_child(hub_heading)
	for i in range(HUB_NAMES.size()):
		var info := Label.new()
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(info)
		hub_labels.append(info)
		var button := Button.new()
		button.pressed.connect(_build_hub.bind(i))
		content.add_child(button)
		hub_buttons.append(button)

func _dispatch_shipment() -> void:
	if manager == null:
		return
	var cash := int(manager.get("cash"))
	if cash < DISPATCH_COST:
		status_label.text = "Не хватает %d монет на отправку груза" % (DISPATCH_COST - cash)
		return
	manager.set("cash", cash - DISPATCH_COST)
	total_trade_cost += DISPATCH_COST
	shipment_cycle += 1
	var from_id := shipment_cycle % DISTRICTS.size()
	var to_id := (from_id + 1 + (shipment_cycle % 2)) % DISTRICTS.size()
	var goods_id := shipment_cycle % GOODS.size()
	var amount := 8 + int(hubs[0]) * 2 + int(hubs[1]) * 3 + int(hubs[2]) * 4
	var reward := BASE_REWARD + amount * 7 + _hub_bonus()
	var order := {"from": from_id, "to": to_id, "goods": goods_id, "amount": amount, "reward": reward}
	active_shipments += 1
	status_label.text = "Груз %s ×%d: %s → %s. Машина в пути" % [GOODS[goods_id], amount, DISTRICTS[from_id], DISTRICTS[to_id]]
	_spawn_cargo_vehicle(from_id, to_id, order)
	_save_state()
	_save_economy()
	_refresh_ui()

func _spawn_cargo_vehicle(from_id: int, to_id: int, order: Dictionary) -> void:
	var van := Node3D.new()
	van.name = "InterdistrictCargoVan"
	van.position = DISTRICT_POSITIONS[from_id] + Vector3(0, 0.1, 0)
	add_child(van)
	_add_box(van, Vector3(3.6, 1.5, 1.9), Vector3(0, 1.0, 0), Color("#e7e9e6"), "CargoBody")
	_add_box(van, Vector3(1.3, 1.15, 1.75), Vector3(2.0, 0.9, 0), Color("#4c819c"), "CargoCab")
	_add_box(van, Vector3(2.3, 0.08, 1.65), Vector3(-0.1, 1.8, 0), Color("#d1a34e"), "CargoRoof")
	for x in [-1.0, 1.8]:
		for z in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.3
			mesh.bottom_radius = 0.3
			mesh.height = 0.14
			wheel.mesh = mesh
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, 0.35, z)
			wheel.material_override = _material(Color("#252b30"))
			van.add_child(wheel)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var midpoint := (DISTRICT_POSITIONS[from_id] + DISTRICT_POSITIONS[to_id]) * 0.5
	midpoint.y = 0.0
	tween.tween_property(van, "position", midpoint + Vector3(0, 0, 8), 3.0)
	tween.tween_property(van, "position", DISTRICT_POSITIONS[to_id], 3.0)
	tween.tween_callback(_complete_shipment.bind(order, van))

func _complete_shipment(order: Dictionary, van: Node3D) -> void:
	if is_instance_valid(van):
		van.queue_free()
	active_shipments = maxi(0, active_shipments - 1)
	var reward := int(order.get("reward", BASE_REWARD))
	var demand_bonus := 0
	if hubs[0]:
		demand_bonus += 8
	if hubs[1]:
		demand_bonus += 12
	if hubs[2]:
		demand_bonus += 18
	reward += demand_bonus
	if manager != null:
		manager.set("cash", int(manager.get("cash")) + reward)
		completed_shipments += 1
		total_trade_revenue += reward
		status_label.text = "Доставка завершена: %s ×%d → %s. +%d монет" % [
			GOODS[int(order.get("goods", 0))], int(order.get("amount", 0)),
			DISTRICTS[int(order.get("to", 0))], reward
		]
		_save_economy()
	_save_state()
	_refresh_ui()

func _build_hub(hub_id: int) -> void:
	if manager == null or hub_id < 0 or hub_id >= HUB_NAMES.size() or hubs[hub_id]:
		return
	var cost := HUB_COSTS[hub_id]
	var cash := int(manager.get("cash"))
	if cash < cost:
		status_label.text = "Не хватает %d монет для предприятия" % (cost - cash)
		return
	manager.set("cash", cash - cost)
	hubs[hub_id] = true
	hub_nodes[hub_id].visible = true
	status_label.text = "%s открыто! Новые рабочие места созданы" % HUB_NAMES[hub_id]
	_save_economy()
	_save_state()
	_refresh_ui()

func _hub_bonus() -> int:
	var bonus := 0
	for built in hubs:
		if built:
			bonus += 25
	return bonus

func _count_professions() -> void:
	profession_counts.clear()
	var jobs: Array = residents.get("resident_jobs") if residents != null else []
	for job in jobs:
		var title := String(job)
		profession_counts[title] = int(profession_counts.get(title, 0)) + 1

func _get_open_jobs() -> int:
	var total := 0
	for built in hubs:
		if built:
			total += 4
	return total

func _refresh_ui() -> void:
	if summary_label == null:
		return
	_count_professions()
	summary_label.text = "Предприятий: %d/3 • грузов в пути: %d\nДоставки: %d • торговая выручка: %d\nРасходы на отправку: %d • чистый результат: %d" % [
		_count_hubs(), active_shipments, completed_shipments, total_trade_revenue,
		total_trade_cost, total_trade_revenue - total_trade_cost
	]
	var job_lines: Array[String] = ["Профессии жителей:"]
	for profession in profession_counts.keys():
		job_lines.append("%s: %d" % [String(profession), int(profession_counts[profession])])
	job_lines.append("Новые рабочие места в логистике: %d" % _get_open_jobs())
	jobs_label.text = "\n".join(PackedStringArray(job_lines))
	dispatch_button.text = "🚚 Отправить межрайонный груз · %d монет" % DISPATCH_COST
	dispatch_button.disabled = manager == null
	for i in range(HUB_NAMES.size()):
		hub_labels[i].text = "%s • %s" % [HUB_NAMES[i], "работает" if hubs[i] else "не построено"]
		hub_buttons[i].text = "%s открыто" % HUB_NAMES[i] if hubs[i] else "Построить · %d монет" % HUB_COSTS[i]
		hub_buttons[i].disabled = hubs[i] or manager == null

func _count_hubs() -> int:
	var total := 0
	for built in hubs:
		if built:
			total += 1
	return total

func _save_economy() -> void:
	if manager != null:
		manager.call("_save_game")
		manager.call("_refresh_ui")

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("industry", "hubs", hubs)
	config.set_value("trade", "completed", completed_shipments)
	config.set_value("trade", "failed", failed_shipments)
	config.set_value("trade", "revenue", total_trade_revenue)
	config.set_value("trade", "cost", total_trade_cost)
	config.set_value("trade", "cycle", shipment_cycle)
	config.save(SAVE_PATH)

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var saved_hubs: Variant = config.get_value("industry", "hubs", hubs)
	if saved_hubs is Array and saved_hubs.size() == hubs.size():
		for i in range(hubs.size()):
			hubs[i] = bool(saved_hubs[i])
	completed_shipments = maxi(0, int(config.get_value("trade", "completed", 0)))
	failed_shipments = maxi(0, int(config.get_value("trade", "failed", 0)))
	total_trade_revenue = maxi(0, int(config.get_value("trade", "revenue", 0)))
	total_trade_cost = maxi(0, int(config.get_value("trade", "cost", 0)))
	shipment_cycle = maxi(0, int(config.get_value("trade", "cycle", 0)))

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, node_name: String) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos
	part.material_override = _material(color)
	parent.add_child(part)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
