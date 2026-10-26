extends Node
## Agartha (HoMM3's Dungeon, session68): the faction's record, creatures and heroes; Morlocks immune to Blind and
## stone gaze; Medusas' stone gaze and Scorpicores' venom (the chance, the lost turns, half damage on stone, the
## quarter retaliation, waking when struck, who is spared); Harpies' strike and return; Minotaurs' morale; the
## Mana Vortex, the Battle Scholar Academy and the Portal of Summoning; the Subterranean ground; the computer's build
## order; a new game as Agartha; and the art each needs.
##   Godot --headless --path . res://tools/agartha_test.tscn      (in the suite)
var checks := 0
var fails := 0

func _ready() -> void:
	_data()
	_morlocks()
	_stone()
	_venom()
	_harpies()
	_minotaurs()
	_town()
	_portal()
	_ground()
	_art()
	print("AGARTHA TEST: %d checks, failures: %d" % [checks, fails])
	get_tree().quit(1 if fails else 0)

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("FAIL ", label)

func _battle(attackers: Array, defenders: Array, spells: Array = [], seed := 68) -> BattleLogic:
	var hero := GameState.make_hero("edmond_halley", 0)
	hero["spells"] = spells
	hero["mana"] = 200
	hero["artifacts"] = []
	hero["machines"] = []
	hero["skills"] = {}
	var L := BattleLogic.new()
	L.setup({"attacker_army": attackers, "defender_army": defenders, "attacker_hero": hero, "seed": seed})
	L.obstacles.clear()
	return L

func _data() -> void:
	var f: Dictionary = GameData.FACTIONS.get("dungeon", {})
	_ok(f.get("name", "") == "Agartha" and f.get("terrain", "") == "subterranean", "the faction exists, on Subterranean ground")
	var want := {"morlock": [4, 3, 5, 4, 14], "infernal_morlock": [5, 4, 6, 5, 14], "harpy": [6, 5, 14, 6, 8],
		"harpy_hag": [6, 6, 14, 9, 8], "watcher": [9, 7, 22, 5, 7], "evil_eye": [10, 8, 22, 7, 7],
		"medusa": [9, 9, 25, 5, 4], "medusa_queen": [10, 10, 30, 6, 4], "minotaur": [14, 12, 50, 6, 3],
		"minotaur_king": [15, 15, 50, 8, 3], "manticore": [15, 13, 80, 7, 2], "scorpicore": [16, 14, 80, 11, 2]}
	for id in want:
		var c: Dictionary = GameData.CREATURES.get(id, {})
		_ok([c.get("attack"), c.get("defense"), c.get("hp"), c.get("speed"), c.get("growth")] == want[id], "%s has HoMM3's numbers" % id)
	_ok(f["creatures"][6] == "red_dragon" and f["upgrades"][6] == "black_dragon" and GameData.CREATURES["red_dragon"]["faction"] == "dungeon"
		and GameData.CREATURES["black_dragon"]["faction"] == "dungeon", "Red and Black Dragons are its seventh tier")
	_ok(GameData.CREATURES["medusa"]["shots"] == 4 and GameData.CREATURES["medusa_queen"]["shots"] == 8
		and GameData.CREATURES["watcher"]["shots"] == 12 and GameData.CREATURES["evil_eye"]["shots"] == 24, "the shooters' shots")
	var heroes := GameData.HEROES.values().filter(func(h): return h["faction"] == "dungeon")
	_ok(heroes.size() == 6 and heroes.filter(func(h): return h["class"] == "Warlock").size() == 3, "six heroes, three Warlocks")
	_ok(GameData.CLASSES["Overlord"]["might"] and not GameData.CLASSES["Warlock"]["might"], "Overlords are might, Warlocks magic")
	_ok(GameData.ability_words("medusa").has("Stone gaze (20%: turns its target to stone)"), "the hover panels name the gaze")

func _morlocks() -> void:
	var L := _battle([{"id": "pikeman", "count": 10}], [{"id": "morlock", "count": 20}, {"id": "infernal_morlock", "count": 20}], ["blind"])
	for m in L.alive_stacks(1):
		_ok(L.stack_immune(m, "blind") and not L.spell_target_ok(0, "blind", m["hex"]), "%s cannot be blinded" % m["id"])
		var med := _battle([{"id": "medusa", "count": 5}], [{"id": m["id"], "count": 5}])
		_ok(med.stone_or_venom(med.alive_stacks(0)[0], med.alive_stacks(1)[0]) == "", "nor turned to stone (%s)" % m["id"])

