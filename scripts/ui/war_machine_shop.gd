extends RefCounted
class_name WarMachineShop
## Neutral adventure-map shop. No stock/day limit; each visiting hero has one slot per machine type.

static func open(owner_node: Node, hero: Dictionary, player: Dictionary, on_purchase := Callable(), rules: AdvRules = null,
		factory := -1) -> void:
	while true:
		var m := Modal.custom(owner_node, "War Machine Factory", 1160)
		m.add_text("%s  •  %d gold" % [hero["name"], player["resources"]["gold"]], 24)
		m.add_text("Equip your hero with one of each war machine.", 20)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		m.body.add_child(row)
		for id in GameData.WAR_MACHINES:
			_add_machine(m, row, hero, player, id)
		m.add_buttons([["Close", ""]])
		m.set_meta("cancel", "")
		var id = await m.closed
		if id == "" or id == null:
			return
		if rules.do({"t": "buy_machine", "p": player["index"], "hero": hero["uid"], "machine": str(id), "object": factory})["ok"]:
			Audio.sfx("build", -4)
			if on_purchase.is_valid():
				on_purchase.call()

static func _add_machine(m: Modal, row: HBoxContainer, hero: Dictionary, player: Dictionary, id: String) -> void:
	var c: Dictionary = GameData.CREATURES[id]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var title := UI.label(c["name"], 26, UI.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var pic := UI.icon(Assets.creature_portrait(id), Vector2(220, 220))
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	var desc := UI.label(GameData.MACHINE_TEXT[id], 20)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(280, 80)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	var cost := HoverInfo.cost_row(c["cost"], player["resources"])
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cost)
	var owned: bool = id in hero.get("machines", [])
	var why := GameState.war_machine_reason(hero, player, id)
	var b := UI.button("Owned" if owned else ("Not enough gold" if why != "" else "Buy"), func(): m.close(id), 22)
	b.name = "Buy_" + id
	b.custom_minimum_size.y = 50
	b.disabled = why != ""
	b.tooltip_text = why if why != "" else "Buy a %s for %s." % [c["name"], hero["name"]]
	v.add_child(b)
