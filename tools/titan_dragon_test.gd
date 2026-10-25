extends Node
## HoMM3's Giants and Titans, Red and Black Dragons (session67, neutral until their towns are built): their numbers and
## upgrades, Titans' full-strength melee and mind immunity, the mutual hatred of Titans and Black Dragons, the dragons'
## spell immunity (Red: levels 1-3, Black: all, friendly spells too) and their breath on the stack behind; on the map
## the Cloud Temple and Dragon Cave, wild Titans and Black Dragons, and the Hill Fort upgrading any creature.
##   Godot --headless --path . res://tools/titan_dragon_test.tscn      (in the suite)
var checks := 0
var fails := 0

func _ready() -> void:
	_data()
	_titan()
	_immunity()
	_breath()
	_art()
	_map()
	_hill_fort()
	print("TITAN DRAGON TEST: %d checks, failures: %d" % [checks, fails])
	get_tree().quit(1 if fails else 0)

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("FAIL ", label)

func _battle(attackers: Array, defenders: Array, spells: Array = []) -> BattleLogic:
	var hero := GameState.make_hero("sir_aldric", 0)
	hero["spells"] = spells
	hero["mana"] = 200
	hero["artifacts"] = []
	hero["machines"] = []
	var L := BattleLogic.new()
	L.setup({"attacker_army": attackers, "defender_army": defenders, "attacker_hero": hero, "seed": 67})
	L.obstacles.clear()
	return L

func _data() -> void:
	var want := {"giant": [19, 16, [40, 60], 150, 7, 0], "titan": [24, 24, [40, 60], 300, 11, 24],
		"red_dragon": [19, 19, [40, 50], 180, 9, 0], "black_dragon": [25, 25, [40, 50], 300, 15, 0]}
	for id in want:
		var c: Dictionary = GameData.CREATURES.get(id, {})
		_ok([c.get("attack"), c.get("defense"), c.get("dmg"), c.get("hp"), c.get("speed"), c.get("shots")] == want[id],
			"%s has HoMM3's numbers" % id)
		_ok(c.get("tier") == 7, "%s is a seventh-tier creature" % id)
	_ok(GameData.upgrade_of_base("giant") == "titan" and GameData.upgrade_of_base("red_dragon") == "black_dragon",
		"the Giant upgrades to the Titan, the Red Dragon to the Black Dragon")
	_ok(GameData.upgrade_of_base("pikeman") == "halberdier" and GameData.upgrade_of_base("titan") == "", "other upgrades as before")
	var words := GameData.ability_words("black_dragon")
	_ok("Hates Titans (+50% dmg)" in words and "Immune to all spells" in words, "the hover panels say so (%s)" % [words])

func _titan() -> void:
	var L := _battle([{"id": "titan", "count": 2}], [{"id": "black_dragon", "count": 2}, {"id": "red_dragon", "count": 2}])
	var t: Dictionary = L.alive_stacks(0)[0]
	var bd: Dictionary = L.alive_stacks(1)[0]
	var rd: Dictionary = L.alive_stacks(1)[1]
	t["hex"] = Vector2i(5, 5)
	bd["hex"] = Vector2i(7, 5)
	rd["hex"] = Vector2i(9, 9)
	# (the Attack against Defense factor as the rules have it, the hero's bonus included; then the hatred's 1.5)
	var ad := func(x, y) -> float:
		var A: int = L.attack_stat(x)
		var D: int = L.defense_stat(y)
		return 1.0 + minf(3.0, 0.05 * (A - D)) if A > D else 1.0 - minf(0.7, 0.025 * (D - A))
	_ok(is_equal_approx(L._mult(t, bd, false, 0), ad.call(t, bd) * 1.5), "a Titan in melee: no shooter's penalty, and its hatred (%.4f)" % L._mult(t, bd, false, 0))
	_ok(is_equal_approx(L._mult(t, rd, true, 0), ad.call(t, rd)), "no hatred for Red Dragons (%.4f)" % L._mult(t, rd, true, 0))
	_ok(is_equal_approx(L._mult(bd, t, false, 0), ad.call(bd, t) * 1.5), "and a Black Dragon's for Titans")
	var g := _battle([{"id": "pikeman", "count": 1}], [{"id": "giant", "count": 1}], ["blind", "berserk", "slow"])
	var gs: Dictionary = g.alive_stacks(1)[0]
	_ok(not g.spell_target_ok(0, "blind", gs["hex"]) and not g.spell_target_ok(0, "berserk", gs["hex"])
		and g.spell_target_ok(0, "slow", gs["hex"]), "Giants shrug off mind spells, not others")

