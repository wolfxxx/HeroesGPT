extends RefCounted
class_name HillFort
## HoMM3's Hill Fort on the adventure map: the visiting hero upgrades any of its stacks that has an upgrade (a faction
## creature, a Giant to a Titan, a Red Dragon to a Black Dragon) at the upgrade price, as in a town. Each upgrade is a
## command ("hill_fort"), so it plays the same online.

## The stacks of the hero's army that can be upgraded here: [slot, from id, to id].
static func upgradable(hero: Dictionary) -> Array:
	var out := []
	for i in 7:
		var st = hero["army"][i]
		if st != null and st["count"] > 0:
			var up := GameData.upgrade_of_base(st["id"])
			if up != "":
				out.append([i, st["id"], up])
	return out

static func open(owner_node: Node, hero: Dictionary, player: Dictionary, on_change: Callable, rules: AdvRules, fort: int) -> void:
	while true:
		var m := Modal.custom(owner_node, "Hill Fort", 1100)
		m.add_text("%s may upgrade troops here, at the usual upgrade price." % hero["name"], 21)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 8)
		m.body.add_child(rows)
		var list := upgradable(hero)
		if list.is_empty():
			m.add_text("None of %s's troops can be upgraded." % hero["name"], 20)
		for e in list:
			_row(m, rows, hero, player, e)
		m.add_buttons([["Close", ""]])
		m.set_meta("cancel", "")
		var si = await m.closed
		if si == null or str(si) == "":
			return
		if rules.do({"t": "hill_fort", "p": player["index"], "hero": hero["uid"], "object": fort, "si": int(si)})["ok"]:
			Audio.sfx("build", -4)
			if on_change.is_valid():
				on_change.call()

static func _row(m: Modal, rows: VBoxContainer, hero: Dictionary, player: Dictionary, e: Array) -> void:
	var st: Dictionary = hero["army"][e[0]]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	rows.add_child(row)
	row.add_child(UI.icon(Assets.creature_portrait(e[1]), Vector2(84, 84)))
	row.add_child(UI.label("→", 30, UI.GOLD))
	row.add_child(UI.icon(Assets.creature_portrait(e[2]), Vector2(84, 84)))
	var txt := UI.label("%d %s  to  %s" % [st["count"], GameData.CREATURES[e[1]]["plural"], GameData.CREATURES[e[2]]["plural"]], 21)
	txt.custom_minimum_size.x = 420
	row.add_child(txt)
	var cost := TownLogic.upgrade_cost(e[1], e[2], st["count"])
	row.add_child(HoverInfo.cost_row(cost, player["resources"]))
	var ok := TownLogic.can_afford(player, cost)
	var b := UI.button("Upgrade" if ok else "Too costly", func(): m.close(str(e[0])), 20)
	b.name = "Upgrade_%d" % e[0]
	b.disabled = not ok
	b.custom_minimum_size = Vector2(170, 46)
	row.add_child(b)
