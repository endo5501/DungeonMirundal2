extends GutTest

# Verifies that PartyCombatant's HP/MP/persistent-status writes propagate
# through the wrapped Character's setters and trigger the change-notification
# signals defined on Character (hp_changed / mp_changed / statuses_changed).


var _human: RaceData
var _fighter_job: JobData
var _mage_job: JobData


func before_each():
	var loader := DataLoader.new()
	for race in loader.load_all_races():
		if race.race_name == "Human":
			_human = race
	for job in loader.load_all_jobs():
		if job.job_name == "Fighter":
			_fighter_job = job
		elif job.job_name == "Mage":
			_mage_job = job


func _make_character(name: String, job: JobData, max_hp: int = 30, max_mp: int = 0) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.race = _human
	ch.job = job
	ch.level = 1
	ch.base_stats = {&"STR": 14, &"INT": 12, &"PIE": 12, &"VIT": 12, &"AGI": 10, &"LUC": 10}
	ch.max_hp = max_hp
	ch.current_hp = max_hp
	ch.max_mp = max_mp
	ch.current_mp = max_mp
	return ch


func _make_repo_with_poison_persistent() -> StatusRepository:
	var repo := StatusRepository.new()
	var poison := StatusData.new()
	poison.id = &"poison"
	poison.scope = StatusData.Scope.PERSISTENT
	repo.register(poison)
	return repo


# --- HP signal via take_damage ---

func test_take_damage_emits_hp_changed_with_new_value():
	var ch := _make_character("Hero", _fighter_job, 20)
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	watch_signals(ch)
	pc.take_damage(5)
	assert_signal_emit_count(ch, "hp_changed", 1)
	assert_signal_emitted_with_parameters(ch, "hp_changed", [15, 20])


# --- MP signal via spend_mp ---

func test_spend_mp_emits_mp_changed_with_new_value():
	var ch := _make_character("Mage", _mage_job, 20, 5)
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	watch_signals(ch)
	assert_true(pc.spend_mp(2))
	assert_signal_emit_count(ch, "mp_changed", 1)
	assert_signal_emitted_with_parameters(ch, "mp_changed", [3, 5])


# --- statuses signal via commit_persistent_to_character ---

func test_commit_persistent_emits_statuses_changed_when_content_differs():
	var ch := _make_character("Hero", _fighter_job)
	# Character starts with no persistent statuses; commit will write [&"poison"].
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	pc.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var repo := _make_repo_with_poison_persistent()
	watch_signals(ch)
	pc.commit_persistent_to_character(repo)
	assert_signal_emit_count(ch, "statuses_changed", 1)
	assert_eq(ch.persistent_statuses.size(), 1)
	assert_eq(ch.persistent_statuses[0], &"poison")


func test_commit_persistent_does_not_emit_when_content_unchanged():
	var ch := _make_character("Hero", _fighter_job)
	# Pre-seed Character with persistent poison so commit's resulting array
	# matches the existing array.
	var seeded: Array[StringName] = [&"poison"]
	ch.persistent_statuses = seeded
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	# Constructor seeds StatusTrack from character.persistent_statuses already.
	var repo := _make_repo_with_poison_persistent()
	watch_signals(ch)
	pc.commit_persistent_to_character(repo)
	assert_signal_emit_count(ch, "statuses_changed", 0)