func _immunity() -> void:
	var L := _battle([{"id": "pikeman", "count": 10}], [{"id": "black_dragon", "count": 1}, {"id": "red_dragon", "count": 1}],
		["magic_arrow", "fireball", "chain_lightning", "armageddon", "implosion"])
	var bd: Dictionary = L.alive_stacks(1)[0]
	var rd: Dictionary = L.alive_stacks(1)[1]
	bd["hex"] = Vector2i(8, 3)
	rd["hex"] = Vector2i(8, 7)
	for sp in ["magic_arrow", "chain_lightning", "implosion"]:
		_ok(not L.spell_target_ok(0, sp, bd["hex"]), "a Black Dragon cannot be struck by %s" % sp)
	_ok(not L.spell_target_ok(0, "magic_arrow", rd["hex"]) and L.spell_target_ok(0, "chain_lightning", rd["hex"])
		and L.spell_target_ok(0, "implosion", rd["hex"]), "a Red Dragon only by spells above level 3")
	var ev: Dictionary = L.cast(0, "armageddon", Vector2i(7, 5))[0]
	_ok(not ev["dmg"].has(bd["uid"]) and ev["dmg"].has(rd["uid"]), "Armageddon burns the Red Dragon, not the Black")
	L.hero_cast[0] = false
	ev = L.cast(0, "fireball", rd["hex"])[0]
	_ok(ev["targets"].is_empty(), "a fireball on a Red Dragon does nothing")
	var own := _battle([{"id": "black_dragon", "count": 1}], [{"id": "pikeman", "count": 1}], ["bless", "haste"])
	_ok(not own.spell_target_ok(0, "bless", own.alive_stacks(0)[0]["hex"]), "not even its own side's spells")

## A Red Dragon strikes a stack: the breath burns the one behind it, ours or theirs, which does not strike back.
func _breath() -> void:
	var L := _battle([{"id": "red_dragon", "count": 3}, {"id": "pikeman", "count": 20}],
		[{"id": "swordsman", "count": 10}, {"id": "archer", "count": 20}])
	var dr: Dictionary = L.alive_stacks(0)[0]
	var mine: Dictionary = L.alive_stacks(0)[1]
	var sw: Dictionary = L.alive_stacks(1)[0]
	var ar: Dictionary = L.alive_stacks(1)[1]
	dr["hex"] = Vector2i(5, 5)  # (its tail on 4, 5)
	sw["hex"] = Vector2i(6, 5)
	ar["hex"] = Vector2i(7, 5)
	mine["hex"] = Vector2i(1, 1)
	_ok(L.breath_victim(dr, sw) == ar, "the stack behind the struck one is in the breath's line")
	var before: int = ar["count"]
	var ev := L.do_melee(dr, sw, dr["hex"])
	var br := ev.filter(func(x): return x["t"] == "breath")
	_ok(br.size() >= 1 and br[0]["d"] == ar and ar["count"] < before, "it burns the archers behind (%s)" % [ev.map(func(x): return x["t"])])
	_ok(ev.filter(func(x): return x["t"] == "attack" and x["retaliation"] and x["a"] == ar).is_empty(), "who do not strike back")
	# our own stack behind is burned as well
	var L2 := _battle([{"id": "red_dragon", "count": 3}, {"id": "pikeman", "count": 20}], [{"id": "swordsman", "count": 10}])
	var d2: Dictionary = L2.alive_stacks(0)[0]
	var p2: Dictionary = L2.alive_stacks(0)[1]
	var s2: Dictionary = L2.alive_stacks(1)[0]
	d2["hex"] = Vector2i(6, 4)  # (it strikes down-left from above: 6,4 -> 5,5; behind that, 5,6 for even/odd rows)
	s2["hex"] = Vector2i(5, 5)
	var behind := BattleLogic.from_cube(BattleLogic.to_cube(Vector2i(5, 5)) * 2 - BattleLogic.to_cube(Vector2i(6, 4)))
	p2["hex"] = behind
	_ok(L2.breath_victim(d2, s2) == p2, "the line runs on diagonally too, and catches our own pikemen (%s)" % behind)
	var L3 := _battle([{"id": "red_dragon", "count": 3}], [{"id": "swordsman", "count": 10}])
	L3.alive_stacks(0)[0]["hex"] = Vector2i(5, 5)
	L3.alive_stacks(1)[0]["hex"] = Vector2i(6, 5)
	_ok(L3.breath_victim(L3.alive_stacks(0)[0], L3.alive_stacks(1)[0]) == null, "nothing behind, nothing burned")
	_ok(BattleLogic.from_cube(BattleLogic.to_cube(Vector2i(3, 7))) == Vector2i(3, 7) and BattleLogic.from_cube(BattleLogic.to_cube(Vector2i(4, 2))) == Vector2i(4, 2),
		"hex and cube coordinates round-trip")

