extends RefCounted
class_name AdvAI
## Computer opponent for the adventure map: builds, recruits, hires, and sends heroes after the
## most valuable target it can safely take (value / distance).

const BUILD_ORDER := ["tavern", "dwelling_1", "dwelling_2", "town_hall", "dwelling_3", "fort", "mage_guild_1",
	"dwelling_4", "marketplace", "citadel", "blacksmith", "dwelling_5", "city_hall", "stables", "dwelling_6", "mage_guild_2",
	"brotherhood", "necromancy_amplifier", "dwelling_7", "castle", "dwelling_1u", "dwelling_2u", "dwelling_3u", "dwelling_4u",
	"capitol", "mage_guild_3", "dwelling_5u", "dwelling_6u", "dwelling_7u", "mage_guild_4"]

var rules: AdvRules
var world: Dictionary
var holding := -1  # the hero whose last choice was to hold its town's gate (run_turn moves it into the garrison)

func _init(r: AdvRules) -> void:
	rules = r
	world = r.world

func run_turn(adv, player: Dictionary) -> String:
	if player.get("ai_day", -1) != world["day"]:
		player["ai_day"] = world["day"]
		_release_garrisons(player)
		manage_towns(player)
		adv.view.rebuild_objects()
	var rally := _assault_rally(player)
	var order: Array = player["heroes"].duplicate()
	if not rally.is_empty():
		order.erase(rally["leader"])
		order.append(rally["leader"]) # deliveries arrive before the main army spends its movement
	var guard := 0
	for hid in order:
		var steps := 0
		while steps < 8:
			steps += 1
			guard += 1
			if guard > 60:
				return ""
			var hero: Dictionary = world["heroes"].get(hid, {})
			if hero.is_empty() or hero["movement"] < 50 or hero.get("in_town", false):  # (a garrison hero stays in)
				break
			var choice := {}
			if hid in rally.get("donors", []):
				var leader: Dictionary = world["heroes"].get(rally["leader"], {})
				if not leader.is_empty() and _transfer_value(leader, hero["army"], true) > 400 and _defense(hero).is_empty():
					var meeting := rules.plan(hero, leader["pos"])
					if not meeting["path"].is_empty() and meeting["reach"] == meeting["path"].size() - 1:
						choice = meeting
			if choice.is_empty(): choice = choose(hero)
			if choice.is_empty() and holding == hid and _garrison(hero):
				adv.view.rebuild_objects()  # (it went into the garrison to hold the town)
				break
			if choice.is_empty():
				# An idle hero may still need to step aside for a later army in this same turn.
				break
			if choice.has("yield"):
				var clearance: Dictionary = choice["yield"]
				var blocker: Dictionary = world["heroes"].get(clearance["hero"], {})
				if not blocker.is_empty():
					await adv.move_hero(blocker, clearance["plan"], false)
				continue # replan against actual occupancy; the blocked army has spent nothing
			_leave_rear_guard(hero, choice)
			var before: int = hero["movement"]
			var army_before := GameState.army_strength(hero["army"])
			var xp_before: int = hero["xp"]
			var r: String = await adv.move_hero(hero, choice, false)
			if r == "battle":
				return "battle"
			if not adv.is_inside_tree():
				return "battle"
			if world["heroes"].has(hid) and world["heroes"][hid]["movement"] == before \
					and GameState.army_strength(hero["army"]) == army_before and hero["xp"] == xp_before:
				hero["movement"] = 0
				break
			# Hero standing in own town: reinforce.
			if world["heroes"].has(hid):
				for town in world["towns"].values():
					if town["pos"] == hero["pos"] and town["owner"] == hero["owner"]:
						_reinforce(hero, town, player)
						rules.hero_in_town(hero, town)
	return ""

