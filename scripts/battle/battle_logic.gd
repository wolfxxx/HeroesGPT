extends RefCounted
class_name BattleLogic
## Pure combat rules on a 15x11 hex grid (odd rows shifted right, HoMM3 layout).
## Large ("two_hex") creatures stand on two hexes of one row: s["hex"] is the front (head) hex, the tail is the
## hex behind it, towards the stack's own side (cells()).
## Mutating calls return Arrays of "events" the battle scene animates:
##   {"t": "move", "s": stack, "path": [hex...]}
##   {"t": "attack", "a": stack, "d": stack, "ranged": bool, "retaliation": bool, "dmg": int, "killed": int, "lucky": bool}
##   {"t": "spell", "spell": id, "side": int, "targets": [stack...], "hex": Vector2i, "dmg": {stack_uid: int}, "killed": {uid: int}}
##   {"t": "death", "s": stack}   {"t": "text", "text": String}   {"t": "heal", "s": stack, "amount": int}
##   {"t": "catapult", "s": stack, "seg": int, "hit": bool, "destroyed": bool}
## War machines are stacks with "machine": true (they never move and don't count for victory). They stand on a back
## rank just outside the grid (column -1 for the attacker, COLS for the defender), where nothing else may stand but
## where they can be shot or struck from the first column. In a siege the defenders stand behind a wall (column
## WALL_X, segments with hit points) with a gate only they can pass; a Citadel adds a moat in front of it and an arrow
## tower in the keep, a Castle two round arrow towers at the ends of the wall (machine stacks with "tower": true that
## nothing can target); the defending hero's own machines stay in the town.

const COLS := 15
const ROWS := 11
const SLOT_ROWS := [0, 2, 4, 5, 6, 8, 10]

var stacks: Array = []        # all stacks, including dead (alive=false)
var obstacles := {}           # Vector2i -> obstacle index (1..4)
var heroes: Array = [null, null]
var players: Array = [-1, -1]
var ai_side: Array = [true, true]
var round_num := 0
var order: Array = []         # stacks yet to act this round
var waited: Array = []        # stacks that chose to wait
var hero_cast := [false, false]
var log_lines: Array = []
var rng := RandomNumberGenerator.new()
var start_counts := {}        # uid -> count at battle start
var terrain := "grass"
var _uid := 0
var siege := 0                # 0: open field, 1: Fort (wall, gate), 2: Citadel (+ moat, keep turret), 3: Castle (+ two towers)
var siege_morale := 0         # morale for the defenders of a siege (the Temple's Chapter House)
var siege_faction := "haven"
var town_name := ""           # the defended town (its garrison is named after it when no hero leads it)
var walls: Array = []         # segments: {"rows": [int], "kind": "wall"|"tower"|"gate", "hp": int}
const WALL_X := 11
const MOAT_X := 10
const SEGMENTS := [[[0], "tower"], [[1, 2], "wall"], [[3, 4], "wall"], [[5], "gate"], [[6, 7], "wall"], [[8, 9], "wall"],
	[[10], "tower"]]
const MACHINE_ROWS := {"ballista": 2, "catapult": 4, "ammo_cart": 6, "first_aid_tent": 8}
const SEG_NAMES := ["the upper tower", "the upper wall", "the wall above the gate", "the gate",
	"the wall below the gate", "the lower wall", "the lower tower"]
## Rows 0 and 10 hold the round towers (a Castle's) or the wall's unbroken ends: no one walks through them, fallen or
## not (as in the classic, where only the four stretches of wall and the gate open a way in).
const SOLID_SEGS := [0, 6]

# ---------------------------------------------------------------------------------------------
func setup(s: Dictionary) -> void:
	if s.has("seed"):
		rng.seed = int(s["seed"])
	else:
		rng.randomize()
	heroes = [s.get("attacker_hero"), s.get("defender_hero")]
	players = [s.get("attacker_player", -1), s.get("defender_player", -1)]
	ai_side = [s.get("attacker_ai", false), s.get("defender_ai", true)]
	terrain = s.get("terrain", "grass")
	siege = int(s.get("siege", 0))
	siege_faction = s.get("siege_faction", "haven")
	siege_morale = int(s.get("siege_morale", 0))
	town_name = s.get("defender_town", "")
	if siege > 0:
		for sg in SEGMENTS:
			walls.append({"rows": sg[0], "kind": sg[1], "hp": 2})
	_deploy(s.get("attacker_army", []), 0)
	_deploy(s.get("defender_army", []), 1)
	for side in 2:
		var h = heroes[side]
		if h != null and not (siege > 0 and side == 1):
			for m in h.get("machines", []):
				if m in GameData.WAR_MACHINES:
					_deploy_machine(m, side, Vector2i(-1 if side == 0 else COLS, MACHINE_ROWS[m]))
	if siege > 0 and heroes[0] != null:
		_deploy_machine("catapult", 0, Vector2i(-1, MACHINE_ROWS["catapult"]))
	if siege >= 2:  # the keep (which no catapult can bring down), and with a Castle the two wall towers
		for i in ([-1, 0, walls.size() - 1] if siege >= 3 else [-1]):
			var t := _deploy_machine("arrow_tower", 1, Vector2i(WALL_X, walls[i]["rows"][0]) if i >= 0 else Vector2i(COLS, 5))
			t["tower"] = true
			t["seg"] = i
	# obstacles (in a siege only in front of the moat)
	var n := rng.randi_range(2, 5)
	var tries := 0
	while obstacles.size() < n and tries < 100:
		tries += 1
		var h := Vector2i(rng.randi_range(3, MOAT_X - 2 if siege > 0 else 11), rng.randi_range(1, 9))
		if stack_at(h) == null and not obstacles.has(h):
			obstacles[h] = rng.randi_range(1, 8)  # (which picture: battle.gd OBSTACLES by terrain)
	_new_round()

## A hero's army takes the field in its formation (as the classic hero screen sets it): spread over the whole
## edge by slot, or grouped, the stacks on rows next to each other in the middle.
func _deploy(army: Array, side: int) -> void:
	var h = heroes[side]
	var grouped: bool = h != null and h.get("formation", "spread") == "grouped"
	var filled := []
	for i in mini(7, army.size()):
		if army[i] != null and army[i]["count"] > 0:
			filled.append(i)
	for i in filled:
		var a = army[i]
		var c: Dictionary = GameData.CREATURES[a["id"]]
		var wide: bool = "two_hex" in c["abilities"]
		var x: int = (1 if wide else 0) if side == 0 else COLS - (2 if wide else 1)
		var hex := Vector2i(x, SLOT_ROWS[i]) + _stagger(i, side)
		if grouped:
			hex = Vector2i(x, 5 - (filled.size() - 1) / 2 + filled.find(i))
		_uid += 1
		var st := {
			"uid": _uid, "id": a["id"], "side": side, "slot": i, "count": a["count"],
			"hp_top": c["hp"] + (GameState.hero_stat(h, "hp") if h != null else 0),
			"hex": hex, "shots": c["shots"],
			"retaliations": 2 if "two_retaliations" in c["abilities"] else 1, "effects": {},
			"alive": true, "defending": false, "waited": false, "acted": false,
		}
		stacks.append(st)
		start_counts[st["uid"]] = st["count"]

