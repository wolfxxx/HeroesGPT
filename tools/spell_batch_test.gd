extends Node
## The spells added in session67 (Chain Lightning, Armageddon, Implosion, Blind, Berserk) and where they are learned
## (the Order's fifth Mage Guild level, Pyramids, shrines only up to level 3), on fixed battle layouts.
##   Godot --headless --path . res://tools/spell_batch_test.tscn      (in the suite)
var checks := 0
var fails := 0

func _ready() -> void:
	_data()
	_chain()
	_armageddon()
	_implosion()
	_blind()
	_berserk()
	_ai()
	_guild()
	_map()
	print("SPELL BATCH TEST: %d checks, failures: %d" % [checks, fails])
	get_tree().quit(1 if fails else 0)

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("FAIL ", label)

func _battle(attackers: Array, defenders: Array, spells: Array) -> BattleLogic:
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
	var want := {"chain_lightning": [4, "air", 24], "armageddon": [4, "fire", 24], "implosion": [5, "earth", 30],
		"blind": [2, "fire", 10], "berserk": [4, "fire", 20]}
	for id in want:
		var d: Dictionary = GameData.SPELLS.get(id, {})
		_ok([d.get("level"), d.get("school"), d.get("mana")] == want[id], "%s: level, school and mana as HoMM3 (%s)" % [id, [d.get("level"), d.get("school"), d.get("mana")]])
		_ok(Assets.has("icons/spell_%s.png" % id), "%s has its spellbook picture" % id)

## Three enemy stacks and one of ours in a line: the bolt strikes the target, then the nearest each time, ours too,
## halving at every jump.
func _chain() -> void:
	var L := _battle([{"id": "pikeman", "count": 20}], [{"id": "archer", "count": 20}, {"id": "archer", "count": 20},
		{"id": "archer", "count": 20}], ["chain_lightning"])
	var e := L.alive_stacks(1)
	var mine: Dictionary = L.alive_stacks(0)[0]
	e[0]["hex"] = Vector2i(6, 5)
	e[1]["hex"] = Vector2i(9, 5)
	e[2]["hex"] = Vector2i(14, 2)
	mine["hex"] = Vector2i(4, 5)
	var order := L.chain_targets(e[0], "chain_lightning")
	_ok(order == [e[0], mine, e[1], e[2]], "the chain jumps to the nearest stack each time, ours included (%s)" % [order.map(func(s): return s["hex"])])
	var full := L.spell_damage_to(0, "chain_lightning", e[0])
	_ok(full == 25 + 40 * L.spell_power(0), "the first strike deals 25 + 40 x Power (%d)" % full)
	var ev: Dictionary = L.cast(0, "chain_lightning", e[0]["hex"])[0]
	_ok(ev["targets"].size() == 4, "four stacks struck")
	_ok(ev["dmg"][e[0]["uid"]] == full and ev["dmg"][mine["uid"]] == full / 2 and ev["dmg"][e[1]["uid"]] == full / 4
		and ev["dmg"][e[2]["uid"]] == full / 8, "each jump at half the one before (%s)" % [ev["dmg"].values()])

func _armageddon() -> void:
	var L := _battle([{"id": "pikeman", "count": 50}, {"id": "skeleton", "count": 50}], [{"id": "archer", "count": 50}],
		["armageddon"])
	L.stacks.append(L._deploy_machine("ballista", 1, Vector2i(15, 3)))
	_ok(L.spell_target_ok(0, "armageddon", Vector2i(0, 0)), "Armageddon needs no target")
	var ev: Dictionary = L.cast(0, "armageddon", Vector2i(7, 5))[0]
	var hit: Array = ev["targets"].map(func(s): return s["id"])
	hit.sort()
	_ok(hit == ["archer", "pikeman", "skeleton"], "it strikes every creature, both sides, the undead too, not war machines (%s)" % [hit])
	_ok(ev["dmg"].values().all(func(v): return v == 30 + 50 * L.spell_power(0)), "30 + 50 x Power each")

func _implosion() -> void:
	var L := _battle([{"id": "pikeman", "count": 1}], [{"id": "bone_dragon", "count": 5}], ["implosion"])
	var d: Dictionary = L.alive_stacks(1)[0]
	var ev: Dictionary = L.cast(0, "implosion", d["hex"])[0]
	_ok(ev["dmg"][d["uid"]] == 100 + 75 * L.spell_power(0), "Implosion deals 100 + 75 x Power to its target")

func _blind() -> void:
	var L := _battle([{"id": "swordsman", "count": 30}], [{"id": "pikeman", "count": 40}, {"id": "skeleton", "count": 40},
		{"id": "gold_golem", "count": 5}], ["blind"])
	var e := L.alive_stacks(1)
	_ok(L.spell_target_ok(0, "blind", e[0]["hex"]), "a living creature can be blinded")
	_ok(not L.spell_target_ok(0, "blind", e[1]["hex"]) and not L.spell_target_ok(0, "blind", e[2]["hex"]),
		"the undead and the ushabti cannot (a mind spell)")
	L.cast(0, "blind", e[0]["hex"])
	_ok(L.spell_lost_turn(e[0]) == "blind", "a blinded stack loses its turn")
	var sw: Dictionary = L.alive_stacks(0)[0]
	e[0]["hex"] = Vector2i(8, 5)
	sw["hex"] = Vector2i(7, 5)
	var top: int = L.damage_range(e[0], sw, false)[1]
	var ev := L.do_melee(sw, e[0], sw["hex"])
	var ret := ev.filter(func(x): return x["t"] == "attack" and x["retaliation"])
	_ok(L.spell_lost_turn(e[0]) == "", "struck, it wakes")
	_ok(ret.size() == 1 and ret[0]["dmg"] <= ceili(top * 0.5 * (2 if ret[0]["lucky"] else 1)),
		"and strikes back at half damage (%s, full at most %d)" % [ret.map(func(x): return x["dmg"]), top])

