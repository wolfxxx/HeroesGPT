extends Node
## Paired diagnostic continuations of unfinished session50 worlds, not a fresh strength benchmark.
## Snapshots lack RNG state: both variants restart with the same explicit seed/UID, not the original stream.
## --townless=7 plays the continuation under the optional seven-day rule.
## --before=res://tools/ai/adventure_ai_session51.gd selects the "before" policy (default: frozen f69ad3a, session49);
## the other seats keep the worlds' original 4f126ec opponent either way.
const Driver = preload("res://tools/ai/campaign_driver.gd")
const Opponent = preload("res://tools/ai/adventure_ai_checkpoint.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := "shots/session50/states168"
	var days := 28
	var only_case := ""
	var trace_path := ""
	var before_path := "res://tools/ai/adventure_ai_session49.gd"
	var townless := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="): directory = arg.substr(6)
		if arg.begins_with("--days="): days = int(arg.substr(7))
		if arg.begins_with("--case="): only_case = arg.substr(7)
		if arg.begins_with("--trace="): trace_path = arg.substr(8)
		if arg.begins_with("--before="): before_path = arg.substr(9)
		if arg.begins_with("--townless="): townless = int(arg.substr(11))  # (the optional seven-day rule)
	var Before = load(before_path)
	print("CAMPAIGN RESUME: before policy ", before_path)
	var names := DirAccess.get_files_at(directory)
	names.sort()
	var driver := Driver.new()
	add_child(driver)
	if trace_path != "":
		driver.trace = FileAccess.open(trace_path, FileAccess.WRITE)
		if driver.trace == null:
			push_error("Cannot open continuation trace")
			get_tree().quit(1)
			return
	var played := 0
	for name in names:
		if not name.ends_with(".dat"): continue
		if only_case != "" and name != only_case: continue
		var file := FileAccess.open(directory.path_join(name), FileAccess.READ)
		var original: Dictionary = file.get_var()
		if original["players"].filter(func(p): return p["alive"]).size() <= 1: continue
		var side := int(name.get_basename().get_slice("_", 1))
		for variant in 2:
			var w := original.duplicate(true)
			w["townless_limit"] = townless
			GameState._uid = 1000
			for key in ["heroes", "towns", "objects"]:
				for uid in w[key]: GameState._uid = maxi(GameState._uid, uid)
			driver.configure(w)
			driver.run_label = name.get_basename() + ("/current" if variant else "/before")
			var policies: Array = []
			for p in w["players"]:
				p["is_ai"] = true
				policies.append(Opponent.new(driver.rules))
			policies[side] = AdvAI.new(driver.rules) if variant else Before.new(driver.rules)
			seed(51000 + int(name.get_slice("_", 0)))
			for day in days:
				for p in w["players"]:
					if not p["alive"]: continue
					w["current_player"] = p["index"]
					driver.ai = policies[p["index"]]
					await driver.ai.run_turn(driver, p)
					driver.record_turn(p)
				if w["players"].filter(func(p): return p["alive"]).size() <= 1: break
				driver.rules.new_day()
			var largest := 0
			for hid in w["players"][side]["heroes"]:
				largest = maxi(largest, GameState.army_strength(w["heroes"][hid]["army"]))
			print("RESUME %s policy=%s day=%d alive=%s towns=%s largest_army=%d" % [name,
				"current" if variant else "before", w["day"], w["players"].map(func(p): return p["alive"]),
				w["players"].map(func(p): return p["towns"].size()), largest])
			played += 1
		await get_tree().process_frame
	print("CAMPAIGN RESUME: %d diagnostic games" % played)
	driver.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if played > 0 else 1)
