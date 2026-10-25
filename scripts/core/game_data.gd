extends Node
## Static game data shared by every system. All asset file names are derived from the ids here
## (see scripts/core/assets.gd and ASSETS.md). Do NOT rename ids without updating assets.

const RESOURCES := ["gold", "wood", "ore", "mercury", "sulfur", "crystal", "gems"]
const RESOURCE_NAMES := {
	"gold": "Gold", "wood": "Wood", "ore": "Ore", "mercury": "Mercury",
	"sulfur": "Sulfur", "crystal": "Crystal", "gems": "Gems",
}

const PLAYER_COLORS := [Color(0.85, 0.15, 0.15), Color(0.2, 0.4, 0.95), Color(0.2, 0.75, 0.3), Color(0.85, 0.7, 0.15)]
const PLAYER_COLOR_NAMES := ["Red", "Blue", "Green", "Gold"]

# ---------------------------------------------------------------------------------------------
# Factions
# ---------------------------------------------------------------------------------------------
## Everything that makes a faction itself, in one record (docs/FOUNDATIONS_AUDIT.md): a new faction is this record,
## its creatures, classes, heroes and buildings' data, and art under its id. Ids stay as first named (`haven` is the
## Temple, `necropolis` the Order of the Dragon; docs/SETTING.md).
##   name, short (for tight labels), desc; creatures / upgrades: tiers 1-7; terrain: native terrain; smith_machine: the war machine its Blacksmith forges;
##   specials: its own buildings (the Town Hall's second row); requires: extra prerequisites in its towns;
##   mage_guild_levels: how high its Mage Guild goes (HoMM3: the Castle's 4, the Necropolis's 5);
##   dwelling_names, town_names; classes: [might, magic] (see CLASSES); battle_figure_lift: its battle hero figures
##   are brightened with a rim light (dark figures before dark siege towers).
const FACTIONS := {
	"haven": {
		"name": "Temple",
		"short": "Temple",
		"desc": "Templar knight-monks, guardians of the Grail.",
		"creatures": ["pikeman", "archer", "griffin", "swordsman", "monk", "cavalier", "angel"],
		"upgrades": ["halberdier", "marksman", "royal_griffin", "crusader", "zealot", "champion", "archangel"],
		"terrain": "grass",
		"smith_machine": "ballista",
		"specials": ["stables", "brotherhood"],
		"requires": {"dwelling_6": ["stables"]},  # (the Stables before the cavalry, as the classic Castle)
		"mage_guild_levels": 4,
		"dwelling_names": ["Guardhouse", "Archers' Tower", "Griffin Tower", "Barracks", "Monastery", "Training Grounds",
			"Portal of Glory"],
		# Templar houses and strongholds of history; five, as before, so a seeded map keeps its names' places
		"town_names": ["Rosslyn", "Gisors", "Tomar", "Acre", "Temple Bruer"],
		"classes": ["Knight", "Cleric"],
	},
	"necropolis": {
		# (the knightly order of 1408 whose Vlad Dracul gave the Dracula legend its name: its vampires and dragons)
		"name": "Order of the Dragon",
		"short": "Dragon",
		"desc": "Deathless heirs of the Dracula legend.",
		"creatures": ["skeleton", "zombie", "ghost", "vampire", "lich", "dread_knight", "bone_dragon"],
		"upgrades": ["skeleton_warrior", "plague_zombie", "wraith", "vampire_lord", "arch_lich", "doom_rider", "ghost_dragon"],
		"terrain": "dirt",
		"smith_machine": "first_aid_tent",
		"specials": ["necromancy_amplifier", "skeleton_transformer"],
		"requires": {},
		"mage_guild_levels": 5,
		"dwelling_names": ["Cursed Temple", "Graveyard", "Tomb of Souls", "Estate", "Mausoleum", "Hall of Darkness",
			"Dragon Vault"],
		"town_names": ["Gravenmoor", "Ashenveil", "Mortholme", "Duskhaven", "Blackfen"],
		"classes": ["Death Knight", "Necromancer"],
		"battle_figure_lift": true,
	},
	"tower": {
		# (HoMM3's Tower as the Illuminated: alchemists, Rosicrucians and the Bavarian order of 1776, hidden sages who
		# make life in flasks and stone; docs/ILLUMINATED.md)
		"name": "The Illuminated",
		"short": "Illuminated",
		"desc": "Hidden sages of the alchemists' art.",
		"creatures": ["homunculus", "gargoyle", "stone_golem", "magus", "genie", "naga", "giant"],
		"upgrades": ["master_homunculus", "obsidian_gargoyle", "iron_golem", "arch_magus", "master_genie", "naga_queen", "titan"],
		"terrain": "snow",
		"smith_machine": "ammo_cart",
		"specials": ["library", "wall_of_knowledge"],
		"requires": {"dwelling_4": ["mage_guild_1"]},  # (the Mage Tower after the Mage Guild, as the classic Tower)
		"mage_guild_levels": 5,
		"dwelling_names": ["Workshop", "Parapet", "Golem Factory", "Mage Tower", "Altar of Wishes", "Golden Pavilion",
			"Cloud Temple"],
		# where the alchemists and the order worked: the Bavarian order's university town, Rudolf II's Prague of the
		# golem, the Rosicrucian manifestos' Kassel and Tübingen, Tycho Brahe's island observatory
		"town_names": ["Ingolstadt", "Prague", "Kassel", "Tübingen", "Uraniborg"],
		"classes": ["Alchemist", "Wizard"],
	},
}

## Hero classes: their faction, might (Attack and Defense favoured at level-up) or magic, and the war machine a new
## hero of the class marches with (might a ballista, magic a first aid tent; more at a smith or factory).
const CLASSES := {
	"Knight": {"faction": "haven", "might": true, "machine": "ballista"},
	"Cleric": {"faction": "haven", "might": false, "machine": "first_aid_tent"},
	"Death Knight": {"faction": "necropolis", "might": true, "machine": "ballista"},
	"Necromancer": {"faction": "necropolis", "might": false, "machine": "first_aid_tent"},
	"Alchemist": {"faction": "tower", "might": true, "machine": "ballista"},
	"Wizard": {"faction": "tower", "might": false, "machine": "first_aid_tent"},
}