## How often a strike leaves the gaze or the venom on its target, over many strikes.
func _rate(attacker: String, defender: String, kind: String) -> float:
	var hit := 0
	for i in 300:
		var L := _battle([{"id": attacker, "count": 1}], [{"id": defender, "count": 200}], [], 1000 + i)
		var a: Dictionary = L.alive_stacks(0)[0]
		var d: Dictionary = L.alive_stacks(1)[0]
		L._strike(a, d, false, 0, false)
		if d["effects"].has(kind):
			hit += 1
	return hit / 300.0

func _stone() -> void:
	var r := _rate("medusa", "swordsman", "stone")
	_ok(r > 0.12 and r < 0.28, "a Medusa's strike turns one in five to stone (%.2f)" % r)
	var L := _battle([{"id": "medusa", "count": 1}], [{"id": "swordsman", "count": 1}])
	_ok(_rate("medusa", "swordsman", "stone") == r, "the same on every machine (the battle's dice)")
	var med: Dictionary = L.alive_stacks(0)[0]
	_ok(L.stone_or_venom(med, L.alive_stacks(1)[0]) == "stone", "a Swordsman can be turned to stone")
	var B := _battle([{"id": "medusa", "count": 1}], [{"id": "ballista", "count": 1}])
	_ok(B.stone_or_venom(B.alive_stacks(0)[0], B.alive_stacks(1)[0]) == "", "a war machine cannot")
	# struck while stone: half damage, it wakes and does not strike back
	var a := _battle([{"id": "swordsman", "count": 10}], [{"id": "swordsman", "count": 10}], [], 5)
	var b := _battle([{"id": "swordsman", "count": 10}], [{"id": "swordsman", "count": 10}], [], 5)
	var stone: Dictionary = b.alive_stacks(1)[0]
	stone["effects"]["stone"] = 3
	_ok(b.spell_lost_turn(stone) == "stone", "stone loses its turn")
	var e1 := a.do_melee(a.alive_stacks(0)[0], a.alive_stacks(1)[0], _beside(a, a.alive_stacks(1)[0]))
	var e2 := b.do_melee(b.alive_stacks(0)[0], stone, _beside(b, stone))
	_ok(int(e2[_first_attack(e2)]["dmg"]) == maxi(1, int(int(e1[_first_attack(e1)]["dmg"]) * 0.5)),
		"struck, stone takes half damage (%d vs %d)" % [e2[_first_attack(e2)]["dmg"], e1[_first_attack(e1)]["dmg"]])
	_ok(e2.filter(func(e): return e["t"] == "attack" and e["retaliation"]).is_empty(), "and does not strike back")
	_ok(not stone["effects"].has("stone") and b.spell_lost_turn(stone) == "", "and wakes")

func _beside(L: BattleLogic, t: Dictionary) -> Vector2i:
	for n in BattleLogic.neighbors(t["hex"]):
		if L.is_free(n):
			return n
	return t["hex"]

func _first_attack(ev: Array) -> int:
	for i in ev.size():
		if ev[i]["t"] == "attack":
			return i
	return 0

func _venom() -> void:
	var r := _rate("scorpicore", "swordsman", "paralyze")
	_ok(r > 0.12 and r < 0.28, "a Scorpicore's sting paralyzes one in five (%.2f)" % r)
	_ok(_rate("manticore", "swordsman", "paralyze") == 0.0, "a Manticore's does not")
	var L := _battle([{"id": "scorpicore", "count": 1}], [{"id": "black_dragon", "count": 1}, {"id": "red_dragon", "count": 1}])
	var s: Dictionary = L.alive_stacks(0)[0]
	_ok(L.stone_or_venom(s, L.alive_stacks(1)[0]) == "" and L.stone_or_venom(s, L.alive_stacks(1)[1]) == "paralyze",
		"Black Dragons are spared, Red Dragons are not")
	# a paralyzed stack, struck, wakes and strikes back at a quarter
	var a := _battle([{"id": "swordsman", "count": 10}], [{"id": "swordsman", "count": 10}], [], 9)
	var b := _battle([{"id": "swordsman", "count": 10}], [{"id": "swordsman", "count": 10}], [], 9)
	var p: Dictionary = b.alive_stacks(1)[0]
	p["effects"]["paralyze"] = 3
	_ok(b.spell_lost_turn(p) == "paralyze", "paralyzed, it loses its turn")
	var ra: Array = a.do_melee(a.alive_stacks(0)[0], a.alive_stacks(1)[0], _beside(a, a.alive_stacks(1)[0])).filter(func(e): return e["t"] == "attack" and e["retaliation"])
	var rb: Array = b.do_melee(b.alive_stacks(0)[0], p, _beside(b, p)).filter(func(e): return e["t"] == "attack" and e["retaliation"])
	_ok(ra.size() == 1 and rb.size() == 1 and int(rb[0]["dmg"]) <= maxi(1, int(int(ra[0]["dmg"]) * 0.25)) + 1,
		"struck, it strikes back at a quarter (%s vs %s)" % [rb.map(func(e): return e["dmg"]), ra.map(func(e): return e["dmg"])])
	_ok(not p["effects"].has("paralyze"), "and wakes")
	var c := _battle([{"id": "pikeman", "count": 1}], [{"id": "pikeman", "count": 1}], ["cure"])
	var me: Dictionary = c.alive_stacks(0)[0]
	me["effects"]["paralyze"] = 3
	c.cast(0, "cure", me["hex"])
	_ok(not me["effects"].has("paralyze"), "Cure ends it")

