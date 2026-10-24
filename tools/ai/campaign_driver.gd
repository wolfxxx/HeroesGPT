extends "res://scripts/adventure/adventure.gd"
## Headless adapter: execute the production movement, visits, AI and instant-battle path.
## Rendering and modal game-over announcements alone are disabled. All players must be AI.
var battles := 0
var trace: FileAccess
var run_label := ""

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func configure(state: Dictionary) -> void:
	GameState.world = state
	world = state
	rules = AdvRules.new(world)
	ai = AdvAI.new(rules)
	if view == null:
		view = SilentView.new()
		add_child(view)
		hud = SilentHUD.new()
		add_child(hud)
	view.world = world

func _visible_to_human(_pos: Vector2i) -> bool:
	return false

func _check_game_over() -> bool:
	return false # the harness records elimination without opening a modal or deleting the world

func _start_battle(setup: Dictionary, _involves_human: bool) -> String:
	battles += 1
	return await super._start_battle(setup, false)

func move_hero(hero: Dictionary, plan: Dictionary, animate: bool) -> String:
	var before: Vector2i = hero["pos"]
	var movement: int = hero["movement"]
	var army := GameState.army_strength(hero["army"])
	var xp: int = hero["xp"]
	var target: Dictionary = plan["target"]
	var result := await super.move_hero(hero, plan, animate)
	if trace:
		_record({"event": "move", "hero": hero["uid"], "owner": hero["owner"], "from": before,
			"to": hero["pos"], "goal": plan["path"].back(), "kind": plan["kind"],
			"target": target.get("type", plan["kind"]), "target_uid": target.get("uid", -1),
			"cost": movement - hero["movement"], "army_change": GameState.army_strength(hero["army"]) - army,
			"xp_change": hero["xp"] - xp})
	return result

func record_turn(player: Dictionary) -> void:
	if not trace: return
	var heroes := []
	for hid in player["heroes"]:
		var h: Dictionary = world["heroes"][hid]
		heroes.append({"uid": hid, "pos": h["pos"], "strength": ai._strength(h), "army": h["army"],
			"movement": h["movement"], "goal": h.get("ai_goal", {})})
	var towns := []
	for tid in player["towns"]:
		var t: Dictionary = world["towns"][tid]
		towns.append({"uid": tid, "pos": t["pos"], "garrison": GameState.army_strength(t["garrison"]),
			"available": t["available"], "buildings": t["buildings"]})
	_record({"event": "turn", "owner": player["index"], "resources": player["resources"], "heroes": heroes, "towns": towns})

func _record(event: Dictionary) -> void:
	event["run"] = run_label
	event["day"] = world["day"]
	trace.store_line(JSON.stringify(event))

class SilentView extends MapView:
	func rebuild_objects() -> void: pass
	func refresh_object(_uid: int) -> void: pass
	func remove_object(_uid: int) -> void: pass
	func hero_node(_uid: int) -> Node2D: return null

class SilentHUD extends AdventureHUD:
	func refresh() -> void: pass
	func toast(_text: String, _duration := 3.0) -> void: pass
	func set_turn_label(_t: String) -> void: pass