## Several same-day deliveries can unlock an assault even when no individual delivery does.
## Preview sequentially on copies so seven slots and the donor's last creature are respected.
func _assault_rally(player: Dictionary) -> Dictionary:
	var leader_uid := _leader(player)
	if leader_uid < 0: return {}
	var leader: Dictionary = world["heroes"][leader_uid]
	if leader["movement"] < 50: return {}
	var preview: Array = leader["army"].duplicate(true)
	var before := GameState.army_strength(preview)
	var donors := []
	for hid in player["heroes"]:
		if hid == leader_uid: continue
		var donor: Dictionary = world["heroes"][hid]
		if donor["movement"] < 50 or not _defense(donor).is_empty(): continue
		var meeting := rules.plan(donor, leader["pos"])
		if meeting["path"].is_empty() or meeting["reach"] != meeting["path"].size() - 1 \
				or meeting["costs"].back() > donor.get("max_movement", 1500): continue
		var trial := preview.duplicate(true)
		if _transfer(trial, donor["army"].duplicate(true), true) <= 400: continue
		preview = trial
		donors.append(hid)
	if donors.is_empty() or not _unlocks_assault(leader, GameState.army_strength(preview) - before): return {}
	return {"leader": leader_uid, "donors": donors}

# ---------------------------------------------------------------------------------------------
func manage_towns(player: Dictionary) -> void:
	var week := rules.week_of(world["day"])
	var want_heroes := mini(3, 1 + week / 2)
	# Heroes first: a player without heroes can neither expand nor defend.
	for tid in player["towns"]:
		var town: Dictionary = world["towns"][tid]
		if player["heroes"].size() < want_heroes and TownLogic.has_building(town, "tavern") \
				and player["resources"]["gold"] >= 2500 and rules.hero_at(town["pos"]).is_empty() and world["tavern"].size() > 0:
			hire_hero(player, town)
	var reserve := 2500 if player["heroes"].size() < want_heroes else 0
	var day_of_week: int = (world["day"] - 1) % 7 + 1
	var towns: Array = player["towns"].duplicate()
	var threats := {}
	for tid in towns:
		threats[tid] = _town_threat(world["towns"][tid])
	towns.sort_custom(func(a, b): return threats[a] > threats[b])
	for tid in towns:
		var town: Dictionary = world["towns"][tid]
		var threatened: bool = threats[tid] > 0.0
		if threatened:
			_recruit(town, player, 0)  # today's defense takes priority over future economic buildings
		if not town["built_today"]:
			for b in BUILD_ORDER:
				if TownLogic.has_building(town, b):
					continue
				var reason := TownLogic.build_block_reason(town, player, b)
				if reason == "":
					TownLogic.build(town, player, b)
					break
				if reason == "Not enough resources" and not b.begins_with("mage"):
					break  # save up for it
		# recruit into garrison, best first, keeping the hiring reserve and (early in the week)
		# saving for the next building on the list
		var save := 0 if threatened else reserve
		if not threatened and day_of_week < 6:
			var next := _next_building(town, player)
			if next != "":
				save += int(GameData.BUILDINGS[next]["cost"].get("gold", 0))
		_recruit(town, player, save)
		var visitor := rules.hero_at(town["pos"])
		if not visitor.is_empty() and visitor["owner"] == player["index"]:
			_reinforce(visitor, town, player)

## Only reserve for a building whose faction, prerequisites and kingdom limit allow it tomorrow.
func _next_building(town: Dictionary, player: Dictionary) -> String:
	var tomorrow := town.duplicate()
	tomorrow["built_today"] = false
	for id in BUILD_ORDER:
		if TownLogic.build_block_reason(tomorrow, player, id) in ["", "Not enough resources"]:
			return id
	return ""

func _recruit(town: Dictionary, player: Dictionary, save: int) -> void:
	for tier in range(7, 0, -1):
		var n := TownLogic.max_recruitable(town, player, tier)
		var cid := TownLogic.dwelling_creature(town, tier)
		var price: int = GameData.CREATURES[cid]["cost"].get("gold", 0)
		if price > 0:
			n = mini(n, maxi(0, (player["resources"]["gold"] - save) / price))
		if n > 0:
			TownLogic.recruit(town, player, tier, n, town["garrison"])

