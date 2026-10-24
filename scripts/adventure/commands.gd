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
## Armies are named by reference: {"hero": uid} (its army) or {"town": uid} (its garrison). Two armies must stand
## together: the same army, a hero and a town it stands in (at the gate or in the garrison), or two heroes side by side.
##   stack_move    {p, from, si, to, ti, split: bool, swap: bool}
##                                                      the army bar's move: into an empty slot (or half of it, split),
##                                                      onto the same creature (merge) or another (swap; `swap` swaps
##                                                      two stacks of the same creature too); a hero's army is never
##                                                      emptied into another army
##   move_troops   {p, from, si, to, n}                 n creatures of a stack join the other army (its stack of that
##                                                      creature, else its first free slot)
##   upgrade_stack {p, town: uid, army, si}             in a town with the upgraded dwelling, at the upgrade price
## (Hero movement, the turn, building and garrison moves follow, docs/FOUNDATIONS_AUDIT.md.)

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
		"stack_move":
			return _stack_move(rules, player, cmd)
		"move_troops":
			return _move_troops(rules, player, cmd)
		"upgrade_stack":
			return _upgrade_stack(rules, player, cmd)
	return _no("Unknown command.")

## The army an army reference names, if the player owns it ([] otherwise).
static func army_of(rules: AdvRules, player: Dictionary, ref) -> Array:
	if not ref is Dictionary:
		return []
	if ref.has("hero"):
		var h: Dictionary = rules.world["heroes"].get(int(ref["hero"]), {})
		return h["army"] if not h.is_empty() and h["owner"] == player["index"] else []
	if ref.has("town"):
		var t: Dictionary = rules.world["towns"].get(int(ref["town"]), {})
		return t["garrison"] if not t.is_empty() and t["owner"] == player["index"] else []
	return []

static func _pos_of(rules: AdvRules, ref: Dictionary) -> Vector2i:
	var o: Dictionary = rules.world["heroes" if ref.has("hero") else "towns"].get(int(ref.get("hero", ref.get("town", -1))), {})
	return o.get("pos", Vector2i(-99, -99))

## Can these two armies exchange troops: the same army, a hero and a town it stands in, or two heroes side by side?
static func together(rules: AdvRules, a: Dictionary, b: Dictionary) -> bool:
	if a.has("town") and b.has("town"):
		return int(a["town"]) == int(b["town"])
	var d: Vector2i = _pos_of(rules, a) - _pos_of(rules, b)
	if a.has("hero") and b.has("hero"):
		return maxi(absi(d.x), absi(d.y)) <= 1
	return d == Vector2i.ZERO

static func _two_armies(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Array:
	var src := army_of(rules, player, cmd.get("from"))
	var dst := army_of(rules, player, cmd.get("to"))
	if src.is_empty() or dst.is_empty() or not together(rules, cmd["from"], cmd["to"]):
		return []
	return [src, dst]

static func _stack_count(army: Array) -> int:
	return army.filter(func(s): return s != null).size()

static func _stack_move(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var ab := _two_armies(rules, player, cmd)
	if ab.is_empty():
		return _no("Those armies are not together.")
	var src: Array = ab[0]
	var dst: Array = ab[1]
	var si := int(cmd.get("si", -1))
	var ti := int(cmd.get("ti", -1))
	if si < 0 or si > 6 or ti < 0 or ti > 6 or src[si] == null:
		return _no("No such stack.")
	var same := is_same(src, dst) and si == ti
	if same:
		return _no("No such stack.")
	var a: Dictionary = src[si]
	var b = dst[ti]
	# a hero's army keeps at least one stack: it cannot be moved or merged away whole into another army
	var keeps: bool = cmd["from"].has("hero") and not is_same(src, dst) and _stack_count(src) <= 1
	if b == null:
		if cmd.get("split", false) and a["count"] > 1:
			var half: int = a["count"] / 2
			a["count"] -= half
			dst[ti] = {"id": a["id"], "count": half}
		else:
			if keeps:
				return _no("A hero cannot give away the last stack.")
			dst[ti] = a
			src[si] = null
	elif b["id"] == a["id"] and not cmd.get("swap", false):
		if keeps:
			return _no("A hero cannot give away the last stack.")
		b["count"] += a["count"]
		src[si] = null
	else:
		dst[ti] = a
		src[si] = b
	return {"ok": true, "reason": ""}

static func _move_troops(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var ab := _two_armies(rules, player, cmd)
	if ab.is_empty():
		return _no("Those armies are not together.")
	var src: Array = ab[0]
	var dst: Array = ab[1]
	var si := int(cmd.get("si", -1))
	var n := int(cmd.get("n", 0))
	if si < 0 or si > 6 or src[si] == null or n <= 0 or n > int(src[si]["count"]) or is_same(src, dst):
		return _no("No such troops.")
	if cmd["from"].has("hero") and n == int(src[si]["count"]) and _stack_count(src) <= 1:
		return _no("A hero cannot give away the last stack.")
	if not GameState.add_to_army(dst, src[si]["id"], n):
		return _no("No room in the army.")
	src[si]["count"] -= n
	if src[si]["count"] == 0:
		src[si] = null
	return {"ok": true, "reason": ""}

static func _upgrade_stack(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var town: Dictionary = rules.world["towns"].get(int(cmd.get("town", -1)), {})
	var army := army_of(rules, player, cmd.get("army"))
	var si := int(cmd.get("si", -1))
	if town.is_empty() or town["owner"] != player["index"] or army.is_empty() or si < 0 or si > 6 or army[si] == null:
		return _no("No such stack.")
	if not together(rules, cmd["army"], {"town": town["uid"]}):
		return _no("The army is not in the town.")
	if not TownLogic.upgrade_stack(town, player, army[si]):
		return _no("Cannot upgrade that stack here.")
	return {"ok": true, "reason": ""}

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
