extends Node3D

# MINI WORLD TYCOON — Production & manufacturing milestone.
# Three factories turn purchased raw materials into retail inventory.
const FACTORY_NAMES: Array[String] = ["Пекарня", "Завод напитков", "Фабрика снеков"]
const PRODUCT_NAMES: Array[String] = ["Хлеб", "Напитки", "Снэки"]
const BUILD_COSTS: Array[int] = [900, 1250, 1550]
const UPGRADE_COSTS: Array[int] = [650, 850, 1050]
const WORKER_COST := 180
const WORKER_SALARY := 9
const SHIFT_INTERVAL := 22.0
const PAYROLL_INTERVAL := 30.0
const MAX_WORKERS := 5
const RAW_NAMES: Array[String] = ["Зерно", "Фрукты", "Упаковка", "Электроэнергия"]
const RAW_PRICES: Array[int] = [8, 11, 6, 5]
const RAW_PER_BATCH: Array[Array] = [[3, 0, 1, 1], [0, 3, 2, 2], [1, 1, 2, 1]]
const OUTPUT_PER_BATCH: Array[int] = [6, 6, 8]
const BASE_FACTORY_CAPACITY := 24

var manager: Node
var shop: Node
var supply: Node
var factories: Array[Dictionary] = []
var raw_stock: Array[int] = [24, 18, 30, 30]
var total_batches := 0
var total_units_produced := 0
var total_raw_spent := 0
var total_payroll := 0
var total_factory_revenue := 0
var shift_timer: Timer
var payroll_timer: Timer
var panel: PanelContainer
var summary_label: Label
var raw_label: Label
var status_label: Label
var factory_labels: Array[Label] = []
var build_buttons: Array[Button] = []
var upgrade_buttons: Array[Button] = []
var worker_buttons: Array[Button] = []
var shift_buttons: Array[Button] = []
var raw_buttons: Array[Button] = []
var factory_nodes: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var market: Node

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	shop = get_parent().get_node_or_null("StoreGameplay")
	supply = get_parent().get_node_or_null("SupplyChain")
	market = get_parent().get_node_or_null("MarketEconomy")
	_load_state()
	_create_factory_visuals()
	_create_panel()
	_start_timers()
	_refresh_ui()

func _create_factory_visuals() -> void:
	var positions: Array[Vector3] = [
		Vector3(82, 0, -48),
		Vector3(82, 0, -22),
		Vector3(82, 0, 4)
	]
	for i in range(FACTORY_NAMES.size()):
		var factory := Node3D.new()
		factory.name = "Factory_%d" % i
		factory.position = positions[i]
		add_child(factory)
		factory_nodes.append(factory)
		_build_factory_visual(factory, i)
		factory.visible = _is_factory_built(i)

func _build_factory_visual(parent: Node3D, factory_id: int) -> void:
	var colors: Array[Color] = [Color("#bd8657"), Color("#5c9eb2"), Color("#a875a8")]
	_add_box(parent, Vector3(12, 5.5, 9), Vector3(0, 2.75, 0), colors[factory_id], "FactoryBody")
	_add_box(parent, Vector3(3.0, 2.6, 0.2), Vector3(0, 1.3, 4.6), Color("#46545b"), "FactoryDoor")
	_add_box(parent, Vector3(2.0, 3.8, 2.0), Vector3(-3.5, 6.0, -2.2), Color("#89969a"), "Chimney")
	_add_box(parent, Vector3(2.0, 0.25, 2.0), Vector3(-3.5, 8.0, -2.2), Color("#64747a"), "ChimneyCap")
	var sign := Label3D.new()
	sign.text = FACTORY_NAMES[factory_id]
	sign.font_size = 32
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 5.0, 4.8)
	sign.modulate = Color.WHITE
	parent.add_child(sign)
	var window_color := Color("#b9e4ec")
	for x in [-4.0, 4.0]:
		_add_box(parent, Vector3(1.8, 1.3, 0.12), Vector3(x, 3.2, 4.62), window_color, "FactoryWindow")

