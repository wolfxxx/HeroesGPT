extends RefCounted
class_name Commands
## The command layer (docs/FOUNDATIONS_AUDIT.md, step 2): every action a player takes, by a person at a screen or by
## the computer, is a plain dictionary handed to AdvRules.do(cmd), which checks it against the rules, applies it and
## reports what happened. Commands hold only ids, numbers and strings, so they can be saved, replayed or sent over a
## network to a host that runs the game. Screens choose and show; the computer chooses; only commands change the world.
##
## Each command names its player ("p": player index). The result is {"ok": bool, "reason": String, ...}.
##   recruit_town  {p, town: uid, tier: 1-7, n, into: "town" (its army: a garrison hero's, else the garrison) | "garrison"}
##   recruit_site  {p, hero: uid, object: uid, n}       a map dwelling, into the visiting hero's army
##   recruit_portal {p, town: uid, n}                   what a Portal of Summoning has called, into the town's army
##   hire          {p, town: uid, hero_id}              a Tavern hero to the town's gate -> "hero": uid
##   trade         {p, give, get, n}                    at the market rate (TownLogic.market_rate) -> "got"
## Armies are named by reference: {"hero": uid} (its army) or {"town": uid} (its garrison). Two armies must stand
## together: the same army, a hero and a town it stands in (at the gate or in the garrison), or two heroes side by side.
##   stack_move    {p, from, si, to, ti, split: bool, swap: bool}
##                                                      the army bar's move: into an empty slot (or half of it, split),
##                                                      onto the same creature (merge) or another (swap; `swap` swaps
##                                                      two stacks of the same creature too); a hero's army is never
##                                                      emptied into another army
##   move_troops   {p, from, si, to, n}                 n creatures of a stack join the other army (its stack of that
##                                                      creature, else its first free slot)
##   upgrade_stack {p, town: uid, army, si}             in a town with the upgraded dwelling, at the upgrade price
##   step          {p, hero: uid, to: [x, y]}           one step to a neighbouring free tile, paying its cost
##                                                      (AdvRules.step_cost, as the route planner) and seeing around it;
##                                                      the screen walks a route one step at a time and handles what the
##                                                      hero meets (-> "cost")
##   end_turn      {p}                                  the next living player's turn; a new day when the round ends
##                                                      (-> "next", "day": AdvRules.new_day's report or {})
##   visit         {p, hero, object}                    the hero, standing on a map site, takes or uses it (not a
##                                                      monster, not a guarded Pyramid: those are fights) -> "event"
##                                                      (AdvRules.visit's report; its icons are textures, local only)
##   chest         {p, hero, choice: "gold" | "xp"}     the chest the hero just opened (its offer kept on the hero by
##                                                      `visit`) -> "levels"
##   capture       {p, hero, town}                      an enemy or neutral town with no garrison and no defender, at
##                                                      whose gate the hero stands
##   battle_result {p, result}                          a fought or resolved battle's outcome applied (AdvRules.
##                                                      apply_battle; the player whose turn it is) -> "event"
##   build         {p, town, building}                  TownLogic.build (its requirements, cost and one a day)
##   sleep         {p, hero, asleep: bool}              the hero sleeps (passed over by Next Hero) or wakes
##   town_visit    {p, hero, town}                      a hero in its own town learns the Mage Guild's spells and has
##                                                      its spell points restored -> "learned", "mana"
##   (build teaches a hero visiting the town a new Mage Guild's spells, hire the hired hero the town's: "learned")
##   enter_garrison {p, hero, town} / leave_garrison {p, town} / swap_garrison {p, town}
##                                                      the hero at the gate and the town's garrison hero (AdvRules)
##   equip         {p, hero, artifact, worn: bool}      a worn artifact to the backpack, or one from it put on
##   split_set     {p, hero, artifact}                  a worn combination parted into its pieces
##   join_set      {p, hero, artifact}                  a parted combination joined again (when all its pieces are worn)
##   give_artifact {p, hero, to: uid, artifact}         to the player's hero standing beside it
##   buy_machine   {p, hero, machine, town | object}    at the town's Blacksmith (its own machine) or a War Machine
##                                                      Factory the hero stands at (GameState.war_machine_reason)
##   transform     {p, town, army, si}                  the town's transforming building on a stack in it
##   offer_me      {p, hero, town, artifact}            Eridu's House of the Me: a hero in the town gives the artifact
##                                                      up for crystal and gold (AdvRules.offer_me) -> "paid"
##   gate          {p, hero, town, to: uid}             Eridu's Dur-An-Ki: the hero at the town's gate passes to the
##                                                      other town's (AdvRules.gate_jump), its movement kept
##   level_roll    {p, hero}                            the rules roll a pending level's stat and skill options (kept
##                                                      on the hero until chosen) -> "stat", "options"
##   level_up      {p, hero, skill}                     the rolled level taken, with one of its offered skills
## (Every action a player takes on the map and in towns is now a command: docs/FOUNDATIONS_AUDIT.md.)

