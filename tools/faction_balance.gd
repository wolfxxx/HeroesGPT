extends Node
## Tier-by-tier creature balance (docs/ERIDU.md, Balance): each creature of a faction against the same tier's creature
## (base against base, upgrade against upgrade) of every other faction, armies of equal AI value (what the computer's
## instant battles and the map AI weigh them by), fought out with the battle rules and the battle AI on both sides,
## sides swapped, no heroes. Prints the faction's share of battles won per tier and a 2-SE interval, so a creature
## whose AI value is too high (it loses at equal value) or too low (it wins) stands out. --by=growth: armies of the
## same weeks of growth instead (what a town makes in a week: how strong the tier is in play, not how it is valued).
##   Godot --headless --path . res://tools/faction_balance.tscn -- --faction=eridu --seeds=12 --value=12000 [--by=growth --weeks=3]
var faction := "eridu"
var seeds := 12
var value := 12000
var by := "value"
var weeks := 3

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--faction="):
			faction = a.substr(10)
		elif a.begins_with("--seeds="):
			seeds = int(a.substr(8))
		elif a.begins_with("--value="):
			value = int(a.substr(8))
		elif a.begins_with("--by="):
			by = a.substr(5)
		elif a.begins_with("--weeks="):
			weeks = int(a.substr(8))
	var total_w := 0.0
	var total_n := 0
	for kind in ["creatures", "upgrades"]:
		for tier in range(1, 8):
			var mine: String = GameData.FACTIONS[faction][kind][tier - 1]
			var line := []
			var w := 0.0
			var n := 0
			for other in GameData.FACTIONS:
				if other == faction:
					continue
				var theirs: String = GameData.FACTIONS[other][kind][tier - 1]
				var ow := 0.0
				for s in seeds:
					for side in 2:
						var r := _fight(mine, theirs, side, 1000 * tier + 17 * s + side)
						ow += r
				w += ow
				n += seeds * 2
				line.append("%s %.0f%%" % [theirs, 100.0 * ow / (seeds * 2)])
			var p := w / n
			print("%-18s T%d %s  won %.0f%% +/- %.0f  (%s)" % [mine, tier, kind.substr(0, 4), 100 * p,
				200 * sqrt(maxf(p * (1 - p), 0.01) / n), ", ".join(line)])
			total_w += w
			total_n += n
	print("FACTION BALANCE %s (%s): won %.1f%% of %d battles" % [faction, by, 100.0 * total_w / total_n, total_n])
	get_tree().quit()

## One battle: `mine` on side `side`; 1 if it wins, 0.5 a draw (step limit), 0 if it loses.
func _fight(mine: String, theirs: String, side: int, seed: int) -> float:
	var a := _army(mine)
	var b := _army(theirs)
	var L := BattleLogic.new()
	L.setup({"attacker_army": a if side == 0 else b, "defender_army": b if side == 0 else a,
		"attacker_hero": null, "defender_hero": null, "seed": seed})
	var steps := 0
	while L.is_over() < 0 and steps < 3000:
		steps += 1
		var s = L.current()
		if s == null:
			break
		if s.get("machine", false) or s.get("tower", false):
			L.machine_act(s)
			continue
		if L.spell_lost_turn(s) != "" or L.check_fear(s) or L.check_bad_morale(s):
			L.finish_turn(s)
			continue
		var act := L.berserk_action(s)
		if act.is_empty():
			act = BattleAI.decide(L, s)
		match act.get("type", ""):
			"shoot": L.do_shoot(s, act["target"])
			"melee": L.do_melee(s, act["target"], act["from"])
			"genie": L.genie_cast(s, act["target"])
			"move": L.do_move(s, act["hex"])
			"wait":
				if not L.do_wait(s):
					L.do_defend(s)
			_: L.do_defend(s)
		L.roll_good_morale(s)
	var won := L.is_over()
	if won < 0:
		return 0.5
	return 1.0 if won == side else 0.0

## Equal AI value, in up to three stacks (as a small army would be split).
func _army(id: String) -> Array:
	var n := maxi(1, int(round(float(value) / GameData.CREATURES[id]["ai_value"])))
	if by == "growth":
		n = int(GameData.CREATURES[id]["growth"]) * weeks
	var out: Array = [null, null, null, null, null, null, null]
	var k := mini(3, n)
	for i in k:
		out[i * 2] = {"id": id, "count": n / k + (1 if i < n % k else 0)}
	return out