func hire_hero(player: Dictionary, town: Dictionary) -> Dictionary:
	var cands := []
	for hid in world["tavern"]:
		if GameData.HEROES[hid]["faction"] == town["faction"]:
			cands.append(hid)
	if cands.is_empty():
		cands = world["tavern"].duplicate()
	if cands.is_empty():
		return {}
	var hid: String = cands[randi() % cands.size()]
	world["tavern"].erase(hid)
	player["resources"]["gold"] -= 2500
	var hero := GameState.tavern_hero(hid, player["index"])
	hero["pos"] = town["pos"]
	hero["movement"] = 0 if player["is_ai"] == false else hero["movement"]
	world["heroes"][hero["uid"]] = hero
	player["heroes"].append(hero["uid"])
	_reinforce(hero, town, player)
	rules.rebuild()
	return hero

func _reinforce(hero: Dictionary, town: Dictionary, _player: Dictionary) -> void:
	# Upgrading a base stack can merge it with an upgraded stack already carried, freeing an army slot.
	for stack in hero["army"]:
		if stack:
			TownLogic.upgrade_stack(town, _player, stack)
	_merge_stacks(hero["army"])
	_collect_garrison(hero["army"], town)
	for stack in hero["army"]:
		if stack:
			TownLogic.upgrade_stack(town, _player, stack)
	_merge_stacks(hero["army"])

## Garrison strength that holds the gate against the strongest army able to reach it next turn, when the garrison
## can hold it at all (a garrison too weak to hold is better carried by the hero).
func _garrison_keep(town: Dictionary) -> float:
	var threat := _town_threat(town)
	var need := threat * 1.4 / 1.25
	if threat <= 0.0 or GameState.army_strength(town["garrison"]) < need: return 0.0
	return need

## A hero takes the town's garrison into its army, leaving what the gate needs (the most valuable troops go first).
func _collect_garrison(army: Array, town: Dictionary) -> int:
	var keep := _garrison_keep(town)
	var spare := float(GameState.army_strength(town["garrison"])) - keep
	var order := []
	for i in 7:
		if town["garrison"][i]: order.append(i)
	order.sort_custom(func(a, b): return GameData.CREATURES[town["garrison"][a]["id"]]["ai_value"] > GameData.CREATURES[town["garrison"][b]["id"]]["ai_value"])
	var value := 0
	for i in order:
		var s: Dictionary = town["garrison"][i]
		var unit: int = GameData.CREATURES[s["id"]]["ai_value"]
		var n: int = s["count"] if keep <= 0.0 else mini(s["count"], int(spare / unit))
		if n <= 0 or not GameState.add_to_army(army, s["id"], n): continue
		s["count"] -= n
		spare -= n * unit
		value += n * unit
		if s["count"] == 0: town["garrison"][i] = null
	return value

func _merge_stacks(army: Array) -> void:
	var first := {}
	for i in army.size():
		if army[i] == null: continue
		var id: String = army[i]["id"]
		if first.has(id):
			army[first[id]]["count"] += army[i]["count"]
			army[i] = null
		else:
			first[id] = i

## Consolidate at an ordinary adjacent friendly meeting, retaining one creature with the courier.
## Preview on copies first: seven-slot limits must never cause lost troops or pointless trips.
func _transfer(receiver: Array, donor: Array, keep_one: bool) -> int:
	var reserve := -1
	if keep_one:
		for i in donor.size():
			if donor[i] and (reserve < 0 or GameData.CREATURES[donor[i]["id"]]["ai_value"] < GameData.CREATURES[donor[reserve]["id"]]["ai_value"]):
				reserve = i
	var value := 0
	for i in donor.size():
		var s = donor[i]
		if s == null: continue
		var count: int = s["count"] - (1 if i == reserve else 0)
		if count > 0 and GameState.add_to_army(receiver, s["id"], count):
			value += count * GameData.CREATURES[s["id"]]["ai_value"]
			s["count"] -= count
			if s["count"] == 0: donor[i] = null
	return value

func _transfer_value(receiver: Dictionary, donor: Array, keep_one: bool) -> int:
	return _transfer(receiver["army"].duplicate(true), donor.duplicate(true), keep_one)

