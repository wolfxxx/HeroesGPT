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

func _init(r: AdvRules) -> void:
	rules = r
	world = r.world

func run_turn(adv, player: Dictionary) -> String:
	if player.get("ai_day", -1) != world["day"]:
		player["ai_day"] = world["day"]
		manage_towns(player)
		adv.view.rebuild_objects()
	var guard := 0
	for hid in player["heroes"].duplicate():
		var steps := 0
		while steps < 8:
			steps += 1
			guard += 1
			if guard > 60:
				return ""
			var hero: Dictionary = world["heroes"].get(hid, {})
			if hero.is_empty() or hero["movement"] < 50:
				break
			var choice := choose(hero)
			if choice.is_empty():
				hero["movement"] = 0
				break
			var before: int = hero["movement"]
			var army_before := GameState.army_strength(hero["army"])
			var r: String = await adv.move_hero(hero, choice, false)
			if r == "battle":
				return "battle"
			if not adv.is_inside_tree():
				return "battle"
			if world["heroes"].has(hid) and world["heroes"][hid]["movement"] == before and GameState.army_strength(hero["army"]) == army_before:
				hero["movement"] = 0
				break
			# Hero standing in own town: reinforce.
			if world["heroes"].has(hid):
				for town in world["towns"].values():
					if town["pos"] == hero["pos"] and town["owner"] == hero["owner"]:
						_reinforce(hero, town, player)
						rules.hero_in_town(hero, town)
	return ""

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
	for i in 7:
		var s = town["garrison"][i]
		if s and GameState.add_to_army(hero["army"], s["id"], s["count"]):
			town["garrison"][i] = null
	for stack in hero["army"]:
		if stack:
			TownLogic.upgrade_stack(town, _player, stack)

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
	var n: int = o["available"]
	for r in c["cost"]:
		n = mini(n, player["resources"].get(r, 0) / c["cost"][r])
	if n > 0 and GameState.add_to_army(hero["army"], o["creature"], n):
		TownLogic.pay(player, c["cost"], n)
		o["available"] -= n

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
	var defense := _defense(hero)
	if not defense.is_empty():
		hero.erase("ai_goal")
		return {} if defense.has("hold") else defense
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
		if delivery > 400 and _strength(hero) < _strength(leader) * 0.35:
			var meeting := rules.plan(hero, leader["pos"])
			if not meeting["path"].is_empty() and meeting["costs"].back() <= hero.get("max_movement", 1500) * 0.5:
				cands.append([leader["pos"], delivery * 1.2])
	for o in world["objects"].values():
		var d: Vector2i = o["pos"] - hp
		if absi(d.x) > 22 or absi(d.y) > 22:
			continue
		var v := _object_value(hero, player, o, me)
		if v > 0:
			cands.append([o["pos"], v])
	for t in world["towns"].values():
		var v := 0.0
		if t["owner"] != hero["owner"]:
			var def := float(GameState.army_strength(t["garrison"])) * 1.25
			var dh := rules.hero_at(t["pos"])
			if not dh.is_empty():
				def += _strength(dh)
			if me > def * 1.4:
				v = 12000.0
		elif t["pos"] != hp and rules.hero_at(t["pos"]).is_empty():
			var reinforcement := _transfer_value(hero, t["garrison"], false)
			if reinforcement > me * 0.25:
				v = 2500.0 + reinforcement * 0.6
		if v > 0:
			cands.append([t["pos"], v])
	for e in world["heroes"].values():
		if e["owner"] != hero["owner"]:
			# A hero at a town defends with its garrison: the town candidate above already
			# evaluates that combined force. Do not add a deceptively cheap hero-only attack.
			var in_town := false
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
		var plan := rules.plan(hero, c[0])
		if plan["path"].is_empty() or plan["reach"] == 0:
			continue
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

## Largest hostile army that can reach the gate next turn, following the actual terrain/occupancy path.
func _town_threat(town: Dictionary) -> float:
	var threat := 0.0
	for enemy in world["heroes"].values():
		if enemy["owner"] == town["owner"]:
			continue
		var budget: int = enemy.get("max_movement", enemy["movement"])
		if Vector2(enemy["pos"] - town["pos"]).length() * 50.0 > budget:
			continue
		var plan := rules.plan(enemy, town["pos"])
		if not plan["path"].is_empty() and plan["costs"].back() <= budget:
			threat = maxf(threat, _strength(enemy))
	return threat

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
		var garrison := GameState.army_strength(town["garrison"]) * 1.25
		if threat <= 0.0 or garrison >= threat * 1.4:
			continue
		var resident := rules.hero_at(town["pos"])
		if not resident.is_empty():
			if resident["uid"] == hero["uid"] and _strength(hero) + garrison >= threat * 1.1:
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
			if o["available"] <= 0:
				return 0.0
			var c: Dictionary = GameData.CREATURES[o["creature"]]
			if player["resources"]["gold"] < c["cost"].get("gold", 0) * 2:
				return 0.0
			return 1200.0 + c["ai_value"] * mini(o["available"], 10) * 0.3
		"watchtower":
			return 0.0 if hero["owner"] in o.get("visited_by", []) else 150.0
		"war_machine_factory":
			return 1400.0 if not factory_purchases(hero, player).is_empty() else 0.0
		"monster":
			var ms := float(GameData.CREATURES[o["creature"]]["ai_value"] * o["count"])
			if me > ms * 1.6:
				return 600.0 + ms * 0.25
	return 0.0
