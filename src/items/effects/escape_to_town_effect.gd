class_name EscapeToTownEffect
extends ItemEffect


func apply(_targets: Array, _context) -> ItemEffectResult:
	var r := ItemEffectResult.ok("町へ帰還する")
	r.request_town_return = true
	return r
