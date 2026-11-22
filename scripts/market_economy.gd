extends Node3D

# MINI WORLD TYCOON — District market, commodity exchange and wholesale contracts.
const RAW_NAMES: Array[String] = ["Зерно", "Фрукты", "Упаковка", "Электроэнергия"]
const BASE_RAW_PRICES: Array[int] = [8, 11, 6, 5]
const PRODUCT_NAMES: Array[String] = ["Хлеб", "Напитки", "Снэки"]
const WHOLESALE_BASE: Array[int] = [17, 24, 34]
const DISTRICTS: Array[String] = ["Центр", "Северный район", "Южный район"]
const SAVE_PATH := "user://district_market.cfg"

var manager: Node
var shop: Node
var production: Node
var raw_multipliers: Array[float] = [1.0, 1.0, 1.0, 1.0]
var district_demand: Array[float] = [1.0, 0.92, 1.08]
var market_event := "Обычный рынок"
var market_event_time := 0.0
var market_cycle := 0
var wholesale_units := 0
var wholesale_revenue := 0
var price_history: Array[Array] = [[], [], [], []]
var panel: PanelContainer
var summary_label: Label
var prices_label: Label
var district_label: Label
var event_label: Label
var status_label: Label
var sell_buttons: Array[Button] = []
var timer: Timer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	shop = get_parent().get_node_or_null("StoreGameplay")
	production = get_parent().get_node_or_null("ProductionSystem")
	_load_state()
	_create_panel()
	_start_market_clock()
	_refresh_ui()

func get_raw_price(raw_id: int) -> int:
	if raw_id < 0 or raw_id >= BASE_RAW_PRICES.size():
		return 1
	return maxi(1, roundi(float(BASE_RAW_PRICES[raw_id]) * raw_multipliers[raw_id]))

func get_retail_multiplier(product_id: int) -> float:
	if product_id < 0 or product_id >= PRODUCT_NAMES.size():
		return 1.0
	var district_average := (district_demand[0] + district_demand[1] + district_demand[2]) / 3.0
	return clampf(district_average * (0.96 + raw_multipliers[mini(product_id, 3)] * 0.04), 0.75, 1.3)

func get_district_demand(district_id: int) -> float:
	if district_id < 0 or district_id >= district_demand.size():
		return 1.0
	return district_demand[district_id]

func _start_market_clock() -> void:
	timer = Timer.new()
	timer.wait_time = 45.0
	timer.autostart = true
	timer.timeout.connect(_market_tick)
	add_child(timer)

func _market_tick() -> void:
	market_cycle += 1
	for i in range(raw_multipliers.size()):
		raw_multipliers[i] = clampf(raw_multipliers[i] + rng.randf_range(-0.12, 0.12), 0.68, 1.55)
	for i in range(district_demand.size()):
		district_demand[i] = clampf(district_demand[i] + rng.randf_range(-0.08, 0.08), 0.65, 1.4)
	market_event_time = maxf(0.0, market_event_time - 45.0)
	if market_event_time <= 0.0:
		_start_market_event()
	for i in range(price_history.size()):
		price_history[i].append(get_raw_price(i))
		if price_history[i].size() > 12:
			price_history[i].pop_front()
	_save_state()
	_refresh_ui()

func _start_market_event() -> void:
	var event_id := rng.randi_range(0, 4)
	match event_id:
		0:
			market_event = "Урожайный сезон: зерно дешевле"
			raw_multipliers[0] = maxf(0.68, raw_multipliers[0] - 0.22)
		1:
			market_event = "Неурожай фруктов: цены выросли"
			raw_multipliers[1] = minf(1.55, raw_multipliers[1] + 0.28)
		2:
			market_event = "Дефицит упаковки"
			raw_multipliers[2] = minf(1.55, raw_multipliers[2] + 0.3)
		3:
			market_event = "Энергетический пик"
			raw_multipliers[3] = minf(1.55, raw_multipliers[3] + 0.32)
		_:
			market_event = "Городская ярмарка: высокий спрос"
			for i in range(district_demand.size()):
				district_demand[i] = minf(1.4, district_demand[i] + 0.16)
	market_event_time = 90.0

