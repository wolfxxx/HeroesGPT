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
var _mouse := Vector2(-1, -1)  # the cursor from mouse events (simulated input too, unlike the OS cursor); off the window: -1
var _rclick_info := false      # the right button is held: its information panel stays up until release
var _pending_click := Vector2i(-1, -1)  # clicked while the hero was still moving: planned when it stops
var _net_dirty := false  # online: another machine's command changed the world; redrawn once in the next frame
const DRAG_START := 10.0
var _mouse_in := true  # the cursor is over the window (in a browser: the page)
var _left_at := Vector2.INF  # in a browser, the cursor gone off the page: just past the edge it left by
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
		if Shot.setup == "duel":  # (online check: the second player's hero two steps from the first player's)
			var w := GameState.world
			var h0: Dictionary = w["heroes"][w["players"][0]["heroes"][0]]
			var h1: Dictionary = w["heroes"][w["players"][1]["heroes"][0]]
			var r := AdvRules.new(w)
			for d in [Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(3, 1), Vector2i(1, 3)]:
				var q: Vector2i = h0["pos"] + d
				if r.inside(q) and r.walkable_ground(q) and r.at(q).is_empty():
					h1["pos"] = q
					print("DUEL red %s blue %s" % [h0["pos"], q])
					break
		if Shot.setup == "artifacts":  # (judge shot: one artifact of each tier laid out beside the first hero)
			_shot_artifacts(GameState.world)
		if Shot.setup == "town_levels":  # (shot: the first town a Castle, the second a village without a Fort)
			var towns: Array = GameState.world["towns"].values()
			towns[0]["buildings"].append_array(["citadel", "castle"])
			towns[1]["buildings"].erase("fort")
			for t in towns.slice(0, 3): print("TOWN %s at %s level %d" % [t["name"], t["pos"], TownLogic.siege_level(t)])
		if Shot.setup == "titans":  # (shot: where the Hill Fort, Cloud Temple, Dragon Cave and wild stacks are)
			var w := GameState.world
			for o in w["objects"].values():
				if o["type"] == "hill_fort" or o.get("creature", "") in ["giant", "red_dragon", "titan", "black_dragon"]:
					print("SITE %s %s at %s" % [o["type"], o.get("creature", ""), o["pos"]])
			if Shot.args.has("hill_fort"):  # (the first hero at the fort, with troops to upgrade and the means)
				var p0: Dictionary = w["players"][0]
				var h: Dictionary = w["heroes"][p0["heroes"][0]]
				for o in w["objects"].values():
					if o["type"] == "hill_fort":
						h["pos"] = o["pos"]
				h["army"] = [{"id": "giant", "count": 3}, {"id": "red_dragon", "count": 2}, {"id": "pikeman", "count": 25},
					{"id": "archer", "count": 12}, null, null, null]
				p0["resources"]["gold"] = 30000
				p0["resources"]["gems"] = 10
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
	if Net.active:
		_net_attach()

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

	var sel: int = _v()["selected_hero"]
	if not selected_town().is_empty() and sel == -1:
		_select_town(_v()["selected_town"], true)  # (back from a town picked in the town list)
	else:
		if not world["heroes"].has(sel) or world["heroes"][sel]["owner"] != _human():
			sel = _first_hero_with_mp()
		_select_hero(sel, true)
	_update_music()
	if Net.active:
		Net.world_ready()  # (once the screen is whole: players waiting in the lobby are seated now)
	_post_ready.call_deferred()

