extends Node3D

# MINI WORLD TYCOON — Milestone 29: civic projects and park development.
const SAVE_PATH := "user://city_development.cfg"
const PROJECTS := [
	{"name": "Цветочные клумбы", "cost": 250, "happiness": 2, "demand": 1, "kind": "flowers", "description": "Украшают центральный парк"},
	{"name": "Новый фонтан", "cost": 450, "happiness": 3, "demand": 1, "kind": "fountain", "description": "Главная точка отдыха горожан"},
	{"name": "Детская площадка", "cost": 650, "happiness": 4, "demand": 1, "kind": "playground", "description": "Больше мест для семей"},
	{"name": "Скульптура города", "cost": 800, "happiness": 4, "demand": 1, "kind": "statue", "description": "Новая городская достопримечательность"},
	{"name": "Скамейки и фонари", "cost": 950, "happiness": 5, "demand": 1, "kind": "street_furniture", "description": "Комфортнее гулять вечером"},
	{"name": "Большой парк", "cost": 1300, "happiness": 7, "demand": 2, "kind": "grand_park", "description": "Финальное благоустройство района"}
]
const PROJECT_POSITIONS := [
	Vector3(4, 0, 43), Vector3(28, 0, 43), Vector3(16, 0, 33),
	Vector3(16, 0, 53), Vector3(4, 0, 53), Vector3(28, 0, 33)
]

var manager: Node
var city_life: Node
var rivals: Node
var completed: Array[bool] = [false, false, false, false, false, false]
var project_buttons: Array[Button] = []
var summary_label: Label
var status_label: Label
var total_demand_bonus := 0
var total_happiness_bonus := 0
var ui_timer: Timer

func _ready() -> void:
	manager = get_parent().get_node_or_null("TycoonManager")
	city_life = get_parent().get_node_or_null("CityPopulation")
	rivals = get_parent().get_node_or_null("RivalBusinesses")
	_load_projects()
	_create_hud()
	_rebuild_projects()
	for project_id in range(completed.size()):
		if completed[project_id]:
			_build_project_visual(project_id)
	_apply_bonuses()
	_refresh_ui()
	ui_timer = Timer.new()
	ui_timer.wait_time = 2.0
	ui_timer.autostart = true
	ui_timer.timeout.connect(_refresh_ui)
	add_child(ui_timer)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CityDevelopmentHUD"
	layer.layer = 9
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(650, 270)
	panel.custom_minimum_size = Vector2(285, 220)
	panel.size = Vector2(285, 250)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(270, 230)
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var title := Label.new()
	title.text = "🌳 БЛАГОУСТРОЙСТВО ГОРОДА"
	title.add_theme_font_size_override("font_size", 17)
	content.add_child(title)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	for i in range(PROJECTS.size()):
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_buy_project.bind(i))
		project_buttons.append(button)
		content.add_child(button)

func _buy_project(project_id: int) -> void:
	if project_id < 0 or project_id >= PROJECTS.size() or completed[project_id] or manager == null:
		return
	var project: Dictionary = PROJECTS[project_id]
	var cost := int(project["cost"])
	if int(manager.get("cash")) < cost:
		status_label.text = "Не хватает монет: нужно ещё %d." % (cost - int(manager.get("cash")))
		return
	manager.set("cash", int(manager.get("cash")) - cost)
	completed[project_id] = true
	_build_project_visual(project_id)
	_apply_bonuses()
	_save_projects()
	manager.call("_save_game")
	manager.call("_refresh_ui")
	status_label.text = "Город стал красивее! Счастье +%d, спрос +%d." % [int(project["happiness"]), int(project["demand"])]
	_refresh_ui()
	if rivals != null and rivals.has_method("_refresh_hud"):
		rivals.call("_refresh_hud")

