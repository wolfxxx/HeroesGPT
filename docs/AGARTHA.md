# Agartha (HoMM3's Dungeon)

Status: **built** (session68, 2026-10-26). The user chose "deeper theming" (Troglodytes renamed Morlocks after H. G.
Wells's underground folk, Beholders renamed Watchers; the rest keep HoMM3's names), "add Subterranean" (HoMM3's own
cave-floor terrain on the surface map) and "build it all". The setting's lines apply (`docs/SETTING.md`): the Hollow
Earth and Agartha as the old legends and novels tell them (Halley, Symmes, Verne, Holberg, The Smoky God, Mizora).
None of the occult-Nazi Hollow Earth lore: no "Vril", no black sun, no sun wheel. The inner sun is always a bright
golden orb, and the banners carry an invented device (a small bronze dragon's claw on violet).

## In one paragraph

Through the openings at the poles, and down the crater of Sneffels, lies the world inside the world: a vast cavern
under a small golden inner sun, giant mushrooms, crystal-veined cliffs and a buried sea. Its kingdom is HoMM3's
Dungeon in everything the rules touch: the same seven tiers, numbers, abilities, buildings and costs, a Mage Guild to
level 5, the Ballista at the Blacksmith, Subterranean its native ground. The names of two creatures, the town names,
the heroes and the look are its own.

## Creatures (HoMM3's numbers)

| Tier | Base / upgrade | HoMM3 | Abilities |
|---|---|---|---|
| 1 | Morlock / Infernal Morlock | Troglodyte / Infernal Troglodyte | immune to Blind and stone gaze |
| 2 | Harpy / Harpy Hag | Harpy / Harpy Hag | flying; strike and return (back to where it started); the Hag: no enemy retaliation |
| 3 | Watcher / Evil Eye | Beholder / Evil Eye | shoot (12 / 24 shots); no melee penalty |
| 4 | Medusa / Medusa Queen | Medusa / Medusa Queen | shoot (4 / 8 shots); no melee penalty; stone gaze; large |
| 5 | Minotaur / Minotaur King | Minotaur / Minotaur King | morale always at least +1 |
| 6 | Manticore / Scorpicore | Manticore / Scorpicore | flying; large; the Scorpicore: paralyzing venom |
| 7 | Red Dragon / Black Dragon | Red Dragon / Black Dragon | (already in the game: flying, breath, spell immunity, the Black Dragon's hatred of Titans) |

**Stone gaze** (HoMM3): one in five melee strikes, retaliations too, that the target survives turns it to stone for
three rounds. Stone cannot act or strike back, takes half damage, and wakes when struck. Morlocks and war machines are
spared. **Paralyzing venom**: one in five melee strikes paralyzes the target for three rounds. A paralyzed stack
loses its turns and wakes when struck, striking back at a quarter of its damage; Cure ends it. War machines and Black
Dragons are spared. The Watchers' look keeps clear of D&D's beholder: one great eye in a floating orb, no eye stalks.

## The town

Dwellings: Warren, Harpy Loft, Pillar of Eyes, Chapel of Stilled Voices, Labyrinth, Manticore Lair, Dragon Cave (after
the third Mage Guild level, as HoMM3). The Blacksmith sells the Ballista. Specials, as HoMM3:
- **Mana Vortex** (1000 gold, after the Mage Guild): once a week, the first hero to visit has its spell points
  restored, then doubled.
- **Portal of Summoning** (2500 gold, 5 ore, after the Mage Guild): each week it calls the creatures of one of the
  owner's map dwellings, picked at random. The same creature as last week adds a week's growth; another replaces
  what was waiting. They are recruited in the town (click the Portal).
- **Battle Scholar Academy** (1000 gold, 5 wood, 5 ore): +1000 experience, once, to each hero who visits.

Not built, as with the Illuminated: HoMM3's Artifact Merchants (the game buys no artifacts), the Mushroom Rings (no
faction has horde buildings) and the Grail building. Town names: Agartha, Symzonia (Symmes's 1820 novel of the inner
world), Mizora (Mary E. Bradley Lane's 1880s kingdom inside the pole), Nazar (Holberg's inner planet) and Sneffels
(the Icelandic crater where Verne's travellers went down).

## Heroes (from legend and the old novels)

Classes: **Overlord** (might) and **Warlock** (magic), HoMM3's names.

| Hero | Class | Specialty |
|---|---|---|
| John Cleves Symmes (captain, "Symmes's Holes" at the poles, 1818) | Overlord | Offense |
| Olaf Jansen (the Norse sailor of *The Smoky God*, 1908) | Overlord | Logistics |
| Niels Klim (Holberg's student who fell into the inner world and was its emperor, 1741) | Overlord | Leadership |
| Edmond Halley (the astronomer of the hollow, inner-lit shells, 1692) | Warlock | Wisdom |
| Arne Saknussemm (Verne's Icelandic alchemist who went down first, 1864) | Warlock | Sorcery |
| Vera Zarovitch (the traveller to Mizora, 1880) | Warlock | Luck |

## Subterranean ground

HoMM3's cave floor, as an eighth terrain on the surface map (no underground map level). It has the normal movement
cost (100) and appears only in Agartha's zones, so seeded maps without Agartha are unchanged. Its woods are giant
mushrooms and stalagmites; its decor is glowing caps, crystals, moss, lava vents and bones. Its battlefield is a
cavern floor under the inner sun with stalagmites, mushrooms, crystals and basalt spires as obstacles. The map plays
the darker adventure music there.

## The look

Dark violet-black basalt and obsidian, dark bronze, violet roofs, amber lamplight, glowing violet and pale-teal
crystals, giant mushrooms. The town screen stands in the Order of the Dragon's layout with every building painted
anew (`tools/art/new_faction_town.py`), and the Portal of Summoning has a place of its own at the front right. The
siege is the Order's walls restyled in violet basalt on a cavern floor (`siege_levels_paint.py restyle dungeon`).
