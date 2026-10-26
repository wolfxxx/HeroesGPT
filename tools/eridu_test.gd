extends Node
## Eridu (the user's own faction, session68, docs/ERIDU.md): the faction's record, creatures and heroes; Shaping;
## the Scorpion Men's venom, Sharur's deflector, the Abgal's dispel, the Lamassu's sweep, the constructs, the beam;
## the House of the Me and the Dur-An-Ki, by command and by the computer; the Ziggurat's name; a new game as Eridu;
## its heroes' own spell look; and the art each needs.
##   Godot --headless --path . res://tools/eridu_test.tscn      (in the suite)
var checks := 0
var fails := 0

func _ready() -> void:
	_data()
	_shaping()
	_venom()
	_deflector()
	_dispel()
	_sweep()
	_constructs()
	_house_of_me()
	_gate()
	_town()
	_art()
	print("ERIDU TEST: %d checks, failures: %d" % [checks, fails])
	get_tree().quit(1 if fails else 0)

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("FAIL ", label)

func _battle(attackers: Array, defenders: Array, spells: Array = [], seed := 68, hero_id := "enki") -> BattleLogic:
	var hero := GameState.make_hero(hero_id, 0)
	hero["spells"] = spells
	hero["mana"] = 200
	hero["artifacts"] = []
	hero["machines"] = []
	hero["skills"] = {}
	var L := BattleLogic.new()
	L.setup({"attacker_army": attackers, "defender_army": defenders, "attacker_hero": hero, "seed": seed})
	L.obstacles.clear()
	return L

func _beside(L: BattleLogic, t: Dictionary) -> Vector2i:
	for n in BattleLogic.neighbors(t["hex"]):
		if L.is_free(n):
			return n
	return t["hex"]

func _data() -> void:
	var f: Dictionary = GameData.FACTIONS.get("eridu", {})
	_ok(f.get("name", "") == "Eridu" and f.get("terrain", "") == "swamp" and f.get("smith_machine", "") == "ammo_cart",
		"the faction exists, on swamp, with the Ammo Cart")
	# (the design's first numbers as tuned by tools/faction_balance.tscn, docs/ERIDU.md)
	var want := {"lulu": [4, 3, 7, 5, 14], "adamu": [5, 4, 8, 6, 14], "igigi": [5, 4, 10, 4, 9],
		"igigi_skywatcher": [6, 5, 12, 6, 9], "scorpion_man": [8, 6, 22, 7, 7], "scorpion_guardian": [9, 7, 24, 9, 7],
		"sharur": [10, 11, 35, 7, 4], "shargaz": [11, 12, 40, 9, 4], "apkallu": [12, 9, 34, 6, 3], "abgal": [13, 10, 35, 7, 3],
		"lamassu": [15, 15, 100, 6, 2], "shedu": [17, 17, 110, 7, 2], "anzu": [20, 20, 200, 11, 1], "imdugud": [26, 24, 280, 15, 1]}
	for id in want:
		var c: Dictionary = GameData.CREATURES.get(id, {})
		_ok([c.get("attack"), c.get("defense"), c.get("hp"), c.get("speed"), c.get("growth")] == want[id], "%s has the design's numbers" % id)
		_ok(c.get("faction", "") == "eridu" and c.has("ai_value"), "%s is Eridu's, valued for the computer" % id)
	for i in 7:
		var u: String = f["upgrades"][i]
		_ok(GameData.CREATURES[u].get("upgrade_of", "") == f["creatures"][i] and GameData.CREATURES[u]["tier"] == i + 1,
			"%s upgrades %s" % [u, f["creatures"][i]])
	_ok(GameData.CREATURES["anzu"]["cost"].get("crystal", 0) == 1 and GameData.CREATURES["imdugud"]["cost"].get("crystal", 0) == 2,
		"its top tier costs crystal")
	var heroes := GameData.HEROES.values().filter(func(h): return h["faction"] == "eridu")
	_ok(heroes.size() == 6 and heroes.filter(func(h): return h["class"] == "Keeper").size() == 3, "six heroes, three Keepers")
	_ok(heroes.all(func(h): return int(h["skills"].get("shaping", 0)) == 1), "every one with Basic Shaping")
	_ok(GameData.CLASSES["Lugal"]["might"] and not GameData.CLASSES["Keeper"]["might"], "Lugal are might, Keepers magic")
	for a in ["venom", "deflector", "dispel", "sweep"]:
		_ok(GameData.ABILITY_TEXT.has(a), "the hover panels name %s" % a)
	_ok(GameData.SKILLS.has("shaping"), "Shaping is a skill a hero may learn")

