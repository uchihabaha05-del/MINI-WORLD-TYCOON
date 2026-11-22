extends Node3D

# MINI WORLD TYCOON — lightweight visual polish pass for Android.
# Adds readable street furniture, trees, industrial details and warm local lighting.
const METAL := Color("#46535b")
const WOOD := Color("#956b49")
const LEAF_DARK := Color("#3f794b")
const LEAF_LIGHT := Color("#69a85e")
const LAMP_GLOW := Color("#ffe5a6")

func _ready() -> void:
	_add_street_lamps()
	_add_roadside_trees()
	_add_public_benches()
	_add_industrial_details()
	_add_factory_lighting()
	_add_shop_lighting()
	_add_plaza_accents()

func _add_street_lamps() -> void:
	var positions: Array[Vector3] = [
		Vector3(-8, 0, -12), Vector3(8, 0, -12),
		Vector3(-8, 0, 12), Vector3(8, 0, 12),
		Vector3(-34, 0, -34), Vector3(34, 0, -34),
		Vector3(-34, 0, 34), Vector3(34, 0, 34),
		Vector3(-58, 0, 0), Vector3(58, 0, 0)
	]
	for i in range(positions.size()):
		var root := Node3D.new()
		root.name = "StreetLamp_%02d" % i
		root.position = positions[i]
		add_child(root)
		_cylinder(root, 0.08, 0.08, 5.0, Vector3(0, 2.5, 0), METAL, "Pole")
		_cylinder(root, 0.12, 0.12, 0.16, Vector3(0, 4.95, 0), Color("#7b8990"), "LampHousing")
		_sphere(root, 0.23, Vector3(0, 4.82, 0), LAMP_GLOW, "LampBulb")
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.9, 0.09, 0.09)
		arm.mesh = arm_mesh
		arm.position = Vector3(0.36, 4.9, 0)
		arm.material_override = _mat(METAL)
		root.add_child(arm)
		if i < 4:
			var light := OmniLight3D.new()
			light.position = Vector3(0, 4.7, 0)
			light.light_color = Color("#ffdca0")
			light.light_energy = 0.35
			light.omni_range = 8.0
			light.shadow_enabled = false
			root.add_child(light)

func _add_roadside_trees() -> void:
	var positions: Array[Vector3] = [
		Vector3(-49, 0, -24), Vector3(-49, 0, 24),
		Vector3(49, 0, -24), Vector3(49, 0, 24),
		Vector3(-63, 0, -62), Vector3(-47, 0, -62),
		Vector3(47, 0, 62), Vector3(63, 0, 62),
		Vector3(-92, 0, 12), Vector3(92, 0, -12),
		Vector3(-12, 0, 92), Vector3(12, 0, -92)
	]
	for i in range(positions.size()):
		var tree := Node3D.new()
		tree.name = "DecorativeTree_%02d" % i
		tree.position = positions[i]
		add_child(tree)
		_cylinder(tree, 0.24, 0.18, 2.2, Vector3(0, 1.1, 0), WOOD, "Trunk")
		_sphere(tree, 1.35, Vector3(0, 2.6, 0), LEAF_DARK, "CanopyLower")
		_sphere(tree, 1.05, Vector3(0.35, 3.25, 0.1), LEAF_LIGHT, "CanopyUpper")

func _add_public_benches() -> void:
	var positions: Array[Vector3] = [Vector3(-8, 0, 48), Vector3(39, 0, 48), Vector3(8, 0, 58), Vector3(-39, 0, -48)]
	for i in range(positions.size()):
		var bench := Node3D.new()
		bench.name = "StreetBench_%d" % i
		bench.position = positions[i]
		add_child(bench)
		_box(bench, Vector3(2.4, 0.18, 0.72), Vector3(0, 0.65, 0), WOOD, "Seat")
		_box(bench, Vector3(2.4, 0.8, 0.16), Vector3(0, 1.05, -0.28), WOOD, "Back")
		for x in [-0.85, 0.85]:
			_box(bench, Vector3(0.14, 0.62, 0.14), Vector3(x, 0.32, 0), METAL, "Leg")

func _add_industrial_details() -> void:
	var production := get_parent().get_node_or_null("ProductionSystem")
	if production == null:
		return
	for i in range(3):
		var factory := production.get_node_or_null("Factory_%d" % i) as Node3D
		if factory == null:
			continue
		var detail := Node3D.new()
		detail.name = "IndustrialDetail"
		factory.add_child(detail)
		_box(detail, Vector3(2.4, 0.7, 1.8), Vector3(3.0, 5.9, -2.0), Color("#697a82"), "RoofVent")
		_box(detail, Vector3(0.18, 1.8, 0.18), Vector3(3.0, 7.1, -2.0), Color("#89969a"), "VentPipe")
		for crate_index in range(3):
			_box(detail, Vector3(1.1, 0.85, 1.0), Vector3(-3.6 + float(crate_index) * 1.25, 0.45, 5.4), WOOD, "ShippingCrate")
		_box(detail, Vector3(0.22, 2.2, 0.22), Vector3(-5.2, 1.1, 2.0), METAL, "SafetyPost")
		_box(detail, Vector3(0.22, 2.2, 0.22), Vector3(5.2, 1.1, 2.0), METAL, "SafetyPost")

func _add_factory_lighting() -> void:
	var production := get_parent().get_node_or_null("ProductionSystem")
	if production == null:
		return
	for i in range(3):
		var factory := production.get_node_or_null("Factory_%d" % i) as Node3D
		if factory == null:
			continue
		var lamp := OmniLight3D.new()
		lamp.name = "FactoryEntranceLight"
		lamp.position = Vector3(0, 4.0, 5.0)
		lamp.light_color = Color("#ffe2b2")
		lamp.light_energy = 0.45
		lamp.omni_range = 9.0
		lamp.shadow_enabled = false
		factory.add_child(lamp)

func _add_shop_lighting() -> void:
	var shop := get_parent().get_node_or_null("StoreGameplay")
	if shop == null:
		return
	for x in [-5.0, 0.0, 5.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "ShopCeilingLight"
		lamp.position = Vector3(x, 5.8, -12.0)
		lamp.light_color = Color("#fff0d4")
		lamp.light_energy = 0.28
		lamp.omni_range = 7.0
		lamp.shadow_enabled = false
		shop.add_child(lamp)

func _add_plaza_accents() -> void:
	for i in range(4):
		var planter := Node3D.new()
		planter.name = "PlazaPlanter_%d" % i
		planter.position = Vector3(-5.0 + float(i) * 3.3, 0, 40)
		add_child(planter)
		_box(planter, Vector3(1.8, 0.45, 1.4), Vector3(0, 0.23, 0), Color("#987451"), "Planter")
		_sphere(planter, 0.62, Vector3(0, 0.8, 0), LEAF_LIGHT, "Shrub")

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, node_name: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _mat(color)
	parent.add_child(mesh_instance)

func _cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color, node_name: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _mat(color)
	parent.add_child(mesh_instance)

func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, node_name: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _mat(color)
	parent.add_child(mesh_instance)

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
