extends Node
## The Illuminated (HoMM3's Tower, session67): the faction's record, creatures and heroes; the unliving (no morale, mind
## spells, life drain, Death Ripple, Necromancy); the Magi (no wall penalty, the hero's spells 2 cheaper); Master Genies'
## helpful spells (three a battle, not one already on the target, the same on every machine); the Library and the
## Wall of Knowledge; the computer's build order; and the art each needs.
##   Godot --headless --path . res://tools/illuminated_test.tscn      (in the suite)
var checks := 0
var fails := 0

func _ready() -> void:
	_data()
	_unliving()
	_magi()
	_genies()
	_town()
	_art()
	print("ILLUMINATED TEST: %d checks, failures: %d" % [checks, fails])
	get_tree().quit(1 if fails else 0)

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("FAIL ", label)

func _battle(attackers: Array, defenders: Array, spells: Array = [], seed := 67) -> BattleLogic:
	var hero := GameState.make_hero("nicolas_flamel", 0)
	hero["spells"] = spells
	hero["mana"] = 200
	hero["artifacts"] = []
	hero["machines"] = []
	var L := BattleLogic.new()
	L.setup({"attacker_army": attackers, "defender_army": defenders, "attacker_hero": hero, "seed": seed})
	L.obstacles.clear()
	return L

func _data() -> void:
	var f: Dictionary = GameData.FACTIONS.get("tower", {})
	_ok(f.get("name", "") == "The Illuminated", "the faction exists")
	var want := {"homunculus": [3, 3, 4, 4, 16], "master_homunculus": [4, 4, 4, 5, 16], "gargoyle": [6, 6, 16, 6, 9],
		"obsidian_gargoyle": [7, 7, 16, 9, 9], "stone_golem": [7, 10, 30, 3, 6], "iron_golem": [9, 10, 35, 5, 6],
		"magus": [11, 8, 25, 5, 5], "arch_magus": [12, 9, 30, 7, 5], "genie": [12, 12, 40, 7, 3],
		"master_genie": [12, 12, 40, 11, 3], "naga": [16, 13, 110, 5, 2], "naga_queen": [16, 13, 110, 7, 2]}
	for id in want:
		var c: Dictionary = GameData.CREATURES.get(id, {})
		_ok([c.get("attack"), c.get("defense"), c.get("hp"), c.get("speed"), c.get("growth")] == want[id], "%s has HoMM3's numbers" % id)
	_ok(f["creatures"][6] == "giant" and f["upgrades"][6] == "titan" and GameData.CREATURES["giant"]["faction"] == "tower",
		"Giants and Titans are its seventh tier")
	_ok(GameData.CREATURES["master_homunculus"]["shots"] == 8 and GameData.CREATURES["homunculus"]["shots"] == 0,
		"Master Homunculi shoot, Homunculi do not")
	var heroes := GameData.HEROES.values().filter(func(h): return h["faction"] == "tower")
	_ok(heroes.size() == 6 and heroes.filter(func(h): return h["class"] == "Wizard").size() == 3, "six heroes, three Wizards")

func _unliving() -> void:
	var L := _battle([{"id": "stone_golem", "count": 10}, {"id": "gargoyle", "count": 10}, {"id": "pikeman", "count": 10}],
		[{"id": "vampire", "count": 5}], ["death_ripple", "blind"])
	var golem: Dictionary = L.alive_stacks(0)[0]
	var garg: Dictionary = L.alive_stacks(0)[1]
	var pike: Dictionary = L.alive_stacks(0)[2]
	_ok(not L.living(golem) and not L.living(garg) and L.living(pike), "Golems and Gargoyles are not alive")
	_ok(L.morale(0, golem) == 0 and L.morale(0, garg) == 0, "they feel no morale")
	var ev: Dictionary = L.cast(0, "death_ripple", Vector2i(7, 5))[0]
	_ok(not ev["targets"].has(golem) and not ev["targets"].has(garg) and ev["targets"].has(pike), "Death Ripple passes them by")
	_ok(L.stack_immune(garg, "blind"), "mind spells too")
	var r := Necromancy.calculate(GameState.make_hero("lord_morthis", 1), [{"id": "skeleton", "count": 1}, null, null, null, null, null, null],
		[{"id": "gargoyle", "count": 40}], 1)
	_ok(r["raised"] == 0, "and no Skeletons rise from them")
	_ok(GameData.CREATURES["iron_golem"]["spell_resist"] == 75 and GameData.CREATURES["stone_golem"]["spell_resist"] == 50,
		"Golems take half and a quarter of spell damage")

