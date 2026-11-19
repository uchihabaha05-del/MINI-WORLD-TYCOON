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
var income_timer: Timer

func _ready() -> void:
	_create_plots()
	_load_game()
	for i in range(plots.size()):
		if not String(plots[i]["building"]).is_empty():
			_spawn_building(i)
	_create_interface()
	_refresh_all_plots()
	_refresh_ui()
	_start_income_timer()

func _create_plots() -> void:
	var positions: Array[Vector3] = [
		Vector3(-43, 0.2, -43),
		Vector3(43, 0.2, -43),
		Vector3(-43, 0.2, 43),
		Vector3(43, 0.2, 43)
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
		shape.size = Vector3(14, 1.0, 14)
		collision.shape = shape
		area.add_child(collision)

		var pad := MeshInstance3D.new()
		pad.name = "PlotSurface"
		var pad_mesh := BoxMesh.new()
		pad_mesh.size = Vector3(14, 0.18, 14)
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

		area.input_event.connect(_on_plot_input_event.bind(i))
		add_child(area)
		plots.append({
			"id": i,
			"area": area,
			"pad": pad,
			"owned": false,
			"building": "",
			"level": 0,
			"workers": 0
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

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 18
	panel.offset_top = -220
	panel.offset_right = 440
	panel.offset_bottom = -18
	root.add_child(panel)

	var content := VBoxContainer.new()
	panel.add_child(content)
	plot_title = Label.new()
	plot_title.add_theme_font_size_override("font_size", 22)
	content.add_child(plot_title)
	plot_info = Label.new()
	plot_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(plot_info)

	buy_button = Button.new()
	buy_button.text = "Купить участок — 300"
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
	_spawn_building(selected_plot)
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
	_save_game()
	_refresh_all_plots()
	_refresh_ui()

func _start_income_timer() -> void:
	income_timer = Timer.new()
	income_timer.wait_time = INCOME_INTERVAL
	income_timer.autostart = true
	income_timer.timeout.connect(_collect_income)
	add_child(income_timer)

func _collect_income() -> void:
	var earned := 20 # Starting MINI MARKET business.
	var payroll := 0
	var worker_bonus := 0
	for plot in plots:
		var building_type := String(plot["building"])
		if not building_type.is_empty() and BUILDINGS.has(building_type):
			var definition: Dictionary = BUILDINGS[building_type]
			earned += int(definition["income"]) * int(plot["level"])
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
		pad.material_override = _make_material(color)

func _refresh_ui() -> void:
	cash_label.text = "💰  %d монет" % cash
	var business_count := 0
	var business_income := 20
	for business_plot in plots:
		var business_type := String(business_plot["building"])
		if not business_type.is_empty() and BUILDINGS.has(business_type):
			business_count += 1
			business_income += int(BUILDINGS[business_type]["income"]) * int(business_plot["level"])
	business_summary_label.text = "Предприятий: %d  •  Доход: %d / 10 сек." % [business_count, business_income]
	if status_label.text.is_empty():
		status_label.text = "Ваш MINI MARKET приносит 20 за цикл"
	if not _has_selection():
		plot_title.text = "Выберите участок"
		plot_info.text = "Нажмите на свободную зелёную площадку на карте."
		buy_button.visible = false
		store_button.visible = false
		cafe_button.visible = false
		apartments_button.visible = false
		restaurant_button.visible = false
		workshop_button.visible = false
		upgrade_button.visible = false
		staff_label.visible = false
		hire_worker_button.visible = false
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
	cafe_button.disabled = cash < int(BUILDINGS["Кафе"]["cost"])
	apartments_button.disabled = cash < int(BUILDINGS["Апартаменты"]["cost"])
	restaurant_button.disabled = cash < int(BUILDINGS["Ресторан"]["cost"])
	workshop_button.disabled = cash < int(BUILDINGS["Мастерская"]["cost"])
	upgrade_button.visible = owned and not building_type.is_empty()
	var has_business := owned and not building_type.is_empty() and building_type != "Апартаменты"
	var worker_count := int(plot.get("workers", 0))
	var worker_limit := maxi(1, int(plot["level"]) * MAX_WORKERS_PER_LEVEL)
	staff_label.visible = has_business
	hire_worker_button.visible = has_business
	staff_label.text = "Персонал: %d/%d • зарплата %d за цикл • бонус +%d дохода" % [worker_count, worker_limit, worker_count * WORKER_SALARY, worker_count * WORKER_BONUS]
	hire_worker_button.text = "Нанять работника — %d" % WORKER_HIRE_COST
	hire_worker_button.disabled = cash < WORKER_HIRE_COST or worker_count >= worker_limit
	if not owned:
		plot_info.text = "Свободная земля. Цена покупки: %d монет." % PLOT_COST
	elif building_type.is_empty():
		plot_info.text = "Участок ваш. Выберите здание для строительства."
	else:
		var definition: Dictionary = BUILDINGS[building_type]
		var level := int(plot["level"])
		plot_info.text = "%s • уровень %d\nДоход: %d монет за цикл. Улучшение: %d." % [
			building_type, level, int(definition["income"]) * level, 500 * level
		]
	upgrade_button.text = "Улучшить — %d монет" % (500 * int(plot["level"]))
	upgrade_button.disabled = cash < 500 * int(plot["level"])

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
	_save_game()
	_refresh_ui()

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
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		config.set_value("plots", "owned_%d" % i, bool(plot["owned"]))
		config.set_value("plots", "building_%d" % i, String(plot["building"]))
		config.set_value("plots", "level_%d" % i, int(plot["level"]))
		config.set_value("plots", "workers_%d" % i, int(plot.get("workers", 0)))
	config.save("user://tycoon_save.cfg")

func _load_game() -> void:
	var config := ConfigFile.new()
	if config.load("user://tycoon_save.cfg") != OK:
		return
	cash = int(config.get_value("economy", "cash", STARTING_CASH))
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		plot["owned"] = bool(config.get_value("plots", "owned_%d" % i, false))
		plot["building"] = String(config.get_value("plots", "building_%d" % i, ""))
		plot["level"] = int(config.get_value("plots", "level_%d" % i, 0))
		plot["workers"] = maxi(0, int(config.get_value("plots", "workers_%d" % i, 0)))
		plots[i] = plot
