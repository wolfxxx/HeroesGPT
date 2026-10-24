# The setting: a secret history

Status: **approved** (2026-10-24; answers at the end), the first renames **built** (see "What changed first").
The user wants the game to lean hard on the world of conspiracy theories: Nibiru, secret societies, the Templars,
UFOs, the occult, occult Nazis as villains. This document sets the premise, the tone, the lines the setting does not
cross, and how each faction, relic and map object fits. The mechanics stay true to HoMM3 (tiers, towns, battles,
spells, artifact rules); the setting changes the names, the texts, the lore and, over time, the look.

## The premise

**Everything the whisperers said was true.** The chronicles of the realm are a cover story. Behind them, secret
orders have fought for ages over what the old kings hid.

The **Shattered Crown** of the game's title was never a king's crown. It was forged from the crystal heart of a
ship that fell from the sky, Alalu's ship (see `docs/ERIDU_PROPOSAL.md`): the Me that taught men kingship. Whoever
wore it ruled. When it shattered, its shards scattered across the world, and every secret order hunts them: the
Templars to guard them, the Order of the Dragon to use them, the Anunnaki to take back what is theirs, and the Iron Order to build
an empire with them.

This keeps the game's title and its first scenario ("two lords claim the broken crown of the old kingdom") and
gives every faction a reason to fight.

## The feel: stumbling into the depths

The user's guiding aim (2026-10-24): the game should feel like **stumbling into the depths of conspiracy theories and
old mysteries.** Every new piece is judged by one question: *does this make the player stumble deeper?*

- **It starts ordinary.** A medieval war over a broken crown, as HoMM3 opens. Then cracks show: a stone circle that
  hums, a rumour that sounds mad, a relic that shouldn't exist.
- **Layer by layer.** The strangeness deepens as the game goes on, one layer a month: **historical** mysteries (the
  Templars, the Grail, lost treasure), the **occult** (the deathless, alchemy, scrying), the **ancient** (Egypt,
  Thoth, Atlantis), the **cosmic** (the fallen star, Nibiru, the watchers). The factions follow the same descent, from
  the grounded Temple to the Anunnaki.
- **Rumours that turn out true.** Some whispers are real hints about the map; the player learns that following them
  pays.
- **Digging, not reading.** Mysteries are found and pieced together through play (HoMM3's own obelisks and puzzle map,
  reskinned as a conspiracy board and the hunt for a Shard of the Crown), not delivered as long texts.