# ---------------------------------------------------------------------------------------------
# Creatures.  speed = hexes per turn, init = initiative ordering (higher acts first).
# shots > 0 => ranged.  growth = weekly growth. cost = resource dictionary.
# abilities: flying, ranged, no_retaliation, double_strike, undead, no_melee_penalty,
#            jousting, life_drain, breath, unlimited_retaliation, regenerate, fear, two_hex, mind_immune,
#            unliving (HoMM3's non-living: no morale, mind spells, life drain, disease or Death Ripple),
#            no_wall_penalty, spell_cost_down (its hero's spells cost 2 less), genie_spells (casts helpful spells)
# hates: creature ids it deals +50% damage to (HoMM3's Titans and Black Dragons). spell_immunity: the highest spell
# level that cannot touch it, its own side's spells too (HoMM3's Red Dragons 3, Black Dragons 5: every spell).
# fig_scale: its battle figure taller than its tier's (HoMM3's Giants and Titans tower over men).
# ---------------------------------------------------------------------------------------------
const CREATURES := {
	# ---------------- HAVEN ----------------
	"pikeman": {"name": "Sergeant", "plural": "Sergeants", "faction": "haven", "tier": 1,
		"attack": 4, "defense": 5, "dmg": [1, 3], "hp": 10, "speed": 4, "growth": 14, "shots": 0,
		"cost": {"gold": 60}, "abilities": ["anti_cavalry"], "ai_value": 80},
	"archer": {"name": "Archer", "plural": "Archers", "faction": "haven", "tier": 2,
		"attack": 6, "defense": 3, "dmg": [2, 3], "hp": 10, "speed": 4, "growth": 9, "shots": 12,
		"cost": {"gold": 100}, "abilities": ["ranged"], "ai_value": 126},
	"griffin": {"name": "Griffin", "plural": "Griffins", "faction": "haven", "tier": 3,
		"attack": 8, "defense": 8, "dmg": [3, 6], "hp": 25, "speed": 6, "growth": 7, "shots": 0,
		"cost": {"gold": 200}, "abilities": ["flying", "two_retaliations", "two_hex"], "ai_value": 351},
	"swordsman": {"name": "Swordsman", "plural": "Swordsmen", "faction": "haven", "tier": 4,
		"attack": 10, "defense": 12, "dmg": [6, 9], "hp": 35, "speed": 5, "growth": 4, "shots": 0,
		"cost": {"gold": 300}, "abilities": [], "ai_value": 445},
	"monk": {"name": "Chaplain Brother", "plural": "Chaplain Brothers", "faction": "haven", "tier": 5,
		"attack": 12, "defense": 7, "dmg": [10, 12], "hp": 30, "speed": 5, "growth": 3, "shots": 12,
		"cost": {"gold": 400}, "abilities": ["ranged"], "ai_value": 582},
	"cavalier": {"name": "Cavalier", "plural": "Cavaliers", "faction": "haven", "tier": 6,
		"attack": 15, "defense": 15, "dmg": [15, 25], "hp": 100, "speed": 7, "growth": 2, "shots": 0,
		"cost": {"gold": 1000}, "abilities": ["jousting", "two_hex"], "ai_value": 1946},
	"angel": {"name": "Angel", "plural": "Angels", "faction": "haven", "tier": 7,
		"attack": 20, "defense": 20, "dmg": [50, 50], "hp": 200, "speed": 12, "growth": 1, "shots": 0,
		"cost": {"gold": 3000, "gems": 1}, "abilities": ["flying", "hates_undead", "two_hex"], "ai_value": 5019},
	# ---------------- NECROPOLIS ----------------
	"skeleton": {"name": "Skeleton", "plural": "Skeletons", "faction": "necropolis", "tier": 1,
		"attack": 5, "defense": 4, "dmg": [1, 3], "hp": 6, "speed": 4, "growth": 12, "shots": 0,
		"cost": {"gold": 60}, "abilities": ["undead"], "ai_value": 60},
	"zombie": {"name": "Zombie", "plural": "Zombies", "faction": "necropolis", "tier": 2,
		"attack": 5, "defense": 5, "dmg": [2, 3], "hp": 20, "speed": 3, "growth": 8, "shots": 0,
		"cost": {"gold": 100}, "abilities": ["undead", "disease"], "ai_value": 128},
	"ghost": {"name": "Ghost", "plural": "Ghosts", "faction": "necropolis", "tier": 3,
		"attack": 7, "defense": 7, "dmg": [3, 5], "hp": 18, "speed": 7, "growth": 7, "shots": 0,
		"cost": {"gold": 200}, "abilities": ["undead", "flying", "regenerate"], "ai_value": 270},
	"vampire": {"name": "Vampire", "plural": "Vampires", "faction": "necropolis", "tier": 4,
		"attack": 10, "defense": 9, "dmg": [5, 8], "hp": 30, "speed": 6, "growth": 4, "shots": 0,
		"cost": {"gold": 360}, "abilities": ["undead", "flying", "no_retaliation", "life_drain"], "ai_value": 555},
	"lich": {"name": "Lich", "plural": "Liches", "faction": "necropolis", "tier": 5,
		"attack": 13, "defense": 10, "dmg": [11, 13], "hp": 30, "speed": 6, "growth": 3, "shots": 12,
		"cost": {"gold": 550}, "abilities": ["undead", "ranged", "death_cloud"], "ai_value": 848},
	"dread_knight": {"name": "Dread Knight", "plural": "Dread Knights", "faction": "necropolis", "tier": 6,
		"attack": 18, "defense": 18, "dmg": [15, 30], "hp": 120, "speed": 7, "growth": 2, "shots": 0,
		"cost": {"gold": 1200}, "abilities": ["undead", "death_blow", "two_hex"], "ai_value": 2382},
	"bone_dragon": {"name": "Bone Dragon", "plural": "Bone Dragons", "faction": "necropolis", "tier": 7,
		"attack": 17, "defense": 15, "dmg": [25, 50], "hp": 150, "speed": 9, "growth": 1, "shots": 0,
		"cost": {"gold": 1800}, "abilities": ["undead", "flying", "fear", "two_hex"], "ai_value": 3388},
	# ---------------- WAR MACHINES (tier 0: never recruited or met on the map; "machine" stacks don't move) ----------------
	"ballista": {"name": "Ballista", "plural": "Ballistas", "faction": "neutral", "tier": 0, "machine": true,
		"attack": 10, "defense": 10, "dmg": [10, 20], "hp": 250, "speed": 0, "growth": 0, "shots": 99,
		"cost": {"gold": 2500}, "abilities": ["ranged"], "ai_value": 600},
	"first_aid_tent": {"name": "First Aid Tent", "plural": "First Aid Tents", "faction": "neutral", "tier": 0, "machine": true,
		"attack": 0, "defense": 0, "dmg": [0, 0], "hp": 75, "speed": 0, "growth": 0, "shots": 0,
		"cost": {"gold": 750}, "abilities": ["heals"], "ai_value": 300},
	"ammo_cart": {"name": "Ammo Cart", "plural": "Ammo Carts", "faction": "neutral", "tier": 0, "machine": true,
		"attack": 0, "defense": 5, "dmg": [0, 0], "hp": 100, "speed": 0, "growth": 0, "shots": 0,
		"cost": {"gold": 1000}, "abilities": ["ammo"], "ai_value": 200},
	"catapult": {"name": "Catapult", "plural": "Catapults", "faction": "neutral", "tier": 0, "machine": true,
		"attack": 10, "defense": 10, "dmg": [0, 0], "hp": 1000, "speed": 30, "growth": 0, "shots": 0,
		"cost": {}, "abilities": ["siege"], "ai_value": 100},  # (speed: it fires first each round; it never moves)
	"arrow_tower": {"name": "Arrow Tower", "plural": "Arrow Towers", "faction": "neutral", "tier": 0, "machine": true,
		"attack": 10, "defense": 10, "dmg": [10, 15], "hp": 999, "speed": 0, "growth": 0, "shots": 99,
		"cost": {}, "abilities": ["ranged"], "ai_value": 0},
	# ---------------- NEUTRALS (no town recruits them; met on the map). HoMM3's Gold and Diamond Golems, as the setting's
	# ushabti: Egyptian tomb figurines come to life, the Pyramid's guards (docs/SETTING.md). "spell_resist": % less
	# damage from spells.
	"gold_golem": {"name": "Gilded Ushabti", "plural": "Gilded Ushabtis", "faction": "neutral", "tier": 5,
		"attack": 11, "defense": 12, "dmg": [8, 10], "hp": 50, "speed": 5, "growth": 3, "shots": 0,
		"cost": {"gold": 500}, "abilities": ["golem"], "spell_resist": 85, "ai_value": 600},
	"diamond_golem": {"name": "Crystal Ushabti", "plural": "Crystal Ushabtis", "faction": "neutral", "tier": 6,
		"attack": 13, "defense": 12, "dmg": [10, 14], "hp": 60, "speed": 5, "growth": 2, "shots": 0,
		"cost": {"gold": 750}, "abilities": ["golem"], "spell_resist": 95, "ai_value": 775},
	# HoMM3's Mummy, recruited at its neutral dwelling on the map, the Tomb of Curses ("dwelling": its name)
	"mummy": {"name": "Mummy", "plural": "Mummies", "faction": "neutral", "tier": 3, "dwelling": "Tomb of Curses",
		"attack": 7, "defense": 7, "dmg": [3, 5], "hp": 30, "speed": 5, "growth": 7, "shots": 0,
		"cost": {"gold": 300}, "abilities": ["undead", "curse_strike"], "ai_value": 270},
	# ---------------- THE ILLUMINATED (HoMM3's Tower) ----------------
	"homunculus": {"name": "Homunculus", "plural": "Homunculi", "faction": "tower", "tier": 1,
		"attack": 3, "defense": 3, "dmg": [1, 2], "hp": 4, "speed": 4, "growth": 16, "shots": 0,
		"cost": {"gold": 30}, "abilities": [], "ai_value": 44},
	"gargoyle": {"name": "Gargoyle", "plural": "Gargoyles", "faction": "tower", "tier": 2,
		"attack": 6, "defense": 6, "dmg": [2, 3], "hp": 16, "speed": 6, "growth": 9, "shots": 0,
		"cost": {"gold": 130}, "abilities": ["flying", "unliving"], "ai_value": 165},
	"stone_golem": {"name": "Stone Golem", "plural": "Stone Golems", "faction": "tower", "tier": 3,
		"attack": 7, "defense": 10, "dmg": [4, 5], "hp": 30, "speed": 3, "growth": 6, "shots": 0,
		"cost": {"gold": 150}, "abilities": ["golem", "unliving"], "spell_resist": 50, "ai_value": 250},
	"magus": {"name": "Magus", "plural": "Magi", "faction": "tower", "tier": 4,
		"attack": 11, "defense": 8, "dmg": [7, 9], "hp": 25, "speed": 5, "growth": 5, "shots": 24,
		"cost": {"gold": 350}, "abilities": ["ranged", "no_wall_penalty", "spell_cost_down"], "ai_value": 570},
	"genie": {"name": "Genie", "plural": "Genies", "faction": "tower", "tier": 5,
		"attack": 12, "defense": 12, "dmg": [13, 16], "hp": 40, "speed": 7, "growth": 3, "shots": 0,
		"cost": {"gold": 550}, "abilities": ["flying"], "ai_value": 884},
	"naga": {"name": "Naga", "plural": "Nagas", "faction": "tower", "tier": 6,
		"attack": 16, "defense": 13, "dmg": [20, 20], "hp": 110, "speed": 5, "growth": 2, "shots": 0,
		"cost": {"gold": 1100}, "abilities": ["no_retaliation", "two_hex"], "ai_value": 2016},
	# HoMM3's Tower and Dungeon top creatures. Giants and Titans are the Illuminated's seventh tier, and are met on the
	# map too (the Cloud Temple, wild Titans); Red and Black Dragons wait for their town (Agartha, docs/SETTING.md):
	# Red Dragons recruited at their map dwellings, Black Dragons in the wild or upgraded at a Hill Fort.
	"giant": {"name": "Giant", "plural": "Giants", "faction": "tower", "tier": 7, "dwelling": "Cloud Temple",
		"attack": 19, "defense": 16, "dmg": [40, 60], "hp": 150, "speed": 7, "growth": 1, "shots": 0,
		"cost": {"gold": 2000, "gems": 1}, "abilities": ["mind_immune"], "fig_scale": 1.25, "ai_value": 3718},
	"red_dragon": {"name": "Red Dragon", "plural": "Red Dragons", "faction": "neutral", "tier": 7, "dwelling": "Dragon Cave",
		"attack": 19, "defense": 19, "dmg": [40, 50], "hp": 180, "speed": 9, "growth": 1, "shots": 0,
		"cost": {"gold": 2500, "sulfur": 1}, "abilities": ["flying", "breath", "two_hex"], "spell_immunity": 3, "ai_value": 4702},
	# ---------------- UPGRADES (from an upgraded dwelling; "upgrade_of" names the base creature) ----------------
	"halberdier": {"name": "Halberdier", "plural": "Halberdiers", "faction": "haven", "tier": 1, "upgrade_of": "pikeman",
		"attack": 6, "defense": 5, "dmg": [2, 3], "hp": 10, "speed": 5, "growth": 14, "shots": 0,
		"cost": {"gold": 75}, "abilities": ["anti_cavalry"], "ai_value": 115},
	"marksman": {"name": "Marksman", "plural": "Marksmen", "faction": "haven", "tier": 2, "upgrade_of": "archer",
		"attack": 7, "defense": 4, "dmg": [2, 4], "hp": 10, "speed": 6, "growth": 9, "shots": 24,
		"cost": {"gold": 150}, "abilities": ["ranged"], "ai_value": 184},
	"royal_griffin": {"name": "Royal Griffin", "plural": "Royal Griffins", "faction": "haven", "tier": 3, "upgrade_of": "griffin",
		"attack": 9, "defense": 9, "dmg": [3, 6], "hp": 25, "speed": 9, "growth": 7, "shots": 0,
		"cost": {"gold": 240}, "abilities": ["flying", "two_retaliations", "two_hex"], "ai_value": 448},
	"crusader": {"name": "Crusader", "plural": "Crusaders", "faction": "haven", "tier": 4, "upgrade_of": "swordsman",
		"attack": 12, "defense": 12, "dmg": [7, 10], "hp": 35, "speed": 6, "growth": 4, "shots": 0,
		"cost": {"gold": 400}, "abilities": ["double_strike"], "ai_value": 588},
	"zealot": {"name": "Zealot", "plural": "Zealots", "faction": "haven", "tier": 5, "upgrade_of": "monk",
		"attack": 12, "defense": 10, "dmg": [10, 12], "hp": 30, "speed": 7, "growth": 3, "shots": 24,
		"cost": {"gold": 450}, "abilities": ["ranged"], "ai_value": 750},
	"champion": {"name": "Champion", "plural": "Champions", "faction": "haven", "tier": 6, "upgrade_of": "cavalier",
		"attack": 16, "defense": 16, "dmg": [20, 25], "hp": 100, "speed": 9, "growth": 2, "shots": 0,
		"cost": {"gold": 1200}, "abilities": ["jousting", "two_hex"], "ai_value": 2100},
	"archangel": {"name": "Archangel", "plural": "Archangels", "faction": "haven", "tier": 7, "upgrade_of": "angel",
		"attack": 30, "defense": 30, "dmg": [50, 50], "hp": 250, "speed": 18, "growth": 1, "shots": 0,
		"cost": {"gold": 5000, "gems": 3}, "abilities": ["flying", "hates_undead", "two_hex"], "ai_value": 8776},
	"skeleton_warrior": {"name": "Skeleton Warrior", "plural": "Skeleton Warriors", "faction": "necropolis", "tier": 1, "upgrade_of": "skeleton",
		"attack": 6, "defense": 6, "dmg": [1, 3], "hp": 6, "speed": 5, "growth": 12, "shots": 0,
		"cost": {"gold": 70}, "abilities": ["undead"], "ai_value": 85},
	"plague_zombie": {"name": "Plague Zombie", "plural": "Plague Zombies", "faction": "necropolis", "tier": 2, "upgrade_of": "zombie",
		"attack": 7, "defense": 6, "dmg": [2, 3], "hp": 25, "speed": 4, "growth": 8, "shots": 0,
		"cost": {"gold": 140}, "abilities": ["undead", "disease"], "ai_value": 180},
	"wraith": {"name": "Wraith", "plural": "Wraiths", "faction": "necropolis", "tier": 3, "upgrade_of": "ghost",
		"attack": 7, "defense": 7, "dmg": [3, 5], "hp": 18, "speed": 9, "growth": 7, "shots": 0,
		"cost": {"gold": 230}, "abilities": ["undead", "flying", "regenerate"], "ai_value": 315},
	"vampire_lord": {"name": "Vampire Lord", "plural": "Vampire Lords", "faction": "necropolis", "tier": 4, "upgrade_of": "vampire",
		"attack": 10, "defense": 10, "dmg": [5, 8], "hp": 40, "speed": 9, "growth": 4, "shots": 0,
		"cost": {"gold": 500}, "abilities": ["undead", "flying", "no_retaliation", "life_drain"], "ai_value": 783},
	"arch_lich": {"name": "Arch Lich", "plural": "Arch Liches", "faction": "necropolis", "tier": 5, "upgrade_of": "lich",
		"attack": 13, "defense": 10, "dmg": [11, 15], "hp": 40, "speed": 7, "growth": 3, "shots": 24,
		"cost": {"gold": 600}, "abilities": ["undead", "ranged", "death_cloud"], "ai_value": 1079},
	"doom_rider": {"name": "Doom Rider", "plural": "Doom Riders", "faction": "necropolis", "tier": 6, "upgrade_of": "dread_knight",
		"attack": 20, "defense": 20, "dmg": [20, 35], "hp": 130, "speed": 9, "growth": 2, "shots": 0,
		"cost": {"gold": 1500}, "abilities": ["undead", "death_blow", "two_hex"], "ai_value": 2950},
	"ghost_dragon": {"name": "Ghost Dragon", "plural": "Ghost Dragons", "faction": "necropolis", "tier": 7, "upgrade_of": "bone_dragon",
		"attack": 19, "defense": 17, "dmg": [25, 50], "hp": 200, "speed": 14, "growth": 1, "shots": 0,
		"cost": {"gold": 3000, "mercury": 1}, "abilities": ["undead", "flying", "fear", "two_hex"], "ai_value": 4696},
	"master_homunculus": {"name": "Master Homunculus", "plural": "Master Homunculi", "faction": "tower", "tier": 1, "upgrade_of": "homunculus",
		"attack": 4, "defense": 4, "dmg": [1, 2], "hp": 4, "speed": 5, "growth": 16, "shots": 8,
		"cost": {"gold": 40}, "abilities": ["ranged"], "ai_value": 66},
	"obsidian_gargoyle": {"name": "Obsidian Gargoyle", "plural": "Obsidian Gargoyles", "faction": "tower", "tier": 2, "upgrade_of": "gargoyle",
		"attack": 7, "defense": 7, "dmg": [2, 3], "hp": 16, "speed": 9, "growth": 9, "shots": 0,
		"cost": {"gold": 160}, "abilities": ["flying", "unliving"], "ai_value": 201},
	"iron_golem": {"name": "Iron Golem", "plural": "Iron Golems", "faction": "tower", "tier": 3, "upgrade_of": "stone_golem",
		"attack": 9, "defense": 10, "dmg": [4, 5], "hp": 35, "speed": 5, "growth": 6, "shots": 0,
		"cost": {"gold": 200}, "abilities": ["golem", "unliving"], "spell_resist": 75, "ai_value": 412},
	"arch_magus": {"name": "Arch Magus", "plural": "Arch Magi", "faction": "tower", "tier": 4, "upgrade_of": "magus",
		"attack": 12, "defense": 9, "dmg": [7, 9], "hp": 30, "speed": 7, "growth": 5, "shots": 24,
		"cost": {"gold": 450}, "abilities": ["ranged", "no_wall_penalty", "spell_cost_down"], "ai_value": 680},
	"master_genie": {"name": "Master Genie", "plural": "Master Genies", "faction": "tower", "tier": 5, "upgrade_of": "genie",
		"attack": 12, "defense": 12, "dmg": [13, 16], "hp": 40, "speed": 11, "growth": 3, "shots": 0,
		"cost": {"gold": 600}, "abilities": ["flying", "genie_spells"], "ai_value": 942},
	"naga_queen": {"name": "Naga Queen", "plural": "Naga Queens", "faction": "tower", "tier": 6, "upgrade_of": "naga",
		"attack": 16, "defense": 13, "dmg": [30, 30], "hp": 110, "speed": 7, "growth": 2, "shots": 0,
		"cost": {"gold": 1600}, "abilities": ["no_retaliation", "two_hex"], "ai_value": 2840},
	"titan": {"name": "Titan", "plural": "Titans", "faction": "tower", "tier": 7, "upgrade_of": "giant",
		"attack": 24, "defense": 24, "dmg": [40, 60], "hp": 300, "speed": 11, "growth": 1, "shots": 24,
		"cost": {"gold": 5000, "gems": 2}, "abilities": ["ranged", "no_melee_penalty", "mind_immune"], "hates": ["black_dragon"], "fig_scale": 1.25,
		"ai_value": 7500},
	"black_dragon": {"name": "Black Dragon", "plural": "Black Dragons", "faction": "neutral", "tier": 7, "upgrade_of": "red_dragon",
		"attack": 25, "defense": 25, "dmg": [40, 50], "hp": 300, "speed": 15, "growth": 1, "shots": 0,
		"cost": {"gold": 4000, "sulfur": 2}, "abilities": ["flying", "breath", "two_hex"], "hates": ["titan"], "spell_immunity": 5,
		"ai_value": 8721},
}