func _leader(player: Dictionary) -> int:
	var uid := -1
	var best := -1.0
	for hid in player["heroes"]:
		var hero: Dictionary = world["heroes"].get(hid, {})
		if hero.is_empty(): continue
		var value: float = _strength(hero) + hero["level"] * 200
		if value > best:
			best = value
			uid = hid
	return uid

func exchange_troops(a: Dictionary, b: Dictionary) -> int:
	if a["owner"] != b["owner"]: return 0
	var distance: Vector2i = a["pos"] - b["pos"]
	if maxi(absi(distance.x), absi(distance.y)) > 1: return 0
	var leader := _leader(rules.player_of(a))
	if leader != a["uid"] and leader != b["uid"]: return 0
	var receiver := a if leader == a["uid"] else b
	var donor := b if receiver == a else a
	var moved := _transfer(receiver["army"], donor["army"], true)
	donor.erase("ai_goal")
	return moved

func recruit_from_dwelling(hero: Dictionary, o: Dictionary) -> void:
	var player := rules.player_of(hero)
	var c: Dictionary = GameData.CREATURES[o["creature"]]
	var n := dwelling_recruits(hero, o)
	if n > 0 and GameState.add_to_army(hero["army"], o["creature"], n):
		TownLogic.pay(player, c["cost"], n)
		o["available"] -= n

## Use the same affordable, carryable count when planning a visit and when buying.
func dwelling_recruits(hero: Dictionary, o: Dictionary) -> int:
	var player := rules.player_of(hero)
	var c: Dictionary = GameData.CREATURES[o["creature"]]
	var n: int = o["available"]
	for r in c["cost"]:
		n = mini(n, player["resources"].get(r, 0) / c["cost"][r])
	return n if n > 0 and GameState.add_to_army(hero["army"].duplicate(true), o["creature"], n) else 0

# ---------------------------------------------------------------------------------------------
## Plan and execute the same purchases so a fully equipped or cash-poor hero never loops at a factory.
func factory_purchases(hero: Dictionary, player: Dictionary) -> Array:
	var purchases := []
	var budget: int = maxi(0, int(player["resources"].get("gold", 0)) - 1000)
	var shooters := false
	for stack in hero["army"]:
		if stack != null and stack["count"] > 0 and GameData.CREATURES[stack["id"]]["shots"] > 0:
			shooters = true
	for id in GameData.WAR_MACHINES:
		if id == "ammo_cart" and not shooters:
			continue
		var cost: int = GameData.CREATURES[id]["cost"]["gold"]
		if cost <= budget and GameState.war_machine_reason(hero, player, id) == "":
			purchases.append(id)
			budget -= cost
	return purchases

func buy_from_factory(hero: Dictionary) -> void:
	var player := rules.player_of(hero)
	for id in factory_purchases(hero, player):
		GameState.buy_war_machine(hero, player, id)

func _strength(hero: Dictionary) -> float:
	var s := float(GameState.army_strength(hero["army"]))
	return s * (1.0 + 0.05 * (GameState.hero_stat(hero, "attack") + GameState.hero_stat(hero, "defense")))

