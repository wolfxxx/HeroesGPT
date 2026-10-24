extends RefCounted
class_name Lore
## The setting's voice (docs/SETTING.md, "The feel"): the weekly omens the astrologers add to their proclamation and the
## rumours of the Tavern, which grow stranger month by month as the player stumbles deeper: historical mysteries, then
## the occult, then the ancient, then the cosmic. Some rumours are true hints about the map (a relic, an unclaimed mine).
## Everything is drawn from a generator seeded by the map's seed and the week, never the shared random stream, so a
## seeded game plays exactly as before and every player hears the same omen and rumour that week.

const LAYERS := ["historical", "occult", "ancient", "cosmic"]

const OMENS := [
	[  # historical: the Templars, the Grail, the old kings
		"The bells of a drowned church were heard ringing under the lake.",
		"A Templar cross was found cut into a milestone overnight. No one owns the chisel.",
		"Crows gathered on the old king's tomb and would not be driven off.",
		"A hermit came down from the hills to say the crown was never gold.",
		"Pilgrims swear the road to the coast grew a mile longer in the night.",
		"A ship with red-crossed sails was seen at dawn, and was not in any harbour by noon.",
	],
	[  # occult: the deathless, alchemy, scrying
		"In every mirror of a village, for one night, a stranger stood behind the looker.",
		"An alchemist's house burned with a green flame that gave no heat.",
		"The ravens spoke in a schoolmaster's voice. The schoolmaster has been dead a year.",
		"A grave was found open from the inside, the earth piled neatly beside it.",
		"For three nights every candle in the chapel burned downward.",
		"A count no one knew danced at the harvest feast, and left no footprints in the flour.",
	],
	[  # ancient: Egypt, Thoth, lost lands
		"Red sand fell with the rain in the north, smelling of incense.",
		"The black obelisks cast their shadows the wrong way at noon.",
		"Fishermen netted a tablet of green stone, written in a hand no scholar reads.",
		"A tide went out and did not come back for a day, and there were streets beneath it.",
		"Bees left every hive in the valley and built a comb in the shape of a pyramid.",
		"The old circles hummed so loudly that the cattle would not graze near them.",
	],
	[  # cosmic: the fallen star, Nibiru, the watchers
		"A second moon rose for an hour and set in the east.",
		"Every compass in the realm pointed at the same hill all night.",
		"Lights crossed the sky in a line, turned, and came back.",
		"Crops were found flattened in rings, warm to the touch at dawn.",
		"The astrologers counted one star more than last year, and it is moving.",
		"For a moment at midnight every dog in the land howled at the same patch of sky.",
	],
]

const RUMOURS := [
	[
		"The Templars were burned, they say. Then why do their ships still sail?",
		"A knight paid for his ale with a coin no mint ever struck.",
		"The old king had nine sons, and none of them is buried where the stones say.",
		"They say the Grail is not a cup at all.",
		"Whoever holds a shard of the crown dreams of a sky full of strange stars.",
	],
	[
		"The Count was at the old king's court, and at his grandfather's. Same face.",
		"Doctor Dee's mirror shows you the room you are in, but empty, and later.",
		"The Order of the Dragon pays in silver that never tarnishes.",
		"An alchemist in the south made gold, they say, and was never seen again.",
		"Don't drink with anyone who won't sit with his back to a mirror.",
	],
	[
		"Thoth wrote forty-two books. The scholars own forty-one.",
		"Under every great circle of stones runs a road no map shows.",
		"They found a city under the sea, with streets too wide for men.",
		"The obelisks are not markers. They are counting something.",
		"The first kings did not build the pyramids. They found them.",
	],
	[
		"The crown fell from the sky. Ask yourself who dropped it.",
		"Men in black coats ask about falling stars, and nobody remembers their faces.",
		"The old gods counted their years by a star that comes back every three thousand six hundred.",
		"Some of the stars, they say, are watching back.",
		"They are not coming. They never left.",
	],
]

## How deep the player has stumbled: 0 historical, 1 occult, 2 ancient, 3 cosmic (one layer a month).
static func depth(day: int) -> int:
	return clampi((day - 1) / 28, 0, LAYERS.size() - 1)

static func week_index(day: int) -> int:
	return (day - 1) / 7

static func _rng(world: Dictionary, week: int, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(world.get("seed", 0)), week, what])
	return r

## The month's lines dealt one a week: the layer's pool shuffled once for the map, so no line repeats within a month
## (the last layer, which lasts, cycles through its pool).
static func _deal(world: Dictionary, pools: Array, day: int, what: String) -> String:
	var layer := depth(day)
	var pool: Array = pools[layer].duplicate()
	var r := _rng(world, layer, what + "_order")
	for i in range(pool.size() - 1, 0, -1):  # (Fisher-Yates with the private generator)
		var j := r.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool[(week_index(day) - layer * 4) % pool.size()]

## The astrologers' omen for the week that starts on `day`.
static func omen(world: Dictionary, day: int) -> String:
	return _deal(world, OMENS, day, "omen")

## This week's Tavern rumour: the one AdvRules.new_day stored at the week's start (on the first week, or in an older
## save, made now).
static func rumour(world: Dictionary) -> String:
	var r: Dictionary = world.get("rumour", {})
	if r.get("week", -1) == week_index(int(world.get("day", 1))):
		return r["text"]
	return make_rumour(world)["text"]

## A rumour for the current week: two times in five, when the map allows, a true hint about where a relic lies or a
## mine without a master; otherwise one of the month's whispers.
static func make_rumour(world: Dictionary) -> Dictionary:
	var day := int(world.get("day", 1))
	var week := week_index(day)
	var g := _rng(world, week, "rumour")
	var hints := []
	for o in world.get("objects", {}).values():
		if o["type"] == "artifact" and GameData.ARTIFACTS.has(o["artifact"]):
			hints.append(["They say %s lies somewhere %s, if you can believe a drunk.",
				_the(GameData.ARTIFACTS[o["artifact"]]["name"]), o["pos"]])
		elif o["type"] == "mine" and o.get("owner", -1) < 0:
			var m := _the(GameData.MINES[o["mine"]]["name"])
			hints.append(["%s %s has no master yet.", m[0].to_upper() + m.substr(1), o["pos"]])
	var text := ""
	if not hints.is_empty() and g.randf() < 0.4:
		var h: Array = hints[g.randi() % hints.size()]
		text = h[0] % [h[1], _where(world, h[2])]
	else:
		text = _deal(world, RUMOURS, day, "rumour")
	return {"week": week, "text": text}

## "the Crystal Skull", "The Holy Grail" -> "the Holy Grail", "Dr. Dee's Scrying Mirror" as it is.
static func _the(name: String) -> String:
	if name.begins_with("The "):
		return "the " + name.substr(4)
	if name.begins_with("Dr. "):
		return name
	return "the " + name

## Where a tile lies, from the nearest town: "north of Gisors", "near Ashenveil".
static func _where(world: Dictionary, p: Vector2i) -> String:
	var best := {}
	var bd := INF
	for t in world.get("towns", {}).values():
		var d := Vector2(p - t["pos"]).length()
		if d < bd:
			bd = d
			best = t
	if best.is_empty():
		return "in the wilds"
	if bd < 4.0:
		return "near %s" % best["name"]
	var v := Vector2(p - best["pos"])
	var dirs := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var k := int(round(atan2(v.y, v.x) / (PI / 4.0))) % 8  # (y grows southward on the map)
	return "%s of %s" % [dirs[(k + 8) % 8], best["name"]]
