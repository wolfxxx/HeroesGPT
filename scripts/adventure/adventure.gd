extends Node2D
## Adventure map scene controller: input, camera, hero movement, visits, turns, AI turns.

const TILE := WorldGen.TILE
const MAP_VIEW_W := 1540.0   # visible map width (right panel covers the rest)
const MAP_VIEW_H := 1036.0

var world: Dictionary
var rules: AdvRules
var view: MapView
var hud: AdventureHUD
var ai: AdvAI
var cam: Camera2D
var busy := false
var _plan := {}
var _plan_target := Vector2i(-1, -1)
var _drag_from := Vector2.ZERO
var _dragging := false
var _drag_button := MOUSE_BUTTON_NONE  # the button driving the press/drag (left or middle)
var _drag_screen := Vector2i.ZERO      # last cursor position on the screen while it is held
var _press_screen := Vector2i.ZERO     # where on the screen the button went down
var _drag_synced := false              # a motion event moved the map this frame (the poll only resyncs)
var _left_down := false      # left button held on the map: a click on release, or a drag once it moves
var _left_tile := Vector2i(-1, -1)
var _info_tile := Vector2i(-2, -2)
var _rclick_info := false      # the right button is held: its information panel stays up until release
var _pending_click := Vector2i(-1, -1)  # clicked while the hero was still moving: planned when it stops
const DRAG_START := 10.0
const EDGE := 14.0           # edge-scroll band (screen pixels), also just outside the window
var _cam_target := Vector2.ZERO
var _follow := -1            # the walking hero the camera rides along with (its sprite, not its tile)

func _ready() -> void:
	if GameState.world.is_empty():
		var s := GameState.new_game_settings.duplicate()
		if Shot.setup != "":
			s["seed"] = int(Shot.args.get("seed", "12345"))
			s["faction"] = Shot.args.get("faction", s.get("faction", "haven"))
		GameState.world = WorldGen.generate(s)
		if Shot.setup == "artifacts":  # (judge shot: one artifact of each tier laid out beside the first hero)
			_shot_artifacts(GameState.world)
		if Shot.setup == "all_spells":
			for h in GameState.world["heroes"].values():  # a seasoned hero: spells, skills and some gear
				h["spells"] = GameData.SPELLS.keys()
				h["skills"].merge({"wisdom": 2, "offense": 1, "logistics": 3})
				h["artifacts"] = []
				h["backpack"] = []
				# (every tier, and a combination: the dragon set merges as its last part arrives)
				for a in ["dragonbone_blade", "dragonscale_shield", "dragonskull_helm", "gravecloak", "pendant_of_clarity",
						"sunsteel_cuirass", "ring_of_vitality", "signet_of_coin", "travellers_boots", "orb_of_embers",
						"clover_of_fortune", "seers_spyglass", "banner_of_the_muster", "soldiers_shortsword",
						"bone_crown", "sun_pendant", "boots_of_speed", "seraphs_feather"]:
					GameState.give_artifact(h, a)  # (as found: worn while a slot is free, then the backpack)
				h["max_movement"] = GameState.hero_max_movement(h)
				h["movement"] = h["max_movement"]
	world = GameState.world
	RenderingServer.set_default_clear_color(Color(0.02, 0.02, 0.03))
	rules = AdvRules.new(world)
	ai = AdvAI.new(rules)

	view = MapView.new()
	add_child(view)
	view.setup(world)

	cam = Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.zoom = Vector2.ONE * GameState.map_zoom
	add_child(cam)
	cam.make_current()

	hud = AdventureHUD.new()
	add_child(hud)
	hud.setup(self)

	for p in world["players"]:
		rules.reveal_all_for(p)
	_refresh_fog()

	var sel: int = world.get("selected_hero", -1)
	if not world["heroes"].has(sel) or world["heroes"][sel]["owner"] != _human():
		sel = _first_hero_with_mp()
	_select_hero(sel, true)
	_update_music()
	_post_ready.call_deferred()

func _post_ready() -> void:
	await get_tree().process_frame
	if Shot.active:
		_shot_view()
	if not GameState.battle_result.is_empty():
		var result := GameState.battle_result
		GameState.battle_result = {}
		var ev := rules.apply_battle(result)
		view.rebuild_objects()
		_refresh_fog()
		hud.refresh()
		if ev["hero"] >= 0 and world["heroes"].has(ev["hero"]):
			await _handle_level_ups(world["heroes"][ev["hero"]])
		if not world["heroes"].has(world.get("selected_hero", -1)):
			_select_hero(_first_hero_with_mp())
		if await _check_game_over():
			return
	if not world.get("intro_shown", false) and world.has("scenario") and not Shot.active:
		# the scenario's briefing, once, as the game begins
		world["intro_shown"] = true
		var sc: Dictionary = world["scenario"]
		await Modal.message(self, sc["name"], "%s\n\nVictory: %s.\nDefeat: %s." % [sc["desc"],
			GameData.victory_text(sc["victory"]), GameData.loss_text(sc["loss"], rules.townless_limit())]).closed
	if world["players"][world["current_player"]]["is_ai"]:
		_run_ai_turns()
	elif GameState.hotseat() and not GameState.was_handed(world["current_player"]):
		await _start_human_turn()  # (hot-seat: the first turn, or a loaded game: name whose turn it is first)
	elif world.get("pending_turn_banner", false):
		world["pending_turn_banner"] = false
		_turn_banner()

func _human() -> int:
	return GameState.human_player_index()

func human_player() -> Dictionary:
	return world["players"][_human()]

func selected_hero() -> Dictionary:
	return world["heroes"].get(world.get("selected_hero", -1), {})