func _shaping() -> void:
	var h := GameState.make_hero("alalu", 0)
	var army := [{"id": "lulu", "count": 5}, null, null, null, null, null, null]
	var r := Necromancy.calculate(h, army, [{"id": "pikeman", "count": 100}])
	_ok(r["raise_skill"] == "shaping" and r["raised_id"] == "lulu" and r["raised"] == 10, "Basic Shaping remakes 10%% of slain Sergeants as Lulu (%s)" % [r])
	h["skills"]["shaping"] = 3
	_ok(Necromancy.calculate(h, army, [{"id": "pikeman", "count": 100}])["raised"] == 30, "Expert: 30 in 100")
	_ok(Necromancy.calculate(h, army, [{"id": "skeleton", "count": 100}, {"id": "stone_golem", "count": 50}])["raised"] == 0,
		"the undead and constructs cannot be shaped")
	var big := Necromancy.calculate(h, army, [{"id": "angel", "count": 10}])
	_ok(big["raised"] == 3, "capped by health: ten Angels make 3 Lulu, not 750 (%d)" % big["raised"])
	var full := [{"id": "adamu", "count": 5}, {"id": "igigi", "count": 1}, {"id": "igigi", "count": 1}, {"id": "igigi", "count": 1},
		{"id": "igigi", "count": 1}, {"id": "igigi", "count": 1}, {"id": "igigi", "count": 1}]
	var up := Necromancy.calculate(h, full, [{"id": "pikeman", "count": 90}])
	_ok(up["raised_id"] == "adamu" and up["raised"] == 18, "a full army with Adamu gets two thirds as many Adamu (%s)" % [up])
	_ok(Necromancy.message(r).begins_with("Shaping remakes 10 Lulu"), "the battle's report names Shaping (%s)" % Necromancy.message(r))
	var nh := GameState.make_hero("lord_morthis", 0)
	_ok(Necromancy.calculate(nh, army, [{"id": "pikeman", "count": 100}])["raised_id"] == "skeleton", "Necromancy is unchanged")

func _venom() -> void:
	var L := _battle([{"id": "scorpion_man", "count": 10}], [{"id": "swordsman", "count": 30}])
	var s: Dictionary = L.alive_stacks(0)[0]
	var d: Dictionary = L.alive_stacks(1)[0]
	var def0 := L.defense_stat(d)
	L._strike(s, d, false, 0, false)
	_ok(L.defense_stat(d) == def0 - 2, "a sting takes 2 Defense (%d -> %d)" % [def0, L.defense_stat(d)])
	for i in 4:
		L._strike(s, d, false, 0, false)
	_ok(L.defense_stat(d) == def0 - 6, "down to -6 at most (%d)" % L.defense_stat(d))
	L._new_round()
	L._new_round()
	L._new_round()
	L._new_round()
	_ok(L.defense_stat(d) == def0 - 6, "for the whole battle")
	var C := _battle([{"id": "pikeman", "count": 10}], [{"id": "pikeman", "count": 1}], ["cure"])
	var me: Dictionary = C.alive_stacks(0)[0]
	me["venom"] = 2
	C.cast(0, "cure", me["hex"])
	_ok(int(me.get("venom", 0)) == 0, "Cure ends it")
	var G := _battle([{"id": "scorpion_man", "count": 10}], [{"id": "skeleton", "count": 30}, {"id": "stone_golem", "count": 10}])
	G._strike(G.alive_stacks(0)[0], G.alive_stacks(1)[0], false, 0, false)
	G._strike(G.alive_stacks(0)[0], G.alive_stacks(1)[1], false, 0, false)
	_ok(int(G.alive_stacks(1)[0].get("venom", 0)) == 0 and int(G.alive_stacks(1)[1].get("venom", 0)) == 0,
		"the undead and constructs take no venom")
	_ok(GameData.CREATURES["scorpion_guardian"]["abilities"].has("two_retaliations"), "Scorpion Guardians strike back twice")

