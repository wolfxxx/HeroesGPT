extends Node
## HoMM3's Pyramid with its guards as the setting's ushabti (Gold and Diamond Golems): the creatures and their spell
## resistance, one Pyramid near the middle of medium and larger maps (none on small ones), the guard battle, the spell
## of the highest level learned or lost forever, the empty pyramid's -2 luck until the next battle, no Skeletons
## raised from statues, and the computer only going for it with an army well beyond its guards.
##   Godot_console.exe --headless --path . res://tools/pyramid_test.tscn  -> "PYRAMID TEST: N checks, failures: 0"

var checks := 0
var failures := 0

func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)

func _ready() -> void:
	# the creatures, as HoMM3's golems
	var g: Dictionary = GameData.CREATURES["gold_golem"]
	var d: Dictionary = GameData.CREATURES["diamond_golem"]
	_ok(g["attack"] == 11 and g["defense"] == 12 and g["dmg"] == [8, 10] and g["hp"] == 50 and g["speed"] == 5
		and g["spell_resist"] == 85, "the Gilded Ushabti has the Gold Golem's numbers")
	_ok(d["attack"] == 13 and d["defense"] == 12 and d["dmg"] == [10, 14] and d["hp"] == 60 and d["speed"] == 5
		and d["spell_resist"] == 95, "the Crystal Ushabti has the Diamond Golem's numbers")
	for id in ["gold_golem", "diamond_golem"]:
		for s in ["", "_attack", "_hit", "_dead", "_move0", "_move3"]:
			_ok(Assets.has("creatures/%s%s.png" % [id, s]), "%s%s sprite" % [id, s])
		_ok(Assets.has("creatures/portraits/%s.png" % id), "%s portrait" % id)

	# spells hurt them far less
	var L := BattleLogic.new()
	var a := GameState.make_hero("sir_aldric", 0)
	a["army"] = [{"id": "pikeman", "count": 10}, null, null, null, null, null, null]
	L.setup({"attacker_army": a["army"], "defender_army": [{"id": "gold_golem", "count": 5}, {"id": "diamond_golem", "count": 5},
		{"id": "skeleton", "count": 5}, null, null, null, null], "attacker_hero": a, "defender_hero": null, "seed": 1})
	var base := L.spell_damage(0, "lightning_bolt")
	for st in L.stacks:
		if st["side"] == 1:
			var expect: int = {"gold_golem": int(base * 0.15), "diamond_golem": int(base * 0.05), "skeleton": base}[st["id"]]
			_ok(L.spell_damage_to(0, "lightning_bolt", st) == expect, "%s takes %d of %d spell damage" % [st["id"], expect, base])

	# the map: one Pyramid near the middle of a medium map, none on a small one
	for size in [36, 48]:
		var s := GameState.new_game_settings.duplicate()
		s["seed"] = 12345
		s["map_size"] = size
		var w := WorldGen.generate(s)
		var pyrs: Array = w["objects"].values().filter(func(o): return o["type"] == "pyramid")
		if size == 36:
			_ok(pyrs.is_empty(), "no Pyramid on a small map")
			continue
		_ok(pyrs.size() == 1, "one Pyramid on a medium map")
		if pyrs.size() != 1:
			continue
		var o: Dictionary = pyrs[0]
		_ok(Vector2(o["pos"]).distance_to(Vector2(24, 24)) < 12.0, "near the middle: %s" % o["pos"])
		_ok(o["guards"] == WorldGen.PYRAMID_GUARDS and GameData.SPELLS[o["spell"]]["level"] == 4,
			"guarded by 40 Gilded and 2 x 10 Crystal Ushabtis, a level-4 spell inside")
		_play(w, o)

	get_tree().root.add_child.call_deferred(Walk.new(checks, failures))

