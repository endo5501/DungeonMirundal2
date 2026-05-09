class_name CombatLog
extends Control

const MAX_LINES: int = 8
const TITLE_TEXT := "BATTLE LOG"

var _lines: Array[String] = []
var _label: Label
var _title_label: Label
var _status_repo_override: StatusRepository = null


func set_status_repo_for_testing(repo: StatusRepository) -> void:
	_status_repo_override = repo


func _resolve_status_display(status_id) -> String:
	if status_id == null:
		return ""
	var repo := StatusRepoLocator.resolve(_status_repo_override)
	if repo != null:
		var data: StatusData = repo.find(status_id)
		if data != null and data.display_name != "":
			return data.display_name
	return String(status_id)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _label != null:
		return
	clip_contents = true
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", CombatWindowStyle.make_panel())
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_title_label = Label.new()
	_title_label.text = TITLE_TEXT
	_title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_title_label)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 21)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.size_flags_vertical = Control.SIZE_FILL
	vbox.add_child(_label)


func append_line(text: String) -> void:
	if text.find("\n") == -1:
		_lines.append(text)
	else:
		for line in text.split("\n", false):
			_lines.append(line)
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	_refresh_label()


func append_from_report_action(action: Dictionary) -> void:
	var text := _format_action(action)
	if text.length() > 0:
		append_line(text)


func get_lines() -> Array[String]:
	return _lines.duplicate()


func get_display_text() -> String:
	return "\n".join(_lines)


func get_title_text() -> String:
	return TITLE_TEXT


func clear_log() -> void:
	_lines.clear()
	_refresh_label()


func _refresh_label() -> void:
	_ensure_ready()
	if _label != null:
		_label.text = get_display_text()


func _ensure_ready() -> void:
	if _label == null:
		_build_ui()


func _format_action(action: Dictionary) -> String:
	var type: String = action.get("type", "")
	var attacker: String = action.get("attacker_name", "")
	var target: String = action.get("target_name", "")
	var damage: int = int(action.get("damage", 0))
	var defended: bool = bool(action.get("defended", false))
	var retargeted_from: String = action.get("retargeted_from", "")
	var confusion_swap: bool = bool(action.get("confusion_swap", false))
	var confusion_prefix: String = "(混乱中) " if confusion_swap else ""
	match type:
		"attack":
			if retargeted_from != "":
				return "%s は既に倒れているため %s を攻撃：%d ダメージ" % [retargeted_from, target, damage]
			if defended:
				return "%s%s の攻撃！ %s は身を守り %d ダメージ" % [confusion_prefix, attacker, target, damage]
			return "%s%s の攻撃！ %s に %d ダメージ" % [confusion_prefix, attacker, target, damage]
		"miss":
			return "%s%s の攻撃！ しかし %s は身をかわした" % [confusion_prefix, attacker, target]
		"defend":
			return "%s は身を守っている" % attacker
		"escape":
			var success: bool = bool(action.get("success", false))
			if success:
				return "逃走に成功した"
			return "逃走に失敗した"
		"defeated":
			return "%s は倒れた" % target
		"item_use":
			var item_name: String = action.get("item_name", "")
			var message: String = action.get("message", "")
			return "%s は %s を使った！ %s" % [attacker, item_name, message]
		"item_cancelled":
			var cancelled_item: String = action.get("item_name", "")
			return "%s は 行動不能で %s を使えなかった" % [attacker, cancelled_item]
		"cast":
			return _format_cast_action(action)
		"cast_skipped_no_mp":
			var caster_no_mp: String = action.get("caster_name", "")
			var spell_no_mp: String = action.get("spell_display_name", "")
			return "%s は %s を唱えようとしたが MP が足りない" % [caster_no_mp, spell_no_mp]
		"cast_skipped_no_target":
			var caster_no_t: String = action.get("caster_name", "")
			var spell_no_t: String = action.get("spell_display_name", "")
			return "%s の %s は対象がいなくなり不発に終わった" % [caster_no_t, spell_no_t]
		"tick_damage":
			var actor_t: String = action.get("actor_name", "")
			var sd_t := _resolve_status_display(action.get("status_id"))
			var amount: int = int(action.get("amount", 0))
			return "%s は %s で %d ダメージを受けた" % [actor_t, sd_t, amount]
		"wake":
			var actor_w: String = action.get("actor_name", "")
			return "%s は目を覚ました" % actor_w
		"inflict":
			return _format_status_line(action, "target_name", "%s は %s になった")
		"cure":
			return _format_status_line(action, "actor_name", "%s の %s が治った")
		"resist":
			return _format_status_line(action, "target_name", "%s は %s に抵抗した")
		"action_locked":
			var actor_l: String = action.get("actor_name", "")
			return "%s は行動できない" % actor_l
		"cast_silenced":
			var caster_s: String = action.get("caster_name", "")
			return "%s は呪文を唱えようとしたが声が出ない" % caster_s
		"stat_mod":
			var target_m: String = action.get("target_name", "")
			var stat_label := _stat_display_label(action.get("stat", &""))
			var delta_m = action.get("delta", 0)
			var delta_text: String
			var direction: String
			# attack/defense/agility ship int delta; hit/evasion ship float delta.
			# Render each with the appropriate precision so float deltas don't
			# truncate to "+0" via int conversion.
			if typeof(delta_m) == TYPE_FLOAT:
				var f := float(delta_m)
				delta_text = "%+.1f" % f
				direction = "上昇した" if f >= 0.0 else "低下した"
			else:
				var i := int(delta_m)
				delta_text = "%+d" % i
				direction = "上昇した" if i >= 0 else "低下した"
			return "%s の%s が %s %s" % [target_m, stat_label, delta_text, direction]
		_:
			return ""


func _format_status_line(action: Dictionary, name_key: String, template: String) -> String:
	var name: String = action.get(name_key, "")
	var sd := _resolve_status_display(action.get("status_id"))
	return template % [name, sd]


func _stat_display_label(stat) -> String:
	match stat:
		&"attack":
			return "攻撃"
		&"defense":
			return "防御"
		&"agility":
			return "素早さ"
		&"hit":
			return "命中"
		&"evasion":
			return "回避"
		_:
			return String(stat)


func _format_cast_action(action: Dictionary) -> String:
	var caster: String = action.get("caster_name", "")
	var spell: String = action.get("spell_display_name", "")
	var entries: Array = action.get("entries", [])
	var retargeted: String = action.get("retargeted_from", "")
	var prefix: String
	if retargeted != "":
		prefix = "%s は %s を唱えた！ (%s が倒れたため再ターゲット)" % [caster, spell, retargeted]
	else:
		prefix = "%s は %s を唱えた！" % [caster, spell]
	if entries.is_empty():
		return prefix
	var parts: Array[String] = [prefix]
	parts.append_array(SpellResolution.format_entries(entries))
	return "\n".join(parts)