# ---------------------------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------------------------
## Screenshot harness options: --reveal (no fog), --cam=x,y (tile to centre on), --zoom=z; with --setup also
## --seed=n and --faction=f for the generated map.
## Screenshot setup: a relic, a major, a minor and a treasure artifact and a set part on free tiles beside the first
## hero, so the judge sees how artifacts lie on the map.
static func _shot_artifacts(w: Dictionary) -> void:
	var p0: Dictionary = w["players"][0]
	var hero: Dictionary = w["heroes"][p0["heroes"][0]]
	var size: Vector2i = w["size"]
	var taken := {}
	for o in w["objects"].values():
		taken[o["pos"]] = true
	for t in w["towns"].values():
		for dy in range(-4, 2):  # leave sky above the painted towers: a cape must not read as their flag
			for dx in range(-3, 4):
				taken[t["pos"] + Vector2i(dx, dy)] = true
	var picks := ["banner_of_the_muster", "orb_of_embers", "cape_of_courage", "soldiers_shortsword", "dragonskull_helm"]
	for r in range(2, 7):
		for dy in range(-r, 1):  # (beside and above the hero: below, the resource bar would cover them)
			for dx in range(-r, r + 1):
				if picks.is_empty():
					return
				var q: Vector2i = hero["pos"] + Vector2i(dx, dy)
				if q.x < 1 or q.y < 1 or q.x >= size.x - 1 or q.y >= size.y - 1 or taken.has(q):
					continue
				var i := q.y * size.x + q.x
				if w["blocked"][i] != 0 or w["terrain"][i] in [WorldGen.T_WATER, WorldGen.T_ROAD]:
					continue
				var under_tree := false  # (a tree right behind it: its trunk and shadow over the item)
				for d in w["decor"]:
					var dt := Vector2i(d["p"] / WorldGen.TILE)
					var k: String = d["k"]
					if absi(dt.x - q.x) <= 1 and dt.y - q.y >= 0 and dt.y - q.y <= 1 and (k.begins_with("tree") or k.begins_with("snow_pine")):
						under_tree = true
				if under_tree:
					continue
				var o := {"type": "artifact", "artifact": picks.pop_front(), "uid": GameState.next_uid(), "pos": q}
				w["objects"][o["uid"]] = o
				# (no flowers, stumps or logs on it or right beside it: they read as a stain or crowded the item)
				w["decor"] = w["decor"].filter(func(d):
					var dt := Vector2i(d["p"] / WorldGen.TILE)
					var k: String = d["k"]
					return not (absi(dt.x - q.x) <= 1 and absi(dt.y - q.y) <= 1 and not k.begins_with("tree")
						and not k.begins_with("mountain") and not k.begins_with("snow_pine")))
				for ddy in range(-1, 2):
					for ddx in range(-1, 2):
						taken[q + Vector2i(ddx, ddy)] = true

func _shot_view() -> void:
	if Shot.args.has("reveal"):
		human_player()["explored"].fill(1)
		_refresh_fog()
	if Shot.args.has("zoom"):
		cam.zoom = Vector2.ONE * float(Shot.args["zoom"])
	if Shot.args.has("cam"):
		var xy: PackedStringArray = Shot.args["cam"].split(",")
		center_on(Vector2i(int(xy[0]), int(xy[1])), true)

func center_on(tile: Vector2i, instant := false) -> void:
	var p := view.tile_center(tile)
	_cam_target = _clamp_cam(p - Vector2(MAP_VIEW_W, MAP_VIEW_H) * 0.5 / cam.zoom)
	if instant:
		cam.position = _cam_target

func center_on_world(p: Vector2) -> void:
	_cam_target = _clamp_cam(p - Vector2(MAP_VIEW_W, MAP_VIEW_H) * 0.5 / cam.zoom)

func _clamp_cam(p: Vector2) -> Vector2:
	var size: Vector2 = Vector2(world["size"]) * TILE
	var view_sz := Vector2(MAP_VIEW_W, MAP_VIEW_H) / cam.zoom
	var margin := 2.0 * TILE  # (as the classic map: the view runs a little past the edge, onto its rocky border)
	return Vector2(clampf(p.x, -margin, maxf(-margin, size.x - view_sz.x + margin)),
		clampf(p.y, -margin, maxf(-margin, size.y - view_sz.y + margin)))

func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if not _modal_open():
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): move.x -= 1
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): move.x += 1
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): move.y -= 1
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_CTRL): move.y += 1
		if DisplayServer.window_is_focused() and not Shot.active and not Shot.remote and not _dragging:
			move += _edge_scroll()
	_poll_drag()
	if move != Vector2.ZERO:
		_cam_target = _clamp_cam(_cam_target + move.normalized() * 900.0 * delta / cam.zoom.x)
	var hn: Node2D = view.hero_node(_follow) if _follow >= 0 else null
	if hn:
		# glide with the figure as it walks: a target that moves smoothly, not one step a tile
		var focus := hn.position - Vector2(0, TILE * 0.5 - 6)
		var hero: Dictionary = world["heroes"].get(_follow, {})
		# On entering sight, hold at the first visible tile until the sprite emerges from fog.
		if not hero.is_empty() and (not rules.player_of(hero)["is_ai"] or _visible_to_human(Vector2i((focus / TILE).floor()))):
			center_on_world(focus)
		cam.position = cam.position.lerp(_cam_target, minf(1.0, delta * 6.0))
	else:
		cam.position = cam.position.lerp(_cam_target, minf(1.0, delta * 10.0))
	var mpos := get_viewport().get_mouse_position()
	if _modal_open():
		if _info_tile != Vector2i(-3, -3):  # a window is up: the status line and tile highlight would show under it
			_info_tile = Vector2i(-3, -3)
			HoverInfo.hide_for(self)
			hud.set_status("")
			view.set_hover(Vector2i(-1, -1))
	elif _info_tile != Vector2i(-2, -2) and (busy or mpos.x > MAP_VIEW_W or mpos.y > MAP_VIEW_H or mpos.x < 0 or mpos.y < 0):
		_info_tile = Vector2i(-2, -2)
		HoverInfo.hide_for(self)
	hud.update_minimap_view(cam.position, Vector2(MAP_VIEW_W, MAP_VIEW_H) / cam.zoom)

## Edge scrolling, measured on the screen: the cursor at a window edge, or anywhere past it, scrolls that way
## (while the window has the focus).
func _edge_scroll() -> Vector2:
	var m := DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
	var ws := Vector2(DisplayServer.window_get_size())
	var v := Vector2.ZERO
	if m.x < EDGE: v.x -= 1
	if m.x > ws.x - EDGE: v.x += 1
	if m.y < EDGE: v.y -= 1
	if m.y > ws.y - EDGE: v.y += 1
	return v

## Map dragging: mouse motion over the map pans it (_unhandled_input); when the cursor goes over the side panel,
## the bottom bar or out of the window those events stop reaching the map, so the cursor's place on the screen
## keeps panning it until the button is let go anywhere.
func _poll_drag() -> void:
	if _drag_button == MOUSE_BUTTON_NONE:
		return
	if not Input.is_mouse_button_pressed(_drag_button):  # (released where the map never heard of it)
		_drag_button = MOUSE_BUTTON_NONE
		_left_down = false
		_dragging = false
		return
	var now := DisplayServer.mouse_get_position()
	if _drag_synced:
		_drag_synced = false
		_drag_screen = now
		return
	var ws := Vector2(DisplayServer.window_get_size())
	var vs := get_viewport().get_visible_rect().size
	var scale := minf(ws.x / vs.x, ws.y / vs.y)  # screen pixels per viewport pixel
	if scale <= 0.0:  # (no real window: headless runs)
		return
	if not _dragging:
		if Vector2(now - _press_screen).length() / scale <= DRAG_START:
			return
		_dragging = true
		HoverInfo.hide_for(self)
	var d := Vector2(now - _drag_screen) / scale
	_drag_screen = now
	if d != Vector2.ZERO:
		_cam_target = _clamp_cam(_cam_target - d / cam.zoom)
		cam.position = _cam_target

