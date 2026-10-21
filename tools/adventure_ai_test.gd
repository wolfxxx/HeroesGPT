extends Node
## Deterministic adventure decisions on an unobstructed map, using the real path and town rules.
var checks := 0
var fails := 0
var world: Dictionary
var rules: AdvRules
var ai: AdvAI

func _ready() -> void:
	_spending()
	_defense()
	_targets()
	GameState.world = {}
	print("ADVENTURE AI TEST: %d checks, failures: %d" % [checks, fails])
	get_tree().quit(1 if fails else 0)

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("FAIL ", label)

func _reset() -> void:
	var terrain := PackedByteArray()
	terrain.resize(24 * 16)
	terrain.fill(WorldGen.T_GRASS)
	var blocked := PackedByteArray()
	blocked.resize(terrain.size())
	world = {"size": Vector2i(24, 16), "day": 3, "terrain": terrain, "blocked": blocked,
		"heroes": {}, "towns": {}, "objects": {}, "players": [], "tavern": []}
	for i in 2:
		world["players"].append({"index": i, "is_ai": true, "heroes": [], "towns": [],
			"resources": {"gold": 500, "wood": 0, "ore": 0, "mercury": 0, "sulfur": 0, "crystal": 0, "gems": 0}})
	GameState.world = world
	rules = AdvRules.new(world)
	ai = AdvAI.new(rules)

func _hero(side: int, pos: Vector2i, count: int) -> Dictionary:
	var h := GameState.make_hero("sir_aldric" if side == 0 else "lord_morthis", side)
	h["army"] = [{"id": "pikeman", "count": count}, null, null, null, null, null, null]
	h["artifacts"] = []
	h["pos"] = pos
	world["heroes"][h["uid"]] = h
	world["players"][side]["heroes"].append(h["uid"])
	rules.rebuild()
	return h

func _town(side: int, pos: Vector2i, faction := "haven") -> Dictionary:
	var town := TownLogic.make_town(faction, side, pos, "Test Town")
	world["towns"][town["uid"]] = town
	world["players"][side]["towns"].append(town["uid"])
	rules.rebuild()
	return town

func _object(pos: Vector2i, type: String) -> Dictionary:
	var o := {"uid": GameState.next_uid(), "pos": pos, "type": type}
	world["objects"][o["uid"]] = o
	rules.rebuild()
	return o

func _spending() -> void:
	_reset()
	_hero(0, Vector2i(1, 1), 10)
	var town := _town(0, Vector2i(8, 8), "necropolis")
	# A mature Necropolis must not reserve money forever for Haven's Stables/Brotherhood
	# or a second Capitol. No legal building remains here.
	for id in GameData.BUILDINGS:
		if GameData.BUILDINGS[id].get("faction", "necropolis") == "necropolis" and id != "capitol":
			town["buildings"].append(id)
	town["built_today"] = true
	town["available"] = [10, 0, 0, 0, 0, 0, 0]
	var capital := _town(0, Vector2i(20, 10), "necropolis")
	capital["buildings"] = ["capitol"]
	capital["built_today"] = true
	capital["available"] = [0, 0, 0, 0, 0, 0, 0]
	ai.manage_towns(world["players"][0])
	_ok(GameState.army_strength(town["garrison"]) > 0, "recruits instead of saving for impossible buildings")
	_ok(world["players"][0]["resources"]["gold"] >= 0, "recruiting cannot overspend")
	_reset()
	_hero(0, Vector2i(1, 1), 10)
	town = _town(0, Vector2i(8, 8))
	_hero(1, Vector2i(10, 8), 20)
	ai.manage_towns(world["players"][0])
	_ok(GameState.army_strength(town["garrison"]) > 0, "imminent threat overrides building and hiring savings")
	_ok(world["players"][0]["resources"]["gold"] >= 0, "emergency recruiting cannot overspend")

func _defense() -> void:
	_reset()
	var town := _town(0, Vector2i(8, 8))
	var hero := _hero(0, town["pos"], 100)
	var enemy := _hero(1, Vector2i(11, 8), 40)
	_object(Vector2i(7, 8), "chest")
	_ok(ai.choose(hero).is_empty(), "defender holds the threatened gate rather than chasing treasure")
	# A second nearby hero must not be sent to exchange troops with the existing defender.
	var helper := _hero(0, Vector2i(5, 8), 90)
	var choice := ai.choose(helper)
	_ok(choice.get("kind", "") != "meet", "does not send reinforcements into a no-op friendly meeting")
	# Vacate the gate; a reachable defender should return before collecting adjacent loot.
	hero["pos"] = Vector2i(6, 8)
	rules.rebuild()
	choice = ai.choose(hero)
	_ok(choice.get("target", {}).get("uid", -1) == town["uid"], "nearest capable hero returns to defend")
	choice = ai.choose(helper)
	_ok(choice.get("target", {}).get("uid", -1) != town["uid"], "only one hero is assigned to the threatened town")
	# A geometrically close attacker behind an impassable barrier is not an imminent threat.
	for y in 16:
		world["blocked"][y * 24 + 10] = 1
	rules.rebuild()
	choice = ai.choose(hero)
	_ok(choice.get("target", {}).get("type", "") == "chest", "unreachable enemy does not pin a defender")
	# A weak returning hero cannot be ordered into a fight with guards at the town entrance.
	world["blocked"].fill(0)
	var guard := _object(Vector2i(8, 7), "monster")
	guard["creature"] = "bone_dragon"
	guard["count"] = 100
	rules.rebuild()
	choice = ai.choose(hero)
	_ok(choice.get("target", {}).get("uid", -1) != town["uid"], "defense route respects lethal entrance guards")

func _targets() -> void:
	_reset()
	var hero := _hero(0, Vector2i(4, 8), 100)
	var tower := _object(Vector2i(5, 8), "watchtower")
	tower["visited_by"] = [0]
	_ok(ai.choose(hero).is_empty(), "does not repeatedly revisit a spent watchtower")
	tower["visited_by"] = []
	_ok(not ai.choose(hero).is_empty(), "unvisited watchtower remains a target")
	world["objects"].clear()
	var town := _town(1, Vector2i(8, 8))
	town["garrison"][0] = {"id": "angel", "count": 100}
	_hero(1, town["pos"], 1)
	_ok(ai.choose(hero).is_empty(), "enemy hero at a town does not bypass its garrison strength check")
	world["heroes"].erase(world["players"][1]["heroes"][0])
	town["garrison"] = [null, null, null, null, null, null, null]
	rules.rebuild()
	_ok(not ai.choose(hero).is_empty(), "undefended enemy town remains a capture target")
