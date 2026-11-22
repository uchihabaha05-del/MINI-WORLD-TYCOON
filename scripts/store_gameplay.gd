extends Node3D

# MINI WORLD TYCOON — Milestone 31: contextual shop management interaction.
const PRODUCTS := [
	{"name": "Хлеб", "buy": 12, "sell": 22, "color": Color("#d7a45f")},
	{"name": "Напитки", "buy": 18, "sell": 32, "color": Color("#63a9d1")},
	{"name": "Снэки", "buy": 25, "sell": 45, "color": Color("#d77d68")}
]
const RESTOCK_AMOUNT := 5
const EMPLOYEE_HIRE_COST := 350
const EMPLOYEE_SALARY := 15
const PAYROLL_INTERVAL := 10.0
const AUTO_RESTOCK_INTERVAL := 12.0
const AUTO_RESTOCK_THRESHOLD := 2
const DELIVERY_AMOUNT := 15
const DELIVERY_TRAVEL_TIME := 5.0

var manager: Node
var stock: Array[int] = [5, 5, 5]
var stock_labels: Array[Label] = []
var sales_label: Label
var total_sales := 0
var total_profit := 0
var rng := RandomNumberGenerator.new()
var employee_hired := false
var employee_label: Label
var hire_button: Button
var payroll_timer: Timer
var auto_restock_timer: Timer
var payroll_paid_total := 0
var auto_restocked_total := 0
var delivery_pending: Array[bool] = [false, false, false]
var delivery_label: Label
var city_life: Node
var city_event_multiplier: float = 1.0
var shop_panel: PanelContainer

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	city_life = get_parent().get_node_or_null("CityPopulation")
	_load_shop_state()
	_build_shelves()
	_create_shop_interface()
	_start_staff_system()
	_refresh_shop_ui()

func _build_shelves() -> void:
	for i in range(PRODUCTS.size()):
		var x := -21.0 + float(i) * 6.0
		var shelf := Node3D.new()
		shelf.name = "ProductShelf_%d" % i
		shelf.position = Vector3(x, 0.0, -14.0)
		add_child(shelf)

		var base := MeshInstance3D.new()
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(4.4, 0.18, 1.1)
		base.mesh = base_mesh
		base.position.y = 0.85
		base.material_override = _mat(Color("#805b3e"))
		shelf.add_child(base)

		for side in [-1.0, 1.0]:
			var support := MeshInstance3D.new()
			var support_mesh := BoxMesh.new()
			support_mesh.size = Vector3(0.14, 1.7, 1.0)
			support.mesh = support_mesh
			support.position = Vector3(side * 2.05, 0.85, 0)
			support.material_override = _mat(Color("#6b503b"))
			shelf.add_child(support)

		var label := Label3D.new()
		label.text = String(PRODUCTS[i]["name"])
		label.font_size = 30
		label.pixel_size = 0.012
		label.position = Vector3(0, 1.9, 0.58)
		label.modulate = Color.WHITE
		shelf.add_child(label)
		_update_shelf_products(shelf, i)
	_build_checkout_area()

func _update_shelf_products(shelf: Node3D, product_id: int) -> void:
	for child in shelf.get_children():
		if child.name.begins_with("ProductItem"):
			child.queue_free()
	var count := mini(stock[product_id], 10)
	var product_color: Color = PRODUCTS[product_id]["color"]
	for i in range(count):
		var item := MeshInstance3D.new()
		item.name = "ProductItem_%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.42, 0.48, 0.42)
		item.mesh = mesh
		item.position = Vector3(-1.65 + float(i % 5) * 0.8, 1.2 + float(i / 5) * 0.5, 0)
		item.material_override = _mat(product_color)
		shelf.add_child(item)

