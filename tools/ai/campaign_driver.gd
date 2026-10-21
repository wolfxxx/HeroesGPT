extends "res://scripts/adventure/adventure.gd"
## Headless adapter: execute the production movement, visits, AI and instant-battle path.
## Rendering and modal game-over announcements alone are disabled. All players must be AI.
var battles := 0

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

class SilentView extends MapView:
	func rebuild_objects() -> void: pass
	func refresh_object(_uid: int) -> void: pass
	func remove_object(_uid: int) -> void: pass
	func hero_node(_uid: int) -> Node2D: return null

class SilentHUD extends AdventureHUD:
	func refresh() -> void: pass
	func toast(_text: String, _duration := 3.0) -> void: pass
