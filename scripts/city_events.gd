extends Node3D

# MINI WORLD TYCOON — City Events: rotating celebrations and city challenges.
const EVENT_INTERVAL := 90.0
const EVENT_DURATION := 45.0
const EVENTS := [
	{"title":"🎈 День скидок","description":"Покупатели тратят больше!","multiplier":1.5,"reward":180,"color":Color("#f2b84b")},
	{"title":"🎉 Городской праздник","description":"Жители радуются и приходят в магазины.","multiplier":1.35,"reward":220,"color":Color("#e98ac4")},
	{"title":"🍔 Фестиваль еды","description":"Продажи еды приносят больше монет.","multiplier":1.6,"reward":250,"color":Color("#e58b52")},
	{"title":"🚌 День транспорта","description":"Городской транспорт получает поддержку.","multiplier":1.25,"reward":160,"color":Color("#65a9d5")},
	{"title":"🌳 Зелёный город","description":"Жители довольны чистым городом.","multiplier":1.3,"reward":190,"color":Color("#79bd79")},
	{"title":"🎵 Музыкальный вечер","description":"Покупатели чаще заходят в магазины.","multiplier":1.4,"reward":200,"color":Color("#a88be0")},
	{"title":"🏃 Спортивный день","description":"Город активнее обычного.","multiplier":1.3,"reward":170,"color":Color("#70b8b0")},
	{"title":"🎂 День рождения города","description":"Большой праздник с щедрой наградой!","multiplier":1.7,"reward":350,"color":Color("#edbd68")},
	{"title":"🛍 Ярмарка","description":"Все магазины получают бонус к продажам.","multiplier":1.55,"reward":240,"color":Color("#d68c58")},
	{"title":"✨ Ночь огней","description":"Красивый вечер и дополнительные покупки.","multiplier":1.45,"reward":230,"color":Color("#879ce0")},
	{"title":"🐾 День семьи","description":"Семьи гуляют по городу и покупают товары.","multiplier":1.35,"reward":210,"color":Color("#e6a2a2")},
	{"title":"🏆 Неделя побед","description":"Особая награда за участие в событии.","multiplier":1.5,"reward":300,"color":Color("#d9b64e")}
]

var manager: Node
var store: Node
var event_label: Label
var event_timer: Timer
var active_event: Dictionary = {}
var seconds_left := 0
var event_number := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	manager = get_parent().get_node_or_null("TycoonManager")
	store = get_parent().get_node_or_null("StoreGameplay")
	_create_hud()
	_start_timer()
	_start_event()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CityEventsHUD"
	layer.layer = 7
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(650, 18)
	panel.custom_minimum_size = Vector2(300, 86)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	event_label = Label.new()
	event_label.custom_minimum_size = Vector2(280, 72)
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.add_theme_font_size_override("font_size", 15)
	box.add_child(event_label)

func _start_timer() -> void:
	event_timer = Timer.new()
	event_timer.wait_time = 1.0
	event_timer.autostart = true
	event_timer.timeout.connect(_tick_event)
	add_child(event_timer)

func _start_event() -> void:
	var event_index := rng.randi_range(0, EVENTS.size() - 1)
	active_event = EVENTS[event_index].duplicate(true)
	seconds_left = int(EVENT_DURATION)
	event_number += 1
	if store != null and store.has_method("set_city_event_multiplier"):
		store.call("set_city_event_multiplier", float(active_event["multiplier"]))
	_refresh_event_label()

func _tick_event() -> void:
	if active_event.is_empty():
		return
	seconds_left -= 1
	if seconds_left <= 0:
		_finish_event()
		return
	_refresh_event_label()

func _finish_event() -> void:
	if store != null and store.has_method("set_city_event_multiplier"):
		store.call("set_city_event_multiplier", 1.0)
	var reward := int(active_event.get("reward", 0))
	if manager != null:
		manager.set("cash", int(manager.get("cash")) + reward)
		var status: Label = manager.get("status_label") as Label
		if status != null:
			status.text = "🎊 Событие завершено! Награда: +%d монет!" % reward
		manager.call("_save_game")
		manager.call("_refresh_ui")
	event_label.text = "🎊 %s завершён! Получено +%d монет.\nСледующий городской праздник скоро!" % [String(active_event["title"]), reward]
	active_event.clear()
	var wait_timer := get_tree().create_timer(EVENT_INTERVAL)
	wait_timer.timeout.connect(_start_event)

func _refresh_event_label() -> void:
	if active_event.is_empty():
		return
	event_label.text = "%s\n%s\n⏱ Осталось: %d сек.  •  Бонус продаж: x%.2f" % [
		String(active_event["title"]),
		String(active_event["description"]),
		seconds_left,
		float(active_event["multiplier"])
	]
