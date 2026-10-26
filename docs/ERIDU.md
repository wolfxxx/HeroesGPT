# Eridu, the faction of the Anunnaki

Status: **built** (session68, 2026-10-26). The proposal of session67 (`docs/ERIDU_PROPOSAL.md` until now) with
the user's answers: the name Eridu, Anzu at the top, Shaping as the faction skill, the House of the Me pays crystal
and gold, constructs and Dur-An-Ki as proposed, and Eridu's heroes' spells look their own. It is the user's idea and
a deliberate deviation from HoMM3, which has no such town; everything else stays true to HoMM3, and the faction
plugs into the same frame as the other four, so the rules, the AI, the artifacts and multiplayer keep working.

The names come from Sumerian and Akkadian myth (ancient, free to use). The story borrows the "ancient astronauts"
reading of those myths popularised by Zecharia Sitchin, as an idea only; no text is taken from his books.

## The idea in one paragraph

Long ago a burning chariot fell out of the sky into the southern marshes. In it was **Alalu**, a deposed king of
distant **Nibiru**, who had stolen a sky-ship and blasted his way through the Hammered Bracelet of stars. Others of
his kind, the **Anunnaki**, followed him, looking for the gold their world needed. Around the half-sunk wreck they
raised **Eridu**, "home in the faraway built": canals, mud-brick and glazed-blue walls, a ziggurat over the hull. They
shaped servants and beasts from clay and their own essence, and ruled them with the **Me**, crystal tablets holding
every art and science. To the people of the realm they are gods, or demons. In the rules their science is the same
spellcraft every hero uses.

| What | Name | Meaning |
|---|---|---|
| Faction (id `eridu`) | **Eridu** | the first Anunnaki settlement on Earth, "home in the faraway built" |
| Its people | **the Anunnaki** | "those who from heaven to earth came" |
| Where they came from | Nibiru | their home world, in the lore |
| The crashed ship at the town's heart | the Shem of Alalu | *shem*, *mu*: the "sky chamber" |
| Their "spellbooks" | the Me | crystal tablets of all knowledge |

Town names: Eridu, Ur, Uruk, Nippur, Lagash (the oldest cities of Sumer).

## The look (what decides whether it works)

HoMM3 itself shows the risk. For the Armageddon's Blade expansion its makers planned the **Forge**, a technology town
with cyborgs and guns. Fans protested and it was replaced by Conflux. What they objected to was the look (chrome,
guns and robots beside painted castles and griffins), not strangeness. So:

- **Ancient Mesopotamia first.** Ziggurats, mud-brick and blue-glazed brick with gold reliefs (the Ishtar Gate's
  lions, bulls and dragons), lapis lazuli, bronze, horned crowns, fish-cloaks, palms and reeds, winged discs.
- **Star-science as a glow underneath.** The crashed hull shines like polished metal between the reeds; the Me
  tablets, Sharur and the crowns glow with cold crystal light. Nothing that looks like a modern gun, robot or car.
- **Painted like everything else**, with the same pipeline and warm painted lighting.
- **Seen through ancient eyes.** Names and texts speak of gods, sky-chariots and sages, never "laser", "robot" or
  "alien".

The town: Alalu's ship lies half-sunk in a marsh, its shining hull plates jutting from the reeds. Eridu is built over
and around it: canals, a stepped ziggurat rising over the wreck, glazed-blue gates, gardens of palms.

## How it fits the frame

| | Eridu |
|---|---|
| Hero classes | Lugal (might) / Keeper (magic) |
| Faction skill | Shaping (its Necromancy, below) |
| Native terrain | swamp (Alalu came down in the marshes) |
| Rare resource of its top creature | crystal (the Me are crystal) |
| Blacksmith sells | Ammo Cart |
| Specials | House of the Me, Dur-An-Ki |
| Spells | the Ziggurat (the Mage Guild under its own name), levels 1-4: the same spells |

All other buildings (halls, fort/citadel/castle, tavern, marketplace, blacksmith, dwellings and their upgrades) keep
their rules and costs; only their names and pictures are Eridu's.

**Identity:** fast, fragile and tricky. Strong shooters and fliers, two constructs that know no fear or joy, and
effects nobody else has. The weakness: low health in the lower tiers, so a long slugging match in melee favours the
others.

## The creatures

The proposal's first-pass numbers, tuned with the tier battles of `tools/faction_balance.tscn` (see Balance): Lulu
and Adamu lost a point of Defense and of health, the Igigi two health, the Skywatcher a point of Attack and its top
damage, the Apkallu gained 4 health, the Lamassu and Shedu were cut, the Anzu and Imdugud raised.

