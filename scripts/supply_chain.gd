extends Node3D

# MINI WORLD TYCOON — Supply & Logistics milestone.
# Wholesale purchasing, warehouse capacity, supplier contracts and delivery fleet.
const PRODUCT_NAMES: Array[String] = ["Хлеб", "Напитки", "Снэки"]
const UNIT_COSTS: Array[int] = [12, 18, 25]
const BULK_AMOUNT := 20
const BASE_CAPACITY := 90
const CAPACITY_UPGRADE_COST := 650
const AUTO_ORDER_INTERVAL := 18.0
const LOW_STOCK_LEVEL := 5
const DELIVERY_BASE_TIME := 9.0
const DELIVERY_FEE := 18
const CONTRACT_SALES_STEP := 10

var manager: Node
var shop: Node
var panel: PanelContainer
var summary_label: Label
var status_label: Label
var auto_button: Button
var upgrade_button: Button
var order_buttons: Array[Button] = []
var auto_timer: Timer
var delivery_timer: Timer
var auto_order_enabled := false
var warehouse_level := 1
var supplier_rating := 70
var deliveries_completed := 0
var deliveries_delayed := 0
var units_delivered := 0
var wholesale_spent := 0
var fuel_spent := 0
var contract_rewards := 0
var last_sales_total := 0
var contract_progress := 0
var pending_orders: Array[Dictionary] = []
var warehouse: Node3D
var active_truck: Node3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	shop = get_parent().get_node_or_null("StoreGameplay")
	_load_state()
	_create_warehouse()
	_create_panel()
	_start_logistics()
	if not pending_orders.is_empty():
		_spawn_truck()
	_refresh_ui()

func _process(_delta: float) -> void:
	_check_sales_contract()

func get_warehouse_capacity() -> int:
	return BASE_CAPACITY + (warehouse_level - 1) * 45

func _get_total_stock() -> int:
	if shop == null:
		return 0
	var values: Array = shop.get("stock")
	var total := 0
	for value in values:
		total += int(value)
	return total

func _get_pending_units() -> int:
	var total := 0
	for order in pending_orders:
		total += int(order.get("amount", 0))
	return total

func _create_warehouse() -> void:
	warehouse = Node3D.new()
	warehouse.name = "WholesaleWarehouse"
	warehouse.position = Vector3(-59, 0, -27)
	add_child(warehouse)
	_add_box(warehouse, Vector3(10, 5, 8), Vector3(0, 2.5, 0), Color("#a7b3b8"), "WarehouseBuilding")
	_add_box(warehouse, Vector3(3.2, 2.8, 0.18), Vector3(0, 1.4, 4.08), Color("#526c7b"), "WarehouseDoor")
	_add_box(warehouse, Vector3(10.5, 0.25, 8.5), Vector3(0, 0.12, 0), Color("#646f73"), "WarehouseFoundation")
	for x in [-3.0, 0.0, 3.0]:
		_add_box(warehouse, Vector3(0.22, 3.2, 0.22), Vector3(x, 1.7, -2.6), Color("#5a4635"), "StorageRack")
	var sign := Label3D.new()
	sign.text = "ОПТОВЫЙ СКЛАД"
	sign.font_size = 34
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 5.4, 4.2)
	sign.modulate = Color("#fff2bd")
	warehouse.add_child(sign)

func _create_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SupplyChainHUD"
	layer.layer = 7
	layer.add_to_group("city_dashboard_panels")
	layer.visible = false
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(650, 370)
	panel.custom_minimum_size = Vector2(330, 300)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var title := Label.new()
	title.text = "📦 СКЛАД И ПОСТАВКИ"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	auto_button = Button.new()
	auto_button.pressed.connect(_toggle_auto_order)
	content.add_child(auto_button)
	upgrade_button = Button.new()
	upgrade_button.pressed.connect(_upgrade_warehouse)
	content.add_child(upgrade_button)
	for i in range(PRODUCT_NAMES.size()):
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_order_bulk.bind(i))
		content.add_child(button)
		order_buttons.append(button)
	var contract_label := Label.new()
	contract_label.text = "Контракт: каждые 10 продаж магазина дают бонус поставщика"
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(contract_label)

func _start_logistics() -> void:
	auto_timer = Timer.new()
	auto_timer.wait_time = AUTO_ORDER_INTERVAL
	auto_timer.autostart = true
	auto_timer.timeout.connect(_auto_order_tick)
	add_child(auto_timer)
	delivery_timer = Timer.new()
	delivery_timer.wait_time = 1.0
	delivery_timer.autostart = true
	delivery_timer.timeout.connect(_delivery_tick)
	add_child(delivery_timer)

func _toggle_auto_order() -> void:
	auto_order_enabled = not auto_order_enabled
	_save_state()
	_refresh_ui()

