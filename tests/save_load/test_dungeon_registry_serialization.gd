extends GutTest

func test_to_dict_empty():
	var reg := DungeonRegistry.new()
	var d := reg.to_dict()
	assert_eq(d["dungeons"].size(), 0)

func test_to_dict_with_dungeons():
	var reg := DungeonRegistry.new()
	reg.create("ダンジョン1", DungeonRegistry.SIZE_SMALL)
	reg.create("ダンジョン2", DungeonRegistry.SIZE_SMALL)
	var d := reg.to_dict()
	assert_eq(d["dungeons"].size(), 2)
	assert_eq(d["dungeons"][0]["dungeon_name"], "ダンジョン1")
	assert_eq(d["dungeons"][1]["dungeon_name"], "ダンジョン2")

func test_from_dict_empty():
	var d := {"dungeons": []}
	var reg := DungeonRegistry.from_dict(d)
	assert_eq(reg.size(), 0)

func test_from_dict_with_dungeons():
	var reg := DungeonRegistry.new()
	reg.create("復元テスト", DungeonRegistry.SIZE_SMALL)
	var d := reg.to_dict()
	var restored := DungeonRegistry.from_dict(d)
	assert_eq(restored.size(), 1)
	assert_eq(restored.get_dungeon(0).dungeon_name, "復元テスト")

func test_roundtrip():
	var reg := DungeonRegistry.new()
	reg.create("迷宮A", DungeonRegistry.SIZE_SMALL)
	reg.create("迷宮B", DungeonRegistry.SIZE_MEDIUM)
	var restored := DungeonRegistry.from_dict(reg.to_dict())
	assert_eq(restored.size(), 2)
	assert_eq(restored.get_dungeon(0).dungeon_name, "迷宮A")
	assert_eq(restored.get_dungeon(1).dungeon_name, "迷宮B")
