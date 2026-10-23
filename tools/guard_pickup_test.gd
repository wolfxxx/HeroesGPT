extends Node
## A guarded treasure is fought for, then taken (as the classic game): a hero who walks onto an artifact beside a
## monster fights the monster, and after winning picks the artifact up. Once by a computer player's hero (the fight
## quick-resolved) and once by the human's (the battle scene, then back on the map).
##   Godot_console.exe --headless --path . res://tools/guard_pickup_test.tscn  -> "GUARD PICKUP TEST: N checks, failures: 0"
## In a window, `-- --capture=shots/dir` also saves the human's find after the battle (restore project.godot).

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
		GameState.world = WorldGen.generate(s)
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await get_tree().create_timer(1.5).timeout
		var adv = get_tree().current_scene
		var hero: Dictionary = adv.selected_hero()
		hero["army"] = [{"id": "angel", "count": 20}, null, null, null, null, null, null]
		var me: Dictionary = adv.human_player()

		# the computer's way: quick-resolved, then the visit in the same move
		var spot := _setup(adv, hero, "oaken_buckler")
		_ok(not spot.is_empty(), "found a guarded artifact spot (computer)")
		if not spot.is_empty():
			me["is_ai"] = true
			var r: String = await adv.move_hero(hero, adv.rules.plan(hero, spot["art_pos"]), false)
			me["is_ai"] = false
			_ok(r == "", "the computer's fight is resolved on the map")
			_check(adv, hero, spot, "oaken_buckler", "computer")

		# the human's way: the battle scene, the result applied back on the map, then the visit
		adv = get_tree().current_scene
		hero = adv.selected_hero()
		spot = _setup(adv, hero, "shield_of_dawn")
		_ok(not spot.is_empty(), "found a guarded artifact spot (human)")
		if not spot.is_empty():
			var r: String = await adv.move_hero(hero, adv.rules.plan(hero, spot["art_pos"]), false)
			_ok(r == "battle", "the human's fight opens the battle")
			await get_tree().create_timer(1.5).timeout
			GameState.finish_battle(AdvRules.new(GameState.world).quick_resolve(GameState.pending_battle))
			for i in 60:  # (back on the map; the find is announced in a dialog: close it)
				await get_tree().create_timer(0.1).timeout
				var ml = get_tree().root.get_node_or_null("ModalLayer")
				if ml and ml.get_child_count() > 0 and get_tree().current_scene.name == "Adventure":
					await _capture("guard_pickup_found.png")
					ml.get_child(ml.get_child_count() - 1).close()
			adv = get_tree().current_scene
			_check(adv, adv.world["heroes"][hero["uid"]], spot, "shield_of_dawn", "human")
		print("GUARD PICKUP TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()

	## An artifact two to four steps from the hero with a weak monster beside it, so that only the artifact's own
	## tile on the way lies in the monster's zone.
	func _setup(adv, hero: Dictionary, art: String) -> Dictionary:
		var r: AdvRules = adv.rules
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var a: Vector2i = hero["pos"] + Vector2i(dx, dy)
				var m := a + Vector2i(1, 0)
				if maxi(absi(dx), absi(dy)) < 2 or not r.inside(a) or not r.inside(m):
					continue
				if not (r.walkable_ground(a) and r.walkable_ground(m) and r.at(a).is_empty() and r.at(m).is_empty()):
					continue
				if r.is_guarded(a) or r.is_guarded(m) or maxi(absi(m.x - hero["pos"].x), absi(m.y - hero["pos"].y)) < 2:
					continue
				var ao := {"type": "artifact", "artifact": art, "uid": GameState.next_uid(), "pos": a}
				var mo := {"type": "monster", "creature": "pikeman", "count": 1, "uid": GameState.next_uid(), "pos": m}
				adv.world["objects"][ao["uid"]] = ao
				adv.world["objects"][mo["uid"]] = mo
				r.rebuild()
				var plan: Dictionary = r.plan(hero, a)
				var path: Array = plan.get("path", [])
				var clean: bool = path.size() >= 2 and path[-1] == a and plan.get("reach", 0) == path.size() - 1
				for i in range(1, path.size() - 1):
					clean = clean and r.guards(path[i]).is_empty()
				if clean:
					hero["movement"] = hero["max_movement"]
					adv.view.rebuild_objects()
					return {"art_pos": a, "art": ao["uid"], "monster": mo["uid"]}
				adv.world["objects"].erase(ao["uid"])
				adv.world["objects"].erase(mo["uid"])
				r.rebuild()
		return {}

	func _check(adv, hero: Dictionary, spot: Dictionary, art: String, who: String) -> void:
		var w: Dictionary = adv.world
		_ok(not w["objects"].has(spot["monster"]), "%s: the guard is beaten" % who)
		_ok(hero["pos"] == spot["art_pos"], "%s: the hero stands where the artifact was" % who)
		_ok(not w["objects"].has(spot["art"]), "%s: the artifact is gone from the map" % who)
		_ok(art in hero.get("artifacts", []) + hero.get("backpack", []) or _worn(hero, art), "%s: the hero has the %s" % [who, art])
		_ok(not hero.has("visit_after_guard"), "%s: no pending visit left on the hero" % who)

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

	func _worn(hero: Dictionary, art: String) -> bool:
		for v in hero.get("slots", {}).values():
			if v == art:
				return true
		return false