## War machines a hero can own (bought at a Blacksmith); the catapult comes with every hero laying siege.
const WAR_MACHINES := ["ballista", "first_aid_tent", "ammo_cart"]
const MACHINE_TEXT := {
	"ballista": "Shoots an enemy stack every round, guided by the hero's Attack.",
	"first_aid_tent": "Heals the top creature of a wounded friendly stack every round.",
	"ammo_cart": "Friendly shooters never run out of arrows.",
	"catapult": "Batters the walls and towers of a besieged town.",
}

const ABILITY_TEXT := {
	"ranged": "Shooter", "flying": "Flying", "undead": "Undead",
	"no_retaliation": "No enemy retaliation", "life_drain": "Drains life",
	"two_retaliations": "Retaliates twice", "jousting": "Jousting bonus",
	"anti_cavalry": "Immune to jousting", "hates_undead": "Hates undead (+50% dmg)",
	"disease": "Disease (-2 Atk/Def)", "regenerate": "Regenerates", "death_cloud": "Death cloud",
	"death_blow": "Chance for double damage", "fear": "Causes fear", "two_hex": "Large creature",
	"golem": "Golem: spells hurt it far less",
	"curse_strike": "Curses what it strikes (25%)",
	"breath": "Breath: strikes the stack behind too", "no_melee_penalty": "No melee penalty",
	"mind_immune": "Immune to mind spells",
	"unliving": "Not alive: no morale, immune to mind spells",
	"no_wall_penalty": "No wall penalty when shooting", "spell_cost_down": "Its hero's spells cost 2 less",
	"genie_spells": "Casts a random helpful spell on an ally (3 a battle)",
}

