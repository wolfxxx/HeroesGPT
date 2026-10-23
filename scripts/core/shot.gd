extends Node
## Automated screenshot harness (used by dev + judge agents).
## Usage (from project dir):
##   Godot_console.exe --path . -- --shot=shots/battle.png --scene=res://scenes/battle.tscn --delay=2.5 [--setup=demo]
## Multiple shots: --shots=3 --interval=1.5 -> writes shots/battle_0.png, _1, _2
## --setup=<name> is exposed as Shot.setup so scenes can build a demo state when launched directly.
## --click=x,y;x,y simulates left clicks (in 1920x1080 viewport coords) one per interval before each shot.
## --hover=x,y;x,y moves the mouse there (after that shot's click, if any) before each shot; "-" skips one.

## --remote=<dir> instead plays the real game from outside (playtests): see _remote.

var setup := ""
var active := false
var remote := false
var args := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	setup = args.get("setup", "")
	if args.has("shot"):
		active = true
		_run.call_deferred()
	elif args.has("remote"):
		remote = true
		_remote.call_deferred()

## Remote play: the game runs normally (main menu first, no demo setups) while another program drives it with
## real input events. It polls <dir>/cmd.txt, runs its lines in order, deletes it and writes <dir>/done.txt with
## the first line's id. Coordinates are WINDOW pixels (the 1600x900 screenshots), not the 1920x1080 design space.
##   id N | click x y | rclick x y (held for `hold` s, default 0.8) | dclick x y | move x y | park
##   key Name (e.g. Enter, Escape, ctrl+s) | keydown Name | keyup Name | wait seconds
##   rtile tx ty seconds [file.png] (hold right on a map tile) | shot file.png (inside <dir>) | state file.json (scene, day, the human side's kingdom) | quit
## Menus and Ctrl+S save to user://playtest_save.dat, never the player's own save. Audio is muted.
func _remote() -> void:
	var dir: String = args["remote"]
	if not dir.is_absolute_path():
		dir = ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.save_path = "user://playtest_save.dat"
	AudioServer.set_bus_mute(0, true)
	DirAccess.remove_absolute(dir.path_join("cmd.txt"))
	print("REMOTE ready ", dir)
	while true:
		await get_tree().create_timer(0.1).timeout
		var path := dir.path_join("cmd.txt")
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		DirAccess.remove_absolute(path)
		var id := ""
		var log_lines: PackedStringArray = []
		for raw in text.split("\n", false):
			var w := raw.strip_edges().split(" ", false)
			if w.is_empty():
				continue
			var p := Vector2.ZERO
			if w.size() >= 3 and w[1].is_valid_float():
				p = Vector2(float(w[1]), float(w[2]))
			match w[0]:
				"id": id = w[1]
				"click": _press(p, MOUSE_BUTTON_LEFT)
				"dclick":
					_press(p, MOUSE_BUTTON_LEFT)
					_press(p, MOUSE_BUTTON_LEFT, true)
				"rclick": await _hold(p, MOUSE_BUTTON_RIGHT, float(w[3]) if w.size() > 3 else 0.8, dir, w)
				"move": _motion(p)
				"park": _motion(Vector2(-400, -400))
				"key": _key(w[1])
				"keydown": _key(w[1], 1)
				"keyup": _key(w[1], 2)
				"wait": await get_tree().create_timer(float(w[1])).timeout
				"shot": await _capture(dir.path_join(w[1]))
				"state": _dump(dir.path_join(w[1]))
				"probe": log_lines.append(_probe(p))
				"ctile": await _click_tile(Vector2i(int(w[1]), int(w[2])), w.size() > 3 and w[3] == "right")
				"rtile": await _hold_tile(Vector2i(int(w[1]), int(w[2])), float(w[3]) if w.size() > 3 else 0.8, dir, w)
				"look": log_lines.append(_look(int(w[1]) if w.size() > 1 else 8))
				"hoverstate": log_lines.append(_hover_state())
				"quit": get_tree().quit()
				_: log_lines.append("unknown command: " + raw)
			await get_tree().process_frame
		var f := FileAccess.open(dir.path_join("done.txt"), FileAccess.WRITE)
		f.store_string(id + "\n" + "\n".join(log_lines))
		f.close()

