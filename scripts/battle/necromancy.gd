extends RefCounted
class_name Necromancy
## Post-victory reward, shared by played battles and instant resolution. This is a preview:
## AdvRules.apply_battle adds it to the winning hero after restoring the surviving army.
## Original/SoD rules: 10/20/30%, per-stack rounding with a minimum of one, undead included,
## health/count caps, and two thirds as many upgraded troops when only their existing stack fits.
## Eridu's Shaping (docs/ERIDU.md) is the same rule with Lulu, on living enemies only: a hero with both skills raises
## with Necromancy. "raise_skill" in the result names the one that raised.

static func calculate(hero, army: Array, fallen: Array, player_index := -1) -> Dictionary:
	var skill := "necromancy"
	if hero != null and not hero.is_empty() and int(hero.get("skills", {}).get("necromancy", 0)) == 0 			and int(hero.get("skills", {}).get("shaping", 0)) > 0:
		skill = "shaping"
	var rule: Dictionary = GameData.SKILLS[skill]["raise"]
	var raise_id: String = rule["creature"]
	var out := {"raised": 0, "raised_id": raise_id, "necromancy_reason": "no_skill", "raise_skill": skill}
	if hero == null or hero.is_empty():
		return out
	var level := clampi(int(hero.get("skills", {}).get(skill, 0)), 0, 3)
	if level == 0:
		return out
	var percent := level * 10
	var base_id := raise_id
	if skill == "necromancy":  # (the Amplifier, the Cloak and the Count's Immortality help Necromancy alone)
		percent += GameState.hero_stat(hero, "necromancy")
		var owner_index: int = hero.get("owner", -1) if player_index < 0 else player_index
		if owner_index >= 0:
			for town in GameState.world.get("towns", {}).values():
				if town["owner"] == owner_index:
					percent += TownLogic.effect(town, "necromancy")  # (the Necromancy Amplifier)
		# Preserve the project's existing Mantle reward; its base creature is subject to the same health cap.
		var flags := GameState.hero_flags(hero, "raise")  # (an artifact may raise another creature)
		if not flags.is_empty():
			base_id = flags[0]
	percent = clampi(percent, 0, 100)
	var upgrade_id := GameData.upgrade_of_base(base_id)
	out["raised_id"] = base_id
	var upgraded := false
	if not _fits(army, base_id):
		if _fits(army, upgrade_id):
			out["raised_id"] = upgrade_id
			upgraded = true
		else:
			out["necromancy_reason"] = "no_room"
			return out
	var target_hp: int = GameData.CREATURES[base_id]["hp"]
	for stack in fallen:
		if stack == null or int(stack.get("count", 0)) <= 0:
			continue
		var data: Dictionary = GameData.CREATURES[stack["id"]]
		if stack["id"] == "arrow_tower":
			continue # a fortification, not a killed creature or war machine
		if "golem" in data["abilities"] or "unliving" in data["abilities"]:
			continue  # (not living: no skeleton rises from a statue, as HoMM3's golems and gargoyles)
		if rule.get("living_only", false) and "undead" in data["abilities"]:
			continue  # (Shaping remakes the living alone)
		var numerator: int = stack["count"] * mini(int(data["hp"]), target_hp) * percent
		var denominator := 100 * target_hp
		if upgraded:
			numerator *= 2
			denominator *= 3
		out["raised"] += maxi(1, numerator / denominator)
	out["necromancy_reason"] = "" if out["raised"] > 0 else "no_casualties"
	return out

static func _fits(army: Array, id: String) -> bool:
	for stack in army:
		if stack == null or (stack["id"] == id and stack["count"] > 0):
			return true
	return false

static func message(reward: Dictionary) -> String:
	var shaping: bool = reward.get("raise_skill", "necromancy") == "shaping"
	var sk := "Shaping" if shaping else "Necromancy"
	if reward["raised"] > 0:
		var c: Dictionary = GameData.CREATURES[reward["raised_id"]]
		return "%s %s %d %s from the fallen." % [sk, "remakes" if shaping else "raises", reward["raised"],
			c["plural"] if reward["raised"] != 1 else c["name"]] if shaping else "Necromancy raises %d %s from the fallen." % [
			reward["raised"], (c["plural"] if reward["raised"] != 1 else c["name"]).to_lower()]
	match reward["necromancy_reason"]:
		"no_room": return "%s: no room in your army for the %s troops." % [sk, "shaped" if shaping else "raised"]
		"no_casualties": return "%s: no fallen %s to %s." % [sk, "living enemies" if shaping else "enemies", "shape" if shaping else "raise"]
	return ""