func _post_ready() -> void:
	await get_tree().process_frame
	if not Net.active and not Net.resume.is_empty():  # (online: the connection went on another screen)
		if not await Reconnect.run(self, "The connection to the game was lost."):
			GameState.change_scene(GameState.SCENE_MENU)
			return
		if not Net.is_host:  # (the host's world has come: the screen starts again on it)
			GameState.change_scene(GameState.SCENE_ADVENTURE, 0.2)
			return
		_net_attach()
		Net.world_ready()
	if Shot.active:
		_shot_view()
		if Shot.setup == "titans" and Shot.args.has("hill_fort"):
			var hf := selected_hero()
			for o in world["objects"].values():
				if o["type"] == "hill_fort" and o["pos"] == hf.get("pos", Vector2i(-1, -1)):
					HillFort.open(self, hf, rules.player_of(hf), func(): hud.refresh(), rules, o["uid"])
	if not GameState.battle_result.is_empty():
		var result := GameState.battle_result
		GameState.battle_result = {}
		var by: int = world.get("current_player", 0)
		var ev: Dictionary = rules.do({"t": "battle_result", "p": by, "result": result}).get("event", {"hero": -1})
		view.rebuild_objects()
		_refresh_fog()
		hud.refresh()
		if ev["hero"] >= 0 and world["heroes"].has(ev["hero"]):
			await _handle_level_ups(world["heroes"][ev["hero"]])
		var mover: Dictionary = world["heroes"].get(result.get("context", {}).get("hero", -1), {})
		if mover.has("visit_after_guard"):
			await _visit_after_guard(mover, not rules.player_of(mover)["is_ai"])
		if not world["heroes"].has(_v()["selected_hero"]) and selected_town().is_empty():
			_select_hero(_first_hero_with_mp())
		if await _check_game_over():
			return
	if not _v()["intro_shown"] and world.has("scenario") and not Shot.active:
		# the scenario's briefing, once, as the game begins
		_v()["intro_shown"] = true
		var sc: Dictionary = world["scenario"]
		await Modal.message(self, sc["name"], "%s\n\nVictory: %s.\nDefeat: %s." % [sc["desc"],
			GameData.victory_text(sc["victory"]), GameData.loss_text(sc["loss"], rules.townless_limit())]).closed
	if not Net.mine(world["current_player"]):
		_await_others()  # (online: another machine's player, or the computer players on the host)
	elif world["players"][world["current_player"]]["is_ai"]:
		_run_ai_turns()
	elif (GameState.hotseat() or Net.active) and not GameState.was_handed(world["current_player"]):
		await _start_human_turn()  # (hot-seat: the first turn, or a loaded game: name whose turn it is first)

func _human() -> int:
	return GameState.human_player_index()

func human_player() -> Dictionary:
	return world["players"][_human()]

## The screen's player's own view (GameState.view): what they have selected, their news.
func _v() -> Dictionary:
	return GameState.view(_human())

func selected_hero() -> Dictionary:
	return world["heroes"].get(_v()["selected_hero"], {})

## The town picked in the town list while no hero is selected (as the classic: one or the other), else {}.
func selected_town() -> Dictionary:
	if _v()["selected_hero"] != -1:
		return {}
	var t: Dictionary = world["towns"].get(_v()["selected_town"], {})
	return t if not t.is_empty() and t["owner"] == _human() else {}

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
	if _net_dirty:
		_net_redraw()
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
		# On entering sight, hold at the first visible tile until the sprite emerges from fog (another player's hero,
		# the computer's or, online, another person's: the camera must not show where it walks unseen).
		if not hero.is_empty() and (rules.player_of(hero)["index"] == _human() or _visible_to_human(Vector2i((focus / TILE).floor()))):
			center_on_world(focus)
		cam.position = cam.position.lerp(_cam_target, minf(1.0, delta * 6.0))
	else:
		cam.position = cam.position.lerp(_cam_target, minf(1.0, delta * 10.0))
	var mpos := _mouse
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
## In a browser only the cursor over the page is known: there it scrolls at the page's edges, and once it has left, on
## the way it left (until it comes back), as past the window's edge on the desktop.
func _edge_scroll() -> Vector2:
	var m := Vector2(DisplayServer.mouse_get_position() - DisplayServer.window_get_position())
	var ws := Vector2(DisplayServer.window_get_size())
	var edge := EDGE
	if OS.has_feature("web"):
		if _mouse_in and _mouse.x >= 0:
			m = _mouse
		elif not _mouse_in and _left_at.is_finite():
			m = _left_at
		else:
			return Vector2.ZERO
		edge = EDGE * get_viewport().get_visible_rect().size.x / maxf(1.0, ws.x)
		ws = get_viewport().get_visible_rect().size
	var v := Vector2.ZERO
	if m.x < edge: v.x -= 1
	if m.x > ws.x - edge: v.x += 1
	if m.y < edge: v.y -= 1
	if m.y > ws.y - edge: v.y += 1
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
## Where the cursor is, for the hover panel to close when it leaves the map (over the side panel, the bottom bar or
## out of the window). Read from the events, not the OS cursor: the remote-play harness moves only the events.
func _input(e: InputEvent) -> void:
	if e is InputEventMouse:
		_mouse = e.position

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_left_at = _past_edge(_mouse)
		_mouse = Vector2(-1, -1)
		_mouse_in = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_in = true
		_left_at = Vector2.INF