func _harpies() -> void:
	var L := _battle([{"id": "harpy", "count": 10}], [{"id": "pikeman", "count": 10}])
	var h: Dictionary = L.alive_stacks(0)[0]
	var t: Dictionary = L.alive_stacks(1)[0]
	t["hex"] = Vector2i(h["hex"].x + 4, h["hex"].y)
	var start: Vector2i = h["hex"]
	var ev := L.do_melee(h, t, _beside(L, t))
	var moves: Array = ev.filter(func(e): return e["t"] == "move")
	_ok(h["hex"] == start and moves.size() == 2 and moves[1]["path"][-1] == start, "a Harpy strikes and flies home")
	_ok(ev.filter(func(e): return e["t"] == "attack" and e["retaliation"]).size() == 1, "a Harpy is struck back")
	var H := _battle([{"id": "harpy_hag", "count": 10}], [{"id": "pikeman", "count": 10}])
	var hag: Dictionary = H.alive_stacks(0)[0]
	var t2: Dictionary = H.alive_stacks(1)[0]
	t2["hex"] = Vector2i(hag["hex"].x + 4, hag["hex"].y)
	var ev2 := H.do_melee(hag, t2, _beside(H, t2))
	_ok(ev2.filter(func(e): return e["t"] == "attack" and e["retaliation"]).is_empty(), "a Harpy Hag is not")

func _minotaurs() -> void:
	# three factions in the army: -2 morale, but a Minotaur's stays positive
	var L := _battle([{"id": "minotaur", "count": 5}, {"id": "pikeman", "count": 5}, {"id": "skeleton", "count": 5},
		{"id": "homunculus", "count": 5}], [{"id": "pikeman", "count": 10}])
	var mino: Dictionary = L.alive_stacks(0)[0]
	var pike: Dictionary = L.alive_stacks(0)[1]
	_ok(L.morale(0, pike) < 0 and L.morale(0, mino) == 1, "a Minotaur's morale is never below +1 (%d, %d)" % [L.morale(0, mino), L.morale(0, pike)])

