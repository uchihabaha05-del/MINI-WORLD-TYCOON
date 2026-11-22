extends Node3D

# MINI WORLD TYCOON — Milestone 4: land ownership, construction and economy.
const PLOT_COST := 300
const STARTING_CASH := 1200
const INCOME_INTERVAL := 10.0
const WORKER_HIRE_COST := 250
const WORKER_SALARY := 8
const WORKER_BONUS := 12
const MAX_WORKERS_PER_LEVEL := 2
const BUILDINGS := {
	"Магазин": {"cost": 450, "income": 45, "color": Color("#e5b66b"), "height": 6.0},
	"Кафе": {"cost": 650, "income": 65, "color": Color("#c77c62"), "height": 5.0},
	"Апартаменты": {"cost": 900, "income": 90, "color": Color("#8faecb"), "height": 10.0},
	"Ресторан": {"cost": 1100, "income": 125, "color": Color("#c66c48"), "height": 7.0},
	"Мастерская": {"cost": 800, "income": 105, "color": Color("#82918e"), "height": 6.5}
}

var cash: int = STARTING_CASH
var plots: Array = []
var selected_plot: int = -1
var cash_label: Label
var status_label: Label
var business_summary_label: Label
var mission_label: Label
var tutorial_step: int = 0
var stars: int = 0
var quest_done: Array = [false, false, false, false, false, false, false, false]
var quest_label: Label
var level_label: Label
var city_level: int = 1
var plot_title: Label
var plot_info: Label
var buy_button: Button
var store_button: Button
var cafe_button: Button
var apartments_button: Button
var restaurant_button: Button
var workshop_button: Button
var upgrade_button: Button
var hire_worker_button: Button
var staff_label: Label
var appeal_label: Label
var marketing_button: Button
var income_timer: Timer
var city_dashboard_open := false
var city_dashboard_button: Button
var story_markers: Array[Label3D] = []

func _ready() -> void:
	_create_plots()
	_load_game()
	for i in range(plots.size()):
		if not String(plots[i]["building"]).is_empty():
			_spawn_building(i)
	_create_interface()
	_check_quests()
	_refresh_all_plots()
	_refresh_ui()
	_start_income_timer()

func _create_plots() -> void:
	var positions: Array[Vector3] = [
		Vector3(-43, 0.2, -43),
		Vector3(43, 0.2, -43),
		Vector3(-43, 0.2, 43),
		Vector3(43, 0.2, 43),
		Vector3(-78, 0.2, -43),
		Vector3(78, 0.2, -43),
		Vector3(-78, 0.2, 43),
		Vector3(78, 0.2, 43),
		Vector3(-43, 0.2, -78),
		Vector3(43, 0.2, -78),
		Vector3(-43, 0.2, 78),
		Vector3(43, 0.2, 78)
	]
	for i in range(positions.size()):
		var area := Area3D.new()
		area.name = "BuildablePlot_%d" % i
		area.position = positions[i]
		area.input_ray_pickable = true
		area.collision_layer = 1
		area.collision_mask = 0

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(12, 1.0, 12)
		collision.shape = shape
		area.add_child(collision)

		var pad := MeshInstance3D.new()
		pad.name = "PlotSurface"
		var pad_mesh := BoxMesh.new()
		pad_mesh.size = Vector3(12, 0.18, 12)
		pad.mesh = pad_mesh
		pad.position.y = -0.08
		area.add_child(pad)

		var marker := Label3D.new()
		marker.name = "PlotLabel"
		marker.text = "УЧАСТОК %d" % (i + 1)
		marker.font_size = 34
		marker.pixel_size = 0.012
		marker.position = Vector3(0, 1.1, 0)
		marker.modulate = Color("#ffffff")
		area.add_child(marker)

		var story_marker := Label3D.new()
		story_marker.name = "StoryHint"
		story_marker.text = "НАЖМИ НА УЧАСТОК"
		story_marker.font_size = 42
		story_marker.pixel_size = 0.012
		story_marker.position = Vector3(0, 3.2, 0)
		story_marker.modulate = Color("#fff2a6")
		story_marker.visible = false
		area.add_child(story_marker)
		story_markers.append(story_marker)

		area.input_event.connect(_on_plot_input_event.bind(i))
		add_child(area)
		plots.append({
			"id": i,
			"area": area,
			"pad": pad,
			"owned": false,
			"building": "",
			"level": 0,
			"workers": 0,
			"appeal": 50
		})

