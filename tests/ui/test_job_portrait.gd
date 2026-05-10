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


func test_get_path_returns_expected_for_known_job():
	for job_id in JOB_IDS:
		var path: String = JobPortrait.path_for(job_id)
		assert_eq(path, "res://assets/images/portraits/jobs/%s.png" % String(job_id))


func test_get_path_returns_empty_for_unknown_job():
	assert_eq(JobPortrait.path_for(&"unknown_job"), "")


func test_get_path_returns_empty_for_empty_id():
	assert_eq(JobPortrait.path_for(&""), "")


func test_get_texture_returns_runtime_image_texture_for_known_job():
	var texture: Texture2D = JobPortrait.texture_for(&"fighter")
	assert_not_null(texture)
	assert_eq(texture.get_class(), "ImageTexture")
	assert_gt(texture.get_width(), 0)
	assert_gt(texture.get_height(), 0)


func test_get_texture_returns_null_for_unknown_job():
	var texture: Texture2D = JobPortrait.texture_for(&"unknown_job")
	assert_null(texture)


func test_get_texture_caches_same_instance():
	var first: Texture2D = JobPortrait.texture_for(&"mage")
	var second: Texture2D = JobPortrait.texture_for(&"mage")
	assert_not_null(first)
	# Same cached instance returned on repeat call.
	assert_same(first, second)