func _magi() -> void:
	var L := _battle([{"id": "magus", "count": 10}], [{"id": "pikeman", "count": 10}], ["magic_arrow"])
	_ok(L.spell_cost(0, "magic_arrow") == 3, "with Magi in the army a 5-mana spell costs 3")
	var mana: int = L.heroes[0]["mana"]
	L.cast(0, "magic_arrow", L.alive_stacks(1)[0]["hex"])
	_ok(L.heroes[0]["mana"] == mana - 3, "and the hero pays 3")
	var none := _battle([{"id": "pikeman", "count": 10}], [{"id": "pikeman", "count": 10}], ["magic_arrow"])
	_ok(none.spell_cost(0, "magic_arrow") == 5, "without them, 5")
	var S := _battle([{"id": "magus", "count": 10}, {"id": "archer", "count": 10}], [{"id": "pikeman", "count": 10}])
	S.siege = 1
	var m: Dictionary = S.alive_stacks(0)[0]
	var a: Dictionary = S.alive_stacks(0)[1]
	var d: Dictionary = S.alive_stacks(1)[0]
	_ok(not S.behind_wall(m, d), "a Magus is never halved by the wall")

func _genies() -> void:
	var L := _battle([{"id": "master_genie", "count": 5}, {"id": "swordsman", "count": 10}, {"id": "stone_golem", "count": 5}],
		[{"id": "pikeman", "count": 10}])
	var g: Dictionary = L.alive_stacks(0)[0]
	var sw: Dictionary = L.alive_stacks(0)[1]
	var enemy: Dictionary = L.alive_stacks(1)[0]
	_ok(L.genie_casts_left(g) == 3, "a Master Genie has three spells")
	_ok(L.genie_target_ok(g, sw) and not L.genie_target_ok(g, enemy), "on its own side only")
	var seen := {}
	for i in 3:
		var before: Array = sw["effects"].keys()
		var ev := L.genie_cast(g, sw)
		_ok(ev.size() == 1 and ev[0]["targets"] == [sw], "cast %d lands on the Swordsmen" % (i + 1))
		var new: Array = sw["effects"].keys().filter(func(k): return not k in before)
		_ok(new.size() == 1 and not seen.has(new[0]) and new[0] in BattleLogic.GENIE_SPELLS, "a helpful spell not already on them (%s)" % [new])
		if new.size() == 1:
			seen[new[0]] = true
	_ok(L.genie_casts_left(g) == 0 and not L.genie_target_ok(g, sw), "then no more")
	var G := _battle([{"id": "genie", "count": 5}, {"id": "swordsman", "count": 10}], [{"id": "pikeman", "count": 10}])
	_ok(G.genie_casts_left(G.alive_stacks(0)[0]) == 0, "plain Genies cast nothing")
	# the same pick on two machines: the battle's own dice
	var picks := []
	for k in 2:
		var M := _battle([{"id": "master_genie", "count": 5}, {"id": "swordsman", "count": 10}], [{"id": "pikeman", "count": 10}], [], 99)
		M.genie_cast(M.alive_stacks(0)[0], M.alive_stacks(0)[1])
		picks.append(M.alive_stacks(0)[1]["effects"].keys())
	_ok(picks[0] == picks[1], "the same spell on both machines (%s)" % [picks])
	# the computer uses them early, on its most valuable stack
	var A := _battle([{"id": "master_genie", "count": 2}, {"id": "naga", "count": 4}], [{"id": "pikeman", "count": 10}])
	var act := BattleAI.decide(A, A.alive_stacks(0)[0])
	_ok(act.get("type") == "genie" and act.get("target") == A.alive_stacks(0)[1], "the computer casts on its Nagas (%s)" % [act.get("type")])