const HIRE_COST := 2500

## A recorder (tools/replay_test.gd): while `log_world` is set, every command accepted on that world is appended to
## `log` as a deep copy taken before it was applied.
static var log: Array = []
static var log_world = null

static func run(rules: AdvRules, cmd: Dictionary) -> Dictionary:
	var rec = cmd.duplicate(true) if log_world != null and is_same(rules.world, log_world) else null
	# (online: a command accepted on this machine's world is passed on to the others, Net; not one that came from them)
	var net = cmd.duplicate(true) if Net.active and not Net.applying and is_same(rules.world, GameState.world) else null
	if net != null and Net.syncing:
		return _no("Waiting for the host's game.")
	var res := _run(rules, cmd)
	if rec != null and res["ok"]:
		log.append(rec)
	if net != null and res["ok"]:
		Net.send(net)
	return res

static func _run(rules: AdvRules, cmd: Dictionary) -> Dictionary:
	var w: Dictionary = rules.world
	var pi: int = int(cmd.get("p", -1))
	if pi < 0 or pi >= w["players"].size():
		return _no("No such player.")
	var player: Dictionary = w["players"][pi]
	# (a player acts on their own turn; a level gained in defence is taken at once, as the classic; a world without
	# turns, as a test's hand-built one, has no turn to keep)
	if (w.has("current_player") and int(w["current_player"]) != pi
			and not cmd.get("t", "") in ["level_roll", "level_up", "battle_result"]):
		return _no("Not your turn.")
	match cmd.get("t", ""):
		"recruit_town":
			return _recruit_town(rules, player, cmd)
		"recruit_site":
			return _recruit_site(rules, player, cmd)
		"recruit_portal":
			return _recruit_portal(rules, player, cmd)
		"hire":
			return _hire(rules, player, cmd)
		"trade":
			return _trade(player, cmd)
		"stack_move":
			return _stack_move(rules, player, cmd)
		"move_troops":
			return _move_troops(rules, player, cmd)
		"upgrade_stack":
			return _upgrade_stack(rules, player, cmd)
		"step":
			return _step(rules, player, cmd)
		"end_turn":
			return _end_turn(rules, player)
		"visit":
			return _visit(rules, player, cmd)
		"chest":
			return _chest(rules, player, cmd)
		"capture":
			return _capture(rules, player, cmd)
		"battle_result":
			return _battle_result(rules, player, cmd)
		"build":
			return _build(rules, player, cmd)
		"town_visit":
			return _town_visit(rules, player, cmd)
		"sleep":
			var sh := _hero_of(rules, player, cmd)
			if sh.is_empty():
				return _no("Not your hero.")
			if bool(cmd.get("asleep", true)):
				sh["asleep"] = true
			else:
				sh.erase("asleep")
			return {"ok": true, "reason": ""}
		"enter_garrison", "leave_garrison", "swap_garrison":
			return _garrison(rules, player, cmd)
		"equip", "split_set", "join_set", "give_artifact":
			return _artifact(rules, player, cmd)
		"buy_machine":
			return _buy_machine(rules, player, cmd)
		"hill_fort":
			return _hill_fort(rules, player, cmd)
		"transform":
			return _transform(rules, player, cmd)
		"offer_me":
			var town := _own_town(rules, player, cmd)
			var hero := _hero_of(rules, player, cmd)
			if town.is_empty() or hero.is_empty():
				return _no("Not your town.")
			var a: String = cmd.get("artifact", "")
			var why := rules.offer_me_reason(hero, town, a)
			return _no(why) if why != "" else {"ok": true, "reason": "", "paid": rules.offer_me(hero, town, a)}
		"gate":
			var town := _own_town(rules, player, cmd)
			var hero := _hero_of(rules, player, cmd)
			var to: Dictionary = rules.world["towns"].get(int(cmd.get("to", -1)), {})
			if town.is_empty() or hero.is_empty() or to.is_empty() or not rules.gate_jump(hero, town, to):
				return _no("The hero cannot pass there.")
			return {"ok": true, "reason": ""}
		"level_roll":
			return _level_roll(rules, player, cmd)
		"level_up":
			return _level_up(rules, player, cmd)
	return _no("Unknown command.")

