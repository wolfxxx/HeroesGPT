extends Node
## Exercise the real adventure controller, animation and camera across enemy turns and fog boundaries.
## Headless: Godot --headless --path . res://tools/adventure_camera_test.tscn
## Visual proof: omit --headless and add -- --capture (writes shots/adventure_camera/*.png).

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Watcher.new())

class Watcher extends Node:
	var checks := 0
	var fails := 0
	var adv
	var mine: Dictionary
	var enemy: Dictionary
	var other: Dictionary
	var capture := false

	func _ready() -> void:
		get_tree().create_timer(45).timeout.connect(func():
			print("FAIL adventure camera test timed out")
			get_tree().quit(2))
		Shot.active = true # suppress briefing and physical-pointer edge scrolling
		capture = OS.get_cmdline_user_args().has("--capture")
		if capture:
			DisplayServer.window_set_size(Vector2i(1600, 900))
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/adventure_camera"))
		GameState.world = WorldGen.generate({"seed": 12345, "map_size": 64, "faction": "haven", "opponents": 1})
		var world := GameState.world
		world["objects"].clear()
		# A clear test area surrounded by the generated landscape; leave the original towns intact.
		var area := Rect2i(28, 22, 28, 28)
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				world["blocked"][y * 64 + x] = 0
				world["terrain"][y * 64 + x] = WorldGen.T_GRASS
		world["decor"] = world["decor"].filter(func(d): return not Rect2(area).grow(3).has_point(d["p"] / WorldGen.TILE))
		mine = world["heroes"][world["players"][0]["heroes"][0]]
		enemy = world["heroes"][world["players"][1]["heroes"][0]]
		enemy["pos"] = Vector2i(38, 30)
		other = GameState.make_hero("lord_morthis", 1)
		other["pos"] = Vector2i(30, 46)
		world["heroes"][other["uid"]] = other
		world["players"][1]["heroes"].append(other["uid"])
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await get_tree().process_frame
		while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != "res://scenes/adventure.tscn":
			await get_tree().process_frame
		adv = get_tree().current_scene
		await get_tree().create_timer(0.2).timeout
		adv.busy = true
		adv.world["current_player"] = 1
		adv.hud.set_turn_label("%s is moving..." % adv.world["players"][1]["name"])
		await _visible()
		await _hidden()
		await _departure()
		await _fog_crossing()
		await _switch_heroes()
		await _visit()
		await _human_turn()
		print("ADVENTURE CAMERA TEST: %d checks, failures: %d" % [checks, fails])
		get_tree().quit(1 if fails else 0)

	func _ok(value: bool, label: String) -> void:
		checks += 1
		if not value:
			fails += 1
			print("FAIL ", label)

	func _fog(rect: Rect2i) -> void:
		var ex: PackedByteArray = adv.human_player()["explored"]
		ex.fill(0)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				ex[y * 64 + x] = 1
		adv.human_player()["explored"] = ex
		adv.rules.reveal(adv.human_player(), mine["pos"], 7)
		adv._refresh_fog()

	func _place(hero: Dictionary, pos: Vector2i) -> void:
		var old: Vector2i = hero["pos"]  # (the test's own placing, not a move: no command)
		hero["pos"] = pos
		adv.rules.refresh_tile(old)
		adv.rules.refresh_tile(pos)
		hero["movement"] = 5000
		adv.view.hero_node(hero["uid"]).position = adv.view.hero_foot(pos)

	func _plan(start: Vector2i, length: int) -> Dictionary:
		var path := []
		var costs := []
		for x in range(length + 1):
			path.append(start + Vector2i(x, 0))
			costs.append(x * 100)
		return {"path": path, "costs": costs, "reach": length, "target": {}}

	func _walk(hero: Dictionary, plan: Dictionary, result: Dictionary) -> void:
		result["return"] = await adv.move_hero(hero, plan, hero["owner"] == 0)
		result["done"] = true

	func _on_screen(pos: Vector2i) -> bool:
		var screen: Vector2 = (adv.view.tile_center(pos) - adv.cam.position) * adv.cam.zoom
		return Rect2(0, 0, adv.MAP_VIEW_W, adv.MAP_VIEW_H).has_point(screen)

	func _shot(label: String) -> void:
		if not capture:
			return
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/adventure_camera/%s.png" % label))

	func _visible() -> void:
		_fog(Rect2i(34, 25, 18, 11))
		adv.center_on(mine["pos"], true)
		await _shot("before_enemy")
		_ok(not _on_screen(enemy["pos"]), "enemy begins outside the current camera view")
		var selected: int = GameState.view()["selected_hero"]
		var result := {"done": false}
		_walk(enemy, _plan(enemy["pos"], 8), result)
		_ok(adv._follow == enemy["uid"] and _on_screen(Vector2i(38, 30)), "visible AI walk immediately comes into view")
		var start_cam: Vector2 = adv.cam.position
		await _shot("enemy_start")
		var midway := false
		while not result["done"]:
			if not midway and enemy["pos"].x >= 42:
				midway = true
				await _shot("enemy_walking")
			await get_tree().process_frame
		_ok(adv.cam.position.x > start_cam.x + 128, "camera travels with the animated enemy")
		_ok(_on_screen(enemy["pos"]), "enemy stays in view at the end of its walk")
		_ok(adv._follow == -1, "follow released after reaching destination")
		_ok(GameState.view()["selected_hero"] == selected, "watching an enemy preserves the player's selected hero")

	func _hidden() -> void:
		_fog(Rect2i())
		_place(enemy, Vector2i(38, 30))
		adv.center_on(mine["pos"], true)
		var before: Vector2 = adv.cam.position
		var spr: Sprite2D = adv.view.hero_node(enemy["uid"]).get_node("Sprite")
		var token: int = spr.get_meta("step_token", 0)
		await adv.move_hero(enemy, _plan(enemy["pos"], 8), false)
		_ok(enemy["pos"] == Vector2i(46, 30), "hidden movement still completes")
		_ok(adv.cam.position == before and adv._cam_target == before, "hidden movement does not redirect camera")
		_ok(adv._follow == -1 and spr.get_meta("step_token", 0) == token, "hidden movement neither follows nor animates")

	func _fog_crossing() -> void:
		_fog(Rect2i(38, 25, 5, 11)) # only x38..42 are explored along this route
		var explored: PackedByteArray = adv.human_player()["explored"].duplicate()
		_place(enemy, Vector2i(34, 30))
		adv.center_on(mine["pos"], true)
		var result := {"done": false}
		_walk(enemy, _plan(enemy["pos"], 16), result)
		_ok(enemy["pos"] == Vector2i(38, 30), "unseen steps finish before first visible animation")
		_ok(adv._follow == enemy["uid"] and _on_screen(Vector2i(38, 30)), "camera picks up a hero emerging from fog")
		await _shot("entering_sight")
		var left_sight := false
		var last_visible_target := Vector2.ZERO
		while not result["done"]:
			if not left_sight and enemy["pos"].x == 43:
				left_sight = true
				_ok(adv._follow == -1, "camera releases on the first hidden step")
				last_visible_target = adv._cam_target
				var focus: Vector2 = adv._cam_target + Vector2(adv.MAP_VIEW_W, adv.MAP_VIEW_H) * 0.5 / adv.cam.zoom
				_ok(focus.is_equal_approx(adv.view.tile_center(Vector2i(42, 30))), "camera stops at the last explored tile")
				await _shot("leaving_sight")
			await get_tree().process_frame
		_ok(left_sight, "observed the visible-to-hidden transition")
		_ok(adv._cam_target == last_visible_target and enemy["pos"] == Vector2i(50, 30), "remaining hidden route does not move camera target")
		_ok(adv.human_player()["explored"] == explored, "following does not reveal enemy terrain")
		await get_tree().process_frame
		_ok(adv.view.hero_node(enemy["uid"]).position.is_equal_approx(adv.view.hero_foot(enemy["pos"])), "completed departure animation cannot pull a hidden hero back to the fog edge")
		await _shot("after_hidden_steps")

	func _departure() -> void:
		_fog(Rect2i(34, 25, 5, 11)) # only the starting tile, x38, is visible along this route
		_place(enemy, Vector2i(38, 30))
		adv.center_on(mine["pos"], true)
		var result := {"done": false}
		_walk(enemy, _plan(enemy["pos"], 8), result)
		_ok(_on_screen(Vector2i(38, 30)), "an enemy leaving sight on its first step is still shown")
		_ok(adv._follow == -1, "departure animation does not follow into hidden terrain")
		var target: Vector2 = adv._cam_target
		while not result["done"]:
			await get_tree().process_frame
		_ok(adv._cam_target == target, "all later hidden steps leave departure camera unchanged")

	func _switch_heroes() -> void:
		_fog(Rect2i(28, 40, 15, 12))
		_place(other, Vector2i(30, 46))
		var result := {"done": false}
		_walk(other, _plan(other["pos"], 1), result)
		_ok(adv._follow == other["uid"] and _on_screen(Vector2i(30, 46)), "even a one-tile walk switches to the next visible enemy")
		while not result["done"]:
			await get_tree().process_frame
		_ok(adv._follow == -1, "short movement also releases follow")
		# No movement points / empty path must not acquire an enemy camera target.
		var before: Vector2 = adv._cam_target
		await adv.move_hero(other, _plan(other["pos"], 0), false)
		_ok(adv._follow == -1 and adv._cam_target == before, "zero-length route leaves camera alone")

	func _visit() -> void:
		var object := {"uid": GameState.next_uid(), "pos": Vector2i(33, 46), "type": "resource", "res": "gold", "amount": 100}
		adv.world["objects"][object["uid"]] = object
		adv.rules.rebuild()
		var gold: int = adv.world["players"][1]["resources"]["gold"]
		await adv.move_hero(other, _plan(other["pos"], 2), false)
		_ok(adv.world["players"][1]["resources"]["gold"] == gold + 100, "movement still performs its final visit")
		_ok(adv._follow == -1, "object interaction releases follow before refreshing nodes")
		# A pseudo-step to a friendly hero takes the early interaction return without walking.
		_place(enemy, other["pos"] + Vector2i(1, 0))
		await adv.move_hero(other, _plan(other["pos"], 1), false)
		_ok(adv._follow == -1, "occupied final tile also releases follow")

	func _human_turn() -> void:
		# End Turn -> real AI target selection/pathing -> new day -> human camera restoration.
		_fog(Rect2i(34, 25, 18, 11))
		_place(enemy, Vector2i(38, 30))
		enemy["movement"] = 400
		other["movement"] = 0
		mine["movement"] = 0 # avoid the expected "heroes can still move" confirmation
		var object := {"uid": GameState.next_uid(), "pos": Vector2i(42, 30), "type": "resource", "res": "gold", "amount": 10000}
		adv.world["objects"][object["uid"]] = object
		adv.rules.rebuild()
		adv.view.rebuild_objects()
		adv.world["players"][1]["ai_day"] = adv.world["day"] # keep this fixture's existing two heroes
		adv.world["current_player"] = 0
		adv.busy = false
		adv.hud.set_turn_label("")
		adv.center_on(mine["pos"], true)
		var day: int = adv.world["day"]
		adv.end_turn()
		var saw_enemy := false
		while adv.busy:
			if adv._follow == enemy["uid"] and _on_screen(enemy["pos"]):
				if not saw_enemy:
					saw_enemy = true
					await _shot("actual_ai_turn")
			await get_tree().process_frame
		_ok(saw_enemy, "End Turn shows the real AI's chosen walk")
		_ok(not adv.world["objects"].has(object["uid"]), "real AI reaches and collects its chosen target")
		_ok(adv.world["day"] == day + 1 and adv.world["current_player"] == 0, "AI turn completes and advances to the human's next day")
		await get_tree().create_timer(0.6).timeout
		_ok(GameState.view()["selected_hero"] == mine["uid"] and _on_screen(mine["pos"]), "human turn returns the camera to the player's hero")
		_ok(adv._follow == -1, "human turn has no stale enemy follow")
		await _shot("your_turn")
		# Walk a clear route through unexplored ground with the normal human command.
		_place(mine, Vector2i(30, 24))
		adv.center_on(mine["pos"], true)
		adv._plan = _plan(mine["pos"], 4)
		adv._execute_move()
		_ok(adv._follow == mine["uid"], "human movement retains sprite following")
		while adv.busy:
			await get_tree().process_frame
		_ok(mine["pos"] == Vector2i(34, 24) and adv._follow == -1, "human route completes and releases camera")