## Where the cursor went on leaving the page from `m` (its last place on it): just past the nearest edge, or past
## both at a corner.
func _past_edge(m: Vector2) -> Vector2:
	var size := get_viewport().get_visible_rect().size
	if m.x < 0 or m.y < 0:
		return Vector2.INF
	var near := 0.06 * size.y  # (how close to a second edge counts as a corner)
	var gaps := [m.x, size.x - m.x, m.y, size.y - m.y]
	var least: float = gaps.min()
	var out := m
	if m.x == least or m.x < near: out.x = -1.0
	elif size.x - m.x == least or size.x - m.x < near: out.x = size.x + 1.0
	if m.y == least or m.y < near: out.y = -1.0
	elif size.y - m.y == least or size.y - m.y < near: out.y = size.y + 1.0
	return out

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
					hud.save_game()

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
		if hh["uid"] == _v()["selected_hero"]:
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
	if hero.is_empty() or hero.get("in_town", false):
		if not town.is_empty() and town["owner"] == me:
			open_town(town["uid"])
		elif not hero.is_empty():  # (a garrison hero waits inside: out through the town screen first)
			hud.toast("%s is in a town's garrison: send them to the gate in the town screen" % hero["name"])
		return
	if t == _plan_target and not _plan.is_empty():
		_execute_move()
		return
	_make_plan(t)

func _make_plan(t: Vector2i) -> void:
	var hero := selected_hero()
	if hero.is_empty() or hero.get("in_town", false):
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

## Hover panel for a map tile: what the hero, town or object there is and what visiting it does (null: nothing), with
## a relic's or site's declassified line at the bottom (blacked out until the player has held it or been there).
func _tile_info(t: Vector2i, detailed := false):
	var info = _tile_info_base(t, detailed)
	if info is VBoxContainer and rules.town_covering(t).is_empty():
		var o := rules.object_covering(t)
		var key := Lore.key_for(o) if not o.is_empty() else ""
		if key != "":
			HoverInfo.line(info, Lore.shown(world, human_player()["index"], key), Color(0.66, 0.62, 0.55), 17)
	return info

