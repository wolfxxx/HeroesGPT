extends Node
## Announcements through the real scenes: the battle result names the artifacts a victor captures from a defeated
## hero (and the adventure map then hands them over); entering an own town announces the Mage Guild spells learned
## and spell points restored, and says nothing when there is nothing new.
##   Godot_console.exe --headless --path . res://tools/announce_test.tscn  -> "ANNOUNCE TEST: N checks, failures: 0"
## In a window, `-- --capture=shots/dir` saves both dialogs (restore project.godot afterwards).

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
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _battle_spoils()
		await _town_visit()
		print("ANNOUNCE TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()

	func _world() -> Dictionary:
		var s := GameState.new_game_settings.duplicate()
		s["seed"] = 12345
		var w := WorldGen.generate(s)
		w["intro_shown"] = true
		GameState.world = w
		GameState.return_scene = GameState.SCENE_ADVENTURE
		return w

	func _battle_spoils() -> void:
		var w := _world()
		var rules := AdvRules.new(w)
		var me: Dictionary = w["heroes"][w["players"][0]["heroes"][0]]
		var foe: Dictionary = w["heroes"][w["players"][1]["heroes"][0]]
		for a in ["oaken_buckler", "shield_of_dawn"]:  # (the second is carried: its slot is taken)
			GameState.give_artifact(foe, a)
		var expect: Array = foe["artifacts"] + foe["backpack"]
		_ok(expect.size() == 2 and foe["backpack"].size() == 1, "the defeated hero wears one artifact and carries another")
		GameState.pending_battle = rules.battle_vs_hero(me, foe)
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
		await _frames(30)
		var battle = get_tree().current_scene
		battle._end_battle(0)  # (the attacker, the human side, wins)
		var waited := 0
		while not _modal_text().contains("Victory") and waited < 600:
			waited += 1
			await get_tree().process_frame
		var text := _modal_text()
		_ok(text.contains("captures %s's artifacts" % foe["name"]), "the result names the capture")
		_ok(text.contains("Oaken Buckler") and text.contains("Shield of Dawn"), "worn and carried artifacts are both listed")
		await _capture("announce_battle.png")
		_key(KEY_ENTER)
		waited = 0
		while not _scene().ends_with("adventure.tscn") and waited < 900:
			waited += 1
			await get_tree().process_frame
		await _frames(30)
		_ok("oaken_buckler" in me["artifacts"] + me["backpack"] and "shield_of_dawn" in me["artifacts"] + me["backpack"],
			"the victor then actually holds both: %s / %s" % [me["artifacts"], me["backpack"]])
		while _modal_open():  # (a level-up from the victory)
			_key(KEY_ENTER)
			await _frames(10)

	func _town_visit() -> void:
		var w := _world()
		var rules := AdvRules.new(w)
		var me: Dictionary = w["heroes"][w["players"][0]["heroes"][0]]
		var town: Dictionary = w["towns"][w["players"][0]["towns"][0]]
		town["buildings"].append("mage_guild_1")
		TownLogic.learn_guild_spells(town)
		var guild: Array = town["mage_spells"].filter(func(sp): return not sp in me["spells"])
		me["mana"] = 0
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await _frames(60)
		var adv = get_tree().current_scene
		adv._interact_with(me, {"kind": "town", "uid": town["uid"]}, true)
		var waited := 0
		while not _modal_text().contains("Mage Guild") and waited < 900:
			waited += 1
			await get_tree().process_frame
		var text := _modal_text()
		_ok(_scene().ends_with("town.tscn"), "the visit opens the town screen")
		_ok(not guild.is_empty() and guild.all(func(sp): return sp in me["spells"]), "the hero learns the guild's spells")
		_ok(guild.all(func(sp): return text.contains(GameData.SPELLS[sp]["name"])), "every new spell is named: %s" % [guild])
		_ok(text.contains("spell points are restored to %d" % me["mana"]) and me["mana"] > 0, "restored spell points are announced")
		await _capture("announce_town.png")
		_key(KEY_ENTER)
		await _frames(20)
		_ok(not _modal_open(), "OK closes it")
		# leave and come back: nothing new to learn, full mana, so no dialog
		GameState.pending_town = {"town_uid": town["uid"], "hero_uid": me["uid"],
			"report": {"hero": me["uid"], "learned": rules.hero_in_town(me, town), "mana": 0}}
		get_tree().change_scene_to_file("res://scenes/town.tscn")
		await _frames(60)
		_ok(not _modal_open(), "a visit that teaches nothing shows no dialog")

	func _scene() -> String:  # (none while a scene change is under way)
		var c := get_tree().current_scene
		return c.scene_file_path if c else ""

	func _modal_open() -> bool:
		var l := get_tree().root.get_node_or_null("ModalLayer")
		return l != null and l.get_child_count() > 0

	func _modal_text() -> String:
		var l := get_tree().root.get_node_or_null("ModalLayer")
		return _texts(l) if l else ""

	func _texts(n: Node) -> String:
		var out := ""
		if n is Label:
			out += n.text + "\n"
		for c in n.get_children():
			out += _texts(c)
		return out

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func _key(code: Key) -> void:
		for pressed in [true, false]:
			var e := InputEventKey.new()
			e.keycode = code
			e.pressed = pressed
			Input.parse_input_event(e)

	func _capture(file: String) -> void:
		var dir := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--capture="):
				dir = a.trim_prefix("--capture=")
		if dir == "" or DisplayServer.get_name() == "headless":
			return
		await _frames(30)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + dir))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + dir + "/" + file))