# ---------------------------------------------------------------------------------------------
# Heroes. class: might (knight/death_knight) or magic (cleric/necromancer).
# ---------------------------------------------------------------------------------------------
const HEROES := {
	"sir_aldric": {"name": "Sir Aldric", "faction": "haven", "class": "Knight",
		"attack": 2, "defense": 2, "power": 1, "knowledge": 1, "specialty": "Leadership", "skills": {"leadership": 1}},
	"lady_seraphine": {"name": "Lady Seraphine", "faction": "haven", "class": "Cleric",
		"attack": 1, "defense": 0, "power": 2, "knowledge": 2, "specialty": "Light magic", "skills": {"wisdom": 1}, "spells": ["bless", "cure"]},
	"lord_gareth": {"name": "Lord Gareth", "faction": "haven", "class": "Knight",
		"attack": 3, "defense": 1, "power": 1, "knowledge": 1, "specialty": "Archery", "skills": {"archery": 1}},
	"brother_tomas": {"name": "Brother Tomas", "faction": "haven", "class": "Cleric",
		"attack": 0, "defense": 1, "power": 2, "knowledge": 3, "specialty": "Knowledge", "skills": {"wisdom": 1}, "spells": ["magic_arrow", "shield"]},
	# heroes from legend (docs/SETTING.md): the last Grand Master of the Temple and its founder
	"jacques_de_molay": {"name": "Jacques de Molay", "faction": "haven", "class": "Knight",
		"attack": 1, "defense": 3, "power": 1, "knowledge": 1, "specialty": "Armorer", "skills": {"armorer": 1}},
	"hugues_de_payens": {"name": "Hugues de Payens", "faction": "haven", "class": "Knight",
		"attack": 2, "defense": 2, "power": 1, "knowledge": 1, "specialty": "Logistics", "skills": {"logistics": 1}},
	"lord_morthis": {"name": "Lord Morthis", "faction": "necropolis", "class": "Death Knight",
		"attack": 2, "defense": 2, "power": 1, "knowledge": 1, "specialty": "Necromancy", "skills": {"necromancy": 1}},
	"vesna_nightshade": {"name": "Vesna Nightshade", "faction": "necropolis", "class": "Necromancer",
		"attack": 1, "defense": 0, "power": 3, "knowledge": 2, "specialty": "Dark magic", "skills": {"necromancy": 1}, "spells": ["curse", "slow"]},
	"kragor_the_pale": {"name": "Kragor the Pale", "faction": "necropolis", "class": "Death Knight",
		"attack": 3, "defense": 2, "power": 0, "knowledge": 1, "specialty": "Offense", "skills": {"necromancy": 1, "offense": 1}},
	"ilsa_grimveil": {"name": "Ilsa Grimveil", "faction": "necropolis", "class": "Necromancer",
		"attack": 0, "defense": 1, "power": 2, "knowledge": 3, "specialty": "Sorcery", "skills": {"necromancy": 1}, "spells": ["magic_arrow", "weakness"]},
	# heroes from legend: the count who never aged, and John Dee's scryer
	"saint_germain": {"name": "Saint-Germain", "faction": "necropolis", "class": "Necromancer",
		"attack": 1, "defense": 1, "power": 2, "knowledge": 2, "specialty": "Wisdom", "skills": {"necromancy": 1, "wisdom": 1}, "spells": ["haste", "weakness"]},
	"edward_kelley": {"name": "Edward Kelley", "faction": "necropolis", "class": "Necromancer",
		"attack": 0, "defense": 1, "power": 3, "knowledge": 2, "specialty": "Luck", "skills": {"necromancy": 1, "luck": 1}, "spells": ["curse", "magic_arrow"]},
	# the Illuminated, all from legend (docs/ILLUMINATED.md): the alchemist who made the Stone and his wife, the
	# physician-alchemist, the brotherhood's founder, the order's founder, the count of a hundred names
	"nicolas_flamel": {"name": "Nicolas Flamel", "faction": "tower", "class": "Alchemist",
		"attack": 1, "defense": 1, "power": 2, "knowledge": 2, "specialty": "Wisdom", "skills": {"wisdom": 1},
		"spells": ["stone_skin"]},
	"perenelle_flamel": {"name": "Perenelle Flamel", "faction": "tower", "class": "Alchemist",
		"attack": 1, "defense": 2, "power": 1, "knowledge": 2, "specialty": "Armorer", "skills": {"armorer": 1},
		"spells": ["shield"]},
	"paracelsus": {"name": "Paracelsus", "faction": "tower", "class": "Alchemist",
		"attack": 2, "defense": 1, "power": 1, "knowledge": 2, "specialty": "Archery", "skills": {"archery": 1},
		"spells": ["cure"]},
	"christian_rosenkreuz": {"name": "Christian Rosenkreuz", "faction": "tower", "class": "Wizard",
		"attack": 0, "defense": 0, "power": 2, "knowledge": 4, "specialty": "Wisdom", "skills": {"wisdom": 1},
		"spells": ["magic_arrow", "haste"]},
	"adam_weishaupt": {"name": "Adam Weishaupt", "faction": "tower", "class": "Wizard",
		"attack": 0, "defense": 1, "power": 3, "knowledge": 2, "specialty": "Sorcery", "skills": {"wisdom": 1, "sorcery": 1},
		"spells": ["magic_arrow", "slow"]},
	"cagliostro": {"name": "Cagliostro", "faction": "tower", "class": "Wizard",
		"attack": 1, "defense": 0, "power": 2, "knowledge": 3, "specialty": "Luck", "skills": {"wisdom": 1, "luck": 1},
		"spells": ["bless", "curse"]},
}