func _create_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ProductionHUD"
	layer.layer = 8
	layer.add_to_group("city_dashboard_panels")
	layer.visible = false
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(650, 370)
	panel.custom_minimum_size = Vector2(340, 370)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var title := Label.new()
	title.text = "🏭 ПРОИЗВОДСТВО"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary_label)
	raw_label = Label.new()
	raw_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(raw_label)
	for i in range(RAW_NAMES.size()):
		var raw_button := Button.new()
		raw_button.pressed.connect(_buy_raw_material.bind(i))
		content.add_child(raw_button)
		raw_buttons.append(raw_button)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	for i in range(FACTORY_NAMES.size()):
		var heading := Label.new()
		heading.text = FACTORY_NAMES[i]
		heading.add_theme_font_size_override("font_size", 16)
		content.add_child(heading)
		var info := Label.new()
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(info)
		factory_labels.append(info)
		var build := Button.new()
		build.pressed.connect(_build_factory.bind(i))
		content.add_child(build)
		build_buttons.append(build)
		var row := HBoxContainer.new()
		content.add_child(row)
		var upgrade := Button.new()
		upgrade.pressed.connect(_upgrade_factory.bind(i))
		row.add_child(upgrade)
		upgrade_buttons.append(upgrade)
		var worker := Button.new()
		worker.pressed.connect(_hire_factory_worker.bind(i))
		row.add_child(worker)
		worker_buttons.append(worker)
		var shift := Button.new()
		shift.pressed.connect(_toggle_factory_shift.bind(i))
		content.add_child(shift)
		shift_buttons.append(shift)

func _start_timers() -> void:
	shift_timer = Timer.new()
	shift_timer.wait_time = SHIFT_INTERVAL
	shift_timer.autostart = true
	shift_timer.timeout.connect(_production_tick)
	add_child(shift_timer)
	payroll_timer = Timer.new()
	payroll_timer.wait_time = PAYROLL_INTERVAL
	payroll_timer.autostart = true
	payroll_timer.timeout.connect(_payroll_tick)
	add_child(payroll_timer)

func _build_factory(factory_id: int) -> void:
	if manager == null or factory_id < 0 or factory_id >= FACTORY_NAMES.size():
		return
	if _is_factory_built(factory_id):
		return
	var cost := BUILD_COSTS[factory_id]
	if int(manager.get("cash")) < cost:
		status_label.text = "Не хватает %d монет для строительства" % (cost - int(manager.get("cash")))
		return
	manager.set("cash", int(manager.get("cash")) - cost)
	factories[factory_id] = {
		"built": true,
		"level": 1,
		"workers": 1,
		"active": true,
		"batches": 0,
		"produced": 0,
		"failed_shifts": 0
	}
	if factory_id < factory_nodes.size():
		factory_nodes[factory_id].visible = true
	_save_economy()
	_save_state()
	_refresh_ui()
	status_label.text = "%s построена. Первая смена запущена!" % FACTORY_NAMES[factory_id]

func _upgrade_factory(factory_id: int) -> void:
	if not _is_factory_built(factory_id):
		return
	var level := int(factories[factory_id].get("level", 1))
	var cost := UPGRADE_COSTS[factory_id] * level
	if manager == null or int(manager.get("cash")) < cost:
		status_label.text = "Недостаточно средств для улучшения"
		return
	manager.set("cash", int(manager.get("cash")) - cost)
	factories[factory_id]["level"] = level + 1
	_save_economy()
	_save_state()
	_refresh_ui()

func _hire_factory_worker(factory_id: int) -> void:
	if not _is_factory_built(factory_id):
		return
	var workers := int(factories[factory_id].get("workers", 0))
	if workers >= MAX_WORKERS:
		status_label.text = "Достигнут лимит персонала"
		return
	if manager == null or int(manager.get("cash")) < WORKER_COST:
		status_label.text = "Не хватает монет на найм"
		return
	manager.set("cash", int(manager.get("cash")) - WORKER_COST)
	factories[factory_id]["workers"] = workers + 1
	_save_economy()
	_save_state()
	_refresh_ui()

func _toggle_factory_shift(factory_id: int) -> void:
	if not _is_factory_built(factory_id):
		return
	factories[factory_id]["active"] = not bool(factories[factory_id].get("active", true))
	_save_state()
	_refresh_ui()

func _buy_raw_material(raw_id: int) -> void:
	if raw_id < 0 or raw_id >= RAW_NAMES.size() or manager == null:
		return
	var amount := 20
	var unit_price := int(market.call("get_raw_price", raw_id)) if market != null and market.has_method("get_raw_price") else RAW_PRICES[raw_id]
	var cost := unit_price * amount
	var current_total := 0
	for value in raw_stock:
		current_total += value
	if current_total + amount > 180:
		status_label.text = "Сырьевой склад заполнен (180 единиц)"
		return
	if int(manager.get("cash")) < cost:
		status_label.text = "Не хватает монет на закупку сырья"
		return
	manager.set("cash", int(manager.get("cash")) - cost)
	raw_stock[raw_id] += amount
	total_raw_spent += cost
	_save_economy()
	_save_state()
	_refresh_ui()
	status_label.text = "Закуплено: %s +%d" % [RAW_NAMES[raw_id], amount]

