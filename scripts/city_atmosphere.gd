extends Node3D

# MINI WORLD TYCOON — dynamic atmosphere milestone.
# Lightweight day/night, weather and street lighting for mobile devices.

const DAY_LENGTH := 240.0
const WEATHER_MIN_TIME := 75.0
const WEATHER_MAX_TIME := 115.0
const LAMP_POSITIONS: Array[Vector3] = [
	Vector3(-8, 0, -12), Vector3(8, 0, -12),
	Vector3(-8, 0, 12), Vector3(8, 0, 12),
	Vector3(-34, 0, -34), Vector3(34, 0, -34),
	Vector3(-34, 0, 34), Vector3(34, 0, 34),
	Vector3(-58, 0, 0), Vector3(58, 0, 0)
]
const WEATHER_NAMES: Array[String] = ["Ясно", "Облачно", "Дождь"]

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var weather_label: Label
var rain: CPUParticles3D
var street_lights: Array[OmniLight3D] = []
var elapsed := 0.0
var weather_timer := 90.0
var weather_index := 0
var day_phase := 0.28
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	world_environment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	sun = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_create_street_lights()
	_create_rain()
	_create_hud()
	_update_atmosphere()

func _process(delta: float) -> void:
	elapsed += delta
	day_phase = fposmod(day_phase + delta / DAY_LENGTH, 1.0)
	weather_timer -= delta
	if weather_timer <= 0.0:
		_change_weather()
	_update_atmosphere()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AtmosphereHUD"
	layer.layer = 2
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(190, 58)
	layer.add_child(panel)
	weather_label = Label.new()
	weather_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(weather_label)

func _create_street_lights() -> void:
	for i in range(LAMP_POSITIONS.size()):
		var lamp := OmniLight3D.new()
		lamp.name = "DynamicStreetLight_%02d" % i
		lamp.position = LAMP_POSITIONS[i] + Vector3(0, 4.65, 0)
		lamp.light_color = Color("#ffd99a")
		lamp.light_energy = 0.72
		lamp.omni_range = 12.0
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		street_lights.append(lamp)

func _create_rain() -> void:
	rain = CPUParticles3D.new()
	rain.name = "CityRain"
	rain.amount = 180
	rain.lifetime = 1.25
	rain.emitting = false
	rain.position = Vector3(0, 22, 0)
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(100, 1, 100)
	rain.direction = Vector3(0, -1, 0)
	rain.spread = 4.0
	rain.gravity = Vector3(0, -32, 0)
	rain.initial_velocity_min = 22.0
	rain.initial_velocity_max = 28.0
	rain.scale_amount_min = 0.035
	rain.scale_amount_max = 0.06
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(0.025, 0.42, 0.025)
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color("#a9c9df")
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mesh.material = drop_material
	rain.mesh = drop_mesh
	add_child(rain)

func _change_weather() -> void:
	var next_weather := rng.randi_range(0, WEATHER_NAMES.size() - 1)
	if next_weather == weather_index:
		next_weather = (next_weather + 1) % WEATHER_NAMES.size()
	weather_index = next_weather
	weather_timer = rng.randf_range(WEATHER_MIN_TIME, WEATHER_MAX_TIME)
	if rain != null:
		rain.emitting = weather_index == 2

func _update_atmosphere() -> void:
	# A smooth daylight curve: sunrise, noon, sunset and night.
	var daylight := clampf(0.5 + 0.5 * sin((day_phase - 0.25) * TAU), 0.08, 1.0)
	var night_factor := 1.0 - daylight
	var weather_dim := 0.78 if weather_index == 1 else (0.68 if weather_index == 2 else 1.0)
	if sun != null:
		sun.light_energy = lerpf(0.12, 1.15, daylight) * weather_dim
		sun.rotation_degrees.x = lerpf(-8.0, -72.0, day_phase)
		if weather_index == 2:
			sun.light_color = Color("#b9c8d5")
		else:
			sun.light_color = Color("#fff0d0").lerp(Color.WHITE, daylight)
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		var day_sky := Color("#8fc5eb")
		var night_sky := Color("#101a35")
		var overcast := Color("#788b9b")
		var sky := night_sky.lerp(day_sky, daylight)
		if weather_index > 0:
			sky = sky.lerp(overcast, 0.42 if weather_index == 1 else 0.62)
		env.background_color = sky
		env.ambient_light_color = Color("#26334d").lerp(Color("#d9e5ef"), daylight * weather_dim)
		env.ambient_light_energy = lerpf(0.28, 0.78, daylight) * weather_dim
	for lamp in street_lights:
		if is_instance_valid(lamp):
			lamp.visible = night_factor > 0.42
			lamp.light_energy = 0.72 * clampf((night_factor - 0.25) * 2.2, 0.0, 1.0)
	if weather_label != null:
		var period := "Ночь" if daylight < 0.25 else ("Вечер" if daylight < 0.48 else ("Утро" if day_phase < 0.5 else "День"))
		weather_label.text = "\u{1F305} %s  •  %02d:%02d\nПогода: %s" % [period, int(day_phase * 24.0), int(fposmod(day_phase * 1440.0, 60.0)), WEATHER_NAMES[weather_index]]
