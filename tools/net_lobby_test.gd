extends Node
## The lobby through the real New Game screen on two processes (main_menu.gd's lobby, Net.lobby_*): the host opens a
## game by address and a second process joins it from its own main menu. The joined screen shows the host's lobby and
## holds Blue; it picks its own town and hero, which reach the host. The host turns to a random map with three rivals:
## Green open, Tan a computer with the Temple's town; the joined player takes Green, and the host leaves Blue empty.
## The joined screen sees all of it. The host begins: the joined machine is seated as Green with its choices, Blue is
## out of the game from the start with its town neutral, Tan's computer has its town, and both worlds match. Then
## a few rounds pass on the host's world (Blue's turn skipped).
##   Godot --headless --path . res://tools/net_lobby_test.tscn      (in the suite)

const PORT := 24794

func _ready() -> void:
	var w := Watcher.new()
	w.name = "LobbyTest"  # (the same path on both machines: its rpcs)
	get_tree().root.add_child.call_deferred(w)

class Watcher extends Node:
	var checks := 0
	var failures := 0
	var _pid := -1
	var _report := {}
	var _client := "--net-role=client" in OS.get_cmdline_user_args()

	func _ok(cond: bool, what: String) -> void:
		checks += 1
		if not cond:
			failures += 1
			print("FAIL ", what)

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		Net.online_path = "user://net_lobby_test_online.dat"
		Net.join_path = "user://net_lobby_test_join.dat"
		Net.port = PORT
		get_tree().change_scene_to_file(GameState.SCENE_MENU)
		await _wait(func(): return _menu() != null, 30.0)
		await _frames(10)
		if _client:
			_joiner()
		else:
			get_tree().create_timer(240.0).timeout.connect(func():
				print("FAIL the lobby test ran out of time")
				_end(1))
			_host()

	func _menu():
		var cs := get_tree().current_scene
		return cs if cs != null and cs.scene_file_path == GameState.SCENE_MENU else null

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func _wait(cond: Callable, secs := 20.0) -> bool:
		var t0 := Time.get_ticks_msec()
		while not cond.call() and Time.get_ticks_msec() - t0 < secs * 1000:
			await get_tree().process_frame
		return cond.call()

	func _end(code: int) -> void:
		if _pid > 0 and OS.is_process_running(_pid):
			OS.kill(_pid)
		Net.forget()
		get_tree().quit(code)

	# -----------------------------------------------------------------------------------------
	# The host (Red)
	# -----------------------------------------------------------------------------------------
	func _host() -> void:
		var menu = _menu()
		_ok(Net.host() == "", "the game is hosted")
		menu._online = true
		menu._set_seat_value("seat_human", 1, true)
		menu._fix_seats()
		menu._open_setup()
		menu._select_scenario(GameData.SCENARIOS[0]["id"])
		menu._lobby_push()
		_pid = OS.create_process(OS.get_executable_path(), ["--headless", "--path",
			ProjectSettings.globalize_path("res://"), "res://tools/net_lobby_test.tscn", "--", "--net-role=client"])
		_ok(await _wait(func(): return Net.lobby_seats.size() == 2), "a machine joins the lobby")
		var id: int = Net.lobby_seats.get(1, -1)
		_ok(id > 1, "it holds Blue, the colour open to people")
		_ok(menu._scen_info.text.contains("1 of 1 joined"), "the screen says so (%s)" % menu._scen_info.text)
		_step.rpc_id(id, "choose")
		_ok(await _wait(func(): return menu._choice("faction", 1) == "necropolis" and menu._choice("hero", 1) == "ilsa_grimveil"),
			"its town and hero reach the host (%s, %s)" % [menu._choice("faction", 1), menu._choice("hero", 1)])
		# a random map with three rivals: Green open, Tan a computer with the Temple's town
		menu._select_scenario("random")
		menu._settings["opponents"] = 3
		menu._refresh_options()
		menu._cycle_seat(2)  # (Green: computer -> empty -> open)
		menu._cycle_seat(2)
		_ok(menu._seat_human(2) and not menu._seat_empty(2), "Green is open to people")
		menu._cycle_ai_town(3)  # (Tan: Random -> the first town)
		_ok(menu._choice("ai_faction", 3) == GameData.FACTIONS.keys()[0], "Tan's computer gets a town (%s)" % menu._choice("ai_faction", 3))
		await _frames(5)
		_step.rpc_id(id, "take green")
		_ok(await _wait(func(): return Net.lobby_seats.get(2, -1) == id and not Net.lobby_seats.has(1)), "the joined player takes Green")
		menu._cycle_seat(1)  # (Blue, open and free now: computer, then empty)
		menu._cycle_seat(1)
		_ok(menu._seat_empty(1) and not menu._seat_human(1), "Blue is left empty")
		await _frames(5)
		_step.rpc_id(id, "report")
		_ok(await _wait(func(): return not _report.is_empty()), "the joined screen reports its lobby")
		_ok(_report.get("mine", -1) == 2, "it shows itself as Green")
		_ok(_report.get("empty", false) and _report.get("tan", "") == GameData.FACTIONS.keys()[0] and _report.get("random", false),
			"it shows Blue empty, Tan's town and the random map (%s)" % [_report])
		_ok(_report.get("locked", false), "and keeps the scenario out of its reach")
		var faction2: String = menu._choice("faction", 2)
		var hero2: String = menu._choice("hero", 2)
		_report = {}
		menu._start_game()
		_ok(await _wait(func(): return Net.peers.size() == 1, 60.0), "the game begins and the joined machine is seated")
		_ok(Net.peers.values() == [2], "as Green, the colour it held (%s)" % [Net.peers.values()])
		var w := GameState.world
		var ps: Array = w["players"]
		_ok(ps.size() == 4, "four colours")
		_ok(not ps[1]["alive"] and ps[1].get("empty", false) and ps[1]["heroes"].is_empty() and ps[1]["towns"].is_empty(),
			"Blue is out of the game from the start")
		var neutral: int = w["towns"].values().filter(func(t): return t["owner"] == -1).size()
		_ok(neutral >= 2, "its town is neutral, with the map's own (%d neutral towns)" % neutral)
		_ok(not ps[2]["is_ai"] and ps[2]["faction"] == faction2 and w["heroes"][ps[2]["start_hero"]]["id"] == hero2,
			"Green is the joined player, with its town and hero")
		_ok(ps[3]["is_ai"] and ps[3]["faction"] == GameData.FACTIONS.keys()[0], "Tan is the computer, with its town")
		_step.rpc_id(Net.peers.keys()[0], "report map")
		_ok(await _wait(func(): return not _report.is_empty(), 30.0), "the joined machine reports from the map")
		_ok(_report.get("seat", -1) == 2 and _report.get("digest", 0) == Net.digest(GameState.world), "its world matches the host's")
		if _report.get("digest", 0) != Net.digest(GameState.world):
			Net._dump("host")
		# a few rounds on the host's world: Blue's turn never comes
		var rules := AdvRules.new(w)
		var seen := {}
		Net.leave()  # (alone now: the turns are this world's only)
		for k in 12:
			var cur: int = w["current_player"]
			seen[cur] = true
			if not Commands.run(rules, {"t": "end_turn", "p": cur})["ok"]:
				break
		_ok(not seen.has(1) and seen.has(0) and seen.has(2) and seen.has(3), "turns pass Blue by (%s)" % [seen.keys()])
		print("NET LOBBY TEST: %d checks, failures: %d" % [checks, failures])
		_end(1 if failures > 0 else 0)

	@rpc("any_peer", "call_remote", "reliable")
	func _done(report: Dictionary) -> void:
		_report = report

	@rpc("authority", "call_remote", "reliable")
	func _step(what: String) -> void:
		var menu = _menu()
		match what:
			"choose":
				menu._select_faction("necropolis")
				menu._select_hero("ilsa_grimveil")
			"take green":
				await _wait(func(): return Net.lobby.get("settings", {}).get("opponents", 0) == 3)
				Net.lobby_ask({"take": 2})
			"report":
				var s: Dictionary = Net.lobby.get("settings", {})
				_done.rpc_id(1, {"mine": Net.lobby_mine(), "empty": menu._seat_empty(1), "tan": menu._choice("ai_faction", 3),
					"random": GameData.scenario(s.get("scenario", "")).get("random", false),
					"locked": menu._scen_buttons.values().all(func(b): return b.mouse_filter == Control.MOUSE_FILTER_IGNORE)})
			"report map":
				await _wait(func(): var cs := get_tree().current_scene; return cs != null and cs.scene_file_path == GameState.SCENE_ADVENTURE, 30.0)
				Net._dump("mine")  # (for tools/net_diff.tscn, should they differ)
				_done.rpc_id(1, {"seat": Net.seat, "digest": Net.digest(GameState.world)})
				await get_tree().create_timer(1.0).timeout
				get_tree().quit()

	# -----------------------------------------------------------------------------------------
	# The joining machine
	# -----------------------------------------------------------------------------------------
	func _joiner() -> void:
		var menu = _menu()
		menu._join("127.0.0.1")
		await _wait(func(): return menu._guest, 30.0)
