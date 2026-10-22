extends Node
## Town-defence diagnostic: generated-map campaigns played by one policy in every seat (production movement, visits
## and instant battles, as the tournament), recording every town capture with the state its owner left it in at
## the end of the owner's last turn: garrison, a hero at the gate, the strongest enemy army able to reach the gate
## within one and within two days, and the strongest own hero able to get back to it within one day.
##   Godot_console.exe --headless --path . res://tools/ai/town_defense_report.tscn -- --maps=1800,1801 --players=2
##   --size=36 --days=28 --policy=res://scripts/adventure/adv_ai.gd --verbose --trace=shots/x.jsonl (the driver's moves)
## A capture is "empty" when the town had no garrison and no hero, "exposed" when the capturer could already reach it
## within two days. Prints one CAPTURE line per capture (with --verbose) and a TOWN DEFENCE summary.
const Driver = preload("res://tools/ai/campaign_driver.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var maps: Array = []
	var players := 2
	var map_size := 36
	var days := 28
	var policy_path := "res://scripts/adventure/adv_ai.gd"
	var verbose := false
	var driver_trace := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--maps="):
			for value in arg.substr(7).split(","): maps.append(int(value))
		if arg.begins_with("--players="): players = int(arg.substr(10))
		if arg.begins_with("--size="): map_size = int(arg.substr(7))
		if arg.begins_with("--days="): days = int(arg.substr(7))
		if arg.begins_with("--policy="): policy_path = arg.substr(9)
		if arg == "--verbose": verbose = true
		if arg.begins_with("--trace="): driver_trace = arg.substr(8)
	if maps.is_empty(): maps = [1800, 1801, 1802, 1803]
	var Policy = load(policy_path)
	var driver := Driver.new()
	add_child(driver)
	if driver_trace != "": driver.trace = FileAccess.open(driver_trace, FileAccess.WRITE)
	var totals := {"captures": 0, "empty": 0, "exposed_empty": 0, "could_hold": 0, "held_lost": 0, "ended": 0,
		"end_days": 0, "towns_left_empty_exposed": 0, "owner_turns": 0, "swept": 0, "walked_out": 0}
	print("CONFIG maps=%s players=%d size=%d days=%d policy=%s" % [maps, players, map_size, days, policy_path])
	for m in maps:
		GameState._uid = 1000
		var state := WorldGen.generate({"seed": 48000 + m, "map_size": map_size, "opponents": players - 1,
			"faction": "haven" if m % 2 == 0 else "necropolis"})
		for p in state["players"]: p["is_ai"] = true
		driver.configure(state)
		driver.run_label = str(m)
		var policies: Array = []
		for seat in players: policies.append(Policy.new(driver.rules))
		var probe: AdvAI = AdvAI.new(driver.rules)  # (measurements only)
		var left := {}  # town uid -> what its owner left at the end of its last turn
		seed(88000 + m)
		var day_end := days
		for day in days:
			for p in state["players"]:
				if not p["alive"]: continue
				state["current_player"] = p["index"]
				driver.ai = policies[p["index"]]
				var owned_before := {}
				var start := {}  # this player's towns as the turn begins: garrison and a hero at the gate
				for t in state["towns"].values():
					owned_before[t["uid"]] = t["owner"]
					if t["owner"] == p["index"]:
						start[t["uid"]] = [GameState.army_strength(t["garrison"]), not driver.rules.hero_at(t["pos"]).is_empty()]
				await driver.ai.run_turn(driver, p)
				driver.record_turn(p)
				for t in state["towns"].values():
					var was: int = owned_before[t["uid"]]
					if was >= 0 and was != p["index"] and t["owner"] == p["index"] and left.has(t["uid"]):
						var l: Dictionary = left[t["uid"]]
						totals["captures"] += 1
						var empty: bool = l["garrison"] == 0 and not l["resident"]
						if empty: totals["empty"] += 1
						if empty and l["threat2"] > 0: totals["exposed_empty"] += 1
						if l["back"] > 0 and l["back"] + l["garrison"] * 1.25 >= l["threat1"] * 1.1 and l["threat1"] > 0:
							totals["could_hold"] += 1
						if l["resident"]: totals["held_lost"] += 1
						if empty and l["threat2"] > 0 and l["swept"]: totals["swept"] += 1
						if empty and l["threat2"] > 0 and l["walked_out"]: totals["walked_out"] += 1
						if verbose:
							print("CAPTURE map=%d day=%d town=%d from=%d by=%d left: garrison=%d resident=%s threat1=%.0f threat2=%.0f back=%.0f owner_towns=%d swept=%s walked_out=%s" %
								[m, state["day"], t["uid"], was, p["index"], l["garrison"], l["resident"], l["threat1"],
								l["threat2"], l["back"], l["towns"], l["swept"], l["walked_out"]])
				# what this player leaves behind for the others' turns
				for tid in p["towns"]:
					var t: Dictionary = state["towns"][tid]
					var resident := driver.rules.hero_at(t["pos"])
					var l := {"garrison": GameState.army_strength(t["garrison"]), "resident": not resident.is_empty(),
						"threat1": _threat(driver.rules, probe, t, 1), "threat2": _threat(driver.rules, probe, t, 2),
						"back": _back(driver.rules, probe, p, t), "towns": p["towns"].size(),
						"swept": start.has(tid) and start[tid][0] > 0 and GameState.army_strength(t["garrison"]) < start[tid][0],
						"walked_out": start.has(tid) and start[tid][1] and resident.is_empty()}
					left[tid] = l
					totals["owner_turns"] += 1
					if l["garrison"] == 0 and not l["resident"] and l["threat2"] > 0:
						totals["towns_left_empty_exposed"] += 1
			if state["players"].filter(func(p): return p["alive"]).size() <= 1:
				day_end = state["day"]
				totals["ended"] += 1
				break
			driver.rules.new_day()
		totals["end_days"] += day_end
		print("MAP %d day=%d alive=%s towns=%s" % [m, state["day"], state["players"].map(func(p): return p["alive"]),
			state["players"].map(func(p): return p["towns"].size())])
		await get_tree().process_frame
	print("TOWN DEFENCE: %d maps, captures %d (empty %d, empty and reachable within two days %d [garrison taken that turn %d, a hero walked out %d], a hero could have held %d, with a hero inside %d), towns left empty within two days' reach %d of %d town-turns, games ended %d, mean end day %.1f" %
		[maps.size(), totals["captures"], totals["empty"], totals["exposed_empty"], totals["swept"], totals["walked_out"], totals["could_hold"], totals["held_lost"],
		totals["towns_left_empty_exposed"], totals["owner_turns"], totals["ended"], float(totals["end_days"]) / maps.size()])
	driver.queue_free()
	await get_tree().process_frame
	get_tree().quit()

## The strongest hostile army whose route to the gate costs at most `days` days of its full movement.
func _threat(rules: AdvRules, probe: AdvAI, town: Dictionary, days: int) -> float:
	var threat := 0.0
	for enemy in rules.world["heroes"].values():
		if enemy["owner"] == town["owner"]: continue
		var budget: int = enemy.get("max_movement", enemy["movement"]) * days
		if Vector2(enemy["pos"] - town["pos"]).length() * 50.0 > budget: continue
		var plan := rules.plan(enemy, town["pos"])
		if not plan["path"].is_empty() and plan["costs"].back() <= budget:
			threat = maxf(threat, probe._strength(enemy))
	return threat

## The strongest own hero (outside the town) able to walk back to its gate within a day of full movement.
func _back(rules: AdvRules, probe: AdvAI, player: Dictionary, town: Dictionary) -> float:
	var best := 0.0
	for hid in player["heroes"]:
		var h: Dictionary = rules.world["heroes"][hid]
		if h["pos"] == town["pos"]: continue
		var budget: int = h.get("max_movement", 1500)
		if Vector2(h["pos"] - town["pos"]).length() * 50.0 > budget: continue
		var plan := rules.plan(h, town["pos"])
		if not plan["path"].is_empty() and plan["costs"].back() <= budget:
			best = maxf(best, probe._strength(h))
	return best
