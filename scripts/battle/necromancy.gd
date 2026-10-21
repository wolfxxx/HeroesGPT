extends RefCounted
class_name Necromancy
## Post-victory reward, shared by played battles and instant resolution. This is a preview:
## AdvRules.apply_battle adds it to the winning hero after restoring the surviving army.
## Original/SoD rules: 10/20/30%, per-stack rounding with a minimum of one, undead included,
## health/count caps, and two thirds as many upgraded troops when only their existing stack fits.

static func calculate(hero, army: Array, fallen: Array, player_index := -1) -> Dictionary:
	var out := {"raised": 0, "raised_id": "skeleton", "necromancy_reason": "no_skill"}
	if hero == null or hero.is_empty():
		return out
	var level := clampi(int(hero.get("skills", {}).get("necromancy", 0)), 0, 3)
	if level == 0:
		return out
	var percent := level * 10 + GameState.hero_stat(hero, "necromancy")
	var owner_index: int = hero.get("owner", -1) if player_index < 0 else player_index
	if owner_index >= 0:
		for town in GameState.world.get("towns", {}).values():
			if town["owner"] == owner_index and TownLogic.has_building(town, "necromancy_amplifier"):
				percent += 10
	percent = clampi(percent, 0, 100)
	# Preserve the project's existing Mantle reward; its base creature is subject to the same health cap.
	var base_id := "zombie" if "zombie" in GameState.hero_flags(hero, "raise") else "skeleton"
	var upgrade_id := "plague_zombie" if base_id == "zombie" else "skeleton_warrior"
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
	if reward["raised"] > 0:
		return "Necromancy raises %d %s from the fallen." % [reward["raised"],
			GameData.CREATURES[reward["raised_id"]]["plural"].to_lower()]
	match reward["necromancy_reason"]:
		"no_room": return "Necromancy: no room in your army for the raised troops."
		"no_casualties": return "Necromancy: no fallen enemies to raise."
	return ""