func _deploy_machine(id: String, side: int, hex: Vector2i) -> Dictionary:
	var c: Dictionary = GameData.CREATURES[id]
	_uid += 1
	var st := {"uid": _uid, "id": id, "side": side, "slot": -1, "count": 1, "hp_top": c["hp"], "hex": hex,
		"shots": c["shots"], "retaliations": 0, "effects": {}, "alive": true, "defending": false, "waited": false,
		"acted": false, "machine": true}
	stacks.append(st)
	start_counts[st["uid"]] = 1
	return st

## The middle slot (row 5, between the stacks on rows 4 and 6) stands two hexes forward, so the three middle stacks
## don't merge into one heap of figures; row 8 one forward, clear of the tall figure that usually stands on row 10.
static func _stagger(slot: int, side: int) -> Vector2i:
	var k: int = {3: 2, 5: 1}.get(slot, 0)
	return Vector2i(k if side == 0 else -k, 0)

func cdata(s: Dictionary) -> Dictionary:
	return GameData.CREATURES[s["id"]]

## A creature's health in this battle: its own, plus what its hero's artifacts give every creature (machines and
## towers excepted).
func max_hp(s: Dictionary) -> int:
	var v: int = cdata(s)["hp"]
	var h = heroes[s["side"]] if s["side"] >= 0 and s["side"] < heroes.size() else null
	if h != null and not s.get("machine", false) and not s.get("tower", false):
		v += GameState.hero_stat(h, "hp")
	return v

## Whether the side's army is immune to the spell (a combination artifact of its hero).
func immune(side: int, spell: String) -> bool:
	var h = heroes[side]
	if h == null:
		return false
	var sp: Dictionary = GameData.SPELLS[spell]
	return spell in GameState.hero_flags(h, "immune_spells") \
		or (sp.has("damage") and sp["school"] in GameState.hero_flags(h, "immune_school"))

## Whether this stack is spared by the spell: its side's protection (above); a creature whose hide turns spells up to
## a level (HoMM3's dragons: friendly spells too); or, for a mind spell (Blind, Berserk), a creature without a mind to
## bend (the undead, the ushabti as HoMM3's golems, Giants and Titans, war machines).
func stack_immune(s: Dictionary, spell: String) -> bool:
	if immune(s["side"], spell):
		return true
	if int(GameData.SPELLS[spell]["level"]) <= int(cdata(s).get("spell_immunity", 0)):
		return true
	if spell == "blind" and has_ab(s, "blind_immune"):  # (Morlocks: eyes long given up to the dark)
		return true
	if GameData.SPELLS[spell].get("mind", false):
		return not living(s) or has_ab(s, "golem") or has_ab(s, "mind_immune") or s.get("machine", false)
	return false

## Alive in HoMM3's sense: not undead, not a made thing (Gargoyles, Golems) and not a war machine. Only the living
## feel morale, are drained, diseased, struck by Death Ripple or a Lich's cloud, or bent by mind spells.
func living(s: Dictionary) -> bool:
	return not has_ab(s, "undead") and not has_ab(s, "unliving") and not s.get("machine", false)

func has_ab(s: Dictionary, ab: String) -> bool:
	return ab in cdata(s)["abilities"]

## Living stacks (of one side). Arrow towers are left out (nothing targets them) unless `towers`.
func alive_stacks(side := -1, towers := false) -> Array:
	var out := []
	for s in stacks:
		if s["alive"] and (side < 0 or s["side"] == side) and (towers or not s.get("tower", false)):
			out.append(s)
	return out

## Living creature stacks of a side (war machines and towers don't win a battle).
func fighters(side: int) -> int:
	var n := 0
	for s in stacks:
		if s["alive"] and s["side"] == side and not s.get("machine", false):
			n += 1
	return n

# ---------------------------------------------------------------------------------------------
# Siege
# ---------------------------------------------------------------------------------------------
## How the battle result names a side: its hero, else a town's garrison, else the neutral creatures.
func side_name(side: int) -> String:
	if heroes[side]:
		return heroes[side]["name"]
	return "The garrison of %s" % town_name if side == 1 and town_name != "" else "Neutral creatures"

## Index of the wall segment standing on a hex (-1: none, or no siege).
func wall_seg(h: Vector2i) -> int:
	if siege == 0 or h.x != WALL_X:
		return -1
	for i in walls.size():
		if h.y in walls[i]["rows"]:
			return i
	return -1

## Does an intact wall keep a stack of `side` off this hex? (Defenders pass their own gate.)
func wall_blocks(h: Vector2i, side: int) -> bool:
	var i := wall_seg(h)
	if i < 0:
		return false
	if i in SOLID_SEGS:
		return true
	if walls[i]["hp"] <= 0:
		return false
	return not (walls[i]["kind"] == "gate" and side == 1)

## The moat in front of the wall (a Citadel's or a Castle's; not before the gate: the bridge): walking into it ends
## the move.
func is_moat(h: Vector2i) -> bool:
	return siege >= 2 and h.x == MOAT_X and h.y != 5

## Shots from outside at a stack behind an unbroken stretch of wall do half damage.
func behind_wall(a: Dictionary, d: Dictionary) -> bool:
	if siege == 0 or a["side"] != 0 or has_ab(a, "no_wall_penalty"):  # (the Magi's bolts pass the walls)
		return false
	var i := wall_seg(Vector2i(WALL_X, d["hex"].y))
	return i >= 0 and (walls[i]["hp"] > 0 or i in SOLID_SEGS) and a["hex"].x < WALL_X and d["hex"].x > WALL_X