func _town() -> void:
	var p := {"resources": {"gold": 99999, "wood": 99, "ore": 99, "mercury": 99, "sulfur": 99, "crystal": 99, "gems": 99}}
	var t := TownLogic.make_town("tower", 0, Vector2i.ZERO, "Ingolstadt", true)
	t["buildings"].append("mage_guild_1")
	TownLogic.learn_guild_spells(t)
	var n1: int = t["mage_spells"].size()
	_ok(TownLogic.build_block_reason(t, p, "library") == "", "the Library can be built after the Mage Guild")
	TownLogic.build(t, p, "library")
	_ok(t["mage_spells"].size() == n1 + 1, "and the guild teaches one more spell (%d -> %d)" % [n1, t["mage_spells"].size()])
	_ok(TownLogic.build_block_reason(TownLogic.make_town("haven", 0, Vector2i.ZERO, "Acre", true), p, "library") == "Not in this town",
		"not in the Temple's towns")
	t["built_today"] = false
	TownLogic.build(t, p, "wall_of_knowledge")
	var w := WorldGen.generate({"seed": 4242, "map_size": 48, "faction": "tower", "opponents": 1})
	var rules := AdvRules.new(w)
	var h := GameState.make_hero("cagliostro", 0)
	var k: int = h["knowledge"]
	_ok(rules.study_wall(h, t) == 1 and h["knowledge"] == k + 1, "the Wall of Knowledge: +1 Knowledge")
	_ok(rules.study_wall(h, t) == 0 and h["knowledge"] == k + 1, "once per hero")
	var order := AdvAI.build_order("tower")
	_ok("library" in order and "wall_of_knowledge" in order and "mage_guild_5" in order, "the computer builds them, and the fifth guild level")
	_ok(TownLogic.build_block_reason(TownLogic.make_town("tower", 0, Vector2i.ZERO, "Prague", true), p, "dwelling_4").begins_with("Requires"),
		"the Mage Tower needs the Mage Guild first")
	var me: Dictionary = w["players"][0]
	_ok(me["faction"] == "tower" and w["towns"][me["towns"][0]]["faction"] == "tower", "a new game can be played as the Illuminated")

func _art() -> void:
	for id in GameData.FACTIONS["tower"]["creatures"] + GameData.FACTIONS["tower"]["upgrades"]:
		for p in ["creatures/%s.png", "creatures/portraits/%s.png", "creatures/%s_attack.png", "creatures/%s_hit.png",
				"creatures/%s_dead.png", "creatures/%s_move0.png"]:
			_ok(Assets.has(p % id), "%s painted" % (p % id))
	for hid in GameData.HEROES:
		if GameData.HEROES[hid]["faction"] == "tower":
			_ok(Assets.has("heroes/portraits/%s.png" % hid), "%s's portrait" % hid)
	for p in ["heroes/map_tower.png", "heroes/map_tower_run0.png", "heroes/battle_tower.png", "heroes/battle_tower_cast.png",
			"heroes/battle_tower_idle0.png", "map/town_tower.png", "map/town_tower_fort.png", "map/town_tower_village.png",
			"town/tower_bg.png", "town/layout_tower.json", "battle/bg_siege_tower_1.png", "battle/bg_siege_tower_3.png",
			"audio/music/town_tower.mp3", "icons/building_tower_library.png", "icons/building_tower_dwelling_7.png"]:
		_ok(Assets.has(p), "%s made" % p)
	var lay = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town/layout_tower.json")) if Assets.has("town/layout_tower.json") else {}
	for b in ["village_hall", "town_hall", "city_hall", "capitol", "fort", "citadel", "castle", "tavern", "marketplace",
			"mage_guild_1", "mage_guild_2", "blacksmith", "library", "wall_of_knowledge"] + range(1, 8).map(func(i): return "dwelling_%d" % i):
		_ok(lay is Dictionary and lay.has(b) and Assets.has("town/tower_%s.png" % b), "the town screen has its %s" % b)