func _create_shop_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ShopManagementHUD"
	layer.layer = 6
	add_child(layer)

	shop_panel = PanelContainer.new()
	shop_panel.anchor_left = 1.0
	shop_panel.anchor_right = 1.0
	shop_panel.offset_left = -300
	shop_panel.offset_right = -14
	shop_panel.offset_top = 14
	shop_panel.offset_bottom = -14
	shop_panel.visible = false
	layer.add_child(shop_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var title := Label.new()
	title.text = "🏪 MINI MARKET"
	title.add_theme_font_size_override("font_size", 21)
	content.add_child(title)

	sales_label = Label.new()
	sales_label.text = "Продажи: 0  •  Прибыль: 0"
	content.add_child(sales_label)
	delivery_label = Label.new()
	delivery_label.text = "Поставки: готовы к заказу"
	content.add_child(delivery_label)

	employee_label = Label.new()
	content.add_child(employee_label)
	hire_button = Button.new()
	hire_button.pressed.connect(_hire_employee)
	content.add_child(hire_button)

	for i in range(PRODUCTS.size()):
		var row := HBoxContainer.new()
		content.add_child(row)
		var info := Label.new()
		info.custom_minimum_size = Vector2(112, 0)
		info.text = "%s: %d шт." % [PRODUCTS[i]["name"], stock[i]]
		row.add_child(info)
		stock_labels.append(info)
		var button := Button.new()
		button.text = "+5 · %d" % (int(PRODUCTS[i]["buy"]) * RESTOCK_AMOUNT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_restock_product.bind(i))
		row.add_child(button)
		var delivery_button := Button.new()
		delivery_button.text = "Доставка +15"
		delivery_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		delivery_button.pressed.connect(_order_delivery.bind(i))
		row.add_child(delivery_button)

func _restock_product(product_id: int) -> void:
	if manager == null:
		return
	var cost := int(PRODUCTS[product_id]["buy"]) * RESTOCK_AMOUNT
	if int(manager.get("cash")) < cost:
		return
	manager.set("cash", int(manager.get("cash")) - cost)
	stock[product_id] += RESTOCK_AMOUNT
	_save_shop_state()
	manager.call("_save_game")
	manager.call("_check_quests")
	manager.call("_refresh_ui")
	_refresh_shop_ui()
	var shelf := get_node_or_null("ProductShelf_%d" % product_id) as Node3D
	if shelf:
		_update_shelf_products(shelf, product_id)


func _order_delivery(product_id: int) -> void:
	if manager == null or product_id < 0 or product_id >= PRODUCTS.size():
		return
	if delivery_pending[product_id]:
		delivery_label.text = "Эта поставка уже в пути"
		return
	var cost := int(PRODUCTS[product_id]["buy"]) * DELIVERY_AMOUNT
	if int(manager.get("cash")) < cost:
		delivery_label.text = "Недостаточно монет для заказа"
		return
	manager.set("cash", int(manager.get("cash")) - cost)
	delivery_pending[product_id] = true
	delivery_label.text = "Грузовик в пути: %s (+%d)" % [PRODUCTS[product_id]["name"], DELIVERY_AMOUNT]
	manager.call("_save_game")
	manager.call("_refresh_ui")
	var truck := _create_delivery_truck()
	var tween := create_tween()
	tween.tween_property(truck, "position", Vector3(-17.0, 0.0, -22.0), DELIVERY_TRAVEL_TIME)
	tween.tween_interval(0.8)
	tween.tween_callback(_complete_delivery.bind(product_id, truck))

func _create_delivery_truck() -> Node3D:
	var truck := Node3D.new()
	truck.name = "SupplierTruck"
	truck.position = Vector3(-29.0, 0.0, -22.0)
	add_child(truck)
	_box_for_parent(truck, Vector3(4.2, 1.5, 2.0), Vector3.ZERO, Color("#d9e4e8"), "TruckCargo")
	_box_for_parent(truck, Vector3(1.5, 1.2, 1.9), Vector3(2.6, 0.0, 0.0), Color("#4b83a5"), "TruckCab")
	for x in [-1.2, 2.5]:
		for z in [-1.05, 1.05]:
			var wheel := MeshInstance3D.new()
			wheel.name = "TruckWheel"
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.38
			mesh.bottom_radius = 0.38
			mesh.height = 0.18
			wheel.mesh = mesh
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, -0.55, z)
			wheel.material_override = _mat(Color("#26323a"))
			truck.add_child(wheel)
	return truck

func _box_for_parent(parent: Node3D, size: Vector3, pos: Vector3, color: Color, node_name: String) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos + Vector3(0, 0.75, 0)
	part.material_override = _mat(color)
	parent.add_child(part)

func _complete_delivery(product_id: int, truck: Node3D) -> void:
	if product_id >= 0 and product_id < stock.size():
		stock[product_id] += DELIVERY_AMOUNT
		delivery_pending[product_id] = false
		var shelf := get_node_or_null("ProductShelf_%d" % product_id) as Node3D
		if shelf:
			_update_shelf_products(shelf, product_id)
		_save_shop_state()
		_refresh_shop_ui()
		delivery_label.text = "Доставлено: %s (+%d шт.)" % [PRODUCTS[product_id]["name"], DELIVERY_AMOUNT]
	if is_instance_valid(truck):
		var tween := create_tween()
		tween.tween_property(truck, "position", Vector3(-29.0, 0.0, -22.0), DELIVERY_TRAVEL_TIME)
		tween.tween_callback(truck.queue_free)