func _town() -> void:
	var p := {"resources": {"gold": 99999, "wood": 99, "ore": 99, "mercury": 99, "sulfur": 99, "crystal": 99, "gems": 99}}
	var t := TownLogic.make_town("dungeon", 0, Vector2i.ZERO, "Agartha", true)
	_ok(TownLogic.build_block_reason(t, p, "mana_vortex").begins_with("Requires"), "the Mana Vortex needs the Mage Guild")
	t["buildings"].append("mage_guild_1")
	for b in ["mana_vortex", "battle_scholar_academy"]:
		t["built_today"] = false
		_ok(TownLogic.build_block_reason(t, p, b) == "" and TownLogic.build(t, p, b), "the %s can be built" % b)
	_ok(TownLogic.build_block_reason(TownLogic.make_town("haven", 0, Vector2i.ZERO, "Acre", true), p, "mana_vortex") == "Not in this town",
		"not in the Temple's towns")
	var w := WorldGen.generate({"seed": 6868, "map_size": 48, "faction": "dungeon", "opponents": 1})
	var rules := AdvRules.new(w)
	var h := GameState.make_hero("edmond_halley", 0)
	h["mana"] = 3
	var full := GameState.max_mana(h)
	_ok(rules.drink_vortex(h, t) > 0 and h["mana"] == 2 * full, "the Vortex restores, then doubles the spell points (%d of %d)" % [h["mana"], full])
	h["mana"] = 3
	var h2 := GameState.make_hero("arne_saknussemm", 0)
	_ok(rules.drink_vortex(h2, t) == 0, "once a week, for the first hero")
	w["day"] += 7
	_ok(rules.drink_vortex(h2, t) > 0, "and again the next week")
	var xp: int = h["xp"]
	_ok(rules.attend_academy(h, t) == 1000 and h["xp"] == xp + 1000 and int(h.get("pending_levels", 0)) > 0,
		"the Academy: +1000 experience, a level to choose")
	_ok(rules.attend_academy(h, t) == 0 and h["xp"] == xp + 1000, "once per hero")
	var order := AdvAI.build_order("dungeon")
	_ok("mana_vortex" in order and "portal_of_summoning" in order and "battle_scholar_academy" in order and "mage_guild_5" in order,
		"the computer builds them, and the fifth guild level")
	var t7 := TownLogic.make_town("dungeon", 0, Vector2i.ZERO, "Nazar", true)
	t7["buildings"] += ["dwelling_3", "dwelling_4", "dwelling_5", "dwelling_6", "citadel", "blacksmith", "mage_guild_2"]
	_ok(TownLogic.build_block_reason(t7, p, "dwelling_7").begins_with("Requires"), "the Dragon Cave needs the third guild level")
	t7["buildings"].append("mage_guild_3")
	_ok(TownLogic.build_block_reason(t7, p, "dwelling_7") == "", "then it can be built")
	var me: Dictionary = w["players"][0]
	_ok(me["faction"] == "dungeon" and w["towns"][me["towns"][0]]["faction"] == "dungeon", "a new game can be played as Agartha")
	# through the town visit command, as both machines run it
	var town: Dictionary = w["towns"][me["towns"][0]]
	town["buildings"] += ["mage_guild_1", "mana_vortex", "battle_scholar_academy"]
	var hero: Dictionary = w["heroes"][me["heroes"][0]]
	hero["pos"] = town["pos"]
	var r := rules.do({"t": "town_visit", "p": 0, "hero": hero["uid"], "town": town["uid"]})
	_ok(r["ok"] and r["xp"] == 1000 and r["vortex"] > 0, "a visit studies at the Academy and drinks the Vortex (%s)" % [r])

func _portal() -> void:
	var w := WorldGen.generate({"seed": 6869, "map_size": 48, "faction": "dungeon", "opponents": 1})
	var rules := AdvRules.new(w)
	var me: Dictionary = w["players"][0]
	var town: Dictionary = w["towns"][me["towns"][0]]
	me["resources"] = {"gold": 99999, "wood": 99, "ore": 99, "mercury": 99, "sulfur": 99, "crystal": 99, "gems": 99}
	town["buildings"] += ["mage_guild_1"]
	town["built_today"] = false
	_ok(rules.do({"t": "build", "p": 0, "town": town["uid"], "building": "portal_of_summoning"})["ok"], "the Portal can be built")
	_ok(town.get("portal", {}).is_empty(), "with no dwelling of ours on the map it calls nothing")
	var dw: Array = w["objects"].values().filter(func(o): return o["type"] == "dwelling")
	dw.sort_custom(func(a, b): return a["uid"] < b["uid"])
	_ok(dw.size() >= 2, "the map has dwellings (%d)" % dw.size())
	if dw.size() < 2:
		return
	dw[0]["owner"] = 0
	rules.summon_portal(town)
	var pool: Dictionary = town.get("portal", {})
	_ok(pool.get("creature", "") == dw[0]["creature"] and pool.get("count", 0) == GameData.CREATURES[dw[0]["creature"]]["growth"],
		"it calls a week of our dwelling's creatures (%s)" % [pool])
	rules.summon_portal(town)
	_ok(int(town["portal"]["count"]) == 2 * int(GameData.CREATURES[dw[0]["creature"]]["growth"]), "the same creature again: they add up")
	var army: Array = rules.town_army(town)
	var before := GameState.army_strength(army)
	var res := rules.do({"t": "recruit_portal", "p": 0, "town": town["uid"], "n": 1})
	_ok(res["ok"] and GameState.army_strength(rules.town_army(town)) > before and int(town["portal"]["count"]) == 2 * int(GameData.CREATURES[dw[0]["creature"]]["growth"]) - 1,
		"recruited into the town")
	_ok(not rules.do({"t": "recruit_portal", "p": 0, "town": town["uid"], "n": 999})["ok"], "not more than it called")
	dw[1]["owner"] = 0
	var seen := {}
	for d in 30:
		w["day"] += 7
		rules.summon_portal(town)
		seen[town["portal"]["creature"]] = true
	_ok(seen.size() == (2 if dw[0]["creature"] != dw[1]["creature"] else 1), "each week one of our dwellings, at random (%s)" % [seen.keys()])

