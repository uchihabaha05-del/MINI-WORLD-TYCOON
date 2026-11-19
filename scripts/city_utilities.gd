extends Node3D

# MINI WORLD TYCOON — Milestone 15: utility network and operating costs.
const TICK_SECONDS := 20.0
const ELECTRICITY_BASE := 8
const WATER_BASE := 5
const POWER_PER_BUILDING := 3
const WATER_PER_BUILDING := 2
const CONNECTION_COST := 120

var manager: Node
var timer: Timer
var hud_label: Label
var connected_plots: Array[bool] = []
var electricity_cost := 0
var water_cost := 0
var last_total_cost := 0
var utility_status := "Сети готовы к подключению"

func _ready() -> void:
	manager = get_parent().get_node_or_null("TycoonManager")
	var plot_count := 0
	if manager != null:
		plot_count = (manager.get("plots") as Array).size()
	connected_plots.resize(plot_count)
	for i in range(connected_plots.size()):
		connected_plots[i] = false
	_load_state()
	_create_hud()
	_recalculate_costs()
	_start_timer()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.add_to_group("city_dashboard_panels")
	layer.visible = false
	layer.name = "UtilitiesHUD"
	layer.layer = 5
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.offset_left = 330
	panel.offset_top = 18
	panel.offset_right = 620
	panel.offset_bottom = 190
	layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "🏙 КОММУНАЛЬНЫЕ СЕТИ"
	title.add_theme_font_size_override("font_size", 17)
	content.add_child(title)
	hud_label = Label.new()
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hud_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 76)
	content.add_child(scroll)
	var plot_buttons := VBoxContainer.new()
	scroll.add_child(plot_buttons)
	for i in range(connected_plots.size()):
		var button := Button.new()
		button.text = "Подключить участок %d — %d" % [i + 1, CONNECTION_COST]
		button.pressed.connect(_connect_plot.bind(i))
		plot_buttons.add_child(button)

func _connect_plot(plot_id: int) -> void:
	if plot_id < 0 or plot_id >= connected_plots.size() or connected_plots[plot_id]:
		return
	if manager == null:
		utility_status = "Экономика недоступна"
		_refresh_hud()
		return
	var plots: Array = manager.get("plots")
	if plot_id >= plots.size() or not bool(plots[plot_id].get("owned", false)):
		utility_status = "Сначала купите этот участок"
		_refresh_hud()
		return
	var balance := int(manager.get("cash"))
	if balance < CONNECTION_COST:
		utility_status = "Недостаточно монет для подключения"
		_refresh_hud()
		return
	manager.set("cash", balance - CONNECTION_COST)
	connected_plots[plot_id] = true
	utility_status = "Участок %d подключён к электричеству и воде" % (plot_id + 1)
	_save_state()
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_recalculate_costs()
	_refresh_hud()

func _start_timer() -> void:
	timer = Timer.new()
	timer.wait_time = TICK_SECONDS
	timer.autostart = true
	timer.timeout.connect(_charge_utilities)
	add_child(timer)

func _charge_utilities() -> void:
	_recalculate_costs()
	if manager == null or last_total_cost <= 0:
		_refresh_hud()
		return
	var balance := int(manager.get("cash"))
	if balance >= last_total_cost:
		manager.set("cash", balance - last_total_cost)
		utility_status = "Коммунальные услуги оплачены"
		manager.call("_save_game")
		manager.call("_refresh_ui")
	else:
		utility_status = "Не хватает монет на коммунальные услуги"
	_refresh_hud()

func _recalculate_costs() -> void:
	var active_buildings := 0
	var connected_buildings := 0
	if manager != null:
		var plots: Array = manager.get("plots")
		for i in range(plots.size()):
			var plot: Dictionary = plots[i]
			if not String(plot.get("building", "")).is_empty():
				active_buildings += 1
				if i < connected_plots.size() and connected_plots[i]:
					connected_buildings += 1
	electricity_cost = ELECTRICITY_BASE + connected_buildings * POWER_PER_BUILDING if connected_buildings > 0 else 0
	water_cost = WATER_BASE + connected_buildings * WATER_PER_BUILDING if connected_buildings > 0 else 0
	last_total_cost = electricity_cost + water_cost
	_refresh_hud()

func _refresh_hud() -> void:
	if hud_label == null:
		return
	var connected_count := 0
	for value in connected_plots:
		if value:
			connected_count += 1
	hud_label.text = "Подключено участков: %d/%d\nЭлектричество: %d\nВода: %d\nВсего за %d сек.: %d\n%s" % [
		connected_count, connected_plots.size(), electricity_cost, water_cost, int(TICK_SECONDS), last_total_cost, utility_status
	]

func _save_state() -> void:
	var config := ConfigFile.new()
	for i in range(connected_plots.size()):
		config.set_value("utilities", "connected_%d" % i, connected_plots[i])
	config.save("user://city_utilities.cfg")

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load("user://city_utilities.cfg") != OK:
		return
	for i in range(connected_plots.size()):
		connected_plots[i] = bool(config.get_value("utilities", "connected_%d" % i, false))
	# The array is sized from the current plot list before loading, so removed plot slots are ignored.

# End of utility save loader.