func _create_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TycoonHUD"
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var top := PanelContainer.new()
	top.position = Vector2(18, 18)
	top.custom_minimum_size = Vector2(310, 76)
	root.add_child(top)

	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 25)
	top_box.add_child(cash_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	top_box.add_child(status_label)
	business_summary_label = Label.new()
	business_summary_label.add_theme_font_size_override("font_size", 14)
	top_box.add_child(business_summary_label)
	mission_label = Label.new()
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.add_theme_font_size_override("font_size", 14)
	quest_label = Label.new()
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_label.add_theme_font_size_override("font_size", 13)
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 13)
	var dashboard_row := HBoxContainer.new()
	dashboard_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dashboard_row.anchor_left = 1.0
	dashboard_row.anchor_right = 1.0
	dashboard_row.offset_left = -174
	dashboard_row.offset_right = -18
	dashboard_row.offset_top = 18
	dashboard_row.offset_bottom = 62
	root.add_child(dashboard_row)
	city_dashboard_button = Button.new()
	city_dashboard_button.text = "ГОРОД  +"
	city_dashboard_button.custom_minimum_size = Vector2(150, 42)
	city_dashboard_button.pressed.connect(_toggle_city_dashboard)
	dashboard_row.add_child(city_dashboard_button)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 18
	panel.offset_top = -286
	panel.offset_right = 440
	panel.offset_bottom = -18
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(mission_label)
	content.add_child(quest_label)
	content.add_child(level_label)
	plot_title = Label.new()
	plot_title.add_theme_font_size_override("font_size", 22)
	content.add_child(plot_title)
	plot_info = Label.new()
	plot_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(plot_info)

	buy_button = Button.new()
	buy_button.text = "Купить землю — 300 монет"
	buy_button.pressed.connect(_buy_selected_plot)
	content.add_child(buy_button)

	var build_row := HBoxContainer.new()
	content.add_child(build_row)
	store_button = _make_build_button("Магазин · 450", "Магазин")
	build_row.add_child(store_button)
	cafe_button = _make_build_button("Кафе · 650", "Кафе")
	build_row.add_child(cafe_button)
	apartments_button = _make_build_button("Дом · 900", "Апартаменты")
	build_row.add_child(apartments_button)

	var business_row := HBoxContainer.new()
	content.add_child(business_row)
	restaurant_button = _make_build_button("Ресторан · 1100", "Ресторан")
	business_row.add_child(restaurant_button)
	workshop_button = _make_build_button("Мастерская · 800", "Мастерская")
	business_row.add_child(workshop_button)

	upgrade_button = Button.new()
	upgrade_button.text = "Улучшить здание"
	upgrade_button.pressed.connect(_upgrade_selected_plot)
	content.add_child(upgrade_button)
	staff_label = Label.new()
	staff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(staff_label)
	hire_worker_button = Button.new()
	hire_worker_button.pressed.connect(_hire_plot_worker)
	content.add_child(hire_worker_button)
	appeal_label = Label.new()
	appeal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(appeal_label)
	marketing_button = Button.new()
	marketing_button.pressed.connect(_promote_selected_business)
	content.add_child(marketing_button)

func _toggle_city_dashboard() -> void:
	city_dashboard_open = not city_dashboard_open
	for dashboard_panel in get_tree().get_nodes_in_group("city_dashboard_panels"):
		if is_instance_valid(dashboard_panel):
			dashboard_panel.visible = city_dashboard_open
	city_dashboard_button.text = "ГОРОД  −" if city_dashboard_open else "ГОРОД  +"

func _make_build_button(caption: String, building_type: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_build_selected_plot.bind(building_type))
	return button

