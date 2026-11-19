extends Node3D

# MINI WORLD TYCOON — Milestone 5: player movement and first customers.
const PLAYER_SPEED := 6.0
const CUSTOMER_INTERVAL := 9.0
const MAX_ACTIVE_CUSTOMERS := 6
const SHOP_ENTRANCE := Vector3(-15.0, 0.0, -8.2)

var player: CharacterBody3D
var camera_rig: Camera3D
var move_vector := Vector2.ZERO
var held_directions := {"left": false, "right": false, "up": false, "down": false}
var customer_timer: Timer
var customer_count := 0
var active_customers := 0
var customer_label: Label
var joystick_hint: Label
var store_system: Node
var tycoon_manager: Node
var rival_system: Node
var visits_by_business := {"MINI MARKET": 0, "Кафе": 0, "Ресторан": 0, "Мастерская": 0, "Магазин": 0}

func _ready() -> void:
	store_system = get_tree().current_scene.get_node_or_null("StoreGameplay")
	tycoon_manager = get_tree().current_scene.get_node_or_null("TycoonManager")
	rival_system = get_tree().current_scene.get_node_or_null("RivalBusinesses")
	_create_player()
	_create_controls()
	_create_customer_counter()
	_spawn_customer()
	_start_customer_timer()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var keyboard := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	var direction := move_vector
	if keyboard.length() > 0.05:
		direction = keyboard
	direction = direction.limit_length(1.0)
	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.y * PLAYER_SPEED
	player.velocity.y = 0.0
	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -104.0, 104.0)
	player.global_position.z = clampf(player.global_position.z, -104.0, 104.0)
	if direction.length() > 0.08:
		player.rotation.y = atan2(direction.x, direction.y)
	if camera_rig:
		var target := player.global_position + Vector3(0, 28, 34)
		camera_rig.global_position = camera_rig.global_position.lerp(target, minf(delta * 2.5, 1.0))
		camera_rig.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "PlayerCharacter"
	player.position = Vector3(-15, 0.15, -4.0)
	player.collision_layer = 2
	player.collision_mask = 0
	add_child(player)

	var body_collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	body_collision.shape = capsule
	body_collision.position.y = 0.9
	player.add_child(body_collision)

	var body := MeshInstance3D.new()
	body.name = "PlayerBody"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position.y = 0.9
	body.material_override = _material(Color("#347db7"))
	player.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "PlayerHead"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.27
	head_mesh.height = 0.54
	head.mesh = head_mesh
	head.position = Vector3(0, 1.98, 0)
	head.material_override = _material(Color("#e8b995"))
	player.add_child(head)

	var marker := Label3D.new()
	marker.text = "ВЫ"
	marker.font_size = 28
	marker.pixel_size = 0.012
	marker.position = Vector3(0, 2.5, 0)
	marker.modulate = Color("#ffffff")
	player.add_child(marker)

	camera_rig = get_tree().current_scene.get_node_or_null("Camera3D") as Camera3D

func _create_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PlayerControls"
	layer.layer = 5
	add_child(layer)

	var pad := GridContainer.new()
	pad.name = "MovementPad"
	pad.columns = 3
	pad.anchor_left = 1.0
	pad.anchor_top = 1.0
	pad.anchor_right = 1.0
	pad.anchor_bottom = 1.0
	pad.offset_left = -220
	pad.offset_top = -174
	pad.offset_right = -18
	pad.offset_bottom = -18
	pad.add_theme_constant_override("h_separation", 5)
	pad.add_theme_constant_override("v_separation", 5)
	layer.add_child(pad)

	_add_empty_cell(pad)
	_add_direction_button(pad, "▲", "up")
	_add_empty_cell(pad)
	_add_direction_button(pad, "◀", "left")
	_add_direction_button(pad, "●", "stop")
	_add_direction_button(pad, "▶", "right")
	_add_empty_cell(pad)
	_add_direction_button(pad, "▼", "down")
	_add_empty_cell(pad)

	joystick_hint = Label.new()
	joystick_hint.text = "УПРАВЛЕНИЕ"
	joystick_hint.anchor_left = 1.0
	joystick_hint.anchor_top = 1.0
	joystick_hint.anchor_right = 1.0
	joystick_hint.anchor_bottom = 1.0
	joystick_hint.offset_left = -200
	joystick_hint.offset_top = -198
	joystick_hint.offset_right = -18
	joystick_hint.offset_bottom = -178
	joystick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(joystick_hint)