func _ground() -> void:
	_ok(WorldGen.TERRAIN_ORDER[WorldGen.T_SUBTERRANEAN] == "subterranean" and GameData.TERRAINS["subterranean"]["move_cost"] == 100,
		"Subterranean ground: the eighth terrain, at the normal cost")
	var w := WorldGen.generate({"seed": 6870, "map_size": 48, "faction": "dungeon", "opponents": 1})
	var town: Dictionary = w["towns"][w["players"][0]["towns"][0]]
	var p: Vector2i = town["pos"]
	var n := 0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var q := p + Vector2i(dx, dy)
			if q.x >= 0 and q.y >= 0 and q.x < w["size"].x and q.y < w["size"].y and w["terrain"][q.y * w["size"].x + q.x] == WorldGen.T_SUBTERRANEAN:
				n += 1
	_ok(n > 20, "Agartha's towns stand on it (%d of 49 tiles)" % n)
	var other := WorldGen.generate({"seed": 6870, "map_size": 48, "faction": "haven", "opponents": 1})
	_ok(not Array(other["terrain"]).has(WorldGen.T_SUBTERRANEAN) or Array(w["players"].map(func(pl): return pl["faction"])).has("dungeon")
		or Array(other["players"].map(func(pl): return pl["faction"])).has("dungeon"), "and only where Agartha lives")

func _art() -> void:
	for id in GameData.FACTIONS["dungeon"]["creatures"] + GameData.FACTIONS["dungeon"]["upgrades"]:
		for p in ["creatures/%s.png", "creatures/portraits/%s.png", "creatures/%s_attack.png", "creatures/%s_hit.png",
				"creatures/%s_dead.png", "creatures/%s_move0.png"]:
			_ok(Assets.has(p % id), "%s painted" % (p % id))
	for hid in GameData.HEROES:
		if GameData.HEROES[hid]["faction"] == "dungeon":
			_ok(Assets.has("heroes/portraits/%s.png" % hid), "%s's portrait" % hid)
	for p in ["heroes/map_dungeon.png", "heroes/map_dungeon_run0.png", "heroes/battle_dungeon.png", "heroes/battle_dungeon_cast.png",
			"heroes/battle_dungeon_idle0.png", "heroes/map_warlock.png", "heroes/battle_warlock.png",
			"map/town_dungeon.png", "map/town_dungeon_fort.png", "map/town_dungeon_village.png",
			"town/dungeon_bg.png", "town/layout_dungeon.json", "battle/bg_siege_dungeon_1.png", "battle/bg_siege_dungeon_3.png",
			"audio/music/town_dungeon.mp3", "icons/building_dungeon_mana_vortex.png", "icons/building_dungeon_dwelling_7.png",
			"terrain/subterranean.png", "battle/bg_subterranean.png", "battle/obstacle_stalagmites.png", "battle/obstacle_cave_mushroom.png",
			"map/decor_mushroom_tree_1.png", "map/decor_glow_caps.png"]:
		_ok(Assets.has(p), "%s made" % p)
	for k in load("res://scripts/battle/battle.gd").OBSTACLES["subterranean"]:
		_ok(Assets.has("battle/obstacle_%s.png" % k), "the cave obstacle %s" % k)
	for row in WorldGen.DECOR_KINDS[WorldGen.T_SUBTERRANEAN]:
		_ok(Assets.has("map/%s.png" % row[0]), "the cave decor %s" % row[0])
	var lay = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town/layout_dungeon.json")) if Assets.has("town/layout_dungeon.json") else {}
	for b in ["village_hall", "town_hall", "city_hall", "capitol", "fort", "citadel", "castle", "tavern", "marketplace",
			"mage_guild_1", "mage_guild_2", "blacksmith", "mana_vortex", "portal_of_summoning", "battle_scholar_academy"] \
			+ range(1, 8).map(func(i): return "dwelling_%d" % i):
		_ok(lay is Dictionary and lay.has(b) and Assets.has("town/dungeon_%s.png" % b), "the town screen has its %s" % b)
