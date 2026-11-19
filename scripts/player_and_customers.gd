extends Node3D

# MINI WORLD TYCOON — Milestone 32: analog controls, orbit camera and animated crowds.
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
var arm_left: Node3D
var arm_right: Node3D
var leg_left: Node3D
var leg_right: Node3D
var interaction_button: Button
var interaction_label: Label
var nearby_plot_id := -1
var near_shop := false
var camera_yaw := 0.0
var camera_pitch := 34.0
var camera_distance := 40.0
var camera_touch_index := -1
var last_camera_touch := Vector2.ZERO
var joystick_touch_index := -1
var joystick_center := Vector2.ZERO
var joystick_base: Panel
var joystick_knob: Panel
var customer_animation_clock := 0.0
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

func _process(delta: float) -> void:
	customer_animation_clock += delta * 7.0
	for customer in get_children():
		if not customer.name.begins_with("Customer_"):
			continue
		var phase := customer_animation_clock + float(customer.get_instance_id() % 10)
		var swing := sin(phase) * 0.32
		var arm_a := customer.get_node_or_null("ArmLeft") as Node3D
		var arm_b := customer.get_node_or_null("ArmRight") as Node3D
		var leg_a := customer.get_node_or_null("LegLeft") as Node3D
		var leg_b := customer.get_node_or_null("LegRight") as Node3D
		if arm_a != null and arm_b != null and leg_a != null and leg_b != null:
			arm_a.rotation.x = swing
			arm_b.rotation.x = -swing
			leg_a.rotation.x = -swing
			leg_b.rotation.x = swing

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
	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -104.0, 104.0)
	player.global_position.z = clampf(player.global_position.z, -104.0, 104.0)
	if direction.length() > 0.08:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(direction.x, direction.y), minf(delta * 12.0, 1.0))
	animation_clock += delta * (12.0 if direction.length() > 0.1 and wants_sprint else 8.0)
	if player_body_mesh != null:
		player_body_mesh.position.y = 0.9 + (sin(animation_clock) * 0.045 if direction.length() > 0.1 and player.is_on_floor() else 0.0)
	var swing := sin(animation_clock) * (0.55 if wants_sprint else 0.38) if direction.length() > 0.1 and player.is_on_floor() else 0.0
	if arm_left != null:
		arm_left.rotation.x = swing
		arm_right.rotation.x = -swing
		leg_left.rotation.x = -swing
		leg_right.rotation.x = swing
	_update_nearby_interaction()
	if stamina_bar != null:
		stamina_bar.value = stamina
	if movement_status != null:
		movement_status.text = "БЕГ" if wants_sprint else ("ПРЫЖОК" if not player.is_on_floor() else "ХОДЬБА")
	if camera_rig:
		var yaw := deg_to_rad(camera_yaw)
		var pitch := deg_to_rad(camera_pitch)
		var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * camera_distance
		var focus := player.global_position + Vector3(0, 1.0, 0)
		var target := focus + offset
		camera_rig.global_position = camera_rig.global_position.lerp(target, minf(delta * 6.0, 1.0))
		camera_rig.look_at(focus, Vector3.UP)

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

	_create_limbs()
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

	_create_virtual_joystick(layer)
	_add_action_button(layer, "БЕГ", Vector2(-250, -150), true, true)
	_add_action_button(layer, "ПРЫЖОК", Vector2(-130, -150), false, true)
	interaction_button = Button.new()
	interaction_button.text = "ВЗАИМОДЕЙСТВИЕ"
	interaction_button.anchor_left = 1.0
	interaction_button.anchor_top = 1.0
	interaction_button.anchor_right = 1.0
	interaction_button.anchor_bottom = 1.0
	interaction_button.offset_left = -250
	interaction_button.offset_top = -88
	interaction_button.offset_right = -18
	interaction_button.offset_bottom = -32
	interaction_button.disabled = true
	interaction_button.pressed.connect(_interact)
	layer.add_child(interaction_button)
	interaction_label = Label.new()
	interaction_label.anchor_left = 1.0
	interaction_label.anchor_top = 1.0
	interaction_label.anchor_right = 1.0
	interaction_label.anchor_bottom = 1.0
	interaction_label.offset_left = -250
	interaction_label.offset_top = -118
	interaction_label.offset_right = -18
	interaction_label.offset_bottom = -92
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.text = "Подойди к объекту"
	layer.add_child(interaction_label)
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


