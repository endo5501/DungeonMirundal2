extends Control

# Saves tab UI. Owns a SaveSession and binds form widgets to its setters.
# Keeps the UI layer thin: every mutation goes through SaveSession (so the
# logic is exercised by tests rather than driven from here).

const _RepoPicker := preload("res://tools/dev_console/shared/repository_picker.gd")

# Stat keys in the order they are displayed; mirrors Character.STAT_KEYS.
const _STAT_KEYS: Array[StringName] = [&"STR", &"INT", &"PIE", &"VIT", &"AGI", &"LUC"]

# Slot enum order in EquipSlot (1..6); SLOT_KEYS gives the json field names.
const _EQUIP_SLOTS: Array[int] = [
	1,  # WEAPON
	2,  # ARMOR
	3,  # HELMET
	4,  # SHIELD
	5,  # GAUNTLET
	6,  # ACCESSORY
]
const _SLOT_LABELS: Array[String] = [
	"Weapon", "Armor", "Helmet", "Shield", "Gauntlet", "Accessory",
]

@onready var _slot_picker: OptionButton = %SlotPicker
@onready var _reload_button: Button = %ReloadButton
@onready var _save_button: Button = %SaveButton
@onready var _status_label: Label = %StatusLabel
@onready var _party_list: ItemList = %PartyList
@onready var _name_edit: LineEdit = %NameEdit
@onready var _race_picker: OptionButton = %RacePicker
@onready var _job_picker: OptionButton = %JobPicker
@onready var _level_spin: SpinBox = %LevelSpin
@onready var _exp_spin: SpinBox = %ExpSpin
@onready var _current_hp_spin: SpinBox = %CurrentHpSpin
@onready var _max_hp_spin: SpinBox = %MaxHpSpin
@onready var _current_mp_spin: SpinBox = %CurrentMpSpin
@onready var _max_mp_spin: SpinBox = %MaxMpSpin
@onready var _stat_spins: Array[SpinBox] = [
	%StrSpin, %IntSpin, %PieSpin, %VitSpin, %AgiSpin, %LucSpin,
]
@onready var _spell_grid: GridContainer = %SpellGrid
@onready var _equip_grid: GridContainer = %EquipGrid
@onready var _gold_spin: SpinBox = %GoldSpin
@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _add_item_picker: OptionButton = %AddItemPicker
@onready var _add_item_button: Button = %AddItemButton
@onready var _rebuild_spells_button: Button = %RebuildSpellsButton
@onready var _recompute_hp_button: Button = %RecomputeHpButton
@onready var _set_level_button: Button = %SetLevelButton

var _session: SaveSession = null
var _race_resources: Array = []
var _job_resources: Array = []
var _selected_char: int = -1
# True while we're refreshing the form from session state, so signal handlers
# can ignore "user-initiated" change events.
var _suppress_signals: bool = false


func _ready() -> void:
	_session = SaveSession.new()
	_wire_signals()
	_populate_static_pickers()
	refresh_slot_list()
	_set_status("")
	_set_form_enabled(false)


