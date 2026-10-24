extends RefCounted
class_name Lore
## The setting's voice (docs/SETTING.md, "The feel"): the weekly omens the astrologers add to their proclamation and the
## rumours of the Tavern, which grow stranger month by month as the player stumbles deeper: historical mysteries, then
## the occult, then the ancient, then the cosmic. Some rumours are true hints about the map (a relic, an unclaimed mine).
## Everything is drawn from a generator seeded by the map's seed and the week, never the shared random stream, so a
## seeded game plays exactly as before and every player hears the same omen and rumour that week.
## It also keeps the "declassified" lines: one strange sentence for each relic and map site, shown blacked out (as a
## redacted file) until the player has held that relic or visited that kind of site. Only these lines are hidden: an
## artifact's effect and a site's rules always show, as in the classic.

const LAYERS := ["historical", "occult", "ancient", "cosmic"]

## The declassified lines: "art:<artifact id>", "site:<object type>" (mines: "site:<mine id>").
const ENTRIES := {
	"art:soldiers_shortsword": "Notched in the same three places as the sword on the old king's tomb.",
	"art:sword_of_valor": "Its owners never lose a duel. Its owners never grow old, either.",
	"art:ogre_hewn_cleaver": "No ogre ever forged steel. Someone gave them this.",
	"art:oaken_buckler": "Cut from the oak where the hanged men are said to whisper.",
	"art:shield_of_dawn": "The sun on it rises in the west.",
	"art:ironwood_tower_shield": "Ironwood does not grow in this world. The bark is still warm.",
	"art:quilted_gambeson": "Stitched with a map in the lining, in thread you can only see by moonlight.",
	"art:breastplate_of_ironbark": "Rings in the bark count back further than the world is supposed to be old.",
	"art:ring_of_vitality": "The looped cross of life. The priests who wore it were buried with their eyes open.",
	"art:ring_of_swiftness": "Whoever wears it arrives a moment before they set out.",
	"art:crown_of_command": "Prester John's crown, from a kingdom no map could find twice.",
	"art:apprentices_circlet": "Every apprentice who wore it later forgot their own master's name.",
	"art:helm_of_wisdom": "Solomon bound demons with a ring. The helm, they say, was for listening to them.",
	"art:amulet_of_insight": "The eye of the falcon god. Turn it over: on the back it is looking at you.",
	"art:pendant_of_clarity": "The crystal shows the room as it will be when you have gone.",
	"art:orb_of_power": "Quartz, cut by no tool known to any mason. It is warmer at night.",
	"art:orb_of_tempests": "The storm inside it is a weather no sky of ours has had.",
	"art:orb_of_embers": "It still burns with the fire of a city no chronicle names.",
	"art:orb_of_tides": "The water inside answers a moon that is not ours.",
	"art:orb_of_bedrock": "Stone from beneath the deepest mine, and it hums when held near the obelisks.",
	"art:travellers_boots": "The dust on them is from roads that were paved over a thousand years ago.",
	"art:boots_of_speed": "Seven leagues a stride. Nobody says where the eighth goes.",
	"art:wayfarers_cloak": "Pilgrims' marks are sewn inside: every shrine from here to the end of the world.",
	"art:seers_spyglass": "John Dee's black mirror. He saw angels in it, and they saw him.",
	"art:cape_of_courage": "Woven by the widows of a battle no herald records.",
	"art:clover_of_fortune": "Four leaves, and a fifth that only shows in a mirror.",
	"art:signet_of_coin": "The seal of a bank that lent to kings, and was never repaid, and never asked.",
	"art:bottomless_purse": "The lost wealth of the Temple. It was never in the ships.",
	"art:banner_of_the_muster": "Men march under it who were not in the muster roll.",
	"art:dragonbone_blade": "Saint George's sword. The dragon, they say, was never a beast.",
	"art:dragonscale_shield": "Scales from a creature the bestiaries call a dragon, for want of a better word.",
	"art:dragonskull_helm": "The skull is too large for any dragon that ever flew under this sky.",
	"art:bone_crown": "The Count's coronet. He wore it at four courts in two hundred years.",
	"art:gravecloak": "Saint-Germain's cloak, still faintly warm, as if he had only just stepped out of it.",
	"art:phylactery_of_ages": "The Elixir of Life. The label is in the Count's hand, and dated next year.",
	"art:sun_pendant": "The Templar cross. Hold it at dusk and it points, very slightly, to the west.",
	"art:seraphs_feather": "It is not a cup at all. The cup is what it lets you see.",
	"art:sunsteel_cuirass": "A Templar's white mantle. The burning at the stake left no mark on it.",
	"art:dragonheart_arms": "Saint George never killed the dragon. He sealed it away, and these are the keys.",
	"art:mantle_of_the_lich_king": "Whoever wears all three does not die. Whoever wears them is not quite who they were.",
	"art:seraphs_covenant": "The Grail Hallows together, as the Temple guarded them. Now the Order of the Dragon knows.",
	"site:shrine": "The stones are older than the hill they stand on.",
	"site:learning_stone": "Thoth's glyphs. They are not a language. They are a set of instructions.",
	"site:watchtower": "The astrologer kept a ledger of the stars. The last page counts one more than the first.",
	"site:windmill": "The miller grinds at night as well. Nobody has seen what.",
	"site:campfire": "The fire is still warm. The footprints lead in, and not out.",
	"site:chest": "The lock was opened from the inside.",
	"site:war_machine_factory": "The engineers here build to drawings older than the craft of building.",
	"site:gold_mine": "The Anunnaki came for gold. Some of these shafts were here before any king.",
	"site:sawmill": "The timber is marked with a sign the woodsmen cannot read and will not explain.",
	"site:ore_mine": "The miners stopped digging the lowest gallery. Something down there was digging back.",
	"site:crystal_cavern": "The crystals ring when a star falls, a moment before it is seen.",
	"site:gem_pond": "The gems are found already cut.",
	"site:alchemist_lab": "The alchemist left in a hurry. The gold in the crucible had not finished becoming lead.",
	"site:sulfur_dune": "The smell is not sulfur alone. Something under the dune breathes.",
	"site:pyramid": "No king is buried here. The chamber was built for something to wait in.",
	"site:tomb_of_curses": "The seals on the doors were broken from the inside, and then put back.",
}

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
		elif o["type"] == "pyramid" and not o.get("guards", []).is_empty():
			hints.append(["They say a pyramid stands somewhere %s%s, and its guardians have never slept.", "", o["pos"]])
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