func _deflector() -> void:
	var a := _battle([{"id": "archer", "count": 20}], [{"id": "swordsman", "count": 10}])
	var b := _battle([{"id": "archer", "count": 20}], [{"id": "sharur", "count": 10}])
	var sw := a.damage_range(a.alive_stacks(0)[0], a.alive_stacks(1)[0], true)
	var sh := b.damage_range(b.alive_stacks(0)[0], b.alive_stacks(1)[0], true)
	# (Swordsmen and Sharur have nearly the same Defense: 12 and 11; the shot at Sharur is halved)
	_ok(sh[1] < sw[1] * 0.6, "shots at Sharur are halved (%s vs %s)" % [sh, sw])
	var m := b.damage_range(b.alive_stacks(1)[0], b.alive_stacks(0)[0], false)
	_ok(m[0] > 0, "Sharur strikes in melee as usual")
	var c := _battle([{"id": "pikeman", "count": 20}], [{"id": "sharur", "count": 10}])
	var c2 := _battle([{"id": "pikeman", "count": 20}], [{"id": "swordsman", "count": 10}])
	_ok(c.damage_range(c.alive_stacks(0)[0], c.alive_stacks(1)[0], false)[1] >= c2.damage_range(c2.alive_stacks(0)[0], c2.alive_stacks(1)[0], false)[1],
		"melee at Sharur is not halved")

func _dispel() -> void:
	var L := _battle([{"id": "abgal", "count": 10}], [{"id": "lamassu", "count": 10}])
	var t: Dictionary = L.alive_stacks(1)[0]
	t["effects"] = {"bless": 3, "haste": 3, "shield": 3, "slow": 2}
	L.do_shoot(L.alive_stacks(0)[0], t)
	_ok(not t["effects"].has("bless") and not t["effects"].has("haste") and not t["effects"].has("shield") and t["effects"].has("slow"),
		"an Abgal's shot dispels the helpful spells, not the harmful (%s)" % [t["effects"]])
	var A := _battle([{"id": "apkallu", "count": 10}], [{"id": "lamassu", "count": 10}])
	var t2: Dictionary = A.alive_stacks(1)[0]
	t2["effects"] = {"bless": 3}
	A.do_shoot(A.alive_stacks(0)[0], t2)
	_ok(t2["effects"].has("bless"), "an Apkallu's does not")

func _sweep() -> void:
	var L := _battle([{"id": "lamassu", "count": 5}], [{"id": "pikeman", "count": 20}, {"id": "archer", "count": 20}, {"id": "monk", "count": 20}])
	var lam: Dictionary = L.alive_stacks(0)[0]
	lam["hex"] = Vector2i(7, 5)
	var e := L.alive_stacks(1)
	# two enemies beside it, one away
	var spots := []
	for c in L.cells(lam):
		for n in BattleLogic.neighbors(c):
			if L.is_free(n) and not n in spots:
				spots.append(n)
	e[0]["hex"] = spots[0]
	e[1]["hex"] = spots[spots.size() - 1]
	e[2]["hex"] = Vector2i(1, 9)
	var before := e.map(func(o): return L.total_hp(o))
	var ev := L.do_melee(lam, e[0], lam["hex"])
	_ok(L.total_hp(e[0]) < before[0] and L.total_hp(e[1]) < before[1] and L.total_hp(e[2]) == before[2],
		"a Lamassu strikes every enemy beside it, and no other (%s -> %s)" % [before, e.map(func(o): return L.total_hp(o))])
	var rets := ev.filter(func(x): return x["t"] == "attack" and x["retaliation"])
	_ok(rets.size() == 1 and rets[0]["a"] == e[0], "only the one attacked strikes back")
	_ok(ev.filter(func(x): return x["t"] == "attack" and x.get("sweep", false)).size() == 1, "the others' blow is marked for the screen")
	var victims := L.sweep_victims(lam, e[0])
	_ok(victims.size() == 1 and victims[0] == e[1], "the AI sees whom the sweep reaches")
	var dec := BattleAI.decide(L, lam)
	_ok(dec.get("type", "") in ["melee", "move", "defend", "wait"], "the battle AI decides with sweep (%s)" % dec.get("type", ""))

