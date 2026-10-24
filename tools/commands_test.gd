extends Node
## The command layer (scripts/adventure/commands.gd): each command checks the rules, applies itself and reports, and
## survives a round trip through JSON (as it would over a network: numbers come back as floats).
##   Godot_console.exe --headless --path . res://tools/commands_test.tscn  -> "COMMANDS TEST: N checks, failures: 0"

var checks := 0
var failures := 0

func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)

## Sends a command the way a network would: through JSON.
func _do(rules: AdvRules, cmd: Dictionary) -> Dictionary:
	return rules.do(JSON.parse_string(JSON.stringify(cmd)))

func _ready() -> void:
	var s := GameState.new_game_settings.duplicate()
	s["seed"] = 12345
	var w := WorldGen.generate(s)
	GameState.world = w
	var rules := AdvRules.new(w)
	var me: Dictionary = w["players"][0]
	var town: Dictionary = w["towns"][me["towns"][0]]
	var foe_town: Dictionary = w["towns"][w["players"][1]["towns"][0]]

	# recruit in a town
	town["available"][0] = 10
	var gold: int = me["resources"]["gold"]
	var cid := TownLogic.dwelling_creature(town, 1)
	var price: int = GameData.CREATURES[cid]["cost"]["gold"]
	var r := _do(rules, {"t": "recruit_town", "p": 0, "town": town["uid"], "tier": 1, "n": 4, "into": "garrison"})
	_ok(r["ok"] and r["n"] == 4 and town["available"][0] == 6 and me["resources"]["gold"] == gold - 4 * price,
		"recruiting 4 pays for them and takes them from the dwelling")
	var found := false
	for st in town["garrison"]:
		found = found or (st != null and st["id"] == cid and st["count"] >= 4)
	_ok(found, "and they stand in the garrison")
	_ok(not _do(rules, {"t": "recruit_town", "p": 0, "town": town["uid"], "tier": 1, "n": 7})["ok"], "not more than are available")
	_ok(not _do(rules, {"t": "recruit_town", "p": 1, "town": town["uid"], "tier": 1, "n": 1})["ok"], "not in another player's town")
	_ok(not _do(rules, {"t": "recruit_town", "p": 0, "town": foe_town["uid"], "tier": 1, "n": 1})["ok"], "not in an enemy town")
	_ok(not _do(rules, {"t": "recruit_town", "p": 0, "town": town["uid"], "tier": 7, "n": 1})["ok"], "not from a dwelling not built")
	me["resources"]["gold"] = 0
	_ok(not _do(rules, {"t": "recruit_town", "p": 0, "town": town["uid"], "tier": 1, "n": 1})["ok"], "not without the gold")
	me["resources"]["gold"] = 20000

	# hire at the Tavern
	if not TownLogic.has_building(town, "tavern"):
		town["buildings"].append("tavern")
	for h in w["heroes"].values():  # (an empty gate)
		if h["pos"] == town["pos"]:
			h["pos"] += Vector2i(0, 2)
	rules.rebuild()
	var hid: String = w["tavern"][0]
	var nheroes: int = me["heroes"].size()
	r = _do(rules, {"t": "hire", "p": 0, "town": town["uid"], "hero_id": hid})
	_ok(r["ok"] and me["heroes"].size() == nheroes + 1 and not hid in w["tavern"] and me["resources"]["gold"] == 17500,
		"hiring takes the hero from the taverns for 2500 gold")
	_ok(w["heroes"][int(r["hero"])]["pos"] == town["pos"], "to the town's gate")
	_ok(not _do(rules, {"t": "hire", "p": 0, "town": town["uid"], "hero_id": w["tavern"][0]})["ok"], "not with a hero at the gate")
	_ok(not _do(rules, {"t": "hire", "p": 0, "town": town["uid"], "hero_id": "no_such_hero"})["ok"], "not a hero outside the taverns")

	# a map dwelling
	var o := {}
	for x in w["objects"].values():
		if x["type"] == "dwelling" and x["creature"] != "mummy":
			o = x
			break
	var h: Dictionary = w["heroes"][int(r["hero"])]
	o["available"] = 5
	r = _do(rules, {"t": "recruit_site", "p": 0, "hero": h["uid"], "object": o["uid"], "n": 3})
	_ok(r["ok"] and o["available"] == 2, "recruiting at a map dwelling")
	_ok(not _do(rules, {"t": "recruit_site", "p": 1, "hero": h["uid"], "object": o["uid"], "n": 1})["ok"], "not with another player's hero")

	# the market
	me["resources"]["wood"] = 10
	gold = me["resources"]["gold"]
	r = _do(rules, {"t": "trade", "p": 0, "give": "wood", "get": "gold", "n": 4})
	_ok(r["ok"] and me["resources"]["wood"] == 6 and me["resources"]["gold"] == gold + int(4 * TownLogic.market_rate("wood", "gold")),
		"trading 4 wood for gold at the market rate")
	_ok(not _do(rules, {"t": "trade", "p": 0, "give": "wood", "get": "gold", "n": 50})["ok"], "not more than you have")
	_ok(not _do(rules, {"t": "trade", "p": 0, "give": "wood", "get": "wood", "n": 1})["ok"], "not a resource for itself")
	_ok(not rules.do({"t": "no_such_command", "p": 0})["ok"] and not rules.do({"t": "trade", "p": 9})["ok"], "unknown commands and players refused")
	_stacks(w, rules, town, h)
	_steps(w, rules, h)
	_meetings()
	_the_rest()
	print("COMMANDS TEST: %d checks, failures: %d" % [checks, failures])
	get_tree().quit()