func choose(hero: Dictionary) -> Dictionary:
	holding = -1
	var defense := _defense(hero)
	if not defense.is_empty():
		hero.erase("ai_goal")
		if defense.has("hold"):
			holding = hero["uid"]
			return {}
		return defense
	var me := _strength(hero)
	var player := rules.player_of(hero)
	var best := {}
	var best_score := 0.0
	var hp: Vector2i = hero["pos"]
	var cands := []
	var leader_uid := _leader(player)
	if hero["uid"] != leader_uid and leader_uid >= 0:
		var leader: Dictionary = world["heroes"][leader_uid]
		var delivery := _transfer_value(leader, hero["army"], true)
		# Do not dismantle a useful second army or chase the leader across the map.
		if delivery > 400 and (_strength(hero) < _strength(leader) * 0.35 or _unlocks_assault(leader, delivery)):
			var meeting := rules.plan(hero, leader["pos"])
			if not meeting["path"].is_empty() and meeting["costs"].back() <= hero.get("max_movement", 1500) * 0.5:
				cands.append([leader["pos"], delivery * 1.2, "delivery"])
	for o in world["objects"].values():
		var d: Vector2i = o["pos"] - hp
		if absi(d.x) > 22 or absi(d.y) > 22:
			continue
		var v := _object_value(hero, player, o, me)
		if v > 0:
			cands.append([o["pos"], v])
	# Under the optional seven-day rule a townless player must take a town or lose: accept a riskier assault.
	var townless := rules.townless_days_left(player) > 0
	for t in world["towns"].values():
		var v := 0.0
		if t["owner"] != hero["owner"]:
			var def := float(GameState.army_strength(t["garrison"])) * 1.25
			var dh := rules.hero_at(t["pos"])
			if not dh.is_empty():
				def += _strength(dh)
			var gh := rules.garrison_hero(t)  # (a hero waiting inside defends the walls)
			if not gh.is_empty():
				def += _strength(gh) * 1.25
			if me > def * (1.1 if townless else 1.4):
				v = 36000.0 if townless else 12000.0
		elif t["pos"] != hp and rules.hero_at(t["pos"]).is_empty():
			var reinforcement := _collect_garrison(hero["army"].duplicate(true), t.duplicate(true))
			if reinforcement > me * 0.25:
				v = 2500.0 + reinforcement * 0.6
		if v > 0:
			cands.append([t["pos"], v])
	for e in world["heroes"].values():
		if e["owner"] != hero["owner"]:
			# A hero at a town defends with its garrison: the town candidate above already
			# evaluates that combined force. Do not add a deceptively cheap hero-only attack.
			var in_town: bool = e.get("in_town", false)
			for t in world["towns"].values():
				if t["pos"] == e["pos"] and t["owner"] != hero["owner"]:
					in_town = true
			if in_town:
				continue
			var es := _strength(e)
			if me > es * 1.3:
				cands.append([e["pos"], 7000.0 + es * 0.2])
	for c in cands:
		# Reaching a guarded tile means fighting its guards: only go if they are beatable.
		var guarded_ok := true
		for g in rules.guards(c[0]):
			if float(GameData.CREATURES[g["creature"]]["ai_value"] * g["count"]) * 1.6 > me:
				guarded_ok = false
		if not guarded_ok:
			continue
		var plan := _plan_with_passage(hero, c[0])
		if plan["path"].is_empty() or plan["reach"] == 0:
			continue
		# An occupied shop/dwelling is a meeting, not a purchase. It must actually help the army.
		if plan["kind"] == "meet" and c.size() < 3:
			var other: Dictionary = plan["target"]
			if hero["uid"] != leader_uid and other["uid"] != leader_uid: continue
			var receiver := hero if hero["uid"] == leader_uid else other
			var donor := other if receiver == hero else hero
			if _transfer_value(receiver, donor["army"], true) == 0: continue
		var cost: int = plan["costs"][plan["costs"].size() - 1]
		var score: float = c[1] / (1.0 + cost / 150.0)
		var goal: Dictionary = hero.get("ai_goal", {})
		if goal.get("pos", Vector2i(-1, -1)) == c[0]:
			score *= 1.2 # keep a viable multi-day objective unless a materially better opportunity appears
		var exclusive: bool = plan["kind"] == "town" and plan["target"].get("owner", -1) != hero["owner"]
		exclusive = exclusive or plan["target"].get("type", "") in ["resource", "chest", "campfire", "artifact", "monster", "mine"]
		for hid in (player["heroes"] if exclusive else []):
			if hid == hero["uid"]: continue
			var other: Dictionary = world["heroes"].get(hid, {})
			var assigned: Dictionary = other.get("ai_goal", {})
			if assigned.get("pos", Vector2i(-1, -1)) != c[0] or int(assigned.get("day", -2)) < world["day"] - 1:
				continue
			# A recent assignment avoids duplicate errands; a much nearer hero may still take over.
			if Vector2(other["pos"] - c[0]).length() <= Vector2(hp - c[0]).length() + 2.0:
				score *= 0.6
				break
		if score > best_score:
			best_score = score
			best = plan
	if best.is_empty():
		hero.erase("ai_goal")
	else:
		hero["ai_goal"] = {"pos": best["path"].back(), "day": world["day"]}
	return best

