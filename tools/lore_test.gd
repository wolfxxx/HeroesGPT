extends Node
## The setting's voice (scripts/core/lore.gd): weekly omens deepen month by month, Tavern rumours are fixed for a week
## and sometimes true hints about the map, and none of it touches the shared random stream (a seeded game plays as
## before). Prints a sample of the year's rumours and omens to read.
##   Godot_console.exe --headless --path . res://tools/lore_test.tscn  -> "LORE TEST: N checks, failures: 0"

var checks := 0
var failures := 0

func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)

func _ready() -> void:
	var s := GameState.new_game_settings.duplicate()
	s["seed"] = 12345
	var w := WorldGen.generate(s)
	GameState.world = w

	# the shared stream is untouched
	seed(42)
	var a := randi()
	seed(42)
	Lore.make_rumour(w)
	Lore.omen(w, 8)
	_ok(randi() == a, "omens and rumours draw nothing from the shared random stream")

	_ok(Lore.depth(1) == 0 and Lore.depth(29) == 1 and Lore.depth(57) == 2 and Lore.depth(85) == 3 and Lore.depth(400) == 3,
		"a layer deeper each month, the cosmic last")
	var hints := 0
	for week in 16:
		var day := week * 7 + 1
		w["day"] = day
		var r1: Dictionary = Lore.make_rumour(w)
		_ok(r1 == Lore.make_rumour(w), "week %d: the same rumour every time" % week)
		_ok(Lore.omen(w, day) in Lore.OMENS[Lore.depth(day)], "week %d: the omen is from the month's layer" % week)
		var t: String = r1["text"]
		if not t in Lore.RUMOURS[Lore.depth(day)]:
			hints += 1
			var named := false
			for town in w["towns"].values():
				named = named or t.contains(town["name"])
			_ok(named, "a hint names a real town: " + t)
		print("  week %2d [%s] %s | %s" % [week + 1, Lore.LAYERS[Lore.depth(day)], t, Lore.omen(w, day)])
	_ok(hints > 0 and hints < 16, "some rumours are hints about the map, most are whispers (%d of 16)" % hints)

	# stored for the week by the rules, and read back
	w["day"] = 1
	var rules := AdvRules.new(w)
	for i in 7:
		rules.new_day()
	_ok(w.get("rumour", {}).get("week", -1) == 1 and Lore.rumour(w) == w["rumour"]["text"], "the new week's rumour is kept for the week")
	_declassified(w, rules)
	print("LORE TEST: %d checks, failures: %d" % [checks, failures])
	get_tree().quit()

## The declassified lines: one for every artifact and mine; blacked out until the player has held the relic or visited
## that kind of site; revealed in the message of that first meeting only.
func _declassified(w: Dictionary, rules: AdvRules) -> void:
	for a in GameData.ARTIFACTS:
		_ok(Lore.ENTRIES.has("art:" + a), "%s has a declassified line" % a)
	for m in GameData.MINES:
		_ok(Lore.ENTRIES.has("site:" + m), "%s has a declassified line" % m)
	var me := 0
	var h: Dictionary = w["heroes"][w["players"][me]["heroes"][0]]
	var key := "art:orb_of_power"
	var hidden := Lore.shown(w, me, key)
	_ok(hidden.contains("█") and hidden != Lore.ENTRIES[key] and hidden.split(" ").size() == Lore.ENTRIES[key].split(" ").size(),
		"an unseen relic's line is blacked out, word for word: " + hidden)
	_ok(hidden == Lore.shown(w, me, key), "always the same words blacked out")
	GameState.give_artifact(h, "orb_of_power")
	_ok(Lore.shown(w, me, key) == Lore.ENTRIES[key], "taking the relic declassifies it")
	h["artifacts"].erase("orb_of_power")
	h["backpack"].erase("orb_of_power")
	_ok(Lore.known(w, me, key), "and it stays known after the relic is gone")
	_ok(not Lore.known(w, 1, key), "but only for its player")
	# a site: revealed in the visit's message the first time, not after
	var circle := {}
	for o in w["objects"].values():
		if o["type"] == "shrine":
			circle = o
			break
	if not circle.is_empty():
		_ok(not Lore.known(w, me, "site:shrine"), "the stone circles are unknown at first")
		var ev1 := rules.visit(h, circle)
		_ok(ev1["text"].ends_with(Lore.ENTRIES["site:shrine"]) and Lore.known(w, me, "site:shrine"), "visiting declassifies the stone circles")
		var ev2 := rules.visit(h, circle)
		_ok(not ev2["text"].contains(Lore.ENTRIES["site:shrine"]), "the second visit tells it no more")