func _map() -> void:
	var w := WorldGen.generate({"seed": 4242, "map_size": 72, "faction": "haven", "opponents": 1})
	var kinds := {}
	for o in w["objects"].values():
		var k: String = o["type"] + ("_" + o["creature"] if o["type"] in ["dwelling", "monster"] and o["creature"] in ["giant", "red_dragon", "titan", "black_dragon"] else "")
		kinds[k] = kinds.get(k, 0) + 1
	for k in ["hill_fort", "dwelling_giant", "dwelling_red_dragon", "monster_titan", "monster_black_dragon"]:
		_ok(kinds.get(k, 0) == 1, "a medium map has one %s (%d)" % [k, kinds.get(k, 0)])
	var small := WorldGen.generate({"seed": 4242, "map_size": 36, "faction": "haven", "opponents": 1})
	var sk: Array = small["objects"].values().map(func(o): return o["type"] + "_" + str(o.get("creature", "")))
	_ok("hill_fort_" in sk and not "dwelling_giant" in sk and not "monster_titan" in sk, "a small map: the Hill Fort only")
	for o in w["objects"].values():
		if o["type"] == "dwelling" and o["creature"] in ["giant", "red_dragon"]:
			_ok(o["available"] == 1, "%s's dwelling starts with one to recruit" % o["creature"])

func _hill_fort() -> void:
	var w := WorldGen.generate({"seed": 4242, "map_size": 72, "faction": "haven", "opponents": 1})
	GameState.world = w
	var rules := AdvRules.new(w)
	var me: Dictionary = w["players"][0]
	var h: Dictionary = w["heroes"][me["heroes"][0]]
	var fort: Dictionary = w["objects"].values().filter(func(o): return o["type"] == "hill_fort")[0]
	h["army"] = [{"id": "giant", "count": 2}, {"id": "pikeman", "count": 10}, {"id": "red_dragon", "count": 1},
		{"id": "titan", "count": 1}, null, null, null]
	me["resources"] = {"gold": 20000, "wood": 0, "ore": 0, "mercury": 0, "sulfur": 5, "crystal": 0, "gems": 5}
	var cmd := {"t": "hill_fort", "p": 0, "hero": h["uid"], "object": fort["uid"], "si": 0}
	_ok(not rules.do(cmd)["ok"], "only a hero standing at the Hill Fort")
	h["pos"] = fort["pos"]
	_ok(HillFort.upgradable(h).map(func(e): return e[0]) == [0, 1, 2], "the Giants, Sergeants and Red Dragon can be upgraded, not the Titan")
	_ok(rules.do(cmd)["ok"] and h["army"][0]["id"] == "titan", "the Giants become Titans")
	_ok(me["resources"]["gold"] == 20000 - 2 * 3000 and me["resources"]["gems"] == 5 - 2, "for the price difference, per creature (%s)" % [me["resources"]])
	_ok(rules.do({"t": "hill_fort", "p": 0, "hero": h["uid"], "object": fort["uid"], "si": 1})["ok"] and h["army"][1]["id"] == "halberdier",
		"a faction creature too: Sergeants to Halberdiers")
	me["resources"]["sulfur"] = 0
	_ok(not rules.do({"t": "hill_fort", "p": 0, "hero": h["uid"], "object": fort["uid"], "si": 2})["ok"], "not without the sulfur")
	me["resources"]["sulfur"] = 1
	var ai := AdvAI.new(rules)
	_ok(ai._object_value(h, me, fort, 1000.0) > 0.0, "the computer values the fort while it has something to upgrade")
	ai.upgrade_at_hill_fort(h, fort["uid"])
	_ok(h["army"][2]["id"] == "black_dragon", "and upgrades its Red Dragon there")
	_ok(ai._object_value(h, me, fort, 1000.0) == 0.0, "then it has nothing more to do there")

func _art() -> void:
	for id in ["giant", "titan", "red_dragon", "black_dragon"]:
		_ok(Assets.has("creatures/%s.png" % id) and Assets.has("creatures/portraits/%s.png" % id), "%s has its figure and portrait" % id)
		for pose in ["attack", "hit", "dead", "move0", "move3"]:
			_ok(Assets.has("creatures/%s_%s.png" % [id, pose]), "%s has its %s pose" % [id, pose])
	for p in ["map/dwelling_giant.png", "map/dwelling_red_dragon.png", "map/hill_fort.png"]:
		_ok(Assets.has(p), "%s painted" % p)