func _tile_info_base(t: Vector2i, detailed := false):
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
			var gh := rules.garrison_hero(town)
			if not gh.is_empty():
				HoverInfo.line(v, "Garrison led by %s:" % gh["name"], UI.GOLD, 18)
				_army_row(v, gh["army"], true)
			elif GameState.army_is_empty(town["garrison"]):
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
		"hill_fort":
			var v := HoverInfo.box("Hill Fort")
			HoverInfo.line(v, "Upgrades the visiting hero's troops, at the usual upgrade price.")
			var ups := HillFort.upgradable(hero) if not hero.is_empty() else []
			for e in ups:
				HoverInfo.line(v, "%s to %s" % [GameData.CREATURES[e[1]]["plural"], GameData.CREATURES[e[2]]["plural"]], UI.GOLD, 18)
			if not hero.is_empty() and ups.is_empty():
				HoverInfo.line(v, "Nothing in %s's army to upgrade." % hero["name"], Color(0.8, 0.75, 0.65), 18)
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
			var v := HoverInfo.creature(o["creature"], -1, c.get("dwelling", "%s dwelling" % c["name"]))
			HoverInfo.line(v, "%d available to recruit." % o["available"], UI.GOLD, 18)
			var own: int = o.get("owner", -1)
			_visit_line(v, own == me, "Yours: new recruits every week." if own == me else
				("Not visited." if own < 0 else "Owned by %s." % world["players"][own]["name"]))
			return v
		"shrine":
			var sp: Dictionary = GameData.SPELLS[o["spell"]]
			var v := HoverInfo.box("Stone Circle")
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
			var v := HoverInfo.box("Obelisk of Thoth")
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
		"pyramid":
			var v := HoverInfo.box("Pyramid")
			var gs: Array = o.get("guards", [])
			if not gs.is_empty():
				var by := {}
				for g in gs:
					by[g["id"]] = by.get(g["id"], 0) + int(g["count"])
				var parts := PackedStringArray()
				for id in by:
					parts.append("%d %s" % [by[id], GameData.CREATURES[id]["plural"]])
				HoverInfo.line(v, "Guarded by " + " and ".join(parts) + ".", Color(1, 0.6, 0.5), 18)
				HoverInfo.line(v, "Inside: a spell of the highest level, for a hero wise enough to learn it.")
			elif o.get("spell", "") != "":
				HoverInfo.line(v, "Its guardians are fallen. The spell waits inside.")
			else:
				HoverInfo.line(v, "Empty. Searching it disturbs the dead: -2 luck until the next battle.", Color(0.8, 0.75, 0.65), 18)
			return v
		"watchtower":
			var v := HoverInfo.box("Observatory")
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
				var dc: Dictionary = GameData.CREATURES[o["creature"]]
				return "%s (%d available)" % [dc.get("dwelling", "%s dwelling" % dc["name"]), o["available"]]
			"shrine":
				return "Stone Circle (%s)" % GameData.SPELLS[o["spell"]]["name"]
			"learning_stone":
				var sel := selected_hero()
				return "Obelisk of Thoth" + ("" if sel.is_empty() else (" (visited)" if sel["uid"] in o.get("visited", []) else " (not visited)"))
			"windmill":
				return "Windmill (%s)" % ("visited this week" if human_player()["index"] in o.get("visited_week", []) else "not visited this week")
			"pyramid":
				return "Pyramid (%s)" % ("guarded" if not o.get("guards", []).is_empty() else ("empty" if o.get("spell", "") == "" else "unguarded"))
			"watchtower":
				return "Observatory (%s)" % ("visited" if human_player()["index"] in o.get("visited_by", []) else "not visited")
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
	_v()["selected_hero"] = uid
	_v()["selected_town"] = -1
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
		_v()["selected_town"] = human_player()["towns"][0]  # (no hero: the first town is selected)
		center_on(world["towns"][_v()["selected_town"]]["pos"], instant)
	hud.refresh()

func select_hero(uid: int) -> void:
	if not busy:
		_select_hero(uid)

## As the classic town list: selecting a town drops the hero selection and centres the map on the town.
func _select_town(uid: int, instant := false) -> void:
	_v()["selected_hero"] = -1
	_v()["selected_town"] = uid
	view.set_selected(-1)
	_plan = {}
	_plan_target = Vector2i(-1, -1)
	view.clear_path()
	center_on(world["towns"][uid]["pos"], instant)
	hud.refresh()

func select_town(uid: int) -> void:
	if not busy:
		_select_town(uid)

func _first_hero_with_mp() -> int:
	var p := human_player()
	for hid in p["heroes"]:
		var hh: Dictionary = world["heroes"][hid]
		if hh["movement"] > 0 and not hh.get("asleep", false) and not hh.get("in_town", false):
			return hid
	return p["heroes"][0] if p["heroes"].size() > 0 else -1