## A hero's step: to a neighbouring free tile, paying the planner's cost and seeing around it; never two tiles at
## once, onto a monster, past the movement left or for another player. The turn passes to the next living player, and a
## new day begins when the round ends.
func _steps(w: Dictionary, rules: AdvRules, h: Dictionary) -> void:
	rules.rebuild()
	var start: Vector2i = h["pos"]
	var to := Vector2i(-1, -1)
	for d in AdvRules.DIRS:
		var q: Vector2i = start + d
		if rules.walkable_ground(q) and rules.at(q).is_empty():
			to = q
			break
	h["movement"] = 1500
	var cost := rules.step_cost(start, to)
	_ok(_do(rules, {"t": "step", "p": 0, "hero": h["uid"], "to": [to.x, to.y]})["ok"] and h["pos"] == to and h["movement"] == 1500 - cost,
		"a step to a free neighbour pays its cost")
	_ok(rules.hero_at(to) == h and rules.hero_at(start).is_empty(), "and the map knows where the hero stands")
	var far: Vector2i = to + Vector2i(2, 0)
	_ok(not _do(rules, {"t": "step", "p": 0, "hero": h["uid"], "to": [far.x, far.y]})["ok"], "not two tiles at once")
	_ok(not _do(rules, {"t": "step", "p": 1, "hero": h["uid"], "to": [start.x, start.y]})["ok"], "not another player's hero")
	h["movement"] = 10
	_ok(not _do(rules, {"t": "step", "p": 0, "hero": h["uid"], "to": [start.x, start.y]})["ok"] and h["pos"] == to, "not past the movement left")
	h["movement"] = 1500
	var m := {}
	for o in w["objects"].values():
		if o["type"] == "monster":
			m = o
			break
	h["pos"] = m["pos"] + Vector2i(1, 0)
	rules.rebuild()
	_ok(not _do(rules, {"t": "step", "p": 0, "hero": h["uid"], "to": [m["pos"].x, m["pos"].y]})["ok"], "not onto a monster (that is a fight)")
	# the turn
	w["current_player"] = 0
	var day: int = w["day"]
	_ok(not _do(rules, {"t": "end_turn", "p": 1})["ok"], "only the player whose turn it is ends it")
	var r := _do(rules, {"t": "end_turn", "p": 0})
	_ok(r["ok"] and int(r["next"]) == 1 and w["current_player"] == 1 and w["day"] == day and r["day"].is_empty(), "the next player's turn, the same day")
	for i in range(1, w["players"].size()):
		r = _do(rules, {"t": "end_turn", "p": w["current_player"]})
	_ok(w["current_player"] == 0 and w["day"] == day + 1 and r["day"].has("new_week"), "after the last player, a new day")

