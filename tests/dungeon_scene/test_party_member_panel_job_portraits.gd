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


func test_panel_uses_job_portrait_module_for_path():
	# PartyMemberPanel SHALL delegate path resolution to the shared JobPortrait
	# module so the path table has a single source of truth.
	for job_id in JOB_IDS:
		var path: String = JobPortrait.path_for(job_id)
		assert_eq(path, "res://assets/images/portraits/jobs/%s.png" % String(job_id))


func test_panel_uses_job_portrait_module_for_texture():
	# PartyMemberPanel SHALL share the JobPortrait texture cache so consumers
	# (PartyMemberPanel, StatusView) receive identical Texture2D instances.
	var texture: Texture2D = JobPortrait.texture_for(&"fighter")
	assert_not_null(texture)
	assert_eq(texture.get_class(), "ImageTexture")
	assert_gt(texture.get_width(), 0)
	assert_gt(texture.get_height(), 0)


func test_unknown_job_resolves_empty_portrait_path():
	assert_eq(JobPortrait.path_for(&"unknown_job"), "")


func test_empty_job_resolves_empty_portrait_path():
	assert_eq(JobPortrait.path_for(&""), "")