func _on_plot_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, plot_id: int) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		_select_plot(plot_id)

func _select_plot(plot_id: int) -> void:
	selected_plot = plot_id
	if tutorial_step == 0:
		tutorial_step = 1
	_refresh_all_plots()
	_refresh_ui()

func _buy_selected_plot() -> void:
	if not _has_selection():
		return
	var plot: Dictionary = plots[selected_plot]
	if bool(plot["owned"]) or cash < PLOT_COST:
		return
	cash -= PLOT_COST
	plot["owned"] = true
	plots[selected_plot] = plot
	if tutorial_step < 2:
		tutorial_step = 2
	_check_quests()
	_save_game()
	_refresh_all_plots()
	_refresh_ui()

func _build_selected_plot(building_type: String) -> void:
	if not _has_selection():
		return
	var plot: Dictionary = plots[selected_plot]
	if not bool(plot["owned"]) or not String(plot["building"]).is_empty():
		return
	if not BUILDINGS.has(building_type):
		return
	var definition: Dictionary = BUILDINGS[building_type]
	var cost := int(definition["cost"])
	if cash < cost:
		return
	cash -= cost
	plot["building"] = building_type
	plot["level"] = 1
	plots[selected_plot] = plot
	if tutorial_step < 3:
		tutorial_step = 3
	_spawn_building(selected_plot)
	_check_quests()
	_save_game()
	_refresh_all_plots()
	_refresh_ui()

func _upgrade_selected_plot() -> void:
	if not _has_selection():
		return
	var plot: Dictionary = plots[selected_plot]
	if String(plot["building"]).is_empty():
		return
	var level := int(plot["level"])
	var cost := 500 * level
	if cash < cost:
		return
	cash -= cost
	plot["level"] = level + 1
	plots[selected_plot] = plot
	_update_building_visual(selected_plot)
	_check_quests()
	_save_game()
	_refresh_all_plots()
	_refresh_ui()

func _start_income_timer() -> void:
	income_timer = Timer.new()
	income_timer.wait_time = INCOME_INTERVAL
	income_timer.autostart = true
	income_timer.timeout.connect(_collect_income)
	add_child(income_timer)

func _get_building_cycle_income(plot: Dictionary) -> int:
	var building_type := String(plot.get("building", ""))
	if building_type.is_empty() or not BUILDINGS.has(building_type):
		return 0
	var base_income := int(BUILDINGS[building_type]["income"]) * int(plot.get("level", 1))
	if building_type == "Апартаменты":
		return base_income
	var city_life := get_parent().get_node_or_null("CityPopulation")
	var demand_factor := 1.0
	var happiness_factor := 1.0
	if city_life != null:
		if city_life.has_method("get_business_demand_multiplier"):
			demand_factor = float(city_life.call("get_business_demand_multiplier", building_type))
		if city_life.has_method("get_happiness"):
			happiness_factor = 0.8 + float(city_life.call("get_happiness")) / 350.0
	return maxi(0, roundi(float(base_income) * demand_factor * happiness_factor))

func _collect_income() -> void:
	var earned := 20 # Starting MINI MARKET business.
	var payroll := 0
	var worker_bonus := 0
	for plot in plots:
		var building_type := String(plot["building"])
		if not building_type.is_empty() and BUILDINGS.has(building_type):
			earned += _get_building_cycle_income(plot)
			payroll += int(plot.get("workers", 0)) * WORKER_SALARY
	if cash >= payroll:
		for plot in plots:
			var building_type := String(plot["building"])
			if not building_type.is_empty() and building_type != "Апартаменты":
				worker_bonus += int(plot.get("workers", 0)) * WORKER_BONUS
		cash -= payroll
		earned += worker_bonus
		cash += earned
		status_label.text = "Доход +%d, зарплаты -%d за цикл" % [earned, payroll]
	else:
		cash += earned
		status_label.text = "Доход +%d • не хватает на зарплаты: %d" % [earned, payroll]
	if tutorial_step == 3:
		tutorial_step = 4
		status_label.text = "Ура! Ты заработал первые монетки! 🎉"
	_save_game()
	_refresh_ui()