func _constructs() -> void:
	var L := _battle([{"id": "sharur", "count": 5}, {"id": "lamassu", "count": 2}, {"id": "pikeman", "count": 5}, {"id": "skeleton", "count": 5}],
		[{"id": "pikeman", "count": 10}], ["blind"])
	var sh: Dictionary = L.alive_stacks(0)[0]
	var la: Dictionary = L.alive_stacks(0)[1]
	_ok(L.morale(0, sh) == 0 and L.morale(0, la) == 0 and L.morale(0, L.alive_stacks(0)[2]) < 0, "constructs feel no morale")
	_ok(not L.living(sh) and not L.living(la), "and are not living (Death Ripple, mind spells pass them)")
	_ok(L.stack_immune(sh, "blind"), "Blind cannot touch them")
	var A := _battle([{"id": "anzu", "count": 1}], [{"id": "pikeman", "count": 10}, {"id": "pikeman", "count": 10}])
	_ok(A.has_ab(A.alive_stacks(0)[0], "breath") and GameData.CREATURES["shargaz"]["abilities"].has("breath"),
		"Anzu's storm and Shargaz's beam strike the stack behind (the Dragons' breath)")

func _house_of_me() -> void:
	var w := WorldGen.generate({"seed": 6890, "map_size": 48, "faction": "eridu", "opponents": 1})
	GameState.world = w
	var rules := AdvRules.new(w)
	var me: Dictionary = w["players"][0]
	_ok(me["faction"] == "eridu" and w["towns"][me["towns"][0]]["faction"] == "eridu", "a new game can be played as Eridu")
	var town: Dictionary = w["towns"][me["towns"][0]]
	var hero: Dictionary = w["heroes"][me["heroes"][0]]
	hero["pos"] = town["pos"]
	rules.rebuild()
	hero["artifacts"] = ["sword_of_valor"]
	hero["backpack"] = ["soldiers_shortsword", "dragonbone_blade", "banner_of_the_muster"]
	var cmd := {"t": "offer_me", "p": 0, "hero": hero["uid"], "town": town["uid"], "artifact": "sword_of_valor"}
	_ok(not rules.do(cmd)["ok"], "no House of the Me: nothing to give")
	town["buildings"] += ["mage_guild_1", "house_of_me"]
	var res: Dictionary = me["resources"]
	var gold: int = res["gold"]
	var crystal: int = res["crystal"]
	var r := rules.do(cmd)
	_ok(r["ok"] and r["paid"] == {"crystal": 4, "gold": 1000} and res["gold"] == gold + 1000 and res["crystal"] == crystal + 4
		and not "sword_of_valor" in hero["artifacts"], "a minor artifact worn: 4 crystal and 1000 gold (%s)" % [r])
	cmd["artifact"] = "banner_of_the_muster"
	_ok(rules.do(cmd).get("paid", {}) == {"crystal": 10, "gold": 4000} and not "banner_of_the_muster" in hero["backpack"], "a relic carried: 10 and 4000")
	cmd["artifact"] = "dragonbone_blade"
	_ok(not rules.do(cmd)["ok"] and "dragonbone_blade" in hero["backpack"], "a set's piece cannot be given up")
	_ok(AdvRules.me_tribute("dragonheart_arms").is_empty(), "nor a combination")
	cmd["artifact"] = "ogre_hewn_cleaver"
	_ok(not rules.do(cmd)["ok"], "nor what the hero does not have")
	_ok(TownLogic.build_block_reason(TownLogic.make_town("haven", 0, Vector2i.ZERO, "Acre", true),
		{"resources": {"gold": 99999, "crystal": 99}}, "house_of_me") == "Not in this town", "not in the Temple's towns")
	# the computer gives up what it only carries
	var ai := AdvAI.new(rules)
	hero["backpack"] = ["soldiers_shortsword", "dragonbone_blade"]
	hero["artifacts"] = ["shield_of_dawn"]
	ai.offer_spares(hero, town)
	_ok(hero["backpack"] == ["dragonbone_blade"] and hero["artifacts"] == ["shield_of_dawn"], "the computer offers its spares, keeps what it wears (%s)" % [hero["backpack"]])

