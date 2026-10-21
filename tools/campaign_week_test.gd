extends Node
## A scripted week joining construction, recruitment, walking, shops, Necromancy, AI and real save/load.
## Uses its own uniquely named save, never the player's savegame.dat.
const Driver = preload("res://tools/ai/campaign_driver.gd")
var checks := 0
var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _ok(value: bool, label: String) -> void:
	checks += 1
	if not value:
		fails += 1
		print("FAIL ", label)

func _run() -> void:
	var state := WorldGen.generate({"seed": 48123, "map_size": 36, "faction": "necropolis", "hero": "kragor_the_pale"})
	state["terrain"].fill(WorldGen.T_GRASS)
	state["blocked"].fill(0)
	state["objects"].clear()
	var player: Dictionary = state["players"][0]
	var hero: Dictionary = state["heroes"][player["heroes"][0]]
	var town: Dictionary = state["towns"][player["towns"][0]]
	town["pos"] = Vector2i(8, 8)
	hero["pos"] = town["pos"]
	hero["army"] = [{"id": "skeleton", "count": 200}, null, null, null, null, null, null]
	hero["skills"]["necromancy"] = 3
	hero["machines"] = []
	for p in state["players"]:
		p["is_ai"] = true # instant combat and no modal choices in this integration harness
	for resource in player["resources"]:
		player["resources"][resource] = 50000 if resource == "gold" else 100
	var factory := {"uid": GameState.next_uid(), "type": "war_machine_factory", "pos": Vector2i(12, 8)}
	var guard := {"uid": GameState.next_uid(), "type": "monster", "pos": Vector2i(16, 8), "creature": "pikeman", "count": 20}
	state["objects"][factory["uid"]] = factory
	state["objects"][guard["uid"]] = guard
	var driver := Driver.new()
	add_child(driver)
	driver.configure(state)
	var town_uid: int = town["uid"]
	var hero_uid: int = hero["uid"]
	var path := "user://campaign_week_test_%d.dat" % OS.get_process_id()
	var growth_before := 0
	for day in range(1, 8):
		_ok(state["day"] == day and not town["built_today"], "day %d construction resets" % day)
		var built := false
		for id in AdvAI.BUILD_ORDER:
			if TownLogic.build(town, player, id):
				built = true
				break
		_ok(built and town["built_today"], "day %d constructs an eligible building" % day)
		_ok(not TownLogic.build(town, player, "marketplace"), "day %d rejects second construction" % day)
		if day == 1:
			var stock: int = town["available"][0]
			_ok(TownLogic.recruit(town, player, 1, 3, hero["army"]), "recruit into hero army")
			_ok(town["available"][0] == stock - 3, "recruitment consumes town stock")
			var plan := driver.rules.plan(hero, factory["pos"])
			_ok(plan["reach"] == plan["path"].size() - 1 and plan["reach"] > 0, "factory can be reached today")
			await driver.move_hero(hero, plan, false)
			_ok(hero["machines"].size() == 2, "factory equips non-shooting hero with ballista and tent")
			_ok(GameState.buy_war_machine(hero, player, "ammo_cart"), "player can also buy an ammo cart")
		elif day == 2:
			var before: int = hero["army"][0]["count"]
			await driver.move_hero(hero, driver.rules.plan(hero, guard["pos"]), false)
			_ok(not state["objects"].has(guard["uid"]), "walking into guard resolves battle")
			_ok(hero["army"][0]["count"] == before + 5, "Expert Necromancy raises one per defeated four-Pikeman stack (%d -> %d)" % [before, hero["army"][0]["count"]])
		elif day == 4:
			var snapshot := var_to_bytes(state)
			_ok(GameState.save_game(path), "save midweek to isolated file")
			GameState.world = {}
			_ok(GameState.load_game(path), "load midweek through production save API")
			state = GameState.world
			_ok(var_to_bytes(state) == snapshot, "save/load preserves full world including fog, equipment and construction")
			driver.configure(state)
			player = state["players"][0]
			hero = state["heroes"][hero_uid]
			town = state["towns"][town_uid]
		elif day == 7:
			await driver.move_hero(hero, driver.rules.plan(hero, town["pos"]), false)
			_ok(hero["pos"] == town["pos"], "hero returns to town before weekly growth")
		for p in state["players"]:
			if p["index"] != 0 and p["alive"]:
				state["current_player"] = p["index"]
				await driver.ai.run_turn(driver, p)
		state["current_player"] = 0
		growth_before = town["available"][0]
		var info := driver.rules.new_day()
		_ok(info["new_week"] == (day == 7), "weekly growth occurs only at day eight")
		_ok(hero["movement"] >= hero["max_movement"], "next day restores hero movement")
		for p in state["players"]:
			_ok(p["resources"].values().all(func(n): return n >= 0), "treasuries stay nonnegative")
	_ok(state["day"] == 8 and town["available"][0] > growth_before, "new week adds dwelling recruits")
	_ok(hero["machines"].size() == 3 and state["objects"].has(factory["uid"]), "equipment and permanent factory survive the week")
	_ok(driver.battles > 0, "week exercised combat and Necromancy")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CAMPAIGN WEEK TEST: %d checks, failures: %d" % [checks, fails])
	driver.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if fails else 0)