func _spawn_building(plot_id: int) -> void:
	var plot: Dictionary = plots[plot_id]
	var area: Area3D = plot["area"]
	var old := area.get_node_or_null("ConstructedBuilding")
	if old:
		old.queue_free()
	var building_type := String(plot["building"])
	if building_type.is_empty():
		return
	var definition: Dictionary = BUILDINGS[building_type]
	var level := int(plot["level"])
	var height := float(definition["height"]) + float(level - 1) * 1.5
	var root := Node3D.new()
	root.name = "ConstructedBuilding"
	area.add_child(root)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(9.0, height, 8.0)
	body.mesh = body_mesh
	body.position = Vector3(0, height * 0.5 + 0.12, 0)
	body.material_override = _make_material(definition["color"])
	root.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(9.5, 0.45, 8.5)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, height + 0.35, 0)
	roof.material_override = _make_material(Color("#4b555d"))
	root.add_child(roof)

	var window := MeshInstance3D.new()
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(5.0, minf(2.2, height * 0.35), 0.12)
	window.mesh = window_mesh
	window.position = Vector3(0, maxf(1.5, height * 0.35), 4.08)
	window.material_override = _make_material(Color("#6cabbc"))
	root.add_child(window)

	var sign := Label3D.new()
	sign.text = building_type.to_upper() + "  •  " + "УРОВЕНЬ %d" % level
	sign.font_size = 28
	sign.pixel_size = 0.01
	sign.position = Vector3(0, height + 1.2, 0)
	root.add_child(sign)

func _update_building_visual(plot_id: int) -> void:
	_spawn_building(plot_id)

func _refresh_all_plots() -> void:
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		var pad: MeshInstance3D = plot["pad"]
		var color := Color("#82bd72")
		if bool(plot["owned"]):
			color = Color("#d8bd70") if String(plot["building"]).is_empty() else Color("#7899a8")
		if i == selected_plot:
			color = Color("#f2dc77")
		elif tutorial_step == 0 and i == 0:
			color = Color("#f2dc77")
		pad.material_override = _make_material(color)
		if i < story_markers.size():
			var hint := story_markers[i]
			hint.visible = false
			if tutorial_step == 0 and i == 0:
				hint.text = "⬇ ПЕРВЫЙ УЧАСТОК"
				hint.visible = true
			elif tutorial_step == 1 and i == selected_plot:
				hint.text = "КУПИ ЭТУ ЗЕМЛЮ"
				hint.visible = true
			elif tutorial_step == 2 and i == selected_plot:
				hint.text = "ПОСТРОЙ МАГАЗИН"
				hint.visible = true