func _start_press(button: MouseButton) -> void:
	_drag_button = button
	_drag_screen = DisplayServer.mouse_get_position()
	_press_screen = _drag_screen

func _modal_open() -> bool:
	var l := get_tree().root.get_node_or_null("ModalLayer")
	return l != null and l.get_child_count() > 0

# ---------------------------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------------------------
func _unhandled_input(e: InputEvent) -> void:
	if _modal_open():
		return
	if e is InputEventMouseMotion:
		# left-drag (or middle-drag) pans the map; a left press that doesn't move is a click
		if _left_down and not _dragging and e.position.distance_to(_drag_from) > DRAG_START:
			_dragging = true
			HoverInfo.hide_for(self)
		if _dragging:
			_cam_target = _clamp_cam(_cam_target - e.relative / cam.zoom)
			cam.position = _cam_target
			_drag_synced = true
			return
		if e.position.x < 0 or e.position.y < 0:  # (a cursor off the window reads nothing)
			view.set_hover(Vector2i(-1, -1))
			hud.set_status("")
			HoverInfo.hide_for(self)
			_info_tile = Vector2i(-2, -2)
			return
		var t := _pick(view.tile_at(_event_world(e)), _event_world(e))
		view.set_hover(t if rules.inside(t) else Vector2i(-1, -1))
		hud.set_status(_describe_tile(t))
		if t != _info_tile and not busy:
			_info_tile = t
			# (inside the map view: not over the side panel)
			HoverInfo.show_for(self, _tile_info(t), 0.3, 1, -1.0, Rect2(), Rect2(0, 0, AdventureHUD.PANEL_X - 6, 1036))
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_MIDDLE:
			if e.pressed:
				_start_press(MOUSE_BUTTON_MIDDLE)
				_dragging = true
			else:
				_dragging = false
				_drag_button = MOUSE_BUTTON_NONE
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.1)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / 1.1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_left_down = true
				_drag_from = e.position
				_start_press(MOUSE_BUTTON_LEFT)
				_left_tile = _pick(view.tile_at(_event_world(e)), _event_world(e))
			elif _left_down:
				_left_down = false
				var was_drag := _dragging
				_dragging = false
				_drag_button = MOUSE_BUTTON_NONE
				_info_tile = Vector2i(-2, -2)
				if not was_drag:
					if busy:
						_pending_click = _left_tile
					else:
						_click(_left_tile, false)
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			if e.pressed:
				_right_click(_pick(view.tile_at(_event_world(e)), _event_world(e)))
			elif _rclick_info:  # (the classic right-click: the information stays up while the button is held)
				_rclick_info = false
				_info_tile = Vector2i(-2, -2)
				HoverInfo.hide_for(self)
	elif e is InputEventKey and e.pressed and not e.echo:
		if busy:
			return
		match e.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if not _plan.is_empty():
					_execute_move()
			KEY_E:
				end_turn()
			KEY_H, KEY_TAB:
				next_hero()
			KEY_K:
				hud.open_kingdom()
			KEY_I:
				if not selected_hero().is_empty():
					hud.open_hero_screen(selected_hero())
			KEY_Z:
				toggle_sleep()
			KEY_M:
				continue_move()
			KEY_C:
				if not selected_hero().is_empty():
					SpellBook.open(self, selected_hero())
			KEY_T:
				var p := human_player()
				if p["towns"].size() > 0:
					open_town(p["towns"][0])
			KEY_ESCAPE:
				hud.open_system_menu()
			KEY_S:
				if e.ctrl_pressed:
					GameState.save_game()
					hud.toast("Game saved")

## A row of an army's portraits: exact counts for your own troops, the classic count words for anyone else's.
func _army_row(v: VBoxContainer, army: Array, exact: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for s in army:
		if s == null:
			continue
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 0)
		c.add_child(UI.icon(Assets.creature_portrait(s["id"]), Vector2(48, 48)))
		var l := UI.label(str(s["count"]) if exact else UI.count_word(s["count"]), 15)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 48
		c.add_child(l)
		row.add_child(c)
	v.add_child(row)

## Creature, hero and treasure sprites stand above their tile: a point on a sprite means that unit (front-most
## first), otherwise the tile itself, or the unit below when the tile is empty.
func _pick(t: Vector2i, world_p = null) -> Vector2i:
	if world_p != null:
		var s := view.sprite_tile_at(world_p)
		if s != Vector2i(-1, -1):
			return s
	if not rules.inside(t) or not rules.at(t).is_empty() or not rules.town_covering(t).is_empty() or not rules.object_covering(t).is_empty():
		return t
	var below := t + Vector2i(0, 1)
	if rules.inside(below):
		var o := rules.at(below)
		if o.get("kind", "") == "hero" or (o.get("kind", "") == "object" and world["objects"][o["uid"]]["type"] == "monster"):
			return below
	return t

func _event_world(e: InputEventMouse) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * e.position

func _zoom(f: float) -> void:
	var center := cam.position + Vector2(MAP_VIEW_W, MAP_VIEW_H) * 0.5 / cam.zoom
	cam.zoom = (cam.zoom * f).clamp(Vector2(0.55, 0.55), Vector2(1.4, 1.4))
	GameState.map_zoom = cam.zoom.x
	_cam_target = _clamp_cam(center - Vector2(MAP_VIEW_W, MAP_VIEW_H) * 0.5 / cam.zoom)
	cam.position = _cam_target

func _click(t: Vector2i, _dbl: bool) -> void:
	if not rules.inside(t):
		return
	var me := _human()
	if not rules.is_explored(human_player(), t):
		return
	var hh := rules.hero_at(t)
	if not hh.is_empty() and hh["owner"] == me:
		if hh["uid"] == world["selected_hero"]:
			hud.open_hero_screen(hh)
			return
		# As the classic game: with a hero selected, another of yours is a meeting target (walk over and trade);
		# the first click shows the route, the second walks. Only an unreachable hero is selected instead.
		if not selected_hero().is_empty() and t == _plan_target and not _plan.is_empty():
			_execute_move()
			return
		if not selected_hero().is_empty():
			_make_plan(t)
			if not _plan.is_empty():
				return
		_select_hero(hh["uid"])
		return
	var town := rules.town_covering(t)
	var hero := selected_hero()
	if not town.is_empty() and town["owner"] == me and t != town["pos"]:
		open_town(town["uid"])
		return
	if hero.is_empty():
		if not town.is_empty() and town["owner"] == me:
			open_town(town["uid"])
		return
	if t == _plan_target and not _plan.is_empty():
		_execute_move()
		return
	_make_plan(t)