func next_hero() -> void:
	var p := human_player()
	if p["heroes"].is_empty():
		return
	var i: int = p["heroes"].find(_v()["selected_hero"])
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
	rules.do({"t": "sleep", "p": h["owner"], "hero": h["uid"], "asleep": not h.get("asleep", false)})
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
	if hero.get("asleep", false):  # (a sleeping hero sent on his way wakes)
		rules.do({"t": "sleep", "p": hero["owner"], "hero": hero["uid"], "asleep": false})
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
		var prev: Vector2i = hero["pos"]
		# (the rules move the hero, pay the step and reveal around it; the screen shows the walk)
		if not rules.do({"t": "step", "p": hero["owner"], "hero": hero["uid"], "to": [p.x, p.y]})["ok"]:
			hero.erase("dest")
			break
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
		if human:
			_refresh_fog()
		var gs := rules.guards(p)
		if gs.size() > 0:
			hero.erase("dest")
			var tgt: Dictionary = plan["target"] if plan["target"] in gs else gs[0]
			if last and occ.get("kind", "") == "object":
				hero["visit_after_guard"] = occ["uid"]  # (the treasure the guard stood over: taken once it is beaten)
			var r := await _interact_with(hero, {"kind": "object", "uid": tgt["uid"]}, human)
			if r == "":
				await _visit_after_guard(hero, human)
			return r
		if last:
			hero.erase("dest")
			if occ.get("kind", "") != "":
				return await _interact_with(hero, occ, human)
	_follow = -1
	return ""

## A hero who stepped onto a guarded object and won the fight gets the object, as in the classic (a guarded artifact,
## chest or resource is fought for, then taken). Lost, fled or moved on: nothing.
func _visit_after_guard(hero: Dictionary, human: bool) -> void:
	var uid = hero.get("visit_after_guard", -1)
	hero.erase("visit_after_guard")
	if uid < 0 or not world["heroes"].has(hero["uid"]) or not world["objects"].has(uid):
		return
	var o: Dictionary = world["objects"][uid]
	if o["pos"] != hero["pos"] or o["type"] == "monster" or rules.guards(hero["pos"]).size() > 0:
		return
	await _interact_with(hero, {"kind": "object", "uid": uid}, human)
	view.rebuild_objects()

func _visible_to_human(p: Vector2i) -> bool:
	return rules.is_explored(human_player(), p)

func _interact_with(hero: Dictionary, occ: Dictionary, human: bool) -> String:
	_follow = -1  # visits/battles can rebuild hero nodes or replace this scene
	match occ.get("kind", ""):
		"object":
			var o: Dictionary = world["objects"][occ["uid"]]
			if o["type"] == "monster":
				return await _start_battle(rules.battle_vs_monster(hero, o), human)
			if o["type"] == "pyramid" and not o.get("guards", []).is_empty():  # (its guards first, then inside)
				hero["visit_after_guard"] = o["uid"]
				var r := await _start_battle(rules.battle_vs_site(hero, o), human)
				if r == "":
					await _visit_after_guard(hero, human)
				return r
			var res := rules.do({"t": "visit", "p": hero["owner"], "hero": hero["uid"], "object": o["uid"]})
			if res["ok"]:
				await _show_event(hero, res["event"], human)
		"town":
			var town: Dictionary = world["towns"][occ["uid"]]
			if town["owner"] == hero["owner"]:
				var report := _enter_own_town(hero, town)
				await _academy(hero, report)
				if human:
					open_town(town["uid"], report)  # (the town screen announces what the visit taught)
				return ""
			if GameState.army_is_empty(town["garrison"]) and rules.town_defender(town, hero).is_empty():
				rules.do({"t": "capture", "p": hero["owner"], "hero": hero["uid"], "town": town["uid"]})
				Audio.sfx("flag_capture")
				view.rebuild_objects()
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
				# (a hero at the gate of a town that also holds a garrison hero is met outside the walls, as the classic)
				if t["pos"] == other["pos"] and t["owner"] != hero["owner"] and rules.garrison_hero(t).is_empty():
					return await _start_battle(rules.battle_vs_town(hero, t), involves_human)
			return await _start_battle(rules.battle_vs_hero(hero, other), involves_human)
	return ""