func _wire_signals() -> void:
	_reload_button.pressed.connect(_on_reload_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_party_list.item_selected.connect(_on_character_selected)
	_name_edit.text_changed.connect(_on_name_changed)
	_race_picker.item_selected.connect(_on_race_selected)
	_job_picker.item_selected.connect(_on_job_selected)
	_level_spin.value_changed.connect(_on_level_value_changed)
	_set_level_button.pressed.connect(_on_set_level_pressed)
	_exp_spin.value_changed.connect(_on_exp_changed)
	_current_hp_spin.value_changed.connect(_on_current_hp_changed)
	_max_hp_spin.value_changed.connect(_on_max_hp_changed)
	_current_mp_spin.value_changed.connect(_on_current_mp_changed)
	_max_mp_spin.value_changed.connect(_on_max_mp_changed)
	for i in range(_stat_spins.size()):
		var key := _STAT_KEYS[i]
		var spin: SpinBox = _stat_spins[i]
		spin.value_changed.connect(func(v: float) -> void: _on_stat_changed(key, int(v)))
	_gold_spin.value_changed.connect(_on_gold_changed)
	_add_item_button.pressed.connect(_on_add_item_pressed)
	_rebuild_spells_button.pressed.connect(_on_rebuild_spells_pressed)
	_recompute_hp_button.pressed.connect(_on_recompute_hp_pressed)


func _populate_static_pickers() -> void:
	# Race / Job dropdowns load from data dirs; cache the resources so we can
	# resolve a selection back to a StringName id.
	_race_resources = _RepoPicker.fill_from_dir(_race_picker, "res://data/races/")
	_job_resources = _RepoPicker.fill_from_dir(_job_picker, "res://data/jobs/")
	# Add-item dropdown is filled from the ItemRepository (always available).
	_RepoPicker.fill_with_items(_add_item_picker, _session.get_item_repository())


func refresh_slot_list() -> void:
	# Capture the currently-selected slot so we can re-select it after rebuild.
	# Without this, OptionButton.clear() drops the selection back to index 0
	# (= the lowest slot id), which silently retargets subsequent Save clicks.
	var prev_slot: int = -1
	if not _slot_picker.disabled and _slot_picker.item_count > 0:
		var sel: int = _slot_picker.get_selected()
		if sel >= 0:
			prev_slot = _slot_picker.get_item_id(sel)
	_slot_picker.clear()
	var slots := _session.list_slots()
	if slots.is_empty():
		_slot_picker.add_item("(no saves)")
		_slot_picker.disabled = true
		return
	_slot_picker.disabled = false
	var to_select: int = 0
	for i in range(slots.size()):
		var slot: int = slots[i]
		_slot_picker.add_item("Slot %03d" % slot, slot)
		if slot == prev_slot:
			to_select = i
	_slot_picker.select(to_select)


func _selected_slot_number() -> int:
	if _slot_picker.disabled or _slot_picker.item_count == 0:
		return -1
	var idx := _slot_picker.get_selected()
	return _slot_picker.get_item_id(idx)


# --- Slot load/save -----------------------------------------------------

func _on_reload_pressed() -> void:
	var slot := _selected_slot_number()
	if slot < 0:
		_set_status("No save selected.", true)
		return
	var result: int = _session.load_slot(slot)
	match result:
		SaveSession.LoadResult.OK:
			_set_status("Loaded slot %d." % slot)
			_refresh_party_list()
			_set_form_enabled(true)
			_refresh_inventory()
			_refresh_gold()
			if _session.list_characters().size() > 0:
				_party_list.select(0)
				_on_character_selected(0)
		SaveSession.LoadResult.FILE_NOT_FOUND:
			_set_status("Slot %d not found." % slot, true)
		SaveSession.LoadResult.PARSE_ERROR:
			_set_status("Slot %d failed to parse." % slot, true)


func _on_save_pressed() -> void:
	var slot := _selected_slot_number()
	if slot < 0:
		_set_status("No save selected.", true)
		return
	var ok: bool = _session.save_to_slot(slot)
	if ok:
		_set_status("Saved slot %d." % slot)
		# Don't refresh_slot_list() here: the list contents don't change on
		# overwrite, and rebuilding the OptionButton resets its selection.
	else:
		_set_status("Save to slot %d failed." % slot, true)


# --- Party list / character selection -----------------------------------

func _refresh_party_list() -> void:
	_party_list.clear()
	for ch in _session.list_characters():
		var line: String = "%s  Lv%d  %s/%s" % [
			ch["name"], int(ch["level"]),
			ch["race_id"], ch["job_id"],
		]
		_party_list.add_item(line)


func _on_character_selected(idx: int) -> void:
	_selected_char = idx
	_refresh_character_form()
	_refresh_spell_grid()
	_refresh_equip_grid()


func _refresh_character_form() -> void:
	if _selected_char < 0:
		return
	var ch: Character = _session.get_character(_selected_char)
	if ch == null:
		return
	_suppress_signals = true
	_name_edit.text = ch.character_name
	_select_picker_id(_race_picker, _race_resources, _resource_id_or_empty(ch.race))
	_select_picker_id(_job_picker, _job_resources, _resource_id_or_empty(ch.job))
	_level_spin.value = ch.level
	_exp_spin.value = ch.accumulated_exp
	_current_hp_spin.value = ch.current_hp
	_max_hp_spin.value = ch.max_hp
	_current_mp_spin.value = ch.current_mp
	_max_mp_spin.value = ch.max_mp
	for i in range(_STAT_KEYS.size()):
		_stat_spins[i].value = int(ch.base_stats.get(_STAT_KEYS[i], 0))
	_suppress_signals = false


func _select_picker_id(picker: OptionButton, resources: Array, target_id: StringName) -> void:
	for i in range(resources.size()):
		var res: Resource = resources[i]
		if "id" in res and res.id == target_id:
			picker.select(i)
			return
	if picker.item_count > 0:
		picker.select(0)


func _resource_id_or_empty(res: Resource) -> StringName:
	if res == null:
		return &""
	if "id" in res:
		return res.id
	return &""


# --- Field handlers -----------------------------------------------------

func _on_name_changed(new_text: String) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	_session.set_character_name(_selected_char, new_text)
	# Keep the party-list line label in sync.
	_party_list.set_item_text(_selected_char, "%s  Lv%d  ..." % [new_text, int(_level_spin.value)])


func _on_race_selected(idx: int) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	if idx < 0 or idx >= _race_resources.size():
		return
	var race: RaceData = _race_resources[idx]
	if race == null:
		return
	_session.set_race(_selected_char, race.id)


func _on_job_selected(idx: int) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	if idx < 0 or idx >= _job_resources.size():
		return
	var job: JobData = _job_resources[idx]
	if job == null:
		return
	_session.set_job(_selected_char, job.id)


func _on_level_value_changed(v: float) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	# Spinbox edits write only the integer. Press the "Set Level" button to
	# also recompute HP/MP/spells (set_level semantics).
	_session.set_level_value(_selected_char, int(v))


func _on_set_level_pressed() -> void:
	if _selected_char < 0:
		return
	var target := int(_level_spin.value)
	var ok: bool = _session.set_level(_selected_char, target)
	if ok:
		_refresh_character_form()
		_refresh_spell_grid()
		_set_status("Level set to %d (HP/MP/spells rebuilt)." % target)
	else:
		_set_status("Set level failed (job missing or N < 1).", true)


func _on_exp_changed(v: float) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	_session.set_accumulated_exp(_selected_char, int(v))


func _on_current_hp_changed(v: float) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	_session.set_current_hp(_selected_char, int(v))


func _on_max_hp_changed(v: float) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	_session.set_max_hp(_selected_char, int(v))


func _on_current_mp_changed(v: float) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	_session.set_current_mp(_selected_char, int(v))


func _on_max_mp_changed(v: float) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	_session.set_max_mp(_selected_char, int(v))


func _on_stat_changed(key: StringName, value: int) -> void:
	if _suppress_signals or _selected_char < 0:
		return
	_session.set_base_stat(_selected_char, key, value)


# --- Spell grid (checkboxes) -------------------------------------------

func _refresh_spell_grid() -> void:
	for child in _spell_grid.get_children():
		child.queue_free()
	if _selected_char < 0:
		return
	var ch: Character = _session.get_character(_selected_char)
	if ch == null:
		return
	var ids: Array = _session.get_spell_repository().ids()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for sid in ids:
		var cb := CheckBox.new()
		cb.text = String(sid)
		cb.button_pressed = ch.known_spells.has(sid)
		var captured_id: StringName = sid
		cb.toggled.connect(func(p: bool) -> void:
			_session.toggle_known_spell(_selected_char, captured_id, p))
		_spell_grid.add_child(cb)


func _on_rebuild_spells_pressed() -> void:
	if _selected_char < 0:
		return
	_session.recompute_spells_from_level(_selected_char)
	_refresh_spell_grid()
	_set_status("Spells rebuilt from level.")


func _on_recompute_hp_pressed() -> void:
	if _selected_char < 0:
		return
	_session.recompute_hp_mp_from_level(_selected_char)
	_refresh_character_form()
	_set_status("HP/MP recomputed from level.")


# --- Equipment grid -----------------------------------------------------

func _refresh_equip_grid() -> void:
	for child in _equip_grid.get_children():
		child.queue_free()
	if _selected_char < 0:
		return
	var ch: Character = _session.get_character(_selected_char)
	if ch == null or ch.equipment == null:
		return
	var inv := _session.list_inventory()
	for i in range(_EQUIP_SLOTS.size()):
		var slot: int = _EQUIP_SLOTS[i]
		var label := Label.new()
		label.text = _SLOT_LABELS[i]
		_equip_grid.add_child(label)
		var picker := OptionButton.new()
		_RepoPicker.fill_with_inventory_for_slot(picker, inv)
		# Resolve current equipped item to inventory index.
		var current: ItemInstance = ch.equipment.get_equipped(slot)
		var current_idx: int = -1
		if current != null:
			current_idx = inv.find(current)
		_select_option_by_id(picker, current_idx)
		var captured_slot: int = slot
		picker.item_selected.connect(func(picker_idx: int) -> void:
			var inv_idx: int = picker.get_item_id(picker_idx)
			if inv_idx == _RepoPicker.EMPTY_INDEX:
				_session.unequip(_selected_char, captured_slot)
			else:
				_session.equip(_selected_char, captured_slot, inv_idx))
		_equip_grid.add_child(picker)


func _select_option_by_id(picker: OptionButton, target_id: int) -> void:
	for i in range(picker.item_count):
		if picker.get_item_id(i) == target_id:
			picker.select(i)
			return
	if picker.item_count > 0:
		picker.select(0)


# --- Inventory ---------------------------------------------------------

func _refresh_inventory() -> void:
	for child in _inventory_list.get_children():
		child.queue_free()
	var inv := _session.list_inventory()
	for i in range(inv.size()):
		var inst: ItemInstance = inv[i]
		var row := HBoxContainer.new()
		var label := Label.new()
		var item_name := "(unknown)"
		if inst != null and inst.item != null:
			item_name = "%s  [%s]" % [inst.item.item_name, String(inst.item.item_id)]
		label.text = "#%d  %s" % [i, item_name]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove_button := Button.new()
		remove_button.text = "Remove"
		var captured_idx: int = i
		remove_button.pressed.connect(func() -> void:
			_session.remove_item(captured_idx)
			_refresh_inventory()
			_refresh_equip_grid())
		row.add_child(remove_button)
		_inventory_list.add_child(row)


func _refresh_gold() -> void:
	_suppress_signals = true
	_gold_spin.value = _session.get_gold()
	_suppress_signals = false


func _on_gold_changed(v: float) -> void:
	if _suppress_signals:
		return
	_session.set_gold(int(v))


func _on_add_item_pressed() -> void:
	var idx: int = _add_item_picker.get_selected()
	if idx < 0:
		return
	# Re-derive the StringName id from the label suffix "(id)"
	var label := _add_item_picker.get_item_text(idx)
	var open := label.rfind("(")
	if open < 0:
		_set_status("Could not parse item id from picker.", true)
		return
	var id_str := label.substr(open + 1, label.length() - open - 2)
	var ok: bool = _session.add_item(StringName(id_str), true)
	if ok:
		_refresh_inventory()
		_refresh_equip_grid()
		_set_status("Added %s." % id_str)
	else:
		_set_status("Add item failed.", true)


# --- Status / form gating ---------------------------------------------

func _set_form_enabled(enabled: bool) -> void:
	for n in [
		_name_edit, _race_picker, _job_picker, _level_spin, _exp_spin,
		_current_hp_spin, _max_hp_spin, _current_mp_spin, _max_mp_spin,
		_gold_spin, _add_item_button, _rebuild_spells_button,
		_recompute_hp_button, _set_level_button, _save_button,
	]:
		if n != null and "disabled" in n:
			n.disabled = not enabled
		elif n != null and "editable" in n:
			n.editable = enabled
	for spin in _stat_spins:
		spin.editable = enabled


func _set_status(msg: String, is_error: bool = false) -> void:
	_status_label.text = msg
	_status_label.modulate = Color(1, 0.5, 0.5) if is_error else Color(1, 1, 1)