## A war machine's turn: the ballista and the towers shoot, the tent heals, the catapult batters the wall.
func machine_act(s: Dictionary) -> Array:
	var ev := []
	match s["id"]:
		"ballista", "arrow_tower":
			var best = null
			var bv := -1.0
			for e in alive_stacks(1 - s["side"]):
				var v := BattleAI._value_of_damage(self, e, (damage_range(s, e, true)[0] + damage_range(s, e, true)[1]) * 0.5)
				if v > bv:
					bv = v
					best = e
			if best != null:
				ev = _strike(s, best, true, 0, false)
		"first_aid_tent":
			var best = null
			var gap := 0
			for a in alive_stacks(s["side"]):
				var g: int = max_hp(a) - a["hp_top"]
				if not a.get("machine", false) and g > gap:
					gap = g
					best = a
			if best != null:
				var got := heal(best, rng.randi_range(1, 25), false)
				log_lines.append("The First Aid Tent heals %s for %d." % [_name(best), got])
				ev = [{"t": "heal", "s": best, "amount": got, "log": log_lines.size()}]
		"catapult":
			for shot in 2:  # two boulders a turn
				ev += _catapult_shot(s)
	finish_turn(s)
	return ev

## Can the catapult bring this segment down? The stretches of wall and the gate; the round towers only where a
## Castle has them (otherwise rows 0 and 10 are the wall's ends, which it leaves alone).
func breakable(i: int) -> bool:
	return walls[i]["kind"] != "tower" or siege >= 3

## One boulder at a random standing stretch of wall (cracked ones more likely); a fallen tower falls silent.
func _catapult_shot(s: Dictionary) -> Array:
	var ev := []
	var cands := []
	for i in walls.size():
		if walls[i]["hp"] > 0 and breakable(i):  # (the crew keeps at a cracked stretch until it falls)
			for k in (2 if walls[i]["kind"] in ["gate", "tower"] else 1) * (4 if walls[i]["hp"] < 2 else 1):
				cands.append(i)
	if not cands.is_empty():
		var i: int = cands[rng.randi() % cands.size()]
		var hit := rng.randf() < 0.7
		var destroyed := false
		if hit:
			walls[i]["hp"] -= 1
			destroyed = walls[i]["hp"] <= 0
		var what: String = SEG_NAMES[i] if i < SEG_NAMES.size() else "the wall"
		log_lines.append(("The catapult %s %s." % ["breaches" if destroyed else "hits", what]) if hit
			else "The catapult misses %s." % what)
		ev = [{"t": "catapult", "s": s, "seg": i, "hit": hit, "destroyed": destroyed, "log": log_lines.size()}]
		if destroyed and walls[i]["kind"] == "tower":
			for t in stacks:
				if t.get("tower", false) and t.get("seg", -1) == i and t["alive"]:
					t["alive"] = false
					t["count"] = 0
					order.erase(t)
					waited.erase(t)
					ev.append({"t": "death", "s": t})
	return ev

## The war machines (not the catapult) of a side still standing: what its hero keeps after the battle.
func machines_left(side: int) -> Array:
	var out := []
	for s in stacks:
		if s["side"] == side and s["alive"] and s.get("machine", false) and s["id"] in GameData.WAR_MACHINES:
			out.append(s["id"])
	return out

# ---------------------------------------------------------------------------------------------
# Hex geometry (offset coordinates, odd rows shifted right)
# ---------------------------------------------------------------------------------------------
static func in_bounds(h: Vector2i) -> bool:
	return h.x >= 0 and h.y >= 0 and h.x < COLS and h.y < ROWS

## The grid plus the war machines' back rank on either side (only machines stand there).
static func on_field(h: Vector2i) -> bool:
	return h.x >= -1 and h.y >= 0 and h.x <= COLS and h.y < ROWS

static func neighbors(h: Vector2i) -> Array:
	var d: Array
	if h.y % 2 == 0:
		d = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(0, 1), Vector2i(-1, 1)]
	else:
		d = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(0, 1)]
	var out := []
	for o in d:
		var n: Vector2i = h + o
		if on_field(n):  # (a machine on the back rank has neighbours on the grid; moves still check in_bounds)
			out.append(n)
	return out

static func to_cube(h: Vector2i) -> Vector3i:
	var x := h.x - (h.y - (h.y & 1)) / 2
	var z := h.y
	return Vector3i(x, -x - z, z)

static func from_cube(c: Vector3i) -> Vector2i:
	return Vector2i(c.x + (c.z - (c.z & 1)) / 2, c.z)

static func distance(a: Vector2i, b: Vector2i) -> int:
	var ca := to_cube(a)
	var cb := to_cube(b)
	return (absi(ca.x - cb.x) + absi(ca.y - cb.y) + absi(ca.z - cb.z)) / 2

func stack_at(h: Vector2i) -> Variant:
	for s in stacks:
		if s["alive"] and not s.get("tower", false) and (s["hex"] == h or (is_wide(s) and tail(s) == h)):
			return s
	return null

func is_free(h: Vector2i) -> bool:
	return in_bounds(h) and not obstacles.has(h) and stack_at(h) == null and wall_seg(h) < 0

func is_wide(s: Dictionary) -> bool:
	return has_ab(s, "two_hex")

## Offset from a stack's head hex to its tail: towards its own side of the field.
static func tail_dir(side: int) -> Vector2i:
	return Vector2i(-1 if side == 0 else 1, 0)

func tail(s: Dictionary, head = null) -> Vector2i:
	return (s["hex"] if head == null else head) + tail_dir(s["side"])

## The hexes a stack covers with its head on `head` (default: where it stands).
func cells(s: Dictionary, head = null) -> Array:
	var h: Vector2i = s["hex"] if head == null else head
	return [h, h + tail_dir(s["side"])] if is_wide(s) else [h]

## Can the stack stand with its head on `head` (in bounds, no obstacle, no other stack)?
func fits(s: Dictionary, head: Vector2i) -> bool:
	for c in cells(s, head):
		if not in_bounds(c) or obstacles.has(c) or wall_blocks(c, s["side"]):
			return false
		var o = stack_at(c)
		if o != null and o != s:
			return false
	return true

## Hex distance between two stacks (closest cells).
func stack_distance(a: Dictionary, b: Dictionary) -> int:
	var best := 999
	for x in cells(a):
		for y in cells(b):
			best = mini(best, distance(x, y))
	return best

func _touches(a_cells: Array, b_cells: Array) -> bool:
	for x in a_cells:
		for y in b_cells:
			if distance(x, y) == 1:
				return true
	return false

# ---------------------------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------------------------
func speed(s: Dictionary) -> int:
	var v: int = cdata(s)["speed"]
	var h = heroes[s["side"]]
	if h != null and not s.get("machine", false) and not s.get("tower", false):
		v += GameState.hero_stat(h, "speed")  # (a ring of swiftness)
	if s["effects"].has("haste"):
		v += 3
	if s["effects"].has("slow"):
		v = int(ceil(v * 0.75))
	return maxi(1, v)

func attack_stat(s: Dictionary) -> int:
	var v: int = cdata(s)["attack"]
	var h = heroes[s["side"]]
	if h:
		v += GameState.hero_stat(h, "attack")
	if s["effects"].has("weakness"):
		v -= 3
	if s["effects"].has("disease"):
		v -= 2
	return maxi(0, v)