func _refresh_ui() -> void:
	var business_count := 0
	var business_income := 20
	for business_plot in plots:
		var business_type := String(business_plot["building"])
		if not business_type.is_empty() and BUILDINGS.has(business_type):
			business_count += 1
			business_income += _get_building_cycle_income(business_plot)
	business_summary_label.text = "Зданий: %d  •  Прогноз дохода: %d монет / 10 сек." % [business_count, business_income]
	_update_city_progress(business_count)
	cash_label.text = "💰  Мои монетки: %d" % cash
	_update_mission()
	_update_quest_text()
	if status_label.text.is_empty():
		status_label.text = "Твой магазин приносит монетки!"
	if not _has_selection():
		plot_title.text = "Выбери место для своего здания"
		plot_info.text = "Найди зелёную площадку и нажми на неё."
		buy_button.visible = false
		store_button.visible = false
		cafe_button.visible = false
		apartments_button.visible = false
		restaurant_button.visible = false
		workshop_button.visible = false
		upgrade_button.visible = false
		staff_label.visible = false
		hire_worker_button.visible = false
		appeal_label.visible = false
		marketing_button.visible = false
		return

	var plot: Dictionary = plots[selected_plot]
	plot_title.text = "Участок %d" % (selected_plot + 1)
	var owned := bool(plot["owned"])
	var building_type := String(plot["building"])
	buy_button.visible = not owned
	buy_button.disabled = cash < PLOT_COST
	store_button.visible = owned and building_type.is_empty()
	cafe_button.visible = owned and building_type.is_empty()
	apartments_button.visible = owned and building_type.is_empty()
	restaurant_button.visible = owned and building_type.is_empty()
	workshop_button.visible = owned and building_type.is_empty()
	store_button.disabled = cash < int(BUILDINGS["Магазин"]["cost"])
	cafe_button.disabled = cash < int(BUILDINGS["Кафе"]["cost"]) or _count_buildings() < 1
	apartments_button.disabled = cash < int(BUILDINGS["Апартаменты"]["cost"]) or _count_buildings() < 2
	restaurant_button.disabled = cash < int(BUILDINGS["Ресторан"]["cost"]) or _count_buildings() < 4
	workshop_button.disabled = cash < int(BUILDINGS["Мастерская"]["cost"]) or _count_buildings() < 3
	cafe_button.text = "Кафе · 650" if _count_buildings() >= 1 else "Кафе 🔒 (1 здание)"
	apartments_button.text = "Дом · 900" if _count_buildings() >= 2 else "Дом 🔒 (2 здания)"
	workshop_button.text = "Мастерская · 800" if _count_buildings() >= 3 else "Мастерская 🔒 (3 здания)"
	restaurant_button.text = "Ресторан · 1100" if _count_buildings() >= 4 else "Ресторан 🔒 (4 здания)"
	upgrade_button.visible = owned and not building_type.is_empty()
	var has_business := owned and not building_type.is_empty() and building_type != "Апартаменты"
	var worker_count := int(plot.get("workers", 0))
	var worker_limit := maxi(1, int(plot["level"]) * MAX_WORKERS_PER_LEVEL)
	staff_label.visible = has_business
	hire_worker_button.visible = has_business
	staff_label.text = "Персонал: %d/%d • зарплата %d за цикл • бонус +%d дохода" % [worker_count, worker_limit, worker_count * WORKER_SALARY, worker_count * WORKER_BONUS]
	hire_worker_button.text = "Нанять работника — %d" % WORKER_HIRE_COST
	hire_worker_button.disabled = cash < WORKER_HIRE_COST or worker_count >= worker_limit
	appeal_label.visible = has_business
	marketing_button.visible = has_business
	var appeal := int(plot.get("appeal", 50))
	var marketing_cost := 120 + int(plot["level"]) * 20
	appeal_label.text = "Привлекательность: %d/100 • выше показатель — чаще визиты" % appeal
	marketing_button.text = "Реклама +10 привлекательности — %d" % marketing_cost
	marketing_button.disabled = cash < marketing_cost or appeal >= 100
	if not owned:
		plot_info.text = "Это свободное место. Купи его, чтобы построить своё здание. Цена: %d монет." % PLOT_COST
	elif building_type.is_empty():
		plot_info.text = "Земля теперь твоя! Выбери, что построить. Магазин — самый простой старт."
	else:
		var definition: Dictionary = BUILDINGS[building_type]
		var level := int(plot["level"])
		plot_info.text = "Ты построил: %s!\nУровень: %d • Базовый доход: %d за 10 секунд.\nСпрос города и счастье жителей влияют на фактический доход. Улучшение: %d." % [
			building_type, level, _get_building_cycle_income(plot), 500 * level
		]
	upgrade_button.text = "Улучшить — %d монет" % (500 * int(plot["level"]))
	upgrade_button.disabled = cash < 500 * int(plot["level"])



