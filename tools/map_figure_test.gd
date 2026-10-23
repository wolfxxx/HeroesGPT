extends Node
## Each hero class has its own figure on the adventure map, as the classic: the Knight and the Death Knight their
## faction's (map_haven, map_necropolis), the Cleric and the Necromancer their own (map_cleric, map_necromancer), each
## with its own gallop frames.
##   Godot_console.exe --headless --path . res://tools/map_figure_test.tscn  -> "MAP FIGURE TEST: N checks, failures: 0"
## In a window, `-- --capture=shots/dir` also saves the four side by side on the map, then the Cleric mid-gallop.

const HEROES := {"sir_aldric": "haven", "brother_tomas": "cleric", "lord_morthis": "necropolis",
	"vesna_nightshade": "necromancer"}

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
		var w := WorldGen.generate(s)
		GameState.world = w
		var me: Dictionary = w["players"][0]
		var start: Dictionary = w["heroes"][w["start_hero"]]
		var rules := AdvRules.new(w)
		rules.rebuild()
		# the four on free ground in a row by the starting hero
		var spots: Array = []
		for dy in range(-3, 4):
			for dx in range(-4, 5):
				var p: Vector2i = start["pos"] + Vector2i(dx, dy)
				if spots.size() < 4 and rules.inside(p) and rules.walkable_ground(p) and rules.at(p).is_empty() \
						and spots.all(func(q): return absi(q.x - p.x) >= 2 or q.y != p.y) and p != start["pos"]:
					spots.append(p)
		_ok(spots.size() == 4, "found four free tiles by the start")
		var uids := {}
		var k := 0
		for id in HEROES:
			var h := GameState.make_hero(id, 0)
			h["pos"] = spots[k] if k < spots.size() else start["pos"]
			w["heroes"][h["uid"]] = h
			me["heroes"].append(h["uid"])
			uids[id] = h["uid"]
			k += 1
			_ok(MapView.hero_figure(h) == HEROES[id], "%s (%s) rides as map_%s" % [h["name"], h["class"], HEROES[id]])
			_ok(Assets.has("heroes/map_%s_run0.png" % HEROES[id]), "with %s's gallop frames" % h["class"])
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await get_tree().create_timer(1.5).timeout
		var adv = get_tree().current_scene
		for id in uids:
			var n = adv.view.hero_node(uids[id])
			var spr: Sprite2D = n.get_node("Sprite") if n else null
			_ok(spr != null and spr.texture.resource_path.ends_with("map_%s.png" % HEROES[id]), "%s is drawn with its class figure" % id)
		adv.center_on(spots[1] if spots.size() > 1 else start["pos"], true)
		await _capture("map_figures.png")
		# a step of the Cleric: its own gallop frames
		var cl: Dictionary = w["heroes"][uids["brother_tomas"]]
		var cs: Sprite2D = adv.view.hero_node(cl["uid"]).get_node("Sprite")
		adv.view.move_hero_step(cl["uid"], cl["pos"] + Vector2i(0, 1), 0.6)
		await get_tree().create_timer(0.1).timeout
		_ok(cs.texture.resource_path.contains("map_cleric_run"), "the Cleric gallops with its own frames")
		await _capture("map_figures_gallop.png", 0)
		await get_tree().create_timer(1.0).timeout
		_ok(cs.texture.resource_path.ends_with("map_cleric.png"), "and stands again as the Cleric")
		# the pennant flies behind the rider whichever way the hero faces, above its head; no owner-coloured outline
		var node: Node2D = adv.view.hero_node(cl["uid"])
		var flag: Node2D = node.get_node("Flag")
		_ok(flag.position.x < 0 and flag.scale.x < 0 and flag.position.y < -60, "facing right, the pennant flies left, up behind the rider")
		_ok(cs.material.get_shader_parameter("team") == null or cs.material.get_shader_parameter("team").a == 0.0, "no owner-coloured outline on the figure")
		adv.view.move_hero_step(cl["uid"], cl["pos"] + Vector2i(-1, 1), 0.6)
		await get_tree().create_timer(0.2).timeout
		_ok(flag.position.x > 0 and flag.scale.x > 0, "facing left, the pennant flies right, still behind the rider")
		await _capture("map_figures_left.png", 0)
		await get_tree().create_timer(1.0).timeout
		print("MAP FIGURE TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()

	func _capture(file: String, frames := 20) -> void:
		var dir := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--capture="):
				dir = a.trim_prefix("--capture=")
		if dir == "" or DisplayServer.get_name() == "headless":
			return
		for i in frames:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + dir))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + dir + "/" + file))