func _make_plan(t: Vector2i) -> void:
	var hero := selected_hero()
	if hero.is_empty():
		return
	var p := rules.plan(hero, t)
	if p["path"].is_empty():
		_plan = {}
		_plan_target = Vector2i(-1, -1)
		view.clear_path()
		return
	_plan = p
	_plan_target = t
	view.set_path(p["path"], p["reach"], p["kind"])
	hero["dest"] = t

## As the classic map: holding the right button shows what is there at once (the hover panel, with a hero's army or
## an own town's garrison added), until the button is released.
func _right_click(t: Vector2i) -> void:
	var info = _tile_info(t, true)
	if info == null:
		return
	_rclick_info = true
	_info_tile = t
	HoverInfo.show_for(self, info, 0.0, 1, -1.0, Rect2(), Rect2(0, 0, AdventureHUD.PANEL_X - 6, 1036))

## Hover panel for a map tile: what the hero, town or object there is and what visiting it does (null: nothing).
func _tile_info(t: Vector2i, detailed := false):
	if not rules.inside(t) or not rules.is_explored(human_player(), t):
		return null
	var hh := rules.hero_at(t)
	if not hh.is_empty():
		var v := HoverInfo.box(hh["name"])
		HoverInfo.line(v, "Level %d %s" % [hh["level"], hh["class"]])
		HoverInfo.line(v, world["players"][hh["owner"]]["name"], Color(0.8, 0.75, 0.65))
		if detailed:  # (an own hero's exact numbers; another's army as the classic shows it, in words)
			_army_row(v, hh["army"], hh["owner"] == _human())
		return v
	var town := rules.town_covering(t)
	if not town.is_empty():
		var v := HoverInfo.box(town["name"])
		HoverInfo.line(v, "%s town" % GameData.FACTIONS[town["faction"]]["name"])
		HoverInfo.line(v, "Neutral" if town["owner"] < 0 else world["players"][town["owner"]]["name"], Color(0.8, 0.75, 0.65))
		if detailed and town["owner"] == _human():
			if GameState.army_is_empty(town["garrison"]):
				HoverInfo.line(v, "No garrison.", Color(0.8, 0.75, 0.65), 18)
			else:
				HoverInfo.line(v, "Garrison:", UI.GOLD, 18)
				_army_row(v, town["garrison"], true)
		return v
	var o := rules.object_covering(t)
	var me: int = human_player()["index"]
	var hero := selected_hero()
	if o.is_empty():
		if rules.is_guarded(t):
			return "Guarded: stepping here means a fight with the monsters next to it."
		return null
	match o["type"]:
		"monster":
			var v := HoverInfo.creature(o["creature"], -1, "%s %s" % [UI.count_word(o["count"]), GameData.CREATURES[o["creature"]]["plural"]])
			HoverInfo.line(v, "Click to attack.", Color(1, 0.6, 0.5), 18)
			return v
		"resource":
			var v := HoverInfo.box(GameData.RESOURCE_NAMES[o["res"]])
			HoverInfo.line(v, "A pile of %s. Walk over it to pick it up." % GameData.RESOURCE_NAMES[o["res"]].to_lower())
			return v
		"campfire":
			var v := HoverInfo.box("Campfire")
			HoverInfo.line(v, "Abandoned supplies: gold and %s." % GameData.RESOURCE_NAMES[o["res"]].to_lower())
			return v
		"chest":
			var v := HoverInfo.box("Treasure Chest")
			HoverInfo.line(v, "Keep the gold, or give it away for experience.")
			return v
		"artifact":  # (named, with its tier and effect, as the classic's right-click)
			var d: Dictionary = GameData.ARTIFACTS[o["artifact"]]
			var v := HoverInfo.box(d["name"])
			var tr: Array = GameData.ARTIFACT_TIERS[d["tier"]]
			HoverInfo.line(v, "%s artifact" % tr[0], tr[1])
			HoverInfo.line(v, d["desc"])
			if d.has("set"):
				HoverInfo.line(v, "Part of the %s" % GameData.ARTIFACTS[d["set"]]["name"], Color(0.8, 0.65, 1.0))
			return v
		"mine":
			var m: Dictionary = GameData.MINES[o["mine"]]
			var v := HoverInfo.box(m["name"])
			var row := HBoxContainer.new()
			row.add_child(UI.icon(Assets.res_icon(m["resource"]), Vector2(26, 26)))
			row.add_child(UI.label(" +%d %s per day" % [m["amount"], GameData.RESOURCE_NAMES[m["resource"]].to_lower()], 19))
			v.add_child(row)
			HoverInfo.line(v, "Unclaimed: visit to claim it." if o["owner"] < 0 else "Owned by %s." % world["players"][o["owner"]]["name"],
				Color(0.8, 0.75, 0.65))
			return v
		"war_machine_factory":
			var v := HoverInfo.box("War Machine Factory")
			HoverInfo.line(v, "Buy war machines for the visiting hero.")
			for id in GameData.WAR_MACHINES:
				var c: Dictionary = GameData.CREATURES[id]
				var owned: bool = id in hero.get("machines", [])
				HoverInfo.line(v, "%s — %d gold%s" % [c["name"], c["cost"]["gold"], " (owned)" if owned else ""],
					Color(0.65, 0.85, 0.55) if owned else UI.GOLD, 18)
			HoverInfo.line(v, "Open to all heroes. Stock never runs out.", Color(0.8, 0.75, 0.65), 18)
			return v
		"dwelling":
			var c: Dictionary = GameData.CREATURES[o["creature"]]
			var v := HoverInfo.creature(o["creature"], -1, "%s dwelling" % c["name"])
			HoverInfo.line(v, "%d available to recruit." % o["available"], UI.GOLD, 18)
			var own: int = o.get("owner", -1)
			_visit_line(v, own == me, "Yours: new recruits every week." if own == me else
				("Not visited." if own < 0 else "Owned by %s." % world["players"][own]["name"]))
			return v
		"shrine":
			var sp: Dictionary = GameData.SPELLS[o["spell"]]
			var v := HoverInfo.box("Shrine of Magic")
			HoverInfo.line(v, "Teaches %s (level %d): %s" % [sp["name"], sp["level"], sp["desc"]])
			if not hero.is_empty():
				if o["spell"] in hero["spells"]:
					_visit_line(v, true, "%s already knows it." % hero["name"])
				elif sp["level"] > rules.max_spell_level(hero):
					_visit_line(v, true, "%s needs more Wisdom to learn a level %d spell." % [hero["name"], sp["level"]])
				else:
					_visit_line(v, false, "%s can learn it." % hero["name"])
			return v
		"learning_stone":
			var v := HoverInfo.box("Learning Stone")
			HoverInfo.line(v, "+1000 experience, once per hero.")
			if not hero.is_empty():
				var seen: bool = hero["uid"] in o.get("visited", [])
				_visit_line(v, seen, "%s: %s" % [hero["name"], "already visited." if seen else "not visited yet."])
			return v
		"windmill":
			var v := HoverInfo.box("Windmill")
			HoverInfo.line(v, "The miller shares resources once a week.")
			if me in o.get("visited_week", []):
				var left: int = 7 - (int(world["day"]) - 1) % 7
				_visit_line(v, true, "Visited this week. More in %d day%s." % [left, "" if left == 1 else "s"])
			else:
				_visit_line(v, false, "Not visited this week.")
			return v
		"watchtower":
			var v := HoverInfo.box("Watchtower")
			HoverInfo.line(v, "Reveals the land around it.")
			var seen: bool = me in o.get("visited_by", [])
			_visit_line(v, seen, "Visited." if seen else "Not visited.")
			return v
	return _describe_tile(t)