func _production_tick() -> void:
	if shop == null:
		return
	var produced_any := false
	var state_changed := false
	for i in range(factories.size()):
		if not _is_factory_built(i) or not bool(factories[i].get("active", true)):
			continue
		var workers := int(factories[i].get("workers", 0))
		if workers <= 0 or not _has_recipe_materials(i):
			factories[i]["failed_shifts"] = int(factories[i].get("failed_shifts", 0)) + 1
			state_changed = true
			continue
		if not _has_output_capacity(OUTPUT_PER_BATCH[i]):
			status_label.text = "Склад магазина заполнен: производство %s приостановлено" % PRODUCT_NAMES[i]
			state_changed = true
			continue
		_consume_recipe(i)
		var level := int(factories[i].get("level", 1))
		var output := OUTPUT_PER_BATCH[i] + (level - 1) * 2 + int((workers - 1) / 2)
		_add_to_shop_stock(i, output)
		factories[i]["batches"] = int(factories[i].get("batches", 0)) + 1
		factories[i]["produced"] = int(factories[i].get("produced", 0)) + output
		total_batches += 1
		total_units_produced += output
		produced_any = true
		state_changed = true
	if produced_any:
		_refresh_shop()
	if state_changed:
		_save_state()
		_refresh_ui()

func _has_recipe_materials(factory_id: int) -> bool:
	for raw_id in range(RAW_NAMES.size()):
		if raw_stock[raw_id] < int(RAW_PER_BATCH[factory_id][raw_id]):
			return false
	return true

func _consume_recipe(factory_id: int) -> void:
	for raw_id in range(RAW_NAMES.size()):
		raw_stock[raw_id] -= int(RAW_PER_BATCH[factory_id][raw_id])

func _has_output_capacity(amount: int) -> bool:
	var current := 0
	if shop != null:
		var stock: Array[int] = shop.get("stock")
		for value in stock:
			current += value
	var pending := 0
	if supply != null and supply.has_method("_get_pending_units"):
		pending = int(supply.call("_get_pending_units"))
	var capacity := int(supply.call("get_warehouse_capacity")) if supply != null and supply.has_method("get_warehouse_capacity") else 90
	return current + pending + amount <= capacity

func _add_to_shop_stock(product_id: int, amount: int) -> void:
	var stock: Array[int] = shop.get("stock")
	stock[product_id] += amount
	shop.set("stock", stock)
	var shelf := shop.get_node_or_null("ProductShelf_%d" % product_id)
	if shelf != null and shop.has_method("_update_shelf_products"):
		shop.call("_update_shelf_products", shelf, product_id)

func _payroll_tick() -> void:
	if manager == null:
		return
	var total_due := 0
	for factory in factories:
		if not bool(factory.get("built", false)):
			continue
		total_due += int(factory.get("workers", 0)) * WORKER_SALARY
	if total_due <= 0:
		return
	var balance := int(manager.get("cash"))
	if balance < total_due:
		status_label.text = "Фабрики: не хватает денег на зарплату %d" % total_due
		return
	manager.set("cash", balance - total_due)
	total_payroll += total_due
	_save_economy()
	_save_state()
	_refresh_ui()

func _check_inactive_reason(factory_id: int) -> String:
	if not bool(factories[factory_id].get("active", true)):
		return "смена остановлена"
	if int(factories[factory_id].get("workers", 0)) <= 0:
		return "нет работников"
	for raw_id in range(RAW_NAMES.size()):
		if raw_stock[raw_id] < int(RAW_PER_BATCH[factory_id][raw_id]):
			return "не хватает: " + RAW_NAMES[raw_id]
	return "готова к производству"

func _is_factory_built(factory_id: int) -> bool:
	return factory_id >= 0 and factory_id < factories.size() and bool(factories[factory_id].get("built", false))

