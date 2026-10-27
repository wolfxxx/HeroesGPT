extends Node
## Meeting your own hero by clicking, as the classic game: with a hero selected, a click on another of yours shows the
## route, a second click walks over and opens the Hero Meeting dialog. A hero with no route is selected instead.
##   Godot_console.exe --headless --path . res://tools/meet_test.tscn  -> "MEET TEST: N checks, failures: 0"
## In a window, `-- --capture=shots/dir` also saves the meeting before and after the hand-overs (restore project.godot).

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
		var me: Dictionary = w["heroes"][w["start_hero"]]
		# a second hero three or four steps away, on free ground the first can walk to
		var spot := Vector2i(-1, -1)
		for d in [Vector2i(3, 2), Vector2i(-3, 2), Vector2i(3, 3), Vector2i(-3, 3), Vector2i(0, 4), Vector2i(4, 1), Vector2i(-4, 1)]:
			var q: Vector2i = me["pos"] + d
			if rules.walkable_ground(q) and rules.at(q).is_empty() and not rules.is_guarded(q) and not rules.plan(me, q)["path"].is_empty():
				spot = q
				break
		_ok(spot != Vector2i(-1, -1), "found a free tile for the second hero")
		# artifacts to hand over at the meeting: the helm completes the other hero's Dragonheart Arms; the second shield
		# rides in the backpack
		for art in ["dragonskull_helm", "oaken_buckler", "shield_of_dawn"]:
			GameState.give_artifact(me, art)
		var other := GameState.make_hero("brother_tomas", 0)
		for art in ["dragonbone_blade", "dragonscale_shield"]:
			GameState.give_artifact(other, art)
		other["pos"] = spot
		w["heroes"][other["uid"]] = other
		w["players"][0]["heroes"].append(other["uid"])
		w["tavern"].erase("brother_tomas")
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await get_tree().create_timer(1.5).timeout
		var adv = get_tree().current_scene
		adv._select_hero(me["uid"], true)
		await get_tree().process_frame
		_ok(adv._describe_tile(spot).begins_with("Meet "), "status line offers the meeting: " + adv._describe_tile(spot))
		await _click(adv, spot)
		await _frames(2)
		_ok(GameState.view()["selected_hero"] == me["uid"], "first click keeps the selected hero")
		_ok(adv._plan_target == spot and adv.view.path_points.size() > 0, "first click shows the route to the other hero")
		_ok(not adv._modal_open(), "no dialog yet")
		await _click(adv, spot)
		var waited := 0
		while not adv._modal_open() and waited < 600:
			waited += 1
			await get_tree().process_frame
		_ok(adv._modal_open(), "second click walks over and opens the meeting")
		var d: Vector2i = me["pos"] - spot
		_ok(maxi(absi(d.x), absi(d.y)) == 1, "the heroes stand side by side (%s and %s)" % [me["pos"], spot])
		var l := get_tree().root.get_node_or_null("ModalLayer")
		var titled := false
		if l:
			for m in l.get_children():
				titled = titled or _has_text(m, "Hero Meeting")
		_ok(titled, "the dialog is the Hero Meeting")
		await _capture("meeting_before.png")
		var rows := _rows(l)
		_ok(rows.size() == 2, "each hero has an artifact row")
		if rows.size() == 2:
			_ok(_arts(rows[0]) == ["dragonskull_helm", "oaken_buckler", "shield_of_dawn"], "the visitor's row lists worn, then carried: %s" % [_arts(rows[0])])
			await _press(_sock(rows[0], "dragonskull_helm"))
			_ok("dragonheart_arms" in other["artifacts"] and not "dragonskull_helm" in me["artifacts"],
				"the helm crosses over and completes the combination: %s" % [other["artifacts"]])
			_ok(_has_text(get_tree().root.get_node("ModalLayer"), "Arms of Saint George"), "the merge is announced")
			_key(KEY_ENTER)  # (closes the announcement, back to the meeting)
			await _frames(30)
			rows = _rows(get_tree().root.get_node("ModalLayer"))
			_ok(_arts(rows[1]) == ["dragonheart_arms"], "the other hero's row is redrawn: %s" % [_arts(rows[1])])
			await _press(_sock(rows[0], "shield_of_dawn"))  # (carried: its slot is taken by the combination there)
			_ok("shield_of_dawn" in other["backpack"] and not "shield_of_dawn" in me.get("backpack", []),
				"a carried artifact whose slot is taken goes into the other hero's backpack")
			rows = _rows(get_tree().root.get_node("ModalLayer"))
			await _press(_sock(rows[1], "shield_of_dawn"))
			_ok("shield_of_dawn" in me["artifacts"] or "shield_of_dawn" in me["backpack"], "and it can be handed back")
			await _capture("meeting_after.png")
			_ok(me["movement"] <= me["max_movement"] and other["movement"] <= other["max_movement"], "movement left never exceeds the maximum")
		_key(KEY_ENTER)
		await _frames(30)
		_ok(not adv._modal_open(), "Done closes the meeting")
		# a hero with no route is still selected by a click: wall one in (rules only; the view is not redrawn)
		var walled := Vector2i(-1, -1)
		for y in range(2, adv.world["size"].y - 2):
			for x in range(2, adv.world["size"].x - 2):
				var q := Vector2i(x, y)
				if walled == Vector2i(-1, -1) and adv.rules.walkable_ground(q) and adv.rules.at(q).is_empty() 						and (q - me["pos"]).length() > 4 and (q - me["pos"]).length() < 8:
					walled = q
		var sz: Vector2i = adv.world["size"]
		for dd in AdvRules.DIRS:
			var q: Vector2i = walled + dd
			adv.world["blocked"][q.y * sz.x + q.x] = 1
		var third := GameState.make_hero("lady_seraphine", 0)
		third["pos"] = walled
		adv.world["heroes"][third["uid"]] = third
		adv.world["players"][0]["heroes"].append(third["uid"])
		adv.rules.rebuild()
		adv._select_hero(me["uid"], true)
		adv._click(walled, false)
		await _frames(2)
		_ok(GameState.view()["selected_hero"] == third["uid"], "an unreachable hero is selected instead")
		# back home: with a hero out on the map, a click on any tile of an own town (not only the gate) shows the route
		# to the gate and the second click walks in; it doesn't open the town screen from afar
		var town := {}
		for tw in adv.world["towns"].values():
			if tw["owner"] == 0:
				town = tw
		var body := Vector2i(-1, -1)
		for dy in range(-3, 1):
			for dx in range(-2, 3):
				var q: Vector2i = town["pos"] + Vector2i(dx, dy)
				if body == Vector2i(-1, -1) and q != town["pos"] and adv.rules.town_covering(q).get("uid", -1) == town["uid"]:
					body = q
		_ok(body != Vector2i(-1, -1), "found a town tile other than the gate")
		me["movement"] = me["max_movement"]
		adv._select_hero(me["uid"], true)
		adv._click(body, false)
		await _frames(2)
		_ok(get_tree().current_scene == adv and GameState.pending_town.is_empty(), "first click on the town doesn't open it")
		_ok(adv._plan_target == town["pos"] and not adv._plan.is_empty(), "it shows the route to the town's gate")
		adv._click(body + Vector2i(1, 0) if adv.rules.town_covering(body + Vector2i(1, 0)).get("uid", -1) == town["uid"] else body, false)
		var walked := 0
		while get_tree().current_scene == adv and walked < 900:
			walked += 1
			await get_tree().process_frame
		_ok(me["pos"] == town["pos"], "a second click on the town walks the hero to its gate (%s)" % [me["pos"]])
		_ok(GameState.pending_town.get("hero_uid", -1) == me["uid"], "and the hero visits the town")
		print("MEET TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()

	func _capture(file: String) -> void:
		var dir := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--capture="):
				dir = a.trim_prefix("--capture=")
		if dir == "" or DisplayServer.get_name() == "headless":
			return
		await _frames(20)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + dir))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + dir + "/" + file))

	func _rows(n: Node) -> Array:
		var out := []
		if n is HFlowContainer:
			out.append(n)
		for c in n.get_children():
			out += _rows(c)
		return out

	func _arts(row: Node) -> Array:
		return row.get_children().filter(func(c): return c.has_meta("artifact")).map(func(c): return c.get_meta("artifact"))

	func _sock(row: Node, art: String) -> Control:
		for c in row.get_children():
			if c.has_meta("artifact") and c.get_meta("artifact") == art:
				return c
		return null

	func _press(c: Control) -> void:
		if c == null:
			_ok(false, "artifact socket found")
			return
		await _frames(2)
		var p: Vector2 = get_viewport().get_final_transform() * c.get_global_rect().get_center()
		for pressed in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = pressed
			e.position = p
			Input.parse_input_event(e)
		await _frames(3)

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func _has_text(n: Node, text: String) -> bool:
		if n is Label and n.text == text:
			return true
		for c in n.get_children():
			if _has_text(c, text):
				return true
		return false

	func _click(adv, t: Vector2i) -> void:
		adv.center_on(t, true)
		await get_tree().process_frame
		var p: Vector2 = get_viewport().get_final_transform() * (get_viewport().get_canvas_transform() * adv.view.tile_center(t))
		for pressed in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = pressed
			e.position = p
			Input.parse_input_event(e)

	func _key(code: Key) -> void:
		for pressed in [true, false]:
			var e := InputEventKey.new()
			e.keycode = code
			e.pressed = pressed
			Input.parse_input_event(e)