func _add_empty_cell(parent: GridContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(62, 48)
	parent.add_child(spacer)

func _add_direction_button(parent: GridContainer, caption: String, direction: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(62, 48)
	button.add_theme_font_size_override("font_size", 23)
	button.focus_mode = Control.FOCUS_NONE
	if direction == "stop":
		button.pressed.connect(_clear_direction)
	else:
		button.button_down.connect(_set_direction.bind(direction, true))
		button.button_up.connect(_set_direction.bind(direction, false))
	parent.add_child(button)

func _set_direction(direction: String, active: bool) -> void:
	held_directions[direction] = active
	_update_move_vector()

func _clear_direction() -> void:
	for key in held_directions.keys():
		held_directions[key] = false
	_update_move_vector()

func _update_move_vector() -> void:
	move_vector = Vector2(
		float(held_directions["right"]) - float(held_directions["left"]),
		float(held_directions["down"]) - float(held_directions["up"])
	).limit_length(1.0)

func _create_customer_counter() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CustomerHUD"
	layer.layer = 4
	add_child(layer)
	customer_label = Label.new()
	customer_label.text = "Сейчас в городе: 0 / %d\nВсего посетило: 0" % MAX_ACTIVE_CUSTOMERS
	customer_label.position = Vector2(18, 104)
	customer_label.add_theme_font_size_override("font_size", 19)
	layer.add_child(customer_label)

func _start_customer_timer() -> void:
	customer_timer = Timer.new()
	customer_timer.wait_time = CUSTOMER_INTERVAL
	customer_timer.autostart = true
	customer_timer.timeout.connect(_spawn_customer)
	add_child(customer_timer)

func _spawn_customer() -> void:
	if active_customers >= MAX_ACTIVE_CUSTOMERS:
		return
	customer_count += 1
	active_customers += 1
	if customer_label:
		customer_label.text = "Сейчас в городе: %d / %d\\nВсего посетило: %d" % [active_customers, MAX_ACTIVE_CUSTOMERS, customer_count]
	var customer := Node3D.new()
	customer.name = "Customer_%d" % customer_count
	var spawn_position := Vector3(-15.0 + float((customer_count % 3) - 1) * 2.5, 0.0, 2.0)
	customer.position = spawn_position
	add_child(customer)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.55
	body.mesh = body_mesh
	body.position.y = 0.78
	body.material_override = _material(Color("#d18b54") if customer_count % 2 == 0 else Color("#638bba"))
	customer.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position.y = 1.68
	head.material_override = _material(Color("#e7b895"))
	customer.add_child(head)

	var destination: Dictionary = _choose_business_destination()
	var target: Vector3 = destination["position"]
	var route := [spawn_position, Vector3(target.x, 0.0, spawn_position.z), target]
	_walk_customer(customer, route, String(destination["business"]), int(destination["spend"]), spawn_position, bool(destination.get("rival", false)), int(destination.get("rival_id", -1)), int(destination.get("plot_id", -1)))

func _choose_business_destination() -> Dictionary:
	var destinations: Array[Dictionary] = [
		{"business": "MINI MARKET", "position": SHOP_ENTRANCE, "spend": 0}
	]
	if tycoon_manager != null:
		var owned_plots: Array = tycoon_manager.get("plots")
		for plot in owned_plots:
			var building: String = String(plot.get("building", ""))
			if building.is_empty() or building == "Апартаменты":
				continue
			var area: Node3D = plot.get("area") as Node3D
			if area == null:
				continue
			var entrance: Vector3 = area.global_position + Vector3(0.0, 0.0, 5.5)
			var spend: int = 18
			if building == "Ресторан":
				spend = 28
			elif building == "Мастерская":
				spend = 24
			elif building == "Кафе":
				spend = 16
			destinations.append({"business": building, "position": entrance, "spend": spend, "plot_id": int(plot["id"])})
	if rival_system != null and rival_system.has_method("get_rival_destinations"):
		for rival_destination in rival_system.call("get_rival_destinations"):
			destinations.append(rival_destination)
	var total_weight: float = 0.0
	for destination in destinations:
		var weight: float = 45.0
		if bool(destination.get("rival", false)):
			weight = float(destination.get("weight", 50.0))
		elif String(destination["business"]) != "MINI MARKET":
			var plot_id: int = int(destination.get("plot_id", -1))
			var appeal: int = int(tycoon_manager.call("get_business_appeal", plot_id)) if tycoon_manager and tycoon_manager.has_method("get_business_appeal") else 50
			weight = 10.0 + float(appeal)
		destination["weight"] = weight
		total_weight += weight
	var roll: float = randf() * total_weight
	for destination in destinations:
		roll -= float(destination["weight"])
		if roll <= 0.0:
			return destination
	return destinations[0]

func _walk_customer(customer: Node3D, path: Array, business: String, spend: int, spawn_position: Vector3, is_rival: bool, rival_id: int, plot_id: int) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	for point in path:
		var destination: Vector3 = point
		var travel_time := maxf(1.2, customer.global_position.distance_to(destination) / 4.0)
		tween.tween_property(customer, "global_position", destination, travel_time)
	tween.tween_callback(_serve_customer.bind(business, spend, is_rival, rival_id, plot_id))
	tween.tween_interval(2.0)
	tween.tween_property(customer, "global_position", spawn_position, 3.0)
	tween.tween_callback(_customer_left.bind(customer))

func _serve_customer(business: String, spend: int, is_rival: bool = false, rival_id: int = -1, plot_id: int = -1) -> void:
	if not visits_by_business.has(business):
		visits_by_business[business] = 0
	visits_by_business[business] = int(visits_by_business[business]) + 1
	_refresh_customer_label()
	if is_rival:
		if rival_system != null and rival_system.has_method("record_rival_visit"):
			rival_system.call("record_rival_visit", rival_id)
		return
	if business == "MINI MARKET":
		if store_system and store_system.has_method("serve_customer"):
			store_system.call("serve_customer")
		return
	if tycoon_manager == null:
		return
	var happiness_factor := 1.0
	var city_life := get_tree().current_scene.get_node_or_null("CityPopulation")
	if city_life and city_life.has_method("get_happiness"):
		happiness_factor = 0.7 + float(city_life.call("get_happiness")) / 200.0
	var appeal_factor := 1.0
	if plot_id >= 0 and tycoon_manager.has_method("get_business_appeal"):
		appeal_factor = 0.75 + float(tycoon_manager.call("get_business_appeal", plot_id)) / 400.0
	var revenue := roundi(float(spend) * happiness_factor * appeal_factor)
	tycoon_manager.set("cash", int(tycoon_manager.get("cash")) + revenue)
	tycoon_manager.call("_save_game")
	tycoon_manager.call("_refresh_ui")

func _customer_left(customer: Node3D) -> void:
	active_customers = maxi(0, active_customers - 1)
	_refresh_customer_label()
	if is_instance_valid(customer):
		customer.queue_free()

func _serve_customer() -> void:
	if store_system and store_system.has_method("serve_customer"):
		store_system.call("serve_customer")

func _refresh_customer_label() -> void:
	if customer_label == null:
		return
	var shop_visits := int(visits_by_business.get("MINI MARKET", 0))
	var cafe_visits := int(visits_by_business.get("Кафе", 0))
	var restaurant_visits := int(visits_by_business.get("Ресторан", 0))
	var workshop_visits := int(visits_by_business.get("Мастерская", 0))
	customer_label.text = "Гости: %d / %d  •  Всего: %d\nMINI MARKET: %d  Кафе: %d\nРесторан: %d  Мастерская: %d" % [active_customers, MAX_ACTIVE_CUSTOMERS, customer_count, shop_visits, cafe_visits, restaurant_visits, workshop_visits]

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