func _start_battle(setup: Dictionary, involves_human: bool) -> String:
	var fought := {}  # (online: a battle another machine fought and sent back)
	if Net.active:
		# (online: each person fights their own side on their own machine. Two people: the battle on both screens,
		# each sending its side's actions (Net.battle_begin). The computer against another machine's player: fought
		# on that machine, the host waiting for its result (Net.fight_remote). No person: resolved at once.)
		var pl: Array = world["players"]
		var ap: int = setup.get("attacker_player", -1)
		var dp: int = setup.get("defender_player", -1)
		var person_a: bool = ap >= 0 and not pl[ap]["is_ai"]
		var person_d: bool = dp >= 0 and not pl[dp]["is_ai"]
		var me_a := person_a and ap == Net.seat
		var me_d := person_d and dp == Net.seat
		setup["attacker_ai"] = not person_a
		setup["defender_ai"] = not person_d
		if not setup.has("seed"):
			setup["seed"] = rules.battle_seed()
		var other := (dp if person_d and not me_d else -1) if me_a else (ap if person_a and not me_a else -1)
		if (me_a or me_d) and other >= 0:
			var theirs := setup.duplicate()
			theirs["remote_sides"] = [me_a, me_d]
			theirs["net_result"] = "apply" if other == world["current_player"] else "none"
			setup["remote_sides"] = [not me_a, not me_d]
			setup["net_result"] = "apply" if Net.seat == world["current_player"] else "none"
			Net.battle_begin(theirs, other)
			involves_human = true
		elif not me_a and not me_d and (person_a or person_d) and Net.is_host:
			var far := dp if person_d else ap
			hud.set_turn_label("%s is fighting..." % pl[far]["name"])
			var theirs := setup.duplicate()
			theirs["net_result"] = "send"
			fought = await Net.fight_remote(theirs, far)
			involves_human = false
		else:
			involves_human = me_a or me_d
	if involves_human:
		var dp: int = setup.get("defender_player", -1)
		if (world["players"][world["current_player"]]["is_ai"] and GameState.hotseat() and dp >= 0
				and not setup.get("defender_ai", true) and dp != _human()):
			# (hot-seat: a computer player attacks a human who is not at the screen: call them to defend)
			_cover()
			GameState.viewer = dp
			var p: Dictionary = world["players"][dp]
			await Modal.message(self, "To Arms, %s!" % p["name"], "%s is attacked by %s. Take the field!" % [
				_defender_name(setup), world["players"][world["current_player"]]["name"]], [[_flag_icon(p), p["name"]]]).closed
		Audio.sfx("battle_start")
		GameState.return_scene = GameState.SCENE_ADVENTURE
		if not setup.has("seed"):
			setup["seed"] = rules.battle_seed()
		GameState.start_battle(setup)
		busy = true
		return "battle"
	var result: Dictionary = fought if not fought.is_empty() else rules.quick_resolve(setup)
	if Engine.time_scale > 1.0:  # soak-test diagnostics (tools/sim_test.gd)
		print("SIMBATTLE day %d %s P%d str %d vs %d -> %s" % [world["day"], setup["context"]["type"], setup["attacker_player"],
			GameState.army_strength(setup["attacker_army"]), GameState.army_strength(setup["defender_army"]), result["winner"]])
	var by: int = world.get("current_player", setup.get("attacker_player", 0))
	var ev: Dictionary = rules.do({"t": "battle_result", "p": by, "result": result}).get("event", {"hero": -1})
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
	for uid in rules.removed:
		view.remove_object(uid)
	rules.removed.clear()
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
			var lv: int = rules.do({"t": "chest", "p": hero["owner"], "hero": hero["uid"], "choice": str(r)}).get("levels", 0)
			if lv > 0:
				await _handle_level_ups(hero)
		else:
			var pick := "gold" if rules.player_of(hero)["resources"]["gold"] < 10000 else "xp"
			var lv: int = rules.do({"t": "chest", "p": hero["owner"], "hero": hero["uid"], "choice": pick}).get("levels", 0)
			if lv > 0:
				await _handle_level_ups(hero)
	elif ev.has("factory"):
		if human:
			await WarMachineShop.open(self, hero, rules.player_of(hero), func(): hud.refresh(), rules, ev["factory"])
		else:
			ai.buy_from_factory(hero)
	elif ev.has("hill_fort"):
		if human:
			await HillFort.open(self, hero, rules.player_of(hero), func(): hud.refresh(), rules, ev["hill_fort"])
		else:
			ai.upgrade_at_hill_fort(hero, ev["hill_fort"])
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
	if not Net.mine(hero["owner"]):
		return  # (online: the hero's own player chooses, on their machine at their next turn)
	var human: bool = not rules.player_of(hero)["is_ai"]
	while int(hero.get("pending_levels", 0)) > 0:
		var roll := rules.do({"t": "level_roll", "p": hero["owner"], "hero": hero["uid"]})
		if not roll["ok"]:
			break
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
			var pick := Dice.derived(world, ["skill pick", hero["uid"], hero["level"]])  # (the computer's choice)
			skill = roll["options"][pick.randi() % roll["options"].size()]
		rules.do({"t": "level_up", "p": hero["owner"], "hero": hero["uid"], "skill": skill})
	hud.refresh()