## Leaving a town that an enemy army can reach next turn: leave behind enough troops to hold it against that army,
## when that costs at most a quarter of the hero's strength (an empty gate is otherwise taken by any passing raider).
func _leave_rear_guard(hero: Dictionary, choice: Dictionary) -> void:
	var town := {}
	for t in world["towns"].values():
		if t["pos"] == hero["pos"] and t["owner"] == hero["owner"]:
			town = t
	if town.is_empty() or choice.get("path", []).size() < 2: return
	var threat := _town_threat(town)
	var need := (threat * 1.4 - _town_hold(town)) / 1.25
	if threat <= 0.0 or need <= 0.0 or need > GameState.army_strength(hero["army"]) * 0.25: return
	# cheapest units first, whole units only; the hero keeps at least one creature
	var order := []
	for i in hero["army"].size():
		if hero["army"][i]: order.append(i)
	order.sort_custom(func(a, b): return GameData.CREATURES[hero["army"][a]["id"]]["ai_value"] < GameData.CREATURES[hero["army"][b]["id"]]["ai_value"])
	var left := 0
	for i in order: left += hero["army"][i]["count"]
	for i in order:
		if need <= 0.0: break
		var s: Dictionary = hero["army"][i]
		var unit: int = GameData.CREATURES[s["id"]]["ai_value"]
		var n: int = mini(mini(s["count"], ceili(need / unit)), left - 1)
		if n <= 0 or not GameState.add_to_army(town["garrison"], s["id"], n): continue
		s["count"] -= n
		left -= n
		need -= n * unit
		if s["count"] == 0: hero["army"][i] = null

## A blocked leader can ask an idle ally to make a legal one-step move off its route.
## The relaxed path is diagnostic only: run_turn moves the blocker, then replans normally.
func _plan_with_passage(hero: Dictionary, target: Vector2i) -> Dictionary:
	var plan := rules.plan(hero, target)
	if not plan["path"].is_empty() or hero["uid"] != _leader(rules.player_of(hero)): return plan
	var blockers := []
	for hid in rules.player_of(hero)["heroes"]:
		if hid == hero["uid"]: continue
		var ally: Dictionary = world["heroes"][hid]
		if ally["movement"] < 50 or not _defense(ally).is_empty(): continue
		var pos: Vector2i = ally["pos"]
		# Never move a gate defender or expose a blocked/guarded underlying tile.
		if not rules.walkable_ground(pos) or not rules.guards(pos).is_empty(): continue
		if world["towns"].values().any(func(t): return t["pos"] == pos): continue
		if world["objects"].values().any(func(o): return o["pos"] == pos): continue
		blockers.append(ally)
	# Finish all defense checks before temporarily relaxing any route.
	for ally in blockers: rules.astar.set_point_solid(ally["pos"], false)
	var relaxed := rules.plan(hero, target)
	for ally in blockers: rules.astar.set_point_solid(ally["pos"], true)
	if relaxed["path"].is_empty(): return plan
	for pos in relaxed["path"]:
		for ally in blockers:
			if ally["pos"] != pos: continue
			for dir in AdvRules.DIRS:
				var aside: Vector2i = pos + dir
				if aside in relaxed["path"] or not rules.walkable_ground(aside) or not rules.at(aside).is_empty() \
						or not rules.guards(aside).is_empty(): continue
				var step := rules.plan(ally, aside)
				if step["path"].size() != 2 or step["reach"] != 1: continue
				relaxed["yield"] = {"hero": ally["uid"], "plan": step}
				return relaxed
			return plan # the first obstruction has no legal place to go
	return plan