| Tier | Creature (upgrade) | Att | Def | Damage | HP | Speed | Growth | Cost | Abilities |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **Lulu** | 4 | 3 | 1–3 | 7 | 5 | 14 | 60 | — |
| 1 | Adamu | 5 | 4 | 1–3 | 8 | 6 | 14 | 75 | — |
| 2 | **Igigi** | 5 | 4 | 2–3 | 10 | 4 | 9 | 100 | shooter (10 shots) |
| 2 | Igigi Skywatcher | 6 | 5 | 2–3 | 12 | 6 | 9 | 150 | shooter (20 shots), no melee penalty |
| 3 | **Scorpion Man** (girtablilu) | 8 | 6 | 3–6 | 22 | 7 | 7 | 200 | venom |
| 3 | Scorpion Guardian | 9 | 7 | 3–6 | 24 | 9 | 7 | 240 | venom, two retaliations |
| 4 | **Sharur** | 10 | 11 | 6–8 | 35 | 7 | 4 | 340 | flying, construct, deflector |
| 4 | Shargaz | 11 | 12 | 7–9 | 40 | 9 | 4 | 450 | flying, construct, deflector, beam |
| 5 | **Apkallu** | 12 | 9 | 9–13 | 34 | 6 | 3 | 500 | shooter (12 shots) |
| 5 | Abgal | 13 | 10 | 10–14 | 35 | 7 | 3 | 600 | shooter (24 shots), dispel |
| 6 | **Lamassu** | 15 | 15 | 15–25 | 100 | 6 | 2 | 1100 | large, construct, sweep |
| 6 | Shedu | 17 | 17 | 20–25 | 110 | 7 | 2 | 1400 | large, construct, sweep |
| 7 | **Anzu** | 20 | 20 | 35–45 | 200 | 11 | 1 | 2500 + 1 crystal | large, flying, beam (a storm breath) |
| 7 | Imdugud | 26 | 24 | 40–50 | 280 | 15 | 1 | 4000 + 2 crystal | large, flying, beam, fear |

Who they are:
- **Lulu / Adamu:** the "primitive workers" the Anunnaki shaped from clay and their own essence: lean, tattooed
  men in kilts with bronze tools and spears. Adamu is the perfected first of them.
- **Igigi:** the sky-watchers who manned the heavens, in tall caps and fringed robes, shooting bolts of light from
  short star-bows.
- **Scorpion Men:** the guardians of the Mashu mountain gate in the Gilgamesh epic: a man above, a scorpion below,
  with a venomous tail.
- **Sharur / Shargaz:** Ninurta's weapons in the myths, which fly and speak on their own: a winged mace-head of
  bronze and glowing crystal that hovers and smashes.
- **Apkallu / Abgal:** the seven sages who brought the arts to mankind, in fish-cloaks or eagle heads, with a cone
  and a bucket; their light undoes spells.
- **Lamassu / Shedu:** the winged, human-headed bull colossi of the palace gates, here stone made to walk.
- **Anzu / Imdugud:** the lion-headed storm eagle who stole the Tablets of Destiny; its wings raise whirlwinds.

Dwellings, by tier: Bit-Shimti (the "house where the wind of life is breathed in", where the workers are made),
Skywatch, Gate of Mashu, Armory of Ninurta, House of the Sages, Gate of the Guardians, Anzu's Eyrie.

### Abilities