func _motion(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)

func _press(p: Vector2, button: MouseButton, double := false) -> void:
	_motion(p)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.double_click = double and pressed
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)

## A held right click (HoMM's information popups last while the button is down), with an optional shot taken
## during the hold: rclick x y seconds file.png
func _hold(p: Vector2, button: MouseButton, secs: float, dir: String, w: PackedStringArray) -> void:
	_motion(p)
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)
	await get_tree().create_timer(secs).timeout
	if w.size() > 4:
		await _capture(dir.path_join(w[4]))
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.position = p
	up.global_position = p
	Input.parse_input_event(up)

func _capture(out: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)

## What a player can read off their own kingdom screen, for the playtest log (enemy details are left out).
func _dump(out: String) -> void:
	var s := {"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		"window": DisplayServer.window_get_size()}
	var w := GameState.world
	if not w.is_empty():
		var me := GameState.human_player_index()
		s["day"] = w["day"]
		s["current_player"] = w["current_player"]
		s["players"] = w["players"].map(func(p): return {"index": p["index"], "ai": p["is_ai"],
			"faction": p.get("faction", ""), "alive": p.get("alive", true), "towns": p["towns"].size(),
			"heroes": p["heroes"].size()})
		s["resources"] = w["players"][me]["resources"]
		var heroes := []
		for uid in w["players"][me]["heroes"]:
			var h: Dictionary = w["heroes"][uid]
			heroes.append({"uid": uid, "name": h.get("name", ""), "pos": h.get("pos"), "level": h.get("level"),
				"mp": h.get("movement"), "mana": h.get("mana"), "army": h.get("army")})
		s["heroes"] = heroes
		var towns := []
		for uid in w["players"][me]["towns"]:
			var t: Dictionary = w["towns"][uid]
			towns.append({"uid": uid, "name": t.get("name", ""), "pos": t.get("pos"), "built_today": t.get("built_today"),
				"buildings": t.get("buildings"), "garrison": t.get("garrison")})
		s["towns"] = towns
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_jsonable(s), "  "))
	f.close()

## What a left click at a window point on the adventure map resolves to, for the selected hero (playtest diagnosis).
func _probe(p: Vector2) -> String:
	var adv := get_tree().current_scene
	if adv == null or not "rules" in adv:
		return "probe: not on the adventure map"
	var wp: Vector2 = adv._event_world(_fake_event(p))
	var raw: Vector2i = adv.view.tile_at(wp)
	var t: Vector2i = adv._pick(raw, wp)
	var r: AdvRules = adv.rules
	var oc := r.object_covering(t)
	var h: Dictionary = adv.selected_hero()
	var plan := r.plan(h, t) if not h.is_empty() else {}
	return "probe %s: raw %s pick %s at=%s covering=%s walkable=%s hero=%s plan=%s len=%d reach=%d" % [p, raw, t,
		r.at(t), "%s@%s" % [oc.get("type", ""), oc.get("pos", "")] if not oc.is_empty() else "-", r.walkable_ground(t),
		h.get("pos", "-"), plan.get("kind", "-"), plan.get("path", []).size(), plan.get("reach", 0)]

## A real mouse click on a map tile: scrolls the view there first if it is off screen (as a player would).
func _click_tile(t: Vector2i, right: bool) -> void:
	var adv := get_tree().current_scene
	if adv == null or not "view" in adv:
		return
	var canvas: Vector2 = get_viewport().get_canvas_transform() * adv.view.tile_center(t)
	if canvas.x < 40 or canvas.y < 40 or canvas.x > 1500 or canvas.y > 1000:
		adv.center_on(t, true)
		await get_tree().create_timer(0.3).timeout
		canvas = get_viewport().get_canvas_transform() * adv.view.tile_center(t)
	var win: Vector2 = get_viewport().get_final_transform() * canvas
	_press(win, MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT)