## Check whether transferable troops enable a nearby conquest under the ordinary safety threshold.
## Ordinary individual deliveries stay within half a day; a coordinated rally may use a full day.
func _unlocks_assault(leader: Dictionary, delivery: int) -> bool:
	var strength := _strength(leader)
	var combined := strength * (1.0 + float(delivery) / maxf(1.0, GameState.army_strength(leader["army"])))
	for town in world["towns"].values():
		if town["owner"] < 0 or town["owner"] == leader["owner"]: continue
		var defender := GameState.army_strength(town["garrison"]) * 1.25
		var resident := rules.hero_at(town["pos"])
		if not resident.is_empty(): defender += _strength(resident)
		var inside := rules.garrison_hero(town)
		if not inside.is_empty(): defender += _strength(inside) * 1.25
		if strength > defender * 1.4 or combined <= defender * 1.4 or not _safe_gate(leader, town): continue
		var plan := _plan_with_passage(leader, town["pos"])
		if not plan["path"].is_empty() and plan["costs"].back() <= leader.get("max_movement", 1500) * 2:
			return true
	return false

## Largest hostile army that can reach the gate next turn, following the actual terrain/occupancy path.
func _town_threat(town: Dictionary) -> float:
	var threat := 0.0
	for enemy in world["heroes"].values():
		if enemy["owner"] == town["owner"] or enemy.get("in_town", false):
			continue
		var budget: int = enemy.get("max_movement", enemy["movement"])
		if Vector2(enemy["pos"] - town["pos"]).length() * 50.0 > budget:
			continue
		var plan := rules.plan(enemy, town["pos"])
		if not plan["path"].is_empty() and plan["costs"].back() <= budget:
			threat = maxf(threat, _strength(enemy))
	return threat

## What holds a town's walls without the hero at its gate: its garrison, or its garrison hero's army (walls: x1.25).
func _town_hold(town: Dictionary) -> float:
	var gh := rules.garrison_hero(town)
	return (_strength(gh) if not gh.is_empty() else float(GameState.army_strength(town["garrison"]))) * 1.25

## Holding a threatened town from its gate (as the classic computer players): the hero moves into the garrison and
## leads all its troops behind the walls, and the gate is free for the Tavern. Stays at the gate when they don't fit.
func _garrison(hero: Dictionary) -> bool:
	for town in world["towns"].values():
		if town["pos"] == hero["pos"] and town["owner"] == hero["owner"] and rules.garrison_hero(town).is_empty():
			return rules.enter_garrison(hero, town)
	return false

## At the start of the day, a garrison hero whose town no army can reach any more comes out to the gate (the gate
## free) to campaign again.
func _release_garrisons(player: Dictionary) -> void:
	for tid in player["towns"]:
		var town: Dictionary = world["towns"][tid]
		if not rules.garrison_hero(town).is_empty() and _town_threat(town) <= 0.0:
			rules.leave_garrison(town)

func _safe_gate(hero: Dictionary, town: Dictionary) -> bool:
	for guard in rules.guards(town["pos"]):
		if GameData.CREATURES[guard["creature"]]["ai_value"] * guard["count"] * 1.6 > _strength(hero):
			return false
	return true

## Hold a threatened town, or assign its nearest capable hero who can arrive today.
## Other heroes continue expanding, and impossible rescues do not consume their turn.
func _defense(hero: Dictionary) -> Dictionary:
	for town in world["towns"].values():
		if town["owner"] != hero["owner"]:
			continue
		var threat := _town_threat(town)
		var garrison := _town_hold(town)
		if threat <= 0.0 or garrison >= threat * 1.4:
			continue
		var resident := rules.hero_at(town["pos"])
		if not resident.is_empty():
			if resident["uid"] == hero["uid"] and _strength(hero) + garrison >= threat * 1.1:
				var intercept := _counterattack(hero, town)
				if not intercept.is_empty():
					return intercept
				return {"hold": true}
			continue
		var defender := -1
		var best_cost := INF
		var best_plan := {}
		for hid in rules.player_of(hero)["heroes"]:
			var candidate: Dictionary = world["heroes"][hid]
			if _strength(candidate) + garrison < threat * 1.1 or not _safe_gate(candidate, town):
				continue
			var plan := rules.plan(candidate, town["pos"])
			if plan["path"].is_empty() or plan["reach"] < plan["path"].size() - 1:
				continue
			var cost: int = plan["costs"].back()
			if cost < best_cost:
				best_cost = cost
				defender = hid
				best_plan = plan
		if defender == hero["uid"]:
			return best_plan
	return {}

