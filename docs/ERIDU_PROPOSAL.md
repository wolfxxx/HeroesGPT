# Eridu, the faction of the Anunnaki — proposal (awaiting the user's approval)

Status: **proposal, nothing built** (2026-10-24; revised the same day around the Sumerian / Nibiru naming theme the
user chose, replacing the first draft's "Starfall"). It is the user's idea and a deliberate deviation from HoMM3,
which has no such town. Everything else in the game stays true to HoMM3; this faction plugs into the same frame as
Haven and Necropolis so that the rules, the AI, the artifacts and multiplayer keep working unchanged.

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

## Names

| What | Name | Meaning |
|---|---|---|
| Faction (town type, as Haven and Necropolis) | **Eridu** | the first Anunnaki settlement on Earth, "home in the faraway built" |
| Its people | **the Anunnaki** | "those who from heaven to earth came" |
| Where they came from | Nibiru | their home world, in the lore |
| The crashed ship at the town's heart | the Shem of Alalu | *shem*, *mu*: the "sky chamber" |
| Their "spellbooks" | the Me | crystal tablets of all knowledge |

Other faction names from the same theme, if Eridu doesn't fit: **Abzu** (their deep waters and mines), **Duranki**
("bond of heaven and earth"), **Nibiru**, or the people's name **Anunnaki** for the faction itself (question 1).

## The look (what decides whether it works)

HoMM3 itself shows the risk. For the Armageddon's Blade expansion its makers planned the **Forge**, a technology town
with cyborgs and guns. Fans protested and it was replaced by Conflux. What they objected to was the look (chrome,
guns and robots beside painted castles and griffins), not strangeness. This theme avoids it naturally:

- **Ancient Mesopotamia first.** Ziggurats, mud-brick and blue-glazed brick with gold reliefs (the Ishtar Gate's
  lions, bulls and dragons), lapis lazuli, bronze, horned crowns, fish-cloaks, palms and reeds, winged sun-discs.
- **Star-science as a glow underneath.** The crashed hull shines like polished metal between the reeds; the Me
  tablets, Sharur and the crowns glow with cold crystal light. Nothing that looks like a modern gun, robot or car.
- **Painted like everything else.** The same pipeline (Blender library models, painted over by the image model)
  and the same warm painted lighting.
- **Seen through ancient eyes.** Names and texts speak of gods, sky-chariots and sages, never "laser", "robot" or
  "alien".

The town: Alalu's ship lies half-sunk in a marsh, its shining hull plates jutting from the reeds. Eridu is built over
and around it: canals, a stepped ziggurat rising over the wreck, glazed-blue gates, gardens of palms.

## How it fits the existing frame

| | Haven | Necropolis | Eridu |
|---|---|---|---|
| Creatures | 7 tiers + upgrades | 7 tiers + upgrades | 7 tiers + upgrades |
| Hero classes | Knight / Cleric | Death Knight / Necromancer | Lugal / Keeper |
| Faction skill | — | Necromancy | Shaping (below) |
| Native terrain | grass | dirt | swamp (Alalu came down in the marshes; the terrain already exists) |
| Rare resource of its top creature | gems | mercury | crystal (the Me are crystal) |
| Blacksmith sells | Ballista | First Aid Tent | Ammo Cart |
| Specials | Stables, Brotherhood of the Sword | Necromancy Amplifier, Skeleton Transformer | House of the Me, Dur-An-Ki |
| Spells | Mage Guild 1–4 | Mage Guild 1–4 | Ziggurat 1–4 (a terrace per level): the same spells |

All other buildings (halls, fort/citadel/castle, tavern, marketplace, blacksmith, dwellings and their upgrades) keep
their rules and costs; only their names and pictures are Eridu's.

**Identity:** fast, fragile and tricky. Strong shooters and fliers, two constructs that know no fear or joy, and
effects nobody else has. The weakness: low health in the lower tiers, so a long slugging match in melee favours
Haven and Necropolis.

## The creatures

Every one is a being of the myths, as the Anunnaki made or brought them. First-pass numbers, set against Haven and
Necropolis tier by tier (costs, growth and the strength budget of each tier). They are a starting point: the AI
tournament tools measure the faction against the other two before anything is final (see Balance).

| Tier | Creature (upgrade) | Att | Def | Damage | HP | Speed | Growth | Cost | Abilities |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **Lulu** | 4 | 4 | 1–3 | 8 | 5 | 14 | 60 | — |
| 1 | Adamu | 5 | 5 | 1–3 | 9 | 6 | 14 | 75 | — |
| 2 | **Igigi** | 5 | 4 | 2–3 | 12 | 4 | 9 | 100 | shooter (10 shots) |
| 2 | Igigi Skywatcher | 7 | 5 | 2–4 | 12 | 6 | 9 | 150 | shooter (20 shots), no melee penalty |
| 3 | **Scorpion Man** (girtablilu) | 8 | 6 | 3–6 | 22 | 7 | 7 | 200 | venom (−2 Defense to the struck stack) |
| 3 | Scorpion Guardian | 9 | 7 | 3–6 | 24 | 9 | 7 | 240 | venom, two retaliations |
| 4 | **Sharur** | 10 | 11 | 6–8 | 35 | 7 | 4 | 340 | flying, construct, deflector (−50% damage from shooters) |
| 4 | Shargaz | 11 | 12 | 7–9 | 40 | 9 | 4 | 450 | flying, construct, deflector, beam (hits the stack behind its target too) |
| 5 | **Apkallu** | 12 | 9 | 9–13 | 30 | 6 | 3 | 500 | shooter (12 shots) |
| 5 | Abgal | 13 | 10 | 10–14 | 35 | 7 | 3 | 600 | shooter (24 shots), dispel (its shot removes good spells from the target) |
| 6 | **Lamassu** | 16 | 16 | 15–25 | 110 | 6 | 2 | 1100 | large, construct, sweep (strikes every adjacent enemy) |
| 6 | Shedu | 18 | 18 | 20–30 | 120 | 7 | 2 | 1400 | large, construct, sweep |
| 7 | **Anzu** | 19 | 19 | 30–45 | 180 | 10 | 1 | 2500 + 1 crystal | large, flying, beam (a storm breath) |
| 7 | Imdugud | 24 | 22 | 35–50 | 230 | 14 | 1 | 4000 + 2 crystal | large, flying, beam, fear |

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

The dwellings, by tier: Bit-Shimti (the "house where the wind of life is breathed in", where the workers are made),
Skywatch, Gate of Mashu, Armory of Ninurta, House of the Sages, Gate of the Guardians, Anzu's Eyrie (each also seen
on the adventure map like the other factions' dwellings).

### New abilities (the code they need)

Existing abilities cover "two retaliations", "shooter", "flying", "large" and "fear". New:

| Ability | Rule | Closest HoMM3 precedent |
|---|---|---|
| construct | no morale (never good or bad); not living: Death Ripple passes it, Resurrection cannot bring it back, Necromancy and Shaping cannot take it | Golems and elementals |
| no melee penalty | a shooter that is not halved in melee | Mages, Titans |
| venom | the struck stack has −2 Defense for the battle (stacks up to −6) | Dragon Flies' and Serpent Flies' weakening |
| deflector | damage from shooters halved | Air Shield |
| beam | the attack also hits the stack directly behind the target | Dragons' breath |
| dispel | a ranged hit removes the target's good spells | Serpent Flies' dispel |
| sweep | attacks every adjacent enemy stack at once | Hydras, Cerberi |

Each also needs the battle AI to value it, a battle effect and a line in the creature panel.

## Heroes

Two classes, as every faction: **Lugal** (might: "great man", a warrior-king in a horned helm and bronze scale,
riding a winged lion) and **Keeper** (magic: a keeper of the Me in a fringed robe and horned crown, holding a glowing
crystal tablet, on the same mount). Four starting heroes, named for the figures of the myths:

| Hero | Class | Specialty | Starts with |
|---|---|---|---|
| Alalu | Lugal | Shaping (the exiled king who came first) | Shaping 1 |
| Ninurta | Lugal | Offense (the war god, master of Sharur) | Shaping 1, Offense 1 |
| Enki | Keeper | Sorcery (lord of Eridu, the Abzu and the Me) | Shaping 1, Magic Arrow, Haste |
| Ninhursag | Keeper | Knowledge (the mother who shaped the workers) | Shaping 1, Shield, Cure |

They need what the existing heroes have: a portrait each, a map figure per class (standing + four gallop frames),
a battle figure per class (idle loop + casting pose), and the map pennant.

## The faction skill: Shaping

The counterpart of Necromancy, from the myth of how the Anunnaki made their workers. After a won battle part of the
**slain living** enemies are remade as **Lulu**: Basic 10%, Advanced 20%, Expert 30% of the slain count. It follows
the same rules as Necromancy (rounding per stack, a cap by health so a dragon does not become a hundred Lulu, needs a
free slot or a Lulu stack; with only an Adamu stack, two thirds as many Adamu). It cannot take undead or
constructs, so it is weak against Necropolis and strong against Haven. It reuses `Necromancy.calculate` with another
creature and filter.

**Alternative (question 3):** "Tribute": slain enemies give gold and crystal instead of troops (the Anunnaki came for
gold). It gives the faction a different economy from Necropolis, but no army growth.

## Special buildings

- **House of the Me** (needs the Ziggurat): a visiting hero may give an artifact up to be read into new Me. It is
  gone, and the kingdom gets crystal and gold by tier (treasure: 2 crystal + 500 gold; minor: 4 + 1000; major: 6 +
  2000; relic: 10 + 4000). Combination artifacts and their parts can't be given up. This is the faction's own
  relationship with artifacts; for everyone else artifacts work exactly as now. (Question 4: crystal and gold, or a
  permanent +1 to a random primary skill for majors and relics.)
- **Dur-An-Ki**, "bond of heaven and earth" (needs the Citadel): a hero standing in the town may jump to any other
  Eridu town of the same player with a Dur-An-Ki, for all their remaining movement. This is HoMM3's own Inferno
  **Castle Gate**, so it is HoMM3-true.

## Artifacts

Unchanged, as HoMM3: any hero wears any artifact. Eridu heroes wear the same swords, rings and cloaks as everyone,
trophies of the realm. Their portraits and the hero screen need nothing new. Their own relationship with artifacts is
the House of the Me, above. (Optional later: a Tablets of Destiny relic set, the Me as artifacts, usable by anyone.
Not part of this proposal.)

## Spells: science that looks like magic

- The **Ziggurat** replaces the Mage Guild in Eridu towns: the same four levels, costs and spells, a new terrace for
  each level. A Keeper who visits a Haven Mage Guild learns spells as usual and vice versa, and shrines and scrolls
  work for everyone.
- Spell names stay as they are. (Question 7: spells cast by Eridu heroes could look different, for example Magic
  Arrow as a bolt of cold crystal light and Lightning Bolt as a blue-white arc from the sky. It is a presentation
  change only and cheap.)

## Sieges

The same siege rules: catapult, wall segments, gate, moat, keep and towers. The walls are mud-brick faced with
blue-glazed brick and gold reliefs of lions and bulls, the gate an Ishtar-style arch, the moat a canal of the marsh,
the towers stepped corner towers, the keep the ziggurat with the ship's shining hull showing through. Three siege
backgrounds (Fort, Citadel, Castle), as the other two factions.

## What it costs

| Area | Work |
|---|---|
| Creatures | 14 × (standing, attack, hit, dead, 4 move frames) + 14 portraits; three of them large |
| Heroes | 4 portraits, 2 map figures with gallop frames, 2 battle figures with idle and cast |
| Town | town screen: background + about 28 building pictures, layout file |
| Map | 7 dwellings, the town on the map (swamp terrain already exists) |
| Sieges | 3 siege backgrounds with walls, gate, towers and wrecks |
| Sound and music | a town theme; creature attack and death sounds; beam, sweep and venom effects |
| Rules | 7 abilities, Shaping, House of the Me, Dur-An-Ki, hero classes |
| AI | value the new abilities in battle; use Shaping, the House of the Me and Dur-An-Ki on the map |
| Tests | each ability, Shaping, the House, the gate; a faction-balance tournament |

The art is the bulk of it; the pipeline is the same one that made Haven and Necropolis.

## Balance

Before it is final, the faction plays computer-against-computer tournaments against Haven and against Necropolis
(the existing `tools/adventure_tournament.tscn`, fresh maps, seats swapped). Battles between equal-value armies
of each tier check the creatures one by one. The numbers above change until neither side wins clearly more than the
other; the result is reported with its uncertainty, as the AI rounds are.

## When

The "Faction data" step of the online plan (moving the faction checks scattered through the code into each
faction's definition) comes first: a third faction built before that would add a third branch to every one of
those places. After it, either:
- a HoMM3 faction third (proven numbers to copy; it tests the faction data model), then Eridu fourth; or
- Eridu third, which tests the data model harder because it differs most.

## Questions for the user

1. **Name:** "Eridu" for the faction (the Anunnaki as its people), or Abzu, Duranki, Nibiru, Anunnaki?
2. **Top creature:** Anzu (the lion-headed storm eagle), or the Mushussu (Marduk's serpent-dragon, on foot)?
3. **Faction skill:** Shaping (slain living enemies become Lulu), or Tribute (they become gold and crystal)?
4. **House of the Me:** crystal and gold for an artifact given up, or a permanent primary skill point for majors
   and relics?
5. **Constructs** (Sharur, Lamassu) have no morale and are not living (Death Ripple, Resurrection, Necromancy and
   Shaping skip them). Agreed?
6. **Dur-An-Ki** as HoMM3's Inferno Castle Gate. Agreed?
7. **Spell looks:** different effects for spells cast by Eridu heroes, or the same as everyone's?
8. **Order:** Eridu third, or fourth after a HoMM3 faction?