func defense_stat(s: Dictionary) -> int:
	var v: int = cdata(s)["defense"]
	var h = heroes[s["side"]]
	if h:
		v += GameState.hero_stat(h, "defense")
	if s["effects"].has("stone_skin"):
		v += 3
	if s["effects"].has("disease"):
		v -= 2
	if s["defending"]:
		v = int(ceil(v * 1.2)) + 1
	return maxi(0, v)

func total_hp(s: Dictionary) -> int:
	return (s["count"] - 1) * max_hp(s) + s["hp_top"] if s["count"] > 0 else 0

func luck(side: int) -> int:
	var h = heroes[side]
	if h == null:
		return 0
	return int(h["skills"].get("luck", 0)) + GameState.hero_stat(h, "luck") + int(h.get("next_battle_luck", 0))

## Morale of a stack's side (-3..3): the hero's Leadership and artifacts, -1 for each extra faction in the army.
## The undead and the made things feel nothing: always 0 for them.
func morale(side: int, s = null) -> int:
	if s != null and (has_ab(s, "undead") or has_ab(s, "unliving")):
		return 0
	var v := 0
	var h = heroes[side]
	if h != null:
		v += int(h["skills"].get("leadership", 0)) + GameState.hero_stat(h, "morale")
	if siege > 0 and side == 1:
		v += siege_morale
	var factions := {}
	for o in alive_stacks(side):
		if not o.get("machine", false):  # (machines are no faction of their own)
			factions[cdata(o).get("faction", "")] = true
	v -= maxi(0, factions.size() - 1)
	if s != null and has_ab(s, "positive_morale"):  # (Minotaurs: never below +1)
		v = maxi(v, 1)
	return clampi(v, -3, 3)

## Bad morale: a stack may freeze and lose its turn (1 in 12 per point below zero).
func check_bad_morale(s: Dictionary) -> bool:
	var m := morale(s["side"], s)
	return m < 0 and rng.randf() < -m / 12.0

## Good morale: once a round, a stack that has just acted may act again (1 in 24 per point). Puts it back at the
## front of the order and returns true.
func roll_good_morale(s: Dictionary) -> bool:
	if not s["alive"] or s.get("morale_turn", false) or is_over() >= 0:
		return false
	var m := morale(s["side"], s)
	if m <= 0 or rng.randf() >= m / 24.0:
		return false
	s["morale_turn"] = true
	s["acted"] = false
	s["defending"] = false
	order.push_front(s)
	log_lines.append("%s %s with courage and %s again!" % [_name(s), "is filled" if s["count"] == 1 else "are filled", "acts" if s["count"] == 1 else "act"])
	return true

func hero_skill(side: int, sk: String) -> int:
	var h = heroes[side]
	return 0 if h == null else int(h["skills"].get(sk, 0))

# ---------------------------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------------------------
func is_flyer(s: Dictionary) -> bool:
	return has_ab(s, "flying")

## hex -> distance for every hex the stack can move to this turn.
func reachable(s: Dictionary) -> Dictionary:
	var spd := speed(s)
	var out := {}
	if s.get("machine", false):
		return out
	if is_flyer(s):
		for y in ROWS:
			for x in COLS:
				var h := Vector2i(x, y)
				var d := distance(s["hex"], h)
				if d <= spd and d > 0 and fits(s, h):
					out[h] = d
		return out
	var dist := {s["hex"]: 0}
	var frontier := [s["hex"]]
	while frontier.size() > 0:
		var nxt := []
		for h in frontier:
			for n in neighbors(h):
				if dist.has(n) or not fits(s, n):
					continue
				dist[n] = dist[h] + 1
				if dist[n] < spd and not is_moat(n):  # (the moat: in, but no further this turn)
					nxt.append(n)
				out[n] = dist[n]
		frontier = nxt
	return out

func path_to(s: Dictionary, target: Vector2i) -> Array:
	if is_flyer(s):
		return [s["hex"], target]
	var prev := {s["hex"]: s["hex"]}
	var frontier := [s["hex"]]
	while frontier.size() > 0:
		var nxt := []
		for h in frontier:
			for n in neighbors(h):
				if prev.has(n) or not fits(s, n):
					continue
				if is_moat(n) and n != target:
					continue
				prev[n] = h
				if n == target:
					var path := [n]
					var c: Vector2i = h
					while c != s["hex"]:
						path.push_front(c)
						c = prev[c]
					path.push_front(s["hex"])
					return path
				nxt.append(n)
		frontier = nxt
	return []

func adjacent_enemies(s: Dictionary) -> Array:
	var out := []
	for c in cells(s):
		for n in neighbors(c):
			var o = stack_at(n)
			if o and o["side"] != s["side"] and not o in out:
				out.append(o)
	return out

## Every stack standing on `hexes`, each once (a large stack covers two of them).
func stacks_on(hexes: Array) -> Array:
	var out := []
	for h in hexes:
		var o = stack_at(h)
		if o and not o in out:
			out.append(o)
	return out

func can_shoot(s: Dictionary) -> bool:
	return s["shots"] > 0 and adjacent_enemies(s).is_empty()

## Head hexes from which s can melee target this turn (includes where it stands if already adjacent).
func attack_positions(s: Dictionary, target: Dictionary, reach: Dictionary = {}) -> Array:
	if reach.is_empty():
		reach = reachable(s)
	var tc := cells(target)
	var cand := []
	for c in tc:
		for n in neighbors(c):
			cand.append(n)
			if is_wide(s):
				cand.append(n - tail_dir(s["side"]))  # the tail touches the target
	var out := []
	for h in cand:
		if h in out or not (h == s["hex"] or reach.has(h)):
			continue
		if _touches(cells(s, h), tc):
			out.append(h)
	return out

# ---------------------------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------------------------
func damage_range(a: Dictionary, d: Dictionary, ranged: bool, moved := 0) -> Array:
	var c := cdata(a)
	var lo: float = c["dmg"][0]
	var hi: float = c["dmg"][1]
	if a["effects"].has("bless"):
		lo = hi
	elif a["effects"].has("curse"):
		hi = lo
	var mult := _mult(a, d, ranged, moved)
	return [maxi(1, int(lo * a["count"] * mult)), maxi(1, int(hi * a["count"] * mult))]

