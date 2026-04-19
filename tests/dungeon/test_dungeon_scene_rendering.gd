extends GutTest


func _make_scene() -> DungeonScene:
	var scene := DungeonScene.new()
	add_child_autofree(scene)
	return scene


func _first_child_of_type(node: Node, type) -> Node:
	for child in node.get_children():
		if is_instance_of(child, type):
			return child
	return null


# --- Torch light ---

func test_camera_has_omni_light_child():
	var scene := _make_scene()
	var camera: Camera3D = _first_child_of_type(scene, Camera3D)
	assert_not_null(camera, "Camera3D present")
	var torch: OmniLight3D = _first_child_of_type(camera, OmniLight3D)
	assert_not_null(torch, "OmniLight3D is a child of the Camera3D")


func test_torch_has_warm_color():
	var scene := _make_scene()
	var camera: Camera3D = _first_child_of_type(scene, Camera3D)
	var torch: OmniLight3D = _first_child_of_type(camera, OmniLight3D)
	assert_not_null(torch)
	assert_gt(torch.light_color.r, torch.light_color.b + 0.1,
		"torch color is warm (R > B + 0.1)")


func test_torch_has_finite_range():
	var scene := _make_scene()
	var camera: Camera3D = _first_child_of_type(scene, Camera3D)
	var torch: OmniLight3D = _first_child_of_type(camera, OmniLight3D)
	assert_not_null(torch)
	assert_gt(torch.omni_range, 0.0, "omni_range > 0")
	assert_lt(torch.omni_range, 50.0, "omni_range is bounded, not practically infinite")


# --- World environment ---

func test_world_environment_present():
	var scene := _make_scene()
	var we: WorldEnvironment = _first_child_of_type(scene, WorldEnvironment)
	assert_not_null(we, "WorldEnvironment child exists")
	assert_not_null(we.environment, "Environment resource attached")


func test_environment_ambient_is_dim():
	var scene := _make_scene()
	var we: WorldEnvironment = _first_child_of_type(scene, WorldEnvironment)
	assert_not_null(we)
	var amb: Color = we.environment.ambient_light_color
	var lum := 0.2126 * amb.r + 0.7152 * amb.g + 0.0722 * amb.b
	assert_lt(lum, 0.1, "ambient_light_color luminance < 0.1 (dim)")


func test_environment_fog_enabled():
	var scene := _make_scene()
	var we: WorldEnvironment = _first_child_of_type(scene, WorldEnvironment)
	assert_not_null(we)
	assert_true(we.environment.fog_enabled, "depth fog enabled")


# --- Shader material ---

func test_mesh_uses_shader_material():
	var scene := _make_scene()
	var mi: MeshInstance3D = _first_child_of_type(scene, MeshInstance3D)
	assert_not_null(mi, "MeshInstance3D child present")
	var mat := mi.material_override
	assert_not_null(mat, "material_override set on MeshInstance3D")
	assert_is(mat, ShaderMaterial,
		"dungeon mesh uses a custom ShaderMaterial (not StandardMaterial3D)")


func test_environment_survives_refresh_without_wiz_map():
	# refresh() returns early without wiz_map; the scene-level environment
	# must not be rebuilt on that code path.
	var scene := _make_scene()
	var we_before: WorldEnvironment = _first_child_of_type(scene, WorldEnvironment)
	scene.refresh()
	var we_after: WorldEnvironment = _first_child_of_type(scene, WorldEnvironment)
	assert_same(we_before, we_after,
		"same WorldEnvironment instance persists across refresh()")