## Stack moves between armies that stand together: the army bar's move, merge, split and swap, the computer's troop
## moves, a hero's last stack kept, and stack upgrades in a town.
func _stacks(w: Dictionary, rules: AdvRules, town: Dictionary, h: Dictionary) -> void:
	var hr := {"hero": h["uid"]}
	var tr := {"town": town["uid"]}
	h["pos"] = town["pos"]
	h["army"] = [{"id": "pikeman", "count": 10}, {"id": "archer", "count": 6}, null, null, null, null, null]
	town["garrison"] = [{"id": "pikeman", "count": 4}, null, {"id": "griffin", "count": 2}, null, null, null, null]
	var mv := func(cmd: Dictionary) -> bool:
		cmd["p"] = 0
		return _do(rules, cmd)["ok"]
	_ok(mv.call({"t": "stack_move", "from": hr, "si": 0, "to": tr, "ti": 0}) and town["garrison"][0]["count"] == 14 and h["army"][0] == null,
		"onto the same creature: the stacks merge")
	_ok(mv.call({"t": "stack_move", "from": tr, "si": 2, "to": hr, "ti": 0}) and h["army"][0]["id"] == "griffin" and town["garrison"][2] == null,
		"into an empty slot: the stack moves")
	_ok(mv.call({"t": "stack_move", "from": hr, "si": 1, "to": tr, "ti": 3, "split": true}) and h["army"][1]["count"] == 3 and town["garrison"][3]["count"] == 3,
		"shift: half of it splits off")
	_ok(mv.call({"t": "stack_move", "from": hr, "si": 0, "to": tr, "ti": 0}) and h["army"][0]["id"] == "pikeman" and town["garrison"][0]["id"] == "griffin",
		"onto another creature: the stacks swap")
	_ok(mv.call({"t": "stack_move", "from": hr, "si": 1, "to": tr, "ti": 3, "swap": true}) and h["army"][1]["count"] == 3 and town["garrison"][3]["count"] == 3,
		"`swap` swaps two stacks of the same creature")
	_ok(mv.call({"t": "move_troops", "from": tr, "si": 0, "to": hr, "n": 1}) and town["garrison"][0]["count"] == 1 and h["army"][2]["id"] == "griffin",
		"move_troops: one Griffin joins the hero's first free slot")
	_ok(mv.call({"t": "move_troops", "from": tr, "si": 0, "to": hr, "n": 1}) and town["garrison"][0] == null and h["army"][2]["count"] == 2,
		"and the last one merges into that stack, emptying the garrison slot")
	h["army"] = [{"id": "pikeman", "count": 5}, null, null, null, null, null, null]
	_ok(not mv.call({"t": "stack_move", "from": hr, "si": 0, "to": tr, "ti": 5}), "a hero's last stack cannot be moved away")
	_ok(not mv.call({"t": "move_troops", "from": hr, "si": 0, "to": tr, "n": 5}), "nor all of it as troops")
	_ok(mv.call({"t": "move_troops", "from": hr, "si": 0, "to": tr, "n": 4}) and h["army"][0]["count"] == 1, "all but one may go")
	h["pos"] = town["pos"] + Vector2i(3, 0)
	_ok(not mv.call({"t": "stack_move", "from": tr, "si": 1, "to": hr, "ti": 1}), "not between a town and a hero who is not in it")
	var foe: Dictionary = w["heroes"][w["players"][1]["heroes"][0]]
	_ok(not mv.call({"t": "move_troops", "from": {"hero": foe["uid"]}, "si": 0, "to": hr, "n": 1}), "not from another player's army")
	# upgrades: a base stack in a town with the upgraded dwelling, paid for
	h["pos"] = town["pos"]
	if not TownLogic.has_building(town, "dwelling_1u"):
		town["buildings"].append("dwelling_1u")
	w["players"][0]["resources"]["gold"] = 20000
	var base := TownLogic.dwelling_creature(town, 1)
	h["army"][0] = {"id": GameData.base_of(base), "count": 3}
	_ok(mv.call({"t": "upgrade_stack", "town": town["uid"], "army": hr, "si": 0}) and h["army"][0]["id"] == GameData.upgrade_of_base(GameData.base_of(base)),
		"a stack upgrades in the town")
	_ok(not mv.call({"t": "upgrade_stack", "town": town["uid"], "army": hr, "si": 0}), "but not twice")

