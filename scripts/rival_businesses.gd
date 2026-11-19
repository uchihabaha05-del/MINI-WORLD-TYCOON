extends Node3D

# MINI WORLD TYCOON — Milestone 22: rival businesses and district competition.
const RIVAL_DATA := [
	{"id": 0, "name": "CITY MART", "type": "Магазин", "position": Vector3(-12, 0, -82), "appeal": 68, "color": Color("#d16c4d")},
	{"id": 1, "name": "URBAN CAFE", "type": "Кафе", "position": Vector3(12, 0, 82), "appeal": 76, "color": Color("#bd8b53")},
	{"id": 2, "name": "NORTH FOOD", "type": "Ресторан", "position": Vector3(-82, 0, 12), "appeal": 82, "color": Color("#a75b4b")},
	{"id": 3, "name": "QUICK FIX", "type": "Мастерская", "position": Vector3(82, 0, -12), "appeal": 60, "color": Color("#607e91")}
]
var rivals: Array[Dictionary] = []
var total_rival_visits := 0
var saved_rival_visits: Dictionary = {}
var rival_label: Label
var district_label: Label
var manager: Node

func _ready() -> void:
	manager = get_parent().get_node_or_null("TycoonManager")
	_load_stats()
	_create_rivals()
	_create_hud()
	_refresh_hud()

func _create_rivals() -> void:
	for data in RIVAL_DATA:
		var rival: Dictionary = data.duplicate(true)
		rival["visits"] = int(saved_rival_visits.get(int(rival["id"]), 0))
		rivals.append(rival)
		_build_rival_shop(rival)

func _build_rival_shop(data: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Rival_" + String(data["name"]).replace(" ", "_")
	root.position = data["position"]
	add_child(root)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(11, 5.5, 9)
	body.mesh = body_mesh
	body.position.y = 2.75
	body.material_override = _material(data["color"])
	root.add_child(body)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(11.6, 0.5, 9.6)
	roof.mesh = roof_mesh
	roof.position.y = 5.75
	roof.material_override = _material(Color("#39434a"))
	root.add_child(roof)
	var glass := MeshInstance3D.new()
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(5.2, 2.4, 0.16)
	glass.mesh = glass_mesh
	glass.position = Vector3(0, 2.0, 4.58)
	glass.material_override = _material(Color("#8fc4d0"))
	root.add_child(glass)
	var sign := Label3D.new()
	sign.text = String(data["name"])
	sign.font_size = 30
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 4.9, 4.9)
	sign.modulate = Color.WHITE
	root.add_child(sign)

func get_rival_destinations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rival in rivals:
		var rival_position: Vector3 = rival["position"]
		result.append({
			"business": String(rival["type"]),
			"position": rival_position + Vector3(0, 0, 5.5),
			"spend": _rival_spend(String(rival["type"])),
			"rival": true,
			"rival_id": int(rival["id"]),
			"appeal": int(rival["appeal"]),
			"weight": 10.0 + float(rival["appeal"])
		})
	return result

func _rival_spend(business_type: String) -> int:
	match business_type:
		"Кафе": return 16
		"Ресторан": return 28
		"Мастерская": return 24
		_: return 18

func record_rival_visit(rival_id: int) -> void:
	for i in range(rivals.size()):
		if int(rivals[i]["id"]) == rival_id:
			rivals[i]["visits"] = int(rivals[i]["visits"]) + 1
			total_rival_visits += 1
			break
	_save_stats()
	_refresh_hud()

func get_district_rating() -> int:
	var player_appeal := 0
	var player_businesses := 0
	if manager != null:
		for plot in manager.get("plots"):
			var kind := String(plot.get("building", ""))
			if not kind.is_empty() and kind != "Апартаменты":
				player_businesses += 1
				player_appeal += int(plot.get("appeal", 50))
	var average := int(float(player_appeal) / float(maxi(1, player_businesses))) if player_businesses > 0 else 35
	var competitor_strength := 0
	for rival in rivals:
		competitor_strength += int(rival["appeal"])
	var pressure := int(float(competitor_strength) / float(maxi(1, rivals.size())))
	var civic := get_parent().get_node_or_null("CityDevelopment")
	var civic_bonus := int(civic.call("get_completed_count")) * 2 if civic != null and civic.has_method("get_completed_count") else 0
	return clampi(50 + average / 2 - pressure / 3 + mini(15, player_businesses * 3) + civic_bonus, 0, 100)

func _save_stats() -> void:
	var config := ConfigFile.new()
	config.set_value("market", "total_rival_visits", total_rival_visits)
	for rival in rivals:
		config.set_value("rivals", "visits_%d" % int(rival["id"]), int(rival["visits"]))
	config.save("user://rival_market.cfg")

func _load_stats() -> void:
	var config := ConfigFile.new()
	if config.load("user://rival_market.cfg") != OK:
		return
	total_rival_visits = maxi(0, int(config.get_value("market", "total_rival_visits", 0)))
	for data in RIVAL_DATA:
		var rival_id := int(data["id"])
		saved_rival_visits[rival_id] = maxi(0, int(config.get_value("rivals", "visits_%d" % rival_id, 0)))

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.add_to_group("city_dashboard_panels")
	layer.visible = false
	layer.name = "RivalBusinessHUD"
	layer.layer = 6
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(450, 365)
	panel.custom_minimum_size = Vector2(190, 76)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	rival_label = Label.new()
	rival_label.add_theme_font_size_override("font_size", 15)
	content.add_child(rival_label)
	district_label = Label.new()
	district_label.add_theme_font_size_override("font_size", 15)
	content.add_child(district_label)

func _refresh_hud() -> void:
	if rival_label == null:
		return
	var leader_name := "—"
	var leader_visits := -1
	for rival in rivals:
		if int(rival["visits"]) > leader_visits:
			leader_visits = int(rival["visits"])
			leader_name = String(rival["name"])
	rival_label.text = "Конкуренты: %d  •  их визиты: %d\nЛидер посещений: %s (%d)" % [rivals.size(), total_rival_visits, leader_name, maxi(0, leader_visits)]
	district_label.text = "Рейтинг делового района: %d / 100" % get_district_rating()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
