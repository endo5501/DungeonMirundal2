extends GutTest

func test_bonus_points_at_least_5():
	var gen := BonusPointGenerator.new(12345)
	for i in range(100):
		assert_gte(gen.generate(), 5)

func test_deterministic_with_same_seed():
	var gen1 := BonusPointGenerator.new(42)
	var gen2 := BonusPointGenerator.new(42)
	var results1: Array[int] = []
	var results2: Array[int] = []
	for i in range(20):
		results1.append(gen1.generate())
		results2.append(gen2.generate())
	assert_eq(results1, results2)

func test_different_seeds_produce_different_results():
	var gen1 := BonusPointGenerator.new(100)
	var gen2 := BonusPointGenerator.new(200)
	var results1: Array[int] = []
	var results2: Array[int] = []
	for i in range(20):
		results1.append(gen1.generate())
		results2.append(gen2.generate())
	assert_ne(results1, results2)

func test_average_in_expected_range():
	var gen := BonusPointGenerator.new(99999)
	var total := 0
	var count := 10000
	for i in range(count):
		total += gen.generate()
	var average := float(total) / float(count)
	assert_gte(average, 6.0, "Average should be >= 6.0")
	assert_lte(average, 9.0, "Average should be <= 9.0")

func test_high_bonus_is_rare():
	var gen := BonusPointGenerator.new(77777)
	var high_count := 0
	var count := 10000
	for i in range(count):
		if gen.generate() >= 15:
			high_count += 1
	var ratio := float(high_count) / float(count)
	assert_lt(ratio, 0.05, "Less than 5%% of results should be >= 15")
