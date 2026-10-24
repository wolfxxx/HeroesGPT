extends Node
## Good morale in a played battle (battle.gd `_carry`): two computer-led armies with Leadership 3 (+3 morale, 1 in 8
## per action) fight on the real battle screen. Both sides must win extra actions (the computer never had them
## before session67), each by the stack that has just moved or attacked, and never twice in a round for one stack.
##   Godot --headless --path . res://tools/battle_morale_test.tscn

var checks := 0
var failures := 0

func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL ", what)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	GameState._uid = 1000
	var a := GameState.make_hero("sir_aldric", 0)
	var d := GameState.make_hero("lord_gareth", 1)
	a["army"] = [{"id": "pikeman", "count": 40}, {"id": "archer", "count": 20}, {"id": "griffin", "count": 10},
		{"id": "swordsman", "count": 8}, {"id": "monk", "count": 5}, null, null]
	d["army"] = [{"id": "pikeman", "count": 40}, {"id": "archer", "count": 20}, {"id": "griffin", "count": 10},
		{"id": "swordsman", "count": 8}, {"id": "monk", "count": 5}, null, null]
	for h in [a, d]:
		h["skills"]["leadership"] = 3
		h["spells"] = []
	GameState.battle_speed = 8.0
	GameState.pending_battle = {"attacker_army": a["army"], "defender_army": d["army"], "attacker_hero": a,
		"defender_hero": d, "terrain": "grass", "attacker_player": 0, "defender_player": 1, "attacker_ai": true,
		"defender_ai": true, "seed": 777, "context": {"type": "test"}}
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	var L: BattleLogic = battle.L
	# each good morale, as it is won: the stack whose turn the screen is showing (the one that has just acted) must
	# be the one named and marked
	var again := []   # [round, uid, side]
	var wrong := 0
	var t0 := Time.get_ticks_msec()
	var last_log := 0
	while L.is_over() < 0 and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
		for i in range(last_log, L.log_lines.size()):
			if "with courage" in L.log_lines[i]:
				var st: Dictionary = battle._stack(battle._acting_uid)
				if st.is_empty() or not st.get("morale_turn", false) or not L.log_lines[i].begins_with(L._name(st)):
					wrong += 1
				else:
					again.append([L.round_num, st["uid"], st["side"]])
		last_log = L.log_lines.size()
	_ok(wrong == 0, "each good morale goes to the stack that has just acted (%d wrong)" % wrong)
	_ok(L.is_over() >= 0, "the battle ends")
	var sides := [0, 0]
	for g in again:
		if g[2] >= 0:
			sides[g[2]] += 1
	print("  good morale: attacker %d, defender %d, over %d rounds" % [sides[0], sides[1], L.round_num])
	_ok(sides[0] > 0, "the attacking computer's stacks win good morale")
	_ok(sides[1] > 0, "the defending computer's stacks win good morale")
	var per_round := {}
	for g in again:
		var k := "%d/%d" % [g[0], g[1]]
		per_round[k] = per_round.get(k, 0) + 1
	_ok(per_round.values().all(func(n): return n == 1), "never twice in a round for one stack")
	print("BATTLE MORALE TEST: %d checks, failures: %d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