## What a hero meets: a site visited only by a hero standing on it (a monster is a fight), a chest's gold or
## experience taken from the offer the visit kept (not one the caller names), an undefended town captured only from its
## gate, a battle's result applied only on its player's turn.
func _meetings() -> void:
	var s := GameState.new_game_settings.duplicate()
	s["seed"] = 4242
	var w := WorldGen.generate(s)
	GameState.world = w
	var rules := AdvRules.new(w)
	var me: Dictionary = w["players"][0]
	var h: Dictionary = w["heroes"][me["heroes"][0]]
	var chest := {}
	var mon := {}
	for o in w["objects"].values():
		if o["type"] == "chest" and chest.is_empty(): chest = o
		if o["type"] == "monster" and mon.is_empty(): mon = o
	_ok(not _do(rules, {"t": "visit", "p": 0, "hero": h["uid"], "object": chest["uid"]})["ok"], "not a site the hero is not on")
	h["pos"] = chest["pos"]
	rules.rebuild()
	var r := _do(rules, {"t": "visit", "p": 0, "hero": h["uid"], "object": chest["uid"]})
	_ok(r["ok"] and r["event"].has("choice") and not w["objects"].has(chest["uid"]), "visiting a chest opens it and offers a choice")
	var gold: int = me["resources"]["gold"]
	_ok(not _do(rules, {"t": "chest", "p": 0, "hero": h["uid"], "choice": "jewels"})["ok"], "gold or experience only")
	r = _do(rules, {"t": "chest", "p": 0, "hero": h["uid"], "choice": "gold", "gold": 999999})
	_ok(r["ok"] and me["resources"]["gold"] == gold + int(chest["gold"]), "the chest's own gold, whatever the caller says")
	_ok(not _do(rules, {"t": "chest", "p": 0, "hero": h["uid"], "choice": "gold"})["ok"], "and only once")
	h["pos"] = mon["pos"]
	_ok(not _do(rules, {"t": "visit", "p": 0, "hero": h["uid"], "object": mon["uid"]})["ok"], "a monster is not visited: it is fought")
	# capture: an enemy town with no garrison and no defender, from its gate
	var t: Dictionary = w["towns"][w["players"][1]["towns"][0]]
	for i in 7: t["garrison"][i] = null
	for hid in w["players"][1]["heroes"].duplicate():
		if w["heroes"][hid]["pos"] == t["pos"]: w["heroes"][hid]["pos"] += Vector2i(0, 3)
	_ok(not _do(rules, {"t": "capture", "p": 0, "hero": h["uid"], "town": t["uid"]})["ok"], "not a town the hero is not at")
	h["pos"] = t["pos"]
	rules.rebuild()
	_ok(_do(rules, {"t": "capture", "p": 0, "hero": h["uid"], "town": t["uid"]})["ok"] and t["owner"] == 0, "an undefended town is taken")
	_ok(not _do(rules, {"t": "capture", "p": 0, "hero": h["uid"], "town": t["uid"]})["ok"], "but not twice")
	# a battle's result, on its player's turn
	w["current_player"] = 0
	_ok(not rules.do({"t": "battle_result", "p": 1, "result": {"winner": "attacker"}})["ok"], "not out of turn")
	_ok(not rules.do({"t": "battle_result", "p": 0, "result": "won"})["ok"], "not without a result")

