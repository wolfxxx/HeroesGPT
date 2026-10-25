# The Illuminated (HoMM3's Tower)

Status: **built** (session67, 2026-10-25). The user chose "light theming" (two creatures renamed, the rest HoMM3's
names in the order's look) and "build it all" in one go. The setting's lines apply (`docs/SETTING.md`): the
Illuminated are the historical Bavarian order of 1776, the Rosicrucians and the alchemists, as their legends tell
them: hidden sages, not a modern "they rule the world" theory. No living people; no religious symbols on their
buildings (their sign is a small gold eye in a triangle on blue banners).

## In one paragraph

High in snowy mountains, above the clouds, an order of alchemists and sages keeps the knowledge the old kings burned:
how to grow life in a flask, how to wake stone, how to bind a djinn to a ring. They are HoMM3's Tower in everything
the rules touch: the same seven tiers, numbers, abilities, buildings and costs, a Mage Guild to level 5, snow their
native ground. Only the names of two creatures, the town names, the heroes and the look are their own.

## Creatures (HoMM3's numbers)

| Tier | Base / upgrade | HoMM3 | Abilities |
|---|---|---|---|
| 1 | Homunculus / Master Homunculus | Gremlin / Master Gremlin | the Master throws flasks (8 shots) |
| 2 | Gargoyle / Obsidian Gargoyle | Stone / Obsidian Gargoyle | flying; not alive |
| 3 | Stone Golem / Iron Golem | Stone / Iron Golem | spells do 50% / 25% damage; not alive (the golem of Prague) |
| 4 | Magus / Arch Magus | Mage / Arch Mage | shoot; no wall penalty; their hero's spells cost 2 less |
| 5 | Genie / Master Genie | Genie / Master Genie | flying; the Master casts a random helpful spell on an ally, three times a battle (Solomon's djinn) |
| 6 | Naga / Naga Queen | Naga / Naga Queen | no enemy retaliation |
| 7 | Giant / Titan | Giant / Titan | immune to mind spells; the Titan shoots lightning with no melee penalty and hates Black Dragons |

"Not alive" (HoMM3's non-living): no morale, immune to mind spells, untouched by Death Ripple, a Lich's cloud, life
drain and disease, and no Skeletons rise from them. Not modelled: the Genie's hatred of Efreeti (there are none).
The Master Genie's spells are Bless, Haste, Shield, Stone Skin and Cure (when the target is cursed, slowed or weakened),
for three rounds: the game has fewer spells than HoMM3's genie list.

## The town

Dwellings: Workshop, Parapet, Golem Factory, Mage Tower (after the Mage Guild), Altar of Wishes, Golden Pavilion,
Cloud Temple. Blacksmith: the Ammo Cart. Specials: the **Library** (one more spell of each Mage Guild level) and the
**Wall of Knowledge** (+1 Knowledge once to each hero who visits). HoMM3's Lookout Tower, Artifact Merchants and
Skyship are not built (the game has no buying of artifacts and no Grail yet). Town names: Ingolstadt (where the
Bavarian order was founded), Prague (Rudolf II's alchemists and the golem), Kassel and Tübingen (the Rosicrucian
manifestos), Uraniborg (Tycho Brahe's island observatory).

## Heroes (all from legend)

Classes: **Alchemist** (might) and **Wizard** (magic).

| Hero | Class | Specialty |
|---|---|---|
| Nicolas Flamel | Alchemist | Wisdom |
| Perenelle Flamel | Alchemist | Armorer |
| Paracelsus | Alchemist | Archery |
| Christian Rosenkreuz | Wizard | Wisdom |
| Adam Weishaupt | Wizard | Sorcery |
| Cagliostro | Wizard | Luck |

## The look

White marble and pale stone, gold domes and trim, deep blue roofs and banners, glowing pale-blue crystals, brass
instruments and glass flasks, light snow. The town screen stands in the Order of the Dragon's layout, every building
painted anew (`tools/art/new_faction_town.py`); the siege is the Temple's walls restyled in marble and snow
(`siege_levels_paint.py restyle tower`).
