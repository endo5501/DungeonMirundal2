class_name DungeonScene
extends Node3D

const EYE_HEIGHT := 1.0

var _camera: Camera3D
var _mesh_instance: MeshInstance3D
var _mesh: ImmediateMesh
var _material: StandardMaterial3D
var _dungeon_view: DungeonView
var _cell_mesh_builder: CellMeshBuilder

var wiz_map: WizMap
var player_state: PlayerState

func _ready() -> void:
	_dungeon_view = DungeonView.new()
	_cell_mesh_builder = CellMeshBuilder.new()

	_camera = Camera3D.new()
	_camera.fov = 75.0
	add_child(_camera)

	_mesh = ImmediateMesh.new()
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	add_child(_mesh_instance)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(light)

	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.4)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.1)
	ambient.environment = env
	add_child(ambient)

func refresh() -> void:
	if wiz_map == null or player_state == null:
		return
	_update_camera()
	_rebuild_mesh()

func _update_camera() -> void:
	var cell_size := CellMeshBuilder.CELL_SIZE
	var px := player_state.position.x * cell_size + cell_size / 2.0
	var pz := player_state.position.y * cell_size + cell_size / 2.0
	_camera.position = Vector3(px, EYE_HEIGHT, pz)
	_camera.rotation_degrees = Vector3(0, player_state.facing * -90.0, 0)

func _rebuild_mesh() -> void:
	var visible_cells := _dungeon_view.get_visible_cells(
		wiz_map, player_state.position, player_state.facing)

	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	for grid_pos in visible_cells:
		var cell := wiz_map.cell(grid_pos.x, grid_pos.y)
		var faces := _cell_mesh_builder.build_faces(cell, grid_pos)
		for face in faces:
			var f: CellMeshBuilder.Face = face
			for vi in [0, 1, 2, 0, 2, 3]:
				_mesh.surface_set_normal(f.normal)
				_mesh.surface_set_color(f.color)
				_mesh.surface_add_vertex(f.vertices[vi])

	_mesh.surface_end()
	_mesh_instance.set_surface_override_material(0, _material)