## Holds the right button on a map tile (scrolling there first): rtile x y seconds [file.png shot during the hold].
func _hold_tile(t: Vector2i, secs: float, dir: String, w: PackedStringArray) -> void:
	var adv := get_tree().current_scene
	if adv == null or not "view" in adv:
		return
	var canvas: Vector2 = get_viewport().get_canvas_transform() * adv.view.tile_center(t)
	if canvas.x < 40 or canvas.y < 40 or canvas.x > 1500 or canvas.y > 1000:
		adv.center_on(t, true)
		await get_tree().create_timer(0.3).timeout
		canvas = get_viewport().get_canvas_transform() * adv.view.tile_center(t)
	var win: Vector2 = get_viewport().get_final_transform() * canvas
	var ww := PackedStringArray(["rtile", str(win.x), str(win.y), str(secs)])
	if w.size() > 4:
		ww.append(w[4])
	await _hold(win, MOUSE_BUTTON_RIGHT, secs, dir, ww)

## The map's hover / right-click panel and the dialog layer, for diagnosing a panel that does not show.
func _hover_state() -> String:
	var l = get_tree().root.get_node_or_null("HoverLayer")
	var ml = get_tree().root.get_node_or_null("ModalLayer")
	var kids := []
	if ml:
		for c in ml.get_children():
			kids.append("%s(%s,visible=%s,freed=%s)" % [c.name, c.get_class(), c.visible if c is CanvasItem else "-", c.is_queued_for_deletion()])
	if l == null:
		return "hover: no HoverLayer; modal children %s" % [kids]
	return "hover: visible=%s content=%s owner=%s pos=%s size=%s mouse=%s wait=%.2f floor=%s area=%s layer_visible=%s; modal children %s; viewport mouse %s, OS cursor %s, window at %s" % [
		l.panel.visible, l.content != null, l.owner_obj, l.panel.position, l.panel.size, l.mouse, l.wait, l.floor_y, l.area,
		l.visible, kids, get_viewport().get_mouse_position(), DisplayServer.mouse_get_position(), DisplayServer.window_get_position()]

## The status-bar description of every explored object within r tiles of the selected hero (what hovering shows).
func _look(r: int) -> String:
	var adv := get_tree().current_scene
	if adv == null or not "rules" in adv:
		return "look: not on the adventure map"
	var h: Dictionary = adv.selected_hero()
	var c: Vector2i = h.get("pos", Vector2i.ZERO)
	var out: PackedStringArray = ["look around %s (%s, %d mp):" % [c, h.get("name", ""), h.get("movement", 0)]]
	var w := GameState.world
	var items := []
	for o in w["objects"].values():
		var p: Vector2i = o["pos"]
		if absi(p.x - c.x) <= r and absi(p.y - c.y) <= r and adv.rules.is_explored(adv.human_player(), p):
			items.append([p, adv._describe_tile(p)])
	for t in w["towns"].values():
		var p: Vector2i = t["pos"]
		if absi(p.x - c.x) <= r and absi(p.y - c.y) <= r and adv.rules.is_explored(adv.human_player(), p):
			items.append([p, "TOWN " + adv._describe_tile(p)])
	for hh in w["heroes"].values():
		var p: Vector2i = hh["pos"]
		if hh != h and absi(p.x - c.x) <= r and absi(p.y - c.y) <= r and adv.rules.is_explored(adv.human_player(), p):
			items.append([p, "HERO " + adv._describe_tile(p)])
	items.sort_custom(func(a, b): return (a[0] - c).length_squared() < (b[0] - c).length_squared())
	for it in items:
		var plan: Dictionary = adv.rules.plan(h, it[0]) if not h.is_empty() else {}
		var cost: int = plan["costs"].back() if not plan.get("costs", []).is_empty() else -1
		out.append("  %s %s  [%s, cost %d]" % [it[0], it[1], plan.get("kind", "-"), cost])
	return "\n".join(out)

