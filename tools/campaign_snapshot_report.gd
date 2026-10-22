extends Node
## Diagnose final tournament snapshots without changing/saving a player's game.
## --dir=shots/session50/states168 --baseline=res://tools/ai/adventure_ai_checkpoint.gd

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := "shots/session50/states168"
	var baseline_path := "res://tools/ai/adventure_ai_checkpoint.gd"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="): directory = arg.substr(6)
		if arg.begins_with("--baseline="): baseline_path = arg.substr(11)
	var baseline = load(baseline_path)
	var names := DirAccess.get_files_at(directory)
	names.sort()
	for name in names:
		if not name.ends_with(".dat"): continue
		var file := FileAccess.open(directory.path_join(name), FileAccess.READ)
		var w: Dictionary = file.get_var()
		if w["players"].filter(func(p): return p["alive"]).size() <= 1: continue
		GameState.world = w
		var rules := AdvRules.new(w)
		var side := int(name.get_basename().get_slice("_", 1))
		print("SNAPSHOT ", name, " day=", w["day"])
		for t in w["towns"].values(): print("  town=", t["uid"], " owner=", t["owner"], " pos=", t["pos"])
		for p in w["players"]:
			if not p["alive"]: continue
			var ai: AdvAI = AdvAI.new(rules) if p["index"] == side else baseline.new(rules)
			print("  player=%d policy=%s towns=%d heroes=%d" % [p["index"], "current" if p["index"] == side else "checkpoint", p["towns"].size(), p["heroes"].size()])
			if p["index"] == side: print("    rally=", ai._assault_rally(p))
			for hid in p["heroes"]:
				var h: Dictionary = w["heroes"][hid]
				var defense := ai._defense(h)
				var plan := ai.choose(h)
				print("    hero=%d pos=%s strength=%.0f defense=%s target=%s" % [hid, h["pos"], ai._strength(h), "hold" if defense.has("hold") else ("move" if not defense.is_empty() else "none"), plan.get("kind", "none")])
				print("      army=", h["army"])
				if not plan.is_empty(): print("      target uid=", plan.get("target", {}).get("uid", -1), " destination=", plan["path"].back())
				if plan.has("yield"): print("      step aside: hero=", plan["yield"]["hero"], " destination=", plan["yield"]["plan"]["path"].back())
				var leader_uid := ai._leader(p)
				if leader_uid != hid:
					var leader: Dictionary = w["heroes"][leader_uid]
					var value := ai._transfer_value(leader, h["army"], true)
					var meeting := rules.plan(h, leader["pos"])
					print("      delivery value=%d unlocks assault=%s cost=%d" % [value, ai._unlocks_assault(leader, value), meeting["costs"].back() if not meeting["path"].is_empty() else -1])
				for t in w["towns"].values():
					if t["owner"] == p["index"]: continue
					var route := rules.plan(h, t["pos"])
					var resident := rules.town_defender(t, h)
					var danger := GameState.army_strength(t["garrison"]) * 1.25
					if not resident.is_empty(): danger += ai._strength(resident)
					print("      enemy town=%d path=%s cost=%d force ratio=%.2f (attack requires >1.40)" % [t["uid"], not route["path"].is_empty(), route["costs"].back() if not route["costs"].is_empty() else -1, ai._strength(h) / maxf(1, danger)])
					if route["path"].is_empty():
						var clear := w.duplicate(true)
						for other in p["heroes"]:
							if other != hid: clear["heroes"].erase(other)
						var unblocked := AdvRules.new(clear).plan(clear["heroes"][hid], t["pos"])
						print("        path without allied heroes=", not unblocked["path"].is_empty())
	GameState.world = {}
	get_tree().quit()
