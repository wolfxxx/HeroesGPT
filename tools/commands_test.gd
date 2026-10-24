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
	print("COMMANDS TEST: %d checks, failures: %d" % [checks, failures])
	get_tree().quit()