## Building, the garrison, artifacts, war machines, the Transformer and level-ups: each checked by the rules, and a
## level's skill only one of those the rules rolled.
func _the_rest() -> void:
	var s := GameState.new_game_settings.duplicate()
	s["seed"] = 777
	s["faction"] = "necropolis"
	var w := WorldGen.generate(s)
	GameState.world = w
	var rules := AdvRules.new(w)
	var me: Dictionary = w["players"][0]
	me["resources"] = {"gold": 50000, "wood": 50, "ore": 50, "mercury": 50, "sulfur": 50, "crystal": 50, "gems": 50}
	var town: Dictionary = w["towns"][me["towns"][0]]
	var h: Dictionary = w["heroes"][me["heroes"][0]]
	h["pos"] = town["pos"]
	rules.rebuild()
	# build
	town["built_today"] = false
	_ok(_do(rules, {"t": "build", "p": 0, "town": town["uid"], "building": "blacksmith"})["ok"] and "blacksmith" in town["buildings"], "building a Blacksmith")
	_ok(not _do(rules, {"t": "build", "p": 0, "town": town["uid"], "building": "marketplace"})["ok"], "but only one building a day")
	_ok(not _do(rules, {"t": "build", "p": 1, "town": town["uid"], "building": "marketplace"})["ok"], "and not in another player's town")
	# the town's own war machine at its Blacksmith
	h["machines"] = []
	_ok(not _do(rules, {"t": "buy_machine", "p": 0, "hero": h["uid"], "machine": "ballista", "town": town["uid"]})["ok"], "the Order's smith forges no ballista")
	_ok(_do(rules, {"t": "buy_machine", "p": 0, "hero": h["uid"], "machine": "first_aid_tent", "town": town["uid"]})["ok"] and "first_aid_tent" in h["machines"], "its first aid tent")
	# the garrison
	_ok(_do(rules, {"t": "enter_garrison", "p": 0, "hero": h["uid"], "town": town["uid"]})["ok"] and h.get("in_town", false), "the hero goes into the garrison")
	_ok(_do(rules, {"t": "leave_garrison", "p": 0, "town": town["uid"]})["ok"] and not h.get("in_town", false), "and comes out again")
	_ok(not _do(rules, {"t": "leave_garrison", "p": 0, "town": town["uid"]})["ok"], "not twice")
	# the Transformer: a living stack in the town becomes Skeletons
	town["buildings"].append("skeleton_transformer")
	h["army"][1] = {"id": "pikeman", "count": 5}
	_ok(_do(rules, {"t": "transform", "p": 0, "town": town["uid"], "army": {"hero": h["uid"]}, "si": 1})["ok"] and h["army"][1]["id"] == "skeleton", "living creatures transformed")
	_ok(not _do(rules, {"t": "transform", "p": 0, "town": town["uid"], "army": {"hero": h["uid"]}, "si": 1})["ok"], "not the undead")
	# artifacts
	h["artifacts"] = []
	h["backpack"] = ["sword_of_valor"]
	_ok(_do(rules, {"t": "equip", "p": 0, "hero": h["uid"], "artifact": "sword_of_valor", "worn": false})["ok"] and "sword_of_valor" in h["artifacts"], "a carried artifact put on")
	_ok(_do(rules, {"t": "equip", "p": 0, "hero": h["uid"], "artifact": "sword_of_valor", "worn": true})["ok"] and "sword_of_valor" in h["backpack"], "and taken off")
	_ok(not _do(rules, {"t": "equip", "p": 0, "hero": h["uid"], "artifact": "crown_of_command", "worn": false})["ok"], "not one the hero lacks")
	for a in ["dragonbone_blade", "dragonscale_shield", "dragonskull_helm"]:
		GameState.give_artifact(h, a)
	_ok("dragonheart_arms" in h["artifacts"], "(the set merges as its pieces are worn)")
	_ok(_do(rules, {"t": "split_set", "p": 0, "hero": h["uid"], "artifact": "dragonheart_arms"})["ok"] and "dragonbone_blade" in h["artifacts"], "a set parted")
	_ok(_do(rules, {"t": "join_set", "p": 0, "hero": h["uid"], "artifact": "dragonheart_arms"})["ok"] and "dragonheart_arms" in h["artifacts"], "and joined again")
	var h2 := GameState.make_hero("vesna_nightshade", 0)
	h2["pos"] = h["pos"] + Vector2i(1, 0)
	w["heroes"][h2["uid"]] = h2
	me["heroes"].append(h2["uid"])
	_ok(_do(rules, {"t": "give_artifact", "p": 0, "hero": h["uid"], "to": h2["uid"], "artifact": "sword_of_valor"})["ok"] and "sword_of_valor" in h2["artifacts"] + h2["backpack"], "passed to the hero alongside")
	h2["pos"] = h["pos"] + Vector2i(5, 0)
	_ok(not _do(rules, {"t": "give_artifact", "p": 0, "hero": h2["uid"], "to": h["uid"], "artifact": "sword_of_valor"})["ok"], "not to a hero far away")
	# level-ups: the rules roll; the player picks one of what was rolled
	h["pending_levels"] = 1
	var r := _do(rules, {"t": "level_roll", "p": 0, "hero": h["uid"]})
	_ok(r["ok"] and r["stat"] in ["attack", "defense", "power", "knowledge"], "a level rolled")
	_ok(_do(rules, {"t": "level_roll", "p": 0, "hero": h["uid"]})["options"] == r["options"], "asking again shows the same offer")
	var stat_before: int = h[r["stat"]]
	if not r["options"].is_empty():
		_ok(not _do(rules, {"t": "level_up", "p": 0, "hero": h["uid"], "skill": "no_such_skill"})["ok"], "not a skill that was not offered")
	var pick: String = r["options"][0] if not r["options"].is_empty() else ""
	_ok(_do(rules, {"t": "level_up", "p": 0, "hero": h["uid"], "skill": pick})["ok"] and h[r["stat"]] == stat_before + 1 and int(h["pending_levels"]) == 0,
		"the level taken with an offered skill")
	_ok(not _do(rules, {"t": "level_up", "p": 0, "hero": h["uid"], "skill": pick})["ok"], "and only once")
	# the Mage Guild: built with a hero visiting, it teaches at once; a visit restores spell points
	town["built_today"] = false
	h["spells"] = []
	var mg := _do(rules, {"t": "build", "p": 0, "town": town["uid"], "building": "mage_guild_1"})
	_ok(mg["ok"] and not mg["learned"].is_empty() and h["spells"] == mg["learned"], "a new Mage Guild teaches the visiting hero")
	h["mana"] = 0
	var tv := _do(rules, {"t": "town_visit", "p": 0, "hero": h["uid"], "town": town["uid"]})
	_ok(tv["ok"] and h["mana"] == GameState.max_mana(h) and tv["mana"] == h["mana"], "a visit restores spell points")
	_ok(not _do(rules, {"t": "town_visit", "p": 0, "hero": h2["uid"], "town": town["uid"]})["ok"], "not for a hero outside the town")
	# the world's dice: kept in the world; a derived generator leaves them alone
	var st: int = w["rng"]
	Dice.derived(w, "a test").randi()
	_ok(w["rng"] == st, "a derived generator does not move the world's dice")
	var r1 := Dice.roll(w, 1, 1000000)
	_ok(w["rng"] != st, "a roll moves them")
	w["rng"] = st
	_ok(Dice.roll(w, 1, 1000000) == r1, "and from the same state rolls the same")