func _mult(a: Dictionary, d: Dictionary, ranged: bool, moved: int) -> float:
	var A := attack_stat(a)
	var D := defense_stat(d)
	var m := 1.0
	if A > D:
		m += minf(3.0, 0.05 * (A - D))
	else:
		m -= minf(0.7, 0.025 * (D - A))
	var bonus := 1.0
	if ranged:
		bonus += 0.15 * hero_skill(a["side"], "archery")
		if stack_distance(a, d) > 10 and not a.get("machine", false):  # (towers and the ballista: no range penalty)
			bonus *= 0.5
		if behind_wall(a, d):
			bonus *= 0.5
	else:
		bonus += 0.10 * hero_skill(a["side"], "offense")
		if cdata(a)["shots"] > 0 and not has_ab(a, "no_melee_penalty"):
			bonus *= 0.5  # shooters are poor in melee (not the Titans)
		if has_ab(a, "jousting") and not has_ab(d, "anti_cavalry"):
			bonus += 0.05 * moved
		if d["effects"].has("shield"):
			bonus *= 0.85
	if has_ab(a, "hates_undead") and has_ab(d, "undead"):
		bonus *= 1.5
	if d["id"] in cdata(a).get("hates", []):  # (Titans and Black Dragons)
		bonus *= 1.5
	bonus *= 1.0 - 0.07 * hero_skill(d["side"], "armorer")
	return m * bonus

func _roll_damage(a: Dictionary, d: Dictionary, ranged: bool, moved: int) -> int:
	var c := cdata(a)
	var lo: int = c["dmg"][0]
	var hi: int = c["dmg"][1]
	var base := 0
	if a["effects"].has("bless"):
		base = hi * a["count"]
	elif a["effects"].has("curse"):
		base = lo * a["count"]
	elif a["count"] <= 10:
		for i in a["count"]:
			base += rng.randi_range(lo, hi)
	else:
		var sum := 0
		for i in 10:
			sum += rng.randi_range(lo, hi)
		base = int(sum * a["count"] / 10.0)
	return maxi(1, int(base * _mult(a, d, ranged, moved)))

## Applies dmg to stack. Returns number killed.
func apply_damage(d: Dictionary, dmg: int) -> int:
	var hp: int = max_hp(d)
	var before: int = d["count"]
	var pool := total_hp(d) - dmg
	if pool <= 0:
		d["count"] = 0
		d["hp_top"] = 0
		d["alive"] = false
		order.erase(d)
		waited.erase(d)
		return before
	d["count"] = int(ceil(pool / float(hp)))
	d["hp_top"] = pool - (d["count"] - 1) * hp
	return before - d["count"]

func heal(d: Dictionary, amount: int, resurrect: bool) -> int:
	var hp: int = max_hp(d)
	var cap: int = start_counts.get(d["uid"], d["count"]) * hp if resurrect else total_hp(d) - d["hp_top"] + hp
	var pool := mini(cap, total_hp(d) + amount)
	var gained := pool - total_hp(d)
	d["count"] = int(ceil(pool / float(hp)))
	d["hp_top"] = pool - (d["count"] - 1) * hp
	return gained

# ---------------------------------------------------------------------------------------------
# Turn order
# ---------------------------------------------------------------------------------------------
func _new_round() -> void:
	round_num += 1
	hero_cast = [false, false]
	# (as in the classic: the ammo cart never acts, it only keeps the quivers full, so it takes no turn)
	order = alive_stacks(-1, true).filter(func(s): return s["id"] != "ammo_cart")
	order.sort_custom(_turn_before)
	waited = []
	for s in order:
		s["defending"] = false
		s["waited"] = false
		s["acted"] = false
		s["morale_turn"] = false
		s["retaliations"] = 2 if has_ab(s, "two_retaliations") else 1
		# tick effects
		var fx: Dictionary = s["effects"]
		for k in fx.keys():
			fx[k] -= 1
			if fx[k] <= 0:
				fx.erase(k)
		if has_ab(s, "regenerate"):
			s["hp_top"] = max_hp(s)

## Faster first; on a tie the attacker, then the lower army slot.
func _turn_before(a: Dictionary, b: Dictionary) -> bool:
	var sa := speed(a)
	var sb := speed(b)
	if sa != sb:
		return sa > sb
	if a["side"] != b["side"]:
		return a["side"] < b["side"]
	return a["slot"] < b["slot"]

## A spell that changes speed in the middle of a round moves the stacks yet to act (as the classic: a slowed stack
## acts later this round already); the stack acting now keeps its turn.
func _resort_order() -> void:
	if order.size() < 3:
		return
	var rest := order.slice(1)
	rest.sort_custom(_turn_before)
	order = [order[0]] + rest

## Returns the stack whose turn it is (advancing rounds as needed).
func current() -> Variant:
	if is_over() >= 0:
		return null
	for i in 3:
		if order.size() > 0:
			return order[0]
		if waited.size() > 0:
			return waited[0]
		_new_round()
	return null

## Upcoming acting order (for the queue UI).
func upcoming(n: int) -> Array:
	var out := []
	for s in order:
		out.append(s)
	for s in waited:
		out.append(s)
	if out.size() < n:
		var nxt := alive_stacks().filter(func(s): return s["id"] != "ammo_cart")
		nxt.sort_custom(_turn_before)
		for s in nxt:
			out.append(s)
	return out.slice(0, n)

func finish_turn(s: Dictionary) -> void:
	s["acted"] = true
	order.erase(s)
	waited.erase(s)

func do_wait(s: Dictionary) -> bool:
	if s["waited"] or not order.has(s):
		return false
	s["waited"] = true
	order.erase(s)
	waited.push_front(s)  # waited stacks act in reverse order of waiting
	return true

func do_defend(s: Dictionary) -> Array:
	s["defending"] = true
	finish_turn(s)
	return [{"t": "text", "text": "%s %s." % [_name(s), "defends" if s["count"] == 1 else "defend"]}]

func _name(s: Dictionary) -> String:
	var c := cdata(s)
	return c["plural"] if s["count"] != 1 else c["name"]

# ---------------------------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------------------------
func do_move(s: Dictionary, target: Vector2i) -> Array:
	var path := path_to(s, target)
	if path.is_empty():
		return []
	s["hex"] = target
	finish_turn(s)
	return [{"t": "move", "s": s, "path": path}]