| Ability | Rule | In the code |
|---|---|---|
| construct | no morale; not living (immune to mind spells; Death Ripple, Necromancy and Shaping pass it by) | `unliving`, as the Golems |
| no melee penalty | a shooter not halved in melee | `no_melee_penalty` (exists) |
| beam | the attack also hits the stack directly behind the target | `breath` (exists: the Dragons') |
| fear, two retaliations, large, flying | as now | exist |
| venom | each melee strike, a retaliation too, that the target survives takes 2 from its Defense for the battle, down to -6; living targets only; Cure ends it | `venom` (new) |
| deflector | damage from shooters, towers and the Ballista halved (as an Air Shield always on) | `deflector` (new) |
| dispel | a shot that the target survives removes its helpful spells (Bless, Haste, Shield, Stone Skin) | `dispel` (new) |
| sweep | strikes every adjacent enemy stack at once; only the one attacked strikes back (as HoMM3's Hydras) | `sweep` (new) |

## Heroes

**Lugal** (might: "great man", a warrior-king in a horned helm and bronze scale) and **Keeper** (magic: a keeper of
the Me in a fringed robe and horned crown, holding a glowing crystal tablet). They ride horses in lapis-blue
caparisons, as every hero (the proposal's winged lions would need a new mount through the whole figure pipeline). Six heroes, as every faction, all with
Basic Shaping, as the Order's heroes have Necromancy:

| Hero | Class | Specialty | Starts with |
|---|---|---|---|
| Alalu (the exiled king who came first) | Lugal | Shaping | Shaping 1 |
| Ninurta (the war god, master of Sharur) | Lugal | Offense | Shaping 1, Offense 1 |
| Enlil (lord of the wind, who gave the commands) | Lugal | Leadership | Shaping 1, Leadership 1 |
| Enki (lord of Eridu, the Abzu and the Me) | Keeper | Sorcery | Shaping 1; Magic Arrow, Haste |
| Ninhursag (the mother who shaped the workers) | Keeper | Knowledge | Shaping 1; Shield, Cure |
| Inanna (who carried the Me away from Eridu to Uruk) | Keeper | Wisdom | Shaping 1, Wisdom 1; Bless, Slow |

## The faction skill: Shaping

After a won battle part of the **slain living** enemies are remade as **Lulu**: Basic 10%, Advanced 20%, Expert 30%
of the slain. The same rules as Necromancy (rounding per stack, a cap by health so a dragon does not become a hundred
Lulu, a free slot or a Lulu stack needed; with only an Adamu stack, two thirds as many Adamu). Undead and constructs
cannot be shaped, so it is weak against the Order of the Dragon and strong against the Temple. Like Necromancy, any
hero may learn it at a level-up. It runs through `Necromancy.calculate` with another creature and filter.

## Special buildings

- **House of the Me** (1000 gold, 5 crystal; after the Ziggurat): a hero in the town may give an artifact up to be
  read into new Me. It is gone, and the kingdom gets crystal and gold by its class: treasure 2 crystal + 500 gold,
  minor 4 + 1000, major 6 + 2000, relic 10 + 4000. Combination artifacts and their parts cannot be given up.
- **Dur-An-Ki**, "bond of heaven and earth" (10000 gold, 5 wood, 5 ore; after the Citadel): HoMM3's Inferno Castle
  Gate. The hero at the town's gate may pass at once to any other of its player's Eridu towns with a Dur-An-Ki whose
  gate is free. It costs no movement points (as HoMM3; the proposal said "all remaining movement", which HoMM3 does
  not do).

## Spells: science that looks like magic

The Ziggurat is the Mage Guild under its own name (the same four levels, costs and spells). Spells cast by an Eridu
hero look their own: Magic Arrow as cold crystal light, the lightning spells as a blue-white arc from the sky, fire
as white-gold star fire, frost as glittering crystal, the helpful spells as a golden winged glow, the harmful ones
as a deep indigo shadow (`battle/fx_<kind>_eridu.png`). Their rules are unchanged.

## The town and the sieges

The town screen stands in the Temple's layout with every building painted anew (`new_faction_town.py eridu`): the
marshes at golden evening with the fallen ship's silver hull far off among the reeds, the Ziggurat, a reed beer
house, the Ishtar-blue walls; the House of the Me and the Dur-An-Ki where the Temple has its Stables and Chapter
House. The siege is the Temple's restyled: mud brick faced with blue glazed brick and gold lions, square stepped
towers, the keep a square blue tower, a reedy canal for the moat, Igigi archers on the towers.

## Balance

`tools/faction_balance.tscn` fights each creature against the same tier of every other faction, sides swapped, no
heroes, with the battle rules and AI. The existing tournament (`adventure_tournament.tscn`) compares AI versions with
fixed factions, so it cannot measure a faction. Results after tuning (8 seeds, 896 battles each):

| | Eridu | Temple | Order | Illuminated | Agartha |
|---|---|---|---|---|---|
| equal weeks of growth (how strong in play) | 58% | 53% | 40% | 53% | 45% |
| equal AI value (how the computer values them) | 53% | 55% | 49% | 48% | 39% |

The HoMM3 factions swing as widely tier by tier (0% to 100% in single matchups), so the tool is coarse: Eridu sits
at the top of the range in play, inside it by value. The AI values matter most for the computer: its instant
battles (`AdvRules.quick_resolve`) and its choices are weighed by them.