func _play(w: Dictionary, o: Dictionary) -> void:
	GameState.world = w
	var rules := AdvRules.new(w)
	var h: Dictionary = w["heroes"][w["players"][0]["heroes"][0]]
	var setup := rules.battle_vs_site(h, o)
	var n := 0
	for st in setup["defender_army"]:
		if st:
			n += st["count"]
	_ok(n == 60 and setup["context"]["type"] == "site", "the battle is against its sixty guards")
	# the computer stays away while its army is weaker
	var ai := AdvAI.new(rules)
	_ok(ai._object_value(h, w["players"][0], o, 1000.0) == 0.0, "the computer leaves it alone with a small army")
	h["skills"]["wisdom"] = 2
	_ok(ai._object_value(h, w["players"][0], o, 200000.0) > 0.0, "and goes for it with a great one")
	# a lost battle leaves the survivors; a won one clears the guards
	rules.apply_battle({"winner": "defender", "attacker_army": h["army"], "defender_army": [{"id": "gold_golem", "count": 31}, null, null, null, null, null, null],
		"xp": 0, "retreated": true, "fled": 0, "context": {"type": "site", "hero": -1, "object": o["uid"]}})
	_ok(o["guards"] == [{"id": "gold_golem", "count": 31}], "a lost battle leaves the survivors on guard")
	rules.apply_battle({"winner": "attacker", "attacker_army": h["army"], "defender_army": [null, null, null, null, null, null, null],
		"xp": 0, "context": {"type": "site", "hero": h["uid"], "object": o["uid"]}})
	_ok(o["guards"].is_empty(), "a won battle clears the guards")
	# the spell: too little wisdom loses it forever
	var sp: String = o["spell"]
	h["skills"]["wisdom"] = 0
	h["spells"].erase(sp)
	var ev := rules.visit(h, o)
	_ok(not sp in h["spells"] and o["spell"] == "" and ev["text"].contains("lost forever"), "without the wisdom, the spell is lost forever")
	# empty: -2 luck until the next battle
	ev = rules.visit(h, o)
	_ok(h.get("next_battle_luck", 0) == -2 and ev["text"].contains("-2 luck"), "searching it empty costs 2 luck")
	var bl := BattleLogic.new()
	bl.setup({"attacker_army": h["army"], "defender_army": [{"id": "pikeman", "count": 1}, null, null, null, null, null, null],
		"attacker_hero": h, "defender_hero": null, "seed": 1})
	_ok(bl.luck(0) == int(h["skills"].get("luck", 0)) + GameState.hero_stat(h, "luck") - 2, "in the next battle")
	rules.apply_battle({"winner": "attacker", "attacker_army": h["army"], "defender_army": [null, null, null, null, null, null, null],
		"xp": 0, "context": {"type": "demo", "hero": h["uid"]}})
	_ok(not h.has("next_battle_luck"), "and only that one")
	# with the wisdom, a fresh pyramid's spell is learned
	o["spell"] = sp
	h["skills"]["wisdom"] = 2
	ev = rules.visit(h, o)
	_ok(sp in h["spells"] and o["spell"] == "", "with Advanced Wisdom the spell is learned, once")
	# no Skeletons from statues
	var nec := GameState.make_hero("lord_morthis", 1)
	var r := Necromancy.calculate(nec, nec["army"], [{"id": "gold_golem", "count": 40}], 1)
	_ok(r["raised"] == 0, "Necromancy raises nothing from fallen ushabti")
	_ok(Lore.ENTRIES.has("site:pyramid"), "the Pyramid has its declassified line")


## On the map: a hero stepping onto a guarded Pyramid fights its guards (resolved at once, as for a computer player)
## and, having won, goes inside and learns the spell.
class Walk extends Node:
	var checks := 0
	var failures := 0
	func _init(c: int, f: int) -> void:
		checks = c
		failures = f
	func _ok(cond: bool, what: String) -> void:
		checks += 1
		if not cond:
			failures += 1
			print("FAIL: ", what)
	func _ready() -> void:
		var s := GameState.new_game_settings.duplicate()
		s["seed"] = 4242
		var w := WorldGen.generate(s)
		GameState.world = w
		var o: Dictionary = w["objects"].values().filter(func(x): return x["type"] == "pyramid")[0]
		var me: Dictionary = w["players"][0]  # (human while the map loads, so it plays no computer turn)
		var h: Dictionary = w["heroes"][me["heroes"][0]]
		h["army"] = [{"id": "archangel", "count": 40}, {"id": "champion", "count": 40}, null, null, null, null, null]
		h["skills"]["wisdom"] = 2
		h["pos"] = o["pos"]
		get_tree().change_scene_to_file("res://scenes/adventure.tscn")
		await get_tree().create_timer(2.0).timeout
		var adv = get_tree().current_scene
		me["is_ai"] = true  # (now the map is up: level-ups are chosen at once, as the garrison test does)
		var sp: String = o["spell"]
		await adv._interact_with(h, {"kind": "object", "uid": o["uid"]}, false)
		_ok(o["guards"].is_empty(), "on the map: the hero beats the guards")
		_ok(sp in h["spells"] and o["spell"] == "", "then goes inside and learns %s" % sp)
		print("PYRAMID TEST: %d checks, failures: %d" % [checks, failures])
		get_tree().quit()
