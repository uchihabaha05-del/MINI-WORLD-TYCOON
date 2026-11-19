extends Node3D

# MINI WORLD TYCOON — Milestone 30: responsive character controller and mobile gameplay controls.
const PLAYER_SPEED := 6.0
const SPRINT_SPEED := 9.2
const JUMP_VELOCITY := 6.2
const GRAVITY := 18.0
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 26.0
const STAMINA_REGEN := 18.0
const CUSTOMER_INTERVAL := 9.0
const MAX_ACTIVE_CUSTOMERS := 6
const SHOP_ENTRANCE := Vector3(-15.0, 0.0, -8.2)

var player: CharacterBody3D
var camera_rig: Camera3D
var move_vector := Vector2.ZERO
var sprint_held := false
var stamina := STAMINA_MAX
var stamina_bar: ProgressBar
var movement_status: Label
var player_body_mesh: MeshInstance3D
var animation_clock := 0.0
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
	var wants_sprint := (sprint_held or Input.is_key_pressed(KEY_SHIFT)) and direction.length() > 0.1 and stamina > 0.5
	var current_speed := SPRINT_SPEED if wants_sprint else PLAYER_SPEED
	if wants_sprint:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
	player.velocity.x = move_toward(player.velocity.x, direction.x * current_speed, 24.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.y * current_speed, 24.0 * delta)
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = 0.0
	if Input.is_key_pressed(KEY_SPACE) and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY
	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -104.0, 104.0)
	player.global_position.z = clampf(player.global_position.z, -104.0, 104.0)
	if direction.length() > 0.08:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(direction.x, direction.y), minf(delta * 12.0, 1.0))
	animation_clock += delta * (12.0 if direction.length() > 0.1 and wants_sprint else 8.0)
	if player_body_mesh != null:
		player_body_mesh.position.y = 0.9 + (sin(animation_clock) * 0.045 if direction.length() > 0.1 and player.is_on_floor() else 0.0)
	if stamina_bar != null:
		stamina_bar.value = stamina
	if movement_status != null:
		movement_status.text = "БЕГ" if wants_sprint else ("ПРЫЖОК" if not player.is_on_floor() else "ХОДЬБА")
	if camera_rig:
		var target := player.global_position + Vector3(0, 25, 31)
		camera_rig.global_position = camera_rig.global_position.lerp(target, minf(delta * 4.0, 1.0))
		camera_rig.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "PlayerCharacter"
	player.position = Vector3(-15, 0.15, -4.0)
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	_create_ground_collision()

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
	player_body_mesh = body
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

	_add_action_button(layer, "БЕГ", Vector2(24, -150), true)
	_add_action_button(layer, "ПРЫЖОК", Vector2(24, -88), false)
	stamina_bar = ProgressBar.new()
	stamina_bar.min_value = 0
	stamina_bar.max_value = STAMINA_MAX
	stamina_bar.value = STAMINA_MAX
	stamina_bar.show_percentage = false
	stamina_bar.anchor_left = 0.0
	stamina_bar.anchor_top = 1.0
	stamina_bar.anchor_right = 0.0
	stamina_bar.anchor_bottom = 1.0
	stamina_bar.offset_left = 24
	stamina_bar.offset_top = -48
	stamina_bar.offset_right = 190
	stamina_bar.offset_bottom = -34
	layer.add_child(stamina_bar)
	movement_status = Label.new()
	movement_status.position = Vector2(24, 150)
	movement_status.text = "ХОДЬБА"
	movement_status.add_theme_font_size_override("font_size", 15)
	layer.add_child(movement_status)
	var zoom_in := Button.new()
	zoom_in.text = "＋"
	zoom_in.position = Vector2(24, 190)
	zoom_in.custom_minimum_size = Vector2(48, 44)
	zoom_in.pressed.connect(_change_camera_zoom.bind(-4.0))
	layer.add_child(zoom_in)
	var zoom_out := Button.new()
	zoom_out.text = "－"
	zoom_out.position = Vector2(78, 190)
	zoom_out.custom_minimum_size = Vector2(48, 44)
	zoom_out.pressed.connect(_change_camera_zoom.bind(4.0))
	layer.add_child(zoom_out)

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

func _create_ground_collision() -> void:
	var ground := StaticBody3D.new()
	ground.name = "WalkableCityGround"
	ground.collision_layer = 1
	ground.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(220.0, 0.5, 220.0)
	shape_node.shape = shape
	shape_node.position.y = -0.28
	ground.add_child(shape_node)
	add_child(ground)

func _add_action_button(layer: CanvasLayer, caption: String, offset: Vector2, hold: bool) -> void:
	var button := Button.new()
	button.text = caption
	button.anchor_left = 0.0
	button.anchor_top = 1.0
	button.anchor_right = 0.0
	button.anchor_bottom = 1.0
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + 112.0
	button.offset_bottom = offset.y + 52.0
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	if hold:
		button.button_down.connect(func(): sprint_held = true)
		button.button_up.connect(func(): sprint_held = false)
	else:
		button.pressed.connect(_jump)
	layer.add_child(button)

func _jump() -> void:
	if player != null and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY

func _change_camera_zoom(amount: float) -> void:
	if camera_rig != null:
		camera_rig.fov = clampf(camera_rig.fov + amount, 42.0, 78.0)

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
