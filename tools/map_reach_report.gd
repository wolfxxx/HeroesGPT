extends Node
## Diagnostic sweep: for generated maps, counts objects that terrain and building footprints cut off from player 0's
## starting town. Movement follows AdvRules: 8 directions, a diagonal needs a free orthogonal side tile. Pickups,
## monsters, building entrances and town gates count as passable (each is cleared or stepped through), so only
## water, obstacles and building walls separate regions. An object counts as reachable when its action tile is.
## Run: Godot --headless --path . res://tools/map_reach_report.tscn [-- --save=user://playtest_save.dat]
##   -> "REACH SWEEP {...}" (about a minute). Exit code 1 if any map has an unreachable object or town.

const DIRS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("scenario"):  # the tiles a scenario map's access pass cleared: --scenario=shattered_crown
		var st := GameState.new_game_settings.duplicate()
		st["scenario"] = args["scenario"]
		st["seed"] = int(GameData.scenario(args["scenario"])["seed"])
		var wd := WorldGen.generate(st)
		print("cleared: ", WorldGen.last_cleared, " size ", wd["size"])
		get_tree().quit()
		return
	if args.has("save"):
		var f := FileAccess.open(args["save"], FileAccess.READ)
		var w: Dictionary = f.get_var()["world"]
		var start: Vector2i = w["towns"].values().filter(func(t): return t.get("start_owner", t["owner"]) == 0)[0]["pos"]
		print("save: ", report(w, start + Vector2i(0, 1)))
		get_tree().quit()
		return
	var tot := {"maps": 0, "maps_with_cut": 0, "objects": 0, "cut": {}}
	for size in [36, 48, 64]:
		for s in 12:
			var seed_v: int = 7000 + int(size) * 100 + s
			var w := WorldGen.generate({"seed": seed_v, "map_size": size, "opponents": 1 if size < 48 else 3, "faction": "haven"})
			GameState.world = w
			var start: Vector2i = w["towns"].values().filter(func(t): return t["owner"] == 0)[0]["pos"] + Vector2i(0, 1)
			var cut := report(w, start)
			tot["maps"] += 1
			tot["objects"] += w["objects"].size()
			if cut.size() > 0:
				tot["maps_with_cut"] += 1
			for k in cut:
				tot["cut"][k] = tot["cut"].get(k, 0) + cut[k]
			print("size %d seed %d: %s" % [size, seed_v, cut])
	print("REACH SWEEP ", tot)
	get_tree().quit(1 if tot["maps_with_cut"] > 0 else 0)

static func passable(w: Dictionary, p: Vector2i) -> bool:
	var s: Vector2i = w["size"]
	if p.x < 0 or p.y < 0 or p.x >= s.x or p.y >= s.y:
		return false
	var i := p.y * s.x + p.x
	return w["blocked"][i] == 0 and w["terrain"][i] != WorldGen.T_WATER

static func flood(w: Dictionary, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var stack := [start]
	while stack.size() > 0:
		var p: Vector2i = stack.pop_back()
		for d in DIRS:
			var q: Vector2i = p + d
			if seen.has(q) or not passable(w, q):
				continue
			if d.x != 0 and d.y != 0 and not passable(w, p + Vector2i(d.x, 0)) and not passable(w, p + Vector2i(0, d.y)):
				continue
			seen[q] = true
			stack.append(q)
	return seen

## {kind: count} of objects (and towns) whose action tile the start cannot reach.
static func report(w: Dictionary, start: Vector2i) -> Dictionary:
	var seen := flood(w, start)
	var cut := {}
	for o in w["objects"].values():
		if not seen.has(o["pos"]):
			var k: String = o["type"]
			cut[k] = cut.get(k, 0) + 1
	for t in w["towns"].values():
		if not seen.has(t["pos"]):
			cut["town"] = cut.get("town", 0) + 1
	return cut