## A berserk enemy goes for the nearest stack: its own beside it; the spell ends once it has struck. A berserk shooter
## with nothing beside it shoots the nearest.
func _berserk() -> void:
	var L := _battle([{"id": "pikeman", "count": 30}], [{"id": "swordsman", "count": 20}, {"id": "monk", "count": 20}],
		["berserk"])
	var e := L.alive_stacks(1)
	var mine: Dictionary = L.alive_stacks(0)[0]
	e[0]["hex"] = Vector2i(10, 5)
	e[1]["hex"] = Vector2i(11, 5)
	mine["hex"] = Vector2i(2, 5)
	_ok(L.berserk_action(e[0]).is_empty(), "no forced action without the spell")
	L.cast(0, "berserk", e[0]["hex"])
	var act := L.berserk_action(e[0])
	_ok(act.get("type") == "melee" and act.get("target") == e[1], "it attacks its own stack beside it (%s)" % [act.get("type")])
	var before: int = e[1]["count"]
	L.do_melee(e[0], act["target"], act["from"])
	_ok(e[1]["count"] < before, "which loses creatures")
	_ok(not e[0]["effects"].has("berserk"), "and the spell ends")
	# the monks (shooters), alone: they shoot the nearest stack
	e[0]["alive"] = false
	e[1]["effects"]["berserk"] = 2
	act = L.berserk_action(e[1])
	_ok(act.get("type") == "shoot" and act.get("target") == mine, "a berserk shooter shoots the nearest stack")
	var undead := _battle([{"id": "pikeman", "count": 1}], [{"id": "vampire", "count": 5}], ["berserk"])
	_ok(not undead.spell_target_ok(0, "berserk", undead.alive_stacks(1)[0]["hex"]), "the undead cannot be sent berserk")

func _ai() -> void:
	# the computer will not chain lightning into a valuable stack of its own
	var L := _battle([{"id": "angel", "count": 3}], [{"id": "pikeman", "count": 10}, {"id": "pikeman", "count": 10}],
		["chain_lightning"])
	var e := L.alive_stacks(1)
	var mine: Dictionary = L.alive_stacks(0)[0]
	e[0]["hex"] = Vector2i(8, 5)
	e[1]["hex"] = Vector2i(14, 9)
	mine["hex"] = Vector2i(9, 5)
	var sp := BattleAI.decide_spell(L, 0)
	_ok(sp.is_empty() or L.chain_targets(L.stack_at(sp["hex"]), "chain_lightning")[1] != mine,
		"the computer's chain does not jump straight onto its angels")
	# nor Armageddon when it would burn more of its own
	L = _battle([{"id": "angel", "count": 5}], [{"id": "pikeman", "count": 3}], ["armageddon"])
	_ok(BattleAI.decide_spell(L, 0).is_empty(), "no Armageddon that hurts it more than the enemy")
	L = _battle([{"id": "pikeman", "count": 3}], [{"id": "angel", "count": 5}], ["armageddon"])
	_ok(BattleAI.decide_spell(L, 0).get("spell", "") == "armageddon", "Armageddon when the enemy loses more")

func _guild() -> void:
	var t := TownLogic.make_town("necropolis", 0, Vector2i.ZERO, "Blackfen", true)
	t["buildings"].append("mage_guild_4")
	var p := {"resources": {"gold": 99999, "wood": 99, "ore": 99, "mercury": 99, "sulfur": 99, "crystal": 99, "gems": 99}}
	_ok(TownLogic.build_block_reason(t, p, "mage_guild_5") == "", "the Order can build a fifth Mage Guild level")
	TownLogic.build(t, p, "mage_guild_5")
	_ok(TownLogic.mage_guild_level(t) == 5 and "implosion" in t["mage_spells"], "level 5, and it teaches Implosion")
	var h := TownLogic.make_town("haven", 0, Vector2i.ZERO, "Acre", true)
	h["buildings"].append("mage_guild_4")
	_ok(TownLogic.build_block_reason(h, p, "mage_guild_5") == "Not in this town", "the Temple's stops at level 4")

func _map() -> void:
	var w := WorldGen.generate({"seed": 4242, "map_size": 72, "faction": "haven", "opponents": 1})
	var shrines := 0
	var high := 0
	for o in w["objects"].values():
		if o["type"] == "shrine":
			shrines += 1
			if GameData.SPELLS[o["spell"]]["level"] > 3:
				high += 1
		if o["type"] == "pyramid":
			_ok(GameData.SPELLS[o["spell"]]["level"] == 5, "the Pyramid teaches a level 5 spell (%s)" % o["spell"])
	_ok(shrines > 0 and high == 0, "shrines teach levels 1 to 3 only (%d shrines)" % shrines)
