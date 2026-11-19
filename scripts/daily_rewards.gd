extends Node3D

# MINI WORLD TYCOON — Daily reward calendar, saved locally.
const REWARDS: Array[int] = [100, 150, 200, 250, 300, 400, 700]
const DAY_SECONDS := 86400

var manager: Node
var last_claim_day := -1
var streak := 0
var claim_button: Button
var reward_label: Label

func _ready() -> void:
	manager = get_parent().get_node_or_null("TycoonManager")
	_load_reward_state()
	_create_hud()
	_refresh()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DailyRewardHUD"
	layer.layer = 8
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(330, 112)
	panel.custom_minimum_size = Vector2(300, 92)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	reward_label = Label.new()
	reward_label.custom_minimum_size = Vector2(280, 42)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.add_theme_font_size_override("font_size", 14)
	box.add_child(reward_label)
	claim_button = Button.new()
	claim_button.text = "🎁 Забрать подарок"
	claim_button.pressed.connect(_claim_reward)
	box.add_child(claim_button)

func _today() -> int:
	return int(floor(float(Time.get_unix_time_from_system()) / DAY_SECONDS))

func _refresh() -> void:
	var today := _today()
	var can_claim := today > last_claim_day
	var next_day := posmod(streak, REWARDS.size())
	if can_claim:
		reward_label.text = "🎁 Ежедневный подарок\nДень %d из 7 — награда %d монет!" % [next_day + 1, REWARDS[next_day]]
		claim_button.disabled = false
	else:
		reward_label.text = "⭐ Подарок уже получен!\nВозвращайся завтра за новой наградой."
		claim_button.disabled = true

func _claim_reward() -> void:
	var today := _today()
	if today <= last_claim_day or manager == null:
		_refresh()
		return
	if last_claim_day == today - 1:
		streak = posmod(streak, REWARDS.size()) + 1
	else:
		streak = 1
	var reward_index := posmod(streak - 1, REWARDS.size())
	var reward := REWARDS[reward_index]
	manager.set("cash", int(manager.get("cash")) + reward)
	var status: Label = manager.get("status_label") as Label
	if status != null:
		status.text = "🎁 Ежедневный подарок! +%d монет!" % reward
	last_claim_day = today
	_save_reward_state()
	manager.call("_save_game")
	manager.call("_refresh_ui")
	_refresh()

func _save_reward_state() -> void:
	var config := ConfigFile.new()
	config.set_value("daily", "last_claim_day", last_claim_day)
	config.set_value("daily", "streak", streak)
	config.save("user://daily_rewards.cfg")

func _load_reward_state() -> void:
	var config := ConfigFile.new()
	if config.load("user://daily_rewards.cfg") != OK:
		return
	last_claim_day = int(config.get_value("daily", "last_claim_day", -1))
	streak = maxi(0, int(config.get_value("daily", "streak", 0)))