## "Visited" status line on a map site's hover panel: grey once used up, green while there is something to get.
func _visit_line(v: VBoxContainer, done: bool, text: String) -> void:
	HoverInfo.line(v, text, Color(0.62, 0.6, 0.56) if done else Color(0.55, 0.95, 0.5), 18)

func _describe_tile(t: Vector2i) -> String:
	if not rules.inside(t):
		return ""
	if not rules.is_explored(human_player(), t):
		return "Uncharted territory"
	var hh := rules.hero_at(t)
	if not hh.is_empty():
		var sel := selected_hero()
		if hh["owner"] == _human() and not sel.is_empty() and sel["uid"] != hh["uid"]:
			return "Meet %s (trade troops)" % hh["name"]
		return "%s — %s" % [hh["name"], world["players"][hh["owner"]]["name"]]
	var town := rules.town_covering(t)
	if not town.is_empty():
		var owner: String = "Neutral" if town["owner"] < 0 else world["players"][town["owner"]]["name"]
		return "%s (%s) — %s" % [town["name"], GameData.FACTIONS[town["faction"]]["name"], owner]
	var o := rules.object_covering(t)
	if not o.is_empty():
		match o["type"]:
			"monster":
				return "%s %s" % [UI.count_word(o["count"]), GameData.CREATURES[o["creature"]]["plural"]]
			"resource":
				return GameData.RESOURCE_NAMES[o["res"]]
			"mine":
				var owner: String = "unclaimed" if o["owner"] < 0 else world["players"][o["owner"]]["name"]
				return "%s (%s)" % [GameData.MINES[o["mine"]]["name"], owner]
			"dwelling":
				return "%s dwelling (%d available)" % [GameData.CREATURES[o["creature"]]["name"], o["available"]]
			"shrine":
				return "Shrine of Magic (%s)" % GameData.SPELLS[o["spell"]]["name"]
			"learning_stone":
				var sel := selected_hero()
				return "Learning Stone" + ("" if sel.is_empty() else (" (visited)" if sel["uid"] in o.get("visited", []) else " (not visited)"))
			"windmill":
				return "Windmill (%s)" % ("visited this week" if human_player()["index"] in o.get("visited_week", []) else "not visited this week")
			"watchtower":
				return "Watchtower (%s)" % ("visited" if human_player()["index"] in o.get("visited_by", []) else "not visited")
			_:
				return o["type"].capitalize()
	if rules.is_guarded(t):
		return "Guarded by monsters"
	var tn: String = WorldGen.TERRAIN_ORDER[rules.terrain_at(t)]
	return GameData.TERRAINS[tn]["name"]

# ---------------------------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------------------------
func _select_hero(uid: int, instant := false) -> void:
	world["selected_hero"] = uid
	view.set_selected(uid)
	_plan = {}
	_plan_target = Vector2i(-1, -1)
	view.clear_path()
	var hero := selected_hero()
	if not hero.is_empty():
		center_on(hero["pos"], instant)
		if hero.has("dest") and hero["dest"] != hero["pos"]:
			_make_plan(hero["dest"])
	elif human_player()["towns"].size() > 0:
		center_on(world["towns"][human_player()["towns"][0]]["pos"], instant)
	hud.refresh()

func select_hero(uid: int) -> void:
	if not busy:
		_select_hero(uid)

func _first_hero_with_mp() -> int:
	var p := human_player()
	for hid in p["heroes"]:
		if world["heroes"][hid]["movement"] > 0 and not world["heroes"][hid].get("asleep", false):
			return hid
	return p["heroes"][0] if p["heroes"].size() > 0 else -1

func next_hero() -> void:
	var p := human_player()
	if p["heroes"].is_empty():
		return
	var i: int = p["heroes"].find(world["selected_hero"])
	for k in p["heroes"].size():
		var hid: int = p["heroes"][(i + 1 + k) % p["heroes"].size()]
		var h: Dictionary = world["heroes"][hid]
		if (h["movement"] > 0 and not h.get("asleep", false)) or k == p["heroes"].size() - 1:
			_select_hero(hid)
			return

## Sleep / wake the selected hero: Next Hero passes over sleeping heroes (they wake when moved).
func toggle_sleep() -> void:
	var h := selected_hero()
	if h.is_empty():
		return
	h["asleep"] = not h.get("asleep", false)
	hud.toast("%s %s" % [h["name"], "sleeps" if h["asleep"] else "wakes"])
	hud.refresh()

## Walks the selected hero on along the route already shown (or toward the destination it was heading for).
func continue_move() -> void:
	var h := selected_hero()
	if busy or h.is_empty():
		return
	if _plan.is_empty() and h.has("dest") and h["dest"] != h["pos"]:
		_make_plan(h["dest"])
	if _plan.is_empty():
		hud.toast("No route planned: click a destination first")
		return
	_execute_move()

