extends Node
## The adventure panel's hero and town lists, as the classic game: the first click on a hero or a town selects it and
## centres the map on it, a click on the selected one opens its screen. A town and a hero are never selected together;
## the status window shows the selected town, and the town stays selected on the way back from its screen.
##   Godot_console.exe --headless --path . res://tools/list_click_test.tscn  -> "LIST CLICK TEST: N checks, failures: 0"
## In a window, `-- --capture=shots/dir` also saves the panel with the town selected (restore project.godot).

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
		var me: Dictionary = w["players"][0]
		var town: Dictionary = w["towns"][me["towns"][0]]
		var h: Dictionary = w["heroes"][w["start_hero"]]
		h["pos"] = town["pos"] + Vector2i(6, 4)  # (away from the town, so centring on either moves the map)
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await get_tree().create_timer(1.5).timeout
		var adv = get_tree().current_scene
		_ok(GameState.view(0, w)["selected_hero"] == h["uid"] and adv.selected_town().is_empty(), "the game starts with the hero selected")

		# the town list: a first click selects the town and centres the map, the hero is no longer selected
		_card(adv, false).pressed.emit()
		await get_tree().process_frame
		_ok(GameState.view(0, w)["selected_hero"] == -1 and adv.view.selected_hero == -1, "the hero is no longer selected")
		_ok(adv.selected_town().get("uid", -1) == town["uid"], "the town is selected")
		_ok(get_tree().current_scene == adv, "a first click does not open the town")
		var target: Vector2 = adv._cam_target
		adv.center_on(town["pos"], true)
		_ok(target.distance_to(adv._cam_target) < 1.0, "the map is centred on the town")
		_ok(_card(adv, false).has_theme_stylebox_override("normal"), "the town's list button is shown selected")
		_ok(not _card(adv, true).has_theme_stylebox_override("normal"), "the hero's is not")
		_ok(_shows(adv.hud._detail, town["name"]), "the status window shows the town")
		await _capture("list_click_town.png")

		# the hero list: a first click selects the hero again (and drops the town), a click on the map is the hero's
		_card(adv, true).pressed.emit()
		await get_tree().process_frame
		_ok(GameState.view(0, w)["selected_hero"] == h["uid"] and adv.selected_town().is_empty(), "a hero click selects the hero, not the town")
		_ok(_shows(adv.hud._detail, h["name"]), "the status window shows the hero")
		target = adv._cam_target
		adv.center_on(h["pos"], true)
		_ok(target.distance_to(adv._cam_target) < 1.0, "the map is centred on the hero")
		_ok(adv.get_node_or_null("HeroScreen") == null and get_tree().current_scene == adv, "a first click opens nothing")

		# the second click on the selected town opens it; back on the map, the town is still the selection
		_card(adv, false).pressed.emit()
		await get_tree().process_frame
		_card(adv, false).pressed.emit()
		await get_tree().create_timer(1.0).timeout
		_ok(GameState.pending_town.get("town_uid", -1) == town["uid"] and get_tree().current_scene != adv, "a second click opens the town")
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await get_tree().create_timer(1.5).timeout
		adv = get_tree().current_scene
		_ok(adv.selected_town().get("uid", -1) == town["uid"] and GameState.view(0, w)["selected_hero"] == -1, "the town stays selected after its screen")
		_ok(_shows(adv.hud._detail, town["name"]), "and the status window shows it")
		print("LIST CLICK TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()

	## The first list button (after the up arrow) of the hero list or the town list.
	func _card(adv, heroes: bool) -> Button:
		var lst: VBoxContainer = adv.hud._hero_list if heroes else adv.hud._town_list
		for c in lst.get_children():
			if c is Button and not c.is_queued_for_deletion() and c.custom_minimum_size.y == adv.hud.SLOT_H:
				return c
		return null

	func _shows(n: Node, text: String) -> bool:
		if n is Label and n.text == text:
			return true
		for c in n.get_children():
			if not c.is_queued_for_deletion() and _shows(c, text):
				return true
		return false

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