static func _own_town(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var t: Dictionary = rules.world["towns"].get(int(cmd.get("town", -1)), {})
	return t if not t.is_empty() and t["owner"] == player["index"] else {}

static func _build(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var town := _own_town(rules, player, cmd)
	var id: String = cmd.get("building", "")
	if town.is_empty() or not GameData.BUILDINGS.has(id):
		return _no("Not your town.")
	var why := TownLogic.build_block_reason(town, player, id)
	if why != "" or not TownLogic.build(town, player, id):
		return _no(why if why != "" else "Cannot build that.")
	if TownLogic.effect(town, "portal") > 0 and town.get("portal", {}).is_empty():
		rules.summon_portal(town)  # (a new Portal of Summoning calls its first creatures at once)
	var learned := []
	var vh := rules.visiting_hero(town)  # (a new Mage Guild teaches the hero visiting the town at once)
	if id.begins_with("mage_guild") and not vh.is_empty():
		learned = rules.learn_guild(vh, town)
	return {"ok": true, "reason": "", "learned": learned}

static func _town_visit(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var town := _own_town(rules, player, cmd)
	var hero := _hero_of(rules, player, cmd)
	if town.is_empty() or hero.is_empty() or hero["pos"] != town["pos"]:
		return _no("The hero is not in the town.")
	var knowledge := rules.study_wall(hero, town)  # (first: the spell points are restored to the new maximum)
	var xp := rules.attend_academy(hero, town)
	var mana: int = hero["mana"]
	var learned := rules.hero_in_town(hero, town)
	var restored: int = hero["mana"] - mana
	var vortex := rules.drink_vortex(hero, town)  # (restored first, then doubled)
	return {"ok": true, "reason": "", "learned": learned, "mana": restored, "knowledge": knowledge, "xp": xp,
		"vortex": vortex}

static func _garrison(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var town := _own_town(rules, player, cmd)
	if town.is_empty():
		return _no("Not your town.")
	var ok := false
	match cmd["t"]:
		"enter_garrison":
			var hero := _hero_of(rules, player, cmd)
			ok = not hero.is_empty() and rules.enter_garrison(hero, town)
		"leave_garrison":
			ok = rules.leave_garrison(town)
		"swap_garrison":
			ok = rules.swap_garrison(town)
	return {"ok": true, "reason": ""} if ok else _no("Cannot do that here.")

static func _artifact(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero := _hero_of(rules, player, cmd)
	var a: String = cmd.get("artifact", "")
	if hero.is_empty() or not GameData.ARTIFACTS.has(a):
		return _no("Not your hero.")
	var worn: bool = a in hero.get("artifacts", [])
	var carried: bool = a in hero.get("backpack", [])
	var made := ""
	match cmd["t"]:
		"equip":
			if bool(cmd.get("worn", false)) != worn or not (worn or carried):
				return _no("The hero does not have that.")
			made = GameState.swap_artifact(hero, a, worn)
		"split_set":
			if not worn or not GameData.ARTIFACTS[a].has("parts"):
				return _no("Not a worn combination.")
			GameState.split_combination(hero, a)
		"join_set":
			if not a in hero.get("apart", []):
				return _no("That set is not parted.")
			made = GameState.join_combination(hero, a)
		"give_artifact":
			var other: Dictionary = rules.world["heroes"].get(int(cmd.get("to", -1)), {})
			if other.is_empty() or other["owner"] != player["index"] or other["uid"] == hero["uid"]:
				return _no("Not your hero.")
			if not together(rules, {"hero": hero["uid"]}, {"hero": other["uid"]}):
				return _no("The heroes are not together.")
			if not (worn or carried):
				return _no("The hero does not have that.")
			made = GameState.transfer_artifact(hero, other, a)
	return {"ok": true, "reason": "", "made": made}

static func _buy_machine(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero := _hero_of(rules, player, cmd)
	var id: String = cmd.get("machine", "")
	if hero.is_empty():
		return _no("Not your hero.")
	if cmd.has("town"):
		var town := _own_town(rules, player, cmd)
		if town.is_empty() or town["pos"] != hero["pos"] or not TownLogic.has_building(town, "blacksmith"):
			return _no("No Blacksmith here.")
		if id != GameData.FACTIONS[town["faction"]]["smith_machine"]:
			return _no("This Blacksmith does not forge that.")
	else:
		var o: Dictionary = rules.world["objects"].get(int(cmd.get("object", -1)), {})
		if o.is_empty() or o["type"] != "war_machine_factory" or o["pos"] != hero["pos"]:
			return _no("No factory here.")
	var why := GameState.war_machine_reason(hero, player, id)
	if why != "" or not GameState.buy_war_machine(hero, player, id):
		return _no(why if why != "" else "Cannot buy that.")
	return {"ok": true, "reason": ""}

## A stack of the hero's army upgraded at the Hill Fort it stands at, at the town price.
static func _hill_fort(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero := _hero_of(rules, player, cmd)
	var o: Dictionary = rules.world["objects"].get(int(cmd.get("object", -1)), {})
	var si := int(cmd.get("si", -1))
	if hero.is_empty() or o.is_empty() or o["type"] != "hill_fort" or o["pos"] != hero["pos"]:
		return _no("No Hill Fort here.")
	if si < 0 or si > 6 or hero["army"][si] == null:
		return _no("No such stack.")
	var st: Dictionary = hero["army"][si]
	var up := GameData.upgrade_of_base(st["id"])
	if up == "":
		return _no("That stack has no upgrade.")
	var cost := TownLogic.upgrade_cost(st["id"], up, st["count"])
	if not TownLogic.can_afford(player, cost):
		return _no("Not enough resources.")
	TownLogic.pay(player, cost)
	st["id"] = up
	return {"ok": true, "reason": ""}

static func _transform(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var town := _own_town(rules, player, cmd)
	var army := army_of(rules, player, cmd.get("army"))
	var si := int(cmd.get("si", -1))
	if town.is_empty() or army.is_empty() or si < 0 or si > 6 or army[si] == null:
		return _no("No such stack.")
	if not together(rules, cmd["army"], {"town": town["uid"]}):
		return _no("The army is not in the town.")
	var into := TownLogic.transform_creature(town)
	if into == "" or not TownLogic.transform_stack(army[si], into):
		return _no("Cannot transform that.")
	return {"ok": true, "reason": "", "into": into}

static func _level_roll(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero := _hero_of(rules, player, cmd)
	if hero.is_empty() or int(hero.get("pending_levels", 0)) <= 0:
		return _no("No level to take.")
	if not hero.has("level_roll"):  # (rolled once: asking again shows the same offer)
		hero["level_roll"] = rules.roll_level_up(hero)
	var r: Dictionary = hero["level_roll"]
	return {"ok": true, "reason": "", "stat": r["stat"], "options": r["options"].duplicate()}

static func _level_up(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero := _hero_of(rules, player, cmd)
	if hero.is_empty() or not hero.has("level_roll"):
		return _no("No level rolled.")
	var r: Dictionary = hero["level_roll"]
	var skill: String = cmd.get("skill", "")
	if (r["options"].is_empty() and skill != "") or (not r["options"].is_empty() and not skill in r["options"]):
		return _no("That skill was not offered.")
	hero.erase("level_roll")
	rules.apply_level_up(hero, r, skill)
	return {"ok": true, "reason": ""}

static func _hero_of(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var h: Dictionary = rules.world["heroes"].get(int(cmd.get("hero", -1)), {})
	return h if not h.is_empty() and h["owner"] == player["index"] else {}

static func _visit(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero := _hero_of(rules, player, cmd)
	var o: Dictionary = rules.world["objects"].get(int(cmd.get("object", -1)), {})
	if hero.is_empty():
		return _no("Not your hero.")
	if o.is_empty() or o["pos"] != hero["pos"]:
		return _no("The hero is not there.")
	if o["type"] == "monster" or (o["type"] == "pyramid" and not o.get("guards", []).is_empty()):
		return _no("It must be fought first.")
	var ev := rules.visit(hero, o)
	if ev.has("choice"):
		hero["pending_chest"] = {"gold": int(ev["choice"]["gold"]), "xp": int(ev["choice"]["xp"])}
	return {"ok": true, "reason": "", "event": ev}

static func _chest(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero := _hero_of(rules, player, cmd)
	if hero.is_empty() or not hero.has("pending_chest"):
		return _no("No chest to open.")
	var choice: String = cmd.get("choice", "")
	if not choice in ["gold", "xp"]:
		return _no("Gold or experience.")
	var c: Dictionary = hero["pending_chest"]
	hero.erase("pending_chest")
	return {"ok": true, "reason": "", "levels": rules.resolve_chest(hero, choice, int(c["gold"]), int(c["xp"]))}

static func _capture(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero := _hero_of(rules, player, cmd)
	var town: Dictionary = rules.world["towns"].get(int(cmd.get("town", -1)), {})
	if hero.is_empty() or town.is_empty() or town["pos"] != hero["pos"]:
		return _no("The hero is not at that town.")
	if town["owner"] == player["index"]:
		return _no("It is already yours.")
	if not GameState.army_is_empty(town["garrison"]) or not rules.town_defender(town, hero).is_empty():
		return _no("The town is defended.")
	rules.capture_town(town, player["index"])
	rules.check_eliminations()
	return {"ok": true, "reason": ""}

static func _battle_result(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	# (a world without turns, as a test's hand-built one, skips the turn check)
	if rules.world.has("current_player") and int(rules.world["current_player"]) != player["index"]:
		return _no("Not your turn.")
	var result = cmd.get("result")
	if not result is Dictionary or not result.has("winner"):
		return _no("No battle result.")
	return {"ok": true, "reason": "", "event": rules.apply_battle(result)}

## A tile from a command: [x, y] (as JSON carries it) or a Vector2i.
static func tile(v) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Array and v.size() == 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(-99, -99)

static func _step(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero: Dictionary = rules.world["heroes"].get(int(cmd.get("hero", -1)), {})
	if hero.is_empty() or hero["owner"] != player["index"] or hero.get("in_town", false):
		return _no("Not your hero.")
	var to := tile(cmd.get("to"))
	var from: Vector2i = hero["pos"]
	var d := to - from
	if maxi(absi(d.x), absi(d.y)) != 1 or not rules.walkable_ground(to):
		return _no("Cannot step there.")
	var o: Dictionary = rules.at(to)
	if o.get("kind", "") == "hero" or (o.get("kind", "") == "object" and rules.world["objects"][o["uid"]]["type"] == "monster"):
		return _no("Something stands there.")
	var cost := rules.step_cost(from, to)
	if hero["movement"] < cost:
		return _no("Not enough movement.")
	hero["movement"] -= cost
	hero["pos"] = to
	rules.refresh_tile(from)
	rules.refresh_tile(to)
	rules.reveal(player, to, rules.hero_scout_radius(hero))
	return {"ok": true, "reason": "", "cost": cost}

static func _end_turn(rules: AdvRules, player: Dictionary) -> Dictionary:
	var w: Dictionary = rules.world
	if int(w["current_player"]) != player["index"]:
		return _no("Not your turn.")
	var n: int = w["players"].size()
	var cur: int = w["current_player"]
	var day := {}
	for k in n:
		cur = (cur + 1) % n
		if cur == 0:
			day = rules.new_day()
		if w["players"][cur]["alive"]:
			break
	w["current_player"] = cur
	return {"ok": true, "reason": "", "next": cur, "day": day}

## The army an army reference names, if the player owns it ([] otherwise).
static func army_of(rules: AdvRules, player: Dictionary, ref) -> Array:
	if not ref is Dictionary:
		return []
	if ref.has("hero"):
		var h: Dictionary = rules.world["heroes"].get(int(ref["hero"]), {})
		return h["army"] if not h.is_empty() and h["owner"] == player["index"] else []
	if ref.has("town"):
		var t: Dictionary = rules.world["towns"].get(int(ref["town"]), {})
		return t["garrison"] if not t.is_empty() and t["owner"] == player["index"] else []
	return []

static func _pos_of(rules: AdvRules, ref: Dictionary) -> Vector2i:
	var o: Dictionary = rules.world["heroes" if ref.has("hero") else "towns"].get(int(ref.get("hero", ref.get("town", -1))), {})
	return o.get("pos", Vector2i(-99, -99))

## Can these two armies exchange troops: the same army, a hero and a town it stands in, or two heroes side by side?
static func together(rules: AdvRules, a: Dictionary, b: Dictionary) -> bool:
	if a.has("town") and b.has("town"):
		return int(a["town"]) == int(b["town"])
	var d: Vector2i = _pos_of(rules, a) - _pos_of(rules, b)
	if a.has("hero") and b.has("hero"):
		return maxi(absi(d.x), absi(d.y)) <= 1
	return d == Vector2i.ZERO

static func _two_armies(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Array:
	var src := army_of(rules, player, cmd.get("from"))
	var dst := army_of(rules, player, cmd.get("to"))
	if src.is_empty() or dst.is_empty() or not together(rules, cmd["from"], cmd["to"]):
		return []
	return [src, dst]

static func _stack_count(army: Array) -> int:
	return army.filter(func(s): return s != null).size()

static func _stack_move(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var ab := _two_armies(rules, player, cmd)
	if ab.is_empty():
		return _no("Those armies are not together.")
	var src: Array = ab[0]
	var dst: Array = ab[1]
	var si := int(cmd.get("si", -1))
	var ti := int(cmd.get("ti", -1))
	if si < 0 or si > 6 or ti < 0 or ti > 6 or src[si] == null:
		return _no("No such stack.")
	var same := is_same(src, dst) and si == ti
	if same:
		return _no("No such stack.")
	var a: Dictionary = src[si]
	var b = dst[ti]
	# a hero's army keeps at least one stack: it cannot be moved or merged away whole into another army
	var keeps: bool = cmd["from"].has("hero") and not is_same(src, dst) and _stack_count(src) <= 1
	if b == null:
		if cmd.get("split", false) and a["count"] > 1:
			var half: int = a["count"] / 2
			a["count"] -= half
			dst[ti] = {"id": a["id"], "count": half}
		else:
			if keeps:
				return _no("A hero cannot give away the last stack.")
			dst[ti] = a
			src[si] = null
	elif b["id"] == a["id"] and not cmd.get("swap", false):
		if keeps:
			return _no("A hero cannot give away the last stack.")
		b["count"] += a["count"]
		src[si] = null
	else:
		dst[ti] = a
		src[si] = b
	return {"ok": true, "reason": ""}

static func _move_troops(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var ab := _two_armies(rules, player, cmd)
	if ab.is_empty():
		return _no("Those armies are not together.")
	var src: Array = ab[0]
	var dst: Array = ab[1]
	var si := int(cmd.get("si", -1))
	var n := int(cmd.get("n", 0))
	if si < 0 or si > 6 or src[si] == null or n <= 0 or n > int(src[si]["count"]) or is_same(src, dst):
		return _no("No such troops.")
	if cmd["from"].has("hero") and n == int(src[si]["count"]) and _stack_count(src) <= 1:
		return _no("A hero cannot give away the last stack.")
	if not GameState.add_to_army(dst, src[si]["id"], n):
		return _no("No room in the army.")
	src[si]["count"] -= n
	if src[si]["count"] == 0:
		src[si] = null
	return {"ok": true, "reason": ""}

static func _upgrade_stack(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var town: Dictionary = rules.world["towns"].get(int(cmd.get("town", -1)), {})
	var army := army_of(rules, player, cmd.get("army"))
	var si := int(cmd.get("si", -1))
	if town.is_empty() or town["owner"] != player["index"] or army.is_empty() or si < 0 or si > 6 or army[si] == null:
		return _no("No such stack.")
	if not together(rules, cmd["army"], {"town": town["uid"]}):
		return _no("The army is not in the town.")
	if not TownLogic.upgrade_stack(town, player, army[si]):
		return _no("Cannot upgrade that stack here.")
	return {"ok": true, "reason": ""}

static func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func _recruit_town(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var town: Dictionary = rules.world["towns"].get(int(cmd.get("town", -1)), {})
	if town.is_empty() or town["owner"] != player["index"]:
		return _no("Not your town.")
	var tier := int(cmd.get("tier", 0))
	var n := int(cmd.get("n", 0))
	if tier < 1 or tier > 7 or not TownLogic.has_building(town, "dwelling_%d" % tier):
		return _no("No such dwelling.")
	var army: Array = town["garrison"] if cmd.get("into", "town") == "garrison" else rules.town_army(town)
	if not TownLogic.recruit(town, player, tier, n, army):
		return _no("Cannot recruit that many.")
	return {"ok": true, "reason": "", "n": n, "creature": TownLogic.dwelling_creature(town, tier)}

static func _recruit_portal(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var town: Dictionary = rules.world["towns"].get(int(cmd.get("town", -1)), {})
	if town.is_empty() or town["owner"] != player["index"]:
		return _no("Not your town.")
	var pool: Dictionary = town.get("portal", {})
	var n := int(cmd.get("n", 0))
	if pool.is_empty() or n <= 0 or n > int(pool["count"]) or not TownLogic.can_afford(player, GameData.CREATURES[pool["creature"]]["cost"], n):
		return _no("Cannot recruit that many.")
	if not GameState.add_to_army(rules.town_army(town), pool["creature"], n):
		return _no("No room in the army.")
	TownLogic.pay(player, GameData.CREATURES[pool["creature"]]["cost"], n)
	pool["count"] = int(pool["count"]) - n
	return {"ok": true, "reason": "", "n": n, "creature": pool["creature"]}

static func _recruit_site(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var hero: Dictionary = rules.world["heroes"].get(int(cmd.get("hero", -1)), {})
	var o: Dictionary = rules.world["objects"].get(int(cmd.get("object", -1)), {})
	if hero.is_empty() or hero["owner"] != player["index"]:
		return _no("Not your hero.")
	if o.is_empty() or o["type"] != "dwelling":
		return _no("No such dwelling.")
	var n := int(cmd.get("n", 0))
	var c: Dictionary = GameData.CREATURES[o["creature"]]
	if n <= 0 or n > int(o["available"]) or not TownLogic.can_afford(player, c["cost"], n):
		return _no("Cannot recruit that many.")
	if not GameState.add_to_army(hero["army"], o["creature"], n):
		return _no("No room in the army.")
	TownLogic.pay(player, c["cost"], n)
	o["available"] -= n
	return {"ok": true, "reason": "", "n": n, "creature": o["creature"]}

static func _hire(rules: AdvRules, player: Dictionary, cmd: Dictionary) -> Dictionary:
	var w: Dictionary = rules.world
	var town: Dictionary = w["towns"].get(int(cmd.get("town", -1)), {})
	var hid: String = cmd.get("hero_id", "")
	if town.is_empty() or town["owner"] != player["index"]:
		return _no("Not your town.")
	if not TownLogic.has_building(town, "tavern"):
		return _no("The town has no Tavern.")
	if not hid in w["tavern"]:
		return _no("That hero is not in the taverns.")
	for hh in w["heroes"].values():  # (the garrison hero waits inside: the gate is free)
		if hh["pos"] == town["pos"] and not hh.get("in_town", false):
			return _no("A hero is already standing at the town gate.")
	if player["resources"]["gold"] < HIRE_COST:
		return _no("Not enough gold.")
	w["tavern"].erase(hid)
	player["resources"]["gold"] -= HIRE_COST
	var hero := GameState.tavern_hero(hid, player["index"])
	hero["pos"] = town["pos"]
	w["heroes"][hero["uid"]] = hero
	player["heroes"].append(hero["uid"])
	var learned := rules.learn_guild(hero, town)  # (hired in the town: it learns the town's guild, as any visit)
	return {"ok": true, "reason": "", "hero": hero["uid"], "learned": learned}

static func _trade(player: Dictionary, cmd: Dictionary) -> Dictionary:
	var give: String = cmd.get("give", "")
	var get_r: String = cmd.get("get", "")
	var n := int(cmd.get("n", 0))
	if not give in GameData.RESOURCES or not get_r in GameData.RESOURCES or give == get_r:
		return _no("Pick two different resources.")
	if n <= 0 or player["resources"].get(give, 0) < n:
		return _no("Not enough to trade.")
	var got := int(n * TownLogic.market_rate(give, get_r))
	player["resources"][give] -= n
	player["resources"][get_r] = player["resources"].get(get_r, 0) + got
	return {"ok": true, "reason": "", "got": got}
