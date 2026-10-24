extends Node
## The garrison hero, as the classic game: a hero moved up into a town's garrison waits inside, off the map, leading
## the garrison's troops (they join its army, or the move is refused when they don't fit), which frees the gate for
## another (the Tavern can hire again); the town screen's portraits move and swap the two; an attacker meets a hero
## at the gate outside the walls first, and only then the garrison hero in a siege.
##   Godot_console.exe --headless --path . res://tools/garrison_hero_test.tscn  -> "GARRISON HERO TEST: N checks, failures: 0"
## In a window, `-- --capture=shots/dir` also saves the town screen with both heroes (restore project.godot).

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Watcher.new())

class Watcher extends Node:
	var checks := 0
	var failures := 0

	func _ok(cond: bool, what: String) -> void:
		checks += 1
		if not cond:
			failures += 1
			print("FAIL: ", what)

	func _ready() -> void:
		var s := GameState.new_game_settings.duplicate()
		s["seed"] = 12345
		var w := WorldGen.generate(s)
		GameState.world = w
		var rules := AdvRules.new(w)
		var me: Dictionary = w["players"][0]
		var town: Dictionary = w["towns"][me["towns"][0]]
		var h1: Dictionary = w["heroes"][w["start_hero"]]
		h1["pos"] = town["pos"]
		rules.rebuild()
		var c: Array = GameData.FACTIONS[town["faction"]]["creatures"]
		_ok(rules.visiting_hero(town) == h1, "the starting hero stands at the gate")

		# too many kinds to join: refused, nothing changes
		var keep: Array = h1["army"].duplicate(true)
		for i in 7:
			h1["army"][i] = {"id": c[i], "count": 3}
		var other_faction: String = "necropolis" if town["faction"] == "haven" else "haven"
		town["garrison"][0] = {"id": GameData.FACTIONS[other_faction]["creatures"][0], "count": 5}
		_ok(not rules.enter_garrison(h1, town), "a full army of other kinds cannot take the garrison in")
		_ok(not h1.get("in_town", false) and town["garrison"][0] != null, "a refused move changes nothing")
		for i in 7:
			h1["army"][i] = keep[i]
		town["garrison"][0] = {"id": c[0], "count": 5}
		town["garrison"][1] = {"id": c[1], "count": 4}
		var before := GameState.army_strength(h1["army"]) + GameState.army_strength(town["garrison"])

		# into the garrison through the town screen: pick the visiting hero, click the garrison's flag
		GameState.pending_town = {"town_uid": town["uid"]}
		get_tree().change_scene_to_file("res://scenes/town.tscn")
		await get_tree().create_timer(1.0).timeout
		var ts = get_tree().current_scene
		ts._hero_slot("visiting")
		ts._hero_slot("garrison")
		await get_tree().process_frame
		_ok(h1.get("in_town", false) and town.get("garrison_hero", -1) == h1["uid"], "the hero moved into the garrison")
		_ok(GameState.army_is_empty(town["garrison"]), "the garrison's troops joined the hero")
		_ok(GameState.army_strength(h1["army"]) == before, "no troops lost on the way in")
		_ok(ts.hero.is_empty() and not ts._hero_at_gate(), "the gate is free: the Tavern can hire")
		rules.rebuild()
		_ok(rules.hero_at(town["pos"]).is_empty() and rules.at(town["pos"]).get("kind", "") == "town", "the map's gate tile is the town again")
		_ok(rules.town_army(town) == h1["army"], "the town is held by the garrison hero's army")
		# recruiting with a hero in the garrison: the recruits join its army (no hidden town garrison)
		var before_rec: int = 0
		for st in h1["army"]:
			if st and st["id"] == c[0]: before_rec = st["count"]
		town["available"][0] = 7
		town["buildings"].append("dwelling_1")
		_close_soon("buy")
		await ts._recruit_tier(1)
		var after_rec: int = 0
		for st in h1["army"]:
			if st and st["id"] == c[0]: after_rec = st["count"]
		_ok(after_rec > before_rec and GameState.army_is_empty(town["garrison"]), "recruits join the garrison hero's army")
		town["garrison"][3] = {"id": c[3], "count": 2}  # (left by an older version under the garrison hero)
		ts._resolve_state()
		_ok(GameState.army_is_empty(town["garrison"]) and h1["army"].any(func(st): return st and st["id"] == c[3]), "troops stranded under a garrison hero join it when the town opens")

		# a second hero at the gate, then swapped with the garrison hero by the portraits
		var h2 := GameState.make_hero("lord_gareth" if town["faction"] == "haven" else "ilsa_grimveil", 0)
		h2["army"][0] = {"id": c[2], "count": 6}
		h2["pos"] = town["pos"]
		w["heroes"][h2["uid"]] = h2
		me["heroes"].append(h2["uid"])
		ts.hero = h2
		ts.refresh()
		await _capture("garrison_hero_town.png")
		ts._hero_slot("garrison")
		ts._hero_slot("visiting")
		_ok(h2.get("in_town", false) and not h1.get("in_town", false) and ts.hero == h1, "the portraits swap the two heroes")
		ts._hero_slot("visiting")
		ts._hero_slot("garrison")
		_ok(h1.get("in_town", false) and ts.hero == h2, "and back")

		# on the map: the garrison hero has no figure and cannot walk
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await get_tree().create_timer(1.5).timeout
		var adv = get_tree().current_scene
		rules = adv.rules
		_ok(adv.view.hero_node(h1["uid"]) == null and adv.view.hero_node(h2["uid"]) != null, "only the visiting hero is drawn")
		adv._select_hero(h1["uid"])
		adv._make_plan(town["pos"] + Vector2i(0, 3))
		_ok(adv._plan.is_empty(), "a garrison hero has no route")
		_ok(adv._first_hero_with_mp() != h1["uid"], "the garrison hero is not offered as the next to move")

		# an attacker meets the visiting hero outside first (the town stands), then the garrison hero in a siege
		var foe := GameState.make_hero("lady_seraphine" if town["faction"] == "necropolis" else "lord_morthis", 1)
		foe["army"] = [{"id": "angel", "count": 30}, null, null, null, null, null, null]
		foe["pos"] = town["pos"] + Vector2i(0, 1)
		w["heroes"][foe["uid"]] = foe
		w["players"][1]["heroes"].append(foe["uid"])
		rules.rebuild()
		var setup: Dictionary = rules.battle_vs_town(foe, town)
		_ok(setup["defender_hero"] == h1 and setup["siege"] > 0, "the garrison hero defends the walls")
		var bl := BattleLogic.new()
		bl.setup(setup)
		_ok(bl.side_name(1) == h1["name"], "a hero leading the defence names the defenders")
		setup["defender_hero"] = null
		bl.setup(setup)
		_ok(bl.side_name(1) == "The garrison of %s" % town["name"] and bl.side_name(0) == foe["name"], "a town's own garrison is named after the town")
		setup["defender_hero"] = h1
		me["is_ai"] = true  # (both computer: quick-resolved on the map)
		await adv._interact_with(foe, {"kind": "hero", "uid": h2["uid"]}, false)
		_ok(not w["heroes"].has(h2["uid"]), "the visiting hero fell outside the walls")
		_ok(town["owner"] == 0 and h1.get("in_town", false), "the town and its garrison hero still stand")
		rules.rebuild()
		await adv._interact_with(foe, rules.at(town["pos"]), false)
		_ok(town["owner"] == 1, "the siege takes the town")
		_ok(not w["heroes"].has(h1["uid"]) and not town.has("garrison_hero"), "the garrison hero fell with it")
		me["is_ai"] = false
		_computer()
		print("GARRISON HERO TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()

	## The computer, as the classic computer players: a hero holding a threatened town from its gate moves into the
	## garrison (the gate free for the Tavern), and comes out once no army can reach the town.
	func _computer() -> void:
		var s := GameState.new_game_settings.duplicate()
		s["seed"] = 777
		var w := WorldGen.generate(s)
		GameState.world = w
		var rules := AdvRules.new(w)
		var ai := AdvAI.new(rules)
		var cpu: Dictionary = w["players"][1]
		w["current_player"] = 1  # (the computer's turn: a player acts on their own)
		var town: Dictionary = w["towns"][cpu["towns"][0]]
		var h: Dictionary = w["heroes"][cpu["heroes"][0]]
		h["pos"] = town["pos"]
		h["army"] = [{"id": "swordsman", "count": 10}, null, null, null, null, null, null]
		for i in 7:
			town["garrison"][i] = null
		town["garrison"][0] = {"id": "pikeman", "count": 1}
		var foe: Dictionary = w["heroes"][w["players"][0]["heroes"][0]]
		foe["army"] = [{"id": "swordsman", "count": 10}, null, null, null, null, null, null]
		rules.rebuild()
		for d in [Vector2i(0, 3), Vector2i(2, 3), Vector2i(-2, 3), Vector2i(3, 2), Vector2i(-3, 2), Vector2i(0, 4)]:
			var p: Vector2i = town["pos"] + d
			if rules.inside(p) and rules.walkable_ground(p) and rules.at(p).is_empty():
				foe["pos"] = p
				break
		rules.rebuild()
		# a garrison of a third of the threat: too weak alone, enough with the hero
		var unit: int = GameData.CREATURES["pikeman"]["ai_value"]
		town["garrison"][0]["count"] = maxi(1, int(ai._strength(foe) * 0.3 / unit))
		_ok(ai._town_threat(town) > 0.0, "(computer) an enemy army can reach the town")
		var total := GameState.army_strength(h["army"]) + GameState.army_strength(town["garrison"])
		_ok(ai.choose(h).is_empty() and ai.holding == h["uid"] and not h.get("in_town", false), "(computer) the hero chooses to hold the town")
		_ok(ai._garrison(h) and h.get("in_town", false), "(computer) and goes into its garrison to hold it (run_turn)")
		_ok(GameState.army_is_empty(town["garrison"]) and GameState.army_strength(h["army"]) == total, "(computer) leading all its troops")
		_ok(rules.hero_at(town["pos"]).is_empty(), "(computer) the gate is free for the Tavern")
		_ok(is_equal_approx(ai._town_hold(town), ai._strength(h) * 1.25), "(computer) the town's defence counts the garrison hero")
		_ok(ai._step_out(h) and not h.get("in_town", false) and rules.hero_at(town["pos"]) == h, "(computer) each turn it steps out to the gate to decide again")
		# (with the town's troops it could now strike a raider 1.3x weaker: make this one too strong for that)
		var per: float = ai._strength(foe) / foe["army"][0]["count"]
		foe["army"][0]["count"] = int(ceil(ai._strength(h) / 1.2 / per))
		_ok(ai.choose(h).is_empty() and ai.holding == h["uid"] and ai._garrison(h), "(computer) and goes back in while the enemy is near")
		foe["pos"] = Vector2i(1, 1)
		w["heroes"].erase(foe["uid"])
		w["players"][0]["heroes"].erase(foe["uid"])
		rules.rebuild()
		_ok(ai._step_out(h), "(computer) it steps out again the next turn")
		ai.choose(h)
		_ok(ai.holding != h["uid"], "(computer) and with no army near it does not hold the town")

	## Answers the next dialog with `result` once it is up (for a dialog the code under test awaits).
	func _close_soon(result) -> void:
		for i in 120:
			await get_tree().process_frame
			var ml = get_tree().root.get_node_or_null("ModalLayer")
			if ml and ml.get_child_count() > 0:
				ml.get_child(ml.get_child_count() - 1).close(result)
				return

	func _capture(file: String) -> void:
		var dir := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--capture="):
				dir = a.trim_prefix("--capture=")
		if dir == "" or DisplayServer.get_name() == "headless":
			return
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + dir))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + dir + "/" + file))