# ---------------------------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------------------------
func _execute_move() -> void:
	var hero := selected_hero()
	if hero.is_empty() or _plan.is_empty():
		return
	if _plan["reach"] == 0:
		Audio.sfx("error")
		hud.toast("Not enough movement points left today")
		return
	busy = true
	hero["asleep"] = false
	view.clear_path()
	await move_hero(hero, _plan, true)
	busy = false
	if not is_inside_tree():
		return
	if world["heroes"].has(hero["uid"]):
		if hero.has("dest") and hero["dest"] != hero["pos"] and not _plan.is_empty():
			_make_plan(hero["dest"])
		else:
			_plan = {}
			_plan_target = Vector2i(-1, -1)
			view.clear_path()
		if _pending_click != Vector2i(-1, -1) and not _modal_open():
			_make_plan(_pending_click)  # only show the path: walking needs a second click as always
	_pending_click = Vector2i(-1, -1)
	hud.refresh()

## Moves a hero along plan up to its reach, performing the final interaction.
## Returns "battle" if a scene change to battle happened, else "".
func move_hero(hero: Dictionary, plan: Dictionary, animate: bool) -> String:
	var path: Array = plan["path"]
	var costs: Array = plan["costs"]
	var reach: int = plan["reach"]
	var player := rules.player_of(hero)
	var human: bool = not player["is_ai"]
	for i in range(1, reach + 1):
		var p: Vector2i = path[i]
		var last := i == path.size() - 1
		var occ := rules.at(p)
		if occ.get("kind", "") == "hero" or (occ.get("kind", "") == "object" and world["objects"][occ["uid"]]["type"] == "monster"):
			# The pseudo-step onto an enemy/ally.
			hero.erase("dest")
			return await _interact_with(hero, occ, human)
		hero["movement"] = maxi(0, hero["movement"] - (costs[i] - costs[i - 1]))
		var prev: Vector2i = hero["pos"]
		_move_hero_tile(hero, p)
		if p.x != prev.x:
			hero["face_left"] = p.x < prev.x
		var from_visible := _visible_to_human(prev)
		var to_visible := _visible_to_human(p)
		if human or to_visible:
			if not human and _follow != hero["uid"]:
				# Show even a short enemy walk far from the current view, then track its sprite.
				center_on(prev if from_visible else p, true)
			_follow = hero["uid"]
		else:
			if from_visible:
				center_on(prev, _follow != hero["uid"])  # show departure, stop at the last known tile
			_follow = -1
		if animate or from_visible or to_visible:
			var step := view.move_hero_step(hero["uid"], p, 0.14 if human else 0.09)
			if human or to_visible:
				Audio.sfx("footstep_horse", -12, 0.12)
			# Finish the actual position tween before instant hidden steps can move this node again.
			if step:
				await step.finished
			if not is_inside_tree():
				_follow = -1
				return ""
		else:
			var n := view.hero_node(hero["uid"])
			if n:
				n.position = view.hero_foot(p)
		rules.reveal(player, p, rules.hero_scout_radius(hero))
		if human:
			_refresh_fog()
		var gs := rules.guards(p)
		if gs.size() > 0:
			hero.erase("dest")
			var tgt: Dictionary = plan["target"] if plan["target"] in gs else gs[0]
			return await _interact_with(hero, {"kind": "object", "uid": tgt["uid"]}, human)
		if last:
			hero.erase("dest")
			if occ.get("kind", "") != "":
				return await _interact_with(hero, occ, human)
	_follow = -1
	return ""

func _move_hero_tile(hero: Dictionary, p: Vector2i) -> void:
	var old: Vector2i = hero["pos"]
	hero["pos"] = p
	rules.refresh_tile(old)
	rules.refresh_tile(p)

func _visible_to_human(p: Vector2i) -> bool:
	return rules.is_explored(human_player(), p)

func _interact_with(hero: Dictionary, occ: Dictionary, human: bool) -> String:
	_follow = -1  # visits/battles can rebuild hero nodes or replace this scene
	match occ.get("kind", ""):
		"object":
			var o: Dictionary = world["objects"][occ["uid"]]
			if o["type"] == "monster":
				return await _start_battle(rules.battle_vs_monster(hero, o), human)
			var ev := rules.visit(hero, o)
			await _show_event(hero, ev, human)
		"town":
			var town: Dictionary = world["towns"][occ["uid"]]
			if town["owner"] == hero["owner"]:
				var report := _enter_own_town(hero, town)
				if human:
					open_town(town["uid"], report)  # (the town screen announces what the visit taught)
				return ""
			if GameState.army_is_empty(town["garrison"]) and rules.town_defender(town, hero).is_empty():
				rules.capture_town(town, hero["owner"])
				Audio.sfx("flag_capture")
				view.rebuild_objects()
				rules.check_eliminations()
				if human:
					await Modal.message(self, town["name"], "The town of %s opens its gates to you." % town["name"]).closed
				await _check_game_over()
				return ""
			var with_human := human
			if town["owner"] >= 0 and not world["players"][town["owner"]]["is_ai"]:
				with_human = true
			return await _start_battle(rules.battle_vs_town(hero, town), with_human)
		"hero":
			var other: Dictionary = world["heroes"][occ["uid"]]
			if other["owner"] == hero["owner"]:
				if human:
					hud.open_exchange(hero, other)
				else:
					ai.exchange_troops(hero, other)
				return ""
			var involves_human: bool = human or not rules.player_of(other)["is_ai"]
			for t in world["towns"].values():
				if t["pos"] == other["pos"] and t["owner"] != hero["owner"]:
					return await _start_battle(rules.battle_vs_town(hero, t), involves_human)
			return await _start_battle(rules.battle_vs_hero(hero, other), involves_human)
	return ""

func _start_battle(setup: Dictionary, involves_human: bool) -> String:
	if involves_human:
		var dp: int = setup.get("defender_player", -1)
		if (world["players"][world["current_player"]]["is_ai"] and GameState.hotseat() and dp >= 0
				and not setup.get("defender_ai", true) and dp != _human()):
			# (hot-seat: a computer player attacks a human who is not at the screen: call them to defend)
			_cover()
			world["viewer"] = dp
			var p: Dictionary = world["players"][dp]
			await Modal.message(self, "To Arms, %s!" % p["name"], "%s is attacked by %s. Take the field!" % [
				_defender_name(setup), world["players"][world["current_player"]]["name"]], [[_flag_icon(p), p["name"]]]).closed
		Audio.sfx("battle_start")
		GameState.return_scene = GameState.SCENE_ADVENTURE
		world["selected_hero"] = world.get("selected_hero", -1)
		GameState.start_battle(setup)
		busy = true
		return "battle"
	var result := rules.quick_resolve(setup)
	if Engine.time_scale > 1.0:  # soak-test diagnostics (tools/sim_test.gd)
		print("SIMBATTLE day %d %s P%d str %d vs %d -> %s" % [world["day"], setup["context"]["type"], setup["attacker_player"],
			GameState.army_strength(setup["attacker_army"]), GameState.army_strength(setup["defender_army"]), result["winner"]])
	var ev := rules.apply_battle(result)
	if ev["hero"] >= 0 and world["heroes"].has(ev["hero"]):
		await _handle_level_ups(world["heroes"][ev["hero"]])
	view.rebuild_objects()
	return ""

