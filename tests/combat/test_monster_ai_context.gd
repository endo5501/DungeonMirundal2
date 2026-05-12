extends GutTest


func test_context_exposes_required_fields():
	var party: Array = []
	var monsters: Array = []
	var spell_repo := SpellRepository.new()
	var turn_engine := TurnEngine.new()
	var ctx := MonsterAiContext.new(party, monsters, spell_repo, turn_engine)
	assert_eq(ctx.party, party)
	assert_eq(ctx.monsters, monsters)
	assert_eq(ctx.spell_repo, spell_repo)
	assert_eq(ctx.turn_engine, turn_engine)


func test_context_is_refcounted():
	var ctx := MonsterAiContext.new([], [], null, null)
	assert_true(ctx is RefCounted)