func do_melee(s: Dictionary, target: Dictionary, from_hex: Vector2i) -> Array:
	var ev := []
	var moved := 0
	var start: Vector2i = s["hex"]
	if from_hex != s["hex"]:
		var path := path_to(s, from_hex)
		if path.is_empty():
			return []
		moved = path.size() - 1 if not is_flyer(s) else distance(s["hex"], from_hex)
		s["hex"] = from_hex
		ev.append({"t": "move", "s": s, "path": path})
	var woke := _wake(target)
	ev += _strike(s, target, false, moved, false, 0.5 if woke == "stone" else 1.0)  # (stone takes half, and wakes)
	if target["alive"] and s["alive"] and not target.get("machine", false) and target["retaliations"] > 0 and not has_ab(s, "no_retaliation") \
			and _can_act(target) and woke != "stone":
		target["retaliations"] -= 1
		# (a blinded stack, struck, wakes and strikes back at half; a paralyzed one at a quarter)
		ev += _strike(target, s, false, 0, true, {"blind": 0.5, "paralyze": 0.25}.get(woke, 1.0))
	if s["alive"] and has_ab(s, "double_strike") and target["alive"]:
		ev += _strike(s, target, false, 0, false)
	if s["alive"] and has_ab(s, "strike_and_return") and s["hex"] != start and fits(s, start):  # (Harpies fly home)
		ev.append({"t": "move", "s": s, "path": [s["hex"], start]})
		s["hex"] = start
	s["effects"].erase("berserk")  # (Berserk ends once the stack has attacked)
	finish_turn(s)
	return ev

func do_shoot(s: Dictionary, target: Dictionary) -> Array:
	var woke := _wake(target)
	var ev := _strike(s, target, true, 0, false, 0.5 if woke == "stone" else 1.0)
	var cart := false
	for o in alive_stacks(s["side"]):
		if o["id"] == "ammo_cart":
			cart = true
	if not cart:  # (an ammo cart keeps the quivers full)
		s["shots"] -= 1
	if has_ab(s, "death_cloud"):
		var hit := {}
		var killed := {}
		var around := []
		for c in cells(target):
			around += neighbors(c)
		for o in stacks_on(around):
			if o != target and living(o):
				var dmg := maxi(1, int(_roll_damage(s, o, true, 0) * 0.5))
				hit[o["uid"]] = dmg
				killed[o["uid"]] = apply_damage(o, dmg)
		if hit.size() > 0:
			var targets := []
			for o in stacks:
				if hit.has(o["uid"]):
					targets.append(o)
			ev.append({"t": "spell", "spell": "death_cloud", "side": s["side"], "targets": targets, "hex": target["hex"], "dmg": hit, "killed": killed})
			for o in targets:
				if not o["alive"]:
					ev.append({"t": "death", "s": o})
	s["effects"].erase("berserk")
	finish_turn(s)
	return ev

func _can_act(s: Dictionary) -> bool:
	return s["alive"]

## An attack ends Blind, paralysis and stone on the stack it strikes (HoMM3): which it was in ("" if none).
func _wake(s: Dictionary) -> String:
	for k in ["stone", "paralyze", "blind"]:
		if s["effects"].erase(k):
			return k
	return ""

## Medusas' stone gaze and Scorpicores' venom (HoMM3): one in five melee strikes, retaliations too, that the target
## survives turns it to stone (it stands three rounds, takes half damage and wakes when struck; Morlocks and war
## machines are spared) or paralyzes it (it stands three rounds and wakes when struck, striking back at a quarter;
## war machines and Black Dragons are spared).
func stone_or_venom(a: Dictionary, d: Dictionary) -> String:
	if not d["alive"] or d.get("machine", false) or cdata(d).get("machine", false) or d.get("tower", false):
		return ""
	if has_ab(a, "stone_gaze") and not has_ab(d, "blind_immune"):
		return "stone"
	if has_ab(a, "paralyze") and int(cdata(d).get("spell_immunity", 0)) < 5:
		return "paralyze"
	return ""

func _strike(a: Dictionary, d: Dictionary, ranged: bool, moved: int, retaliation: bool, mult := 1.0) -> Array:
	var dmg := _roll_damage(a, d, ranged, moved)
	if mult != 1.0:
		dmg = maxi(1, int(dmg * mult))
	var lucky := false
	var lk := luck(a["side"])
	if lk > 0 and rng.randf() < lk / 24.0:
		dmg *= 2
		lucky = true
	if has_ab(a, "death_blow") and rng.randf() < 0.2:
		dmg *= 2
		lucky = true
	var dname := _name(d)
	var killed := apply_damage(d, dmg)
	var ev := [{"t": "attack", "a": a, "d": d, "ranged": ranged, "retaliation": retaliation, "dmg": dmg, "killed": killed, "lucky": lucky}]
	var verb := ("shoot" if ranged else "attack") + ("s" if a["count"] == 1 else "")
	log_lines.append("%s %s %s for %d damage.%s" % [_name(a), verb, dname, dmg,
		(" %d %s." % [killed, "perishes" if killed == 1 else "perish"]) if killed > 0 else ""])
	ev[0]["log"] = log_lines.size()
	if has_ab(a, "life_drain") and a["alive"] and living(d):
		var g := heal(a, dmg / 2, true)
		if g > 0:
			ev.append({"t": "heal", "s": a, "amount": g})
	if has_ab(a, "disease") and d["alive"] and living(d) and rng.randf() < 0.3:
		d["effects"]["disease"] = 3
	if has_ab(a, "curse_strike") and d["alive"] and not immune(d["side"], "curse") and rng.randf() < 0.25:
		d["effects"].erase("bless")  # (the Mummy's curse, as the spell: minimum damage for 3 rounds)
		d["effects"]["curse"] = 3
	var gaze := stone_or_venom(a, d) if not ranged else ""
	if gaze != "" and rng.randf() < 0.2:
		d["effects"][gaze] = 3
		d["effects"].erase("berserk")
		var plural: bool = d["count"] != 1
		log_lines.append("%s %s." % [_name(d), ("turn" if plural else "turns") + " to stone" if gaze == "stone"
			else ("are" if plural else "is") + " paralyzed"])
		ev.append({"t": "status", "s": d, "text": "Stone" if gaze == "stone" else "Paralyzed", "log": log_lines.size()})
	if not d["alive"]:
		ev.append({"t": "death", "s": d})
	if not ranged and has_ab(a, "breath"):
		ev += _breathe(a, d, moved)
	return ev

## A dragon's breath (HoMM3): its strike, a retaliation too, also burns the stack in the hex just behind the one it
## struck, on the same line, friend or foe; that stack does not strike back.
func _breathe(a: Dictionary, d: Dictionary, moved: int) -> Array:
	var o = breath_victim(a, d)
	if o == null:
		return []
	var dmg := _roll_damage(a, o, false, moved)
	var oname := _name(o)
	var killed := apply_damage(o, dmg)
	log_lines.append("The breath burns %s for %d damage.%s" % [oname, dmg,
		(" %d %s." % [killed, "perishes" if killed == 1 else "perish"]) if killed > 0 else ""])
	var ev := [{"t": "breath", "a": a, "d": o, "dmg": dmg, "killed": killed, "log": log_lines.size()}]
	if not o["alive"]:
		ev.append({"t": "death", "s": o})
	return ev