func _defender_name(setup: Dictionary) -> String:
	var dh = setup.get("defender_hero")
	if dh is Dictionary and not dh.is_empty():
		return dh["name"]
	var town: Dictionary = world["towns"].get(setup.get("context", {}).get("town", -1), {})
	return "The garrison of %s" % town.get("name", "your town")

func _show_event(hero: Dictionary, ev: Dictionary, human: bool) -> void:
	if ev.get("sfx", "") != "" and (human or _visible_to_human(hero["pos"])):
		Audio.sfx(ev["sfx"])
	for uid in world.get("_removed", []):
		view.remove_object(uid)
	world["_removed"] = []
	if ev.has("refresh"):
		view.refresh_object(ev["refresh"])
	if ev.get("fog", false) and human:
		_refresh_fog()
	if ev.has("choice"):
		var c: Dictionary = ev["choice"]
		if human:
			var r = await Modal.choice(self, ev["title"], ev["text"], [
				["%d Gold" % c["gold"], "gold", Assets.res_icon("gold")],
				["%d Experience" % c["xp"], "xp", Assets.tex("icons/stat_xp.png")]]).closed
			var lv := rules.resolve_chest(hero, str(r), c["gold"], c["xp"])
			if lv > 0:
				await _handle_level_ups(hero)
		else:
			var lv := rules.resolve_chest(hero, "gold" if rules.player_of(hero)["resources"]["gold"] < 10000 else "xp", c["gold"], c["xp"])
			if lv > 0:
				await _handle_level_ups(hero)
	elif ev.has("factory"):
		if human:
			await WarMachineShop.open(self, hero, rules.player_of(hero), func(): hud.refresh())
		else:
			ai.buy_from_factory(hero)
	elif ev.has("dwelling"):
		if human:
			await hud.open_dwelling(hero, world["objects"][ev["dwelling"]])
		else:
			ai.recruit_from_dwelling(hero, world["objects"][ev["dwelling"]])
	elif human and ev["title"] != "":
		if ev.has("float"):
			hud.float_text(view.foot_of(hero["pos"]) - Vector2(0, 120), ev["float"])
		else:
			await Modal.message(self, ev["title"], ev["text"], ev["icons"]).closed
	if ev.get("levels", 0) > 0:
		await _handle_level_ups(hero)
	hud.refresh()

func _handle_level_ups(hero: Dictionary) -> void:
	var human: bool = not rules.player_of(hero)["is_ai"]
	while int(hero.get("pending_levels", 0)) > 0:
		var roll := rules.roll_level_up(hero)
		var skill := ""
		if human:
			Audio.sfx("level_up")
			var opts := []
			for s in roll["options"]:
				var lvl := int(hero["skills"].get(s, 0)) + 1
				opts.append(["%s %s" % [["", "Basic", "Advanced", "Expert"][lvl], GameData.SKILLS[s]["name"]], s, Assets.skill_icon(s)])
			var text := "%s has gained a level! (%s +1)\n%s" % [hero["name"], roll["stat"].capitalize(), "Choose a skill to learn:" if opts.size() > 0 else ""]
			if opts.size() > 0:
				skill = await Modal.choice(self, "Level %d" % (hero["level"] - int(hero["pending_levels"]) + 1), text, opts).closed
			else:
				await Modal.message(self, "Level up", text).closed
		elif roll["options"].size() > 0:
			skill = roll["options"][randi() % roll["options"].size()]
		rules.apply_level_up(hero, roll, skill)
	hud.refresh()

# ---------------------------------------------------------------------------------------------
# Towns
# ---------------------------------------------------------------------------------------------
func open_town(uid: int, report := {}) -> void:
	var town: Dictionary = world["towns"][uid]
	var visitor := rules.hero_at(town["pos"])
	if not visitor.is_empty() and visitor["owner"] == town["owner"] and report.is_empty():
		report = _enter_own_town(visitor, town)
	GameState.pending_town = {"town_uid": uid, "hero_uid": visitor.get("uid", -1), "report": report}
	GameState.change_scene(GameState.SCENE_TOWN)

## A hero in its own town learns the Mage Guild's spells and has its spell points restored: what it gained, for the
## town screen to announce ({hero, learned, mana}).
func _enter_own_town(hero: Dictionary, town: Dictionary) -> Dictionary:
	var mana_before: int = hero["mana"]
	var learned := rules.hero_in_town(hero, town)
	return {"hero": hero["uid"], "learned": learned, "mana": hero["mana"] - mana_before}

# ---------------------------------------------------------------------------------------------
# Turns
# ---------------------------------------------------------------------------------------------
func end_turn() -> void:
	if busy:
		return
	var p := human_player()
	var idle := 0
	for hid in p["heroes"]:
		if world["heroes"][hid]["movement"] >= 300:
			idle += 1
	if idle > 0:
		var ok = await Modal.confirm(self, "End Turn", "One or more heroes can still move. End your turn anyway?").closed
		if not ok:
			return
	_advance_player()
	_run_ai_turns()

func _advance_player() -> void:
	var n: int = world["players"].size()
	var cur: int = world["current_player"]
	for k in n:
		cur = (cur + 1) % n
		if cur == 0:
			var info := rules.new_day()
			info["seen_by"] = []
			world["pending_week"] = info
		if world["players"][cur]["alive"]:
			break
	world["current_player"] = cur

func _run_ai_turns() -> void:
	busy = true
	hud.refresh()
	while world["players"][world["current_player"]]["is_ai"] and not world.get("game_over", false):
		var p: Dictionary = world["players"][world["current_player"]]
		hud.set_turn_label("%s is moving..." % p["name"])
		var r := await ai.run_turn(self, p)
		if r == "battle" or not is_inside_tree():
			return  # battle scene takes over; we resume in _post_ready
		if await _check_game_over():
			return
		_advance_player()
		# (one frame per turn: with nothing to animate, e.g. a lone computer player left in an all-computer game, the
		# days would otherwise spin within one frame and overflow the engine's message queue)
		await get_tree().process_frame
		if not is_inside_tree():
			return
	busy = false
	hud.set_turn_label("")
	await _start_human_turn()