func _upgrade_warehouse() -> void:
	if manager == null or int(manager.get("cash")) < CAPACITY_UPGRADE_COST:
		status_label.text = "Не хватает монет для расширения склада"
		return
	manager.set("cash", int(manager.get("cash")) - CAPACITY_UPGRADE_COST)
	warehouse_level += 1
	_save_economy()
	_save_state()
	_refresh_ui()

func _order_bulk(product_id: int) -> void:
	_place_order(product_id, BULK_AMOUNT, false)

func _auto_order_tick() -> void:
	if not auto_order_enabled or shop == null:
		return
	var stock: Array = shop.get("stock")
	for i in range(stock.size()):
		if int(stock[i]) <= LOW_STOCK_LEVEL and not _has_pending_product(i):
			_place_order(i, BULK_AMOUNT, true)
			break

func _place_order(product_id: int, amount: int, automatic: bool) -> void:
	if manager == null or shop == null or product_id < 0 or product_id >= PRODUCT_NAMES.size():
		return
	if _get_total_stock() + _get_pending_units() + amount > get_warehouse_capacity():
		status_label.text = "Склад заполнен: сначала продайте часть товара или расширьте склад"
		return
	var discount := 1.0 - minf(0.15, float(maxi(0, supplier_rating - 70)) * 0.003)
	var goods_cost := roundi(float(UNIT_COSTS[product_id] * amount) * discount)
	var fuel_cost := DELIVERY_FEE + int(amount / 5)
	var total_cost := goods_cost + fuel_cost
	if int(manager.get("cash")) < total_cost:
		status_label.text = "Не хватает %d монет на оптовый заказ" % (total_cost - int(manager.get("cash")))
		return
	manager.set("cash", int(manager.get("cash")) - total_cost)
	wholesale_spent += goods_cost
	fuel_spent += fuel_cost
	pending_orders.append({
		"product": product_id,
		"amount": amount,
		"remaining": DELIVERY_BASE_TIME + rng.randf_range(0.0, 4.0),
		"delayed": false,
		"automatic": automatic
	})
	_save_economy()
	_save_state()
	status_label.text = "Заказ оформлен: %s × %d. Грузовик отправлен со склада" % [PRODUCT_NAMES[product_id], amount]
	_refresh_ui()
	_spawn_truck()

func _has_pending_product(product_id: int) -> bool:
	for order in pending_orders:
		if int(order.get("product", -1)) == product_id:
			return true
	return false

func _spawn_truck() -> void:
	if is_instance_valid(active_truck):
		return
	active_truck = Node3D.new()
	active_truck.name = "WholesaleDeliveryTruck"
	active_truck.position = Vector3(-59, 0, -18)
	add_child(active_truck)
	_add_box(active_truck, Vector3(3.6, 1.35, 1.8), Vector3(0, 1.0, 0), Color("#e4e9eb"), "Cargo")
	_add_box(active_truck, Vector3(1.25, 1.15, 1.7), Vector3(2.15, 0.9, 0), Color("#497d9b"), "Cab")
	for x in [-1.0, 2.1]:
		for z in [-0.95, 0.95]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.32
			mesh.bottom_radius = 0.32
			mesh.height = 0.14
			wheel.mesh = mesh
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, 0.35, z)
			wheel.material_override = _material(Color("#252b30"))
			active_truck.add_child(wheel)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(active_truck, "position", Vector3(-17, 0, -22), DELIVERY_BASE_TIME)

func _delivery_tick() -> void:
	if pending_orders.is_empty():
		return
	var changed := false
	for i in range(pending_orders.size() - 1, -1, -1):
		var order: Dictionary = pending_orders[i]
		order["remaining"] = float(order.get("remaining", 0.0)) - 1.0
		if not bool(order.get("delayed", false)) and float(order["remaining"]) <= 3.0 and rng.randf() < 0.08:
			order["delayed"] = true
			order["remaining"] = float(order["remaining"]) + 5.0
			deliveries_delayed += 1
			supplier_rating = maxi(35, supplier_rating - 2)
			changed = true
		pending_orders[i] = order
		if float(order["remaining"]) <= 0.0:
			_complete_order(order)
			pending_orders.remove_at(i)
			changed = true
	if pending_orders.is_empty() and is_instance_valid(active_truck):
		active_truck.queue_free()
		active_truck = null
	if changed:
		_save_state()
		_refresh_ui()

