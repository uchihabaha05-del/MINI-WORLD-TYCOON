extends Node3D

# MINI WORLD TYCOON — Milestone 21: municipal finance, taxes and city budget.
const FINANCE_TICK := 30.0
const DEFAULT_TAX_RATE := 8
const MIN_TAX_RATE := 0
const MAX_TAX_RATE := 20
const TAX_STEP := 2
const RESIDENT_SERVICE_COST := 1
const BUILDING_SERVICE_COST := 5

var manager: Node
var population_system: Node
var tax_rate := DEFAULT_TAX_RATE
var total_tax_collected := 0
var total_city_spending := 0
var last_tax_income := 0
var last_city_spending := 0
var finance_timer: Timer
var finance_label: Label
var tax_label: Label
var status_label: Label
var lower_tax_button: Button
var raise_tax_button: Button

func _ready() -> void:
	manager = get_parent().get_node_or_null("TycoonManager")
	population_system = get_parent().get_node_or_null("CityPopulation")
	_load_finance()
	_create_hud()
	_refresh_finance()
	_start_timer()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MunicipalFinanceHUD"
	layer.layer = 6
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(340, 18)
	panel.custom_minimum_size = Vector2(300, 160)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "🏛 ГОРОДСКОЙ БЮДЖЕТ"
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)
	tax_label = Label.new()
	content.add_child(tax_label)
	var controls := HBoxContainer.new()
	content.add_child(controls)
	lower_tax_button = Button.new()
	lower_tax_button.text = "Налог −"
	lower_tax_button.pressed.connect(_change_tax_rate.bind(-TAX_STEP))
	controls.add_child(lower_tax_button)
	raise_tax_button = Button.new()
	raise_tax_button.text = "Налог +"
	raise_tax_button.pressed.connect(_change_tax_rate.bind(TAX_STEP))
	controls.add_child(raise_tax_button)
	finance_label = Label.new()
	finance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(finance_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)

func _start_timer() -> void:
	finance_timer = Timer.new()
	finance_timer.wait_time = FINANCE_TICK
	finance_timer.autostart = true
	finance_timer.timeout.connect(_process_city_budget)
	add_child(finance_timer)

func _change_tax_rate(amount: int) -> void:
	tax_rate = clampi(tax_rate + amount, MIN_TAX_RATE, MAX_TAX_RATE)
	status_label.text = "Новая налоговая ставка: %d%%" % tax_rate
	_save_finance()
	_refresh_finance()

func _process_city_budget() -> void:
	if manager == null:
		status_label.text = "Городская экономика недоступна"
		_refresh_finance()
		return
	var plots: Array = manager.get("plots")
	var building_count := 0
	for plot in plots:
		if not String(plot.get("building", "")).is_empty():
			building_count += 1
	var taxable_income := int(manager.call("get_taxable_business_income"))
	var tax_amount := int(round(float(taxable_income) * float(tax_rate) / 100.0))
	var population_count := 36
	if population_system != null:
		population_count = int(population_system.call("get_population"))
	var service_cost := int(ceil(float(population_count) * float(RESIDENT_SERVICE_COST) / 10.0))
	var infrastructure_cost := building_count * BUILDING_SERVICE_COST
	var expense := service_cost + infrastructure_cost
	last_tax_income = tax_amount
	last_city_spending = expense
	total_tax_collected += tax_amount
	total_city_spending += expense
	var balance := int(manager.get("cash"))
	manager.set("cash", balance + tax_amount - expense)
	if tax_amount >= expense:
		status_label.text = "Бюджет профицитный: +%d монет" % (tax_amount - expense)
	else:
		status_label.text = "Дефицит бюджета: −%d монет" % (expense - tax_amount)
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_save_finance()
	_refresh_finance()

func _refresh_finance() -> void:
	if tax_label == null:
		return
	tax_label.text = "Налог на бизнес: %d%%" % tax_rate
	finance_label.text = "Последний сбор: +%d\nРасходы города: −%d за %d сек.\nВсего налогов: %d\nВсего расходов: %d" % [
		last_tax_income, last_city_spending, int(FINANCE_TICK), total_tax_collected, total_city_spending
	]
	lower_tax_button.disabled = tax_rate <= MIN_TAX_RATE
	raise_tax_button.disabled = tax_rate >= MAX_TAX_RATE

func _save_finance() -> void:
	var config := ConfigFile.new()
	config.set_value("municipal", "tax_rate", tax_rate)
	config.set_value("municipal", "total_tax_collected", total_tax_collected)
	config.set_value("municipal", "total_city_spending", total_city_spending)
	config.set_value("municipal", "last_tax_income", last_tax_income)
	config.set_value("municipal", "last_city_spending", last_city_spending)
	config.save("user://municipal_finance.cfg")

func _load_finance() -> void:
	var config := ConfigFile.new()
	if config.load("user://municipal_finance.cfg") != OK:
		return
	tax_rate = clampi(int(config.get_value("municipal", "tax_rate", DEFAULT_TAX_RATE)), MIN_TAX_RATE, MAX_TAX_RATE)
	total_tax_collected = maxi(0, int(config.get_value("municipal", "total_tax_collected", 0)))
	total_city_spending = maxi(0, int(config.get_value("municipal", "total_city_spending", 0)))
	last_tax_income = maxi(0, int(config.get_value("municipal", "last_tax_income", 0)))
	last_city_spending = maxi(0, int(config.get_value("municipal", "last_city_spending", 0)))
