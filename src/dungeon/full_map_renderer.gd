class_name FullMapRenderer
extends RefCounted

const MIN_CELL_PX := 4
const WALL_PX := 1

static var COLOR_FLOOR := Color8(102, 102, 89)
static var COLOR_WALL := Color8(178, 178, 178)
static var COLOR_DOOR := Color8(153, 102, 51)
static var COLOR_PLAYER := Color8(51, 204, 51)
static var COLOR_START := Color8(230, 204, 51)
static var COLOR_GOAL := Color8(220, 70, 70)
static var COLOR_BG := Color8(0, 0, 0)


func render(_wiz_map: WizMap, _explored_map: ExploredMap, _player_state: PlayerState, _target_size: Vector2i) -> Image:
	# Stub: returns a 1x1 background image so tests compile but fail.
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_BG)
	return img