func _create_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DistrictMarketHUD"
	layer.layer = 9
	layer.add_to_group("city_dashboard_panels")
	layer.visible = false
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(650, 370)
	panel.custom_minimum_size = Vector2(340, 330)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var title := Label.new()
	title.text = "📈 РЫНОК И РАЙОНЫ"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary_label)
	event_label = Label.new()
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(event_label)
	prices_label = Label.new()
	prices_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(prices_label)
	district_label = Label.new()
	district_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(district_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	for i in range(PRODUCT_NAMES.size()):
		var button := Button.new()
		button.pressed.connect(_sell_wholesale.bind(i))
		content.add_child(button)
		sell_buttons.append(button)

func _sell_wholesale(product_id: int) -> void:
	if shop == null or manager == null or product_id < 0 or product_id >= PRODUCT_NAMES.size():
		return
	var stock: Array[int] = shop.get("stock")
	var amount := mini(10, stock[product_id])
	if amount <= 0:
		status_label.text = "Нет товара для оптовой продажи"
		return
	var demand_factor := (district_demand[0] + district_demand[1] + district_demand[2]) / 3.0
	var unit_price := maxi(1, roundi(float(WHOLESALE_BASE[product_id]) * demand_factor))
	var revenue := unit_price * amount
	stock[product_id] -= amount
	shop.set("stock", stock)
	wholesale_units += amount
	wholesale_revenue += revenue
	manager.set("cash", int(manager.get("cash")) + revenue)
	var shelf := shop.get_node_or_null("ProductShelf_%d" % product_id)
	if shelf != null and shop.has_method("_update_shelf_products"):
		shop.call("_update_shelf_products", shelf, product_id)
	if shop.has_method("_save_shop_state"):
		shop.call("_save_shop_state")
		shop.call("_refresh_shop_ui")
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_save_state()
	status_label.text = "Оптовый контракт выполнен: %s ×%d за %d монет" % [PRODUCT_NAMES[product_id], amount, revenue]
	_refresh_ui()

func _refresh_ui() -> void:
	if summary_label == null:
		return
	summary_label.text = "Рыночный цикл: %d • оптом продано: %d шт.\nДоход от контрактов: %d монет" % [market_cycle, wholesale_units, wholesale_revenue]
	event_label.text = "Событие: %s (%.0f сек.)" % [market_event, market_event_time]
	var raw_lines: Array[String] = []
	for i in range(RAW_NAMES.size()):
		raw_lines.append("%s: %d мон." % [RAW_NAMES[i], get_raw_price(i)])
	prices_label.text = "Оптовые цены сырья:\n" + "\n".join(PackedStringArray(raw_lines))
	var district_lines: Array[String] = []
	for i in range(DISTRICTS.size()):
		district_lines.append("%s: спрос %d%%" % [DISTRICTS[i], roundi(district_demand[i] * 100.0)])
	district_label.text = "Спрос по районам:\n" + "\n".join(PackedStringArray(district_lines))
	var shop_stock: Array[int] = shop.get("stock") if shop != null else []
	for i in range(sell_buttons.size()):
		var available := int(shop_stock[i]) if i < shop_stock.size() else 0
		sell_buttons[i].text = "Продать оптом %s · до 10 шт." % PRODUCT_NAMES[i]
		sell_buttons[i].disabled = available <= 0 or manager == null

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("market", "raw_multipliers", raw_multipliers)
	config.set_value("market", "district_demand", district_demand)
	config.set_value("market", "event", market_event)
	config.set_value("market", "event_time", market_event_time)
	config.set_value("market", "cycle", market_cycle)
	config.set_value("market", "wholesale_units", wholesale_units)
	config.set_value("market", "wholesale_revenue", wholesale_revenue)
	config.set_value("market", "price_history", price_history)
	config.save(SAVE_PATH)

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var saved_prices: Variant = config.get_value("market", "raw_multipliers", raw_multipliers)
	if saved_prices is Array and saved_prices.size() == raw_multipliers.size():
		for i in range(raw_multipliers.size()):
			raw_multipliers[i] = clampf(float(saved_prices[i]), 0.68, 1.55)
	var saved_demand: Variant = config.get_value("market", "district_demand", district_demand)
	if saved_demand is Array and saved_demand.size() == district_demand.size():
		for i in range(district_demand.size()):
			district_demand[i] = clampf(float(saved_demand[i]), 0.65, 1.4)
	market_event = String(config.get_value("market", "event", market_event))
	market_event_time = maxf(0.0, float(config.get_value("market", "event_time", 0.0)))
	market_cycle = maxi(0, int(config.get_value("market", "cycle", 0)))
	wholesale_units = maxi(0, int(config.get_value("market", "wholesale_units", 0)))
	wholesale_revenue = maxi(0, int(config.get_value("market", "wholesale_revenue", 0)))
	var saved_history: Variant = config.get_value("market", "price_history", price_history)
	if saved_history is Array and saved_history.size() == price_history.size():
		for i in range(price_history.size()):
			if saved_history[i] is Array:
				price_history[i] = saved_history[i]