func _build_project_visual(project_id: int) -> void:
	var root := Node3D.new()
	root.name = "CivicProject_%d" % project_id
	root.position = PROJECT_POSITIONS[project_id]
	add_child(root)
	match String(PROJECTS[project_id]["kind"]):
		"flowers":
			_box(root, Vector3(3.2, 0.22, 2.0), Vector3.ZERO, Color("#805b45"))
			for x in [-1.0, 0.0, 1.0]:
				_sphere(root, Vector3(x, 0.55, 0), 0.34, Color("#e66f91") if int(x * 10) % 2 == 0 else Color("#f0c85e"))
		"fountain":
			_cylinder(root, Vector3(0, 0.18, 0), 2.0, 0.35, Color("#9aa8ad"))
			_cylinder(root, Vector3(0, 0.52, 0), 1.25, 0.38, Color("#65b7d1"))
			_cylinder(root, Vector3(0, 1.0, 0), 0.22, 1.0, Color("#9bb8c2"))
			_sphere(root, Vector3(0, 1.7, 0), 0.35, Color("#78cce5"))
		"playground":
			_box(root, Vector3(4.0, 0.2, 2.8), Vector3.ZERO, Color("#d6b56d"))
			_box(root, Vector3(0.18, 2.2, 0.18), Vector3(-1.2, 1.1, 0), Color("#d94e4e"))
			_box(root, Vector3(0.18, 2.2, 0.18), Vector3(1.2, 1.1, 0), Color("#d94e4e"))
			_box(root, Vector3(2.6, 0.16, 0.18), Vector3(0, 2.0, 0), Color("#e6c75c"))
			_box(root, Vector3(2.0, 0.15, 0.15), Vector3(0, 0.8, 0.8), Color("#4b83aa"))
		"statue":
			_cylinder(root, Vector3(0, 0.55, 0), 0.9, 1.1, Color("#b8b5a8"))
			_box(root, Vector3(0.8, 1.8, 0.65), Vector3(0, 2.0, 0), Color("#8a9ca2"))
			_sphere(root, Vector3(0, 3.15, 0), 0.55, Color("#a8b8bd"))
		"street_furniture":
			for x in [-1.5, 1.5]:
				_box(root, Vector3(1.8, 0.45, 0.65), Vector3(x, 0.45, 0), Color("#9a704c"))
				_cylinder(root, Vector3(x, 1.8, -1.1), 0.08, 3.6, Color("#414b55"))
				_sphere(root, Vector3(x, 3.65, -1.1), 0.38, Color("#ffe4a0"))
		"grand_park":
			_box(root, Vector3(5.0, 0.18, 3.5), Vector3.ZERO, Color("#75a85f"))
			for x in [-1.7, 1.7]:
				_cylinder(root, Vector3(x, 1.0, 0), 0.18, 2.0, Color("#805638"))
				_sphere(root, Vector3(x, 2.25, 0), 1.05, Color("#43834c"))
			_box(root, Vector3(2.6, 0.16, 0.7), Vector3(0, 0.3, 0), Color("#a8794f"))

func _apply_bonuses() -> void:
	total_demand_bonus = 0
	total_happiness_bonus = 0
	for i in range(PROJECTS.size()):
		if completed[i]:
			total_demand_bonus += int(PROJECTS[i]["demand"])
			total_happiness_bonus += int(PROJECTS[i]["happiness"])
	if city_life != null:
		city_life.set("civic_demand_bonus", total_demand_bonus)
		city_life.set("civic_happiness_bonus", total_happiness_bonus)
		city_life.set("happiness", mini(100, 70 + total_happiness_bonus))
		if city_life.has_method("_refresh_hud"):
			city_life.call("_refresh_hud")

func get_completed_count() -> int:
	var count := 0
	for is_done in completed:
		if is_done:
			count += 1
	return count

func _refresh_ui() -> void:
	if summary_label == null:
		return
	var count := get_completed_count()
	var rank := "Небольшой город"
	if count >= 2:
		rank = "Уютный город"
	if count >= 4:
		rank = "Зелёный город"
	if count >= 6:
		rank = "Город мечты"
	summary_label.text = "Проекты: %d/6 • %s\nБонус спроса: +%d • счастье: +%d%%" % [count, rank, total_demand_bonus, total_happiness_bonus]
	for i in range(PROJECTS.size()):
		var project: Dictionary = PROJECTS[i]
		var button := project_buttons[i]
		button.disabled = completed[i] or manager == null or int(manager.get("cash")) < int(project["cost"])
		button.text = ("✓ " if completed[i] else "＋ ") + String(project["name"]) + (" • готово" if completed[i] else " • %d монет" % int(project["cost"]))

func _save_projects() -> void:
	var config := ConfigFile.new()
	for i in range(completed.size()):
		config.set_value("projects", "completed_%d" % i, completed[i])
	config.save(SAVE_PATH)

func _load_projects() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for i in range(completed.size()):
		completed[i] = bool(config.get_value("projects", "completed_%d" % i, false))

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
