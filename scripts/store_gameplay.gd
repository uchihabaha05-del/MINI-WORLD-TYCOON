extends Node3D

# MINI WORLD TYCOON — Milestone 6: stocked shelves and automatic retail sales.
const PRODUCTS := [
	{"name": "Хлеб", "buy": 12, "sell": 22, "color": Color("#d7a45f")},
	{"name": "Напитки", "buy": 18, "sell": 32, "color": Color("#63a9d1")},
	{"name": "Снэки", "buy": 25, "sell": 45, "color": Color("#d77d68")}
]
const RESTOCK_AMOUNT := 5
const SALES_INTERVAL := 5.0

var manager: Node
var stock: Array[int] = [5, 5, 5]
var stock_labels: Array[Label] = []
var sales_label: Label
var total_sales := 0
var total_profit := 0
var sales_timer: Timer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	_build_shelves()
	_create_shop_interface()
	_start_sales_timer()
	_refresh_shop_ui()

func _build_shelves() -> void:
	for i in range(PRODUCTS.size()):
		var x := -21.0 + float(i) * 6.0
		var shelf := Node3D.new()
		shelf.name = "ProductShelf_%d" % i
		shelf.position = Vector3(x, 0.0, -7.0)
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

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -300
	panel.offset_right = -14
	panel.offset_top = 14
	panel.offset_bottom = 250
	layer.add_child(panel)

	var content := VBoxContainer.new()
	panel.add_child(content)

	var title := Label.new()
	title.text = "🏪 MINI MARKET"
	title.add_theme_font_size_override("font_size", 21)
	content.add_child(title)

	sales_label = Label.new()
	sales_label.text = "Продажи: 0  •  Прибыль: 0"
	content.add_child(sales_label)

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

func _restock_product(product_id: int) -> void:
	if manager == null:
		return
	var cost := int(PRODUCTS[product_id]["buy"]) * RESTOCK_AMOUNT
	if int(manager.get("cash")) < cost:
		return
	manager.set("cash", int(manager.get("cash")) - cost)
	stock[product_id] += RESTOCK_AMOUNT
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_refresh_shop_ui()
	var shelf := get_node_or_null("ProductShelf_%d" % product_id) as Node3D
	if shelf:
		_update_shelf_products(shelf, product_id)

func _start_sales_timer() -> void:
	sales_timer = Timer.new()
	sales_timer.wait_time = SALES_INTERVAL
	sales_timer.autostart = true
	sales_timer.timeout.connect(_process_customer_purchase)
	add_child(sales_timer)

func _process_customer_purchase() -> void:
	var available: Array[int] = []
	for i in range(stock.size()):
		if stock[i] > 0:
			available.append(i)
	if available.is_empty() or manager == null:
		return

	var product_id: int = available[rng.randi_range(0, available.size() - 1)]
	stock[product_id] -= 1
	var sale := int(PRODUCTS[product_id]["sell"])
	var cost := int(PRODUCTS[product_id]["buy"])
	manager.set("cash", int(manager.get("cash")) + sale)
	total_sales += 1
	total_profit += sale - cost
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_refresh_shop_ui()
	var shelf := get_node_or_null("ProductShelf_%d" % product_id) as Node3D
	if shelf:
		_update_shelf_products(shelf, product_id)

func _refresh_shop_ui() -> void:
	for i in range(stock_labels.size()):
		stock_labels[i].text = "%s: %d шт." % [PRODUCTS[i]["name"], stock[i]]
	sales_label.text = "Продажи: %d  •  Прибыль: %d" % [total_sales, total_profit]

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
