class_name CombatWindowStyle
extends RefCounted

const FRAME_COLOR := Color(0.72, 0.58, 0.28, 0.95)
const PANEL_BG_COLOR := Color(0.04, 0.04, 0.05, 0.74)
const BORDER_WIDTH: int = 2
const CONTENT_MARGIN: float = 8.0


static func make_panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG_COLOR
	style.border_color = FRAME_COLOR
	style.set_border_width_all(BORDER_WIDTH)
	style.set_content_margin_all(CONTENT_MARGIN)
	return style


static func draw_window(canvas: CanvasItem, rect: Rect2, bg_color: Color) -> void:
	canvas.draw_rect(rect, bg_color)
	canvas.draw_rect(rect, FRAME_COLOR, false, float(BORDER_WIDTH))