# ---------------------------------------------------------------------------------------------
# Towns
# ---------------------------------------------------------------------------------------------
func open_town(uid: int, report := {}) -> void:
	var town: Dictionary = world["towns"][uid]
	var visitor := rules.hero_at(town["pos"])
	if not visitor.is_empty() and visitor["owner"] == town["owner"] and report.is_empty():
		report = _enter_own_town(visitor, town)
		await _academy(visitor, report)
	GameState.pending_town = {"town_uid": uid, "hero_uid": visitor.get("uid", -1), "report": report}
	GameState.change_scene(GameState.SCENE_TOWN)

## Agartha's Battle Scholar Academy: the experience a visit gave, and its levels, on the map before the town opens.
func _academy(hero: Dictionary, report: Dictionary) -> void:
	if int(report.get("xp", 0)) <= 0:
		return
	if Net.mine(hero["owner"]) and not rules.player_of(hero)["is_ai"]:
		await Modal.message(self, "Battle Scholar Academy", "%s studies at the Battle Scholar Academy: +%d experience."
			% [hero["name"], report["xp"]], [[Assets.tex("icons/stat_xp.png"), "+%d" % report["xp"]]]).closed
	await _handle_level_ups(hero)

## A hero in its own town learns the Mage Guild's spells and has its spell points restored: what it gained, for the
## town screen to announce ({hero, learned, mana}).
func _enter_own_town(hero: Dictionary, town: Dictionary) -> Dictionary:
	var r := rules.do({"t": "town_visit", "p": hero["owner"], "hero": hero["uid"], "town": town["uid"]})
	return {"hero": hero["uid"], "learned": r.get("learned", []), "mana": r.get("mana", 0), "knowledge": r.get("knowledge", 0),
		"xp": r.get("xp", 0), "vortex": r.get("vortex", 0)}

# ---------------------------------------------------------------------------------------------
# Turns
# ---------------------------------------------------------------------------------------------
func end_turn() -> void:
	if busy:
		return
	var p := human_player()
	var idle := 0
	for hid in p["heroes"]:
		if world["heroes"][hid]["movement"] >= 300 and not world["heroes"][hid].get("in_town", false):
			idle += 1
	if idle > 0:
		var ok = await Modal.confirm(self, "End Turn", "One or more heroes can still move. End your turn anyway?").closed
		if not ok:
			return
	_advance_player()
	if not Net.mine(world["current_player"]):
		_await_others()
	else:
		_run_ai_turns()

func _advance_player() -> void:
	var res := rules.do({"t": "end_turn", "p": world["current_player"]})
	if not res["day"].is_empty():  # (a new day: each human player hears its news on their own next turn)
		for p in world["players"]:
			if not p["is_ai"]:
				GameState.view(p["index"])["news"] = res["day"].duplicate(true)

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
	if not Net.mine(world["current_player"]):
		_await_others()  # (online: the next is another machine's player)
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
	GameState.viewer = world["current_player"]
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
	for hid in human_player()["heroes"].duplicate():  # (online: levels gained defending on another's turn)
		if world["heroes"].has(hid) and int(world["heroes"][hid].get("pending_levels", 0)) > 0:
			await _handle_level_ups(world["heroes"][hid])

# ---------------------------------------------------------------------------------------------
# Online (Net)
# ---------------------------------------------------------------------------------------------
## Another machine's player (or, joined, the computer players on the host) is moving: the map is shown, its
## commands arrive as they are made (_on_remote_command).
func _await_others() -> void:
	busy = true
	var cur: Dictionary = world["players"][world["current_player"]]
	if Net.is_host and not cur["is_ai"] and not Net.joined(cur["index"]):
		hud.set_turn_label("Waiting for %s to join%s..." % [cur["name"], (" (room " + Net.room + ")") if Net.room != "" else ""])
	else:
		hud.set_turn_label("%s is moving..." % cur["name"])
	hud.refresh()