func _check_quests() -> void:
	var owned_count := 0
	var building_count := 0
	var has_upgrade := false
	var has_worker := false
	var store: Node = get_parent().get_node_or_null("StoreGameplay")
	var total_sales := int(store.get("total_sales")) if store != null else 0
	var total_profit := int(store.get("total_profit")) if store != null else 0
	var shop_employee := bool(store.get("employee_hired")) if store != null else false
	for plot in plots:
		if bool(plot.get("owned", false)):
			owned_count += 1
		if not String(plot.get("building", "")).is_empty():
			building_count += 1
			if int(plot.get("level", 1)) >= 2:
				has_upgrade = true
			if int(plot.get("workers", 0)) > 0:
				has_worker = true
	var conditions: Array = [
		owned_count >= 1,
		building_count >= 1,
		has_upgrade,
		has_worker,
		building_count >= 3,
		total_sales >= 10,
		total_profit >= 500,
		shop_employee
	]
	var rewards: Array[int] = [100, 150, 200, 200, 350, 250, 300, 250]
	var changed := false
	for i in range(quest_done.size()):
		if not bool(quest_done[i]) and bool(conditions[i]):
			quest_done[i] = true
			stars += 1
			cash += rewards[i]
			status_label.text = "⭐ Задание выполнено! +%d монет и звезда!" % rewards[i]
			changed = true
	if changed:
		_save_game()

func _update_quest_text() -> void:
	var names: Array[String] = [
		"Получи свой первый участок",
		"Открой первый магазин",
		"Сделай магазин ещё лучше",
		"Найми помощника для покупателей",
		"Построй целых 3 здания",
		"Продай 10 товаров жителям",
		"Заработай 500 монет на товарах",
		"Позови помощника следить за полками"
	]
	var rewards: Array[int] = [100, 150, 200, 200, 350, 250, 300, 250]
	var next_quest := -1
	for i in range(quest_done.size()):
		if not bool(quest_done[i]):
			next_quest = i
			break
	if next_quest == -1:
		quest_label.text = "🏆 Все задания выполнены!\n⭐ Звёзды: %d — продолжай строить город!" % stars
	else:
		quest_label.text = "🎮 МАЛЕНЬКОЕ ДЕЛО ДЛЯ МЭРА\n%s\n🎁 Награда: %d монет + 1 звезда  •  ⭐ %d" % [names[next_quest], rewards[next_quest], stars]


func _count_buildings() -> int:
	var total := 0
	for plot in plots:
		if not String(plot.get("building", "")).is_empty():
			total += 1
	return total

func _update_city_progress(building_count: int) -> void:
	var target_level := 1
	if building_count >= 1:
		target_level = 2
	if building_count >= 3:
		target_level = 3
	if building_count >= 5:
		target_level = 4
	if building_count >= 8:
		target_level = 5
	if building_count >= 12:
		target_level = 6
	if target_level > city_level:
		var rewards: Array[int] = [0, 250, 500, 750, 1200, 2000]
		var reward := rewards[mini(target_level - 1, rewards.size() - 1)]
		cash += reward
		city_level = target_level
		status_label.text = "🎉 Новый уровень города %d! Награда: +%d монет!" % [city_level, reward]
		_save_game()
	level_label.text = "🏙 Уровень города: %d / 6  •  До следующего: %d зданий" % [city_level, _next_level_building_goal(building_count)]

func _next_level_building_goal(current_count: int) -> int:
	var goals: Array[int] = [1, 3, 5, 8, 12]
	for goal in goals:
		if current_count < goal:
			return goal
	return 12

func _update_mission() -> void:
	match tutorial_step:
		0:
			mission_label.text = "🌈 ИСТОРИЯ ГОРОДКА\nПривет, мэр! Наш городок опустел. Помоги жителям: открой магазин, продавай товары и строй красивые здания!\n\n🧭 ШАГ 1: Иди к жёлтой подсказке и нажми на участок."
		1:
			mission_label.text = "⭐ Отлично! Ты нашёл место для магазина.\n\n🧭 ШАГ 2: Нажми «Купить землю» — это стоит 300 монет. Земля станет твоей!"
		2:
			mission_label.text = "🏗️ Земля твоя! Пора открыть первый магазин.\n\n🧭 ШАГ 3: Нажми кнопку «Магазин» — он стоит 450 монет. Жители ждут покупки!"
		3:
			mission_label.text = "🎉 УРА! Магазин открыт!\nПокупатели скоро придут, а магазин принесёт первые монетки. Подожди немного и смотри, как растёт твой город!"
		_:
			mission_label.text = "🏆 ТЫ — МОЛОДЕЦ, МЭР!\nПервый магазин работает. Теперь помогай городу: пополняй полки, продавай товары, нанимай помощников и открывай кафе, дома и новые магазины."

