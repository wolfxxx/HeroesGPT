extends Node
## Paired generated-map campaigns with sides swapped, using production movement/AI/instant combat.
## --pairs=8 --days=28 --start=0; --self compares the frozen AI with itself (paired delta must be zero).
## --baseline=res://tools/ai/adventure_ai_checkpoint.gd compares against 4f126ec; --trace=shots/run.jsonl logs turns.
## Strategic score is army value + 5000/town + 5 days of mine income + half gold + 100/hero level.
## Score is a proxy at the day limit; report actual eliminations separately, never call score leads wins.
const Driver = preload("res://tools/ai/campaign_driver.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var pairs := 8
	var days := 28
	var first := 0
	var control := false
	var baseline_path := "res://tools/ai/adventure_ai_baseline.gd"
	var trace_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pairs="): pairs = int(arg.substr(8))
		if arg.begins_with("--days="): days = int(arg.substr(7))
		if arg.begins_with("--start="): first = int(arg.substr(8))
		if arg == "--self": control = true
		if arg.begins_with("--baseline="): baseline_path = arg.substr(11)
		if arg.begins_with("--trace="): trace_path = arg.substr(8)
	if pairs < 1 or days < 1 or first < 0:
		push_error("Expected --pairs >= 1, --days >= 1 and --start >= 0")
		get_tree().quit(1)
		return
	var driver := Driver.new()
	add_child(driver)
	var baseline = load(baseline_path)
	if baseline == null or not baseline.can_instantiate():
		push_error("Cannot load campaign baseline: " + baseline_path)
		get_tree().quit(1)
		return
	if trace_path != "":
		driver.trace = FileAccess.open(trace_path, FileAccess.WRITE)
		if driver.trace == null:
			push_error("Cannot open campaign trace: " + trace_path)
			get_tree().quit(1)
			return
	var differences := []
	var wins := [0, 0, 0]
	var battles := 0
	for pair in range(first, first + pairs):
		var delta := 0.0
		for side in 2:
			GameState._uid = 1000 # generated towns/spell pools must match between the paired games
			var state := WorldGen.generate({"seed": 48000 + pair, "map_size": 36, "opponents": 1,
				"faction": "haven" if pair % 2 == 0 else "necropolis"})
			for p in state["players"]: p["is_ai"] = true
			driver.configure(state)
			driver.run_label = "%d/%d" % [pair, side]
			var policies: Array = [baseline.new(driver.rules), baseline.new(driver.rules)]
			if not control: policies[side] = AdvAI.new(driver.rules)
			seed(88000 + pair)
			for day in days:
				for p in state["players"]:
					if not p["alive"]: continue
					state["current_player"] = p["index"]
					driver.ai = policies[p["index"]]
					await driver.ai.run_turn(driver, p)
					driver.record_turn(p)
				if state["players"].any(func(p): return not p["alive"]): break
				driver.rules.new_day()
			var a := _score(state, side)
			var b := _score(state, 1 - side)
			delta += (a - b) / maxf(1.0, a + b) * 50.0
			if not state["players"][1 - side]["alive"]: wins[0] += 1
			elif not state["players"][side]["alive"]: wins[1] += 1
			else: wins[2] += 1
			print("CAMPAIGN pair=%d side=%d day=%d current_score=%.0f baseline_score=%.0f towns=%d/%d" %
				[pair, side, state["day"], a, b, state["players"][side]["towns"].size(), state["players"][1-side]["towns"].size()])
		differences.append(delta)
		await get_tree().process_frame
	battles = driver.battles
	var mean := 0.0
	for x in differences: mean += x / differences.size()
	var variance := 0.0
	for x in differences: variance += pow(x - mean, 2)
	var error := 2.0 * sqrt(variance / maxf(1, pairs - 1) / maxf(1, pairs))
	print("ADVENTURE TOURNAMENT: %d pairs, score delta %.2f +/- %.2f points (2 SE), wins %d losses %d unresolved %d, battles %d, self=%s" %
		[pairs, mean, error, wins[0], wins[1], wins[2], battles, control])
	var failed: bool = control and differences.any(func(d): return not is_zero_approx(d))
	if failed: print("FAIL self-play paired baseline is not deterministic")
	driver.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

func _score(state: Dictionary, side: int) -> float:
	var p: Dictionary = state["players"][side]
	if not p["alive"]: return 0.0
	var score: float = p["towns"].size() * 5000 + p["resources"]["gold"] * 0.5
	for hid in p["heroes"]:
		var h: Dictionary = state["heroes"][hid]
		score += GameState.army_strength(h["army"]) + h["level"] * 100
	for tid in p["towns"]: score += GameState.army_strength(state["towns"][tid]["garrison"])
	for o in state["objects"].values():
		if o["type"] == "mine" and o["owner"] == side:
			var m: Dictionary = GameData.MINES[o["mine"]]
			score += 5 * m["amount"] * (1 if m["resource"] == "gold" else (100 if m["resource"] in ["wood", "ore"] else 250))
	return score
