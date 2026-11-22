extends Node3D

# MINI WORLD TYCOON — City contracts: recurring real-sales objectives and rewards.
const SAVE_PATH := "user://city_contracts.cfg"
const TARGETS: Array[int] = [8, 12, 16, 20, 24]
const REWARDS: Array[int] = [220, 360, 520, 720, 950]
var manager: Node
var shop: Node
var expansion: Node
var contract_index := 0
var progress := 0
var completed_contracts := 0
var lifetime_sales := 0
var last_shop_sales := 0
var contract_label: Label
var status_label: Label
var reward_label: Label
var contract_timer: Timer
var refresh_timer: Timer

func _ready() -> void:
	manager = get_parent().get_node_or_null("TycoonManager")
	shop = get_parent().get_node_or_null("StoreGameplay")
	expansion = get_parent().get_node_or_null("DistrictExpansion")
	_load_state()
	last_shop_sales = int(shop.get("total_sales")) if shop != null else 0
	_create_hud()
	_refresh_hud()
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 1.0
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_track_sales)
	add_child(refresh_timer)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CityContractsHUD"
	layer.layer = 13
	layer.visible = false
	layer.add_to_group("city_dashboard_panels")
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(650, 485)
	panel.custom_minimum_size = Vector2(320, 145)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "📋 ГОРОДСКИЕ КОНТРАКТЫ"
	title.add_theme_font_size_override("font_size", 19)
	content.add_child(title)
	contract_label = Label.new()
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(contract_label)
	reward_label = Label.new()
	content.add_child(reward_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)

func _track_sales() -> void:
	if shop == null:
		return
	var current_sales := int(shop.get("total_sales"))
	var gained := maxi(0, current_sales - last_shop_sales)
	last_shop_sales = current_sales
	if gained <= 0:
		return
	progress += gained
	lifetime_sales += gained
	var completed_any := false
	while progress >= TARGETS[mini(contract_index, TARGETS.size() - 1)]:
		_complete_contract()
		completed_any = true
	if not completed_any or progress > 0:
		_save_state()
		_refresh_hud()

func _complete_contract() -> void:
	var index := mini(contract_index, REWARDS.size() - 1)
	var reward := REWARDS[index]
	var district_rating := int(expansion.call("get_district_rating")) if expansion != null and expansion.has_method("get_district_rating") else 0
	var district_bonus := int(float(reward) * float(district_rating) / 500.0)
	var total_reward := reward + district_bonus
	if manager != null:
		manager.set("cash", int(manager.get("cash")) + total_reward)
		if manager.has_method("_save_game"):
			manager.call("_save_game")
		if manager.has_method("_refresh_ui"):
			manager.call("_refresh_ui")
	completed_contracts += 1
	contract_index += 1
	progress = maxi(0, progress - TARGETS[index])
	status_label.text = "Контракт выполнен! Награда: %d монет (районный бонус +%d)." % [total_reward, district_bonus]
	_save_state()
	_refresh_hud()

func get_completed_contracts() -> int:
	return completed_contracts

func get_contract_progress() -> int:
	return progress

func _refresh_hud() -> void:
	if contract_label == null:
		return
	var index := mini(contract_index, TARGETS.size() - 1)
	var target := TARGETS[index]
	var reward := REWARDS[index]
	contract_label.text = "Продай товары магазина: %d / %d\nКонтракт №%d • награда %d монет" % [mini(progress, target), target, contract_index + 1, reward]
	reward_label.text = "Выполнено контрактов: %d • продаж по контрактам: %d" % [completed_contracts, lifetime_sales]
	if status_label.text.is_empty():
		status_label.text = "Каждая реальная продажа приближает выполнение заказа города."

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("contracts", "index", contract_index)
	config.set_value("contracts", "progress", progress)
	config.set_value("contracts", "completed", completed_contracts)
	config.set_value("contracts", "lifetime_sales", lifetime_sales)
	config.save(SAVE_PATH)

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	contract_index = maxi(0, int(config.get_value("contracts", "index", 0)))
	progress = maxi(0, int(config.get_value("contracts", "progress", 0)))
	completed_contracts = maxi(0, int(config.get_value("contracts", "completed", 0)))
	lifetime_sales = maxi(0, int(config.get_value("contracts", "lifetime_sales", 0)))
