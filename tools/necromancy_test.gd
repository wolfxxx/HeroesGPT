extends Node
## Rules and battle-to-world regression checks; does not read/write the user's saved game.
var checks := 0
var fails := 0
var world: Dictionary

func _ready() -> void:
	_counts_and_slots()
	_casualties()
	_rewards()
	GameState.world = {}
	print("NECROMANCY TEST: %d checks, failures: %d" % [checks, fails])
	get_tree().quit(1 if fails else 0)

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("FAIL ", label)

func _army(ids: Array, count := 10) -> Array:
	var army: Array = [null, null, null, null, null, null, null]
	for i in ids.size():
		army[i] = {"id": ids[i], "count": count}
	return army

func _reset() -> void:
	var terrain := PackedByteArray()
	terrain.resize(16 * 16)
	var blocked := PackedByteArray()
	blocked.resize(terrain.size())
	world = {"size": Vector2i(16, 16), "day": 1, "current_player": 0, "terrain": terrain, "blocked": blocked,
		"heroes": {}, "towns": {}, "objects": {}, "players": [], "tavern": [], "selected_hero": -1}
	for i in 2:
		world["players"].append({"index": i, "is_ai": i == 1, "alive": true, "heroes": [], "towns": [],
			"resources": {"gold": 10000}})
	GameState.world = world

func _hero(owner_index: int) -> Dictionary:
	var hero := GameState.make_hero("kragor_the_pale" if owner_index == 0 else "sir_aldric", owner_index)
	hero["skills"] = {"necromancy": 3}
	hero["army"] = _army(["skeleton"])
	hero["pos"] = Vector2i(4 + owner_index * 4, 6)
	hero["machines"] = []
	world["heroes"][hero["uid"]] = hero
	world["players"][owner_index]["heroes"].append(hero["uid"])
	world["selected_hero"] = hero["uid"]
	return hero

func _counts_and_slots() -> void:
	_reset()
	var hero := _hero(0)
	var fallen := [{"id": "pikeman", "count": 100}]
	for level in [1, 2, 3]:
		hero["skills"]["necromancy"] = level
		var reward := Necromancy.calculate(hero, hero["army"], fallen)
		_ok(reward["raised"] == level * 10, "Basic/Advanced/Expert percentage %d" % level)
	for id in ["skeleton", "zombie", "bone_dragon", "ballista", "ammo_cart"]:
		_ok(Necromancy.calculate(hero, hero["army"], [{"id": id, "count": 10}])["raised"] == 3, "can raise from " + id)
	_ok(Necromancy.calculate(hero, hero["army"], [{"id": "pikeman", "count": 1}])["raised"] == 1, "minimum one from small victory")
	_ok(Necromancy.calculate(hero, hero["army"], [{"id": "pikeman", "count": 1}, {"id": "pikeman", "count": 1}])["raised"] == 2,
		"separate defeated stacks retain SoD rounding")
	_ok(Necromancy.calculate(hero, hero["army"], [])["raised"] == 0, "no enemy losses means no raised troops")
	_ok(Necromancy.calculate(null, hero["army"], fallen)["raised"] == 0, "no hero")
	hero["skills"]["necromancy"] = 0
	_ok(Necromancy.calculate(hero, hero["army"], fallen)["raised"] == 0, "requires skill")
	hero["skills"]["necromancy"] = 3
	var full := _army(GameData.FACTIONS["necropolis"]["creatures"])
	_ok(Necromancy.calculate(hero, full, fallen)["raised"] == 30, "full army merges basic skeletons")
	full = _army(GameData.FACTIONS["necropolis"]["upgrades"])
	var reward := Necromancy.calculate(hero, full, fallen)
	_ok(reward["raised"] == 20 and reward["raised_id"] == "skeleton_warrior", "full upgraded army receives two-thirds warriors")
	_ok(full[0]["count"] == 10, "preview does not mutate army")
	full[6] = null
	reward = Necromancy.calculate(hero, full, fallen)
	_ok(reward["raised"] == 30 and reward["raised_id"] == "skeleton", "free slot prefers normal skeletons")
	full = _army(GameData.FACTIONS["haven"]["creatures"])
	reward = Necromancy.calculate(hero, full, fallen)
	_ok(reward["raised"] == 0 and reward["necromancy_reason"] == "no_room", "full army with no compatible stack cannot receive troops")
	_ok(Necromancy.message(reward).contains("no room"), "full army gets an explanation")
	_ok(Necromancy.message({"raised": 1, "raised_id": "skeleton"}) == "Necromancy raises 1 skeleton from the fallen.",
		"one raised creature is named in the singular")
	_ok(Necromancy.message({"raised": 3, "raised_id": "skeleton"}).contains("3 skeletons"), "several in the plural")
	full[3] = null
	_ok(Necromancy.calculate(hero, full, fallen)["raised"] == 30, "slot freed by casualties can receive reward")
	# Amplifiers stack, only the winning player's buildings count, and artifact bonuses are additive.
	for i in 3:
		world["towns"][i] = {"owner": 0 if i < 2 else 1, "buildings": ["necromancy_amplifier"]}
	_ok(Necromancy.calculate(hero, hero["army"], fallen)["raised"] == 50, "two owned amplifiers stack; enemy one does not")
	hero["artifacts"] = ["gravecloak"]
	_ok(Necromancy.calculate(hero, hero["army"], fallen)["raised"] == 60, "worn artifact adds its bonus")
	for i in range(3, 12):
		world["towns"][i] = {"owner": 0, "buildings": ["necromancy_amplifier"]}
	_ok(Necromancy.calculate(hero, hero["army"], fallen)["raised"] == 100, "rate capped at 100 percent")
	world["towns"].clear()
	hero["artifacts"] = ["mantle_of_the_lich_king"]
	reward = Necromancy.calculate(hero, hero["army"], [{"id": "skeleton", "count": 100}])
	_ok(reward["raised_id"] == "zombie" and reward["raised"] == 16, "existing Mantle reward obeys killed health cap")
	reward = Necromancy.calculate(hero, _army(GameData.FACTIONS["necropolis"]["upgrades"]), [{"id": "skeleton", "count": 100}])
	_ok(reward["raised_id"] == "plague_zombie" and reward["raised"] == 11, "Mantle uses upgraded stack only when army full")

