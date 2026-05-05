extends GutTest

# PartyMemberPanel animation triggers (combat-party-reactions design D3/D4):
#   - hp_changed delta < 0 → shake Tween
#   - hp_changed delta > 0 → heal flash Tween
#   - hp_changed delta = 0 → no Tween
#   - play_lift_animation() → lift Tween
#   - play_die_animation() → modulate.a Tween toward 0.7
#   - revival (prev_hp 0 → positive) → modulate.a restored to 1.0
#   - consecutive same-kind hits override the previous Tween (kill + new)


func _make_character(name: String, hp: int, max_hp: int = 0) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.level = 1
	ch.max_hp = max_hp if max_hp > 0 else hp
	ch.current_hp = hp
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func _make_panel() -> PartyMemberPanel:
	var p := PartyMemberPanel.new()
	add_child_autofree(p)
	return p


# --- API exists ---

func test_panel_exposes_layout_position_field():
	var p := _make_panel()
	# default is Vector2.ZERO until PartyDisplay assigns
	assert_eq(p._layout_position, Vector2.ZERO)


func test_panel_exposes_play_lift_animation():
	var p := _make_panel()
	assert_true(p.has_method("play_lift_animation"))


func test_panel_exposes_play_die_animation():
	var p := _make_panel()
	assert_true(p.has_method("play_die_animation"))


# --- shake on damage ---

func test_hp_decrease_starts_shake_tween():
	var ch := _make_character("Hero", 20)
	var p := _make_panel()
	p.bind_character(ch)
	assert_null(p._active_shake_tween)
	ch.current_hp = 15
	assert_not_null(p._active_shake_tween)
	assert_true(p._active_shake_tween.is_valid())


func test_hp_increase_does_not_start_shake_tween():
	var ch := _make_character("Hero", 10, 20)
	var p := _make_panel()
	p.bind_character(ch)
	ch.current_hp = 15
	assert_null(p._active_shake_tween)


func test_hp_unchanged_starts_no_tween():
	var ch := _make_character("Hero", 20)
	var p := _make_panel()
	p.bind_character(ch)
	ch.current_hp = 20
	assert_null(p._active_shake_tween)
	assert_null(p._active_flash_tween)


func test_consecutive_damage_replaces_active_shake():
	var ch := _make_character("Hero", 20)
	var p := _make_panel()
	p.bind_character(ch)
	ch.current_hp = 15
	var first = p._active_shake_tween
	ch.current_hp = 10
	# A new tween instance replaces the first one.
	assert_ne(p._active_shake_tween, first)
	assert_true(p._active_shake_tween.is_valid())


# --- heal flash on heal ---

func test_hp_increase_starts_flash_tween():
	var ch := _make_character("Hero", 5, 20)
	var p := _make_panel()
	p.bind_character(ch)
	ch.current_hp = 12
	assert_not_null(p._active_flash_tween)
	assert_true(p._active_flash_tween.is_valid())


# --- lift ---

func test_play_lift_animation_starts_lift_tween():
	var p := _make_panel()
	p.play_lift_animation()
	assert_not_null(p._active_lift_tween)
	assert_true(p._active_lift_tween.is_valid())


func test_consecutive_lift_replaces_active_tween():
	var p := _make_panel()
	p.play_lift_animation()
	var first = p._active_lift_tween
	p.play_lift_animation()
	assert_ne(p._active_lift_tween, first)


# --- die fade ---

func test_play_die_animation_starts_modulate_tween():
	var p := _make_panel()
	p.play_die_animation()
	assert_not_null(p._active_die_tween)
	assert_true(p._active_die_tween.is_valid())


# --- revival restores modulate ---

func test_revival_restores_modulate_alpha():
	var ch := _make_character("Hero", 0, 20)
	var p := _make_panel()
	p.bind_character(ch)
	# Enter "dead" state visually.
	p.modulate.a = 0.7
	# HP transitions from 0 → positive: revival.
	ch.current_hp = 5
	assert_eq(p.modulate.a, 1.0)
