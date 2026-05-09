extends GutTest

const JOB_IDS: Array[StringName] = [
	&"fighter",
	&"mage",
	&"priest",
	&"thief",
	&"bishop",
	&"samurai",
	&"lord",
	&"ninja",
]


func _make_panel() -> PartyMemberPanel:
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	return panel


func test_all_known_jobs_resolve_portrait_paths():
	var panel := _make_panel()
	if not panel.has_method("get_job_portrait_path"):
		fail_test("PartyMemberPanel should expose get_job_portrait_path")
		return
	for job_id in JOB_IDS:
		var path: String = panel.call("get_job_portrait_path", job_id)
		assert_eq(path, "res://assets/images/portraits/jobs/%s.png" % String(job_id))


func test_unknown_job_resolves_empty_portrait_path():
	var panel := _make_panel()
	if not panel.has_method("get_job_portrait_path"):
		fail_test("PartyMemberPanel should expose get_job_portrait_path")
		return
	assert_eq(panel.call("get_job_portrait_path", &"unknown_job"), "")


func test_empty_job_resolves_empty_portrait_path():
	var panel := _make_panel()
	if not panel.has_method("get_job_portrait_path"):
		fail_test("PartyMemberPanel should expose get_job_portrait_path")
		return
	assert_eq(panel.call("get_job_portrait_path", &""), "")


func test_known_job_portrait_texture_is_runtime_image_texture():
	var panel := _make_panel()
	if not panel.has_method("get_job_portrait_texture"):
		fail_test("PartyMemberPanel should expose get_job_portrait_texture")
		return
	var texture: Texture2D = panel.call("get_job_portrait_texture", &"fighter")
	assert_not_null(texture)
	assert_eq(texture.get_class(), "ImageTexture")
	assert_gt(texture.get_width(), 0)
	assert_gt(texture.get_height(), 0)
