extends GutTest


const _SPELL_IDS: Array[StringName] = [
	&"fire", &"frost", &"flame", &"blizzard",
	&"heal", &"holy", &"heala", &"allheal",
	&"katino", &"manifo", &"dios",
	&"poison_dart", &"madi", &"dialma",
	&"morlis", &"dilto", &"sopic",
	&"porfic", &"bamatu", &"varyu", &"maporfic",
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


func test_outside_ok_set_includes_healing_lineup_and_status_cures():
	var outside_ok_ids: Array[StringName] = []
	for sid in _SPELL_IDS:
		var spell := load("res://data/spells/%s.tres" % sid) as SpellData
		if spell.scope == SpellData.Scope.OUTSIDE_OK:
			outside_ok_ids.append(spell.id)
	outside_ok_ids.sort()
	# heal / heala / allheal: add-magic-system. dios: add-status-sleep-and-silence.
	# madi / dialma: add-status-poison-and-petrify.
	# porfic / bamatu / varyu: add-stat-modifier-spells (single-target buffs).
	var expected: Array[StringName] = [
		&"allheal", &"bamatu", &"dialma", &"dios", &"heal", &"heala",
		&"madi", &"porfic", &"varyu",
	]
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


# --- add-status-poison-and-petrify: poison_dart / madi / dialma ---

func test_poison_dart_fields():
	var spell := load("res://data/spells/poison_dart.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"poison_dart")
	assert_eq(spell.display_name, "ポイズン・ダート")
	assert_eq(spell.school, SpellData.SCHOOL_MAGE)
	assert_eq(spell.level, 1)
	assert_eq(spell.mp_cost, 3)
	assert_eq(spell.target_type, SpellData.TargetType.ENEMY_ONE)
	assert_eq(spell.scope, SpellData.Scope.BATTLE_ONLY)
	assert_is(spell.effect, DamageWithStatusSpellEffect, "poison_dart effect should be DamageWithStatusSpellEffect")
	var eff := spell.effect as DamageWithStatusSpellEffect
	assert_eq(eff.base_damage, 3)
	assert_eq(eff.spread, 1)
	assert_eq(eff.status_id, &"poison")
	assert_almost_eq(eff.inflict_chance, 0.6, 0.001)
	assert_eq(eff.status_duration, 0)


func test_madi_fields():
	var spell := load("res://data/spells/madi.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"madi")
	assert_eq(spell.display_name, "マディ")
	assert_eq(spell.school, SpellData.SCHOOL_PRIEST)
	assert_eq(spell.level, 2)
	assert_eq(spell.mp_cost, 4)
	assert_eq(spell.target_type, SpellData.TargetType.ALLY_ONE)
	assert_eq(spell.scope, SpellData.Scope.OUTSIDE_OK)
	assert_is(spell.effect, CureStatusSpellEffect, "madi effect should be CureStatusSpellEffect")
	var eff := spell.effect as CureStatusSpellEffect
	assert_eq(eff.status_id, &"poison")


func test_dialma_fields():
	var spell := load("res://data/spells/dialma.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"dialma")
	assert_eq(spell.display_name, "ディアルマ")
	assert_eq(spell.school, SpellData.SCHOOL_PRIEST)
	assert_eq(spell.level, 3)
	assert_eq(spell.mp_cost, 6)
	assert_eq(spell.target_type, SpellData.TargetType.ALLY_ONE)
	assert_eq(spell.scope, SpellData.Scope.OUTSIDE_OK)
	assert_is(spell.effect, CureStatusSpellEffect, "dialma effect should be CureStatusSpellEffect")
	var eff := spell.effect as CureStatusSpellEffect
	assert_eq(eff.status_id, &"petrify")


# --- add-stat-modifier-spells: Mage debuffs (morlis / dilto / sopic) ---

func test_morlis_fields():
	var spell := load("res://data/spells/morlis.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"morlis")
	assert_eq(spell.display_name, "モーリス")
	assert_eq(spell.school, SpellData.SCHOOL_MAGE)
	assert_eq(spell.level, 2)
	assert_eq(spell.mp_cost, 3)
	assert_eq(spell.target_type, SpellData.TargetType.ENEMY_ONE)
	assert_eq(spell.scope, SpellData.Scope.BATTLE_ONLY)
	assert_is(spell.effect, StatModSpellEffect, "morlis effect should be StatModSpellEffect")
	var eff := spell.effect as StatModSpellEffect
	assert_eq(eff.stat, &"defense")
	assert_eq(eff.delta, -2)
	assert_eq(eff.turns, 4)


func test_dilto_fields():
	var spell := load("res://data/spells/dilto.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"dilto")
	assert_eq(spell.display_name, "ディルト")
	assert_eq(spell.school, SpellData.SCHOOL_MAGE)
	assert_eq(spell.level, 2)
	assert_eq(spell.mp_cost, 3)
	assert_eq(spell.target_type, SpellData.TargetType.ENEMY_ONE)
	assert_eq(spell.scope, SpellData.Scope.BATTLE_ONLY)
	assert_is(spell.effect, StatModSpellEffect, "dilto effect should be StatModSpellEffect")
	var eff := spell.effect as StatModSpellEffect
	assert_eq(eff.stat, &"evasion")
	assert_almost_eq(float(eff.delta), -0.2, 0.001)
	assert_eq(eff.turns, 4)


func test_sopic_fields():
	var spell := load("res://data/spells/sopic.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"sopic")
	assert_eq(spell.display_name, "ソピック")
	assert_eq(spell.school, SpellData.SCHOOL_MAGE)
	assert_eq(spell.level, 2)
	assert_eq(spell.mp_cost, 3)
	assert_eq(spell.target_type, SpellData.TargetType.ENEMY_GROUP)
	assert_eq(spell.scope, SpellData.Scope.BATTLE_ONLY)
	assert_is(spell.effect, StatModSpellEffect, "sopic effect should be StatModSpellEffect")
	var eff := spell.effect as StatModSpellEffect
	assert_eq(eff.stat, &"hit")
	assert_almost_eq(float(eff.delta), -0.2, 0.001)
	assert_eq(eff.turns, 4)


# --- add-stat-modifier-spells: Priest buffs (porfic / bamatu / varyu / maporfic) ---

func test_porfic_fields():
	var spell := load("res://data/spells/porfic.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"porfic")
	assert_eq(spell.display_name, "ポーフィック")
	assert_eq(spell.school, SpellData.SCHOOL_PRIEST)
	assert_eq(spell.level, 2)
	assert_eq(spell.mp_cost, 3)
	assert_eq(spell.target_type, SpellData.TargetType.ALLY_ONE)
	assert_eq(spell.scope, SpellData.Scope.OUTSIDE_OK)
	assert_is(spell.effect, StatModSpellEffect, "porfic effect should be StatModSpellEffect")
	var eff := spell.effect as StatModSpellEffect
	assert_eq(eff.stat, &"defense")
	assert_eq(eff.delta, 2)
	assert_eq(eff.turns, 4)


func test_bamatu_fields():
	var spell := load("res://data/spells/bamatu.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"bamatu")
	assert_eq(spell.display_name, "バマツ")
	assert_eq(spell.school, SpellData.SCHOOL_PRIEST)
	assert_eq(spell.level, 2)
	assert_eq(spell.mp_cost, 3)
	assert_eq(spell.target_type, SpellData.TargetType.ALLY_ONE)
	assert_eq(spell.scope, SpellData.Scope.OUTSIDE_OK)
	assert_is(spell.effect, StatModSpellEffect, "bamatu effect should be StatModSpellEffect")
	var eff := spell.effect as StatModSpellEffect
	assert_eq(eff.stat, &"attack")
	assert_eq(eff.delta, 2)
	assert_eq(eff.turns, 4)


func test_varyu_fields():
	var spell := load("res://data/spells/varyu.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"varyu")
	assert_eq(spell.display_name, "バルユ")
	assert_eq(spell.school, SpellData.SCHOOL_PRIEST)
	assert_eq(spell.level, 2)
	assert_eq(spell.mp_cost, 3)
	assert_eq(spell.target_type, SpellData.TargetType.ALLY_ONE)
	assert_eq(spell.scope, SpellData.Scope.OUTSIDE_OK)
	assert_is(spell.effect, StatModSpellEffect, "varyu effect should be StatModSpellEffect")
	var eff := spell.effect as StatModSpellEffect
	assert_eq(eff.stat, &"hit")
	assert_almost_eq(float(eff.delta), 0.2, 0.001)
	assert_eq(eff.turns, 4)


func test_maporfic_fields():
	var spell := load("res://data/spells/maporfic.tres") as SpellData
	assert_not_null(spell)
	assert_eq(spell.id, &"maporfic")
	assert_eq(spell.display_name, "マポーフィック")
	assert_eq(spell.school, SpellData.SCHOOL_PRIEST)
	assert_eq(spell.level, 3)
	assert_eq(spell.mp_cost, 5)
	assert_eq(spell.target_type, SpellData.TargetType.ALLY_ALL)
	assert_eq(spell.scope, SpellData.Scope.BATTLE_ONLY)
	assert_is(spell.effect, StatModSpellEffect, "maporfic effect should be StatModSpellEffect")
	var eff := spell.effect as StatModSpellEffect
	assert_eq(eff.stat, &"defense")
	assert_eq(eff.delta, 2)
	assert_eq(eff.turns, 4)
