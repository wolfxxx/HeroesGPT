extends Node
## Tactical regressions: check the chosen action against actual combat outcomes, with fixed layouts.
var checks := 0
var fails := 0

func _ready() -> void:
	_area()
	_cloud()
	_advance()
	print("BATTLE AI TEST: %d checks, failures: %d" % [checks, fails])
	get_tree().quit(1 if fails else 0)

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("FAIL ", label)

func _battle(attackers: Array, defenders: Array, spells: Array = []) -> BattleLogic:
	var hero := GameState.make_hero("sir_aldric", 0)
	hero["spells"] = spells
	hero["mana"] = 100
	hero["artifacts"] = []
	hero["machines"] = []
	var L := BattleLogic.new()
	L.setup({"attacker_army": attackers, "defender_army": defenders, "attacker_hero": hero, "seed": 47})
	L.obstacles.clear()
	return L

func _area() -> void:
	var L := _battle([{"id": "pikeman", "count": 30}],
		[{"id": "skeleton", "count": 50}, {"id": "skeleton", "count": 50}], ["fireball"])
	var enemies := L.alive_stacks(1)
	enemies[0]["hex"] = Vector2i(8, 5)
	enemies[1]["hex"] = Vector2i(10, 5)
	var spell := BattleAI.decide_spell(L, 0)
	_ok(not spell.is_empty(), "casts when two enemy stacks can be hit")
	if spell.is_empty():
		return
	_ok(L.spell_target_ok(0, spell["spell"], spell["hex"]), "area target is legal")
	_ok(L.stack_at(spell["hex"]) == null, "aims between enemies instead of at one of them")
	var event: Dictionary = L.cast(0, spell["spell"], spell["hex"])[0]
	_ok(event["targets"].size() == 2 and event["dmg"].size() == 2, "actual cast damages both enemies")
	# The same blast must be rejected when it would destroy a more valuable ally.
	L.hero_cast[0] = false
	var ally: Dictionary = L.alive_stacks(0)[0]
	ally["id"] = "angel"
	ally["count"] = 1
	ally["hp_top"] = 1
	ally["hex"] = Vector2i(9, 5)
	spell = BattleAI.decide_spell(L, 0)
	_ok(not spell.is_empty(), "finds an alternative blast clear of the vulnerable ally")
	if not spell.is_empty():
		event = L.cast(0, spell["spell"], spell["hex"])[0]
		_ok(not event["targets"].has(ally), "actual alternative cast spares the ally")
	# Insufficient mana must never produce an action.
	L.hero_cast[0] = false
	L.heroes[0]["mana"] = 0
	_ok(BattleAI.decide_spell(L, 0).is_empty(), "cannot cast without mana")

func _cloud() -> void:
	for friend_id in ["angel", "bone_dragon"]:
		var L := _battle([{"id": "lich", "count": 10}, {"id": friend_id, "count": 10}],
			[{"id": "archer", "count": 30}, {"id": "archer", "count": 30}])
		var lich: Dictionary = L.alive_stacks(0)[0]
		var ally: Dictionary = L.alive_stacks(0)[1]
		var enemies := L.alive_stacks(1)
		lich["hex"] = Vector2i(3, 5)
		enemies[0]["hex"] = Vector2i(8, 5)
		enemies[1]["hex"] = Vector2i(8, 1)
		ally["hex"] = Vector2i(9, 6)
		var action := BattleAI.decide(L, lich)
		_ok(action["type"] == "shoot", "Lich chooses a shot with " + friend_id)
		if action["type"] != "shoot":
			continue
		if friend_id == "angel":
			_ok(action["target"] == enemies[1], "avoids death cloud against a living ally")
		else:
			_ok(action["target"] == enemies[0], "undead ally does not discourage a safe death cloud")
		var hp := L.total_hp(ally)
		L.do_shoot(lich, action["target"])
		_ok(L.total_hp(ally) == hp, "actual shot spares " + friend_id)

func _advance() -> void:
	var L := _battle([{"id": "pikeman", "count": 10}], [{"id": "skeleton", "count": 10}])
	# Neither side can shoot. Repeated waiting outside melee reach used to deadlock mirror AIs.
	for step in 60:
		if L.is_over() >= 0:
			break
		var stack: Dictionary = L.current()
		var action := BattleAI.decide(L, stack)
		match action["type"]:
			"melee": L.do_melee(stack, action["target"], action["from"])
			"move": L.do_move(stack, action["hex"])
			"wait": L.do_wait(stack)
			_: L.do_defend(stack)
	_ok(L.is_over() >= 0, "melee armies approach each other and finish without ranged support")
	L = _battle([{"id": "pikeman", "count": 10}], [{"id": "pikeman", "count": 10}])
	var attacker: Dictionary = L.alive_stacks(0)[0]
	var defender: Dictionary = L.alive_stacks(1)[0]
	attacker["hex"] = Vector2i(4, 5)
	defender["hex"] = Vector2i(10, 5)
	L._deploy_machine("ballista", 0, Vector2i(-1, 2))
	L._deploy_machine("ballista", 1, Vector2i(15, 2))
	L.round_num = 9
	var action := BattleAI.decide(L, attacker)
	_ok(action["type"] == "move" and L.distance(action.get("hex", attacker["hex"]), defender["hex"]) < 5,
		"commits after prolonged ranged standoff instead of waiting forever")
