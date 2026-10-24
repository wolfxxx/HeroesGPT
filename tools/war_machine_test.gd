extends Node
## Factory purchases, persistence, AI choices, generated-map access and battle equipment integration.
var checks := 0
var fails := 0

func _ready() -> void:
	_purchases()
	_maps()
	GameState.world = {}
	print("WAR MACHINE TEST: %d checks, failures: %d" % [checks, fails])
	get_tree().quit(1 if fails else 0)

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("FAIL ", label)

func _purchases() -> void:
	var world := WorldGen.generate({"seed": 12345, "map_size": 32, "faction": "haven", "hero": "sir_aldric"})
	GameState.world = world
	var hero: Dictionary = world["heroes"][world["selected_hero"]]
	var player: Dictionary = world["players"][0]
	var rules := AdvRules.new(world)
	var ai := AdvAI.new(rules)
	var factory: Dictionary = world["objects"].values().filter(func(o): return o["type"] == "war_machine_factory")[0]
	hero.erase("machines") # pre-equipment saves also work
	player["resources"]["gold"] = 4250
	var army: Array = hero["army"].duplicate(true)
	for id in GameData.WAR_MACHINES:
		var gold: int = player["resources"]["gold"]
		_ok(GameState.buy_war_machine(hero, player, id), "buy " + id)
		_ok(player["resources"]["gold"] == gold - GameData.CREATURES[id]["cost"]["gold"], "price " + id)
		gold = player["resources"]["gold"]
		_ok(not GameState.buy_war_machine(hero, player, id) and player["resources"]["gold"] == gold, "reject duplicate " + id)
	_ok(hero["machines"].size() == 3 and player["resources"]["gold"] == 0, "exact classic prices exhaust 4250 gold")
	_ok(hero["army"] == army, "equipment uses no army slots")
	hero["machines"].erase("ammo_cart")
	_ok(not GameState.buy_war_machine(hero, player, "ammo_cart") and not "ammo_cart" in hero["machines"], "no free purchase")
	player["resources"]["gold"] = 1000
	_ok(not GameState.buy_war_machine({}, player, "ammo_cart"), "requires visiting hero")
	_ok(not GameState.buy_war_machine(hero, world["players"][1], "ammo_cart"), "cannot equip another player's hero")
	_ok(not GameState.buy_war_machine(hero, player, "catapult"), "catapult is not sold")
	_ok(not GameState.buy_war_machine(hero, player, "invalid"), "unknown machine rejected")
	_ok(player["resources"]["gold"] == 1000, "rejections leave gold intact")
	_ok(GameState.buy_war_machine(hero, player, "ammo_cart"), "can replace a lost machine")
	var before: Dictionary = factory.duplicate(true)
	for visitor in [hero, GameState.make_hero("lord_morthis", 1), hero]:
		_ok(rules.visit(visitor, factory).get("factory", -1) == factory["uid"], "repeatable for both players")
	_ok(factory == before and world["objects"].has(factory["uid"]), "factory not consumed, captured or depleted")
	var restored: Dictionary = bytes_to_var(var_to_bytes(world))
	_ok(restored["heroes"][hero["uid"]]["machines"] == hero["machines"] and restored["objects"][factory["uid"]] == factory,
		"save-format round trip preserves equipment and factory")
	# The purchased equipment reaches the existing battle system without occupying troop slots.
	hero["army"] = [{"id": "archer", "count": 10}, null, null, null, null, null, null]
	var battle := BattleLogic.new()
	battle.setup({"attacker_army": hero["army"], "attacker_hero": hero,
		"defender_army": [{"id": "zombie", "count": 100}], "seed": 42})
	var machines: Array = battle.alive_stacks(0).filter(func(s): return s.get("machine", false))
	_ok(machines.size() == 3, "all purchased machines deploy in battle")
	var archer: Dictionary = battle.alive_stacks(0).filter(func(s): return s["id"] == "archer")[0]
	var target: Dictionary = battle.alive_stacks(1)[0]
	var shots: int = archer["shots"]
	battle.do_shoot(archer, target)
	_ok(archer["shots"] == shots, "purchased cart preserves ammunition")
	for machine in machines:
		if machine["id"] == "ammo_cart":
			machine["alive"] = false
	battle.do_shoot(archer, target)
	_ok(archer["shots"] == shots - 1, "destroyed cart stops supplying ammunition")
	# Factory decisions share a cumulative budget and leave at least 1000 gold for the economy.
	player["resources"]["gold"] = 5250
	_ok(ai.factory_purchases(hero, player).is_empty(), "equipped AI skips factory")
	_ok(ai._object_value(hero, player, factory, 10000) == 0, "equipped AI does not revisit")
	hero["machines"] = []
	_ok(ai.factory_purchases(hero, player).size() == 3, "AI buys useful missing machines")
	_ok(ai._object_value(hero, player, factory, 10000) > 0, "factory is an AI target")
	hero["pos"] = factory["pos"]  # (bought by command: the hero stands at the factory)
	ai.buy_from_factory(hero)
	_ok(hero["machines"].size() == 3 and player["resources"]["gold"] == 1000, "AI pays and retains reserve")
	hero["machines"] = []
	_ok(ai.factory_purchases(hero, player).is_empty(), "poor AI skips factory")
	player["resources"]["gold"] = 2749
	_ok(ai.factory_purchases(hero, player) == ["first_aid_tent"], "AI budget accounts for earlier purchases")
	player["resources"]["gold"] = 10000
	hero["army"] = army
	# Use an army with no shooters regardless of the starting-hero composition.
	hero["army"] = [{"id": "pikeman", "count": 10}, null, null, null, null, null, null]
	_ok(not "ammo_cart" in ai.factory_purchases(hero, player), "AI avoids a cart without shooters")
	_ok(GameData.FACTIONS["haven"]["smith_machine"] == "ballista" and GameData.FACTIONS["necropolis"]["smith_machine"] == "first_aid_tent", "town smiths remain faction specific")

