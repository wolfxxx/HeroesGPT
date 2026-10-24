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
	print("COMMANDS TEST: %d checks, failures: %d" % [checks, failures])
	get_tree().quit()