const SKILLS := {
	"leadership": {"name": "Leadership", "desc": "+1 morale per level."},
	"wisdom": {"name": "Wisdom", "desc": "Learn higher level spells."},
	"archery": {"name": "Archery", "desc": "+15% ranged damage per level."},
	"offense": {"name": "Offense", "desc": "+10% melee damage per level."},
	"armorer": {"name": "Armorer", "desc": "-7% damage taken per level."},
	"necromancy": {"name": "Necromancy", "raise": {"creature": "skeleton"}, "desc": "After victory, raise slain enemies as Skeletons: Basic 10%, Advanced 20%, Expert 30%. Requires army space or a Skeleton stack; a full army with Skeleton Warriors receives two thirds as many Warriors."},
	"logistics": {"name": "Logistics", "desc": "+10% movement per level."},
	"luck": {"name": "Luck", "desc": "+1 luck per level."},
	"sorcery": {"name": "Sorcery", "desc": "+10% spell damage per level."},
}

# ---------------------------------------------------------------------------------------------
# Spells (combat).  target: enemy, ally, area, all_living, all (every stack on the field, both sides).
# mind: a mind spell (undead and the ushabti, as HoMM3's golems, are immune). chain: stacks a bolt strikes, the first at
# full damage and each jump at half the one before (Chain Lightning). HoMM3's values at the basic level (the game has no
# school mastery).
# ---------------------------------------------------------------------------------------------
const SPELLS := {
	"magic_arrow": {"name": "Magic Arrow", "level": 1, "school": "air", "mana": 5, "target": "enemy", "damage": [10, 10], "desc": "Deals 10 + 10×Power damage."},
	"bless": {"name": "Bless", "level": 1, "school": "water", "mana": 5, "target": "ally", "desc": "Target deals maximum damage."},
	"curse": {"name": "Curse", "level": 1, "school": "fire", "mana": 6, "target": "enemy", "desc": "Target deals minimum damage."},
	"shield": {"name": "Shield", "level": 1, "school": "earth", "mana": 5, "target": "ally", "desc": "Reduces melee damage taken by 15%."},
	"haste": {"name": "Haste", "level": 1, "school": "air", "mana": 6, "target": "ally", "desc": "+3 speed."},
	"slow": {"name": "Slow", "level": 1, "school": "earth", "mana": 6, "target": "enemy", "desc": "-25% speed."},
	"cure": {"name": "Cure", "level": 1, "school": "water", "mana": 6, "target": "ally", "desc": "Heals 10 + 5×Power HP and removes negative effects."},
	"weakness": {"name": "Weakness", "level": 2, "school": "water", "mana": 8, "target": "enemy", "desc": "-3 attack."},
	"lightning_bolt": {"name": "Lightning Bolt", "level": 2, "school": "air", "mana": 10, "target": "enemy", "damage": [10, 25], "desc": "Deals 10 + 25×Power damage."},
	"ice_bolt": {"name": "Ice Bolt", "level": 2, "school": "water", "mana": 8, "target": "enemy", "damage": [10, 20], "desc": "Deals 10 + 20×Power damage."},
	"stone_skin": {"name": "Stone Skin", "level": 1, "school": "earth", "mana": 5, "target": "ally", "desc": "+3 defense."},
	"fireball": {"name": "Fireball", "level": 3, "school": "fire", "mana": 15, "target": "area", "damage": [15, 10], "desc": "Deals 15 + 10×Power damage in an area."},
	"frost_ring": {"name": "Frost Ring", "level": 3, "school": "water", "mana": 12, "target": "area", "damage": [15, 10], "desc": "Deals 15 + 10×Power damage in an area."},
	"death_ripple": {"name": "Death Ripple", "level": 2, "school": "earth", "mana": 10, "target": "all_living", "damage": [10, 5], "desc": "Deals 10 + 5×Power damage to every living creature."},
	"resurrection": {"name": "Resurrection", "level": 4, "school": "earth", "mana": 20, "target": "ally", "desc": "Revives 40 + 20×Power HP of fallen creatures."},
	"meteor_shower": {"name": "Meteor Shower", "level": 4, "school": "earth", "mana": 16, "target": "area", "damage": [25, 25], "desc": "Deals 25 + 25×Power damage in an area."},
	"blind": {"name": "Blind", "level": 2, "school": "fire", "mana": 10, "target": "enemy", "mind": true, "desc": "The target cannot act until it is attacked or the spell ends; attacked, it strikes back at half damage. Undead and ushabti are immune."},
	"chain_lightning": {"name": "Chain Lightning", "level": 4, "school": "air", "mana": 24, "target": "enemy", "damage": [25, 40], "chain": 4, "desc": "Deals 25 + 40×Power damage to the target, then jumps to the nearest stack, friend or foe, three more times at half the damage each jump."},
	"berserk": {"name": "Berserk", "level": 4, "school": "fire", "mana": 20, "target": "enemy", "mind": true, "desc": "On its turn the target attacks the nearest stack, friend or foe; the spell ends once it has attacked. Undead and ushabti are immune."},
	"armageddon": {"name": "Armageddon", "level": 4, "school": "fire", "mana": 24, "target": "all", "damage": [30, 50], "desc": "Deals 30 + 50×Power damage to every creature on the field, yours too."},
	"implosion": {"name": "Implosion", "level": 5, "school": "earth", "mana": 30, "target": "enemy", "damage": [100, 75], "desc": "Deals 100 + 75×Power damage to the target."},
}