## The stack a breath reaches past `d`: one hex on along the line from the attacker's touching hex through the hex it
## struck (two, through a large target's other half); null when that hex is empty or off the field. `head`: where the
## attacker would stand (the AI weighing a strike), else where it stands.
func breath_victim(a: Dictionary, d: Dictionary, head = null) -> Variant:
	for ac in cells(a, head):
		for dc in cells(d):
			if distance(ac, dc) != 1:
				continue
			var step := to_cube(dc) - to_cube(ac)
			var h := from_cube(to_cube(dc) + step)
			if h in cells(d):
				h = from_cube(to_cube(h) + step)
			if not in_bounds(h):
				return null
			var o = stack_at(h)
			return o if o != null and o != a and o != d else null
	return null

## Master Genies (HoMM3): three times a battle, instead of attacking, cast a helpful spell on an ally stack, one the
## rules pick at random among those not already on it (Bless, Haste, Shield, Stone Skin; Cure when it is cursed, slowed
## or weakened), for three rounds. The random pick is the battle's own, so every machine casts the same spell.
const GENIE_SPELLS := ["bless", "haste", "shield", "stone_skin"]

func genie_casts_left(s: Dictionary) -> int:
	return int(s.get("genie_casts", 3)) if has_ab(s, "genie_spells") else 0

func genie_options(t: Dictionary) -> Array:
	if stack_immune(t, "bless") and stack_immune(t, "haste"):
		return []
	var out := GENIE_SPELLS.filter(func(sp): return not t["effects"].has(sp) and not stack_immune(t, sp))
	if t["effects"].has("curse") or t["effects"].has("slow") or t["effects"].has("weakness"):
		out.append("cure")
	return out

func genie_target_ok(s: Dictionary, t) -> bool:
	return t != null and t["side"] == s["side"] and genie_casts_left(s) > 0 and not genie_options(t).is_empty()

func genie_cast(s: Dictionary, t: Dictionary) -> Array:
	var opts := genie_options(t)
	if genie_casts_left(s) <= 0 or opts.is_empty():
		return []
	var sp: String = opts[rng.randi() % opts.size()]
	s["genie_casts"] = genie_casts_left(s) - 1
	match sp:
		"bless":
			t["effects"].erase("curse")
		"haste":
			t["effects"].erase("slow")
	if sp == "cure":
		for k in ["curse", "slow", "weakness", "disease"]:
			t["effects"].erase(k)
		heal(t, 30, false)
	else:
		t["effects"][sp] = 3
	if sp in ["haste", "cure"]:
		_resort_order()
	log_lines.append("%s %s %s on %s." % [_name(s), "casts" if s["count"] == 1 else "cast", GameData.SPELLS[sp]["name"], _name(t)])
	var ev := {"t": "spell", "spell": sp, "side": s["side"], "targets": [t], "hex": t["hex"], "dmg": {}, "killed": {},
		"genie": true, "log": log_lines.size()}
	finish_turn(s)
	return [ev]

## A stack that loses its turn to a spell or a strike: "blind", "paralyze" or "stone" (it stands until struck or
## the effect ends), else "".
func spell_lost_turn(s: Dictionary) -> String:
	for k in ["stone", "paralyze", "blind"]:
		if s["effects"].has(k):
			return k
	return ""

## A berserk stack's action, as the rules decide it (HoMM3): it goes for the nearest stack, friend or foe (the
## nearer by hexes, then the earlier on the field); a shooter with nothing beside it shoots it, others strike it if
## they can reach it this turn, else march toward it. Same form as BattleAI.decide's; {} when not berserk.
func berserk_action(s: Dictionary) -> Dictionary:
	if not s["effects"].has("berserk"):
		return {}
	var others := alive_stacks().filter(func(o): return o != s)
	if others.is_empty():
		return {"type": "defend"}
	others.sort_custom(func(a, b):
		var da := stack_distance(s, a)
		var db := stack_distance(s, b)
		return da < db if da != db else a["uid"] < b["uid"])
	var nearest: Dictionary = others[0]
	var beside := false
	for c in cells(s):
		for n in neighbors(c):
			var o = stack_at(n)
			if o != null and o != s:
				beside = true
	if s["shots"] > 0 and not beside:
		return {"type": "shoot", "target": nearest}
	var reach := reachable(s)
	var pos := attack_positions(s, nearest, reach)
	if not pos.is_empty():
		pos.sort_custom(func(a, b):
			var ca: int = 0 if a == s["hex"] else reach.get(a, 99)
			var cb: int = 0 if b == s["hex"] else reach.get(b, 99)
			return ca < cb if ca != cb else (a.y < b.y if a.y != b.y else a.x < b.x))
		return {"type": "melee", "target": nearest, "from": pos[0]}
	var best: Vector2i = s["hex"]
	var bd := stack_distance(s, nearest)
	for h in reach:
		var d := 99
		for c in cells(nearest):
			d = mini(d, distance(h, c))
		if d < bd or (d == bd and best != s["hex"] and (h.y < best.y or (h.y == best.y and h.x < best.x))):
			bd = d
			best = h
	return {"type": "move", "hex": best} if best != s["hex"] else {"type": "defend"}

## Fear: bone dragons can make living enemies lose their turn.
func check_fear(s: Dictionary) -> bool:
	if has_ab(s, "undead"):
		return false
	for o in alive_stacks(1 - s["side"]):
		if has_ab(o, "fear") and rng.randf() < 0.1:
			return true
	return false

# ---------------------------------------------------------------------------------------------
# Spells
# ---------------------------------------------------------------------------------------------
func can_cast(side: int) -> bool:
	var h = heroes[side]
	return h != null and not hero_cast[side] and h["spells"].size() > 0

## A spell's price for the side's hero: 2 less while Magi stand in its army (HoMM3's Mages), never below 1.
func spell_cost(side: int, spell: String) -> int:
	var m: int = GameData.SPELLS[spell]["mana"]
	for s in alive_stacks(side):
		if has_ab(s, "spell_cost_down"):
			return maxi(1, m - 2)
	return m

func spell_power(side: int) -> int:
	var h = heroes[side]
	return 0 if h == null else maxi(1, GameState.hero_stat(h, "power"))

## A spell's damage to one stack: less for a creature that resists spells (the ushabti, as HoMM3's golems).
func spell_damage_to(side: int, spell: String, target: Dictionary) -> int:
	var resist := int(cdata(target).get("spell_resist", 0))
	return int(spell_damage(side, spell) * (100 - resist) / 100.0)

func spell_damage(side: int, spell: String) -> int:
	var d: Array = GameData.SPELLS[spell]["damage"]
	var v: float = d[0] + d[1] * spell_power(side)
	v *= 1.0 + 0.1 * hero_skill(side, "sorcery")
	var h = heroes[side]
	if h != null:  # (an orb of that school)
		v *= 1.0 + GameState.hero_stat(h, "school_" + String(GameData.SPELLS[spell]["school"])) / 100.0
	return int(v)

