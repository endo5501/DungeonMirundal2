extends GutTest

func test_generate_returns_non_empty_string():
	var gen := DungeonNameGenerator.new()
	var name := gen.generate()
	assert_typeof(name, TYPE_STRING)
	assert_gt(name.length(), 0)

func test_generate_produces_variety():
	var gen := DungeonNameGenerator.new()
	var names := {}
	for i in range(10):
		names[gen.generate()] = true
	assert_gte(names.size(), 2, "At least 2 distinct names from 10 generations")

func test_generate_with_seed_is_reproducible():
	var gen1 := DungeonNameGenerator.new()
	var gen2 := DungeonNameGenerator.new()
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 123
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 123
	assert_eq(gen1.generate_with_rng(rng1), gen2.generate_with_rng(rng2))
