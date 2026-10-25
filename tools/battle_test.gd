extends Node
## Battle-rules soak test: AI against AI with every creature (large ones included), checking after every action
## that no two stacks share a hex, nobody stands on an obstacle, an intact wall or off the field, and the battle ends.
## From seed 20 on both sides have heroes with all their war machines; every third of those is a siege.
##   Godot_console.exe --headless --path . res://tools/battle_test.tscn

func _ready() -> void:
	var fails := 0
	var ends := 0
	for seed in 40:
		var armies := []
		for f in ["haven", "necropolis"]:
			var c: Array = GameData.FACTIONS[f]["creatures"]
			var a := []
			for i in 7:
				a.append({"id": c[(i + seed) % 7] if seed % 3 == 0 else c[i], "count": [30, 18, 9, 6, 4, 2, 1][i] + seed % 5})
			armies.append(a)
		var L := BattleLogic.new()
		var setup := {"attacker_army": armies[seed % 2], "defender_army": armies[1 - seed % 2], "seed": seed,
			"attacker_ai": true, "defender_ai": true}
		if seed >= 20:
			for k in 2:
				var h := GameState.make_hero(["sir_aldric", "lord_morthis"][k], k)
				h["machines"] = GameData.WAR_MACHINES.duplicate()
				setup["attacker_hero" if k == 0 else "defender_hero"] = h
			if seed % 3 == 0:
				setup["siege"] = 1 + seed % 3  # (fort, citadel, castle)
		L.setup(setup)
		var steps := 0
		while L.is_over() < 0 and steps < 600:
			steps += 1
			var s = L.current()
			if s != null and L.check_bad_morale(s):
				L.finish_turn(s)
				continue
			if s == null:
				break
			if s.get("machine", false):
				L.machine_act(s)
				continue
			var act := BattleAI.decide(L, s)
			match act["type"]:
				"shoot": L.do_shoot(s, act["target"])
				"melee": L.do_melee(s, act["target"], act["from"])
				"genie": L.genie_cast(s, act["target"])
				"move": L.do_move(s, act["hex"])
				"wait":
					if not L.do_wait(s):
						L.do_defend(s)
				_: L.do_defend(s)
			L.roll_good_morale(s)
			var err := _check(L)
			if err != "":
				print("FAIL seed %d step %d: %s" % [seed, steps, err])
				fails += 1
				break
		if L.is_over() >= 0:
			ends += 1
	fails += _siege_rules()
	fails += _speed_spells()
	print("BATTLE TEST: %d battles ended of 40, failures: %d" % [ends, fails])
	get_tree().quit()

func _check(L: BattleLogic) -> String:
	var seen := {}
	for s in L.alive_stacks():
		for c in L.cells(s):
			if not (BattleLogic.on_field(c) if s.get("machine", false) else BattleLogic.in_bounds(c)):
				return "%s off the field at %s" % [s["id"], c]  # (machines stand on the back rank)
			if L.obstacles.has(c):
				return "%s on an obstacle at %s" % [s["id"], c]
			if L.wall_blocks(c, s["side"]) and not s.get("tower", false):
				return "%s on an intact wall at %s" % [s["id"], c]
			if seen.has(c):
				return "%s and %s share %s" % [s["id"], seen[c], c]
			seen[c] = s["id"]
	return ""

## The fortification levels (as the classic): a Fort's wall has no moat and no towers for the catapult; a Citadel adds
## the moat; the corner towers (rows 0 and 10) never open a way through, standing or fallen, at any level, so with
## every stretch of wall still up nobody leaves except through the gate.
func _siege_rules() -> int:
	var fails := 0
	for level in [1, 2, 3]:
		var L := BattleLogic.new()
		L.setup({"attacker_army": [{"id": "pikeman", "count": 5}], "defender_army": [{"id": "cavalier", "count": 5}],
			"attacker_hero": GameState.make_hero("sir_aldric", 0), "seed": level, "siege": level})
		var problems := []
		if L.is_moat(Vector2i(BattleLogic.MOAT_X, 2)) != (level >= 2):
			problems.append("moat")
		for i in [0, 6]:
			if L.breakable(i) != (level >= 3):
				problems.append("tower %d breakable" % i)
		var catapult: Dictionary = L.stacks.filter(func(st): return st["id"] == "catapult")[0]
		for k in 60:
			L._catapult_shot(catapult)
		if level < 3 and (L.walls[0]["hp"] < 2 or L.walls[6]["hp"] < 2):
			problems.append("the catapult hit a wall end")
		for w in L.walls:
			w["hp"] = 0
		var cav: Dictionary = L.alive_stacks(1)[0]
		for r in [0, 10]:
			if not L.wall_blocks(Vector2i(BattleLogic.WALL_X, r), 1) or L.fits(cav, Vector2i(BattleLogic.WALL_X, r)):
				problems.append("a fallen corner on row %d lets a stack stand in it" % r)
		for w in L.walls:
			w["hp"] = 2
		L.walls[3]["kind"] = "wall"  # (the gate shut too: there must be no way out at all)
		for y in BattleLogic.ROWS:
			for x in range(BattleLogic.WALL_X + 1, BattleLogic.COLS):
				cav["hex"] = Vector2i(x, y)
				if not L.fits(cav, cav["hex"]):
					continue
				for oy in BattleLogic.ROWS:
					if L.path_to(cav, Vector2i(BattleLogic.MOAT_X - 1, oy)).size() > 0:
						problems.append("a way out from %s to row %d past a standing wall" % [cav["hex"], oy])
		for p in problems.slice(0, 3):
			print("FAIL siege level %d: %s" % [level, p])
		fails += mini(problems.size(), 1)
	return fails

## Slow and Haste in the middle of a round move the stacks yet to act (as the classic: a slowed stack acts later this
## round already); the stack acting now keeps its turn.
func _speed_spells() -> int:
	var L := BattleLogic.new()
	var h := GameState.make_hero("vesna_nightshade", 0)
	h["mana"] = 100
	L.setup({"attacker_army": [{"id": "angel", "count": 1}], "attacker_hero": h, "seed": 3,
		"defender_army": [{"id": "swordsman", "count": 5}, {"id": "griffin", "count": 5}, {"id": "pikeman", "count": 5}]})
	var ids := func(): return L.order.filter(func(st): return not st.get("machine", false)).map(func(st): return st["id"])
	var at := func(id: String) -> Vector2i: return L.stacks.filter(func(st): return st["id"] == id)[0]["hex"]
	var problems := []
	if ids.call() != ["angel", "griffin", "swordsman", "pikeman"]:
		problems.append("start order %s" % [ids.call()])
	L.cast(0, "slow", at.call("griffin"))  # (6 -> 5: level with the swordsmen, who stand in the first slot)
	if ids.call() != ["angel", "swordsman", "griffin", "pikeman"]:
		problems.append("after Slow %s" % [ids.call()])
	L.cast(0, "haste", at.call("pikeman"))  # (4 -> 7: ahead of everyone yet to act, not of the acting angel)
	if ids.call() != ["angel", "pikeman", "swordsman", "griffin"]:
		problems.append("after Haste %s" % [ids.call()])
	for p in problems:
		print("FAIL speed spells: %s" % p)
	return mini(problems.size(), 1)