func _gate() -> void:
	var w := WorldGen.generate({"seed": 6891, "map_size": 48, "faction": "eridu", "opponents": 1})
	GameState.world = w
	var rules := AdvRules.new(w)
	var me: Dictionary = w["players"][0]
	var a: Dictionary = w["towns"][me["towns"][0]]
	var b := {}
	for t in w["towns"].values():
		if t["uid"] != a["uid"] and t["owner"] != 0 and rules.hero_at(t["pos"]).is_empty():
			b = t
			break
	_ok(not b.is_empty(), "a second town to take")
	if b.is_empty():
		return
	rules.capture_town(b, 0)
	b["faction"] = "eridu"
	var hero: Dictionary = w["heroes"][me["heroes"][0]]
	hero["pos"] = a["pos"]
	rules.rebuild()
	var cmd := {"t": "gate", "p": 0, "hero": hero["uid"], "town": a["uid"], "to": b["uid"]}
	_ok(not rules.do(cmd)["ok"], "no Dur-An-Ki: the hero cannot pass")
	var p := {"resources": {"gold": 99999, "wood": 99, "ore": 99, "mercury": 99, "sulfur": 99, "crystal": 99, "gems": 99}}
	_ok(TownLogic.build_block_reason(a, p, "dur_an_ki").begins_with("Requires"), "the Dur-An-Ki needs the Citadel")
	for t in [a, b]:
		t["buildings"] += ["fort", "citadel", "dur_an_ki"]
	_ok(rules.gate_towns(hero, a) == [b], "the other town with one is offered")
	var other := GameState.make_hero("ninurta", 0)
	w["heroes"][other["uid"]] = other
	other["pos"] = b["pos"]
	rules.rebuild()
	_ok(rules.gate_towns(hero, a).is_empty() and not rules.do(cmd)["ok"], "not while a hero stands in its gate")
	w["heroes"].erase(other["uid"])
	rules.rebuild()
	hero["movement"] = 777
	var r := rules.do(cmd)
	_ok(r["ok"] and hero["pos"] == b["pos"] and hero["movement"] == 777, "the hero passes, its movement kept (HoMM3)")
	_ok(rules.hero_at(b["pos"]) == hero and rules.hero_at(a["pos"]).is_empty(), "the map knows where it stands")
	_ok(rules.is_explored(me, b["pos"]), "and sees around it")
	_ok(rules.gate_towns(hero, b) == [a], "and can pass back")
	# the computer passes to hold a threatened town
	var ai := AdvAI.new(rules)
	hero["pos"] = a["pos"]
	rules.rebuild()
	var enemy: Dictionary = w["heroes"][w["players"][1]["heroes"][0]]
	enemy["army"] = [{"id": "pikeman", "count": 60}, null, null, null, null, null, null]
	enemy["pos"] = b["pos"] + Vector2i(2, 2)
	enemy["movement"] = 1500
	enemy["max_movement"] = 1500
	hero["army"] = [{"id": "lamassu", "count": 20}, null, null, null, null, null, null]
	b["garrison"] = [null, null, null, null, null, null, null]
	rules.rebuild()
	var threat := ai._town_threat(b)
	_ok(threat > 0.0, "the raider threatens the far town (%.0f)" % threat)
	_ok(ai._gate_defense(hero) and hero["pos"] == b["pos"], "the computer passes the Dur-An-Ki to hold it")
	_ok(not ai._gate_defense(hero), "once a day")