func _refresh_ui() -> void:
	if summary_label == null:
		return
	var active_count := 0
	var built_count := 0
	for i in range(factories.size()):
		if _is_factory_built(i):
			built_count += 1
			if bool(factories[i].get("active", true)):
				active_count += 1
	summary_label.text = "Фабрики: %d/3 • смены: %d\nВыпущено: %d шт. • партий: %d\nРасходы на сырьё: %d • зарплаты: %d" % [built_count, active_count, total_units_produced, total_batches, total_raw_spent, total_payroll]
	raw_label.text = "Сырьё: " + " • ".join(PackedStringArray([
		"%s %d" % [RAW_NAMES[0], raw_stock[0]],
		"%s %d" % [RAW_NAMES[1], raw_stock[1]],
		"%s %d" % [RAW_NAMES[2], raw_stock[2]],
		"%s %d" % [RAW_NAMES[3], raw_stock[3]]
	]))
	for i in range(RAW_NAMES.size()):
		var live_price := int(market.call("get_raw_price", i)) if market != null and market.has_method("get_raw_price") else RAW_PRICES[i]
		raw_buttons[i].text = "Купить %s +20 — %d" % [RAW_NAMES[i], live_price * 20]
	for i in range(factories.size()):
		var factory: Dictionary = factories[i]
		var built := bool(factory.get("built", false))
		if built:
			factory_labels[i].text = "Уровень %d • работников %d/%d\nВыпущено: %d • неудачных смен: %d\nСостояние: %s" % [
				int(factory.get("level", 1)), int(factory.get("workers", 0)), MAX_WORKERS,
				int(factory.get("produced", 0)), int(factory.get("failed_shifts", 0)), _check_inactive_reason(i)
			]
			build_buttons[i].text = "%s построена" % FACTORY_NAMES[i]
			build_buttons[i].disabled = true
			upgrade_buttons[i].text = "Уровень +1 · %d" % (UPGRADE_COSTS[i] * int(factory.get("level", 1)))
			upgrade_buttons[i].disabled = false
			worker_buttons[i].text = "Работник +1 · %d" % WORKER_COST
			worker_buttons[i].disabled = int(factory.get("workers", 0)) >= MAX_WORKERS
			shift_buttons[i].text = "Остановить смену" if bool(factory.get("active", true)) else "Запустить смену"
		else:
			factory_labels[i].text = "Не построена • рецепт: " + _recipe_text(i)
			build_buttons[i].text = "Построить · %d" % BUILD_COSTS[i]
			build_buttons[i].disabled = false
			upgrade_buttons[i].text = "Улучшение недоступно"
			upgrade_buttons[i].disabled = true
			worker_buttons[i].text = "Найм недоступен"
			worker_buttons[i].disabled = true
			shift_buttons[i].text = "Сначала постройте фабрику"
			shift_buttons[i].disabled = true

func _recipe_text(factory_id: int) -> String:
	var parts: Array[String] = []
	for raw_id in range(RAW_NAMES.size()):
		var amount := int(RAW_PER_BATCH[factory_id][raw_id])
		if amount > 0:
			parts.append("%s ×%d" % [RAW_NAMES[raw_id], amount])
	return ", ".join(PackedStringArray(parts))

func _refresh_shop() -> void:
	if shop != null and shop.has_method("_save_shop_state"):
		shop.call("_save_shop_state")
		shop.call("_refresh_shop_ui")
		if manager != null:
			manager.call("_save_game")
			manager.call("_refresh_ui")

func _save_economy() -> void:
	if manager != null:
		manager.call("_save_game")
		manager.call("_refresh_ui")

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("production", "raw_stock", raw_stock)
	config.set_value("production", "total_batches", total_batches)
	config.set_value("production", "total_units", total_units_produced)
	config.set_value("production", "raw_spent", total_raw_spent)
	config.set_value("production", "payroll", total_payroll)
	config.set_value("production", "factory_revenue", total_factory_revenue)
	config.set_value("production", "factories", factories)
	config.save("user://production_state.cfg")

func _load_state() -> void:
	factories = [
		{"built": false, "level": 1, "workers": 0, "active": false, "batches": 0, "produced": 0, "failed_shifts": 0},
		{"built": false, "level": 1, "workers": 0, "active": false, "batches": 0, "produced": 0, "failed_shifts": 0},
		{"built": false, "level": 1, "workers": 0, "active": false, "batches": 0, "produced": 0, "failed_shifts": 0}
	]
	var config := ConfigFile.new()
	if config.load("user://production_state.cfg") != OK:
		return
	var saved_raw: Variant = config.get_value("production", "raw_stock", raw_stock)
	if saved_raw is Array and saved_raw.size() == raw_stock.size():
		for i in range(raw_stock.size()):
			raw_stock[i] = maxi(0, int(saved_raw[i]))
	total_batches = maxi(0, int(config.get_value("production", "total_batches", 0)))
	total_units_produced = maxi(0, int(config.get_value("production", "total_units", 0)))
	total_raw_spent = maxi(0, int(config.get_value("production", "raw_spent", 0)))
	total_payroll = maxi(0, int(config.get_value("production", "payroll", 0)))
	total_factory_revenue = maxi(0, int(config.get_value("production", "factory_revenue", 0)))
	var saved_factories: Variant = config.get_value("production", "factories", factories)
	if saved_factories is Array and saved_factories.size() == factories.size():
		for i in range(factories.size()):
			if saved_factories[i] is Dictionary:
				factories[i] = saved_factories[i]

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
	material.roughness = 0.8
	return material