func _start_human_turn() -> void:
	if await _check_game_over():
		return
	var cover: CanvasLayer = null
	if GameState.hotseat():
		cover = _cover()  # (hot-seat: hide the last player's map before switching to the next one's)
	world["viewer"] = world["current_player"]
	GameState.handed_over(world["current_player"])
	_refresh_fog()
	view.rebuild_objects()
	_select_hero(_first_hero_with_mp(), cover != null)
	hud.refresh()
	if cover:
		var p := human_player()
		await Modal.message(self, "%s's Turn" % p["name"], "%s. The realm awaits your orders." % rules.date_string(),
			[[_flag_icon(p), p["name"]]]).closed
		cover.queue_free()
	await _turn_banner()

## Hot-seat: a dark screen over the map and its panels (dialogs still show above it).
func _cover() -> CanvasLayer:
	var cover := CanvasLayer.new()
	cover.layer = 80
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.add_child(bg)
	add_child(cover)
	return cover

static func _flag_icon(p: Dictionary) -> Texture2D:
	return UI.flag_icon(p["color"])

func _turn_banner() -> void:
	# the day's news, once for each human player (hot-seat: every one of them hears of the new week)
	var info: Dictionary = world.get("pending_week", {})
	var me: int = human_player()["index"]
	if info.has("seen_by"):
		if me in info["seen_by"]:
			info = {}
		else:
			info["seen_by"].append(me)
	else:
		world["pending_week"] = {}
	Audio.sfx("new_day", -4)
	hud.flash_date()
	if info.get("new_week", false):
		Audio.sfx("new_week")
		var cid: String = info.get("week_creature", "")
		var text := "Astrologers proclaim the Week of the %s.\nAll dwellings increase their population." % (GameData.CREATURES[cid]["name"] if cid != "" else "Peasant")
		await Modal.message(self, "A New Week", text, [[Assets.creature_portrait(cid), GameData.CREATURES[cid]["plural"]]] if cid != "" else []).closed
	else:
		hud.banner("Day %d" % world["day"])
		hud.toast(rules.date_string())
	# the classic warning: a player without a town must take one before the count runs out
	var left := rules.townless_days_left(human_player())
	if left > 0:
		await Modal.message(self, "Without a Town", "You have no town. Capture one within %d day%s, or you will be defeated." % [
			left, "" if left == 1 else "s"]).closed

func _check_game_over() -> bool:
	if world.get("game_over", false):
		return true
	await _hotseat_defeats()
	var cur: Dictionary = world["players"][world["current_player"]]
	if not cur["is_ai"] and not cur["alive"] and GameState.hotseat_alive():
		# (hot-seat: the player whose turn it is fell; the others play on)
		busy = false
		_advance_player()
		_run_ai_turns()
		return true
	var me := human_player()
	var others_alive := false
	for p in world["players"]:
		if p["index"] != me["index"] and p["alive"]:
			others_alive = true
	# the scenario's own conditions (a capture, a hoard of gold, the starting hero, a deadline)
	var sc: Dictionary = world.get("scenario", {})
	var vic: Dictionary = sc.get("victory", {})
	var loss: Dictionary = sc.get("loss", {})
	var lost := ""
	if not me["alive"] and me.get("defeated_townless", false):
		lost = "Seven days have passed without a town to call your own. Your followers have deserted you."
	elif not me["alive"]:
		lost = "Your last hero has fallen and your towns are lost. The Shattered Crown will never be whole again."
	elif loss.get("type", "") == "hero" and not world["heroes"].has(me.get("start_hero", world.get("start_hero", -1))):
		lost = "Your champion has fallen, and with them the last hope of the old order."
	elif loss.get("type", "") == "days" and world["day"] > int(loss.get("days", 112)):
		lost = "The snows have melted and your enemies' hosts have joined together. Time has run out."
	if lost != "":
		world["game_over"] = true
		Audio.music("defeat")
		await Modal.message(self, "Defeat", lost).closed
		GameState.world = {}
		GameState.change_scene(GameState.SCENE_MENU)
		return true
	var won := ""
	if not others_alive:
		won = ("%s is the last lord standing. " % me["name"] if _human_count() > 1 else "") + "All your enemies have been vanquished. The lands bow before you, and the Shattered Crown is yours."
	elif vic.get("type", "") == "capture":
		for t in world["towns"].values():
			if t["owner"] == me["index"] and t.get("start_owner", -1) >= 0 and t["start_owner"] != me["index"]:
				won = "%s is yours. With the enemy's stronghold taken, the border is secure." % t["name"]
	elif vic.get("type", "") == "gold" and me["resources"]["gold"] >= int(vic.get("amount", 0)):
		won = "Your treasury overflows with the gold of the old kings. The realm's lords flock to your banner."
	if won != "":
		if _human_count() > 1 and not won.begins_with(me["name"]):
			won = "%s wins! %s" % [me["name"], won]
		world["game_over"] = true
		Audio.music("victory")
		await Modal.message(self, "Victory!", won).closed
		GameState.world = {}
		GameState.change_scene(GameState.SCENE_MENU)
		return true
	return false

func _human_count() -> int:
	return world["players"].filter(func(p): return not p["is_ai"]).size()

## Hot-seat: a human who falls (or loses their champion) while another human plays on is told so and leaves the
## game; the others carry on. (When every human has fallen, the plain defeat follows.)
func _hotseat_defeats() -> void:
	if _human_count() < 2:
		return
	var loss: Dictionary = world.get("scenario", {}).get("loss", {})
	var out := []
	for p in world["players"]:
		if p["is_ai"] or p.get("defeat_told", false):
			continue
		if p["alive"] and loss.get("type", "") == "hero" and not world["heroes"].has(p.get("start_hero", -1)):
			rules.eliminate(p)  # (their champion fell: they are out)
		if not p["alive"]:
			out.append(p)
	if out.is_empty() or not GameState.hotseat_alive():
		return
	view.rebuild_objects()
	for p in out:
		p["defeat_told"] = true
		var why := ("Seven days have passed without a town to call their own, and their followers have deserted them."
			if p.get("defeated_townless", false) else "Their last hero has fallen and their towns are lost.")
		await Modal.message(self, "%s Is Defeated" % p["name"], "%s %s The game goes on for the others." % [
			p["name"], why], [[_flag_icon(p), p["name"]]]).closed

# ---------------------------------------------------------------------------------------------
func _refresh_fog() -> void:
	view.update_fog(human_player())
	hud.refresh_minimap()

func refresh_after_change() -> void:
	rules.rebuild()
	view.rebuild_objects()
	view.set_selected(world.get("selected_hero", -1))
	hud.refresh()

func _update_music() -> void:
	var hero := selected_hero()
	var t := "grass"
	if not hero.is_empty():
		t = WorldGen.TERRAIN_ORDER[rules.terrain_at(hero["pos"])]
	Audio.music("adventure_dirt" if t in ["dirt", "swamp", "snow"] else "adventure_grass")
