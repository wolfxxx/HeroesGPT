extends Node
## Fixed siege layouts for regressions and screenshots, independent of auto-battle timing.
## --headless res://tools/battle_visual_test.tscn runs assertions.
## With -- --shot=shots/x.png --case=crowd|distant|corpses|lightning|wreck|movement, holds that layout for Shot.

var battle: Node2D
var failures := 0
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Shot.setup = "siege"
	Shot.args["seed"] = "5"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	battle._ended = true
	battle.L.obstacles.clear()
	for i in [1, 3]:
		battle.L.walls[i]["hp"] = 0
		battle._set_wall(i, true)
	_place("angel", Vector2i(10, 7))
	_place("vampire", Vector2i(10, 8))
	_place("ghost", Vector2i(10, 6))
	_place("cavalier", Vector2i(8, 7))
	_place("bone_dragon", Vector2i(7, 8))
	_focus("vampire")
	if Shot.active:
		match Shot.args.get("case", "crowd"):
			"distant": _focus("pikeman")
			"corpses": _corpses()
			"wreck": _wreck()
			"cast":  # the attacking hero acting out a spell (its painted cast pose)
				await get_tree().create_timer(maxf(0.1, float(Shot.args.get("delay", "3")) - 0.6)).timeout
				battle._hero_cast(0)
			"movement":
				await get_tree().create_timer(maxf(0.1, float(Shot.args.get("delay", "3")) - 0.35)).timeout
				_move_ghost()
			"lightning":
				# Capture the real spell animation near its peak, on a fixed target.
				await get_tree().create_timer(maxf(0.1, float(Shot.args.get("delay", "3")) - 0.15)).timeout
				var target := _stack("lich")
				battle._anim_spell({"spell": "lightning_bolt", "side": 0, "targets": [target],
					"hex": target["hex"], "dmg": {}, "killed": {}})
		return
	await get_tree().create_timer(0.7).timeout
	_check_separation()
	_check(_alpha("vampire") > 0.99, "active Vampire stays opaque")
	_check(_alpha("angel") < 0.6, "Angel overlapping the active Vampire fades")
	_check(_alpha("pikeman") > 0.99, "remote Pikeman stays opaque")
	# Logic has already advanced, but the Vampire's turn is still being animated.
	battle.L.order = [_stack("pikeman")]
	await get_tree().create_timer(0.3).timeout
	_check(_alpha("angel") < 0.6, "focus follows displayed action, not the next rules turn")
	_focus("pikeman")
	await get_tree().create_timer(0.4).timeout
	for id in ["angel", "vampire", "ghost", "bone_dragon", "cavalier"]:
		_check(_alpha(id) > 0.99, "unfocused cluster is opaque: " + id)
	# Hovering either member of a crowd uses the same silhouette rule.
	battle._hover = _stack("vampire")["hex"]
	await get_tree().create_timer(0.4).timeout
	_check(_alpha("angel") < 0.6, "hover reveals Vampire")
	battle._hover = Vector2i(-1, -1)
	var ghost_node: Node2D = battle._unit(_stack("ghost"))
	var start := ghost_node.position
	_move_ghost()
	await get_tree().create_timer(0.1).timeout
	_check(ghost_node.get_meta("moving", false) and ghost_node.position.distance_to(start) > 1.0
		and ghost_node.position.distance_to(battle.stand_pos(_stack("ghost"))) > 1.0, "crowd settling does not snap a moving flyer to its destination")
	await get_tree().create_timer(1.2).timeout
	_check(not ghost_node.get_meta("moving", false) and ghost_node.position.distance_to(battle.stand_pos(_stack("ghost"))) < 0.1,
		"moving flyer lands on its footprint and releases crowd settling")
	_corpses()
	await get_tree().create_timer(0.7).timeout
	var corpse: Sprite2D = battle._unit(_stack("bone_dragon")).get_node("Sprite")
	_check(corpse.modulate.r > 0.75, "corpse does not multiply its paint down to charcoal")
	_check(corpse.material.get_shader_parameter("saturation") < 0.3, "corpse is desaturated")
	_check(not battle._unit(_stack("bone_dragon")).get_node("Badge").visible, "corpse has no count badge")
	_wreck()
	await get_tree().create_timer(0.7).timeout
	for id in ["ballista", "first_aid_tent", "ammo_cart", "catapult"]:
		if _stack(id).is_empty():
			continue
		var wreck: Sprite2D = battle._unit(_stack(id)).get_node("Sprite")
		_check(wreck.texture.resource_path.ends_with(id + "_dead.png"), "destroyed %s uses its wreck" % id)
		_check(is_zero_approx(wreck.rotation), "%s wreck lies level instead of rotating the intact machine" % id)
		_check(wreck.get_rect().size.x * wreck.scale.x < 230.0, "%s wreck fits the machine footprint" % id)
		_check(wreck.material.get_shader_parameter("saturation") > 0.5, "%s wreck keeps its painted colours" % id)
	battle.L.walls[2]["hp"] = 1
	battle._show_battered()
	_check(battle._battered[2].texture != null and battle._battered[2].visible, "a wall hit once shows its battered painting")
	_check(not battle._battered[4].visible and not battle._battered[1].visible, "battered look only on the hit segment")
	# count boxes as the classic (by the spells on a stack, not by side) and the rings in the players' flag colours
	var mood: Callable = battle._Badge.mood
	_check(mood.call({"effects": {}}) == "none", "a count box with no spell is the plain purple")
	_check(mood.call({"effects": {"bless": 2, "haste": 1}}) == "good", "good spells only: green")
	_check(mood.call({"effects": {"curse": 2}}) == "bad" and mood.call({"effects": {"disease": 3}}) == "bad", "bad spells or disease: red")
	_check(mood.call({"effects": {"bless": 2, "slow": 1}}) == "both", "both: yellow")
	var keep: Array = battle.L.players.duplicate()
	battle.L.players = [1, -1]
	_check(battle.side_color(0) == GameData.PLAYER_COLORS[1], "the attacker's colour is its player's flag (Blue attacking)")
	_check(battle.side_color(1) not in GameData.PLAYER_COLORS, "neutral creatures are grey")
	battle.L.players = keep
	# the catapult's shot is heard: its launch, then the stone on the wall or a splash short of it
	var cat = null
	for st in battle.L.stacks:
		if st["id"] == "catapult": cat = st
	_check(cat != null, "the attacker brings its catapult")
	if cat != null:
		for hit in [true, false]:
			Audio._last_played.erase("catapult_launch")
			Audio._last_played.erase("catapult_hit")
			Audio._last_played.erase("catapult_miss")
			await battle._anim_catapult({"s": cat, "seg": 2, "hit": hit, "destroyed": false})
			_check(Audio._last_played.has("catapult_launch") and Audio._last_played.has("catapult_hit" if hit else "catapult_miss"),
				"a catapult %s is heard" % ("hit" if hit else "miss"))
	# the ballista's shot is its own deep thunk, an archer's the bow string
	var bal = null
	var target = null
	for st in battle.L.stacks:
		if st["id"] == "ballista" and st["side"] == 0: bal = st
		if st["side"] == 1 and st["alive"] and not st.get("machine", false) and target == null: target = st
	if bal != null and target != null:
		Audio._last_played.erase("ballista_shot")
		Audio._last_played.erase("arrow_shot")
		await battle._anim_attack({"a": bal, "d": target, "ranged": true, "killed": 0, "dmg": 1, "lucky": false})
		_check(Audio._last_played.has("ballista_shot") and not Audio._last_played.has("arrow_shot"), "the ballista's shot is its own sound")
	# the heroes beside the field: resting on their first idle frame, a loop through the frames, a cast pose
	var f0 = battle._hero_figs[0]
	_check(f0 != null and f0[0].texture.resource_path.ends_with("_idle0.png"), "the hero rests on its first idle frame")
	if f0 != null:
		battle._hero_loop(0)
		await get_tree().create_timer(0.25).timeout
		_check(f0[0].texture.resource_path.contains("_idle") and not f0[0].texture.resource_path.ends_with("_idle0.png"), "the idle loop shows the other frames")
		battle._hero_cast(0)
		await get_tree().create_timer(0.3).timeout
		_check(f0[0].texture.resource_path.ends_with("_cast.png"), "casting a spell shows the cast pose")
		await get_tree().create_timer(1.2).timeout
		_check(f0[0].texture.resource_path.ends_with("_idle0.png") and not battle._hero_busy[0], "and the hero rests again")
	print("BATTLE VISUAL TEST: %d checks, failures: %d" % [checks, failures])
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func _stack(id: String) -> Dictionary:
	for s in battle.L.stacks:
		if s["id"] == id:
			return s
	return {}