func _town() -> void:
	_ok(GameData.building_name("eridu", "mage_guild_1") == "Ziggurat" and GameData.building_name("eridu", "mage_guild_3") == "Ziggurat Lv3"
		and GameData.building_name("haven", "mage_guild_1") == "Mage Guild", "the Mage Guild is the Ziggurat in Eridu's towns")
	_ok(not GameData.in_faction("eridu", "mage_guild_5") and GameData.in_faction("eridu", "mage_guild_4"), "to the fourth level")
	_ok(GameData.dwelling_name("eridu", 7) == "Anzu's Eyrie", "its dwellings' names")
	var order := AdvAI.build_order("eridu")
	_ok("house_of_me" in order and "dur_an_ki" in order and order.find("dur_an_ki") > order.find("castle"), "the computer builds both specials")
	_ok(GameData.FACTIONS["eridu"].get("spell_look", "") == "eridu", "its heroes' spells look their own")
	var B = load("res://scripts/battle/battle.gd")
	for fx in ["arcane", "spark", "fire", "frost", "holy", "dark"]:
		_ok(Assets.has("battle/fx_%s_eridu.png" % fx), "Eridu's %s spell effect painted" % fx)
	_ok(B.SPELL_GLOW.has("eridu"), "and its bolts' light")

func _art() -> void:
	for id in GameData.FACTIONS["eridu"]["creatures"] + GameData.FACTIONS["eridu"]["upgrades"]:
		for p in ["creatures/%s.png", "creatures/portraits/%s.png", "creatures/%s_attack.png", "creatures/%s_hit.png",
				"creatures/%s_dead.png", "creatures/%s_move0.png"]:
			_ok(Assets.has(p % id), "%s painted" % (p % id))
	for hid in GameData.HEROES:
		if GameData.HEROES[hid]["faction"] == "eridu":
			_ok(Assets.has("heroes/portraits/%s.png" % hid), "%s's portrait" % hid)
	for p in ["heroes/map_eridu.png", "heroes/map_eridu_run0.png", "heroes/battle_eridu.png", "heroes/battle_eridu_cast.png",
			"heroes/battle_eridu_idle0.png", "heroes/map_keeper.png", "heroes/battle_keeper.png",
			"map/town_eridu.png", "map/town_eridu_fort.png", "map/town_eridu_village.png",
			"town/eridu_bg.png", "town/layout_eridu.json", "battle/bg_siege_eridu_1.png", "battle/bg_siege_eridu_3.png",
			"audio/music/town_eridu.mp3", "icons/building_eridu_house_of_me.png", "icons/building_eridu_dur_an_ki.png",
			"icons/building_eridu_dwelling_7.png", "icons/skill_shaping.png"]:
		_ok(Assets.has(p), "%s made" % p)
	var lay = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town/layout_eridu.json")) if Assets.has("town/layout_eridu.json") else {}
	for b in ["village_hall", "town_hall", "city_hall", "capitol", "fort", "citadel", "castle", "tavern", "marketplace",
			"mage_guild_1", "mage_guild_2", "blacksmith", "house_of_me", "dur_an_ki"] \
			+ range(1, 8).map(func(i): return "dwelling_%d" % i):
		_ok(lay is Dictionary and lay.has(b) and Assets.has("town/eridu_%s.png" % b), "the town screen has its %s" % b)
