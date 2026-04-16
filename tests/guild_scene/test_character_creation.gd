extends GutTest

var _creation
var _guild: Guild
var _races: Array[RaceData]
var _jobs: Array[JobData]

func _make_race(race_name: String, base: int) -> RaceData:
	var r := RaceData.new()
	r.race_name = race_name
	r.base_str = base
	r.base_int = base
	r.base_pie = base
	r.base_vit = base
	r.base_agi = base
	r.base_luc = base
	return r

func _make_job(p_name: String, hp: int, req_str: int = 0) -> JobData:
	var j := JobData.new()
	j.job_name = p_name
	j.base_hp = hp
	j.has_magic = false
	j.base_mp = 0
	j.required_str = req_str
	j.required_int = 0
	j.required_pie = 0
	j.required_vit = 0
	j.required_agi = 0
	j.required_luc = 0
	return j

func before_each():
	_guild = Guild.new()
	_races = [_make_race("Human", 8), _make_race("Elf", 7)]
	_jobs = [_make_job("Fighter", 10), _make_job("Ninja", 8, 99)]
	_creation = CharacterCreation.new()
	_creation.setup(_guild, _races, _jobs)
	add_child_autofree(_creation)

# --- Basic structure ---

func test_has_back_requested_signal():
	assert_has_signal(_creation, "back_requested")

func test_initial_step_is_one():
	assert_eq(_creation.current_step, 1)

func test_total_steps_is_five():
	assert_eq(_creation.total_steps, 5)

# --- Step navigation ---

func test_advance_step():
	_creation.set_name_input("Hero")
	_creation.advance()
	assert_eq(_creation.current_step, 2)

func test_go_back_from_step_2():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.go_back()
	assert_eq(_creation.current_step, 1)

func test_cannot_go_back_from_step_1():
	_creation.go_back()
	assert_eq(_creation.current_step, 1)

func test_cancel_emits_back_requested():
	watch_signals(_creation)
	_creation.cancel()
	assert_signal_emitted(_creation, "back_requested")

# --- Step 1: Name input ---

func test_cannot_advance_with_empty_name():
	_creation.set_name_input("")
	_creation.advance()
	assert_eq(_creation.current_step, 1)

func test_can_advance_with_valid_name():
	_creation.set_name_input("Hero")
	_creation.advance()
	assert_eq(_creation.current_step, 2)

# --- Step 2: Race selection ---

func test_get_available_races():
	assert_eq(_creation.get_available_races().size(), 2)

func test_select_race():
	_creation.set_name_input("Hero")
	_creation.advance()  # -> step 2
	_creation.select_race(0)
	_creation.advance()  # -> step 3
	assert_eq(_creation.current_step, 3)

func test_cannot_advance_step2_without_race():
	_creation.set_name_input("Hero")
	_creation.advance()  # -> step 2
	_creation.advance()  # should stay at 2 (no race selected)
	assert_eq(_creation.current_step, 2)

# --- Step 3: Bonus point allocation ---

func test_step3_generates_bonus_points():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()  # -> step 3
	assert_gt(_creation.get_bonus_total(), 0)

func test_step3_remaining_points_equals_total_initially():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	assert_eq(_creation.get_remaining_points(), _creation.get_bonus_total())

func test_step3_increment_stat():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	var before = _creation.get_remaining_points()
	_creation.increment_stat(&"STR")
	assert_eq(_creation.get_remaining_points(), before - 1)

func test_step3_decrement_stat():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	_creation.increment_stat(&"STR")
	var before = _creation.get_remaining_points()
	_creation.decrement_stat(&"STR")
	assert_eq(_creation.get_remaining_points(), before + 1)

func test_step3_cannot_decrement_below_zero():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	_creation.decrement_stat(&"STR")
	assert_eq(_creation.get_remaining_points(), _creation.get_bonus_total())

func test_step3_cannot_increment_with_zero_remaining():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	# Allocate all points to STR
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	# Try to allocate more
	_creation.increment_stat(&"INT")
	assert_eq(_creation.get_remaining_points(), 0)

func test_step3_cannot_advance_with_remaining_points():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	_creation.advance()  # should stay at 3
	assert_eq(_creation.current_step, 3)

func test_step3_can_advance_when_all_allocated():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()
	assert_eq(_creation.current_step, 4)

func test_step3_reroll():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	_creation.increment_stat(&"STR")
	_creation.reroll_bonus()
	assert_eq(_creation.get_remaining_points(), _creation.get_bonus_total())

# --- Step 3 back resets allocation ---

func test_back_from_step3_resets_allocation():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	_creation.increment_stat(&"STR")
	_creation.go_back()  # -> step 2
	assert_eq(_creation.current_step, 2)
	_creation.select_race(0)
	_creation.advance()  # -> step 3 again
	assert_eq(_creation.get_remaining_points(), _creation.get_bonus_total())

# --- Step 4: Job selection ---

func test_step4_qualified_jobs():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)  # Human base 8
	_creation.advance()
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()  # -> step 4
	var qualified = _creation.get_qualified_jobs()
	# Fighter requires STR 0, should be qualified
	assert_true(qualified.has(0))

func test_step4_unqualified_jobs():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)  # Human base 8
	_creation.advance()
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()  # -> step 4
	var qualified = _creation.get_qualified_jobs()
	# Ninja requires STR 99, impossible to reach
	assert_false(qualified[1])

