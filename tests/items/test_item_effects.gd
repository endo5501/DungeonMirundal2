extends GutTest


class _StubCharacter:
	extends RefCounted
	var current_hp: int = 10
	var max_hp: int = 40
	var current_mp: int = 2
	var max_mp: int = 30


func _alive_wounded() -> _StubCharacter:
	var c := _StubCharacter.new()
	c.current_hp = 10
	c.max_hp = 40
	c.current_mp = 2
	c.max_mp = 30
	return c


# --- HealHpEffect ---

func test_heal_hp_restores_by_power():
	var effect := HealHpEffect.new()
	effect.power = 20
	var target := _alive_wounded()
	var result: ItemEffectResult = effect.apply([target], null)
	assert_true(result.success)
	assert_eq(target.current_hp, 30)


func test_heal_hp_clamps_at_max():
	var effect := HealHpEffect.new()
	effect.power = 20
	var target := _alive_wounded()
	target.current_hp = 35
	var result: ItemEffectResult = effect.apply([target], null)
	assert_true(result.success)
	assert_eq(target.current_hp, 40)


func test_heal_hp_fails_with_empty_targets():
	var effect := HealHpEffect.new()
	effect.power = 20
	var result: ItemEffectResult = effect.apply([], null)
	assert_false(result.success)


func test_heal_hp_does_not_request_town_return():
	var effect := HealHpEffect.new()
	effect.power = 20
	var target := _alive_wounded()
	var result: ItemEffectResult = effect.apply([target], null)
	assert_false(result.request_town_return)


# --- HealMpEffect ---

func test_heal_mp_restores_by_power():
	var effect := HealMpEffect.new()
	effect.power = 10
	var target := _alive_wounded()
	var result: ItemEffectResult = effect.apply([target], null)
	assert_true(result.success)
	assert_eq(target.current_mp, 12)


func test_heal_mp_clamps_at_max():
	var effect := HealMpEffect.new()
	effect.power = 10
	var target := _alive_wounded()
	target.current_mp = 28
	var result: ItemEffectResult = effect.apply([target], null)
	assert_true(result.success)
	assert_eq(target.current_mp, 30)


# --- EscapeToTownEffect ---

func test_escape_to_town_returns_success():
	var effect := EscapeToTownEffect.new()
	var ctx := ItemUseContext.make(true, false)
	var result: ItemEffectResult = effect.apply([], ctx)
	assert_true(result.success)


func test_escape_to_town_requests_town_return():
	var effect := EscapeToTownEffect.new()
	var ctx := ItemUseContext.make(true, false)
	var result: ItemEffectResult = effect.apply([], ctx)
	assert_true(result.request_town_return)


func test_escape_to_town_works_with_no_targets():
	var effect := EscapeToTownEffect.new()
	var ctx := ItemUseContext.make(true, true)
	var result: ItemEffectResult = effect.apply([], ctx)
	assert_true(result.success)


# --- ItemEffectResult helpers ---

func test_item_effect_result_ok_is_success():
	var r := ItemEffectResult.ok("ok")
	assert_true(r.success)
	assert_eq(r.message, "ok")


func test_item_effect_result_failure_is_not_success():
	var r := ItemEffectResult.failure("bad")
	assert_false(r.success)
	assert_eq(r.message, "bad")
