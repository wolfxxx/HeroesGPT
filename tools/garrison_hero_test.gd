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
		me["is_ai"] = true  # (both computer: quick-resolved on the map)
		await adv._interact_with(foe, {"kind": "hero", "uid": h2["uid"]}, false)
		_ok(not w["heroes"].has(h2["uid"]), "the visiting hero fell outside the walls")
		_ok(town["owner"] == 0 and h1.get("in_town", false), "the town and its garrison hero still stand")
		rules.rebuild()
		await adv._interact_with(foe, rules.at(town["pos"]), false)
		_ok(town["owner"] == 1, "the siege takes the town")
		_ok(not w["heroes"].has(h1["uid"]) and not town.has("garrison_hero"), "the garrison hero fell with it")
		me["is_ai"] = false
		print("GARRISON HERO TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()

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
