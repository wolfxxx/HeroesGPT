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
	_counterattack()
	_targets()
	_coordination()
	_transfers()
	_reinforcement_targets()
	_randomness()
	await _meeting_turn()
	await _counterattack_turn()
	await _rally_turn()
	await _passage_turn()
	_occupied_site()
	_rear_guard()
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
		var explored := PackedByteArray()
		explored.resize(terrain.size())
		world["players"].append({"index": i, "is_ai": true, "alive": true, "heroes": [], "towns": [],
			"explored": explored,
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
	var enemy := _hero(1, Vector2i(11, 8), 80)
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

func _counterattack() -> void:
	_reset()
	var town := _town(0, Vector2i(8, 8))
	var hero := _hero(0, town["pos"], 100)
	var enemy := _hero(1, Vector2i(11, 8), 20)
	_object(Vector2i(7, 8), "chest")
	_ok(ai.choose(hero).get("target", {}).get("uid", -1) == enemy["uid"], "strong defender intercepts a reachable raider instead of remaining pinned")
	hero["movement"] = 50
	_ok(ai.choose(hero).is_empty(), "defender holds if it cannot finish the interception today")
	hero["movement"] = hero["max_movement"]
	var second := _hero(1, Vector2i(12, 9), 10)
	_ok(ai.choose(hero).is_empty(), "interception cannot expose the gate to a second raider")
	world["heroes"].erase(second["uid"])
	var enemy_town := _town(1, enemy["pos"])
	enemy_town["garrison"][0] = {"id": "angel", "count": 30}
	rules.rebuild()
	_ok(ai.choose(hero).is_empty(), "interception accounts for an enemy town garrison")
	enemy_town["garrison"][0] = null
	var guard := _object(Vector2i(11, 7), "monster")
	guard.merge({"creature": "bone_dragon", "count": 100})
	rules.rebuild()
	_ok(ai.choose(hero).is_empty(), "interception cannot bypass lethal guards beside its target")

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

func _coordination() -> void:
	_reset()
	var hero := _hero(0, Vector2i(4, 8), 100)
	var first := _object(Vector2i(10, 8), "resource")
	first.merge({"res": "gold", "amount": 800})
	var second := _object(Vector2i(9, 8), "resource")
	second.merge({"res": "gold", "amount": 600})
	_ok(ai.choose(hero)["target"] == first, "selects valuable multi-step objective")
	second["amount"] = 750
	_ok(ai.choose(hero)["target"] == first, "small score fluctuation does not abandon a viable objective")
	world["objects"].erase(first["uid"])
	rules.rebuild()
	_ok(ai.choose(hero)["target"] == second, "consumed objective is replaced immediately")
	world["objects"].clear()
	rules.rebuild()
	ai.choose(hero)
	_ok(not hero.has("ai_goal"), "no reachable target clears stale assignment")
	_reset()
	hero = _hero(0, Vector2i(4, 8), 100)
	var helper := _hero(0, Vector2i(4, 9), 100)
	first = _object(Vector2i(10, 8), "resource")
	first.merge({"res": "gold", "amount": 800})
	second = _object(Vector2i(9, 9), "resource")
	second.merge({"res": "gold", "amount": 600})
	_ok(ai.choose(hero)["target"] == first, "first hero reserves its chosen pickup")
	_ok(ai.choose(helper)["target"] == second, "second hero collects a different useful pickup")
	hero["ai_goal"]["day"] = world["day"] - 2
	helper.erase("ai_goal")
	second["amount"] = 1
	_ok(ai.choose(helper)["target"] == first, "stale reservations cannot block useful targets")

func _transfers() -> void:
	_reset()
	var leader := _hero(0, Vector2i(8, 8), 100)
	var helper := _hero(0, Vector2i(6, 8), 20)
	_ok(ai.choose(helper).get("kind", "") == "meet", "nearby small army can deliver troops to the main hero")
	_ok(ai.exchange_troops(helper, leader) == 0, "troops cannot teleport between nonadjacent heroes")
	helper["pos"] = Vector2i(7, 8)
	rules.rebuild()
	var preview := ai._transfer_value(leader, helper["army"], true)
	_ok(preview == 19 * 80 and helper["army"][0]["count"] == 20, "transfer preview preserves both armies")
	_ok(ai.exchange_troops(helper, leader) == preview, "adjacent meeting transfers the predicted troop value")
	_ok(leader["army"][0]["count"] == 119 and helper["army"][0]["count"] == 1, "transfer conserves creatures and keeps one with courier")
	_ok(ai.choose(helper).get("kind", "") != "meet", "spent courier does not repeatedly visit the main hero")
	var enemy := _hero(1, Vector2i(9, 8), 20)
	_ok(ai.exchange_troops(enemy, leader) == 0, "enemy armies cannot exchange")
	leader["army"] = []
	for id in ["archer", "griffin", "swordsman", "monk", "cavalier", "angel", "zombie"]:
		leader["army"].append({"id": id, "count": 100})
	helper["army"][0]["count"] = 20
	_ok(ai._transfer_value(leader, helper["army"], true) == 0, "full incompatible army cannot accept delivery")
	_ok(ai.choose(helper).get("kind", "") != "meet", "full army does not attract a useless courier")
	var town := _town(0, leader["pos"])
	town["buildings"].append("dwelling_1u")
	leader["army"] = [{"id": "pikeman", "count": 10}, null, null, null, null, null, null]
	var player: Dictionary = world["players"][0]
	player["resources"]["gold"] = 1000
	var cost := TownLogic.upgrade_cost("pikeman", "halberdier", 10)
	ai._reinforce(leader, town, player)
	_ok(leader["army"][0]["id"] == "halberdier" and player["resources"]["gold"] == 1000 - cost["gold"], "town reinforcement pays ordinary upgrade costs")

func _randomness() -> void:
	_reset()
	var hero := _hero(0, Vector2i(4, 8), 100)
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 48123
	b.seed = 48123
	_ok(rules.roll_level_up(hero, a) == rules.roll_level_up(hero, b), "level-up respects supplied seeded generator")
	seed(1234)
	var expected := randi()
	seed(1234)
	for sound in Audio._sfx_pool: sound.stop()
	Audio._last_played.clear()
	Audio.sfx("click")
	_ok(randi() == expected, "sound pitch does not consume gameplay randomness")

func _reinforcement_targets() -> void:
	_reset()
	var leader := _hero(0, Vector2i(8, 8), 100)
	var helper := _hero(0, Vector2i(6, 8), 60)
	var target := _town(1, Vector2i(13, 8))
	target["garrison"][0] = {"id": "pikeman", "count": 90}
	_ok(ai.choose(helper).get("kind", "") == "meet", "substantial nearby army joins when its troops unlock a conquest")
	helper["pos"] = Vector2i(7, 8)
	rules.rebuild()
	_ok(ai.exchange_troops(helper, leader) == 59 * 80, "assault delivery transfers troops and leaves one with the donor")
	_ok(ai.choose(leader).get("target", {}).get("uid", -1) == target["uid"], "reinforced leader now selects the previously unsafe town")
	leader["army"][0]["count"] = 100
	helper["army"][0]["count"] = 60
	target["garrison"][0]["count"] = 300
	_ok(ai.choose(helper).get("kind", "") != "meet", "does not dismantle a second army for an unwinnable assault")
	target["garrison"][0]["count"] = 90
	helper["pos"] = Vector2i(1, 1)
	rules.rebuild()
	_ok(ai.choose(helper).get("kind", "") != "meet", "assault support still respects the short delivery range")
	var town := _town(0, leader["pos"])
	town["buildings"].append("dwelling_1u")
	var player: Dictionary = world["players"][0]
	player["resources"]["gold"] = 10000
	leader["army"] = [{"id": "pikeman", "count": 10}, {"id": "halberdier", "count": 5}]
	for id in ["archer", "griffin", "swordsman", "monk", "cavalier"]:
		leader["army"].append({"id": id, "count": 1})
	town["garrison"][0] = {"id": "angel", "count": 1}
	var cost := TownLogic.upgrade_cost("pikeman", "halberdier", 10)
	ai._reinforce(leader, town, player)
	_ok(leader["army"][0] == {"id": "halberdier", "count": 15}, "paid upgrades merge identical stacks without losing creatures")
	_ok(leader["army"][1] == {"id": "angel", "count": 1} and town["garrison"][0] == null,
		"freed slot accepts town reinforcements in the same visit")
	_ok(player["resources"]["gold"] == 10000 - cost["gold"], "merge does not duplicate upgrade charges")
	var dwelling := _object(Vector2i(10, 8), "dwelling")
	dwelling.merge({"creature": "skeleton", "available": 50, "owner": -1})
	_ok(ai.dwelling_recruits(leader, dwelling) == 0 and ai._object_value(leader, player, dwelling, ai._strength(leader)) == 0,
		"full incompatible army never plans a useless dwelling visit")
	leader["army"][1] = null
	dwelling["creature"] = "angel"
	_ok(ai.dwelling_recruits(leader, dwelling) == 0, "dwelling planning checks rare resource costs as well as gold")
	player["resources"]["gems"] = 1
	_ok(ai.dwelling_recruits(leader, dwelling) == 1, "dwelling plans the exact affordable count")
	ai.recruit_from_dwelling(leader, dwelling)
	_ok(leader["army"][1] == {"id": "angel", "count": 1} and dwelling["available"] == 49
		and player["resources"]["gems"] == 0, "dwelling execution matches preview and pays resources")

func _counterattack_turn() -> void:
	_reset()
	var hero := _hero(0, Vector2i(8, 8), 100)
	_town(0, hero["pos"])
	_town(1, Vector2i(22, 14))
	var enemy := _hero(1, Vector2i(9, 8), 1)
	var gold := _object(Vector2i(10, 9), "resource")
	gold.merge({"res": "gold", "amount": 5000})
	var player: Dictionary = world["players"][0]
	player["ai_day"] = world["day"]
	var driver = preload("res://tools/ai/campaign_driver.gd").new()
	add_child(driver)
	driver.configure(world)
	await driver.ai.run_turn(driver, player)
	_ok(not world["heroes"].has(enemy["uid"]), "production town defender defeats the adjacent raider")
	_ok(not world["objects"].has(gold["uid"]), "a victory without casualties still permits further movement")
	driver.queue_free()
	await get_tree().process_frame

func _rally_turn() -> void:
	_reset()
	var leader := _hero(0, Vector2i(12, 8), 100)
	var first := _hero(0, Vector2i(2, 8), 60)
	var second := _hero(0, Vector2i(12, 0), 60)
	var target := _town(1, Vector2i(20, 8))
	target["garrison"][0] = {"id": "pikeman", "count": 140}
	var player: Dictionary = world["players"][0]
	_ok(not ai._unlocks_assault(leader, 59 * 80), "one courier alone cannot unlock this assault")
	var before := var_to_bytes(world)
	var rally := ai._assault_rally(player)
	_ok(rally.get("leader", -1) == leader["uid"] and rally.get("donors", []).size() == 2,
		"two same-day deliveries jointly unlock the assault")
	_ok(var_to_bytes(world) == before, "rally preview never moves or changes armies/resources")
	first["movement"] = 100
	_ok(ai._assault_rally(player).is_empty(), "rally excludes a courier that cannot arrive today")
	first["movement"] = first["max_movement"]
	var home := _town(0, first["pos"])
	var raider := _hero(1, Vector2i(3, 8), 50)
	_ok(ai._assault_rally(player).is_empty(), "rally never takes a required town defender")
	world["heroes"].erase(raider["uid"])
	world["players"][1]["heroes"].erase(raider["uid"])
	world["towns"].erase(home["uid"])
	player["towns"].erase(home["uid"])
	rules.rebuild()
	target["garrison"][0]["count"] = 400
	_ok(ai._assault_rally(player).is_empty(), "rally rejects an assault still unsafe after all deliveries")
	target["garrison"][0]["count"] = 140
	player["ai_day"] = world["day"]
	var driver = preload("res://tools/ai/campaign_driver.gd").new()
	add_child(driver)
	driver.configure(world)
	await driver.ai.run_turn(driver, player)
	_ok(target["owner"] == 0, "production couriers arrive before leader and enable conquest the same turn")
	_ok(first["army"][0]["count"] == 1 and second["army"][0]["count"] == 1, "rally keeps a creature with each donor")
	driver.queue_free()
	await get_tree().process_frame

func _passage_turn() -> void:
	_reset()
	world["blocked"].fill(1)
	for x in range(1, 21): world["blocked"][8 * 24 + x] = 0
	world["blocked"][7 * 24 + 7] = 0 # the only alcove off the single-file road
	var leader := _hero(0, Vector2i(5, 8), 100)
	var helper := _hero(0, Vector2i(7, 8), 1)
	helper["movement"] = 100
	var gold := _object(Vector2i(10, 8), "resource")
	gold.merge({"res": "gold", "amount": 5000})
	rules.rebuild()
	_ok(rules.plan(leader, gold["pos"])["path"].is_empty(), "ally actually blocks the single-file route")
	var before := var_to_bytes(helper)
	var plan := ai.choose(leader)
	_ok(plan.has("yield") and plan["yield"]["hero"] == helper["uid"], "leader asks the blocking ally to step aside")
	_ok(var_to_bytes(helper) == before and rules.astar.is_point_solid(helper["pos"]),
		"route preview restores the blocking tile")
	# choose may remember a goal, but it must not move the helper or spend its movement.
	_ok(helper["pos"] == Vector2i(7, 8) and helper["movement"] == 100, "passage planning does not teleport or spend movement")
	helper["movement"] = 50
	_ok(not ai.choose(leader).has("yield"), "cannot step aside without enough movement")
	helper["movement"] = 100
	world["blocked"][7 * 24 + 7] = 1
	rules.rebuild()
	_ok(not ai.choose(leader).has("yield"), "cannot clear a corridor without a legal alcove")
	world["blocked"][7 * 24 + 7] = 0
	var guard := _object(Vector2i(7, 6), "monster")
	guard.merge({"creature": "angel", "count": 100})
	rules.rebuild()
	_ok(not ai.choose(leader).has("yield"), "never steps a courier into a guarded alcove")
	world["objects"].erase(guard["uid"])
	var gate := _town(0, helper["pos"])
	rules.rebuild()
	_ok(not ai.choose(leader).has("yield"), "passage never displaces a hero holding a town gate")
	world["towns"].erase(gate["uid"])
	world["players"][0]["towns"].erase(gate["uid"])
	# The weaker helper cannot fight this guard, so it is idle when processed before the leader.
	world["objects"].erase(gold["uid"])
	var objective := _object(Vector2i(10, 8), "monster")
	objective.merge({"creature": "pikeman", "count": 10})
	rules.rebuild()
	var player: Dictionary = world["players"][0]
	player["heroes"] = [helper["uid"], leader["uid"]]
	player["ai_day"] = world["day"]
	var driver = preload("res://tools/ai/campaign_driver.gd").new()
	add_child(driver)
	driver.configure(world)
	await driver.ai.run_turn(driver, player)
	_ok(helper["pos"] == Vector2i(7, 7) and helper["movement"] == 0, "production step aside pays the normal 100 movement")
	_ok(leader["pos"] == Vector2i(9, 8) and not world["objects"].has(objective["uid"]),
		"earlier idle helper retains movement so later leader can clear the corridor and attack")
	driver.queue_free()
	await get_tree().process_frame

func _occupied_site() -> void:
	_reset()
	var leader := _hero(0, Vector2i(8, 8), 100)
	var helper := _hero(0, Vector2i(7, 8), 1)
	world["players"][0]["resources"]["gold"] = 10000
	_object(leader["pos"], "war_machine_factory")
	rules.rebuild()
	_ok(rules.plan(helper, leader["pos"])["kind"] == "meet", "occupied factory actually resolves as a friendly meeting")
	_ok(ai.choose(helper).is_empty(), "courier cannot mistake a useless meeting for buying at an occupied factory")
	helper["army"][0]["count"] = 80 # not an ordinary small courier, but the meeting still transfers real troops
	_ok(ai.choose(helper).get("kind", "") == "meet", "occupied site may still lead to a useful troop exchange")

func _meeting_turn() -> void:
	_reset()
	var leader := _hero(0, Vector2i(8, 8), 100)
	var helper := _hero(0, Vector2i(7, 8), 20)
	leader["movement"] = 0
	var gold := _object(Vector2i(7, 10), "resource")
	gold.merge({"res": "gold", "amount": 1})
	var player: Dictionary = world["players"][0]
	player["ai_day"] = world["day"]
	var driver = preload("res://tools/ai/campaign_driver.gd").new()
	add_child(driver)
	driver.configure(world)
	await driver.ai.run_turn(driver, player)
	_ok(leader["army"][0]["count"] == 119 and helper["army"][0]["count"] == 1, "production meeting conserves armies")
	_ok(not world["objects"].has(gold["uid"]) and helper["pos"] == gold["pos"], "free adjacent exchange does not prematurely end courier movement")
	driver.queue_free()
	await get_tree().process_frame

## Leaving a town an enemy can reach next turn, a hero leaves enough troops to hold it when that is cheap, and none
## when holding it would cost more than a quarter of its army.
func _rear_guard() -> void:
	_reset()
	var town := _town(0, Vector2i(8, 8))
	var hero := _hero(0, town["pos"], 200)
	var raider := _hero(1, Vector2i(13, 8), 20)
	var plan := rules.plan(hero, Vector2i(2, 8))
	var before := GameState.army_strength(hero["army"])
	ai._leave_rear_guard(hero, plan)
	var left := GameState.army_strength(town["garrison"])
	_ok(left * 1.25 >= ai._town_threat(town) * 1.4, "the rear guard holds the gate against the raider (%d left)" % left)
	_ok(before - GameState.army_strength(hero["army"]) == left and left <= before * 0.25, "troops are moved, not lost, and cost at most a quarter")
	_reset()
	var town2 := _town(0, Vector2i(8, 8))
	var hero2 := _hero(0, town2["pos"], 200)
	_hero(1, Vector2i(13, 8), 150)
	ai._leave_rear_guard(hero2, rules.plan(hero2, Vector2i(2, 8)))
	_ok(GameState.army_is_empty(town2["garrison"]) and hero2["army"][0]["count"] == 200, "no rear guard when holding would cost too much")
	ai._leave_rear_guard(hero2, {"path": []})
	_ok(hero2["army"][0]["count"] == 200, "staying put leaves nothing behind")
