extends Node
## A hero who retreats from a battle loses the army but keeps the war machines still standing, as the classic game
## (they are equipment, kept like the artifacts): the result window does not list them among the losses, and the hero
## hired again from the Tavern comes back with them.
##   Godot_console.exe --headless --path . res://tools/retreat_test.tscn  -> "RETREAT TEST: N checks, failures: 0"
## In a window, `-- --capture=shots/dir` also saves the result window.

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
		var h: Dictionary = w["heroes"][w["start_hero"]]
		h["machines"] = GameData.WAR_MACHINES.duplicate()
		h["artifacts"] = ["oaken_buckler"]
		var foe: Dictionary = w["heroes"][w["players"][1]["heroes"][0]]
		foe["pos"] = h["pos"] + Vector2i(1, 0)
		GameState.start_battle(rules.battle_vs_hero(h, foe))
		await _wait_scene("battle.tscn")
		var battle = get_tree().current_scene
		var tent := false
		for st in battle.L.stacks:
			tent = tent or (st["id"] == "first_aid_tent" and st["side"] == 0 and st["alive"])
		_ok(tent, "the hero's First Aid Tent stands on the field")

		battle._retreated = 0
		var lost: Dictionary = battle._lost(0)
		_ok(not lost.is_empty(), "the army left behind is listed as lost")
		for m in GameData.WAR_MACHINES:
			_ok(not lost.has(m), "the %s is not listed among the losses" % m)
		battle._end_battle(1)
		_ok(await _wait_modal("retreats from the battlefield"), "the result window tells of the retreat")
		await _capture("retreat_result.png")
		_key(KEY_ENTER)
		await _wait_scene("adventure.tscn")
		await _frames(30)
		_ok(not w["heroes"].has(h["uid"]) and not me["heroes"].has(h["uid"]), "the hero left the map")
		var kept: Dictionary = w.get("tavern_keep", {}).get(h["id"], {})
		_ok(not kept.is_empty() and h["id"] in w["tavern"], "the hero waits in the Tavern")
		var back := GameState.tavern_hero(h["id"], 0)
		_ok(back["machines"].size() == GameData.WAR_MACHINES.size(), "hired again with every war machine")
		_ok("oaken_buckler" in back["artifacts"], "and the artifacts")
		print("RETREAT TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()

	func _wait_scene(file: String) -> void:
		var waited := 0
		while not (get_tree().current_scene and get_tree().current_scene.scene_file_path.ends_with(file)) and waited < 900:
			waited += 1
			await get_tree().process_frame
		await _frames(30)

	func _wait_modal(text: String, limit := 900) -> bool:
		var waited := 0
		while not _modal_text().contains(text) and waited < limit:
			waited += 1
			await get_tree().process_frame
		return waited < limit

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
