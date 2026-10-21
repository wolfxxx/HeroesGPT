extends Node
## Fixed siege layouts for regressions and screenshots, independent of auto-battle timing.
## --headless res://tools/battle_visual_test.tscn runs assertions.
## With -- --shot=shots/x.png --case=crowd|distant|corpses|lightning|wreck, holds that layout for Shot.

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
			"lightning":
				# Capture the real spell animation near its peak, on a fixed target.
				await get_tree().create_timer(maxf(0.1, float(Shot.args.get("delay", "3")) - 0.15)).timeout
				var target := _stack("lich")
				battle._anim_spell({"spell": "lightning_bolt", "side": 0, "targets": [target],
					"hex": target["hex"], "dmg": {}, "killed": {}})
		return
	await get_tree().create_timer(0.7).timeout
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
	_corpses()
	await get_tree().create_timer(0.7).timeout
	var corpse: Sprite2D = battle._unit(_stack("bone_dragon")).get_node("Sprite")
	_check(corpse.modulate.r > 0.75, "corpse does not multiply its paint down to charcoal")
	_check(corpse.material.get_shader_parameter("saturation") < 0.3, "corpse is desaturated")
	_check(not battle._unit(_stack("bone_dragon")).get_node("Badge").visible, "corpse has no count badge")
	_wreck()
	await get_tree().create_timer(0.7).timeout
	var wreck: Sprite2D = battle._unit(_stack("ballista")).get_node("Sprite")
	_check(wreck.texture.resource_path.ends_with("ballista_dead.png"), "destroyed ballista uses its wreck")
	_check(is_zero_approx(wreck.rotation), "wreck lies level instead of rotating the intact machine")
	_check(wreck.get_rect().size.x * wreck.scale.x < 230.0, "native-resolution wreck fits the machine footprint")
	print("BATTLE VISUAL TEST: %d checks, failures: %d" % [checks, failures])
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func _stack(id: String) -> Dictionary:
	for s in battle.L.stacks:
		if s["id"] == id:
			return s
	return {}

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
	var s := _stack("ballista")
	s["alive"] = false
	s["count"] = 0
	battle._anim_death(s)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