func _build_checkout_area() -> void:
	# Checkout counter inside the shop, facing the entrance.
	_box(Vector3(5.0, 1.05, 1.25), Vector3(-15.0, 0.55, -10.4), Color("#76513b"), "CheckoutCounter")
	_box(Vector3(4.8, 0.12, 1.15), Vector3(-15.0, 1.12, -10.4), Color("#d6b98c"), "CheckoutTop")
	_box(Vector3(1.0, 0.65, 0.65), Vector3(-15.0, 1.48, -10.2), Color("#303b43"), "CashRegister")
	# A simple cashier character behind the counter.
	var cashier := Node3D.new()
	cashier.name = "Cashier"
	cashier.position = Vector3(-15.0, 0.0, -12.0)
	add_child(cashier)
	_capsule(cashier, Vector3(0, 0.85, 0), 0.34, 1.5, Color("#315f86"))
	_sphere(cashier, Vector3(0, 1.75, 0), 0.23, Color("#e8b995"))
	var cashier_tag := Label3D.new()
	cashier_tag.text = "КАССИР"
	cashier_tag.font_size = 24
	cashier_tag.pixel_size = 0.01
	cashier_tag.position = Vector3(0, 2.2, 0)
	cashier.add_child(cashier_tag)
	# Queue markers outside the entrance.
	for i in range(3):
		var marker := MeshInstance3D.new()
		marker.name = "QueueMarker_%d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.22
		mesh.bottom_radius = 0.22
		mesh.height = 0.035
		marker.mesh = mesh
		marker.position = Vector3(-15.0 + float(i - 1) * 1.1, 0.12, -6.2)
		marker.material_override = _mat(Color("#e8c75b"))
		add_child(marker)

func set_city_event_multiplier(value: float) -> void:
	city_event_multiplier = clampf(value, 1.0, 2.0)
	if sales_label != null:
		sales_label.text = "Городское событие: бонус продаж x%.2f" % city_event_multiplier if city_event_multiplier > 1.0 else "Продажи магазина"

func toggle_shop_panel() -> void:
	if shop_panel != null:
		shop_panel.visible = not shop_panel.visible

func serve_customer(wanted_product: int = -1) -> bool:
	if manager == null:
		return false
	var product_id := wanted_product
	if product_id < 0 or product_id >= stock.size():
		var available: Array[int] = []
		for i in range(stock.size()):
			if stock[i] > 0:
				available.append(i)
		if available.is_empty():
			sales_label.text = "Покупатель ушёл: все полки пустые"
			return false
		product_id = available[rng.randi_range(0, available.size() - 1)]
	if stock[product_id] <= 0:
		sales_label.text = "Покупатель ушёл: закончился товар «%s»" % PRODUCTS[product_id]["name"]
		return false
	stock[product_id] -= 1
	var base_sale := int(PRODUCTS[product_id]["sell"])
	var demand_bonus := int(city_life.call("get_demand_bonus")) if city_life and city_life.has_method("get_demand_bonus") else 0
	var shop_demand_factor := float(city_life.call("get_business_demand_multiplier", "Магазин")) if city_life and city_life.has_method("get_business_demand_multiplier") else 1.0
	var sale := int(round(float(base_sale + demand_bonus) * city_event_multiplier * shop_demand_factor))
	var cost := int(PRODUCTS[product_id]["buy"])
	manager.set("cash", int(manager.get("cash")) + sale)
	total_sales += 1
	total_profit += sale - cost
	_save_shop_state()
	manager.call("_save_game")
	manager.call("_check_quests")
	manager.call("_refresh_ui")
	_refresh_shop_ui()
	var shelf := get_node_or_null("ProductShelf_%d" % product_id) as Node3D
	if shelf:
		_update_shelf_products(shelf, product_id)
	return true


