class_name ItemEffectResult
extends RefCounted

var success: bool = false
var message: String = ""
var request_town_return: bool = false


static func ok(msg: String = "") -> ItemEffectResult:
	var r := ItemEffectResult.new()
	r.success = true
	r.message = msg
	return r


static func failure(msg: String) -> ItemEffectResult:
	var r := ItemEffectResult.new()
	r.success = false
	r.message = msg
	return r