# ---------------------------------------------------------------------------------------------
# Town buildings. dwelling_tier > 0 => creature dwelling. requires = list of building ids.
# ---------------------------------------------------------------------------------------------
const BUILDINGS := {
	"village_hall": {"name": "Village Hall", "cost": {}, "income": 500, "requires": [], "desc": "+500 gold per day."},
	"town_hall": {"name": "Town Hall", "cost": {"gold": 2500}, "income": 1000, "requires": ["village_hall", "tavern"], "replaces": "village_hall", "desc": "+1000 gold per day."},
	"city_hall": {"name": "City Hall", "cost": {"gold": 5000}, "income": 2000, "requires": ["town_hall", "marketplace", "mage_guild_1"], "replaces": "town_hall", "desc": "+2000 gold per day."},
	"capitol": {"name": "Capitol", "cost": {"gold": 10000, "wood": 10, "ore": 10}, "income": 4000, "requires": ["city_hall", "castle"], "replaces": "city_hall", "desc": "+4000 gold per day. Only one Capitol per kingdom."},
	"fort": {"name": "Fort", "cost": {"gold": 5000, "wood": 20, "ore": 20}, "requires": [], "desc": "A wall and a gate defend the town in sieges."},
	"citadel": {"name": "Citadel", "cost": {"gold": 2500, "ore": 5}, "requires": ["fort"], "replaces": "fort", "desc": "+50% creature growth. A moat and a keep with an arrow turret defend the town in sieges."},
	"castle": {"name": "Castle", "cost": {"gold": 5000, "wood": 10, "ore": 10}, "requires": ["citadel"], "replaces": "citadel", "desc": "+100% creature growth. Two more arrow towers defend the town in sieges."},
	"tavern": {"name": "Tavern", "cost": {"gold": 500, "wood": 5}, "requires": [], "desc": "Hire heroes. +1 morale on defense."},
	"marketplace": {"name": "Marketplace", "cost": {"gold": 500, "wood": 5}, "requires": [], "desc": "Trade resources."},
	"mage_guild_1": {"name": "Mage Guild", "cost": {"gold": 2000, "wood": 5, "ore": 5}, "requires": [], "desc": "Teaches level 1 spells."},
	"mage_guild_2": {"name": "Mage Guild Lv2", "cost": {"gold": 1000, "wood": 5, "ore": 5, "crystal": 4, "gems": 4}, "requires": ["mage_guild_1"], "replaces": "mage_guild_1", "desc": "Teaches level 2 spells."},
	"mage_guild_3": {"name": "Mage Guild Lv3", "cost": {"gold": 1000, "wood": 5, "ore": 5, "mercury": 4, "sulfur": 4, "crystal": 4, "gems": 4}, "requires": ["mage_guild_2"], "replaces": "mage_guild_2", "desc": "Teaches level 3 spells."},
	"mage_guild_4": {"name": "Mage Guild Lv4", "cost": {"gold": 1000, "wood": 5, "ore": 5, "mercury": 6, "sulfur": 6, "crystal": 6, "gems": 6}, "requires": ["mage_guild_3"], "replaces": "mage_guild_3", "desc": "Teaches level 4 spells."},
	"mage_guild_5": {"name": "Mage Guild Lv5", "cost": {"gold": 1000, "wood": 5, "ore": 5, "mercury": 10, "sulfur": 10, "crystal": 10, "gems": 10}, "requires": ["mage_guild_4"], "replaces": "mage_guild_4", "desc": "Teaches level 5 spells."},
	"blacksmith": {"name": "Blacksmith", "cost": {"gold": 1000, "wood": 5}, "requires": [], "desc": "Sells the town's war machine to a visiting hero: a Ballista in the Temple's towns, a First Aid Tent in the Order of the Dragon's, an Ammo Cart in the Illuminated's."},
	# faction special buildings ("faction": only that faction's towns can build them). "effects" are what they do, read
	# by the rules (TownLogic.effect): start_day_movement (a hero starting the day in the town), siege_morale (the
	# town's defenders), necromancy (+% raised by all the owner's heroes), transform_to (turns a visiting hero's
	# living creatures into that creature), guild_spells (more spells per Mage Guild level), visit_knowledge (+Knowledge
	# once to each visiting hero). "ai_after": the computer builds it right after that building.
	"stables": {"name": "Stables", "faction": "haven", "cost": {"gold": 2000, "wood": 10}, "requires": [],
		"effects": {"start_day_movement": 400}, "ai_after": "city_hall", "desc": "Heroes who start the day in this town get +400 movement points."},
	"brotherhood": {"name": "Chapter House", "faction": "haven", "cost": {"gold": 500, "wood": 5}, "requires": ["tavern"],
		"effects": {"siege_morale": 2}, "ai_after": "mage_guild_2", "desc": "+2 morale for the defenders when the town is besieged."},
	"necromancy_amplifier": {"name": "Necromancy Amplifier", "faction": "necropolis", "cost": {"gold": 1000}, "requires": ["mage_guild_1"],
		"effects": {"necromancy": 10}, "ai_after": "mage_guild_2", "desc": "All your heroes raise 10% more Skeletons with Necromancy."},
	"skeleton_transformer": {"name": "Skeleton Transformer", "faction": "necropolis", "cost": {"gold": 1000}, "requires": ["dwelling_1"],
		"effects": {"transform_to": "skeleton"}, "desc": "Turns a visiting hero's living creatures into Skeletons."},
	"library": {"name": "Library", "faction": "tower", "cost": {"gold": 1500, "wood": 5, "ore": 5, "mercury": 5, "sulfur": 5, "crystal": 5, "gems": 5},
		"requires": ["mage_guild_1"], "effects": {"guild_spells": 1}, "ai_after": "mage_guild_2",
		"desc": "The Mage Guild teaches one more spell of every level."},
	"wall_of_knowledge": {"name": "Wall of Knowledge", "faction": "tower", "cost": {"gold": 1000, "ore": 5}, "requires": ["mage_guild_1"],
		"effects": {"visit_knowledge": 1}, "ai_after": "mage_guild_1",
		"desc": "+1 Knowledge, once, to each hero who visits the town."},
	"dwelling_1": {"name": "Dwelling I", "cost": {"gold": 1000, "ore": 5}, "dwelling_tier": 1, "requires": ["fort"]},
	"dwelling_2": {"name": "Dwelling II", "cost": {"gold": 1000, "wood": 5, "ore": 5}, "dwelling_tier": 2, "requires": ["dwelling_1"]},
	"dwelling_3": {"name": "Dwelling III", "cost": {"gold": 1500, "wood": 5, "ore": 5}, "dwelling_tier": 3, "requires": ["dwelling_1"]},
	"dwelling_4": {"name": "Dwelling IV", "cost": {"gold": 2000, "wood": 10, "ore": 5, "mercury": 2}, "dwelling_tier": 4, "requires": ["dwelling_2", "tavern"]},
	"dwelling_5": {"name": "Dwelling V", "cost": {"gold": 3000, "wood": 5, "ore": 5, "crystal": 5, "gems": 5}, "dwelling_tier": 5, "requires": ["dwelling_3", "mage_guild_1"]},
	"dwelling_6": {"name": "Dwelling VI", "cost": {"gold": 5000, "wood": 10, "ore": 10, "sulfur": 5}, "dwelling_tier": 6, "requires": ["dwelling_4", "blacksmith"]},
	"dwelling_7": {"name": "Dwelling VII", "cost": {"gold": 20000, "ore": 10, "mercury": 10, "gems": 10}, "dwelling_tier": 7, "requires": ["dwelling_5", "dwelling_6", "citadel"]},
	# upgraded dwellings replace their base one and recruit (and upgrade stacks to) the faction's upgraded creature
	"dwelling_1u": {"name": "Upg. Dwelling I", "cost": {"gold": 1000, "ore": 5}, "dwelling_tier": 1, "requires": ["dwelling_1", "blacksmith"], "replaces": "dwelling_1"},
	"dwelling_2u": {"name": "Upg. Dwelling II", "cost": {"gold": 1000, "wood": 5, "ore": 5}, "dwelling_tier": 2, "requires": ["dwelling_2"], "replaces": "dwelling_2"},
	"dwelling_3u": {"name": "Upg. Dwelling III", "cost": {"gold": 1000, "wood": 5, "ore": 5}, "dwelling_tier": 3, "requires": ["dwelling_3"], "replaces": "dwelling_3"},
	"dwelling_4u": {"name": "Upg. Dwelling IV", "cost": {"gold": 1500, "wood": 5, "ore": 5, "crystal": 5}, "dwelling_tier": 4, "requires": ["dwelling_4"], "replaces": "dwelling_4"},
	"dwelling_5u": {"name": "Upg. Dwelling V", "cost": {"gold": 3000, "wood": 5, "ore": 5, "crystal": 2, "gems": 2}, "dwelling_tier": 5, "requires": ["dwelling_5", "mage_guild_2"], "replaces": "dwelling_5"},
	"dwelling_6u": {"name": "Upg. Dwelling VI", "cost": {"gold": 3000, "wood": 10, "ore": 10, "sulfur": 5}, "dwelling_tier": 6, "requires": ["dwelling_6"], "replaces": "dwelling_6"},
	"dwelling_7u": {"name": "Upg. Dwelling VII", "cost": {"gold": 20000, "ore": 10, "mercury": 10, "gems": 10}, "dwelling_tier": 7, "requires": ["dwelling_7", "mage_guild_3"], "replaces": "dwelling_7"},
}

## Whether a town of this faction can have the building: its own specials only, and its Mage Guild only as high as
## the faction's goes.
static func in_faction(faction: String, id: String) -> bool:
	var b: Dictionary = BUILDINGS[id]
	if b.get("faction", faction) != faction:
		return false
	if id.begins_with("mage_guild_") and int(id.substr(11)) > int(FACTIONS[faction].get("mage_guild_levels", 4)):
		return false
	return true

## Everything a building needs in a town of this faction.
static func requires(faction: String, id: String) -> Array:
	return BUILDINGS[id]["requires"] + FACTIONS[faction].get("requires", {}).get(id, [])

