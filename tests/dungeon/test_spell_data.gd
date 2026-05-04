extends GutTest


const _SPELL_IDS: Array[StringName] = [
	&"fire", &"frost", &"flame", &"blizzard",
	&"heal", &"holy", &"heala", &"allheal",
	&"katino", &"manifo", &"dios",
]


func test_spell_data_is_resource():
	var s := SpellData.new()
	assert_true(s is Resource)


func test_spell_data_default_id_is_empty():
	var s := SpellData.new()
	assert_eq(s.id, &"")


func test_spell_data_carries_required_fields():
	var s := SpellData.new()
	s.id = &"fire"
	s.display_name = "ファイア"
	s.school = SpellData.SCHOOL_MAGE
	s.level = 1
	s.mp_cost = 2
	s.target_type = SpellData.TargetType.ENEMY_ONE
	s.scope = SpellData.Scope.BATTLE_ONLY
	assert_eq(s.id, &"fire")
	assert_eq(s.display_name, "ファイア")
	assert_eq(s.school, SpellData.SCHOOL_MAGE)
	assert_eq(s.level, 1)
	assert_eq(s.mp_cost, 2)
	assert_eq(s.target_type, SpellData.TargetType.ENEMY_ONE)
	assert_eq(s.scope, SpellData.Scope.BATTLE_ONLY)


func test_target_type_enum_values_match_spec():
	assert_eq(SpellData.TargetType.ENEMY_ONE, 0)
	assert_eq(SpellData.TargetType.ENEMY_GROUP, 1)
	assert_eq(SpellData.TargetType.ALLY_ONE, 2)
	assert_eq(SpellData.TargetType.ALLY_ALL, 3)


func test_scope_enum_values_match_spec():
	assert_eq(SpellData.Scope.BATTLE_ONLY, 0)
	assert_eq(SpellData.Scope.OUTSIDE_OK, 1)


func test_id_field_is_string_name():
	var s := SpellData.new()
	s.id = &"fire"
	assert_typeof(s.id, TYPE_STRING_NAME)


# --- Loaded .tres files validation ---

func test_each_v1_spell_tres_id_matches_filename():
	for sid in _SPELL_IDS:
		var path := "res://data/spells/%s.tres" % sid
		assert_true(ResourceLoader.exists(path), "%s should exist" % path)
		var spell: SpellData = load(path) as SpellData
		assert_not_null(spell, "%s should load as SpellData" % path)
		assert_eq(spell.id, sid, "%s: id should equal filename basename" % path)


func test_each_v1_spell_school_is_recognized():
	for sid in _SPELL_IDS:
		var spell := load("res://data/spells/%s.tres" % sid) as SpellData
		assert_true(
			spell.school == SpellData.SCHOOL_MAGE or spell.school == SpellData.SCHOOL_PRIEST,
			"%s school should be mage or priest, got %s" % [sid, spell.school]
		)


func test_each_v1_spell_target_type_is_valid_enum():
	for sid in _SPELL_IDS:
		var spell := load("res://data/spells/%s.tres" % sid) as SpellData
		assert_true(
			spell.target_type in [0, 1, 2, 3],
			"%s target_type %d out of range" % [sid, spell.target_type]
		)


func test_each_v1_spell_scope_is_valid_enum():
	for sid in _SPELL_IDS:
		var spell := load("res://data/spells/%s.tres" % sid) as SpellData
		assert_true(
			spell.scope in [0, 1],
			"%s scope %d out of range" % [sid, spell.scope]
		)


func test_each_v1_spell_mp_cost_is_positive():
	for sid in _SPELL_IDS:
		var spell := load("res://data/spells/%s.tres" % sid) as SpellData
		assert_gte(spell.mp_cost, 1, "%s mp_cost should be >= 1" % sid)


func test_outside_ok_set_includes_healing_lineup_and_dios():
	var outside_ok_ids: Array[StringName] = []
	for sid in _SPELL_IDS:
		var spell := load("res://data/spells/%s.tres" % sid) as SpellData
		if spell.scope == SpellData.Scope.OUTSIDE_OK:
			outside_ok_ids.append(spell.id)
	outside_ok_ids.sort()
	# allheal / heal / heala come from add-magic-system; dios joins them in
	# add-status-sleep-and-silence as the first OUTSIDE_OK status-cure spell.
	var expected: Array[StringName] = [&"allheal", &"dios", &"heal", &"heala"]
	expected.sort()
	assert_eq(outside_ok_ids, expected)


func test_damage_spells_embed_damage_effect():
	for sid in [&"fire", &"frost", &"flame", &"blizzard", &"holy"]:
		var spell := load("res://data/spells/%s.tres" % sid) as SpellData
		assert_is(spell.effect, DamageSpellEffect, "%s effect should be DamageSpellEffect" % sid)


func test_healing_spells_embed_heal_effect():
	for sid in [&"heal", &"heala", &"allheal"]:
		var spell := load("res://data/spells/%s.tres" % sid) as SpellData
		assert_is(spell.effect, HealSpellEffect, "%s effect should be HealSpellEffect" % sid)


func test_group_spells_use_enemy_group_target_type():
	for sid in [&"flame", &"blizzard"]:
		var spell := load("res://data/spells/%s.tres" % sid) as SpellData
		assert_eq(spell.target_type, SpellData.TargetType.ENEMY_GROUP)


# --- add-status-sleep-and-silence: status spells ---

func test_katino_fields():
	var spell := load("res://data/spells/katino.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"katino")
	assert_eq(spell.school, SpellData.SCHOOL_MAGE)
	assert_eq(spell.level, 1)
	assert_eq(spell.mp_cost, 2)
	assert_eq(spell.target_type, SpellData.TargetType.ENEMY_GROUP)
	assert_eq(spell.scope, SpellData.Scope.BATTLE_ONLY)
	assert_is(spell.effect, StatusInflictSpellEffect, "katino effect should be StatusInflictSpellEffect")
	var eff := spell.effect as StatusInflictSpellEffect
	assert_eq(eff.status_id, &"sleep")
	assert_almost_eq(eff.chance, 0.6, 0.001)
	assert_eq(eff.duration, 3)


func test_manifo_fields():
	var spell := load("res://data/spells/manifo.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"manifo")
	assert_eq(spell.school, SpellData.SCHOOL_MAGE)
	assert_eq(spell.level, 1)
	assert_eq(spell.mp_cost, 2)
	assert_eq(spell.target_type, SpellData.TargetType.ENEMY_ONE)
	assert_eq(spell.scope, SpellData.Scope.BATTLE_ONLY)
	assert_is(spell.effect, StatusInflictSpellEffect, "manifo effect should be StatusInflictSpellEffect")
	var eff := spell.effect as StatusInflictSpellEffect
	assert_eq(eff.status_id, &"silence")
	assert_almost_eq(eff.chance, 0.55, 0.001)
	assert_eq(eff.duration, 4)


func test_dios_fields():
	var spell := load("res://data/spells/dios.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"dios")
	assert_eq(spell.school, SpellData.SCHOOL_PRIEST)
	assert_eq(spell.level, 1)
	assert_eq(spell.mp_cost, 2)
	assert_eq(spell.target_type, SpellData.TargetType.ALLY_ONE)
	assert_eq(spell.scope, SpellData.Scope.OUTSIDE_OK)
	assert_is(spell.effect, CureStatusSpellEffect, "dios effect should be CureStatusSpellEffect")
	var eff := spell.effect as CureStatusSpellEffect
	assert_eq(eff.status_id, &"sleep")
