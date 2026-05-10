extends GutTest

# Verifies that DungeonScene._rebuild_mesh delegates to CellMeshBuilder.build_meshes
# (the per-batch entry point) instead of looping per-cell. This is a refactor
# regression guard: the rendered vertex count must match what build_meshes
# returns for the same visible_cells set.


func test_refresh_produces_vertex_count_matching_build_meshes():
	var scene := DungeonScene.new()
	add_child_autofree(scene)
	var wiz_map := WizMap.new(8)
	wiz_map.generate(42)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	scene.wiz_map = wiz_map
	scene.player_state = ps

	var visible: Array[Vector2i] = [Vector2i(3, 3), Vector2i(3, 2), Vector2i(2, 3)]
	scene.refresh(visible)

	var builder := CellMeshBuilder.new()
	var expected_faces: Array = builder.build_meshes(visible, wiz_map)
	# Each face contributes 6 vertices (two triangles per quad).
	var expected_vertex_count := expected_faces.size() * 6

	var arrays: Array = scene._mesh.surface_get_arrays(0)
	var actual_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(actual_vertices.size(), expected_vertex_count,
		"DungeonScene mesh vertex count should match CellMeshBuilder.build_meshes output")