# ---------------------------------------------------------------------------------------------
# Artifacts
# ---------------------------------------------------------------------------------------------
## Artifacts in the classic's four tiers (treasure, minor, major, relic) plus combination artifacts. "bonus" holds
## numbers summed over what a hero wears (GameState.hero_stat): attack defense power knowledge morale luck movement,
## hp (every creature), speed (every creature), scout (sight radius), mana_day, gold_day, school_<air|fire|water|earth>
## (+% damage of that school's spells), necromancy (+% raised, with the skill), growth1 (weekly growth of
## first-level creatures in all the owner's towns). "flags" hold the rest (GameState.hero_flags): immune_school,
## immune_spells, raise. A combination ("parts") is worn when all its parts are: they merge into it (as the classic's
## combination artifacts), it fills all their slots, and it can be split back on the hero screen.
const ARTIFACTS := {
	# might
	"soldiers_shortsword": {"name": "Soldier's Shortsword", "slot": "weapon", "tier": "treasure", "bonus": {"attack": 1}, "desc": "+1 Attack"},
	"sword_of_valor": {"name": "Sword of Valor", "slot": "weapon", "tier": "minor", "bonus": {"attack": 3}, "desc": "+3 Attack"},
	"ogre_hewn_cleaver": {"name": "Ogre-Hewn Cleaver", "slot": "weapon", "tier": "major", "bonus": {"attack": 5}, "desc": "+5 Attack"},
	"oaken_buckler": {"name": "Oaken Buckler", "slot": "shield", "tier": "treasure", "bonus": {"defense": 1}, "desc": "+1 Defense"},
	"shield_of_dawn": {"name": "Shield of Dawn", "slot": "shield", "tier": "minor", "bonus": {"defense": 3}, "desc": "+3 Defense"},
	"ironwood_tower_shield": {"name": "Ironwood Tower Shield", "slot": "shield", "tier": "major", "bonus": {"defense": 5}, "desc": "+5 Defense"},
	"quilted_gambeson": {"name": "Quilted Gambeson", "slot": "torso", "tier": "treasure", "bonus": {"defense": 1}, "desc": "+1 Defense"},
	"breastplate_of_ironbark": {"name": "Breastplate of Ironbark", "slot": "torso", "tier": "minor", "bonus": {"defense": 2}, "desc": "+2 Defense"},
	"ring_of_vitality": {"name": "Ankh of Life", "slot": "ring", "tier": "major", "bonus": {"hp": 1}, "desc": "+1 health for every creature"},
	"ring_of_swiftness": {"name": "Ring of Swiftness", "slot": "ring", "tier": "major", "bonus": {"speed": 1}, "desc": "+1 speed for every creature"},
	"crown_of_command": {"name": "Crown of Prester John", "slot": "head", "tier": "major", "bonus": {"attack": 2, "defense": 2, "power": 2, "knowledge": 2}, "desc": "+2 to all four stats"},
	# magic
	"apprentices_circlet": {"name": "Apprentice's Circlet", "slot": "head", "tier": "treasure", "bonus": {"knowledge": 1}, "desc": "+1 Knowledge"},
	"helm_of_wisdom": {"name": "Helm of Solomon", "slot": "head", "tier": "minor", "bonus": {"knowledge": 2}, "desc": "+2 Knowledge"},
	"amulet_of_insight": {"name": "Eye of Horus", "slot": "neck", "tier": "minor", "bonus": {"power": 1, "knowledge": 1}, "desc": "+1 Spell Power, +1 Knowledge"},
	"pendant_of_clarity": {"name": "Pendant of Clarity", "slot": "neck", "tier": "minor", "bonus": {"mana_day": 3}, "desc": "+3 mana each day"},
	"orb_of_power": {"name": "Crystal Skull", "slot": "misc", "tier": "minor", "bonus": {"power": 3}, "desc": "+3 Spell Power"},
	"orb_of_tempests": {"name": "Orb of Tempests", "slot": "misc", "tier": "major", "bonus": {"school_air": 50}, "desc": "Air spells deal 50% more damage"},
	"orb_of_embers": {"name": "Orb of Embers", "slot": "misc", "tier": "major", "bonus": {"school_fire": 50}, "desc": "Fire spells deal 50% more damage"},
	"orb_of_tides": {"name": "Orb of Tides", "slot": "misc", "tier": "major", "bonus": {"school_water": 50}, "desc": "Water spells deal 50% more damage"},
	"orb_of_bedrock": {"name": "Orb of Bedrock", "slot": "misc", "tier": "major", "bonus": {"school_earth": 50}, "desc": "Earth spells deal 50% more damage"},
	# logistics and scouting
	"travellers_boots": {"name": "Traveller's Boots", "slot": "feet", "tier": "treasure", "bonus": {"movement": 200}, "desc": "+200 movement points"},
	"boots_of_speed": {"name": "Seven-League Boots", "slot": "feet", "tier": "major", "bonus": {"movement": 600}, "desc": "+600 movement points"},
	"wayfarers_cloak": {"name": "Wayfarer's Cloak", "slot": "cape", "tier": "treasure", "bonus": {"scout": 1}, "desc": "+1 scouting radius"},
	"seers_spyglass": {"name": "Dr. Dee's Scrying Mirror", "slot": "misc", "tier": "minor", "bonus": {"scout": 2}, "desc": "+2 scouting radius"},
	# morale, luck and economy
	"cape_of_courage": {"name": "Cape of Courage", "slot": "cape", "tier": "minor", "bonus": {"morale": 1}, "desc": "+1 Morale"},
	"clover_of_fortune": {"name": "Clover of Fortune", "slot": "misc", "tier": "minor", "bonus": {"luck": 1}, "desc": "+1 Luck"},
	"signet_of_coin": {"name": "Signet of Coin", "slot": "ring", "tier": "minor", "bonus": {"gold_day": 250}, "desc": "+250 gold each day"},
	"bottomless_purse": {"name": "The Templar Treasure", "slot": "misc", "tier": "major", "bonus": {"gold_day": 750}, "desc": "+750 gold each day"},
	"banner_of_the_muster": {"name": "Banner of the Muster", "slot": "misc", "tier": "relic", "bonus": {"growth1": 3}, "desc": "+3 weekly growth of first-level creatures in all your towns"},
	# set pieces (they merge into the combinations below)
	"dragonbone_blade": {"name": "Ascalon", "slot": "weapon", "tier": "major", "bonus": {"attack": 4}, "desc": "+4 Attack", "set": "dragonheart_arms"},
	"dragonscale_shield": {"name": "Dragonscale Shield", "slot": "shield", "tier": "major", "bonus": {"defense": 4}, "desc": "+4 Defense", "set": "dragonheart_arms"},
	"dragonskull_helm": {"name": "Dragonskull Helm", "slot": "head", "tier": "major", "bonus": {"attack": 2, "defense": 2}, "desc": "+2 Attack, +2 Defense", "set": "dragonheart_arms"},
	"bone_crown": {"name": "Coronet of the Count", "slot": "head", "tier": "minor", "bonus": {"knowledge": 2}, "desc": "+2 Knowledge", "set": "mantle_of_the_lich_king"},
	"gravecloak": {"name": "Cloak of Saint-Germain", "slot": "cape", "tier": "major", "bonus": {"necromancy": 10}, "desc": "+10% Necromancy", "set": "mantle_of_the_lich_king"},
	"phylactery_of_ages": {"name": "Elixir of Life", "slot": "misc", "tier": "major", "bonus": {"power": 2}, "desc": "+2 Spell Power", "set": "mantle_of_the_lich_king"},
	"sun_pendant": {"name": "Cross of the Temple", "slot": "neck", "tier": "minor", "bonus": {"morale": 1}, "desc": "+1 Morale", "set": "seraphs_covenant"},
	"seraphs_feather": {"name": "The Holy Grail", "slot": "misc", "tier": "minor", "bonus": {"luck": 1}, "desc": "+1 Luck", "set": "seraphs_covenant"},
	"sunsteel_cuirass": {"name": "Mantle of the Temple", "slot": "torso", "tier": "major", "bonus": {"defense": 3, "morale": 1}, "desc": "+3 Defense, +1 Morale", "set": "seraphs_covenant"},
	# combinations
	"dragonheart_arms": {"name": "Arms of Saint George", "slot": "weapon", "tier": "combo",
		"parts": ["dragonbone_blade", "dragonscale_shield", "dragonskull_helm"],
		"bonus": {"attack": 8, "defense": 8}, "flags": {"immune_school": ["fire"]},
		"desc": "+8 Attack, +8 Defense; the army takes no damage from Fire spells"},
	"mantle_of_the_lich_king": {"name": "The Count's Immortality", "slot": "cape", "tier": "combo",
		"parts": ["bone_crown", "gravecloak", "phylactery_of_ages"],
		"bonus": {"power": 3, "knowledge": 3, "necromancy": 25}, "flags": {"raise": ["zombie"]},
		"desc": "+3 Spell Power, +3 Knowledge, +25% Necromancy; Necromancy raises Zombies instead of Skeletons"},
	"seraphs_covenant": {"name": "The Grail Hallows", "slot": "torso", "tier": "combo",
		"parts": ["sun_pendant", "seraphs_feather", "sunsteel_cuirass"],
		"bonus": {"morale": 3, "luck": 2, "defense": 3}, "flags": {"immune_spells": ["curse", "weakness"]},
		"desc": "+3 Morale, +2 Luck, +3 Defense; the army is immune to Curse and Weakness"},
}
## The tiers with their names and socket colours (hero screen, hover panels).
const ARTIFACT_TIERS := {"treasure": ["Treasure", Color(0.66, 0.36, 0.2)], "minor": ["Minor", Color(0.8, 0.82, 0.86)],
	"major": ["Major", Color(0.98, 0.8, 0.3)], "relic": ["Relic", Color(0.95, 0.35, 0.3)],
	"combo": ["Combination", Color(0.75, 0.5, 1.0)]}