## Remove a reachable raider instead of letting a weaker army pin the defender indefinitely (the usual 1.3x margin).
## Keep the gate held if another hostile army could take it while this hero is away.
func _counterattack(hero: Dictionary, town: Dictionary) -> Dictionary:
	var threats := []
	for enemy in world["heroes"].values():
		if enemy["owner"] == hero["owner"] or enemy.get("in_town", false): continue
		var route := rules.plan(enemy, town["pos"])
		if not route["path"].is_empty() and route["costs"].back() <= enemy.get("max_movement", enemy["movement"]):
			threats.append(enemy)
	var garrison := _town_hold(town)
	for enemy in threats:
		var danger := _strength(enemy)
		# A hero standing in a town fights with its garrison, not just the visible army.
		# (with a garrison hero inside, the one at the gate is met outside, alone)
		for target_town in world["towns"].values():
			if target_town["pos"] == enemy["pos"] and rules.garrison_hero(target_town).is_empty():
				danger += GameState.army_strength(target_town["garrison"]) * 1.25
		for guard in rules.guards(enemy["pos"]):
			danger = maxf(danger, GameData.CREATURES[guard["creature"]]["ai_value"] * guard["count"])
		if _strength(hero) <= danger * 1.3: continue  # (the margin for any attack on a hero, see choose)
		var uncovered := false
		for other in threats:
			if other != enemy and _strength(other) * 1.4 > garrison: uncovered = true
		if uncovered: continue
		var plan := rules.plan(hero, enemy["pos"])
		if not plan["path"].is_empty() and plan["reach"] == plan["path"].size() - 1:
			return plan
	return {}

func _object_value(hero: Dictionary, player: Dictionary, o: Dictionary, me: float) -> float:
	match o["type"]:
		"resource":
			return 2.5 * (float(o["amount"]) if o["res"] == "gold" else o["amount"] * (100.0 if o["res"] in ["wood", "ore"] else 250.0))
		"campfire":
			return 2000.0
		"chest":
			return 3000.0
		"artifact":  # (by tier; more for the part of a set the hero already half wears)
			var d: Dictionary = GameData.ARTIFACTS[o["artifact"]]
			var v: float = {"treasure": 1500.0, "minor": 2500.0, "major": 4500.0, "relic": 7000.0}.get(d["tier"], 2500.0)
			if d.has("set"):
				for p in GameData.ARTIFACTS[d["set"]]["parts"]:
					if p in hero.get("artifacts", []) + hero.get("backpack", []):
						v += 2000.0
			return v
		"mine":
			if o["owner"] == hero["owner"]:
				return 0.0
			return 4000.0 if o["mine"] == "gold_mine" else 2000.0
		"shrine":
			return 700.0 if not o["spell"] in hero["spells"] and GameData.SPELLS[o["spell"]]["level"] <= rules.max_spell_level(hero) else 0.0
		"windmill":
			return 0.0 if hero["owner"] in o.get("visited_week", []) else 1000.0
		"learning_stone":
			return 0.0 if hero["uid"] in o.get("visited", []) else 1500.0
		"dwelling":
			var n := dwelling_recruits(hero, o)
			if n <= 0: return 0.0
			var c: Dictionary = GameData.CREATURES[o["creature"]]
			return 1200.0 + c["ai_value"] * mini(n, 10) * 0.3
		"watchtower":
			return 0.0 if hero["owner"] in o.get("visited_by", []) else 150.0
		"war_machine_factory":
			return 1400.0 if not factory_purchases(hero, player).is_empty() else 0.0
		"monster":
			var ms := float(GameData.CREATURES[o["creature"]]["ai_value"] * o["count"])
			if me > ms * 1.6:
				return 600.0 + ms * 0.25
	return 0.0