## The declassified line's key for a map object ("" when it has none).
static func key_for(o: Dictionary) -> String:
	match o.get("type", ""):
		"artifact":
			return "art:" + o["artifact"]
		"mine":
			return "site:" + o["mine"]
		"dwelling":  # (a neutral creature's own dwelling has a line: the Tomb of Curses)
			return "site:tomb_of_curses" if o.get("creature", "") == "mummy" else ""
	var k := "site:" + str(o.get("type", ""))
	return k if ENTRIES.has(k) else ""

## Has the player held this relic (or holds it now, set pieces and combinations included) or visited this kind of site?
static func known(world: Dictionary, player_index: int, key: String) -> bool:
	if player_index < 0 or player_index >= world.get("players", []).size():
		return false
	var p: Dictionary = world["players"][player_index]
	if key in p.get("lore_known", []):
		return true
	if key.begins_with("art:"):
		var a := key.substr(4)
		for hid in p.get("heroes", []):
			var h: Dictionary = world["heroes"].get(hid, {})
			if a in h.get("artifacts", []) or a in h.get("backpack", []):
				return true
	return false

## Declassifies a line for a player (an artifact taken, a site visited); saved with the world.
static func mark(world: Dictionary, player_index: int, key: String) -> void:
	if not ENTRIES.has(key) or player_index < 0 or player_index >= world.get("players", []).size():
		return
	var p: Dictionary = world["players"][player_index]
	if not p.has("lore_known"):
		p["lore_known"] = []
	if not key in p["lore_known"]:
		p["lore_known"].append(key)

## The line as the player sees it: whole once known, otherwise most of its words blacked out (always the same ones).
static func shown(world: Dictionary, player_index: int, key: String) -> String:
	var text: String = ENTRIES.get(key, "")
	if text == "" or known(world, player_index, key):
		return text
	return redact(text, key)

static func redact(text: String, salt: String) -> String:
	var words := text.split(" ")
	var out := PackedStringArray()
	for i in words.size():
		var w: String = words[i]
		var core := w.rstrip(".,;:!?")
		if core.length() >= 3 and absi(hash([salt, i])) % 10 < 7:
			w = "█".repeat(core.length()) + w.substr(core.length())
		out.append(w)
	return " ".join(out)

## The player whose eyes the screens show (hot-seat: whose turn it is).
static func viewer(world: Dictionary) -> int:
	return int(world.get("viewer", world.get("current_player", 0)))