func _complete_order(order: Dictionary) -> void:
	var product_id := int(order.get("product", 0))
	var amount := int(order.get("amount", 0))
	if shop == null or product_id < 0 or product_id >= PRODUCT_NAMES.size():
		return
	var stock: Array = shop.get("stock")
	stock[product_id] = int(stock[product_id]) + amount
	shop.set("stock", stock)
	var shelf := shop.get_node_or_null("ProductShelf_%d" % product_id)
	if shelf != null and shop.has_method("_update_shelf_products"):
		shop.call("_update_shelf_products", shelf, product_id)
	deliveries_completed += 1
	units_delivered += amount
	if bool(order.get("delayed", false)):
		supplier_rating = maxi(35, supplier_rating - 1)
		status_label.text = "Поставка прибыла с задержкой: %s +%d" % [PRODUCT_NAMES[product_id], amount]
	else:
		supplier_rating = mini(100, supplier_rating + 1)
		status_label.text = "Поставка доставлена вовремя: %s +%d" % [PRODUCT_NAMES[product_id], amount]
	_save_state()

func _check_sales_contract() -> void:
	if shop == null:
		return
	var current_sales := int(shop.get("total_sales"))
	if current_sales <= last_sales_total:
		return
	var gained := current_sales - last_sales_total
	last_sales_total = current_sales
	contract_progress += gained
	while contract_progress >= CONTRACT_SALES_STEP:
		contract_progress -= CONTRACT_SALES_STEP
		supplier_rating = mini(100, supplier_rating + 1)
		var reward := 30 + warehouse_level * 5
		contract_rewards += reward
		if manager != null:
			manager.set("cash", int(manager.get("cash")) + reward)
		_save_economy()
	_save_state()
	_refresh_ui()

func _refresh_ui() -> void:
	if summary_label == null:
		return
	summary_label.text = "Запас: %d/%d • В пути: %d шт.\nСклад уровень %d • Поставщик: %d/100\nДоставки: %d • задержки: %d • привезено: %d\nОпт: %d • топливо: %d • бонусы: %d" % [
		_get_total_stock(), get_warehouse_capacity(), _get_pending_units(),
		warehouse_level, supplier_rating, deliveries_completed, deliveries_delayed,
		units_delivered, wholesale_spent, fuel_spent, contract_rewards
	]
	auto_button.text = "Автозаказ: ВКЛ" if auto_order_enabled else "Автозаказ: ВЫКЛ"
	upgrade_button.text = "Расширить склад +45 — %d" % CAPACITY_UPGRADE_COST
	upgrade_button.disabled = manager == null or int(manager.get("cash")) < CAPACITY_UPGRADE_COST
	for i in range(order_buttons.size()):
		order_buttons[i].text = "Опт: %s ×%d — %d монет" % [PRODUCT_NAMES[i], BULK_AMOUNT, UNIT_COSTS[i] * BULK_AMOUNT + DELIVERY_FEE + int(BULK_AMOUNT / 5)]
		order_buttons[i].disabled = shop == null or manager == null

func _save_economy() -> void:
	if manager != null:
		manager.call("_save_game")
		manager.call("_refresh_ui")

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("warehouse", "level", warehouse_level)
	config.set_value("warehouse", "auto_order", auto_order_enabled)
	config.set_value("supplier", "rating", supplier_rating)
	config.set_value("supplier", "deliveries_completed", deliveries_completed)
	config.set_value("supplier", "deliveries_delayed", deliveries_delayed)
	config.set_value("supplier", "units_delivered", units_delivered)
	config.set_value("supplier", "wholesale_spent", wholesale_spent)
	config.set_value("supplier", "fuel_spent", fuel_spent)
	config.set_value("supplier", "contract_rewards", contract_rewards)
	config.set_value("contracts", "last_sales", last_sales_total)
	config.set_value("contracts", "progress", contract_progress)
	config.set_value("orders", "pending", pending_orders)
	config.save("user://supply_chain.cfg")

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load("user://supply_chain.cfg") != OK:
		if shop != null:
			last_sales_total = int(shop.get("total_sales"))
		return
	warehouse_level = clampi(int(config.get_value("warehouse", "level", 1)), 1, 10)
	auto_order_enabled = bool(config.get_value("warehouse", "auto_order", false))
	supplier_rating = clampi(int(config.get_value("supplier", "rating", 70)), 35, 100)
	deliveries_completed = maxi(0, int(config.get_value("supplier", "deliveries_completed", 0)))
	deliveries_delayed = maxi(0, int(config.get_value("supplier", "deliveries_delayed", 0)))
	units_delivered = maxi(0, int(config.get_value("supplier", "units_delivered", 0)))
	wholesale_spent = maxi(0, int(config.get_value("supplier", "wholesale_spent", 0)))
	fuel_spent = maxi(0, int(config.get_value("supplier", "fuel_spent", 0)))
	contract_rewards = maxi(0, int(config.get_value("supplier", "contract_rewards", 0)))
	last_sales_total = maxi(0, int(config.get_value("contracts", "last_sales", 0)))
	contract_progress = maxi(0, int(config.get_value("contracts", "progress", 0)))
	var saved_orders: Variant = config.get_value("orders", "pending", [])
	if saved_orders is Array:
		pending_orders = saved_orders

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
