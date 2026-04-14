class_name DungeonNameGenerator
extends RefCounted

const ADJECTIVES: Array[String] = [
	"暗黒の", "深淵の", "忘却の", "灼熱の", "凍てつく",
	"朽ちた", "混沌の", "静寂の", "呪われた", "失われた",
	"永遠の", "禁断の", "幻惑の", "荒廃した", "秘密の",
]

const NOUNS: Array[String] = [
	"迷宮", "洞窟", "回廊", "地下墓地", "坑道",
	"神殿", "遺跡", "迷路", "洞穴", "地下道",
	"霊廟", "大聖堂", "砦", "牢獄", "試練場",
]

var _rng: RandomNumberGenerator

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

func generate() -> String:
	return generate_with_rng(_rng)

func generate_with_rng(rng: RandomNumberGenerator) -> String:
	var adj := ADJECTIVES[rng.randi_range(0, ADJECTIVES.size() - 1)]
	var noun := NOUNS[rng.randi_range(0, NOUNS.size() - 1)]
	return adj + noun