func _move_ghost() -> void:
	var ghost := _stack("ghost")
	var old: Vector2i = ghost["hex"]
	ghost["hex"] = Vector2i(6, 3)
	await battle._anim_move(ghost, [old, ghost["hex"]])

func _check_separation() -> void:
	var ids := ["ghost", "angel", "vampire"]
	var positions := []
	var cells := []
	for id in ids:
		var st := _stack(id)
		var n: Node2D = battle._unit(st)
		positions.append(n.position)
		cells.append(battle.L.cells(st).duplicate())
		_check(n.position.distance_to(battle._footprint_center(st, st["hex"])) <= 18.01, "crowd shift stays within footprint: " + id)
	var separated := _overlap_samples("ghost", "angel") + _overlap_samples("angel", "vampire")
	for id in ids:
		var st := _stack(id)
		battle._unit(st).position = battle._footprint_center(st, st["hex"])
	var centered := _overlap_samples("ghost", "angel") + _overlap_samples("angel", "vampire")
	for i in ids.size():
		battle._unit(_stack(ids[i])).position = positions[i]
		_check(battle.L.cells(_stack(ids[i])) == cells[i], "presentation keeps combat cells unchanged: " + ids[i])
	_check(separated < centered, "staggering reduces painted silhouette overlap (%d < %d samples)" % [separated, centered])
	print("CROWD OVERLAP: %d -> %d opaque samples" % [centered, separated])