func _fake_event(p: Vector2) -> InputEventMouseMotion:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	return m

func _jsonable(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _jsonable(v[k])
			return d
		TYPE_ARRAY:
			return v.map(func(x): return _jsonable(x))
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return v
	return str(v)

func _run() -> void:
	if args.has("scene"):
		get_tree().change_scene_to_file(args["scene"])
	var delay := float(args.get("delay", "2.5"))
	var count := int(args.get("shots", "1"))
	var interval := float(args.get("interval", "1.5"))
	var clicks: PackedStringArray = args.get("click", "").split(";", false)
	var keys: PackedStringArray = args.get("keys", "").split(";", false)
	var hovers: PackedStringArray = args.get("hover", "").split(";", false)
	# the real pointer may rest over the window: park the game's mouse off the screen, so no stray hover (a lit hex,
	# a tooltip) shows in a shot that does not ask for one
	await get_tree().process_frame
	var park := InputEventMouseMotion.new()
	park.position = Vector2(-400, -400)
	Input.parse_input_event(park)
	await get_tree().create_timer(delay).timeout
	var base: String = args["shot"]
	for i in count:
		if i < clicks.size():
			var right := clicks[i].begins_with("r")  # "r960,540": a right click
			var xy := clicks[i].trim_prefix("r").split(",")
			_click(Vector2(float(xy[0]), float(xy[1])), MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT)
			await get_tree().create_timer(0.6).timeout
		if i < hovers.size() and hovers[i] != "-":
			var hp := hovers[i].split(",")
			var m := InputEventMouseMotion.new()
			m.position = get_viewport().get_final_transform() * Vector2(float(hp[0]), float(hp[1]))
			Input.parse_input_event(m)
			await get_tree().create_timer(0.8).timeout
		if i < keys.size() and keys[i] != "":
			_key(keys[i])
			await get_tree().create_timer(0.6).timeout
		# (parked again: a scene loaded since, or the real pointer moving over the window, may have lit a hover; not
		# when the shot asks for a hover or a right-click panel, which the pointer holds open)
		if hovers.is_empty() and not Array(clicks).any(func(c): return c.begins_with("r")):
			Input.parse_input_event(park)
			await get_tree().process_frame
		# (the window was now and then grown to nearly the whole screen mid-run, from outside the game: back to the
		# shot size before each capture, so every shot is 1600x900)
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if DisplayServer.window_get_size() != Vector2i(1600, 900):
			print("SHOT window was ", DisplayServer.window_get_size(), ": resized")
			DisplayServer.window_set_size(Vector2i(1600, 900))
			for f in 3:
				await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var out := base if count == 1 else base.get_basename() + "_%d.png" % i
		var abs_path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
		DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
		img.save_png(abs_path)
		print("SHOT saved ", abs_path)
		if i < count - 1:
			await get_tree().create_timer(interval).timeout
	get_tree().quit()

func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var vp := get_viewport()
	# Convert from 1920x1080 design coordinates into the window's coordinates.
	var xf := vp.get_final_transform()
	var p: Vector2 = xf * pos
	var m := InputEventMouseMotion.new()
	m.position = p
	Input.parse_input_event(m)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = p
		Input.parse_input_event(e)

## mode 0: press and release, 1: press only, 2: release only. "ctrl+s" / "shift+Tab" add modifiers.
func _key(name: String, mode := 0) -> void:
	var parts := name.split("+")
	var code := OS.find_keycode_from_string(parts[-1])
	for pressed in [true, false]:
		if (mode == 1 and not pressed) or (mode == 2 and pressed):
			continue
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		e.ctrl_pressed = parts.has("ctrl")
		e.shift_pressed = parts.has("shift")
		e.alt_pressed = parts.has("alt")
		Input.parse_input_event(e)