func _maps() -> void:
	for size in [32, 36, 48, 64]:
		for opponents in [1, 3]:
			for seed_v in [1, 42, 12345]:
				var world := WorldGen.generate({"map_size": size, "seed": seed_v, "opponents": opponents,
					"faction": "haven" if seed_v % 2 else "necropolis"})
				var factories: Array = world["objects"].values().filter(func(o): return o["type"] == "war_machine_factory")
				var tag := "%d/%d/%d" % [size, opponents, seed_v]
				_ok(factories.size() == opponents + 1, "factory per start " + tag)
				var rules := AdvRules.new(world)
				# Ground reachability after ALL buildings are placed. Guards/collectibles can be cleared in play.
				for y in size:
					for x in size:
						var p := Vector2i(x, y)
						rules.astar.set_point_solid(p, not rules.walkable_ground(p))
				var hero: Dictionary = world["heroes"][world["selected_hero"]]
				for factory in factories:
					_ok(not rules.astar.get_id_path(hero["pos"], factory["pos"]).is_empty(), "factory entrance reachable " + tag)
					var footprint_ok := true
					for off in WorldGen.footprint_for("war_machine_factory"):
						footprint_ok = footprint_ok and not rules.walkable_ground(factory["pos"] + off)
					_ok(footprint_ok and rules.walkable_ground(factory["pos"]), "solid walls and open entrance " + tag)
				# Actual interaction routes a click on the roof to the entrance.
				var f: Dictionary = factories[0]
				hero["pos"] = f["pos"] + Vector2i(0, 1)
				rules.rebuild()
				var plan := rules.plan(hero, f["pos"] + Vector2i(0, -1))
				_ok(plan["kind"] == "visit" and plan["target"].get("uid", -1) == f["uid"] and not plan["path"].is_empty(),
					"roof click visits factory " + tag)