## Artifacts found loose of a tier (set pieces are placed as sets; combinations are never found whole).
static func artifacts_of(tier: String) -> Array:
	return ARTIFACTS.keys().filter(func(a): return ARTIFACTS[a]["tier"] == tier and not ARTIFACTS[a].has("set"))

## The combination artifacts.
static func combinations() -> Array:
	return ARTIFACTS.keys().filter(func(a): return ARTIFACTS[a].has("parts"))

## Where a hero wears artifacts (the classic paper-doll) and how many of each; the rest go into the backpack,
## where they give nothing.
const ARTIFACT_SLOTS := {"head": 1, "cape": 1, "neck": 1, "weapon": 1, "shield": 1, "torso": 1, "ring": 2, "feet": 1,
	"misc": 5}

# ---------------------------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------------------------
## The New Game list: a fixed map (seed, size, rivals) with its victory and loss conditions; "random" lets the
## player pick the size and the rivals, a new land each time.
const SCENARIOS := [
	{"id": "shattered_crown", "name": "The Shattered Crown", "size": 48, "opponents": 1, "seed": 7301,
		"desc": "The crown of the old kings was forged from a star that fell from the sky, and whoever wore it ruled. Now it lies in shards, and two orders claim it. Raise your banners and drive your rival from the land.",
		"victory": {"type": "conquer"}, "loss": {"type": "standard"}},
	{"id": "border_skirmish", "name": "Border Skirmish", "size": 36, "opponents": 1, "seed": 4410,
		"desc": "A rival order has raised a house just across the border. Seize it before its walls grow tall.",
		"victory": {"type": "capture"}, "loss": {"type": "standard"}},
	{"id": "old_kings_gold", "name": "Gold of the Old Kings", "size": 48, "opponents": 2, "seed": 9127,
		"desc": "The lost treasure of the Temple lies scattered across these hills. Whoever gathers enough of it can buy the loyalty of the whole realm.",
		"victory": {"type": "gold", "amount": 60000}, "loss": {"type": "standard"}},
	{"id": "last_champion", "name": "The Last Champion", "size": 48, "opponents": 2, "seed": 5583,
		"desc": "Your hero is the last of a secret order of champions. Two rivals hunt you; should your hero fall, the order and its secret die with them.",
		"victory": {"type": "conquer"}, "loss": {"type": "hero"}},
	{"id": "before_the_thaw", "name": "Before the Thaw", "size": 64, "opponents": 3, "seed": 2246,
		"desc": "Three hidden masters gather while the passes are frozen. Break them all before the snows melt and their hosts join together.",
		"victory": {"type": "conquer"}, "loss": {"type": "days", "days": 112}},
	{"id": "random", "name": "Random Map", "random": true,
		"desc": "A new land every time: choose its size and how many rivals you face.",
		"victory": {"type": "conquer"}, "loss": {"type": "standard"}},
]

static func scenario(id: String) -> Dictionary:
	for s in SCENARIOS:
		if s["id"] == id:
			return s
	return SCENARIOS[0]

static func victory_text(v: Dictionary) -> String:
	match v.get("type", "conquer"):
		"capture": return "Capture an enemy town"
		"gold": return "Amass %d gold" % int(v.get("amount", 0))
	return "Defeat all enemies"

static func loss_text(l: Dictionary, townless := 0) -> String:
	var also := ", or %d days without a town" % townless if townless > 0 else ""
	match l.get("type", "standard"):
		"hero": return "Lose your starting hero" + also
		"days": return "Time runs out (month %d ends)" % (int(l.get("days", 112)) / 28) + also
	return ("Lose all your towns and heroes" + also) if townless <= 0 else "Lose all your heroes, or %d days without a town" % townless

## Starting bonus for the player's first hero (as the classics: gold, an artifact or resources).
const START_BONUSES := {"gold": ["Gold", "+2500 gold"], "artifact": ["Artifact", "A random artifact"],
	"resource": ["Resources", "+10 wood and ore"]}
## The New Game "random artifact" bonus: a minor one.
const BONUS_ARTIFACTS := ["sword_of_valor", "shield_of_dawn", "helm_of_wisdom", "orb_of_power", "pendant_of_clarity",
	"clover_of_fortune", "cape_of_courage", "amulet_of_insight", "breastplate_of_ironbark", "seers_spyglass", "signet_of_coin"]

# ---------------------------------------------------------------------------------------------
# Adventure map
# ---------------------------------------------------------------------------------------------
const TERRAINS := {
	"grass": {"name": "Grass", "move_cost": 100},
	"dirt": {"name": "Dirt", "move_cost": 100},
	"sand": {"name": "Sand", "move_cost": 150},
	"snow": {"name": "Snow", "move_cost": 150},
	"swamp": {"name": "Swamp", "move_cost": 175},
	"water": {"name": "Water", "move_cost": -1},
	"road": {"name": "Road", "move_cost": 50},
}

const MINES := {
	"gold_mine": {"name": "Gold Mine", "resource": "gold", "amount": 1000},
	"sawmill": {"name": "Sawmill", "resource": "wood", "amount": 2},
	"ore_mine": {"name": "Ore Pit", "resource": "ore", "amount": 2},
	"crystal_cavern": {"name": "Crystal Cavern", "resource": "crystal", "amount": 1},
	"gem_pond": {"name": "Gem Pond", "resource": "gems", "amount": 1},
	"alchemist_lab": {"name": "Alchemist's Lab", "resource": "mercury", "amount": 1},
	"sulfur_dune": {"name": "Sulfur Dune", "resource": "sulfur", "amount": 1},
}

const XP_LEVELS := [0, 1000, 2000, 3200, 4600, 6200, 8000, 10000, 12200, 14700, 17500, 20600, 24320, 28784, 34140, 40567]

## A damage range as the classic shows it: "2-3", or one number when it is fixed ("50").
static func dmg_text(lo: int, hi: int) -> String:
	return str(lo) if lo == hi else "%d-%d" % [lo, hi]

static func creature(id: String) -> Dictionary:
	return CREATURES.get(id, {})

static func faction_creature(faction: String, tier: int) -> String:
	return FACTIONS[faction]["creatures"][tier - 1]

static func dwelling_name(faction: String, tier: int, upgraded := false) -> String:
	return ("Upg. " if upgraded else "") + FACTIONS[faction]["dwelling_names"][tier - 1]

## The upgraded creature of a base one ("" when it has none: already upgraded, or no upgrade exists).
static func upgrade_of_base(cid: String) -> String:
	var c: Dictionary = CREATURES.get(cid, {})
	if c.is_empty() or c.has("upgrade_of"):
		return ""
	if FACTIONS.has(c.get("faction", "")):
		return FACTIONS[c["faction"]].get("upgrades", [])[c["tier"] - 1]
	for u in CREATURES:  # (a neutral with an upgrade: the Giant's Titan, the Red Dragon's Black Dragon)
		if CREATURES[u].get("upgrade_of", "") == cid:
			return u
	return ""

## A creature's words for the hover panels: its abilities, then what it hates and the spells it shrugs off.
static func ability_words(cid: String) -> Array:
	var c: Dictionary = CREATURES.get(cid, {})
	var out: Array = c.get("abilities", []).map(func(a): return ABILITY_TEXT.get(a, a))
	for h in c.get("hates", []):
		out.append("Hates %s (+50%% dmg)" % CREATURES[h]["plural"])
	if c.get("spell_immunity", 0) >= 5:
		out.append("Immune to all spells")
	elif c.get("spell_immunity", 0) > 0:
		out.append("Immune to spells of level 1-%d" % c["spell_immunity"])
	return out

## The base creature of an upgraded one (itself for a base creature): sounds and attack effects follow it.
static func base_of(cid: String) -> String:
	return CREATURES.get(cid, {}).get("upgrade_of", cid)

static func building_name(faction: String, id: String) -> String:
	var b: Dictionary = BUILDINGS[id]
	if b.has("dwelling_tier"):
		return dwelling_name(faction, b["dwelling_tier"], b.has("replaces"))
	return b["name"]