func test_step4_select_qualified_job():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()  # -> step 4
	_creation.select_job(0)  # Fighter (always qualifies)
	_creation.advance()  # -> step 5
	assert_eq(_creation.current_step, 5)

# --- Step 4 revalidation on back from step 3 ---

func test_back_from_step4_to_step3_clears_job_selection():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()  # -> step 4
	_creation.select_job(0)  # select Fighter
	_creation.go_back()  # -> step 3
	# Re-allocate all to STR again
	total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()  # -> step 4 again
	# Job selection should be cleared, cannot advance without re-selecting
	_creation.advance()  # should stay at 4
	assert_eq(_creation.current_step, 4)

func test_step4_advance_rejects_unqualified_job():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()  # -> step 4
	# Select Ninja (index 1, requires STR 99 - impossible)
	_creation.select_job(1)
	_creation.advance()
	assert_eq(_creation.current_step, 4)

# --- Step 5: Confirmation ---

func test_get_summary_returns_all_fields():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)  # Human base 8
	_creation.advance()
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()
	_creation.select_job(0)  # Fighter
	_creation.advance()  # -> step 5
	var summary = _creation.get_summary()
	assert_eq(summary["name"], "Hero")
	assert_eq(summary["level"], 1)
	assert_true(summary["hp"] > 0)
	assert_true(summary.has("stats"))
	assert_true(summary["stats"].has(&"STR"))

# --- Cancel from multiple steps ---

func test_cancel_from_step2():
	_creation.set_name_input("Hero")
	_creation.advance()  # -> step 2
	watch_signals(_creation)
	_creation.cancel()
	assert_signal_emitted(_creation, "back_requested")

func test_cancel_from_step3():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()  # -> step 3
	watch_signals(_creation)
	_creation.cancel()
	assert_signal_emitted(_creation, "back_requested")

func test_cancel_from_step4():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()  # -> step 4
	watch_signals(_creation)
	_creation.cancel()
	assert_signal_emitted(_creation, "back_requested")

# --- Bonus generator randomness ---

func test_bonus_generator_not_deterministic_across_instances():
	# Create two separate CharacterCreation instances and check they can produce different bonuses
	var creation2 = CharacterCreation.new()
	creation2.setup(_guild, _races, _jobs)
	add_child_autofree(creation2)
	# Both advance to step 3
	_creation.set_name_input("A")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	creation2.set_name_input("B")
	creation2.advance()
	creation2.select_race(0)
	creation2.advance()
	# Collect several rerolls from each
	var totals_1 := []
	var totals_2 := []
	for i in range(5):
		_creation.reroll_bonus()
		creation2.reroll_bonus()
		totals_1.append(_creation.get_bonus_total())
		totals_2.append(creation2.get_bonus_total())
	# At least one pair should differ (extremely unlikely to be all identical with random seeds)
	var all_same := true
	for i in range(5):
		if totals_1[i] != totals_2[i]:
			all_same = false
			break
	assert_false(all_same, "Two instances should not produce identical bonus sequences")

func test_step1_text_submitted_advances_to_step2():
	_creation._name_edit.text = "Hero"
	_creation._name_edit.text_submitted.emit("Hero")
	assert_eq(_creation.current_step, 2)

func test_step1_text_submitted_with_empty_name_stays():
	_creation._name_edit.text = ""
	_creation._name_edit.text_submitted.emit("")
	assert_eq(_creation.current_step, 1)

func test_step5_confirm_creates_character():
	_creation.set_name_input("Hero")
	_creation.advance()
	_creation.select_race(0)
	_creation.advance()
	var total = _creation.get_bonus_total()
	for i in range(total):
		_creation.increment_stat(&"STR")
	_creation.advance()
	_creation.select_job(0)
	_creation.advance()  # -> step 5
	watch_signals(_creation)
	_creation.confirm_creation()
	assert_eq(_guild.get_all_characters().size(), 1)
	assert_signal_emitted(_creation, "character_created")
	assert_signal_emitted(_creation, "back_requested")

# --- Step 2 skip bug ---

func test_text_submitted_does_not_skip_step2():
	# Simulate: Enter key triggers text_submitted AND _unhandled_input in same frame
	_creation._name_edit.text = "Hero"
	_creation._name_edit.text_submitted.emit("Hero")
	# At this point, step should be 2
	assert_eq(_creation.current_step, 2, "Should be on step 2 after name submission")
	# Now simulate the same Enter key arriving as _unhandled_input
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	_creation._unhandled_input(event)
	# Step 2 should NOT have been advanced - race was not selected by user
	assert_eq(_creation.current_step, 2, "Step 2 should not be skipped by Enter key propagation")

# --- Layout centering ---

func _find_center_container(node: Node) -> CenterContainer:
	for child in node.get_children():
		if child is CenterContainer:
			return child as CenterContainer
	return null

func test_creation_uses_center_container_for_layout():
	assert_not_null(_find_center_container(_creation), "CharacterCreation should use CenterContainer for centering")

func test_creation_center_container_covers_full_rect():
	var center := _find_center_container(_creation)
	assert_not_null(center)
	assert_eq(center.anchor_right, 1.0, "CenterContainer should span full width")
	assert_eq(center.anchor_bottom, 1.0, "CenterContainer should span full height")
