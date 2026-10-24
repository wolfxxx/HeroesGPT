extends Node
## Replay test (docs/FOUNDATIONS_AUDIT.md, step 4): computer players play a seeded map for some days through the real
## turn path (tools/ai/campaign_driver.gd), every accepted command recorded (Commands.log). The commands, sent through
## Godot's own encoding as a network would carry them, are then applied to a copy of the starting world, and the two
## worlds must match. Set aside: what only the computer or the map screen keep for themselves (IGNORED). A second run of
## the same seed must give the same world as well (repeatable dice).
##   Godot --headless --path . res://tools/replay_test.tscn

const Driver := preload("res://tools/ai/campaign_driver.gd")
## Keys that are not game state: the computer's own notes and the walking hero's route and facing on screen.
const IGNORED := ["ai_day", "ai_goal", "yield", "dest", "face_left"]

var checks := 0
var failures := 0

func _ready() -> void:
	for g in [[51001, 2, 36, 12], [51002, 3, 48, 7]]:
		await _game(g[0], g[1], g[2], g[3])
	print("REPLAY TEST: %d checks, failures: %d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", what)

## Plays `days` days with every seat a computer player; returns [starting world, uid counter at the start, the
## recorded commands, the world at the end, the uid counter at the end].
func _play(seed_v: int, players: int, size: int, days: int) -> Array:
	GameState._uid = 1000
	var state := WorldGen.generate({"seed": seed_v, "map_size": size, "opponents": players - 1, "faction": "haven"})
	for p in state["players"]:
		p["is_ai"] = true
	var start: Dictionary = state.duplicate(true)
	var uid0: int = GameState._uid
	var driver = Driver.new()
	add_child(driver)
	driver.configure(state)
	var ais := []
	for i in players:
		ais.append(AdvAI.new(driver.rules))
	Commands.log = []
	Commands.log_world = state
	var turns := 0
	while state["day"] <= days and state["players"].filter(func(p): return p["alive"]).size() > 1 and turns < 400:
		var p: Dictionary = state["players"][state["current_player"]]
		driver.ai = ais[p["index"]]
		await driver.ai.run_turn(driver, p)
		var r: Dictionary = driver.rules.do({"t": "end_turn", "p": p["index"]})
		if not r["ok"]:
			_check(false, "end_turn refused: %s" % r["reason"])
			break
		turns += 1
	Commands.log_world = null
	var log: Array = Commands.log
	Commands.log = []
	driver.queue_free()
	await get_tree().process_frame
	return [start, uid0, log, state, GameState._uid]

func _game(seed_v: int, players: int, size: int, days: int) -> void:
	var a := await _play(seed_v, players, size, days)
	var log: Array = bytes_to_var(var_to_bytes(a[2]))  # (as a network would carry them)
	var kinds := {}
	for c in log:
		kinds[c["t"]] = kinds.get(c["t"], 0) + 1
	print("REPLAY seed %d: %d players, day %d, %d commands %s" % [seed_v, players, a[3]["day"], log.size(), kinds])
	_check(log.size() > 100 and kinds.has("end_turn") and kinds.has("step"), "seed %d: a real game was recorded" % seed_v)
	# replay on a copy of the starting world
	GameState._uid = a[1]
	var copy: Dictionary = a[0].duplicate(true)
	GameState.world = copy
	var rules := AdvRules.new(copy)
	var refused := 0
	for i in log.size():
		var r := rules.do(log[i])
		if not r["ok"]:
			refused += 1
			if refused <= 3:
				print("  refused #%d %s: %s" % [i, log[i]["t"], r["reason"]])
	_check(refused == 0, "seed %d: every recorded command accepted on replay (%d refused)" % [seed_v, refused])
	_check(GameState._uid == a[4], "seed %d: the same uids handed out" % seed_v)
	var diffs := []
	_diff(a[3], copy, "world", diffs)
	for d in diffs.slice(0, 8):
		print("  differs: ", d)
	_check(diffs.is_empty(), "seed %d: the replayed world matches the played one (%d differences)" % [seed_v, diffs.size()])
	# the same seed played again: the same world (the dice are the world's, not the clock's)
	var b := await _play(seed_v, players, size, days)
	var diffs2 := []
	_diff(a[3], b[3], "world", diffs2)
	for d in diffs2.slice(0, 8):
		print("  second run differs: ", d)
	_check(diffs2.is_empty() and a[2].size() == b[2].size(), "seed %d: a second run is identical" % seed_v)

func _diff(x, y, path: String, out: Array) -> void:
	if out.size() > 50:
		return
	if x is Dictionary and y is Dictionary:
		var keys := {}
		for k in x:
			keys[k] = true
		for k in y:
			keys[k] = true
		for k in keys:
			if str(k) in IGNORED:
				continue
			if not x.has(k) or not y.has(k):
				out.append("%s.%s only in %s" % [path, k, "played" if x.has(k) else "replayed"])
			else:
				_diff(x[k], y[k], "%s.%s" % [path, k], out)
	elif (x is Array or x is PackedByteArray or x is PackedInt32Array) and typeof(x) == typeof(y):
		if x.size() != y.size():
			out.append("%s: size %d vs %d" % [path, x.size(), y.size()])
			return
		for i in x.size():
			_diff(x[i], y[i], "%s[%d]" % [path, i], out)
	elif typeof(x) != typeof(y) or x != y:
		out.append("%s: %s vs %s" % [path, str(x).left(60), str(y).left(60)])
