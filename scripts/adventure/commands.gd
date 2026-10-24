extends RefCounted
class_name Commands
## The command layer (docs/FOUNDATIONS_AUDIT.md, step 2): every action a player takes, by a person at a screen or by
## the computer, is a plain dictionary handed to AdvRules.do(cmd), which checks it against the rules, applies it and
## reports what happened. Commands hold only ids, numbers and strings, so they can be saved, replayed or sent over a
## network to a host that runs the game. Screens choose and show; the computer chooses; only commands change the world.
##
## Each command names its player ("p": player index). The result is {"ok": bool, "reason": String, ...}.
##   recruit_town  {p, town: uid, tier: 1-7, n, into: "town" (its army: a garrison hero's, else the garrison) | "garrison"}
##   recruit_site  {p, hero: uid, object: uid, n}       a map dwelling, into the visiting hero's army
##   hire          {p, town: uid, hero_id}              a Tavern hero to the town's gate -> "hero": uid
##   trade         {p, give, get, n}                    at the market rate (TownLogic.market_rate) -> "got"
## (So far the town and dwelling actions; hero movement, stack moves and the turn follow, docs/FOUNDATIONS_AUDIT.md.)

const HIRE_COST := 2500

static func run(rules: AdvRules, cmd: Dictionary) -> Dictionary:
	var w: Dictionary = rules.world
	var pi: int = int(cmd.get("p", -1))
	if pi < 0 or pi >= w["players"].size():
		return _no("No such player.")
	var player: Dictionary = w["players"][pi]
	match cmd.get("t", ""):
		"recruit_town":
			return _recruit_town(rules, player, cmd)
		"recruit_site":
			return _recruit_site(rules, player, cmd)
		"hire":
			return _hire(rules, player, cmd)
		"trade":
			return _trade(player, cmd)
	return _no("Unknown command.")

static func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func _recruit_town(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var town: Dictionary = rules.world["towns"].get(int(cmd.get("town", -1)), {})
	if town.is_empty() or town["owner"] != player["index"]:
		return _no("Not your town.")
	var tier := int(cmd.get("tier", 0))
	var n := int(cmd.get("n", 0))
	if tier < 1 or tier > 7 or not TownLogic.has_building(town, "dwelling_%d" % tier):
		return _no("No such dwelling.")
	var army: Array = town["garrison"] if cmd.get("into", "town") == "garrison" else rules.town_army(town)
	if not TownLogic.recruit(town, player, tier, n, army):
		return _no("Cannot recruit that many.")
	return {"ok": true, "reason": "", "n": n, "creature": TownLogic.dwelling_creature(town, tier)}

static func _recruit_site(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero: Dictionary = rules.world["heroes"].get(int(cmd.get("hero", -1)), {})
	var o: Dictionary = rules.world["objects"].get(int(cmd.get("object", -1)), {})
	if hero.is_empty() or hero["owner"] != player["index"]:
		return _no("Not your hero.")
	if o.is_empty() or o["type"] != "dwelling":
		return _no("No such dwelling.")
	var n := int(cmd.get("n", 0))
	var c: Dictionary = GameData.CREATURES[o["creature"]]
	if n <= 0 or n > int(o["available"]) or not TownLogic.can_afford(player, c["cost"], n):
		return _no("Cannot recruit that many.")
	if not GameState.add_to_army(hero["army"], o["creature"], n):
		return _no("No room in the army.")
	TownLogic.pay(player, c["cost"], n)
	o["available"] -= n
	return {"ok": true, "reason": "", "n": n, "creature": o["creature"]}

static func _hire(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var w: Dictionary = rules.world
	var town: Dictionary = w["towns"].get(int(cmd.get("town", -1)), {})
	var hid: String = cmd.get("hero_id", "")
	if town.is_empty() or town["owner"] != player["index"]:
		return _no("Not your town.")
	if not TownLogic.has_building(town, "tavern"):
		return _no("The town has no Tavern.")
	if not hid in w["tavern"]:
		return _no("That hero is not in the taverns.")
	for hh in w["heroes"].values():  # (the garrison hero waits inside: the gate is free)
		if hh["pos"] == town["pos"] and not hh.get("in_town", false):
			return _no("A hero is already standing at the town gate.")
	if player["resources"]["gold"] < HIRE_COST:
		return _no("Not enough gold.")
	w["tavern"].erase(hid)
	player["resources"]["gold"] -= HIRE_COST
	var hero := GameState.tavern_hero(hid, player["index"])
	hero["pos"] = town["pos"]
	w["heroes"][hero["uid"]] = hero
	player["heroes"].append(hero["uid"])
	return {"ok": true, "reason": "", "hero": hero["uid"]}

static func _trade(player: Dictionary, cmd: Dictionary) -> Dictionary:
	var give: String = cmd.get("give", "")
	var get_r: String = cmd.get("get", "")
	var n := int(cmd.get("n", 0))
	if not give in GameData.RESOURCES or not get_r in GameData.RESOURCES or give == get_r:
		return _no("Pick two different resources.")
	if n <= 0 or player["resources"].get(give, 0) < n:
		return _no("Not enough to trade.")
	var got := int(n * TownLogic.market_rate(give, get_r))
	player["resources"][give] -= n
	player["resources"][get_r] = player["resources"].get(get_r, 0) + got
	return {"ok": true, "reason": "", "got": got}