func _overlap_samples(a_id: String, b_id: String) -> int:
	var a: Sprite2D = battle._unit(_stack(a_id)).get_node("Sprite")
	var b: Sprite2D = battle._unit(_stack(b_id)).get_node("Sprite")
	var box: Rect2 = (a.global_transform * a.get_rect()).intersection(b.global_transform * b.get_rect())
	var count := 0
	for y in range(int(box.position.y), int(box.end.y), 2):
		for x in range(int(box.position.x), int(box.end.x), 2):
			var p := Vector2(x, y)
			if a.is_pixel_opaque(a.to_local(p)) and b.is_pixel_opaque(b.to_local(p)): count += 1
	return count

func _place(id: String, hex: Vector2i) -> void:
	var s := _stack(id)
	s["hex"] = hex
	battle._unit(s).position = battle.stand_pos(s)

func _focus(id: String) -> void:
	var s := _stack(id)
	battle.L.order = [s]
	battle._acting_uid = s["uid"]
	battle._grid.active = s
	battle._refresh_queue()
	for unit in battle.units.values():
		battle._ring(unit).active = unit == battle._unit(s)
		var material: ShaderMaterial = unit.get_node("Sprite").material
		if material:
			material.set_shader_parameter("ink", Color(1, 0.82, 0.25) if unit == battle._unit(s) else Color(0.09, 0.06, 0.03, 0.95))
			material.set_shader_parameter("width", 3.0 if unit == battle._unit(s) else 1.2)

func _alpha(id: String) -> float:
	return battle._unit(_stack(id)).get_meta("body_alpha", 1.0)

func _corpses() -> void:
	_focus("pikeman")
	for id in ["bone_dragon", "swordsman", "zombie"]:
		var s := _stack(id)
		s["alive"] = false
		s["count"] = 0
		battle._anim_death(s)

func _wreck() -> void:
	_focus("pikeman")
	for id in ["ballista", "first_aid_tent", "ammo_cart", "catapult"]:
		var s := _stack(id)
		if s.is_empty():
			continue
		s["alive"] = false
		s["count"] = 0
		battle._anim_death(s)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