func _hire_plot_worker() -> void:
	if not _has_selection():
		return
	var plot: Dictionary = plots[selected_plot]
	var building_type := String(plot["building"])
	if building_type.is_empty() or building_type == "Апартаменты":
		return
	var worker_limit := maxi(1, int(plot["level"]) * MAX_WORKERS_PER_LEVEL)
	var workers := int(plot.get("workers", 0))
	if workers >= worker_limit or cash < WORKER_HIRE_COST:
		return
	cash -= WORKER_HIRE_COST
	plot["workers"] = workers + 1
	plots[selected_plot] = plot
	_check_quests()
	_save_game()
	_refresh_ui()


func _promote_selected_business() -> void:
	if not _has_selection():
		return
	var plot: Dictionary = plots[selected_plot]
	var building_type := String(plot["building"])
	if building_type.is_empty() or building_type == "Апартаменты":
		return
	var appeal := int(plot.get("appeal", 50))
	var cost := 120 + int(plot["level"]) * 20
	if appeal >= 100 or cash < cost:
		return
	cash -= cost
	plot["appeal"] = mini(100, appeal + 10)
	plots[selected_plot] = plot
	_save_game()
	_refresh_ui()

func get_taxable_business_income() -> int:
	var total := 0
	for plot in plots:
		var building_type := String(plot.get("building", ""))
		if not building_type.is_empty() and BUILDINGS.has(building_type):
			total += int(BUILDINGS[building_type]["income"]) * int(plot.get("level", 1))
	return total

func get_business_appeal(plot_id: int) -> int:
	if plot_id < 0 or plot_id >= plots.size():
		return 50
	return int(plots[plot_id].get("appeal", 50))

func _has_selection() -> bool:
	return selected_plot >= 0 and selected_plot < plots.size()

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material

func _save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("economy", "cash", cash)
	config.set_value("tutorial", "step", tutorial_step)
	config.set_value("rewards", "stars", stars)
	config.set_value("progress", "city_level", city_level)
	for quest_index in range(quest_done.size()):
		config.set_value("rewards", "quest_%d" % quest_index, bool(quest_done[quest_index]))
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		config.set_value("plots", "owned_%d" % i, bool(plot["owned"]))
		config.set_value("plots", "building_%d" % i, String(plot["building"]))
		config.set_value("plots", "level_%d" % i, int(plot["level"]))
		config.set_value("plots", "workers_%d" % i, int(plot.get("workers", 0)))
		config.set_value("plots", "appeal_%d" % i, int(plot.get("appeal", 50)))
	config.save("user://tycoon_save.cfg")

func _load_game() -> void:
	var config := ConfigFile.new()
	if config.load("user://tycoon_save.cfg") != OK:
		return
	cash = int(config.get_value("economy", "cash", STARTING_CASH))
	tutorial_step = clampi(int(config.get_value("tutorial", "step", 0)), 0, 4)
	stars = maxi(0, int(config.get_value("rewards", "stars", 0)))
	city_level = clampi(int(config.get_value("progress", "city_level", 1)), 1, 6)
	for quest_index in range(quest_done.size()):
		quest_done[quest_index] = bool(config.get_value("rewards", "quest_%d" % quest_index, false))
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		plot["owned"] = bool(config.get_value("plots", "owned_%d" % i, false))
		plot["building"] = String(config.get_value("plots", "building_%d" % i, ""))
		plot["level"] = int(config.get_value("plots", "level_%d" % i, 0))
		plot["workers"] = maxi(0, int(config.get_value("plots", "workers_%d" % i, 0)))
		plot["appeal"] = clampi(int(config.get_value("plots", "appeal_%d" % i, 50)), 0, 100)
		plots[i] = plot
	if tutorial_step == 0:
		for saved_plot in plots:
			if not String(saved_plot.get("building", "")).is_empty():
				tutorial_step = 4
				break
