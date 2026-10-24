extends Node
## Hot-seat through the real scenes: on New Game each person picks their own town, hero and bonus (no two lead the
## same hero), the seats make human players (names, resources, those choices) while a one-human game is generated
## exactly as before; each human's turn starts behind a dark cover naming the player,
## then shows that player's own map; the new week is announced to every human; a battle between two humans is
## played by both; a computer attacking an absent human calls them to the screen; a fallen human leaves while the
## others play on, and the last one standing wins.
##   Godot_console.exe --headless --path . res://tools/hotseat_test.tscn  -> "HOTSEAT TEST: N checks, failures: 0"
## In a window, `-- --capture=shots/dir` saves the handover and the defence call (restore project.godot afterwards).

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
		_generation()
		await _new_game_screen()
		await _turns()
		await _battle_between_humans()
		await _defence_call()
		await _defeats()
		print("HOTSEAT TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()

	func _settings(seats: Array, factions := ["", "", "", ""]) -> Dictionary:
		var s := GameState.new_game_settings.duplicate()
		s["seed"] = 4242
		s["opponents"] = seats.size() - 1
		s["seat_human"] = seats
		s["seat_faction"] = factions
		return s

	func _generation() -> void:
		var plain := GameState.new_game_settings.duplicate()
		plain["seed"] = 4242
		plain["opponents"] = 2
		plain.erase("seat_human")
		plain.erase("seat_faction")
		var a := WorldGen.generate(plain)
		var b := WorldGen.generate(_settings([true, false, false]))
		_ok(a["terrain"] == b["terrain"] and a["objects"].size() == b["objects"].size(), "one human: the same map as before the seats")
		_ok(b["players"][0]["name"] == "You" and b["players"][1]["name"] == "Blue Lord" and b["players"][1]["is_ai"], "one human: names as before")
		var h := WorldGen.generate(_settings([true, true, false], ["", "necropolis", "", ""]))
		var ps: Array = h["players"]
		_ok(not ps[0]["is_ai"] and not ps[1]["is_ai"] and ps[2]["is_ai"], "seats make Red and Blue human, Green a computer")
		_ok(ps[0]["name"] == "Red Player" and ps[1]["name"] == "Blue Player" and ps[2]["name"] == "Green Lord", "hot-seat names: %s" % [ps.map(func(p): return p["name"])])
		_ok(ps[1]["faction"] == "necropolis", "an extra human's chosen town")
		_ok(ps[1]["resources"]["wood"] >= 20 and ps[1]["resources"]["gold"] >= 20000 and ps[1].has("start_hero"),
			"an extra human starts with a human's resources (Normal) and a champion")
		var s := _settings([true, true, true], ["", "necropolis", "haven", ""])
		s["seat_hero"] = ["", "ilsa_grimveil", "sir_aldric", ""]  # (Green asks for Red's hero: Red keeps him)
		s["seat_bonus"] = ["", "resource", "gold", ""]
		var c := WorldGen.generate(s)
		var blue_hero: Dictionary = c["heroes"][c["players"][1]["start_hero"]]
		var green_hero: Dictionary = c["heroes"][c["players"][2]["start_hero"]]
		_ok(blue_hero["id"] == "ilsa_grimveil", "an extra human leads the hero they chose (%s)" % blue_hero["id"])
		_ok(green_hero["id"] != "sir_aldric" and GameData.HEROES[green_hero["id"]]["faction"] == "haven", "never the same hero as another player")
		_ok(c["players"][1]["resources"]["wood"] == 30 and c["players"][2]["resources"]["gold"] == 22500, "and the bonus they chose")

	## The New Game screen: Blue becomes a person and shows their own choices on the left; Red's hero is greyed for
	## them; the game starts with each player's town, hero and bonus.
	func _new_game_screen() -> void:
		var keep: Dictionary = GameState.new_game_settings
		get_tree().change_scene_to_file(GameState.SCENE_MENU)
		await _wait_scene("main_menu.tscn")
		var menu = get_tree().current_scene
		menu._open_setup()
		menu._settings["opponents"] = 2
		menu._refresh_options()
		await _frames(2)
		_ok(menu._seats_box.get_child_count() == 3, "one button per colour in play")
		var blue: Button = menu._seats_box.get_child(1)
		_ok(blue.text == "Computer", "Blue starts as a computer")
		blue.pressed.emit()
		await _frames(2)
		_ok(menu._seat_human(1) and menu._edit_seat == 1 and menu._faction_head.text.begins_with("Blue Player"),
			"Blue becomes a person and the left side shows Blue's choices")
		menu._select_faction("haven")
		await _frames(2)
		var greyed := []
		for b in menu._hero_row.get_children():
			if b.has_meta("hero") and not b.is_queued_for_deletion() and b.disabled:
				greyed.append(b.get_meta("hero"))
		_ok(greyed == [menu._settings["hero"]], "Red's hero is greyed for Blue (%s)" % [greyed])
		menu._select_hero("lord_gareth")
		menu._bonus_buttons["artifact"].pressed.emit()
		_ok(menu._choice("hero", 1) == "lord_gareth" and menu._choice("bonus", 1) == "artifact" and menu._choice("bonus", 0) == "gold",
			"Blue's hero and bonus are Blue's own")
		menu._seats_box.get_child(0).pressed.emit()
		await _frames(2)
		_ok(menu._edit_seat == 0 and menu._choice("faction", 0) == "haven" and menu._faction_head.text.begins_with("Red Player"), "back to Red's choices")
		menu._seats_box.get_child(1).pressed.emit()  # (shows Blue's choices)
		await _frames(2)
		_ok(menu._seat_human(1) and menu._edit_seat == 1, "a click on a person's colour shows their choices")
		menu._seats_box.get_child(1).pressed.emit()  # (a second click: the computer)
		await _frames(2)
		_ok(not menu._seat_human(1) and menu._faction_head.text == "Choose your faction", "Blue back to a computer: one person again")
		menu._seats_box.get_child(1).pressed.emit()
		await _frames(2)
		_ok(menu._seat_human(1) and menu._edit_seat == 1 and menu._choice("hero", 1) == "lord_gareth", "and Blue's choices were kept")
		var w := WorldGen.generate(menu._settings)
		var bh: Dictionary = w["heroes"][w["players"][1]["start_hero"]]
		_ok(bh["id"] == "lord_gareth" and not w["players"][1]["is_ai"] and bh["artifacts"].size() + bh.get("backpack", []).size() > 0,
			"the game starts with Blue's town, hero and bonus")
		GameState.new_game_settings = keep

	func _start(seats: Array) -> Dictionary:
		var w := WorldGen.generate(_settings(seats))
		for vp in w["players"]: GameState.view(vp["index"], w)["intro_shown"] = true
		GameState.world = w
		GameState.return_scene = GameState.SCENE_ADVENTURE
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await _frames(60)
		return w

	func _turns() -> void:
		var w: Dictionary = await _start([true, true, false])
		_ok(await _wait_modal("Red Player's Turn"), "the first turn is handed to Red")
		_ok(_covered(), "the map is covered during the handover")
		await _capture("hotseat_handover.png")
		_key(KEY_ENTER)
		await _frames(20)
		var adv = get_tree().current_scene
		_ok(not _covered() and GameState.human_player_index() == 0, "Red then sees the map")
		_close_modals()
		await _frames(10)
		for p in w["players"]:
			for hid in p["heroes"]:
				w["heroes"][hid]["movement"] = 0  # (no "heroes can still move" question)
		adv.end_turn()
		_ok(await _wait_modal("Blue Player's Turn"), "ending Red's turn hands the game to Blue")
		_ok(_covered() and GameState.human_player_index() == 1, "covered, and the view is Blue's")
		var sel: Dictionary = w["heroes"].get(GameState.view(w["current_player"], w)["selected_hero"], {})
		_ok(sel.get("owner", -1) == 1, "Blue's hero is selected")
		_key(KEY_ENTER)
		await _frames(20)
		_close_modals()
		# Blue ends the last day of the week: Green moves (Red's map stays the viewer's), the new week reaches both
		w["day"] = 7
		for hid in w["players"][1]["heroes"]:
			w["heroes"][hid]["movement"] = 0
		adv.end_turn()
		_ok(await _wait_modal("Red Player's Turn", 1800), "after the computer's turn, Red again")
		_ok(w["day"] == 8 and w["current_player"] == 0, "a new day")
		_key(KEY_ENTER)
		_ok(await _wait_modal("A New Week"), "Red hears of the new week")
		_close_modals()
		await _frames(10)
		for p in w["players"]:
			for hid in p["heroes"]:
				w["heroes"][hid]["movement"] = 0
		adv.end_turn()
		_ok(await _wait_modal("Blue Player's Turn"), "then Blue")
		_key(KEY_ENTER)
		_ok(await _wait_modal("A New Week"), "Blue hears of the new week too")
		_close_modals()
		await _frames(10)
		# a saved hot-seat game opens behind the cover, naming whose turn it is
		var path := "user://hotseat_test_save.dat"
		_ok(GameState.save_game(path) and GameState.load_game(path), "the hot-seat game saves and loads")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		_ok(await _wait_modal("Blue Player's Turn"), "a loaded game first names whose turn it is")
		_ok(_covered(), "with the map hidden")
		_close_modals()
		await _frames(10)

	func _battle_between_humans() -> void:
		var w := GameState.world
		var rules := AdvRules.new(w)
		var red: Dictionary = w["heroes"][w["players"][0]["heroes"][0]]
		var blue: Dictionary = w["heroes"][w["players"][1]["heroes"][0]]
		var setup := rules.battle_vs_hero(blue, red)
		_ok(not setup["attacker_ai"] and not setup["defender_ai"], "a battle between two humans has no computer side")
		GameState.start_battle(setup)
		await _wait_scene("battle.tscn")
		var battle = get_tree().current_scene
		_ok(battle.scene_file_path.ends_with("battle.tscn") and battle._human_controls(0) and battle._human_controls(1),
			"both sides are played from the screen")
		battle._end_battle(1)
		var waited := 0
		while not _modal_text().contains("is victorious") and waited < 600:
			waited += 1
			await get_tree().process_frame
		_ok(_modal_text().contains("Victory!"), "the result is shown as the winner sees it")
		_key(KEY_ENTER)
		await _wait_scene("adventure.tscn")
		_close_modals()

	func _defence_call() -> void:
		var w: Dictionary = await _start([true, true, false])
		await _wait_modal("Red Player's Turn")
		_key(KEY_ENTER)
		await _frames(20)
		_close_modals()
		var adv = get_tree().current_scene
		var green: Dictionary = w["heroes"][w["players"][2]["heroes"][0]]
		var blue: Dictionary = w["heroes"][w["players"][1]["heroes"][0]]
		w["current_player"] = 2  # (the computer's turn, Red at the screen)
		GameState.viewer = 0
		adv._start_battle(adv.rules.battle_vs_hero(green, blue), true)
		_ok(await _wait_modal("To Arms, Blue Player!"), "a computer attacking Blue calls Blue to the screen")
		_ok(_covered() and GameState.human_player_index() == 1, "behind the cover, the view turns to Blue")
		await _capture("hotseat_defend.png")
		_key(KEY_ENTER)
		await _wait_scene("battle.tscn")
		var battle = get_tree().current_scene
		_ok(battle.scene_file_path.ends_with("battle.tscn") and not battle._human_controls(0) and battle._human_controls(1),
			"then Blue defends against the computer")

	func _defeats() -> void:
		var w: Dictionary = await _start([true, true, false])
		await _wait_modal("Red Player's Turn")
		_key(KEY_ENTER)
		await _frames(20)
		_close_modals()
		var adv = get_tree().current_scene
		adv.rules.eliminate(w["players"][1])
		adv._check_game_over()
		_ok(await _wait_modal("Blue Player Is Defeated"), "a fallen human is told so")
		_key(KEY_ENTER)
		await _frames(20)
		_ok(not w["game_over"] and w["current_player"] == 0 and _scene().ends_with("adventure.tscn"), "and the others play on")
		_ok(not GameState.hotseat(), "one human left: no more handovers")
		adv.rules.eliminate(w["players"][2])
		adv._check_game_over()
		_ok(await _wait_modal("Red Player is the last lord standing"), "the last human standing wins")
		_key(KEY_ENTER)
		await _wait_scene("main_menu.tscn")
		# a human who falls on their own turn: the turn passes on
		w = await _start([true, true, true])
		await _wait_modal("Red Player's Turn")
		_key(KEY_ENTER)
		await _frames(20)
		_close_modals()
		adv = get_tree().current_scene
		adv.rules.eliminate(w["players"][0])
		adv._check_game_over()
		_ok(await _wait_modal("Red Player Is Defeated"), "Red falls on their own turn")
		_key(KEY_ENTER)
		_ok(await _wait_modal("Blue Player's Turn"), "and the game passes to Blue")
		_ok(not w["game_over"] and w["current_player"] == 1, "the game goes on")

	# ---------------------------------------------------------------------------------------------
	func _wait_scene(file: String) -> void:
		var waited := 0
		while not _scene().ends_with(file) and waited < 900:
			waited += 1
			await get_tree().process_frame
		await _frames(30)

	func _covered() -> bool:
		var adv := get_tree().current_scene
		if adv == null:
			return false
		for c in adv.get_children():
			if c is CanvasLayer and c.layer == 80 and not c.is_queued_for_deletion():
				return true
		return false

	func _wait_modal(text: String, limit := 900) -> bool:
		var waited := 0
		while not _modal_text().contains(text) and waited < limit:
			waited += 1
			await get_tree().process_frame
		if waited >= limit:
			print("  (modal now: %s)" % _modal_text().replace("\n", " | "))
		return waited < limit

	func _close_modals() -> void:
		var n := 0
		while _modal_open() and n < 20:
			_key(KEY_ENTER)
			await _frames(8)
			n += 1

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