func _hire_employee() -> void:
	if employee_hired or manager == null:
		return
	if int(manager.get("cash")) < EMPLOYEE_HIRE_COST:
		employee_label.text = "Недостаточно монет для найма"
		return
	manager.set("cash", int(manager.get("cash")) - EMPLOYEE_HIRE_COST)
	employee_hired = true
	_save_shop_state()
	manager.call("_save_game")
	manager.call("_check_quests")
	manager.call("_refresh_ui")
	_refresh_shop_ui()

func _start_staff_system() -> void:
	payroll_timer = Timer.new()
	payroll_timer.wait_time = PAYROLL_INTERVAL
	payroll_timer.autostart = true
	payroll_timer.timeout.connect(_payroll_tick)
	add_child(payroll_timer)
	auto_restock_timer = Timer.new()
	auto_restock_timer.wait_time = AUTO_RESTOCK_INTERVAL
	auto_restock_timer.autostart = true
	auto_restock_timer.timeout.connect(_auto_restock_tick)
	add_child(auto_restock_timer)

func _payroll_tick() -> void:
	if not employee_hired or manager == null:
		return
	var balance := int(manager.get("cash"))
	if balance < EMPLOYEE_SALARY:
		employee_label.text = "Сотрудник ожидает зарплату: %d" % EMPLOYEE_SALARY
		return
	manager.set("cash", balance - EMPLOYEE_SALARY)
	payroll_paid_total += EMPLOYEE_SALARY
	_save_shop_state()
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_refresh_shop_ui()

func _auto_restock_tick() -> void:
	if not employee_hired or manager == null:
		return
	var balance := int(manager.get("cash"))
	for i in range(stock.size()):
		if stock[i] < AUTO_RESTOCK_THRESHOLD:
			var unit_cost := int(PRODUCTS[i]["buy"])
			if balance >= unit_cost:
				balance -= unit_cost
				stock[i] += 1
				auto_restocked_total += 1
				var shelf := get_node_or_null("ProductShelf_%d" % i) as Node3D
				if shelf:
					_update_shelf_products(shelf, i)
	manager.set("cash", balance)
	_save_shop_state()
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_refresh_shop_ui()

func _save_shop_state() -> void:
	var config := ConfigFile.new()
	config.set_value("staff", "employee_hired", employee_hired)
	config.set_value("staff", "payroll_paid_total", payroll_paid_total)
	config.set_value("staff", "auto_restocked_total", auto_restocked_total)
	config.set_value("sales", "total_sales", total_sales)
	config.set_value("sales", "total_profit", total_profit)
	for i in range(stock.size()):
		config.set_value("inventory", "stock_%d" % i, stock[i])
	config.save("user://shop_state.cfg")

func _load_shop_state() -> void:
	var config := ConfigFile.new()
	if config.load("user://shop_state.cfg") != OK:
		return
	employee_hired = bool(config.get_value("staff", "employee_hired", false))
	payroll_paid_total = int(config.get_value("staff", "payroll_paid_total", 0))
	auto_restocked_total = int(config.get_value("staff", "auto_restocked_total", 0))
	total_sales = int(config.get_value("sales", "total_sales", 0))
	total_profit = int(config.get_value("sales", "total_profit", 0))
	for i in range(stock.size()):
		stock[i] = maxi(0, int(config.get_value("inventory", "stock_%d" % i, stock[i])))

func _box(size: Vector3, pos: Vector3, color: Color, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _mat(color)
	add_child(instance)

func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _mat(color)
	parent.add_child(instance)

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _mat(color)
	parent.add_child(instance)

func _refresh_shop_ui() -> void:
	for i in range(stock_labels.size()):
		stock_labels[i].text = "%s: %d шт." % [PRODUCTS[i]["name"], stock[i]]
	var demand := int(city_life.call("get_business_demand", "Магазин")) if city_life and city_life.has_method("get_business_demand") else 55
	sales_label.text = "Продажи: %d  •  Прибыль: %d\\nСпрос на магазин: %d/100" % [total_sales, total_profit, demand]
	if employee_hired:
		employee_label.text = "Сотрудник нанят • зарплата %d / 10 сек. • пополнено: %d" % [EMPLOYEE_SALARY, auto_restocked_total]
		hire_button.text = "Сотрудник работает"
		hire_button.disabled = true
	else:
		employee_label.text = "Персонал: нет • найм: %d монет" % EMPLOYEE_HIRE_COST
		hire_button.text = "Нанять сотрудника — %d" % EMPLOYEE_HIRE_COST
		hire_button.disabled = manager == null or int(manager.get("cash")) < EMPLOYEE_HIRE_COST

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