## Valid targets: "enemy", "ally" -> stack; "area" -> any hex; "all_living", "all" -> none needed.
func spell_target_ok(side: int, spell: String, hex: Vector2i) -> bool:
	var t: String = GameData.SPELLS[spell]["target"]
	var s = stack_at(hex)
	match t:
		"enemy":
			return s != null and s["side"] != side and not stack_immune(s, spell)
		"ally":
			return s != null and s["side"] == side and not stack_immune(s, spell)
		"area":
			return in_bounds(hex)
		"all_living", "all":
			return true
	return false

## The stacks a chain spell strikes, in order: the target, then each time the nearest stack not yet struck, friend
## or foe (the nearer by hexes, then the earlier on the field), creatures only, past those it cannot touch.
func chain_targets(first: Dictionary, spell: String) -> Array:
	var hit := [first]
	var n: int = GameData.SPELLS[spell].get("chain", 1)
	while hit.size() < n:
		var last: Dictionary = hit[-1]
		var best = null
		var bd := 1 << 20
		for o in alive_stacks():
			if o in hit or o.get("machine", false) or stack_immune(o, spell):
				continue
			var d := stack_distance(last, o)
			if d < bd or (d == bd and o["uid"] < best["uid"]):
				bd = d
				best = o
		if best == null:
			break
		hit.append(best)
	return hit

func cast(side: int, spell: String, hex: Vector2i) -> Array:
	var h = heroes[side]
	var sp: Dictionary = GameData.SPELLS[spell]
	h["mana"] -= spell_cost(side, spell)
	hero_cast[side] = true
	var dur := spell_power(side) + 1
	var ev := {"t": "spell", "spell": spell, "side": side, "targets": [], "hex": hex, "dmg": {}, "killed": {}}
	var targets := []
	match sp["target"]:
		"enemy", "ally":
			var s = stack_at(hex)
			if s:
				targets = [s]
				if sp.has("chain"):
					targets = chain_targets(s, spell)
		"area":
			targets = stacks_on([hex] + neighbors(hex))
		"all_living":
			for s in alive_stacks():
				if living(s):
					targets.append(s)
		"all":  # (every creature on the field: Armageddon; war machines are not creatures)
			targets = alive_stacks().filter(func(s): return not s.get("machine", false))
	targets = targets.filter(func(t): return not stack_immune(t, spell))  # (a combination's protection; mind spells)
	ev["targets"] = targets
	var first_name := _name(targets[0]) if targets.size() > 0 else ""  # (before the damage: "on Liches", not after)
	var out := [ev]
	for i in targets.size():
		var s: Dictionary = targets[i]
		if sp.has("damage"):
			var dmg := spell_damage_to(side, spell, s)
			if sp.has("chain"):
				dmg = maxi(1, int(dmg / pow(2.0, i)))  # (each jump of the chain at half the one before)
			ev["dmg"][s["uid"]] = dmg
			ev["killed"][s["uid"]] = apply_damage(s, dmg)
			if not s["alive"]:
				out.append({"t": "death", "s": s})
		else:
			match spell:
				"bless":
					s["effects"].erase("curse")
					s["effects"]["bless"] = dur
				"curse":
					s["effects"].erase("bless")
					s["effects"]["curse"] = dur
				"shield", "haste", "slow", "weakness", "stone_skin":
					if spell == "haste":
						s["effects"].erase("slow")
					if spell == "slow":
						s["effects"].erase("haste")
					s["effects"][spell] = dur
				"cure":
					for k in ["curse", "slow", "weakness", "disease", "paralyze"]:
						s["effects"].erase(k)
					var g := heal(s, 10 + 5 * spell_power(side), false)
					out.append({"t": "heal", "s": s, "amount": g})
				"resurrection":
					var g := heal(s, 40 + 20 * spell_power(side), true)
					out.append({"t": "heal", "s": s, "amount": g})
				"blind":
					s["effects"].erase("berserk")
					s["effects"]["blind"] = dur
				"berserk":
					s["effects"].erase("blind")
					s["effects"]["berserk"] = dur
	if spell in ["haste", "slow", "cure"]:
		_resort_order()
	# the log names the target and the damage, so every number on the field has its line
	var line := "%s casts %s" % [h["name"], sp["name"]]
	if targets.size() == 1:
		line += " on %s" % first_name
	elif targets.size() > 1:
		line += " (%d stacks)" % targets.size()
	if ev["dmg"].size() > 0:
		var total := 0
		var slain := 0
		for k in ev["dmg"]:
			total += ev["dmg"][k]
			slain += ev["killed"].get(k, 0)
		line += ", %d damage" % total + ((", %d %s" % [slain, "perishes" if slain == 1 else "perish"]) if slain > 0 else "")
	log_lines.append(line + ".")
	ev["log"] = log_lines.size()
	return out

# ---------------------------------------------------------------------------------------------
func is_over() -> int:
	## Returns winning side (0/1) or -1 if the battle continues.
	var a := fighters(0)
	var d := fighters(1)
	if a == 0:
		return 1
	if d == 0:
		return 0
	return -1

func army_out(side: int) -> Array:
	var out: Array = [null, null, null, null, null, null, null]
	for s in stacks:
		if s["side"] == side and s["alive"] and s["count"] > 0 and s["slot"] >= 0:
			if out[s["slot"]] == null:
				out[s["slot"]] = {"id": s["id"], "count": s["count"]}
			else:
				out[s["slot"]]["count"] += s["count"]
	return out

func casualties(side: int) -> Dictionary:
	## id -> count lost
	var out := {}
	for s in stacks:
		if s["side"] == side and not s.get("machine", false):
			var lost: int = start_counts[s["uid"]] - s["count"]
			if lost > 0:
				out[s["id"]] = out.get(s["id"], 0) + lost
	return out

## Keep enemy stacks separate for Necromancy's per-stack rounding. Destroyed machines count;
## tower masonry, surviving retreaters and creatures restored by resurrection do not.
func necromancy_casualties(side: int) -> Array:
	var out := []
	for s in stacks:
		if s["side"] == side and not s.get("tower", false):
			var lost: int = start_counts.get(s["uid"], 0) - s["count"]
			if lost > 0:
				out.append({"id": s["id"], "count": lost})
	return out

func killed_hp(side: int) -> int:
	## HP of creatures side lost (experience for the opponent)
	var total := 0
	for id in casualties(side):
		total += casualties(side)[id] * GameData.CREATURES[id]["hp"]
	return total
