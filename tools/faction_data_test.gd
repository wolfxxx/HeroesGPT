extends Node
## Faction data (docs/FOUNDATIONS_AUDIT.md, step 1): every faction is one complete GameData.FACTIONS record, its
## classes, heroes and special buildings agree with it, and the rules read the effects from the data (the Stables'
## movement, the Chapter House's siege morale, the Amplifier's necromancy, the Transformer's creature).
##   Godot_console.exe --headless --path . res://tools/faction_data_test.tscn  -> "FACTION DATA TEST: N checks, failures: 0"

var checks := 0
var failures := 0

func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)

func _ready() -> void:
	for f in GameData.FACTIONS:
		var d: Dictionary = GameData.FACTIONS[f]
		for k in ["name", "desc", "creatures", "upgrades", "terrain", "smith_machine", "specials", "requires",
				"dwelling_names", "town_names", "classes"]:
			_ok(d.has(k), "%s has %s" % [f, k])
		_ok(d["creatures"].size() == 7 and d["upgrades"].size() == 7 and d["dwelling_names"].size() == 7,
			"%s: seven tiers of creatures, upgrades and dwellings" % f)
		for i in 7:
			var c: Dictionary = GameData.CREATURES.get(d["creatures"][i], {})
			var u: Dictionary = GameData.CREATURES.get(d["upgrades"][i], {})
			_ok(c.get("faction", "") == f and c.get("tier", 0) == i + 1, "%s tier %d creature" % [f, i + 1])
			_ok(u.get("upgrade_of", "") == d["creatures"][i], "%s tier %d upgrade" % [f, i + 1])
		_ok(d["smith_machine"] in GameData.WAR_MACHINES, "%s smith forges a war machine" % f)
		_ok(not d["town_names"].is_empty(), "%s has town names" % f)
		_ok(GameData.TERRAINS.has(d["terrain"]), "%s native terrain exists" % f)
		for s in d["specials"]:
			_ok(GameData.BUILDINGS.get(s, {}).get("faction", "") == f, "%s special %s is its own" % [f, s])
		for b in d["requires"]:
			for r in d["requires"][b]:
				_ok(GameData.BUILDINGS.has(b) and GameData.BUILDINGS.has(r), "%s requirement %s -> %s exists" % [f, b, r])
		var kinds := []
		for cls in d["classes"]:
			var cd: Dictionary = GameData.CLASSES.get(cls, {})
			_ok(cd.get("faction", "") == f, "%s class %s belongs to it" % [f, cls])
			_ok(cd.get("machine", "") in GameData.WAR_MACHINES, "class %s starts with a war machine" % cls)
			kinds.append(cd.get("might", false))
		_ok(kinds == [true, false], "%s: a might class, then a magic class" % f)
	for hid in GameData.HEROES:
		var h: Dictionary = GameData.HEROES[hid]
		_ok(h["class"] in GameData.FACTIONS[h["faction"]]["classes"], "%s's class is one of their faction's" % hid)
	for b in GameData.BUILDINGS:
		var after: String = GameData.BUILDINGS[b].get("ai_after", "")
		_ok(after == "" or after in AdvAI.BUILD_ORDER, "%s is built after a building on the computer's list" % b)

	# the computer's build order is the one it had before the data move (session67), specials in their places
	var old := ["tavern", "dwelling_1", "dwelling_2", "town_hall", "dwelling_3", "fort", "mage_guild_1",
		"dwelling_4", "marketplace", "citadel", "blacksmith", "dwelling_5", "city_hall", "stables", "dwelling_6", "mage_guild_2",
		"brotherhood", "necromancy_amplifier", "dwelling_7", "castle", "dwelling_1u", "dwelling_2u", "dwelling_3u", "dwelling_4u",
		"capitol", "mage_guild_3", "dwelling_5u", "dwelling_6u", "dwelling_7u", "mage_guild_4"]
	_ok(AdvAI.build_order("haven") == old.filter(func(b): return b != "necromancy_amplifier"), "the Temple's build order")
	_ok(AdvAI.build_order("necropolis") == old.filter(func(b): return not b in ["stables", "brotherhood"]), "the Lodge's build order")

	# the rules read the effects
	var t := TownLogic.make_town("haven", 0, Vector2i.ZERO, "Rosslyn", true)
	_ok(TownLogic.effect(t, "start_day_movement") == 0 and TownLogic.effect(t, "siege_morale") == 0, "no specials, no effects")
	t["buildings"].append_array(["stables", "brotherhood"])
	_ok(TownLogic.effect(t, "start_day_movement") == 400, "the Stables give 400 movement")
	_ok(TownLogic.effect(t, "siege_morale") == 2, "the Chapter House gives the defenders +2 morale")
	var n := TownLogic.make_town("necropolis", 0, Vector2i.ZERO, "Blackfen", true)
	n["buildings"].append_array(["necromancy_amplifier", "skeleton_transformer"])
	_ok(TownLogic.effect(n, "necromancy") == 10, "the Amplifier adds 10% necromancy")
	_ok(TownLogic.transform_creature(n) == "skeleton" and TownLogic.transform_creature(t) == "", "only the Transformer transforms")
	var st := {"id": "pikeman", "count": 5}
	_ok(TownLogic.transform_stack(st, "skeleton") and st["id"] == "skeleton", "living creatures become Skeletons")
	_ok(not TownLogic.transform_stack({"id": "ghost", "count": 5}, "skeleton"), "undead are not transformed")
	_ok(GameState.starting_machines("Knight") == ["ballista"] and GameState.starting_machines("Necromancer") == ["first_aid_tent"],
		"classes start with their machine")
	_ok(GameData.upgrade_of_base(GameData.SKILLS["necromancy"]["raise"]["creature"]) == "skeleton_warrior", "necromancy raises Skeletons")
	print("FACTION DATA TEST: %d checks, failures: %d" % [checks, failures])
	get_tree().quit()
