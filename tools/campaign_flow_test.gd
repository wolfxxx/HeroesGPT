extends Node
## Real adventure -> tactical battle -> results/level-up -> adventure -> isolated save/reload.
## Also tests an AI-initiated battle, human retreat, and resumption of the interrupted AI turn.
## No instant resolver or fabricated result. --capture writes shots/session50/flow/*.png.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Watcher.new())

class Watcher extends Node:
	var checks := 0
	var fails := 0
	var capture := false
	var mine: Dictionary
	var enemy: Dictionary
	var result := {}
	var save_path := ""
	var user_save_hash := ""

	func _ready() -> void:
		save_path = "user://campaign_flow_%d.dat" % OS.get_process_id()
		user_save_hash = FileAccess.get_sha256(GameState.SAVE_PATH) if GameState.has_save() else ""
		get_tree().create_timer(150, true, false, true).timeout.connect(func():
			print("FAIL campaign flow timed out")
			_cleanup()
			get_tree().quit(2))
		capture = OS.get_cmdline_user_args().has("--capture")
		Shot.active = true # no briefing/physical-pointer edge scrolling; scene/battle logic stays real
		GameState.battle_speed = 4.0
		if capture:
			DisplayServer.window_set_size(Vector2i(1600, 900))
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/session50/flow"))
		GameState.battle_finished.connect(func(r): result = r.duplicate(true))
		await _attack()
		await _defend_retreat()
		_ok((FileAccess.get_sha256(GameState.SAVE_PATH) if GameState.has_save() else "") == user_save_hash,
			"player's real save remains untouched")
		_cleanup()
		print("CAMPAIGN FLOW TEST: %d checks, failures: %d" % [checks, fails])
		get_tree().quit(1 if fails else 0)

	func _cleanup() -> void:
		if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	func _ok(value: bool, label: String) -> void:
		checks += 1
		if not value:
			fails += 1
			print("FAIL ", label)

	func _fixture() -> void:
		GameState.world = WorldGen.generate({"seed": 50601, "map_size": 36, "opponents": 1,
			"faction": "necropolis", "hero": "kragor_the_pale"})
		var w := GameState.world
		w["terrain"].fill(WorldGen.T_GRASS)
		w["blocked"].fill(0)
		w["objects"].clear()
		w["decor"].clear()
		w["intro_shown"] = true
		w["tavern"].clear() # keep the fixture's two armies fixed during the resumed AI turn
		for tid in w["towns"].keys():
			var t: Dictionary = w["towns"][tid]
			if t["owner"] < 0: w["towns"].erase(tid)
			else: t["pos"] = Vector2i(4, 5) if t["owner"] == 0 else Vector2i(30, 30)
		mine = w["heroes"][w["players"][0]["heroes"][0]]
		enemy = w["heroes"][w["players"][1]["heroes"][0]]
		mine["pos"] = Vector2i(10, 10)
		enemy["pos"] = Vector2i(11, 10)
		mine["skills"]["necromancy"] = 3
		mine["army"] = [{"id": "skeleton", "count": 100}, {"id": "lich", "count": 50}, null, null, null, null, null]
		enemy["army"] = [{"id": "pikeman", "count": 10}, null, null, null, null, null, null]
		mine["xp"] = 950
		for h in [mine, enemy]:
			h["machines"] = []
			h["spells"] = []
			h["artifacts"] = []
			h["backpack"] = []
		result = {}

	func _scene(path: String) -> Node:
		while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != path or GameState.transitioning:
			await get_tree().process_frame
		await get_tree().create_timer(0.25).timeout
		return get_tree().current_scene

	func _open_adventure() -> Node:
		GameState.change_scene(GameState.SCENE_ADVENTURE, 0.01)
		return await _scene(GameState.SCENE_ADVENTURE)

	func _modal() -> Modal:
		var layer := get_tree().root.get_node_or_null("ModalLayer")
		if layer:
			for child in layer.get_children():
				if child is Modal and not child.is_queued_for_deletion(): return child
		return null

	func _wait_modal() -> Modal:
		while _modal() == null: await get_tree().process_frame
		await get_tree().create_timer(0.25).timeout
		return _modal()

	func _press_modal(m: Modal, text: String = "") -> void:
		for b in m.find_children("*", "Button", true, false):
			if not b.disabled and (text == "" or b.text == text):
				b.pressed.emit()
				return
		_ok(false, "modal button exists: " + text)

	func _shot(label: String) -> void:
		if not capture: return
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/session50/flow/%s.png" % label))

	func _save_reload(label: String) -> Node:
		var snapshot := var_to_bytes(GameState.world)
		var uid := GameState._uid
		_ok(GameState.save_game(save_path), label + " saves")
		GameState.world = {}
		_ok(GameState.load_game(save_path), label + " loads")
		_ok(var_to_bytes(GameState.world) == snapshot and GameState._uid == uid, label + " preserves complete world and uid")
		_ok(GameState.battle_result.is_empty() and GameState.pending_battle.is_empty(), label + " clears battle handoff")
		var adv := await _open_adventure()
		_ok(GameState.world["current_player"] == 0 and not adv.busy, label + " opens a playable human turn")
		return adv

	func _attack() -> void:
		_fixture()
		var adv := await _open_adventure()
		var mine_uid: int = mine["uid"]
		var enemy_uid: int = enemy["uid"]
		var xp: int = mine["xp"]
		adv._make_plan(enemy["pos"])
		_ok(adv._plan["kind"] == "attack", "human command plans enemy-hero battle")
		adv._execute_move()
		var battle := await _scene(GameState.SCENE_BATTLE)
		_ok(battle.L.ai_side == [false, true], "human attacker faces tactical AI")
		while battle._busy: await get_tree().process_frame
		await _shot("attacking")
		var defending: Dictionary = battle.L.current()
		battle._btns["Defend"].pressed.emit()
		_ok(defending["defending"], "human Defend command applies tactical defense")
		battle._btns["Auto: Off"].pressed.emit()
		var m := await _wait_modal()
		_ok(battle._ended and battle.L.is_over() == 0, "real tactical battle finishes with human victory")
		await _shot("victory")
		_press_modal(m, "OK")
		await _scene(GameState.SCENE_ADVENTURE)
		m = await _wait_modal()
		_ok(int(mine.get("pending_levels", 0)) > 0, "victory opens earned human level-up")
		await _shot("level_up")
		_press_modal(m)
		await get_tree().create_timer(0.3).timeout
		_ok(not GameState.world["heroes"].has(enemy_uid), "defeated enemy removed from map")
		_ok(mine["xp"] == xp + result["xp"] and mine["level"] == 2 and mine["pending_levels"] == 0, "XP and level applied once")
		var expected: Array = result["attacker_army"].duplicate(true)
		GameState.add_to_army(expected, result["raised_id"], result["raised"])
		_ok(result["raised"] > 0 and mine["army"] == expected, "tactical casualties and Expert Necromancy reach adventure")
		_ok(GameState.battle_result.is_empty(), "adventure consumes victory result")
		var army: Array = mine["army"].duplicate(true)
		var saved_xp: int = mine["xp"]
		adv = await _save_reload("after victory")
		mine = GameState.world["heroes"][mine_uid]
		_ok(mine["xp"] == saved_xp and mine["army"] == army, "reload does not duplicate XP or raised creatures")
		await _shot("reloaded_victory")
		adv._make_plan(mine["pos"] + Vector2i(0, 1))
		adv._execute_move()
		while adv.busy: await get_tree().process_frame
		_ok(mine["pos"] == Vector2i(10, 11), "human can move after battle and reload")

	func _defend_retreat() -> void:
		_fixture()
		mine["xp"] = 0
		mine["army"] = [{"id": "skeleton", "count": 3}, null, null, null, null, null, null]
		enemy["army"] = [{"id": "pikeman", "count": 100}, null, null, null, null, null, null]
		mine["movement"] = 0
		var backup := GameState.make_hero("lord_morthis", 0)
		backup["pos"] = Vector2i(4, 5)
		backup["movement"] = 0
		backup["army"] = [{"id": "bone_dragon", "count": 100}, null, null, null, null, null, null]
		GameState.world["heroes"][backup["uid"]] = backup
		GameState.world["players"][0]["heroes"].append(backup["uid"])
		var hero_id: String = mine["id"]
		var mine_uid: int = mine["uid"]
		var adv := await _open_adventure()
		adv.end_turn()
		var battle := await _scene(GameState.SCENE_BATTLE)
		_ok(GameState.world["current_player"] == 1 and battle.L.ai_side == [true, false], "End Turn lets AI initiate human-defended battle")
		while battle._busy: await get_tree().process_frame
		await _shot("defending")
		battle._btns["Retreat"].pressed.emit()
		var m := await _wait_modal()
		_press_modal(m, "Yes")
		m = await _wait_modal()
		await _shot("retreat_result")
		_press_modal(m, "OK")
		adv = await _scene(GameState.SCENE_ADVENTURE)
		while adv.busy or GameState.world["current_player"] != 0: await get_tree().process_frame
		_ok(result["fled"] == 1 and result["retreated"], "human defender retreat recorded")
		_ok(not GameState.world["heroes"].has(mine_uid), "retreat removes deployed hero")
		_ok(GameState.world.get("tavern_keep", {}).has(hero_id), "retreated hero is available for rehiring")
		_ok(GameState.world["day"] == 2, "interrupted AI turn resumes and advances exactly one day")
		_ok(GameState.world["players"][1]["ai_day"] == 1, "AI town management remains stamped once for the interrupted day")
		await _save_reload("after AI turn")
		_ok(GameState.world["day"] == 2 and GameState.world.get("tavern_keep", {}).has(hero_id), "reload preserves date and retreat record")
		await _shot("reloaded_retreat")