func _create_virtual_joystick(layer: CanvasLayer) -> void:
	joystick_base = Panel.new()
	joystick_base.name = "AnalogJoystick"
	joystick_base.anchor_left = 0.0
	joystick_base.anchor_top = 1.0
	joystick_base.anchor_right = 0.0
	joystick_base.anchor_bottom = 1.0
	joystick_base.offset_left = 26
	joystick_base.offset_top = -190
	joystick_base.offset_right = 182
	joystick_base.offset_bottom = -34
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.08, 0.13, 0.2, 0.48)
	base_style.set_corner_radius_all(80)
	base_style.set_border_width_all(3)
	base_style.border_color = Color(0.82, 0.91, 1.0, 0.7)
	joystick_base.add_theme_stylebox_override("panel", base_style)
	layer.add_child(joystick_base)
	joystick_knob = Panel.new()
	joystick_knob.size = Vector2(66, 66)
	joystick_knob.position = Vector2(45, 45)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.25, 0.58, 0.86, 0.94)
	knob_style.set_corner_radius_all(40)
	knob_style.set_border_width_all(2)
	knob_style.border_color = Color.WHITE
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_base.add_child(joystick_knob)
	var screen := get_viewport().get_visible_rect().size
	joystick_center = Vector2(104, screen.y - 112)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_jump()
	var screen := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if joystick_touch_index == -1 and event.position.x < screen.x * 0.43 and event.position.y > screen.y * 0.55:
				joystick_touch_index = event.index
				_update_joystick(event.position)
			elif camera_touch_index == -1 and event.position.x > screen.x * 0.48 and event.position.y < screen.y - 210.0:
				camera_touch_index = event.index
				last_camera_touch = event.position
		else:
			if event.index == joystick_touch_index:
				joystick_touch_index = -1
				move_vector = Vector2.ZERO
				if joystick_knob != null:
					joystick_knob.position = Vector2(45, 45)
			if event.index == camera_touch_index:
				camera_touch_index = -1
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch_index:
			_update_joystick(event.position)
		elif event.index == camera_touch_index:
			var drag := event.position - last_camera_touch
			camera_yaw = wrapf(camera_yaw - drag.x * 0.22, -180.0, 180.0)
			camera_pitch = clampf(camera_pitch + drag.y * 0.12, 18.0, 62.0)
			last_camera_touch = event.position

func _update_joystick(screen_position: Vector2) -> void:
	var offset := screen_position - joystick_center
	move_vector = (offset / 62.0).limit_length(1.0)
	if joystick_knob != null:
		joystick_knob.position = Vector2(45, 45) + move_vector * 42.0

func _create_limbs() -> void:
	arm_left = _make_limb("ArmLeft", Vector3(-0.48, 1.5, 0), 0.14, 0.72, Color("#28638f"))
	arm_right = _make_limb("ArmRight", Vector3(0.48, 1.5, 0), 0.14, 0.72, Color("#28638f"))
	leg_left = _make_limb("LegLeft", Vector3(-0.2, 0.48, 0), 0.17, 0.82, Color("#263d55"))
	leg_right = _make_limb("LegRight", Vector3(0.2, 0.48, 0), 0.17, 0.82, Color("#263d55"))

func _make_limb(label: String, offset: Vector3, radius: float, height: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = offset
	player.add_child(pivot)
	var mesh_node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_node.mesh = mesh
	mesh_node.position.y = -height * 0.38
	mesh_node.material_override = _material(color)
	pivot.add_child(mesh_node)
	return pivot

func _update_nearby_interaction() -> void:
	nearby_plot_id = -1
	near_shop = player.global_position.distance_to(SHOP_ENTRANCE) < 8.0
	var best_distance := 8.0
	if tycoon_manager != null:
		var plots: Array = tycoon_manager.get("plots")
		for i in range(plots.size()):
			var plot_area := plots[i].get("area") as Node3D
			if plot_area == null:
				continue
			var distance := player.global_position.distance_to(plot_area.global_position)
			if distance < best_distance:
				best_distance = distance
				nearby_plot_id = i
	if interaction_button == null:
		return
	interaction_button.disabled = not near_shop and nearby_plot_id < 0
	if near_shop:
		interaction_button.text = "ОТКРЫТЬ МАГАЗИН"
		interaction_label.text = "Управление MINI MARKET"
	elif nearby_plot_id >= 0:
		interaction_button.text = "ВЫБРАТЬ УЧАСТОК"
		interaction_label.text = "Участок %d" % (nearby_plot_id + 1)
	else:
		interaction_button.text = "ВЗАИМОДЕЙСТВИЕ"
		interaction_label.text = "Подойди к магазину или участку"

func _interact() -> void:
	if near_shop and store_system != null and store_system.has_method("toggle_shop_panel"):
		store_system.call("toggle_shop_panel")
	elif nearby_plot_id >= 0 and tycoon_manager != null:
		tycoon_manager.call("_select_plot", nearby_plot_id)

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

func _add_action_button(layer: CanvasLayer, caption: String, offset: Vector2, hold: bool, from_right: bool = false) -> void:
	var button := Button.new()
	button.text = caption
	button.anchor_left = 1.0 if from_right else 0.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0 if from_right else 0.0
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
		camera_distance = clampf(camera_distance + amount * 0.7, 22.0, 58.0)
		camera_rig.fov = clampf(camera_rig.fov + amount * 0.35, 42.0, 78.0)

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
	_add_customer_limb(customer, "ArmLeft", Vector3(-0.38, 1.15, 0), 0.11, 0.58)
	_add_customer_limb(customer, "ArmRight", Vector3(0.38, 1.15, 0), 0.11, 0.58)
	_add_customer_limb(customer, "LegLeft", Vector3(-0.17, 0.42, 0), 0.13, 0.62)
	_add_customer_limb(customer, "LegRight", Vector3(0.17, 0.42, 0), 0.13, 0.62)

	var destination: Dictionary = _choose_business_destination()
	var target: Vector3 = destination["position"]
	var route := [spawn_position, Vector3(target.x, 0.0, spawn_position.z), target]
	_walk_customer(customer, route, String(destination["business"]), int(destination["spend"]), spawn_position, bool(destination.get("rival", false)), int(destination.get("rival_id", -1)), int(destination.get("plot_id", -1)))

func _add_customer_limb(parent: Node3D, node_name: String, offset: Vector3, radius: float, height: float) -> void:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = offset
	parent.add_child(pivot)
	var mesh_node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_node.mesh = mesh
	mesh_node.position.y = -height * 0.36
	mesh_node.material_override = _material(Color("#638bba"))
	pivot.add_child(mesh_node)

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