- **Short and strange.** One or two sentences, concrete and odd ("The black obelisks cast their shadows the wrong way
  at noon."), never explaining too much.

Built so far: the weekly omens and Tavern rumours (`scripts/core/lore.gd`, below); the first Egyptian pieces (the Eye
of Horus, the Ankh of Life, the Obelisk of Thoth). Then the declassified lines (below). Then HoMM3's Pyramid near the
middle of medium and larger maps, guarded by the ushabti (HoMM3's Gold and Diamond Golems as Egyptian tomb figurines
come to life: the Gilded and Crystal Ushabti), a spell of the highest level inside. Then HoMM3's Mummies (cursing what they strike) with their neutral dwelling, the Tomb of Curses.
Planned: more Egyptian relics and map objects, the obelisk puzzle map and the
dig for a Shard of the Crown, the Illuminated as a faction, a story campaign in acts.

### Omens and rumours (built)

Each new week the astrologers' proclamation carries an **omen**, and every Tavern has the week's **rumour** (as
HoMM3's taverns do). Both come from the month's layer; about two rumours in five, when the map allows, are true hints:
where a relic lies ("They say the Cloak of Saint-Germain lies somewhere south of Rosslyn, if you can believe a
drunk.") or a mine without a master. Each month's lines are dealt from a pool shuffled once per map, so none repeats
within a month. They draw from a generator seeded by the map's seed and the week, never the shared random stream, so
seeded games play as before. New lines go in `Lore.OMENS` and `Lore.RUMOURS` (one list per layer).

### Declassified lines (built)

Every relic and every kind of map site has one strange line (`Lore.ENTRIES`), shown at the bottom of its hover panel
and its hero-screen tooltip. Until the player has held that relic or visited that kind of site, most of its words are
blacked out, as in a redacted file ("████ ████ the ███ king's tomb."); the first time, the full line comes with the
message of finding it, and from then on it reads in full. Only these lines are hidden: an artifact's effect and a
site's rules always show, as in HoMM3. Known lines are kept per player (`lore_known`, saved). The black bars are the
full-block character, drawn from a system fallback font (the game's fonts lack it).

## Tone and register

- **Pulp wonder, not "wake up".** The fun is in the secret history being true *in the game*: hidden orders, relics,
  sky-chariots, lost continents. The game never presents anything as a real-world truth. The credits say plainly
  that it is fiction.
- **A medieval and mythic surface.** The game still looks like HoMM3: knights, castles, painted monsters. Modern
  conspiracies are told in that register: UFOs are sky-chariots, the Illuminati an order of hidden sages, Bigfoot a
  beast of the wild woods.
- **Long-dead real people only, as their legends.** Historical figures dead for more than a century may appear as
  their legends tell them (Jacques de Molay, John Dee, the Count of Saint-Germain, Nicolas Flamel). No living people,
  and no one who died recently.
- **Real places as legend allows.** Rennes-le-Château, Rosslyn, Glastonbury, Gisors may name towns and map sites.

## The lines

| | What | Rule |
|---|---|---|
| **In** | Myth, legend and history over a century old: Nibiru and the Anunnaki, the Templars and the Grail, the Bavarian Illuminati, Rosicrucians, alchemists, hermetic and occult orders, Atlantis, Lemuria, Hollow Earth and Agartha, ley lines and stone circles, UFOs as sky-chariots, the Men in Black, cryptids (Bigfoot, the Yeti, the Mothman, the Jersey Devil), the fair folk | Lean in |
| **Villains only** | Occult Nazis, as pulp has used them (Indiana Jones, Hellboy) | A fictional order: the **Iron Order** (below). Never playable, never sympathetic. No real Nazi symbols, names, ranks, insignia, slogans or uniforms, and none of the symbols neo-Nazi groups use today (the swastika and its variants, SS runes, the Black Sun, the Reich eagle, "Vril", "Thule"). It must never be possible to play as them. |
| **Out** | Live modern conspiracy theories: vaccines, chemtrails, 5G, QAnon, election fraud, flat earth; anything aimed at real living people or real groups | Not in the game |
| **Out** | "A secret cabal of a people secretly rules the world" in any form, and its codes (the Protocols, "the Rothschilds", "globalists", reptilian elites, blood libel). These grew from antisemitic sources | Not in the game. Secret orders are fictional and never tied to a real people, faith or nation |
| **Care** | Real faiths and living organisations (the Church, the Freemasons) | Our orders are fictional or long gone (not the Freemasons: "Lodge", their own word, was dropped as the undead faction's name for that reason). Faiths are never the villain |

Why the "out" lines: those theories are not myths at a safe distance. They have living targets and cost real
lives, and inside a game where "the conspiracies are true", including them reads as endorsing them. They would also
split the audience and date the game.

## The factions

The two existing factions keep their rules, creatures and art; only their lore changes (names are question 2).

### Haven: the Templars

The Poor Fellow-Soldiers of Christ and the Temple of Solomon: knight-monks who, the legends say, dug beneath their hall in
Jerusalem and found something, grew richer than kings, were accused of worshipping the idol Baphomet, and were destroyed on Friday the
13th, 1307. In the game they never died out. They guard the Grail and the shards of the Crown from a hidden haven.

- Fits as it is: knights, griffins (heraldry), monks, cavaliers, angels.
- Renamed: Pikeman → Sergeant (the Templars' own rank), Monk → Chaplain Brother, Brotherhood of the Sword → Chapter
  House. The Archer stays an Archer: the Templars' turcopoles were mounted archers, and ours walk. The upgrades keep
  their names (Halberdier, Marksman, Zealot).
- Legendary heroes: Jacques de Molay (the last Grand Master, who cursed the king and the pope from the pyre),
  Hugues de Payens (the founder).
- Town names (built): Rosslyn, Gisors, Tomar, Acre, Temple Bruer.

### Necropolis: the Order of the Dragon

In 1408 the King of Hungary founded the Order of the Dragon to fight the Ottomans. One of its knights, Vlad II, took
the name *Dracul*, "the Dragon"; his son was Vlad *Dracula*, "son of the Dragon", and the root of the vampire
legend. In the game the Order never ended: it is a society of the deathless, and what the elixir legends whisper
of, eternal life, is its necromancy. Behind the Hellfire Club, the grimoires and the immortal Count, it is always the
Order. (Named in place of "the Lodge", which is the Freemasons' word: see the lines.)

- Fits as it is: skeletons, ghosts, vampires, liches, dread knights, bone dragons (its vampires and dragons are its
  name's own legend).
- Legendary heroes: the Count of Saint-Germain (who, it was said, never aged and never died), Edward Kelley (John
  Dee's scryer, who claimed to speak with spirits).
- Town names: keep the existing (Gravenmoor, Ashenveil, Mortholme, Duskhaven, Blackfen).

### Eridu: the Anunnaki

The sky-gods of Nibiru who came for gold and crashed in the marshes (`docs/ERIDU_PROPOSAL.md`). The Shattered Crown
was theirs.

### Future factions: HoMM3's towns, each as a secret history

Each keeps its HoMM3 role and creature line-up; the theme decides names, look and lore.

| HoMM3 town | Secret history | The idea |
|---|---|---|
| Tower (wizards, golems, genies, titans) | **The Illuminated** | the Bavarian Illuminati, Rosicrucians and alchemists: the eye in the pyramid, the Philosopher's Stone, the golem of Prague, Nicolas Flamel |
| Dungeon (troglodytes, beholders, minotaurs, dragons) | **Agartha** | the Hollow Earth: an inner sun, the kingdom beneath, things that come up through the poles |
| Rampart (elves, dwarves, unicorns, dendroids) | **The Hidden Folk** | the fair folk of the stone circles and ley lines, who steal people away (the old faerie abductions) |
| Fortress (lizardmen, basilisks, wyverns, hydras) | **Lemuria** | the sunken land of the serpent folk |
| Conflux (elementals, phoenixes) | **Atlantis** | the drowned empire of orichalcum and crystal power |
| Stronghold (goblins, orcs, ogres, rocs, behemoths) | **The Wild Things** | cryptids: Bigfoot, the Yeti, the Mothman, the Jersey Devil |
| Inferno (imps, demons, devils) | **The Cult of Baphomet** | the idol the Templars were accused of worshipping, and the legions behind it |

## The Iron Order (villains only)

A fictional occult order of conquerors from "another age", who come through the ley lines hunting the Spear of
Destiny and the shards of the Crown to build an empire. The pulp silhouette is enough: grey greatcoats, iron masks,
torchlit excavations, black banners with an **invented** device (an iron crown pierced by a spear). Never real
symbols, names or ranks (see the lines).

How they appear (never as a playable faction, never in a player's army):
- **Excavations**: guarded map sites where the Order digs for a relic. Beating the guards gives the relic.
- **Neutral stacks**: Iron Order troops as hostile map guards, made from existing creature rules (for example
  Iron Legionnaires on the swordsman line).
- **Campaign villain**: a later story campaign could set every order against them.
- They cannot join an army: no dwelling, and the Order's stacks never offer to join, cannot be recruited and cannot
  be raised or shaped.

## Relics: the artifacts

The artifact rules stay as built (`docs/ARTIFACTS_PROPOSAL.md`). The names and pictures can turn to relics of the
secret histories. Proposed renames for the headline artifacts:

| Now | As a relic | Why |
|---|---|---|
| Seraph's Covenant (set: Sun Pendant, Seraph's Feather, Sunsteel Cuirass) | **The Grail Hallows** (the Cross of the Temple, the Holy Grail, the Mantle of the Temple) | the Grail and the Templars who keep it (the parts stay in their slots: neck, misc, torso; a lance has no place among them) |
| Mantle of the Lich King (set: Bone Crown, Gravecloak, Phylactery of Ages) | **The Count's Immortality** (Coronet of the Count, Cloak of Saint-Germain, Elixir of Life) | the deathless Count |
| Dragonheart Arms (set: Dragonbone Blade, Dragonscale Shield, Dragonskull Helm) | **Arms of Saint George** (the blade is **Ascalon**; the shield and helm keep their names, trophies of the dragon) | the dragon-slayer |
| Seer's Spyglass | **Dr. Dee's Scrying Mirror** | John Dee's obsidian mirror |
| Orb of Power | **Crystal Skull** | the crystal skull legends |
| Crown of Command | **Crown of Prester John** | the lost priest-king of the East |
| Bottomless Purse | **The Templar Treasure** | the lost wealth of the Temple |
| Helm of Wisdom | **Helm of Solomon** (it stays a helm; the Emerald Tablet joins the relics for later) | the wise king of the grimoires |
| Boots of Speed | **Seven-League Boots** | folklore |
| Amulet of Insight | **Eye of Horus** (repainted: the wedjat eye in gold and lapis) | the eye of the falcon god, ancestor of the all-seeing eye |
| Ring of Vitality | **Ankh of Life** (repainted: a gold ring with a carnelian ankh) | the Egyptian sign of life; +1 health for every creature |

New relics for later: the Emerald Tablet, the Spear of Destiny (what the Iron Order hunts), the Philosopher's Stone, the Voynich
Manuscript, the Tablets of Destiny, the Head of Baphomet, the Shards of the Crown themselves (a set, the game's
centre).

## Map objects

| Now | Retheme |
|---|---|
| Shrine (teaches a spell) | **Stone Circle** on a ley line (repainted: standing stones with spiral carvings, no runes) |
| Learning stone (experience) | **Obelisk of Thoth** (the black obelisk with glowing glyphs already looked the part; first named the Monolith) |
| Watchtower (reveals the map) | **Observatory** (repainted: a domed stone tower with a telescope) |
| Alchemist's Lab (mercury mine) | keep |
| Chest, campfire, windmill, mines | keep |
| new | **Crop circle**: a hero who walks into it gains movement or luck for the day |
| new | **Excavation** of the Iron Order (above) |
| new | **Men in Black**: a wandering neutral stack that guards sky-chariot wreckage |

## What changed first

Built on 2026-10-24: the factions are named **Temple** (Haven) and **Lodge** (Necropolis; renamed the **Order of the Dragon** the same
day); the scenario texts tell the
premise; the Templar ranks, the artifacts and the map objects above are renamed, and eleven artifacts and two map
objects repainted to match. Ids stay as they were (ARCHITECTURE.md), so saves keep working. Then the heroes from
legend (step 3): Jacques de Molay and Hugues de Payens (Temple Knights), the Count of Saint-Germain and Edward Kelley
(Order of the Dragon Necromancers), six heroes a faction now. Then the Temple's town names: Rosslyn, Gisors, Tomar, Acre and
Temple Bruer (the Order's already fit). Still to do: the art (step 4).

The plan was these cheap steps, which make the new identity visible without much new art:
1. Rewrite the lore: the faction descriptions, scenario texts and the main menu's story, around the Shattered Crown
   as the star-crown.
2. Rename the headline artifacts, the Templar ranks and the map objects as above (names and texts).
3. Legendary heroes: add or rename a few (Jacques de Molay, the Count of Saint-Germain).
4. Then art, as each piece is redone: Templar crosses and mantles on Haven (done in session67: the town screen, cards,
   map towns, sieges and main menu in Templar colours), the Order's dragon sigils on Necropolis (done in session67: town
   screen, cards and map towns in crimson and black with the coiled golden dragon), relic
   pictures.

The bigger steps (Eridu, the Iron Order's excavations, new factions) follow the online plan in HANDOFF §8.

## The user's answers (2026-10-24)

1. **The standing rule:** yes, changed in CLAUDE.md and HANDOFF §3.
2. **Faction names:** rename (built as Temple and Lodge; then the Lodge became the Order of the Dragon, the user's
   choice, as "Lodge" is the Freemasons' word).
3. **The premise:** yes.
4. **The renames:** all (built, with three adjustments noted above: the Archer, the Grail Hallows' parts, the Helm
   of Solomon).
5. **The Iron Order:** yes, villains only.
6. **Future factions:** yes.
