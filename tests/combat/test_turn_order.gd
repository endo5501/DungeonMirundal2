extends GutTest

const TEST_SEED: int = 12345


class _StubActor extends CombatActor:
	var _name: String
	var _agility: int
	var _hp: int
	var _max: int

	func _init(p_name: String, p_agility: int, p_hp: int = 10) -> void:
		_name = p_name
		actor_name = p_name
		_agility = p_agility
		_hp = p_hp
		_max = p_hp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_agility() -> int:
		return _agility


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


# --- basic ordering ---

func test_higher_agility_comes_first():
	var a := _StubActor.new("A", 8)
	var b := _StubActor.new("B", 5)
	var order: Array = TurnOrder.order([b, a], _make_rng())
	assert_eq(order.size(), 2)
	assert_eq(order[0].actor_name, "A")
	assert_eq(order[1].actor_name, "B")


func test_three_actors_sorted_descending():
	var a := _StubActor.new("A", 3)
	var b := _StubActor.new("B", 10)
	var c := _StubActor.new("C", 7)
	var order: Array = TurnOrder.order([a, b, c], _make_rng())
	assert_eq(order[0].actor_name, "B")
	assert_eq(order[1].actor_name, "C")
	assert_eq(order[2].actor_name, "A")


# --- dead exclusion ---

func test_dead_actor_is_excluded():
	var alive := _StubActor.new("Alive", 5)
	var dead := _StubActor.new("Dead", 10)
	dead.take_damage(100)
	var order: Array = TurnOrder.order([alive, dead], _make_rng())
	assert_eq(order.size(), 1)
	assert_eq(order[0].actor_name, "Alive")


# --- tiebreak determinism ---

func test_tie_break_is_deterministic_under_fixed_seed():
	var a := _StubActor.new("A", 5)
	var b := _StubActor.new("B", 5)
	var order1: Array = TurnOrder.order([a, b], _make_rng())
	var order2: Array = TurnOrder.order([a, b], _make_rng())
	assert_eq(order1[0].actor_name, order2[0].actor_name)
	assert_eq(order1[1].actor_name, order2[1].actor_name)


func test_order_does_not_mutate_input_array():
	var a := _StubActor.new("A", 3)
	var b := _StubActor.new("B", 10)
	var input: Array = [a, b]
	TurnOrder.order(input, _make_rng())
	assert_eq(input[0].actor_name, "A")
	assert_eq(input[1].actor_name, "B")


# --- empty ---

func test_empty_input_returns_empty():
	var order: Array = TurnOrder.order([], _make_rng())
	assert_eq(order.size(), 0)