func _on_remote_command(cmd: Dictionary, res: Dictionary) -> void:
	if not is_inside_tree():
		return
	_net_dirty = true
	if cmd.get("t", "") != "end_turn":
		return
	if not res["day"].is_empty():  # (as _advance_player on the machine that ended the turn)
		for p in world["players"]:
			if not p["is_ai"]:
				GameState.view(p["index"])["news"] = res["day"].duplicate(true)
	_net_redraw()
	if await _check_game_over():
		return
	var cur: Dictionary = world["players"][world["current_player"]]
	if not Net.mine(cur["index"]):
		_await_others()
	elif cur["is_ai"]:
		_run_ai_turns()
	else:
		busy = false
		hud.set_turn_label("")
		await _start_human_turn()

func _net_redraw() -> void:
	_net_dirty = false
	rules.removed.clear()
	refresh_after_change()
	_refresh_fog()

func _on_world_received() -> void:
	GameState.change_scene(GameState.SCENE_ADVENTURE, 0.2)  # (the host's world: the screen starts again on it)

func _on_roster_changed() -> void:
	if is_inside_tree() and hud != null:
		hud.toast("A player has joined or left the game.")
		if busy and not Net.mine(world["current_player"]):
			_await_others()

## The connection went: back into the game (Reconnect: a joining machine rejoins, and its screen starts again on the
## host's world, _on_world_received; the host opens its room again and goes on), or to the main menu.
func _on_net_lost(reason: String) -> void:
	if not is_inside_tree() or Reconnect.running:
		return
	if Net.resume.is_empty():
		await Modal.message(self, "Disconnected", reason).closed
		GameState.change_scene(GameState.SCENE_MENU)
	elif not await Reconnect.run(self, reason):
		GameState.change_scene(GameState.SCENE_MENU)
	elif Net.is_host and is_inside_tree():
		hud.refresh()
		if busy and not Net.mine(world["current_player"]):
			_await_others()

## Online: other machines' commands are applied through this screen's rules, then shown.
func _net_attach() -> void:
	Net.rules = rules
	for pair in [[Net.remote_command, _on_remote_command], [Net.world_received, _on_world_received],
			[Net.roster_changed, _on_roster_changed], [Net.lost, _on_net_lost]]:
		if not (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).connect(pair[1])

func _exit_tree() -> void:
	if Net.rules == rules:
		Net.rules = null

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
	var info: Dictionary = _v()["news"]
	_v()["news"] = {}
	Audio.sfx("new_day", -4)
	hud.flash_date()
	if info.get("new_week", false):
		Audio.sfx("new_week")
		var cid: String = info.get("week_creature", "")
		var text := "Astrologers proclaim the Week of the %s.\nAll dwellings increase their population.\n\n%s" % [
			GameData.CREATURES[cid]["name"] if cid != "" else "Peasant", Lore.omen(world, world["day"])]
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
		Net.save(true)  # (online: the host's saved game has ended, and is no longer offered to resume)
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
		Net.save(true)
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
		if p["is_ai"] or GameState.view(p["index"])["defeat_told"]:
			continue
		if p["alive"] and loss.get("type", "") == "hero" and not world["heroes"].has(p.get("start_hero", -1)):
			rules.eliminate(p)  # (their champion fell: they are out)
		if not p["alive"]:
			out.append(p)
	if out.is_empty() or not GameState.hotseat_alive():
		return
	view.rebuild_objects()
	for p in out:
		GameState.view(p["index"])["defeat_told"] = true
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
	view.set_selected(_v()["selected_hero"])
	hud.refresh()

func _update_music() -> void:
	var hero := selected_hero()
	var t := "grass"
	if not hero.is_empty():
		t = WorldGen.TERRAIN_ORDER[rules.terrain_at(hero["pos"])]
	Audio.music("adventure_dirt" if t in ["dirt", "swamp", "snow", "subterranean"] else "adventure_grass")