func _casualties() -> void:
	_reset()
	var hero := _hero(0)
	var enemy := _hero(1)
	enemy["machines"] = ["ammo_cart"]
	var logic := BattleLogic.new()
	logic.setup({"attacker_hero": hero, "defender_hero": enemy, "attacker_army": hero["army"],
		"defender_army": _army(["pikeman", "pikeman"], 10), "seed": 12})
	var targets: Array = logic.stacks.filter(func(s): return s["side"] == 1 and not s.get("machine", false))
	for s in targets:
		s["count"] = 9
	var reward := Necromancy.calculate(hero, logic.army_out(0), logic.necromancy_casualties(1))
	_ok(reward["raised"] == 2, "played battle preserves separate enemy stacks")
	_ok(logic.casualties(1) == {"pikeman": 2}, "casualty display still groups identical creatures")
	for s in targets:
		s["count"] = 10
	_ok(logic.necromancy_casualties(1).is_empty(), "resurrected troops and retreat survivors are not losses")
	var cart: Dictionary = logic.stacks.filter(func(s): return s["id"] == "ammo_cart")[0]
	cart["count"] = 0
	cart["alive"] = false
	_ok(Necromancy.calculate(hero, logic.army_out(0), logic.necromancy_casualties(1))["raised"] == 1, "destroyed enemy machine contributes")
	cart["tower"] = true
	_ok(logic.necromancy_casualties(1).is_empty(), "fortification towers do not contribute")

func _rewards() -> void:
	for context_type in ["hero", "town"]:
		for attacker_wins in [true, false]:
			_reset()
			var attacker := _hero(0)
			var defender := _hero(1)
			var winner: Dictionary = attacker if attacker_wins else defender
			winner["army"] = _army(GameData.FACTIONS["necropolis"]["upgrades"])
			var ctx := {"type": context_type, "hero": attacker["uid"], "defender": defender["uid"]}
			var rules := AdvRules.new(world)
			if context_type == "town":
				var town := TownLogic.make_town("necropolis", 1, defender["pos"])
				world["towns"][town["uid"]] = town
				world["players"][1]["towns"].append(town["uid"])
				ctx["town"] = town["uid"]
			var reward := Necromancy.calculate(winner, winner["army"], [{"id": "skeleton", "count": 100}])
			var result := {"winner": "attacker" if attacker_wins else "defender", "context": ctx, "xp": 0,
				"attacker_army": winner["army"].duplicate(true) if attacker_wins else _army([]),
				"defender_army": _army([]) if attacker_wins else winner["army"].duplicate(true)}
			result.merge(reward)
			var ev := rules.apply_battle(result)
			var tag := "%s %s" % [context_type, result["winner"]]
			_ok(winner["army"][0]["count"] == 30 and winner["army"][0]["id"] == "skeleton_warrior", "award applied to " + tag)
			_ok(ev.get("raised", 0) == 20 and ev["hero"] == winner["uid"], "event identifies recipient " + tag)
			var restored: Dictionary = bytes_to_var(var_to_bytes(world))
			_ok(restored["heroes"][winner["uid"]]["army"][0]["count"] == 30, "reward survives serialization " + tag)
	for attacker_wins in [true, false]:
		_reset()
		var attacker := _hero(0)
		var defender := _hero(1)
		var winner: Dictionary = attacker if attacker_wins else defender
		var loser: Dictionary = defender if attacker_wins else attacker
		winner["army"] = _army(["skeleton"], 10000)
		loser["army"] = _army(["skeleton"], 100)
		var rules := AdvRules.new(world)
		var result := rules.quick_resolve(rules.battle_vs_hero(attacker, defender))
		_ok(result["winner"] == ("attacker" if attacker_wins else "defender") and result.get("raised", 0) == 30,
			"instant battle calculates reward for winning side")
		var before: int = result["attacker_army" if attacker_wins else "defender_army"][0]["count"]
		rules.apply_battle(result)
		_ok(winner["army"][0]["count"] == before + 30, "instant battle awards skeletons")
