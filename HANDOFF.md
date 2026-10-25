# Handoff — where the project stands and how to carry on

Read this first, then `ARCHITECTURE.md` (code map), `ASSETS.md` (every asset path and the art pipeline) and
`CREDITS.md`. This file is written so that another person or another AI assistant can pick the work up exactly
where it stopped. Last updated 2026-10-24 (HeroesGPT repository continuation; latest visual review: judge 47,
overall 9.4), branch `main`, remote `https://github.com/wolfxxx/HeroesGPT.git` (public repo).

## 1. The project in one paragraph

"Heroes of the Shattered Crown" is a Heroes of Might and Magic III–style game in Godot 4.7 (GDScript): a random
adventure map with heroes, mines, monsters and fog; two factions (Haven, Necropolis) with painted town screens,
building and recruiting; hex battles with 14 creatures, war machines, spells and sieges; a computer opponent;
music and sound. All art is 3D library models rendered in Blender and then painted over by an image model, plus
painted icons and UI. The work has gone in **rounds**: an independent judge agent scores 33 screenshots against
the look and feel of HoMM3, and each round fixes what the judge found.

## 2. Status

- **Session67 browser edge scrolling (2026-10-25), committed with this HANDOFF update:** the user found that in the browser the map stopped
  scrolling up once the cursor went past the top of the page (the fix in `4ab24d5` turned edge scrolling off when the
  cursor left the page). Now, as on the desktop, it keeps scrolling toward the edge the cursor left by until it comes
  back (`adventure._past_edge`, `_left_at`). Checked in Chrome on the web build: off the top it scrolled the whole way
  up, and back over the map it stopped (`shots/session67/web/edge_strip.png`).
- **Session67 browser version and online rooms (2026-10-25), committed with this HANDOFF update:** the user asked for the game on GitHub
  Pages so it opens easily on several computers, and chose a relay so the browser version can play online too
  (Cloudflare account made and `wrangler login` run by the user). New: the relay (`relay/`, a Cloudflare Worker with
  a Durable Object per room, live at wss://heroes-relay.shatteredcrown.workers.dev; workers.dev subdomain
  `shatteredcrown` registered for it), `RelayPeer` (`scripts/core/relay_peer.gd`) and `Net.host_room` /
  `join_room`: the host gets a four-character room code, the others type it (desktop or browser, no port to
  open; joining by address stays on the desktop). Menu: Host Online Room / Host by Address / Join (code or address).
  The Web export preset (`export_presets.cfg`, single-threaded) and `.github/workflows/pages.yml` (Godot exports on
  every push to main and publishes to https://wolfxxx.github.io/HeroesGPT/). Browser fixes: no Quit buttons; edge
  scrolling only while the cursor is over the page. Found and fixed in the two-browser run (also on desktop): the
  camera followed another person's walking hero through the fog, showing where they went. Checked: `net_test --
  --relay` (22 checks through the live relay, including a whole world resent and a battle fought on the joined
  machine); two browser windows (Playwright with Chrome) hosting and joining a room, moving and passing turns
  (`shots/session67/web/`). The web download is about 118 MB of game data plus a 40 MB engine.
- **Session67 good morale fixed (2026-10-24), committed with this HANDOFF update:** the user agreed to fix it ("yes"). In played battles the
  computer's stacks never won good morale, and a person's roll went to the wrong stack: `_act` read
  `L.current()` after the action had already ended the stack's turn, so the roll fell on the next stack (often the
  enemy's) and could even start the next round early. Now, as the classic (Heroes 3 wiki, Combat and Morale): after
  a move or an attack the stack that has just acted may act again at once, for every side, never after defending
  or waiting, once a round; rolled straight after the action, before any animation (`battle.gd _carry`), so both
  machines of an online battle roll at the same point. Played battles against the computer get a little harder
  (its stacks now get extra turns too). New `tools/battle_morale_test.tscn` (5 checks; attacker 5, defender 4 extra
  actions over 8 rounds) in the suite.
- **Session67 battles on both screens (2026-10-24), committed with this HANDOFF update:** online battles are now fought by each person on
  their own machine, ending the first two of the three agreed stopgaps. Two people: the battle runs on both screens
  in lockstep (same seed; each machine sends only its own side's actions; `Net.battle_begin/battle_send/battle_next`).
  The host's computer attacking a joined player: fought on that player's machine, result sent back
  (`Net.fight_remote/battle_done`). Left as agreed: a level gained defending is chosen at the owner's next turn.
  The battle screen now carries every choice as an action (`battle.gd _carry/_turn/_ai_turn/_remote_turn`), and
  works on copies of the heroes: spell points and war machines come back in the result (`spell_points`,
  `machines`, applied in `apply_battle`) instead of being written into the world mid-battle. Found: the
  computer's battle actions never rolled good morale (fixed in the next entry). New `tools/net_battle_test.tscn` (12 checks: every action crossed, same result on both) in the suite;
  `net_test` now also has Teal attack Blue (fought on Blue's machine, 22 checks). Windowed check of the host's side
  of a two-machine battle: the other machine's spells arrive and play (`shots/session67/nb_*.png`). Two windows from
  the map (new harness setup `--setup=duel`: the second player's hero two steps from the first's): Red attacked
  Blue's hero, both screens opened the same field ("Waiting for Sir Aldric..." on Blue's), one move by hand then
  auto on both, the same result on both ("Victory!" for Red, "Defeat" for Blue, 308 experience), applied once, no
  differences at the turn's end (`shots/session67/play*/d*_*.png`). Suite passes (26 groups).
- **Session67 online play, first version (2026-10-24), committed with this HANDOFF update:** phase 2 begun (HANDOFF §8). New autoload `Net`
  (`scripts/core/net.gd`): one player hosts (main menu > Multiplayer > Host a Game, then the New Game screen where
  other human colours are "Online"), others join by address (Join). Every machine keeps the world; each accepted
  command is passed on (joining machine -> host, which checks and relays; host -> everyone) and applied in the
  same order; the host's digest at each turn's end catches a world gone astray and sends the host's world. The
  computer players move on the host; each screen shows its own player and waits ("Blue Player is moving...")
  during the others' turns. A player acts only on their own turn (now a rule in `Commands.run`). New `sleep` command
  (the screen set `asleep` directly: found by the first two-window run as a difference). `visit_after_guard` and
  `game_over` are each machine's own (set aside in the digest). Dead `adventure._move_hero_tile` removed
  (`adventure_camera_test` places its hero itself). `garrison_hero_test` now gives the computer its turn. Commands
  test 83 checks (sleep, the turn rule); suite passes. New `tools/net_test.tscn` (two processes, 18 checks, in the
  suite) and `tools/net_diff.tscn`. Checked with two windows on this computer through the remote harness: hosting,
  joining (Blue sees its own map and briefing), a turn each way, a battle fought on the joining machine (victory and
  Necromancy applied identically), no differences over three days (`shots/session67/play*/m_*.png`, `n_*.png`).
  **Temporary deviations, accepted by the user ("Ok") until battles run on both screens:** in a battle between two people the side whose machine is not
  fighting it is led by the computer; the computer attacking another machine's player is resolved at once; a
  level gained defending on another's turn is chosen at the owner's next turn.
- **Session67 dice and the replay test (2026-10-24), committed with this HANDOFF update:** step 4 of `docs/FOUNDATIONS_AUDIT.md`, the last of
  phase 1. New `scripts/core/dice.gd`: the rules roll on the world's own generator (`world["rng"]`, saved), and
  only inside commands (week creature, Windmill, level rolls, a hired hero's troops); choices outside commands
  (the computer's Tavern and skill picks, quick battles' luck, a played battle's seed, now always set) use
  `Dice.derived`, seeded from the world's state without moving it; battle and map presentation use `Dice.look()`.
  New `tools/replay_test.tscn` (in the suite): two computer-played maps recorded as commands, replayed on the
  starting world through `var_to_bytes`, compared, and each played twice: identical. It found one rule outside the
  commands, a hero learning the Mage Guild's spells: now `town_visit` (screen and computer), and `build` (a new Mage
  Guild teaches the visiting hero) and `hire` (the hired hero learns the guild) return `learned`. Commands test 80
  checks. Seeded games changed, so the tournament references are new: 4 players size 48 maps 600-601 21 days
  +6.51 +/- 12.17 (344 battles), 2 players size 36 maps 700-702 +15.28 +/- 19.45 (65 battles); the 4-player run
  repeats exactly. Same-policy controls in the suite still exactly 0.00.
  The current AI is not weaker: 10 two-player size-48 maps (900-909, 28 days) gave +56.42 +/- 26.23 at 2b72882 and
  +78.41 +/- 29.98 now (overlapping); on size 36 (800-809) the current AI now wins 20/20, but games there are
  settled by day-4/5 rushes and swing on any change of dice. Suite: 24 groups pass. In the real game: a Mage Guild
  built with Sir Aldric visiting taught him 4 spells (`build`'s `learned`); a played battle (map-seeded) ran and
  returned to the map (`shots/session67/play/d_*.png`).
- **Session67 screen state out of the world (2026-10-24), committed with this HANDOFF update:** step 3 of `docs/FOUNDATIONS_AUDIT.md`. Each player's
  own screen state now lives in `world["views"][player]` (`GameState.view(p)`): selected hero and town, the
  scenario briefing shown, the day's news still to announce (`news`, set for every human at the new day, read and
  cleared by `_turn_banner`; replaces `pending_week` + `seen_by`), a defeat already told. A host can keep each
  player's view to that player. `GameState.viewer` (whose eyes the screen shows during computer turns) is a plain
  variable, not saved; objects taken off the map are listed in `AdvRules.removed` instead of `world["_removed"]`;
  the dead `pending_turn_banner` branch is gone. Saves are now version 2 (`GameState.SAVE_VERSION`); a version-1
  save is converted on load (`_views_from_v1`). Checked on a copy of the user's save (the original untouched): its
  selected hero came across and the adventure screen opened on it. Suite passes; tournaments with the current AI
  identical before and after. In the real game (remote harness): the scenario briefing once, the hero selected,
  day 2 reached, the town selected from the list, saved and loaded back with the town still selected and no
  briefing again (`shots/session67/play/v_*.png`). Left in the world as game state: hero `dest`
  and `face_left`, the AI's notes, `game_over`. Eight tests now read the view instead of world keys.
- **Session67 command layer, the rest (2026-10-24), committed with this HANDOFF update:** `build`, `enter_garrison` / `leave_garrison` /
  `swap_garrison`, `equip` / `split_set` / `join_set` / `give_artifact`, `buy_machine`, `transform`, and level-ups
  as `level_roll` + `level_up` (the rules roll and keep the offer; the skill must be one offered). Every map and
  town action is now a command (town screen, hero screen, meeting, factory shop, level-up dialog, computer).
  `AdvAI.buy_from_factory(hero)` keeps its signature (the frozen baselines override it: changing it broke them)
  and finds the factory the hero stands at; the war machine test now stands its hero there. Tournaments with the
  current AI identical; the tally showed every new command running (33 builds, 69 level-ups, garrison moves,
  machine buys). Level-up checked in the real UI (Attack +1, Basic Luck chosen). Commands test 74 checks.
- **Session67 command layer, what a hero meets (2026-10-24), committed with this HANDOFF update:** `visit` (a site the hero stands on; not
  a monster or a guarded Pyramid; a chest's offer kept as `hero.pending_chest`), `chest` (the offer's own gold or
  experience, once), `capture` (an undefended town from its gate) and `battle_result` (`apply_battle` on its
  player's turn) used by `adventure._interact_with`, `_show_event`, `_post_ready` and `_start_battle`. Tournaments
  with the current AI identical before and after; one game made 236 visits, 190 battle results, 42 chests and 48
  captures, none refused. In the real UI: a campfire and a chest (+500, +2000 gold) and a fought battle (the
  monster gone after OK). Commands test 51 checks. The adventure AI test's hand-built worlds have no
  `current_player`: `battle_result` skips its turn check there, and the screen sends the attacker. Still direct:
  building, garrison moves, artifacts, level-ups.
- **Session67 command layer, movement and the turn (2026-10-24), committed with this HANDOFF update:** `step` (one step to a free
  neighbour, paying `AdvRules.step_cost` exactly as the planner charges, refreshing the tile cache, revealing
  around the hero) and `end_turn` (the next living player, `new_day` at the end of the round). `adventure.move_hero`
  walks a route as steps (animation, camera and what the hero meets stay in the screen); `_advance_player` sends
  `end_turn` (the screen still keeps `pending_week`). Tournaments with the current AI identical before and after;
  a tally showed 6151 accepted steps and no refusals in one game, and the soak test 23 turn ends. In the real UI
  (remote harness) a walk to an ore pile paid the planner's 357 and took the ore; E ended the turn into day 2.
  Commands test 40 checks. Next: visits, battles and captures as commands.
- **Session67 command layer, stack moves (2026-10-24), committed with this HANDOFF update:** `stack_move` (the army bar: move, merge,
  split, swap, with `swap` to force it), `move_troops`, `upgrade_stack`; armies named `{"hero"}`/`{"town"}` and
  required to stand together (`Commands.together`). Every editable `ArmyStrip` (town screen, hero meeting, hero
  screen) sends them; the computer's real transfers go through `AdvAI._mv` / `_swap` (copies used for previews
  still change directly). **Method corrected:** `adventure_tournament --self` plays only the frozen baseline, so
  the earlier "identical" checks never ran `AdvAI`; re-run without `--self` (the current AI in a seat) on worktrees
  of 758a1f7/26f40f3 (faction data) and 1b010d6/165052c (first commands step): identical, and this step identical
  too. A tally showed the commands ran (61 town recruits, 49 troop moves, 13 hires in one game). Commands test 31
  checks; the town screen's bars checked driving the real screen. ARCHITECTURE.md gives the right comparison.
- **Session67 command layer, first step (2026-10-24), committed with this HANDOFF update:** step 2 of `docs/FOUNDATIONS_AUDIT.md` begun.
  New `scripts/adventure/commands.gd` (`Commands.run`, through `AdvRules.do(cmd)`): actions as plain dictionaries,
  checked, applied, reported. `recruit_town`, `recruit_site`, `hire`, `trade` (the market rate moved to
  `TownLogic.market_rate`); the town screen, the dwelling dialog (`recruit_dialog` takes a `buy(n)` callback) and
  the computer use them. Seeded tournaments (4 players size 48, 2 players size 36) identical before and after.
  New `tools/commands_test.tscn` (17 checks, every command sent through JSON). Next: stack moves, then movement.
  (Its tournament check used `--self`, which plays only the frozen baseline; re-checked in the next entry without it.)
- **Session67 Order of the Dragon art (2026-10-24), committed with this HANDOFF update:** a pilot of five approved by the user ("roll
  out"), then the rest: the Order's 30 town-screen layers (with the backdrop), 27 building cards and 3 map towns
  repainted with crimson-and-black heraldry and the Order's golden dragon coiled in a circle (on banners, shields,
  the Capitol's rose window), the dark stone, bones and green ghost-light kept; the layout unchanged. The Temple
  tool was generalised and renamed `tools/art/faction_repaint.py <faction>` (`haven`, `necropolis`; `slate` for
  the Temple). Its siege paintings are unchanged. Screenshots in ignored `shots/session67/dragon/`.
- **Session67 Temple art (2026-10-24), committed with this HANDOFF update:** the Temple in the Templars' colours, a pilot of five pictures
  approved by the user ("roll out in this style"), then the rest: all 29 town-screen layers and the backdrop, 28
  building cards and the main menu painting repainted by the new `tools/art/temple_repaint.py` (now `faction_repaint.py`) (white stone and
  gold kept; banners white with a red cross pattee; blue roofs grey slate; red-cross shields), each layer pasted
  back inside its old alpha so the layout and click areas are unchanged. The 3 map towns and the 37 siege
  paintings and damage pieces only had blue turned to slate (`slate`, hue-based: the walls and damage pieces must
  stay aligned). The backdrop's edges drifted a little in the repaint (a tree at the far left is gone), noted to
  the user. Screenshots in ignored `shots/session67/temple/` (`pilot_compare.png`, `town_after.png`,
  `menu_after.png`, `siege_after.png`); originals in `shots/session67/temple_old/`.
- **Session67 setting playtest (2026-10-24), committed with this HANDOFF update:** the assistant played "The Shattered Crown" (Normal,
  Order of the Dragon, Saint-Germain, artifact bonus) through the real UI with the remote harness on
  `user://playtest_save.dat` (the player's save hash-checked unchanged, 60b0e1fc928). **Outcome: defeat on day 7**:
  Blue's Vesna Nightshade besieged and took Temple Bruer, killing Saint-Germain, while Duskhaven, emptied of its
  garrison by the player, fell to another Blue force (a player mistake; the computer applied real pressure).
  Seen working in play: the new intro, faction cards and names, Saint-Germain, the Tavern rumour (a true hint: the
  Signet of Coin south-east of Temple Bruer), declassified lines on first visits (cape tooltip, campfire, chest,
  windmill, Wayfarer's Cloak) and not on repeats, the Mage Guild, Necromancy, Sergeants, the Pyramid on the map
  and its panel, a siege of a Temple town with "The garrison of Temple Bruer" in the result, artifact capture.
  Fixed in play: a bare `state` command stopped the harness (`shot.gd`; now `state.json` by default); the
  Wayfarer's Cloak's line said "shrine" (now "stone circle"). Noted, not bugs: a level-up window after a
  chest's experience takes the next click; a fight that interrupts a move stops the hero short of the treasure (as
  HoMM3). Still to see in play: the new-week omen, stone circles and obelisks, the Pyramid fight, Mummies and the
  Tomb, a slain hero rehired at his level. Art still generic: the main menu castle and the Temple town screen (no
  Templar look yet). Evidence in ignored `shots/session67/play/`.
- **Session67 Mummies and the Tomb of Curses (2026-10-24), committed with this HANDOFF update:** step 2: HoMM3's **Mummy** (`mummy`,
  neutral undead, 7/7, 3-5, 30 health, speed 5, growth 7, 300 gold) with a new `curse_strike` ability (25%: the
  struck stack cursed for 3 rounds, Bless lifted; artifacts' curse immunity holds), painted over the Zombie
  (`new_creature_paint.py`, poses, walk cycle); its dwelling the **Tomb of Curses** (`map/dwelling_mummy.png`,
  over the neutral dwelling), one guarded on medium and larger maps, placed with the Pyramid's own generator;
  named by the creature's `"dwelling"`; a declassified line. Pyramid test now 106 checks (Mummy numbers and
  sprites, the curse rate, the Tomb). Screenshots `shots/session67/setting/tomb_map.png`, `mummy_battle.png`.
- **Session67 the Pyramid and the ushabti (2026-10-24), committed with this HANDOFF update:** step 1 of the user's choice ("both, in two
  steps"; step 2 is Mummies with HoMM3's Tomb of Curses). I had said HoMM3's Pyramid is guarded by Mummies; it is
  not: 40 Gold Golems and 2 x 10 Diamond Golems guard it (Heroes 3 wiki), and they are the new neutral **Gilded**
  and **Crystal Ushabti** (`gold_golem`, `diamond_golem`: the golems' numbers, 85 / 95% less spell damage, not
  raised by Necromancy), painted over the Swordsman by the new `tools/art/new_creature_paint.py` with poses and
  walk cycles. One **Pyramid** near the middle of medium and larger maps (new `map/pyramid.png`); beat the guards,
  go inside, learn its level-4 spell with Advanced Wisdom or lose it forever; empty, -2 luck until the next
  battle. `WorldGen._place_obj` split into `_spot_ok` / `_put_obj`. **Seeded medium and large maps change** from
  the Pyramid's placement on (small maps verified identical: a seeded size-36 tournament matches line for line);
  a seeded 4-player tournament before the Pyramid also matched. New `tools/pyramid_test.tscn` (37 checks).
  Screenshots `shots/session67/setting/pyramid_map.png`, `pyramid_battle.png`.
- **Session67 declassified lines (2026-10-24), committed with this HANDOFF update:** one strange line for each of the 41 artifacts and 14
  kinds of map site (`Lore.ENTRIES`), at the bottom of the map hover panel and the hero-screen tooltip, mostly
  blacked out (full blocks) until the player has held the relic or visited that kind of site; the first time, the
  whole line comes with the message. Effects and rules always show, as HoMM3. Known lines per player in
  `player["lore_known"]` (saved), marked by `GameState.give_artifact` and `AdvRules.visit`. `adventure._tile_info`
  now wraps `_tile_info_base`. Lore test 97 checks. Screenshot `shots/session67/setting/declassified.png`.
- **Session67 Egyptian relics (2026-10-24), committed with this HANDOFF update:** the Amulet of Insight is the **Eye of Horus** and the Ring
  of Vitality the **Ankh of Life**, both repainted (`artifact_icons.RETHEMED`, map sprites recut; old art in
  `shots/session67/art_old/`); the Monolith (learning stone) is the **Obelisk of Thoth**, its texts too, and the
  lore lines say obelisks. Effects unchanged. Checked in the hero screen
  (`shots/session67/setting/hero_screen_egypt.png`).
- **Session67 the feel, omens and rumours (2026-10-24), committed with this HANDOFF update:** the user wants the game to feel like stumbling
  into the depths of conspiracy theories and old mysteries. SETTING.md has "The feel" as its guiding principle
  (four layers, one a month: historical, occult, ancient, cosmic; rumours that turn out true; digging, not reading).
  Built: new `scripts/core/lore.gd` with weekly omens (added to the astrologers' new-week proclamation) and Tavern
  rumours (a line in the Tavern window, as HoMM3's), six omens and five rumours per layer, dealt without repeats
  within a month; two in five rumours are true hints (a relic's or unclaimed mine's place by the nearest town).
  Seeded per map and week with a private generator: seeded games are unchanged. `AdvRules.new_day` stores
  `world["rumour"]`. New `tools/lore_test.tscn` (41 checks). Screenshots `shots/session67/setting/week_omen.png`,
  `tavern_rumour.png`. Next on the list: Egyptian relics and map objects, the Pyramid, declassified descriptions.
- **Session67 Order of the Dragon (2026-10-24), committed with this HANDOFF update:** the Lodge is renamed the **Order of the Dragon** (the
  user's choice): "Lodge" is the Freemasons' word, a living organisation, which the setting's lines keep out. The
  real knightly order of 1408 gave Vlad Dracul and Dracula their names, so its vampires and dragons are its own
  legend. Description "Deathless heirs of the Dracula legend." New faction field `short` ("Temple", "Dragon") for
  the New Game seat buttons. Checked on the New Game screen and in the Tavern
  (`shots/session67/setting/newgame_dragon.png`, `tavern_dragon.png`).
- **Session67 faction data (2026-10-24), committed with this HANDOFF update:** step 1 of `docs/FOUNDATIONS_AUDIT.md`. `GameData.FACTIONS` holds
  each faction's whole record (smith machine, specials, extra requirements, dwelling and town names, classes,
  `battle_figure_lift`; `SMITH_MACHINE`, `FACTION_REQUIRES`, `SPECIALS`, `DWELLING_NAMES` and
  `TownLogic.TOWN_NAMES` are gone); new `GameData.CLASSES` (faction, might, starting machine); specials carry
  `effects` read by `TownLogic.effect` / `transform_creature` / `transform_stack` (was `transform_to_skeletons`);
  Necromancy's creature is `SKILLS.necromancy.raise`; `AdvAI.build_order(faction)` places specials by `ai_after`.
  No behaviour change: a seeded 4-player tournament (maps 600-601, 21 days) is identical before and after. New
  `tools/faction_data_test.tscn` (128 checks) in the suite. The Transformer window takes its title and creature
  from the data (and lost its "as as many" typo); screenshot `shots/session67/setting/transformer.png`.
- **Session67 foundations audit (2026-10-24), committed with this HANDOFF update:** `docs/FOUNDATIONS_AUDIT.md` sizes phase 1 of the
  big-picture plan. Battles are already command-shaped (only the turn driver is in `battle.gd`); about a dozen map
  and town actions are carried out in screens (hero movement in `adventure.gd`, recruiting, hiring, trading, stack
  moves), and the AI has its own copies of several; interface state (selection, viewer, banners) lives in the
  saved world; played battles are seeded from the clock, map rules use the global stream that battle animations
  also draw from, saves keep no random state; faction tables are spread over five files and some rules name one
  faction's buildings, classes or creatures. Proposed order: faction data, command layer, interface state,
  randomness and a replay test. Nothing changed in code.
- **Session67 Temple town names (2026-10-24), committed with this HANDOFF update:** `TownLogic.TOWN_NAMES["haven"]` is now Rosslyn,
  Gisors, Tomar, Acre and Temple Bruer (was Stormhold, Brightwater, Valoria, Kingsbridge, Aurelia; earlier entries
  name towns by the old names). Five names as before, so a seeded map gives the same town the name in the same
  place (Brightwater became Gisors). The Lodge's names are kept.
- **Session67 heroes from legend (2026-10-24), committed with this HANDOFF update:** four heroes added (`GameData.HEROES`, portraits by
  the new `tools/art/legend_portraits.py`): Jacques de Molay (Temple Knight, Armorer), Hugues de Payens (Temple
  Knight, Logistics: he guarded the pilgrim roads), the Count of Saint-Germain ("Saint-Germain", Lodge
  Necromancer, Wisdom, Haste and Weakness) and Edward Kelley (Lodge Necromancer, Luck, Curse and Magic Arrow). The
  existing eight stay. The New Game screen lays a faction's six heroes in two rows of three (`_hero_row` is a
  GridContainer; cards 250x72). Specialties remain text; the starting skill gives the effect. Screenshots
  `shots/session67/setting/newgame_haven.png`, `newgame_necropolis.png`.
- **Session67 setting approved, first renames built (2026-10-24), committed with this HANDOFF update:** the user approved
  `docs/SETTING.md` (all six answers yes; factions renamed). CLAUDE.md and §3's HoMM3 rule now say the setting is
  our own secret history. Built: the factions are **Temple** (`haven`) and **Lodge** (`necropolis`) with new
  descriptions; the scenario texts tell the premise (the crown forged from a fallen star); Pikeman → Sergeant,
  Monk → Chaplain Brother, Brotherhood of the Sword → Chapter House; fifteen artifacts renamed as relics, eleven
  repainted (`artifact_icons.RETHEMED`; map sprites recut); the Shrine is the Stone Circle and the Watchtower the
  Observatory, both repainted by the new `tools/art/map_object_paint.py`; the Learning Stone is the Monolith (its
  picture fitted). Ids unchanged (saves, asset paths, tests). Adjustments to the proposal, noted in SETTING.md:
  the Archer keeps its name (turcopoles rode), the Grail Hallows are the Cross, the Grail and the Mantle of the
  Temple (the set's slots), the Helm of Wisdom became the Helm of Solomon (the Emerald Tablet is not a helm), the
  stone circle carries spirals instead of runes. Screenshots in ignored `shots/session67/setting/`,
  `relics_compare.png`; old art in `shots/session67/art_old/`. Still to do: legendary heroes, town names, art.
- **Session67 setting proposal (2026-10-24), committed with this HANDOFF update:** the user wants the setting to lean on conspiracy
  lore. `docs/SETTING.md`: the premise (every secret history is true; the Shattered Crown was forged from the
  crystal heart of Alalu's ship and every order hunts its shards), the tone (pulp wonder on a medieval-mythic
  surface; only long-dead real people, as their legends), the lines (in: myth, legend and history over a century
  old; occult Nazis as villains only, the user's choice, as a fictional Iron Order with no real symbols, never
  playable; out: live modern conspiracy theories such as vaccines, and "secret cabal of a people" theories),
  Haven as the Templars, Necropolis as the Lodge, Eridu as the Anunnaki, HoMM3's other towns as secret histories,
  relic renames for artifacts, rethemed map objects, cheap first steps and 6 questions (one is changing the
  CLAUDE.md HoMM3 rule to "HoMM3's mechanics, our setting"). Awaiting the user's answers; nothing built.
- **Session67 Eridu proposal (2026-10-24), committed with this HANDOFF update:** the user's idea of an alien faction (a crash-landed
  ship as the castle, strange creatures, magic that is science), a deliberate deviation from HoMM3 they raised
  themselves, themed on the Sumerian / Nibiru ancient-astronaut lore they chose (their notes:
  `C:/Users/PC/Documents/factionname.pdf`, outside the repo). `docs/ERIDU_PROPOSAL.md`: the Anunnaki of Eridu,
  a town built over Alalu's crashed ship in the marshes; 7 tiers of mythic creatures (Lulu, Igigi, Scorpion Men,
  Sharur, Apkallu, Lamassu, Anzu) with first-pass stats and 7 new abilities; Lugal / Keeper heroes (Alalu,
  Ninurta, Enki, Ninhursag); Shaping as its Necromancy; House of the Me and Dur-An-Ki; artifacts and spells
  unchanged (the Ziggurat teaches the same spells); the look rules (Mesopotamian first, star-science as a glow;
  the Forge lesson); costs, balance plan and 8 questions. A first draft called it "Starfall"; the user disliked
  the name. Awaiting the user's answers; nothing built.
- **Session67 dismissed heroes (2026-10-24), committed with this HANDOFF update:** a hero dismissed from the hero screen no longer comes
  back from the Tavern fresh. `AdvRules.dismiss_hero` (both dismiss buttons) keeps them in `tavern_keep` with
  everything but the army: level, experience, skills, spells, artifacts and war machines (rehired: a starting army).
  Source: the Heroes 3 wiki's Grail page ("when he is dismissed, it is possible to find him in a tavern with a
  Grail in his backpack") and a Heroes Community thread ("The Hero keeps all Artifacts, but loses the entire
  army"). The heroes of a player knocked out of the game still leave fresh. 4 new checks in
  `tools/retreat_test.tscn` (21).
- **Session67 slain heroes (2026-10-24), committed with this HANDOFF update:** the user agreed to follow HoMM3: a hero slain in battle
  no longer comes back from the Tavern fresh at level 1. `AdvRules._slay_hero` keeps them in `tavern_keep` (like
  one who fled) with their level, experience, primary and secondary skills, spells and spell book; their artifacts
  go to the winning hero (`_loot`) or are lost to monsters and garrisons, and their army and war machines are lost
  (rehired: a starting army and `GameState.starting_machines`, as a fresh hero). The Tavern already shows a kept
  hero's level. No wiki page states the rule outright; it matches community knowledge (Celestial Heavens "Hero
  buy-back"). Those of an eliminated player still leave fresh (dismissed ones: next entry). 8 new checks in
  `tools/retreat_test.tscn` (17).
- **Session67 neutral rings (2026-10-24), committed with this HANDOFF update:** neutral stacks' grey rings were lost on grass (a mid grey
  as bright as the grass). `battle.side_color` now gives neutrals a light silver grey (0.92, 0.91, 0.86), also on
  their turn-queue cards; checked on grass, snow and sand (`shots/session67/rings_compare.png`: before, after,
  snow, sand). The demo battle shot takes `--terrain=<grass|snow|sand|dirt|swamp>`. Fixes session66 playtest
  finding 3 (the last open one there is the killed hero's level).
- **Session67 resource pickup sound (2026-10-24), committed with this HANDOFF update:** `resource_pickup` (every resource but gold, campfires,
  the windmill) remade louder (ElevenLabs: logs and stones dropped onto a cart, a wooden thud and stone clack, a short
  chime); take 3 of three, peak -1.6 dB, low/mid/high 3.64/2.59/0.48 (the old one -16.7 dB, 0.37/0.16/0.02). Old
  file and other takes in ignored `shots/session67/sfx_old/`.
- **Session67 garrison name (2026-10-24), committed with this HANDOFF update:** the battle result named a town's own garrison (no hero
  leading it) "Neutral creatures". `AdvRules.battle_vs_town` now passes `defender_town`, and
  `BattleLogic.side_name(side)` names a side by its hero, else "The garrison of <town>", else "Neutral creatures"
  ("The garrison of Brightwater — casualties"; screenshot in ignored `shots/session67/garrison_result.png`).
  Checked in `garrison_hero_test.gd`. This fixes session66 playtest finding 2.
- **Session67 quiet sounds (2026-10-24), committed with this HANDOFF update:** `mine_capture` and `death_undead` remade (ElevenLabs, prompts
  asking for a loud close-up sound: pickaxe strikes then a shower of coins; cracking bones clattering into a pile). The
  first of three takes each, measured in a window: mine_capture peak -1.6 dB, low/mid/high 0.34/0.43/1.05 (the old
  one -24.6 dB, almost silent); death_undead -0.4 dB, 1.57/2.38/2.41 (old -14.6 dB). Old files and the other takes
  in ignored `shots/session67/sfx_old/`. (resource_pickup, -16 dB, was remade after; footstep_horse is played at
  -12 on purpose.)
- **Session67 archer sound (2026-10-23), committed with this HANDOFF update:** the user disliked the archers' shot. New `arrow_shot`
  (ElevenLabs: a longbow volley, a full woody thrum and the rush of arrows, no plucked twang), the fullest of four
  takes measured in a window (peak -2.2 dB, low/mid energy 2.68/0.79 with a moderate whoosh 0.31; the old one
  peaked at -8.3 dB with little body, 1.04/0.75/0.05). Used by archer stacks and arrow towers; the ballista has its
  own. Previous versions and the other takes are in ignored `shots/session67/sfx_old/`.
- **Session67 ballista sound (2026-10-23), committed with this HANDOFF update:** the user liked the new catapult sounds but found the
  ballista "like someone shooting a little elastic": it used the archers' bow-string `arrow_shot`. New
  `ballista_shot` (ElevenLabs: a heavy siege-crossbow thunk with creaking timber, no high twang), the deepest of
  three takes (low 40-400 Hz to high 2-8 kHz energy 22.6, vs 12.6 and 16.1), peak -1.9 dB; `battle._anim_attack`
  plays it for the ballista, archers keep the bow string. One new battle visual test check (54).
- **Session67 catapult sounds (2026-10-23), committed with this HANDOFF update:** the user heard nothing when the catapult hit or missed.
  The catapult played `arrow_shot` on launch and `blunt_hit` on impact, and measured in a window these peaked at
  -21 dB and -33 dB (every other effect about -1 to -2 dB): effectively silent. New sounds (ElevenLabs,
  `tools/audio/gen_audio.py`): `catapult_launch`, `catapult_hit` (a boulder crashing into stone), `catapult_miss` (a
  splash and thud short of the wall), all about -1 dB; `battle._anim_catapult` plays them. `blunt_hit` (also every
  Zombie and Monk attack) was regenerated (now -1.1 dB, best of three takes) and `arrow_shot` (every arrow) too
  (now -8 dB). The old files are kept in ignored `shots/session67/sfx_old/`. Other effects measured: the quietest
  left are mine_capture (-20 dB), resource_pickup (-16), death_undead and footstep_horse (-14). Three new battle
  visual test checks (53): a catapult hit and a miss are heard.
- **Session67 hero animation (2026-10-23), committed with this HANDOFF update:** the user, playing with Lady Seraphine, found her sitting
  with the mace raised in every pose (standing, galloping, in battle) and the still battle heroes unnatural; they
  chose "rest pose + battle anims". (1) The Cleric was repainted with the mace resting on the shoulder: the map
  standing figure and four gallop frames (`tools/art/map_class_paint.py`) and the battle figure
  (`tools/art/hero_class_paint.py`). (2) As the classic, every battle hero (Knight, Cleric, Necromancer, Death
  Knight) now idles now and then (a 4-frame loop: the horse lowers its head, swishes its tail, lifts a hoof) and acts
  out each spell it casts (the Knight raises a glowing hand, the Cleric the glowing mace, the Necromancer the
  blazing staff, the Death Knight the green-glowing sword): `tools/art/battle_anim_paint.py` (imagegen/batch33),
  `battle._hero_loop` / `_hero_cast`. Four new battle visual test checks (50) and a `--case=cast` shot. Seen in
  `shots/session67/battle_rest.png`, `battle_cast.png`, `battle_cast_cleric.png`, `anim_scale2.png` (every frame at
  battle size), `map_rest_zoom.png`. The idle frames differ a little from one another in the painting (a cape that
  sways, the horse's head); played quickly they read as movement.
- **Session67 map hero pennant (2026-10-23), committed with this HANDOFF update:** the user found the hero's flag on the map oversized and
  hanging low, and the owner-coloured outline around the whole figure unnecessary with a flag. Now, as the classic,
  a small pennant (58 px, was 100) on a pole rising from behind the rider flies above its head, mirrored with the
  hero's facing (`MapView._face_flag`, `HERO_FLAG_H`, `HERO_FLAG_FOOT`; also on each step), and the figure has only the
  ink outline. Three new map figure test checks (18). Seen in `shots/session67/flag_before_zoom.png`,
  `flag_after3_zoom.png`, `figs_zoom.png` (all four classes) and `left_zoom.png` (facing left).
- **Session66 AI round (2026-10-23), committed with this HANDOFF update:** the user asked for the §8 plan's AI round, then the playtest.
  Steps 1 and 4 were done in session52; this round did steps 2 and 3 with step 4's validation against the policy
  just pushed (frozen as `tools/ai/adventure_ai_session65.gd`, control 0.00). Kept two changes
  (**`docs/AI_COORDINATION.md` "Session66"**): (a) a full army swaps its weakest stacks for a courier's or a
  garrison's stronger ones (whole stacks, nothing lost, the donor keeps creatures, a threatened gate keeps its
  hold), which lets the saved armies of seven different creatures consolidate; (b) a computer garrison hero steps
  out to the gate each turn and decides again (session65's hero stayed inside, unable to strike a raider, until no
  army could reach the town). **Final validation on reserved fresh maps, 84 days, vs session65: two-player
  33/15/0, +37.50 ± 20.19; four-player 15/17/0, +29.17 ± 15.11: both intervals exclude zero.** Against the older
  session54 policy the kept version and session65 score about the same on development maps, so most of the gain is
  undoing session65's stuck garrison heroes. Replays: 415/1 and 427/0 won 16–18 days sooner, 409/1 and 444/0 end
  with much larger armies but still in legal standoffs, 412/1 ends with one town instead of three. 104 adventure AI
  checks, 29 garrison hero checks (31 with the playtest fix below).
- **Session66 Haven playtest (2026-10-23), committed with this HANDOFF update:** step 5 of the plan. The assistant played
  "The Shattered Crown" (Normal, Haven, Lady Seraphine, a Cleric) through the real UI with the remote-play harness
  on `user://playtest_save.dat` (the player's save hash-checked unchanged). **Outcome: victory on day 27** (Month 1,
  Week 4, Day 6), every Blue hero beaten and all four towns held. The computer applied real pressure: it took every
  town left empty (Aurelia twice, Kingsbridge, Brightwater), recruited in captured towns, rehired heroes each time,
  beat Seraphine at Aurelia's gate on day 21 and took her artifacts (won back by Gareth on day 22); its armies stayed
  small and never beat a strong army in the field. Exercised this session's work in play: the town list, the
  garrison slot (move in, swap, troops join, Tavern at the freed gate and its refusal with a hero at the gate),
  class map and battle figures, battle colours, guarded artifacts, retreat-free hero battles, sieges, level-ups,
  Mage Guild announcements, week changes, Ctrl+S and Load. **Two bugs fixed in play:** (1) recruiting in a town
  held by a garrison hero put the recruits in the hidden town garrison: `town_screen._recruit_tier` now recruits into
  `AdvRules.town_army`, and troops already stranded there join the hero when the town opens (two garrison hero test
  checks); (2) session57's "unconfirmed" missing right-click popup: after a scene change `adventure._process` hid the
  hover panel because the OS cursor was outside the map, which only the harness can cause (it moves the input
  events, not the OS cursor); the map now tracks the cursor from mouse events (`adventure._mouse`). Harness gained
  `hoverstate`. Findings in §8 "Playtest findings (session66)"; evidence `shots/session66/play/` (`findings.md`,
  `p###.png`, `q###.png`).
- **Session65 computer garrison heroes (2026-10-23), committed with this HANDOFF update:** the computer players now use the garrison as
  the classic's do. A computer hero that holds a threatened town from its gate (`AdvAI._defense` returning "hold")
  moves into the garrison in `run_turn` (`choose` stays side-effect free: it sets `AdvAI.holding`), leading all the
  town's troops behind the walls (`AdvAI._garrison`; it stays at the gate
  when they don't fit), which frees the gate for the Tavern. At the start of a later day it comes out once no army
  can reach the town (`_release_garrisons`, before `manage_towns`; replaced in session66 by a step-out each turn). The AI's defence estimates count a garrison hero
  (`_town_hold` in `_defense`, `_counterattack`, `_leave_rear_guard`), and a hero at an enemy gate with a garrison
  hero inside is met alone. 8 new checks in `tools/garrison_hero_test.tscn` (27). In a traced simulated game
  computer heroes went into garrisons and came out again a day or more later.
- **Session64 map hero figures per class (2026-10-23), committed with this HANDOFF update:** as the classic (each hero class has its own
  adventure map figure), the Cleric and the Necromancer now ride their own figures on the map: new
  `heroes/map_cleric.png`, `map_necromancer.png` and their four gallop frames each, the faction figures' horses in
  the same poses repainted with a mace-raising Cleric in white and blue and a hooded Necromancer with a skull staff
  (`tools/art/map_class_paint.py`, imagegen/batch32, all five poses in one sheet). The Knight keeps `map_haven`, the
  Death Knight `map_necropolis` (a dark lance knight). `MapView.hero_figure` picks the figure (its gallop frames by
  the same name). The new standing figures have the gallop frames' short synthetic shadow, not the Blender
  renders' long one. New `tools/map_figure_test.tscn` (15 checks) in the full suite; seen in
  `shots/session57/map_figures.png` and `map_figures_gallop.png`.
- **Session63 battle colours (2026-10-23), committed with this HANDOFF update:** playtest finding 8. Checked against the classic (VCMI's
  `BattleStacksController`, the engine re-implementation: the amount box is chosen by the stack's spells only,
  never by side or owner). The user chose: count boxes as the classic, purple, green under good spells only, red
  under bad ones only, yellow under both (`battle._Badge.mood`); the rings, turn queue cards, hero name plates and
  spell banners in each player's flag colour instead of attacker red / defender blue, neutral creatures grey
  (`battle.side_color`). New shot flags `--players=a,b` and `--effects=...`; 6 new checks in the battle visual test;
  seen in `shots/session57/colors_blue_attacks.png` (Blue attacking, the three spell box colours) and
  `colors_neutral.png` (Green against grey neutrals).
- **Session62 retreat and war machines (2026-10-23), committed with this HANDOFF update:** playtest finding 9. The rule: a retreated hero
  keeps all artifacts and loses the army (Heroes 3 wiki, Retreat); war machines are equipment in the hero's own
  slots (they can't go in the backpack or be dismissed), so they stay with the hero, unless destroyed in the battle.
  No source states the machines case outright; this follows the artifact rule. The game already did this
  (`battle_logic.machines_left` on the hero, `AdvRules._kill_hero(kept)`, `GameState.tavern_hero`); only the
  battle's result window listed the retreating side's standing machines among the casualties. Fixed in
  `battle._lost`; new `tools/retreat_test.tscn` (10 checks) in the full suite; result window seen in
  `shots/session57/retreat_result.png`.
- **Session61 town list click (2026-10-23), committed with this HANDOFF update:** as the classic (the HoMM3 manual's selector buttons; the
  hero list works so since session60), a first click on a town in the adventure panel's town list selects
  it and centres the map on it, a click on the selected town opens the town screen. Selecting a town drops the hero
  selection (one or the other, as the classic): the town's button is shown pressed, the status window shows the
  town (picture, fort, income, today's build, its garrison or garrison hero's army), Sleep is dimmed; a hero click
  selects the hero again. The town stays selected on the way back from its screen. Code:
  `adventure.select_town/_select_town/selected_town`, `adventure_hud._town_card/_town_view`; new
  `tools/list_click_test.tscn` (15 checks) in the full suite; panel seen in `shots/session57/list_click_town.png`.
- **Session60 garrison hero and hero-list click (2026-10-23), committed with this HANDOFF update:** the user approved playtest findings 2 and
  3. (3) A click on a hero in the adventure hero list now selects and centres the hero; a click on the selected one
  opens the hero screen (as the classic). (2) The garrison hero, as the classic (rules confirmed: the Heroes 3 wiki's
  Tutorial and Tricks pages, a Heroes Community thread): one hero per town may wait in the garrison, off the map,
  leading the garrison's troops (they join its army; the move is refused when they don't fit), so the gate is free
  for the Tavern; in the town screen a portrait clicked once is picked, a click on the other row moves or swaps the
  heroes, a second click on the picked one opens the hero screen. The garrison hero defends the walls in a siege; a
  hero also standing at the gate is fought first in the open. Garrison heroes cannot move, are skipped by "next
  hero" and the end-turn warning, and the AI counts them in a town's defence (it garrisons its own since session65).
  Code: `AdvRules.garrison_hero/town_army/visiting_hero/enter_garrison/leave_garrison/swap_garrison`,
  `town_screen._hero_slot`, `adventure._interact_with`; new `tools/garrison_hero_test.tscn` (19 checks) in the full
  suite; town screen seen in `shots/session57/garrison_hero_town.png`. Old saves load unchanged (no garrison heroes).
- **Session59 small battle fixes (2026-10-23), committed with this HANDOFF update:** the user asked for playtest findings 4-7. (4) A right
  click on a battle stack opens its live card (`battle.gd._show_stack_card`: the hover panel's content, with the
  battle's numbers, the spells on it and their rounds left, and what changes them) instead of the book stats.
  (5) Haste, Slow and Cure cast mid-round re-sort the stacks yet to act (`BattleLogic._resort_order`, one comparator
  `_turn_before` for every turn order), as the classic; checked by `battle_test._speed_spells` (fails on the old
  rules). (6) "raises 1 skeleton" in the singular (`Necromancy.message`, two new necromancy test checks).
  (7) Each hero class has its own battle figure, as the classic: new `heroes/battle_cleric.png` and
  `battle_death_knight.png` (the faction figures' horses repainted with a mace-wielding Cleric and a horned,
  great-sword Death Knight, `tools/art/hero_class_paint.py`, imagegen/batch31); `battle.gd` takes
  `heroes/battle_<class>.png`, else the faction's (Knight, Necromancer). Screenshots `shots/session57/card.png`,
  `heroes_kd.png`, `heroes_cn.png` (new shot flag `--heroes=attacker,defender`). The adventure map still has one
  hero figure per faction (done in session64).
- **Session58 guarded treasure fix (2026-10-23), committed with this HANDOFF update:** the user asked to fix playtest finding 1. A hero
  who walked onto an artifact (or any pickup) beside a monster fought the monster and then stood on the treasure
  without it. Now, as the classic, the treasure is taken after the guard is beaten: `move_hero` remembers the
  target as `hero["visit_after_guard"]` and `_visit_after_guard` visits it after a won fight (a computer's
  quick-resolved fight in the same move; the human's in `_post_ready` after the battle scene); a lost or fled fight,
  a second guard still beside the tile, or a moved object leave it. New `tools/guard_pickup_test.tscn` (14 checks;
  4 fail on the old code) in the full suite; the find after a real battle seen in
  `shots/session57/guard_pickup_found.png`.
- **Session57 siege polish and machine wrecks (2026-10-23), committed with this HANDOFF update:** the user approved finishing the sieges
  (step 1 of three offered) and asked that the destroyed First Aid Tent and Ballista look correct. Before: the tent
  and ammo cart had no wreck and tipped over as faded ghosts; the ballista's wreck showed as a flat silver heap
  (the creatures' grey corpse tone on wood) and, drawn at a tenth of its 1655 px size without mipmaps, speckled.
  Now: wrecks for the tent, ammo cart and catapult (`tools/art/machine_wreck_paint.py`, batch30), every wreck
  resampled to about 1.5x its on-screen size, and wrecks keep their painted colours. The Castle's lower tower (at
  the command bar, only its top shows) had a conical roof with its archer on the spire: it now has a crenellated
  top like the upper tower (`siege_levels_paint.py retop`, its two nearby breaches repainted). A segment hit once
  now shows a painted battered overlay (34, `siege_levels_paint.py damage`) instead of drawn cracks that looked like
  stick figures. Verified in screenshots (`shots/session57/wreck_after2.png`, `castle_h.png`, `bat_*.png`,
  `bat_zoom.png`), `battle_visual_test` 40/40 and the full suite (`shots/session57/tests.log`). Known: on the black
  Necropolis stone the chips are painted pale (like its merlon tops).
- **Session57 Necropolis playtest (2026-10-23), with this entry:** step 2 the user approved. The assistant played
  "The Last Champion" (Normal, Necropolis, Kragor the Pale; Vesna hired) through the real UI with the remote-play
  harness, on `user://playtest_save.dat` (the player's save hash-checked unchanged). **Outcome: defeat on day 9
  (Month 1, Week 2, Day 2)**, when the champion Kragor fell to the Green AI's Ilsa Grimveil next to Brightwater.
  Exercised: building (Citadel, Mage Guild, Tavern, Archers' Tower), recruiting, Tavern hire, chests, campfire,
  sawmill, a creature dwelling, artifacts, guarded resources, 12 battles (spells by hand, manual moves, Auto), a
  real Fort siege of a neutral town with the battered gate and wall overlays visible, retreat, losing both towns
  to the AI while their hero was away (and retaking one), level-ups, the week change, Ctrl+S, menu Load, looting
  of artifacts, the scenario's defeat. Opponent pressure was **real** this time: the two AIs took both towns when
  left empty, and their heroes came back for the town and the champion. Findings are in §8 under "Playtest findings
  (session57)"; one confirmed bug (guarded artifacts are not picked up after the fight). Evidence in ignored
  `shots/session57/play/` (`findings.md`, `p###.png`, `q###.png`).
- **Session56 sieges and town pictures by fortification (2026-10-23), committed with this HANDOFF update:** the user reported that a town
  always looks like a castle on the map and in a siege, and that an enemy knight walked out "at the top where there
  isn't a gate". Cause: one map picture and one siege painting per faction for every level, and a painting whose tall
  towers covered rows 0-2 and 6-10 while the rules put breakable wall on rows 1-2 (a breach there let units walk
  through the painted tower); the Fort also had a moat (HoMM3: the Citadel's). Now, as HoMM3: a Fort is a wall and a
  gate, a Citadel adds the moat and the keep, a Castle the two round towers; the corner segments are never walkable
  and only a Castle's can be hit. New siege paintings per level and faction with the wall laid out on the rules'
  segments (towers rows 0 and 10, wall 1-2, 3-4, 6-7, 8-9, gate 5) and 34 breach overlays
  (`tools/art/siege_levels_paint.py`); new map pictures: a village without a Fort, a walled town with a Fort or
  Citadel, the old castle with a Castle (`tools/art/town_levels_paint.py`, `MapView.town_sprite`). The old single
  siege paintings were removed. `battle_test` gained the siege rule checks. Verified in screenshots
  (`shots/session56/siege_{h,n}{1,2,3}.png`, `crew.png`, `map_levels.png`, `map_village.png`) and the full suite.
  Known: the painted wall cracks (`_Cracks`, a stretch hit once) look like small dark stick figures up close; the
  lower Castle tower is mostly under the command bar, its archer on its roof.
- **Session55 AI round: calling heroes back (2026-10-23), committed with this HANDOFF update, nothing kept in the AI:** the user chose
  "heroes come home or join up when a strong army approaches". `town_defense_report` now prints a RECALL line:
  returning heroes could have held about 40% of captured towns but almost never a player's last town (1 of 34
  two-player, 2 of 33 four-player). Five `_defense` variants (lower hold/recall margins, a two-day horizon) against
  the frozen session54 policy (`tools/ai/adventure_ai_session54.gd`, control 0.00) were neutral or worse, the most
  defensive clearly worse on four-player maps (`docs/AI_COORDINATION.md` "Session55"). `adv_ai.gd` is unchanged.
  Open: the AI-vs-AI benchmark may undervalue defence against a human's single strong army.
- **Session54 AI round: town garrisons (2026-10-22), committed with this HANDOFF update:** the user chose playtest finding 2 (the AI's
  capital taken empty). New diagnostic `tools/ai/town_defense_report.tscn` showed most captured towns were empty and
  reachable by the capturer. Kept, after measuring eight variants (`docs/AI_COORDINATION.md` "Session54"): a hero
  collecting a garrison leaves what holds the gate against an army able to reach it next turn, if the garrison can
  hold it (`AdvAI._collect_garrison` / `_garrison_keep`); a gate defender strikes a raider at 1.3x (was 1.6x).
  Frozen previous policy `tools/ai/adventure_ai_session52.gd` (control 0.00). Final validation on fresh maps,
  84 days: two-player 29/19/0, +20.83 ± 24.01; four-player 11/20/1, +15.05 ± 19.85: all results point the same way,
  intervals include zero. Fewer empty towns are taken (four-player 352 -> 260) and games end sooner. Seven new
  checks (94 adventure AI checks). Not addressed: heroes still wander one at a time, and a garrison cannot hold
  against a much stronger main army.
- **Each hot-seat player makes their own choices (2026-10-22), committed with this HANDOFF update:** the user asked that every player
  pick their own town, hero and bonus, and to keep the "To Arms" call. The Players row is one button per colour
  ("Human / <town>" or "Computer"): a click on a computer's colour makes it a person and the left side (town,
  hero, bonus cards, headed "Blue Player: choose your faction" with the colour's pennant) then shows and edits
  that colour's choices; a click on a person's colour shows theirs; a second click hands it back to the computer
  (choices kept). A hero another player leads is greyed (no two players share one); a new person starts on a town
  no earlier player took. Settings `seat_faction` / `seat_hero` / `seat_bonus` (Red's stay `faction` / `hero` /
  `bonus`); `WorldGen` uses them (a missing or clashing hero falls back to a random free one, a missing bonus to
  a random one). Screenshots `shots/session53/seats_c..f.png`, `start_a.png`; hotseat_test now 46 checks.
- **Hot-seat multiplayer (2026-10-22), committed as `c4fe34f`:** the user agreed to the hot-seat milestone after the polish
  batch. New Game has a **Players** row, one button per colour; Red is you (seat choices: see the entry above).
  Extra humans get a human's starting resources for the difficulty; names become "Red
  Player", "Blue Player" (a one-human game is generated exactly as before, tested). The viewpoint is
  `GameState.human_player_index()`: the human whose turn it is, during computer turns the last human who moved
  (`GameState.viewer`, since session67 not saved). Each human turn in hot-seat starts behind a dark cover with "<Colour> Player's Turn" and a
  pennant (`adventure._start_human_turn`, `_cover`, `UI.flag_icon`); the first turn and a loaded game do the same
  (`GameState.handed_over / was_handed`, deliberately not saved). The new-week dialog reaches every human
  (since session67 each human's own `view["news"]`). Battles between humans are played by both from the screen (BattleLogic already took
  per-side control); the result is titled as the winner sees it. A computer attacking a human who is not at the
  screen first shows "To Arms, <Colour> Player!" behind the cover (an aid, not a rule). A human who falls is told
  "<Colour> Player Is Defeated" and the others play on (in a "lose your champion" scenario `AdvRules.eliminate`
  takes them out); a human who falls on their own turn passes it on; the last player standing wins. New
  `tools/hotseat_test.tscn` (33 checks, in the suite). Inspected `shots/session53/seat*.png`, `handover.png`,
  `blue.png` (Blue's own fog and resources in a real 2-human game) and `hotseat_defend.png`. Full suite passed.
- **Playtest polish (2026-10-22), committed and pushed as `1dfa88b` at the user's request:** the user approved fixing the remaining playtest findings.
  (1) Hero hidden behind a building: a claimed mine/visited windmill is rebuilt (`MapView.refresh_object`) and added
  after the hero at the same y-sort depth; `MapView.hero_foot` now sits 1px lower, so a hero in a doorway always
  draws in front. Verified by claiming the Ore Pit in the real game (`shots/session52/mine_after.png`).
  (2) Sand decoration no longer uses `decor_sandstone` (its orange slab heap read as a resource pile); its weight went
  to `rock_1`/`rock_3`. New maps only: saves keep their stored decor.
  (3) Right-click on the map is the classic held popup: the hover panel shows at once while the button is held and
  closes on release (was a one-line toast). Heroes also show their army (own: exact counts, others: count words),
  own towns their garrison. Verified with held right clicks (`rc_monster.png`, `rc_hero.png`, `rc_town.png`,
  `rc_released.png`). Remote harness gained `rtile x y seconds [shot]`. Full suite passed (`tests6.log`).
- **Announcements (2026-10-22), committed and pushed at the user's request:** after playing, the user asked for captured artifacts and town learning
  to be announced. (1) The battle result now says "<winner> captures <loser>'s artifacts:" with icons and names of
  every worn and carried artifact the defeated hero had (not when it retreated or surrendered: it keeps them);
  `AdvRules._loot` already transferred them silently. (2) Entering an own town: the "Learned: ..." toast was shown
  and immediately hidden by the town scene change. `adventure._enter_own_town` now builds a report (spells learned,
  spell points restored) passed in `GameState.pending_town["report"]`; the town screen shows a "Mage Guild" dialog
  with the spell icons and the restored points, nothing when there is nothing new. The same dialog announces spells
  learned when a Mage Guild level is built with a hero in town or a hero is hired there (which now also follows the
  Wisdom rule instead of always level 1–2). New `Modal.add_icon_flow`. New `tools/announce_test.tscn` (10 checks,
  in the suite). Inspected `shots/session52/announce_battle.png`, `announce_town.png`. Full suite passed (`tests5.log`).
- **Optional seven-day rule (2026-10-22), committed and pushed at the user's request:** the user asked for HoMM3's "lose without a town" rule as an
  optional setting. New Game shows **"Without a town: Play on / 7 days"** (default Play on = previous behaviour;
  saved as `world["townless_limit"]`, old saves read 0). With 7 days: a player who loses every town counts down 7..1
  (`AdvRules.capture_town`/`tick_townless` in `new_day`), the human sees "Without a Town" at the start of each such
  day, capturing any town stops the count, and at the end the player's heroes leave the map and it is defeated
  ("Seven days have passed without a town..."). Defeat texts in the menu and briefing mention it. A townless AI under
  the rule accepts a town assault at 1.1x instead of 1.4x and values it 3x. Tournament `--townless=7` plays with it.
  Eight new checks (87 adventure AI checks). Screenshots inspected: `shots/session52/tl_option.png`,
  `tl_brief.png`, `tl_warning.png`. Full suite passed (`tests4.log`); player's save unchanged. Measured afterwards
  (`docs/AI_COORDINATION.md`): it ends few AI games (5 -> 4 of 32 at the limit on maps 1700–1707; the nine saved
  stalemates unchanged), because stalled games are between players who all still hold towns.
  `campaign_resume_test --townless=7` added.
- **Session52 AI round (2026-10-22), committed and pushed at the user's request:** §8 steps 1 and 4 done; steps 2–3 partly (see
  **`docs/AI_COORDINATION.md` "Session52"**). Frozen baseline `tools/ai/adventure_ai_session51.gd` (`555fedc`,
  control 0.00 ± 0.00); resume tool `--before=`. Kept one change, `AdvAI._leave_rear_guard` (a hero leaving a town an
  enemy can reach next turn leaves enough troops to hold it when that costs at most 25% of its army). Rejected after
  measurement: a danger filter (heroes avoiding stronger enemy reach) and leader-only garrison collection.
  **Final validation on reserved maps: two-player 23/25/0, -4.17 ± 14.64; four-player 7/24/1, -2.42 ± 4.83: no
  demonstrated strength change.** Replays: 427/0 and 425/0 keep one more town, others unchanged. 79 adventure AI
  checks; full suite passed (`shots/session52/tests3.log`). The user then asked for HoMM3's seven-day townless
  rule as an option (entry above).
- **Session52 checkpoint (2026-10-22), this commit (pushed at the user's request):** the user approved fixing playtest findings 1 and 3 (map access,
  meeting by click). AI work (§8 steps 1–4) is next and not started.
  - **Map access.** `WorldGen._reachable` now uses the game's movement rule (a diagonal needs a free orthogonal
    side tile; the old flood let heroes squeeze between two touching corners). Diagonal road steps keep one corner
    tile clear. New `_ensure_access` runs after all objects are placed: anything the first town cannot reach is
    connected by clearing the cheapest trees/rocks (their decor sprites are removed), or, if only water, mountains
    or buildings block it, removed from the map. 36-map sweep before: unreachable objects on 35 maps (about 390
    objects); after: **0**, with 5 objects of about 6,000 removed. Every generated map changes (scenario maps
    too, so judge adventure shots will differ from judge 47). Existing saves keep their maps.
    Visual check: cleared tiles in the "Shattered Crown" map read as ordinary grass (`shots/session52/v002c.png`).
  - **Meeting your own hero by click** (HoMM3 behaviour): with a hero selected, a click on another of your heroes
    shows the route and the status line "Meet <name> (trade troops)"; a second click walks over and opens the
    existing Hero Meeting dialog. An unreachable hero is selected as before; the side-panel hero cards still select.
    Verified with real clicks in the game (`v004_route.png`, `v005_meeting.png`, `v006_traded.png`: troops merged,
    the last stack stays).
  - **Artifact trading at meetings** (user-approved): under each hero's army the Hero Meeting dialog lists that hero's
    worn artifacts, then "Backpack:" and the carried ones. A click hands one to the other hero, who wears it if the
    slots are free, else carries it (`GameState.transfer_artifact`); a combination moves whole, a completed set merges
    and is announced, movement left never grows. Simplification: HoMM3 drags between two paper-dolls; here a click
    hands over. The AI's meetings still exchange troops only. Captures: `meeting_before_c.png`, `meeting_after_c.png`.
  - New tests in the full suite: `tools/meet_test.tscn` (18 checks, including artifact hand-overs by real clicks) and `tools/map_reach_report.tscn` (36 maps, must
    report `maps_with_cut: 0`). Full suite passed (`shots/session52/tests.log`); the player's save is unchanged.
- **Session52 playtest (2026-10-22), included in this commit:** the user asked for the playtest (step 5 of the §8 plan) to
  come first. The assistant played one full campaign through the real UI with real mouse/key events: scenario
  "The Shattered Crown" (conquer), Haven, Sir Aldric, Normal, one Necropolis AI. **Victory on day 13
  (Month 1, Week 2, Day 6)**. Exercised: New Game, briefing, building (7 builds), recruiting/merging, Tavern hire
  and rehire, chests, campfires, mines, windmill, artifacts, guarded mines, 18 battles (manual and Auto), sieges
  of neutral and enemy towns (one lost, the rest won), level-ups with skill choices, week change, Ctrl+S
  save and menu Load, town loss and recapture, the final Victory dialog. **Not exercised:** Necropolis as the
  human, spells cast by hand, marketplace, mage-guild learning, four players, retreat/surrender as the human.
  Opponent pressure was **low**: the AI's capital Gravenmoor fell with an empty garrison and no hero inside,
  its heroes came one at a time, and two attacks on my empty towns were the only threat. This is one game by an
  assistant, not a human difficulty judgement. Findings are in §8 under "Playtest findings (session52)".
  The player's own save was hash-checked before and after (unchanged); the playtest used `user://playtest_save.dat`.
  New: remote-play mode in `scripts/core/shot.gd` (`--remote=<dir>`, see ARCHITECTURE.md) with
  `GameState.save_path`; diagnostic `tools/map_reach_report.tscn`. Screenshots/logs under ignored `shots/playtest/`.
- **Planning follow-up (2026-10-22), documentation, included in this commit:** after the push, the user asked what comes
  next and whether this handoff contains the full plan. The proposed next session is now recorded at the start
  of section 8, including priorities, evidence, validation and completion criteria. Implementation has not
  started. Previous pushed checkpoint: **`555fedc`**; use `git log -1` for this one.
- **Session51 pushed coordination checkpoint (2026-10-22), `555fedc`:** `Improve AI reinforcement coordination and clear allied routes`.
  The user requested committing and pushing this work and the preceding local checkpoint **`eb2c96c`** to
  `origin/main`; both were pushed and the remote hash verified. Previous pushed checkpoint: **`f69ad3a`**.
  No new art, presentation changes, save fields, game rules or judge score.
  - `AdvAI._assault_rally` previews several same-day donors together and moves them before the main army if
    their combined troops enable a nearby assault. Required defenders are excluded; normal slots/transfers,
    one creature retained per donor, at most one normal day's travel. Ordinary deliveries remain half-day trips.
    `run_turn` recomputes this transient plan after a battle; no migration required.
  - `_plan_with_passage` previews a leader's blocked route with eligible allies temporarily removed from the
    AStar solid grid, then restores it. A blocker takes a legal one-step move off the route, paying normal
    movement; the leader replans afterward. Never moves a gate hero/assigned defender or steps onto occupied/
    guarded ground. Idle heroes retain unused movement so they can yield to a later army the same turn.
    Occupied shops/dwellings no longer provoke useless meetings; useful troop exchanges remain allowed.
  - **75 adventure AI checks pass**, including actual paired deliveries -> same-turn conquest, earlier idle
    helper -> paid step aside -> later leader attacks, defense/slot/movement limits and occupied-site behavior.
    `tools/ai/adventure_ai_session49.gd` is the frozen **`f69ad3a`** comparison, verified against committed source
    after subclass adaptation. Existing frozen baselines unchanged. New `tools/campaign_resume_test.tscn`
    compares copied session50 snapshots with identical explicit seeds (snapshots lack their original RNG state).
  - Diagnostic **441/1 wins on day 169** with the rally; frozen policy still unresolved at day 197. Of nine saved
    cases, 415/1 finishes with both policies and seven remain unresolved with both. Not every outcome improves:
    427/0 ends the diagnostic window with zero towns versus one before. See **`docs/AI_COORDINATION.md`** for
    reproducible commands, experimental history, all limitations and raw-log locations under `shots/session51/`.
  - **Final fresh validation vs `f69ad3a`, 84 days:** 24 two-player size-36 maps / 48 games (1100–1123):
    **21 wins / 23 losses / 4 unresolved**, score **-3.12 +/- 8.68 (2 SE)**, 1126 instant battles.
    Eight four-player size-48 maps / 32 games (1200–1207): **9 / 22 / 1**, **+7.78 +/- 10.22**, 1875 battles.
    Both intervals include zero: targeted behavior fixes, **no demonstrated general strength gain** and cannot
    rule out a regression. No tuning followed final validation. Same-policy session49 control remains 0.00 +/- 0.00.
  - **Full suite passed** (`tests-final.log`): compile; 40 battles; 25 visual; 15 battle AI; 75 adventure AI;
    63 week; 29 flow; two/four-player zero-difference controls; 4096 glow phases; 33 camera; 227 factory;
    46 Necromancy; 31 clicks/drag/queued click; five visits; 306 artifacts; `SIM DONE`. `project.godot` restored.
  - Next: follow the proposed plan at the start of section 8; investigate defense/conquest tradeoffs
    (especially 427/0), incompatible full armies and remaining long games; use new map IDs for later validation.
    Human competitive play, fog/map spells/difficulty, remaining machine wrecks and hot-seat remain open.
- **Session50 validation checkpoint (2026-10-22), `eb2c96c`:** `Validate multiplayer campaigns and tactical save flow`.
  The user accepted the next session's larger/four-player validation, unfinished-game investigation and real
  battle/save-flow checks, then asked to continue. Included in the session51 commit/push request above.
  This checkpoint left production AI/rules unchanged; no new art, visual change or judge score.
  - Four-player harness now rotates the candidate through every seat, continues after early eliminations and
    distinguishes candidate losses/unresolved outcomes from all games reaching the limit. New `--players`,
    `--size`, `--maps`, `--dump` options; two-player defaults/statistic preserved. See
    **`docs/CAMPAIGN_VALIDATION.md`** for exact commands, definitions, limitations and the 17-case outcome table.
  - **64 four-player games / 16 fresh maps, 84 days**, against frozen `4f126ec`: size 48 (600–607),
    **11 wins / 20 losses / 1 candidate unresolved**, score **+15.50 +/- 24.86 (2 SE)**, 2818 instant battles;
    size 64 (700–707), **11 / 19 / 2**, **+14.36 +/- 17.05**, 3362 battles. Both intervals include zero:
    no demonstrated general four-player strength gain. Rotated seats are correlated; errors are across maps.
    Thirteen size-48 and five size-64 games reached the limit, including games where the candidate already lost.
    Same-policy four-player 84-day control: **0.00 +/- 0.00** on two maps. Logs: `shots/session50/large*.log`, `control4.log`.
  - All **17** unfinished session49 cases reproduced. At **168 days**, eight finish (four current wins/four losses)
    and nine remain. Final snapshots show gate-holding, divided forces below individual assault thresholds and
    continued town exchanges. In 427/0, allied heroes also block the leader's route; removing them in a copy restores
    it, but the army is still below the safe assault threshold. These are open strategy findings, not fixed stalls.
    New `tools/campaign_snapshot_report.tscn` reads final worlds and diagnoses routes/force/defense decisions.
    JSONL end-turn owner records are different instants; use final snapshots for synchronized town ownership.
    Local evidence: `unresolved.jsonl`, `states/`, `states168/`, `extended168.log`, `snapshot-report.txt`.
  - New **`tools/campaign_flow_test.tscn`, 29 checks pass windowed and headless**: actual human attack -> tactical
    Defend/Auto -> victory -> level-up -> adventure, exact XP/casualties/Necromancy, isolated save/reload and movement;
    End Turn -> AI attack -> human retreat -> AI resumes once -> next human day -> save/reload. The player's normal
    save is hash-checked and untouched. Scripted button signals and isolated save API, not a competitive human
    playtest or menu-slot test. Viewed all seven captures under `shots/session50/flow/`; success log `flow2.log`.
  - **Full suite passed** (`shots/session50/tests.log`): compile; 40 battles; 25 visual; 15 battle AI; 54 adventure AI;
    63 week; 29 flow; two/four-player zero-difference controls; 4096 glow phases; 33 camera; 227 factory;
    46 Necromancy; 31 clicks/drag/queued click; five visits; 306 artifacts; `SIM DONE`. `project.godot` restored.
  - Next: focused defense/consolidation and allied-route coordination fixes using these reproducible cases,
    freeze `f69ad3a` before tuning, and validate on new seeds. Human competitive play, map spells/fog/difficulty,
    remaining machine wrecks and hot-seat remain open. Further commits/pushes require the user's instruction.
- **Session49 pushed checkpoint (2026-10-21), `f69ad3a`:** `Improve AI counterattacks and campaign reinforcement`.
  The user requested committing and pushing the tested AI improvements below to `origin/main`. Previous pushed
  checkpoint: **`4f126ec`** (`Add campaign benchmarks, AI coordination, and visual fixes`).
  No new art, visual changes, judge run or score.
  - Diagnosis: JSONL traces of 84-day campaigns show large armies pinned in their own towns by much weaker
    raiders. Example pair 211: a strength-117576 defender took no action on 13 of the final 14 days; pair 212
    had defenders stationary throughout those 14 days. Turns without action are observations, not proof of a
    bug by themselves; focused scenarios confirmed the unconditional hold policy. See `shots/session49/before*.jsonl`
    and `tools/campaign_trace_report.py`. Some games also simply needed more than 42 days to finish.
  - `AdvAI._counterattack` now lets a resident defender intercept a much weaker raider when the entire route
    fits today's movement, destination guards/garrisons are safe, and the remaining garrison can cover other
    reachable threats. Otherwise it holds as before. The progress guard also recognizes XP gained in a victory:
    defeating an adjacent weak enemy without casualties no longer discards the rest of the hero's movement.
  - `_reinforce` upgrades and merges identical carried stacks before collecting town troops, freeing slots,
    then merges again after new upgrades. Costs and creature counts are preserved. `dwelling_recruits` shares
    the exact affordable/carryable count between target selection and purchase (all resources, seven slots).
    Substantial nearby armies may deliver when their transferable troops make a previously unsafe enemy town
    attack viable (`_unlocks_assault`); ordinary short courier behavior remains. Delivery is still at most half
    a day's travel, one creature stays with the donor, and defense takes priority. No new save fields/rules.
  - Measured against the **frozen pushed policy**, `tools/ai/adventure_ai_checkpoint.gd` from `4f126ec`, not the
    older session47 baseline. Development: counterattack alone, 12 pairs at 84 days, 17 wins / 4 losses / 3
    unresolved, score +54.91 +/- 34.32 (2 SE); combined reinforcement version before the XP-progress fix,
    16 development pairs, 22 / 4 / 6, +57.30 +/- 23.36. No tuning followed fresh-map validation.
  - **Final validation, 48 fresh paired maps / 96 games, start=400**, same maps with sides swapped:
    **42 days: 48 wins / 11 losses / 37 unresolved, score +42.29 +/- 12.99 (2 SE)**;
    **84 days: 66 wins / 13 losses / 17 unresolved, score +54.01 +/- 14.53 (2 SE)**.
    Logs: `shots/session49/conquest-validation42.log`, `conquest-validation84.log`. This demonstrates a gain
    under the current benchmark: size-36 maps, two players, Haven/Necropolis, production instant AI battles.
    It does not establish human-battle balance or cover larger maps/four players. Score leads are not wins.
    The two day limits reuse the same pairs, not independent samples. Checkpoint self-control on two pairs
    remains exactly 0.00 +/- 0.00 (`control.log`). Frozen baselines must remain unchanged.
  - **54 focused adventure checks pass**, including real interception/continued movement, protecting a gate
    from a second threat, lethal guards, assault deliveries, slot freeing and exact resource payment.
    **Full suite passed** (`shots/session49/tests.log`): compile, 40 battles, 25 visual, 15 battle AI,
    51 adventure AI, 63 campaign week, zero-difference baseline control, 4096 glow phases, 33 camera,
    227 factory, 46 Necromancy, 31 clicks/drag/queued click, five visits, 306 artifacts and `SIM DONE`.
    The focused recheck passed 54 after adding three more guard/delivery assertions; production code was unchanged.
    New tools: tournament `--baseline` and `--trace`; driver movement/XP/army and end-turn kingdom JSONL events;
    Python trace summarizer. No new visual changes required screenshots in this session.
  - Next: playtest the improved opponent against a human; investigate the 17 unresolved validation games and
    validate larger/four-player maps before broader strength claims. Spell/army strength estimates remain
    approximate, and fog-information policy/map spells/difficulty remain open. War-machine wrecks and hot-seat
    are separate future work. This checkpoint's commit/push is authorized; future commits require the user's instruction.
- **Session48 pushed checkpoint (2026-10-21), `4f126ec`:** `Add campaign benchmarks, AI coordination, and visual fixes`.
  The user authorized committing/pushing this tested checkpoint, then investigating long AI campaigns and
  improving conquest/reinforcement decisions. Previous pushed commit: **`35ed2e6`**; use `git log -1` for this
  checkpoint's hash at that time. No new assets, judge run or score. Captures/logs are local under ignored `shots/session48/`.
  - `tools/campaign_week_test.tscn` passes **63 checks** through the production adventure controller: seven legal
    daily builds and resets, recruitment, walking to the factory and equipping all machines, a guard battle with
    Expert Necromancy, enemy turns, day-eight growth and midweek save/load of the full world. This is a scripted
    integration fixture, not a manual UI playthrough. It uses a unique test save; the player's save is untouched.
    `GameState` save/load/has-save accept an optional path; default and schema stay unchanged.
  - `AdvAI` retains viable multi-day targets, discourages duplicate errands to consumable/capturable sites, and
    lets nearby small armies deliver troops to the strongest hero (at most half a day's journey, army below 35%
    of the leader's strength). Transfers obey normal army slots and retain one creature with the donor; useful
    free meetings no longer exhaust movement. Town visits pay normal upgrade costs and evaluate only troops the
    visitor can carry. **35 focused checks pass**, including a real meeting followed by movement/collection.
    Defense still takes priority. Optional `hero.ai_goal={pos,day}` uses existing save serialization; no migration.
  - New benchmark: `tools/adventure_tournament.tscn`, production-controller adapter `tools/ai/campaign_driver.gd`,
    frozen pre-change policy `tools/ai/adventure_ai_baseline.gd` from `35ed2e6`. Final candidate on **48 fresh
    pairs / 96 games**, start=200, days=42: **14 wins, 10 losses, 72 unresolved**; normalized strategic-score
    difference **-3.93 +/- 10.02 points (2 SE)**, 2914 instant battles (`strategy-final.log`). **No demonstrated
    overall strength gain**; score leads are not wins. An aggressive courier trial was rejected after -17.11 +/-
    6.63 on eight development pairs; an intermediate policy scored -9.47 +/- 16.10 on 24 validation pairs
    (`strategy-heldout.log`). Final version restores ordinary hero order and fixes free-meeting progress.
    Same-policy control is exactly 0.00 +/- 0.00. Two shared randomness bugs were fixed: sound pitch uses a
    private generator; level-ups honor a supplied RNG or the seeded global stream instead of reseeding from time.
    Other presentation code still consumes global randomness; this is not deterministic online/saved replay.
  - Aligned siege figures shift at most 18px horizontally within their footprints; rings follow, depth order and
    combat cells are unchanged. Movement tweens retain control of moving units. **25 visual checks pass**;
    painted overlap in the fixed Ghost/Angel/Vampire fixture fell from about 686 to 312 samples (breathing causes
    small variation). Residual wing overlap remains; focused fading is still needed. The Necropolis battle hero
    has a modest rim/exposure lift against the towers. Inspected `distant-before/after.png`, `crowd-before/after.png`
    and `movement.png`. Two live auto-sieges also ran without script errors; inspected late frames
    `live-necro_1.png` and `live-haven_1.png` (four captures total). No new independent judge score or claim that
    every siege arrangement is solved.
  - Artifact twinkles use explicit triangle fans and skip invisible subpixel glints, avoiding concave-polygon
    triangulation at near-zero radius. `tools/artifact_glow_test.tscn` completed **4096 phase draws in a real
    window**, including threshold samples, with no polygon errors; inspected `glow-phases.png`.
  - **Full suite passed** (`tests.log`): compile; 40 battles; 25 battle visual; 15 battle AI; 35 adventure AI;
    63 campaign week; two paired same-policy campaigns at exactly zero difference; 4096 glow phase draws;
    33 camera; 227 factory; 46 Necromancy; 31 clicks/drag/queued click; five visits; 306 artifact checks; `SIM DONE`.
    Week/control/glow tools are now in the suite. An exit trap restores `project.godot` even on interruption.
  - Next: evaluate conquest/reinforcement priorities against the measured limits; further siege silhouette work
    without hiding unrelated figures. Map-spell planning, fog policy, difficulty, hot-seat and three machine
    wrecks remain open. This checkpoint's commit/push is authorized; further changes need their own instruction.
- **Last pushed checkpoint (2026-10-21), `35ed2e6`:** `Add factories and fix hero controls, necromancy, and camera follow`.
  The user requested committing and pushing all work so far to `wolfxxx/HeroesGPT`, branch `main`; the previous
  pushed commit was `b81b0c7`. This checkpoint includes all eight changes detailed below, their regression tools,
  the factory painting and its provenance, and the updated architecture/asset/credit docs. Use `git log -1` for
  this commit's hash. Final full suite passed (`shots/adventure_camera/tests.log`); the screenshots listed below
  were inspected during implementation. Screenshot files/logs remain local under ignored `shots/`; reproducible
  regression tools are tracked. No new judge score. Existing saves gain the fixes after saving and restarting;
  factories require a new map. Next: section 8 findings; further commits/pushes require the user's instruction.
- **Enemy-movement camera fix (2026-10-21), included in this checkpoint:** the user reported that visible enemies
  walked without the camera following. Only `_execute_move` (human input) previously set `_follow`.
  `adventure.gd.move_hero` now owns following for both sides, checking visibility on every step. Visible AI moves
  immediately come into view, then the camera tracks the animated sprite without changing the selected hero.
  Entering explored terrain acquires the camera; leaving it stops at the last visible tile. Fully hidden movement
  neither redirects the camera nor animates. Visits, occupied destinations and completed routes release follow;
  the existing human-turn selection returns the camera to your hero. Visibility uses the existing permanent
  explored map; no fog/scouting or save-format changes. Works in existing games after saving and restarting.
  Screenshot inspection exposed a timer/tween race that could leave a departing sprite stuck at the fog edge:
  `MapView.move_hero_step` now returns its position tween, and movement awaits `finished` before hidden steps.
  New `tools/adventure_camera_test.tscn` is in the full suite. Its windowed `-- --capture` run passed 33 checks,
  covering visible/hidden walks, both fog crossings, one-step and zero-step routes, multiple heroes, interactions,
  human movement and real End Turn -> AI target/path -> next day. Viewed captures in `shots/adventure_camera/`:
  `before_enemy`, `enemy_start`, `enemy_walking`, `entering_sight`, `leaving_sight`, `after_hidden_steps`,
  `actual_ai_turn`, `your_turn`; log `shots/adventure_camera_capture.log`. Full suite passed
  (`shots/adventure_camera/tests.log`): compile, 40 battles, 16 battle visual, 15 battle AI, 14 adventure AI,
  33 camera, 227 factory, 46 Necromancy, 31 clicks/drag/queued click, five visits, 306 artifacts and `SIM DONE`.
  No new art or judge score. Next: section 8 findings.
- **Necromancy repair (2026-10-21), included in this checkpoint:** the user reported an Expert hero receiving no
  raised troops. Found four concrete gaps: undead casualties were excluded; winning defenders never received the
  calculated reward; full armies with Skeleton Warriors silently failed to add basic Skeletons; instant AI battles
  omitted raising entirely. `scripts/battle/necromancy.gd` now shares the calculation across both battle paths,
  applying 10/20/30%, additive owned Amplifiers/artifacts, 100% cap, per-stack health/count limits and minimum one.
  Undead and destroyed machines count; towers, restored enemies and surviving retreaters do not. A full army with
  an upgraded stack gets two thirds as many; a free slot prefers the base creature. The existing custom Mantle
  continues to raise Zombies, with the same health and upgrade-slot rules. Rules reference:
  https://heroes.thelazy.net/index.php/Necromancy (original/SoD, not HotA's reduced rates).
  `BattleLogic.necromancy_casualties` keeps stacks separate; `AdvRules.apply_battle` gives the reward to either
  winning hero after restoring survivors. Victory UI shows the received type/count/portrait or a clear no-room /
  no-casualty explanation. The skill description now spells out all three ranks and the army-space rule.
  `tools/necromancy_test.tscn` passed 46 checks, including field/town defense and both instant-resolution winners;
  it is in `tools/run_tests.sh`. Full suite passed (`shots/necromancy/tests.log`): compile, 40 battles, 16 visual,
  15 battle AI, 14 adventure AI, 227 factory, 46 Necromancy, 31 clicks/drag/queued click, five visits, 306 artifact
  checks and `SIM DONE`.
  Local `shots/necromancy/capture.tscn -- --case=attacker|defender|no_room` stages the final casualty state, runs the
  real result dialog, clicks OK, lets the adventure scene apply the result, then inspects the army. All three flows
  passed; viewed `attacker_result/army.png`, `defender_result/army.png`, `no_room_result.png`: 100 fallen Skeletons
  give a full army 20 Skeleton Warriors (30 -> 50), while an incompatible full army explains why it gets none.
  Read-only save inspection found only an older day-1 Basic Kragor, so the user's live army/encounter is not known;
  an optional clarification was requested. No save was modified. **Save current play and restart to load the fix;
  it works in existing games for future battles, not retroactively.** No new art or judge score. Next: section 8 findings.
- **War Machine Factory (2026-10-21), included in this checkpoint:** the user requested the authentic adventure
  shop after discussing faction-specific Blacksmiths. New maps now place neutral factories, trying one near each
  starting region, selling Ballista (2500 gold), First Aid Tent (750), and Ammo Cart (1000). Stock is unlimited;
  each hero can own one of each, replace a destroyed machine, and revisit. Catapults are not sold. Town Blacksmith
  inventory remains faction-specific. Original/SoD prices: https://heroes.thelazy.net/index.php/War_Machine_Factory.
  `WarMachineShop` is in `scripts/ui/war_machine_shop.gd`; shared validation/payment is in `GameState`, called by
  both shops and `AdvAI` (1000-gold reserve, carts only for shooters, no pointless revisits). Existing hero slots,
  battle deployment/ammo and save serialization handle purchases. Gold updates in both modal and HUD immediately.
  `WorldGen._factory_access` verifies routes with proposed walls, reserving path cells AND diagonal side tiles so
  later building footprints cannot isolate a factory. New `MapView` sprite: `assets/map/war_machine_factory.png`,
  generated with built-in imagegen; native alpha retained, prompt in `tools/art/war_machine_factory_prompt.md`.
  **Existing saves keep their layouts: start a new game to find factories.** No save migration/schema change.
  New `tools/war_machine_test.tscn` (in the full suite) passed 227 checks: transactions, repeat visits by both sides,
  save-format round trip, equipment/battle ammo, AI, and 24 generated maps including all menu sizes and legacy 32.
  Full suite passed (`shots/war_machine_factory/tests.log`): compile, 40 battles, 16 visual, 15 battle AI, 14 adventure
  AI, 227 machine checks, 31 map clicks/drag/queued click, five visits, 306 artifact checks, `SIM DONE`.
  Actual input driver `shots/war_machine_factory/capture.tscn` verifies roof click -> walk -> shop -> tent/cart buys
  -> owned buttons -> Close -> hero equipment -> poor repeat visit. Inspected `map.png`, `info.png`, `shop.png`,
  `tent_bought.png`, `all_owned.png`, `equipment.png`, `no_gold.png`; gold/ownership and all three cards are readable.
  `info.png` holds the controller to inspect the real info-panel builder without desktop cursor interference.
  The existing artifact-twinkle triangulation warning recurred in `flow.log` (now `map_view.gd:709`); unrelated to
  factory rendering. No new judge round/score. Next: section 8 findings.
- **Hall build-status badge (2026-10-21), included in this checkpoint:** the Hall picture button inside town now
  shows the same green hammer / gold check as the adventure castle card, with the explicit daily-build tooltip.
  The badge is above the caption, works for all Hall tiers, and updates with the existing refresh after building.
  Shared drawing and wording now live in `UI.build_status_badge` / `UI.build_status_text` (`UI._BuildMark` moved
  from `AdventureHUD`); both callers use the same implementation. No construction rules or assets changed.
  Actual mouse input in local `shots/hall_build_status/capture.tscn` opened the Hall via its badge, selected
  Marketplace, clicked Build, reopened the Hall after building and verified the next-day reset through the rules.
  Inspected `built.png`, `built_tooltip.png`, `hall_after_build.png` and `states.png` (unused/built/next-day crops).
  Full suite passed (`shots/hall_build_status/tests.log`): compilation, 40 battles, 16 visual checks, 15 battle AI
  checks, 14 adventure AI checks, 26 map clicks/drag/queued click, five visits, 307 artifact checks and `SIM DONE`.
  Next: section 8 findings.
- **Town build-status badge (2026-10-21), included in this checkpoint:** at the user's request, each castle card
  beside the adventure menu now shows a green hammer when its daily build is unused, or a gold check after
  construction. The tooltip explicitly says "Not built today" / "Already built today". This reports
  `town.built_today`, not affordability or building prerequisites; existing construction/day rules are unchanged.
  `AdventureHUD._town_card` adds the non-interactive `_BuildMark` overlay, so clicking the badge still enters town.
  Local capture driver `shots/town_build_status/capture.tscn` verified entry by clicking the badge, a successful
  marketplace build through `TownLogic.build`, return via Exit, and reset through `AdvRules.new_day`. Inspected
  `unused.png`, `built.png`, `next_day.png`, both tooltip shots and the `states.png` crops. `flow.log` includes the
  successful flow and the previously recorded, separate artifact-twinkle polygon error at `map_view.gd:706`.
  Full suite passed (`shots/town_build_status/tests.log`): compilation, 40 battles, 16 visual checks, 15 battle AI
  checks, 14 adventure AI checks, 26 map clicks/drag/queued click, five visits, 307 artifact checks and `SIM DONE`.
  Next: section 8 findings.
- **Portrait button styling (2026-10-21), included in this checkpoint:** both clickable hero portraits now use
  `UI.portrait_button` with the existing painted gold bevel, an 8px inset, hover brightening, a hand cursor and
  a darker, slightly inset portrait while held down. The adventure card keeps its movement/mana bars and a
  bright selected frame, but is a momentary action button rather than a toggle; town uses the same frame at
  92px square. No art was added. Actual input captures in `shots/portrait_buttons/` show both screens at idle,
  hover, mouse-down, details open and after Close; inspected full frames and `states.png` crops confirm the
  raised border and press feedback. Local capture driver: `capture.tscn -- --case=adventure|town` in that folder.
  Full suite passed (`shots/portrait_buttons/tests.log`): compilation, 40 battles, 16 visual checks, 15 battle AI
  checks, 14 adventure AI checks, 26 map clicks/drag/queued click, five visits, 307 artifact checks and `SIM DONE`.
- **Castle portrait fix (2026-10-21), included in this checkpoint:** the visiting hero's portrait in
  `town_screen.gd` had no pressed handler. It now opens the same `HeroScreen` as the adventure menu, with a
  matching tooltip; closing it refreshes the town's army strips. Dismiss uses the existing confirmation and
  adventure removal rules, clears the visitor and pending hero reference, and refreshes the empty slot.
  Actual mouse input and inspected screenshots in `shots/town_hero_click/`: `flow_0.png` shows hero details over
  the castle, `flow_1.png` returns to town; `dismiss_flow_2.png` retains the hero after No, `_5.png` shows the
  empty slot after Yes, and `_7.png` returns to adventure with no hero. The previously recorded artifact-twinkle
  polygon error recurred on returning to adventure; it is separate from this interaction fix. Full suite passed
  (`shots/town_hero_click/tests.log`): compilation, 40 battles, 16 visual checks, 15 battle AI checks, 14 adventure
  AI checks, 26 map clicks/drag/queued click, five visits, 307 artifact checks and `SIM DONE`. Next: section 8 findings.
- **Adventure portrait fix (2026-10-21), included in this checkpoint:** the user reported that a hero click in the
  adventure menu appeared to do nothing while the castle card opened its town. `AdventureHUD._hero_card`
  previously only selected the hero. One click now selects it and opens its details; the tooltip states this,
  and clicks while the adventure controller is busy are ignored. Verified by actual input and inspected
  screenshots: `shots/hero_click/hero.png` opens Sir Aldric's details; `flow_1.png` returns to the map after Close;
  `flow_2.png` enters the castle on the next click. Full suite passed (`shots/hero_click/tests.log`): compilation,
  40 battles, 16 visual checks, 15 battle AI checks, 14 adventure AI checks, 26 map clicks/drag/queued click,
  five visits, 307 artifact checks and `SIM DONE`.
  One screenshot run also emitted an artifact-twinkle polygon triangulation error at `map_view.gd:706`;
  the click flow succeeded. That separate rendering issue is recorded for follow-up and was not changed here.
- **Round 47 session authorised (2026-10-21, historical):** the user requested one systematic session covering the test baseline,
  battle readability, remaining visual fixes and measured battle/adventure AI work, with a commit and push after
  each verified fix to `HeroesGPT`; a start on war-machine wrecks or hot-seat is optional. This authorisation
  supersedes the per-commit question in section 6 for this session. No teams; at most one visual judge at a time.
- **Baseline verified:** compilation 0 failures; 40/40 battles ended, 0 failures; 26 map clicks all found paths,
  drag preserved its plan, queued click worked; 5 visit checks; 307 artifact checks passed; all-AI soak `SIM DONE`.
- **Round 47a, battle readability:** removed persistent feet-holes that faded unrelated melee clusters. Fading now
  tests actual painted silhouette overlap with active/hovered/struck figures, using the displayed turn instead of
  the rules' already-advanced turn. The focused figure stays solid; overlapping figures fade to 0.32 in front or
  0.45 behind. Corpses use muted mid-grey shading rather than a 50% black multiplier. Fixed siege regression scene
  `tools/battle_visual_test.tscn`: 13 assertions passed; screenshots `shots/session47/{crowd,distant,corpses}.png`
  inspected. The active Vampire is distinct, unrelated Angel/Dragon are solid, corpses lie grey under living units.
  Full suite passed with the new checks; three live siege runs (two Necropolis, one Haven), six frames in
  `shots/session47/live_siege_*`, were captured and the three late frames inspected. Baseline battle-AI tournament reconfirmed: 319/600
  wins (53%), +1.9 points army kept (+-1.0), 0 unfinished; `shots/session47/ai-before.log`.
- **Round 47b, visual polish:** lightning is a narrow 220px local strike with no storm cloud; the showcase
  artifacts keep an extra tile above town towers; spellbook page headings both use 28px red ink; disabled
  backpack arrows keep their frame and a readable grey symbol. Compilation and all 13 visual assertions pass.
  Captures `shots/session47/lightning.png`, `shots/judge47/adventure_artifacts.png` and `hero_screen.png`
  inspected: the target is clear, all five artifacts remain visible and the cape is separated from the town.
  Both spellbook headings inspected in `shots/judge47/battle_spellbook.png`. Full suite passed;
  33 judge 47 frames captured at 1600x900 and independently reviewed. Last pushed visual fix: `bc013e6` (47b).
- **Judge 47 complete:** menu 9.2, adventure 9.4, town 9.4, dialogs 9.7, battle **9.3 (+0.2)**, overall **9.4**.
  One judge inspected all 33 regular frames, four supplemental fixtures and seven judge46 comparisons. It confirmed
  the focused-unit fade, unrelated opacity, corpse tone, lightning target, cape spacing, headings and arrows.
  Remaining findings are in section 8; still images do not prove every animation/hover transition.
- **Round 47c, AI correctness:** battle spells consider empty blast centres and wide creatures' second hex;
  Liches score living collateral including allies; retaliation counts wounded survivors; blocked shooters do not
  count as ranged support. Melee-only armies advance, and holding for ranged fire ends after eight rounds to avoid
  the healed-ballista standoff. No combat rules or creature stats changed. `tools/battle_ai_test.tscn` has 15
  tactical/end-to-end assertions. The initial fixtures reproduced five failures before the fixes.
  Adventure AI recruits before economic construction when a hostile hero can reach a town next turn, saves only
  for legally possible buildings, holds a viable gate defense or sends one capable nearby hero, skips spent
  watchtowers and no-op friendly-town meetings, and includes a visiting enemy hero's garrison in attack safety.
  `tools/adventure_ai_test.tscn`: 14 checks, six failed before the fix and all pass afterwards. Defense uses real
  path costs and refuses lethal entrance guards. This is a local defense heuristic, not a full strategic planner.
  Final tournaments: vs pre-session AI (bc013e6), 301/600 wins, +0.5 army-kept points (+-0.7);
  fresh pairings 300–599, 303/600 wins, +0.5 (+-0.8). All 1,200 battles ended. Against the original frozen baseline:
  309/600 wins, +1.8 (+-1.0), all ended. **No statistically clear general strength gain over the pre-session AI**;
  these changes fix demonstrated tactical errors and stalled combat. The eight-round hold limit resolves the
  reproduced pairing 91 standoff. Raw logs: `shots/session47/ai-{direct-complete,heldout-final,frozen-final}.log`.
  Full suite passes: 40/40 battle soak, 15 tactical checks, 14 adventure AI checks, map interaction/visits,
  307 artifact checks and all-AI soak. Committed/pushed as `7add0df` (47c), after `bc013e6` (47b).
- **Round 47d, optional wreck work started:** the ballista now has a real broken-machine sprite at
  `assets/creatures/ballista_dead.png`, generated with built-in imagegen from the intact sprite (exact prompt in
  `tools/art/ballista_wreck_prompt.md`). It remains level on the ground, at the idle machine's width, with no
  count badge or live ring. Native alpha preserved; width/anchor metadata added. `battle.gd._pose` supports native
  resolution machine wrecks and no longer requests missing breathing metadata from machines. The visual fixture
  now has 16 checks and `--case=wreck`; all pass. `shots/session47/wreck-final.png` inspected in game after import;
  low grey debris remains in the ballista's place. Full final suite passed (`shots/session47/final-tests.log`).
  This asset was added after judge47 and inspected separately; it is not part of that judge's score.
  This commit is 47d; last pushed AI change is `7add0df`. The first four requested stages are complete, and one of
  four machine wrecks is implemented. Next: remaining three wrecks, strategic AI measurement, and judge47's
  remaining visual findings; hot-seat is still unimplemented. Further commits require the user's instruction.
- **Repository continuation (2026-10-21):** at the user's request, further development in this checkout belongs to
  `wolfxxx/HeroesGPT`, with `origin` pointing there. The original `wolfxxx/Heroes` repository is the source and must
  remain untouched by this continuation. Preserve the existing `main` history. At migration the last gameplay commit was
  `f50213e` (round 46 repairs); the repository setup commit also includes the previously uncommitted judge 46
  scores and findings below. This migration changes only the handoff and Git destination; no gameplay or assets
  changed and no game tests were rerun. Resume from the open findings and AI work in section 8.
- **Artifacts and combination artifacts are built** (the user approved `docs/ARTIFACTS_PROPOSAL.md` as proposed:
  merging as in HoMM3, relics also on random maps, our own names). 41 artifacts in four tiers including three
  combinations, effects in battle and on the map, tiered placement with guards, the hero screen (tier-coloured
  sockets, combinations across their slots, right-click to split or join), each artifact's own picture on the map,
  30 new painted icons, AI valuation, and `tools/artifact_test` (307 checks). Committed and pushed; judge 41 ran on
  it (scores in section 7). Next step of the plan: the AI work (section 8).
- Found and fixed on the way: the all-computer simulation could overflow Godot's message queue once one computer
  player had beaten the others (the AI turn loop never waited a frame); `_run_ai_turns` now waits one frame per turn.
- Round 46 committed and pushed, judge 46 run on it: the adventure_artifacts regression fixed (artifacts skip only tiles right under a
  tree, and the stumps, logs and flowers right beside each are removed instead, so all five show again); corpses
  grey and low in contrast (the outline shader's saturation at 0.25 on death); the hero screen's Formation toggle dims
  the option not chosen. The judge 45 "fade did not trigger" finding was checked with a debug print on that siege
  frame: battle timing varies from run to run; in that re-run the Vampires stood clear, so the rule was left as it is.
  (Judge 46 then saw the knot again in its own run: it recurs in some runs — still open, see section 8.)
- Round 45 committed and pushed, judge 45 run on it: judge 44 fixes — a big figure just behind the stack whose turn it is fades too
  (`_see_through`, the 6th info field), fades a little lighter (0.55); corpses darker and greyer; a spell's log line
  shows with its banner (`_flush_log` in `_anim_spell`); the combination's greyed copy brighter; the showcase
  artifacts keep clear of trees and stumps. Battle AI step 2, measured with the tournament: shooters weigh a target by
  its share of the enemy army (`THREAT_TARGET` 1.0), buff spells valued at half (`BUFF` 0.5: over-valuing them lost
  army), the step-away of a blocked shooter built but left off (`STEP_AWAY`, neutral). Result vs the frozen baseline:
  53% wins, +1.9 points of army kept (+-1.0), up from +1.4. The siege-gate knot in battle_siege_later is only partly
  better (the Angel behind the Vampires now fades; the Vampires in the moat are still small and half hidden).
- Round 44 (AI work begins) committed and pushed, judge 44 run on it: `tools/ai_tournament.gd` plays the current battle AI against a
  frozen copy (`tools/ai/battle_ai_baseline.gd`, class `BattleAIBaseline`) on equal-value army pairings, each fought
  twice with the AIs swapping sides on the same dice (identical AIs split exactly 50%); it prints win rate and a
  paired "army kept" difference with an error bar. First battle-AI changes (`battle_ai.gd`, constants at the end):
  no retaliation counted from a stack that has already struck back this round (a real bug), retaliation weighed
  fully, enemy shooters favoured as melee targets (blocking them), and, when no strike is possible, holding just
  outside enemy melee reach unless the enemy has the stronger shooters or we storm the walls (waiting if nothing
  better). Measured: 52% wins, +1.4 points of army kept (+-0.9) over 600 battles — real but small. The battle scene
  and battle_test handle the AI's new "wait". Also the last artifact fixes from judge 43: soft star twinkle, a pale
  light instead of the relic's red disc, a greyed copy of the combination plus interlocked chain links in its taken
  sockets, no flowers under the showcase artifacts.
- Round 43 (artifact polish after judge 42) committed and pushed, judge 43 run on it: map artifacts without the flat glow plate
  (a dark contact shadow, a faint soft light, a slow twinkle on major and relic ones) and sized by tier by area (the
  relic banner was the smallest); a combination's ghost sockets in iron frames with only a purple chain mark (redrawn so
  it no longer reads as an infinity sign) and the combination itself with a lit rim and corner studs; objects track
  every tile their building covers (`WorldGen.covered`): wandering monsters and guards never stand beside another
  building's walls. A monster right at a mine's entrance is that mine's own guard, as in HoMM3 (judges have read it
  as "pressed between objects"; now listed as intended in `tools/judge_prompt.md`).
- Round 42 (artifact polish after judge 41) committed and pushed, judge 42 run on it: a combination's linked sockets greyed out with a
  chain mark, iron frames for non-artifact and empty sockets, copper for the treasure tier, dimmed backpack arrows,
  the sulfur pile repainted (it read as a flat yellow disc; `tools/art/map_pile.py`), guards no longer placed beside
  another object, trees just below an object turned into bushes (`WorldGen._clear_view_of_objects`), and a 33rd judge
  shot `adventure_artifacts` (`--setup=artifacts`). The placement changes alter generated maps, so judge 42's adventure
  shots show different maps from judge 41's.
- Round 40 is committed and pushed.
- Judge 40 scores: menu 9.2, adventure 9.2, town 9.4, dialogs 9.5, battle 8.9, **overall 9.2**.
- Rounds 31–40 were run as one uninterrupted loop on the user's instruction ("build, commit and push, judge cycle
  until level 40 judge has run"). That authorisation ended with round 40: **from now on, commit and push only when
  the user asks.**
- The four bigger topics the user raised and my recommendations are in section 8; artifacts (the first) are done.

## 3. Standing rules from the user (keep to them)

1. **Stay true to HoMM3.** Prefer the classic mechanics and look. When an idea deviates from HoMM3, say so clearly
   and ask before doing it. (The user rejected a "free unit order" option for that reason. The user did approve
   one non-HoMM3 aid: in battle, a figure standing in front of the stack in play fades so that stack can be seen.)
   **The setting is our own** (approved 2026-10-24): HoMM3's mechanics, with a secret history of conspiracies as
   the setting (`docs/SETTING.md`). Its names, lore and themed art are not deviations; keep to its lines (no live
   modern conspiracy theories such as vaccines; occult Nazis only as the fictional, never-playable Iron Order,
   without real symbols).
2. **One session, no teams of parallel agents** (they used up the user's quota). One background judge agent per
   round is fine.
3. **Commit or push only when asked.** Commit messages are one descriptive paragraph (see `git log`) and end with
   `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (or the equivalent line for whatever assistant is
   working).
4. **Always run `git checkout -- project.godot` after running Godot with a window** — Godot rewrites it. The test
   and judge scripts do it for you.
5. **Secrets**: the ElevenLabs key is only read from the env var `ELEVENLABS_API_KEY` and never printed; the
   Sketchfab key is read inside Blender and never printed; the Google Cloud (Vertex) project id lives in
   `imagegen/vertex_project.txt`, which is git-ignored — never put it in the repo (the repo is public). Don't go
   searching for other credentials.
6. The user's email is for git attribution only.
7. Don't use the phrase "Heroes of Might and Magic" in image-generator prompts.

## 4. Environment

- Windows 11, Git Bash for shell scripts. Godot console exe:
  `C:\Users\PC\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe` (scripts use `$GODOT` if set).
- After adding or changing assets run `Godot --headless --path . --import` (the test script does this).
- Python 3 with PIL and numpy. Windows Python cannot open `/c/...` paths — use `C:/...` paths.
- Image painting: Google Vertex AI, model `gemini-nano-banana-2.1` at location `global`, via
  `tools/art/vertex_paint.py` (project id from `GOOGLE_CLOUD_PROJECT` or `imagegen/vertex_project.txt`; uses the
  machine's application-default credentials). About 30 s per image.
- Blender with the Blender MCP addon on port 9876 (`tools/art/blender/bl.py` talks to it directly for long jobs).
- Audio: ElevenLabs via `tools/audio/gen_audio.py`.
- `shots/` and `imagegen/` are git-ignored (screenshots and painting batches stay local).
- Export templates for 4.7.2 (web single-threaded and Windows x86_64 only) are in
  `%APPDATA%/Godot/export_templates/4.7.2.stable`. `build/` (local exports) is git-ignored.
- The relay runs on the user's free Cloudflare account; wrangler's login is stored on this PC (never print its
  token). Redeploy with `cd relay && npx wrangler deploy`.

## 5. Commands

| What | Command |
|---|---|
| Run the game | `run.bat` |
| Compile-check every script | `sh tools/check.sh` → `CHECK DONE, failures: 0` |
| Full test pass (~4 min) | `sh tools/run_tests.sh` (expected output is in its header) |
| One screenshot | `Godot --path . -- --shot=shots/x.png --scene=res://scenes/battle.tscn --delay=3 --setup=demo` |
| Judge screenshot set | `sh tools/judge_round.sh N` → `shots/judgeN/` (33 shots, 1600x900) |
| Browser version, locally | `Godot --headless --path . --export-release "Web" build/web/index.html`, then serve `build/web` (e.g. `python -m http.server`) |
| Online test through the relay | `Godot --headless --path . res://tools/net_test.tscn -- --relay` |
| Redeploy the relay | `cd relay && npx wrangler deploy` |

Screenshot harness flags (`scripts/core/shot.gd`, coordinates in 1920x1080 space, images saved at 1600x900;
`--setup=artifacts` lays an artifact of each tier beside the first hero):
`--shot --scene --delay --shots --interval --click=x,y;x,y (prefix r for right click) --keys=A;S --hover=x,y`;
scenes also read `--setup=` (`demo`, `rich`, `new_game`, `all_spells`, `upgraded`, `siege`, `siege_haven` (`--siege=1|2|3`,
default 3), `town_levels`,
`necro_rich`, `necro_max`, `x`), `--seed --faction --reveal --cam=x,y --zoom --broken=a,b --battered=a,b --heroes=a,b` (battle heroes by id), `--players=a,b` (demo battle flag colours, -1
neutral), `--terrain=snow` (demo battle ground), `--effects=bless;curse;bless+slow` (spells on the attacker's stacks). The harness parks the
mouse before each capture (except hover and right-click shots). The window must not be headless for shots.

## 6. The round workflow

1. Report the judge's results to the user and propose fixes (flag anything un-HoMM3).
2. On approval, implement; run `sh tools/run_tests.sh`; take verification shots and look at crops of the changed
   areas (for example with a small PIL crop script) before claiming anything.
3. Ask whether to commit, push and run the next judge.
4. On yes: update the docs (below), commit, push, `sh tools/judge_round.sh N`, then launch one background judge
   agent with `tools/judge_prompt.md` filled in. Report its scores and findings, check its claims against the shots
   (judges sometimes misread things), add the scores and findings to this file, and start again at step 1.

**Keeping the docs current is part of every change** (the user asked for it): with each commit, update this file
(status and last commit in §1–2, the score history in §7, open findings and next steps in §8, new systems in §9, new
gotchas in §10), `ARCHITECTURE.md` for new scripts, systems or tools, `ASSETS.md` for new asset paths or art tools,
and `CREDITS.md` for new third-party assets.

Painting new icons: add a sheet to `SHEETS` in `tools/art/button_icons_paint.py`, then
`python tools/art/button_icons_paint.py paint <sheet>` (→ `imagegen/batch20/out/<sheet>.png`), look at it, then
`... ingest <sheet>`, keep the best take under the final name and delete the other takes. Check glows on the
magenta key for pink fringes (recolour them, as was done for the Luck clover).

## 7. Score history (overall, with the weakest area)

| Judge | Menu | Adventure | Town | Dialogs | Battle | Overall |
|---|---|---|---|---|---|---|
| 5 | 5.5 | 6.5 | 7 | 5.5 | 5.5 | 6 |
| 6 | 6 | 7 | 7 | 6.5 | 6 | 6.5 |
| 28 | 8.5 | 8.5 | 8.5 | 9.0 | 8.5 | 8.5 |
| 29 | 8.6 | 8.7 | 8.6 | 9.0 | 8.5 | 8.6 |
| 30 | 8.7 | 8.8 | 8.6 | 9.0 | 8.4 | 8.6 |
| 31 | 8.8 | 8.8 | 8.7 | 9.0 | 8.5 | 8.7 |
| 32 | 8.9 | 8.9 | 8.8 | 9.1 | 8.5 | 8.8 |
| 33 | 9.0 | 9.0 | 8.9 | 9.2 | 8.5 | 8.9 |
| 34 | 9.1 | 9.1 | 9.0 | 9.2 | 8.6 | 9.0 |
| 35 | 9.1 | 9.1 | 9.1 | 9.2 | 8.7 | 9.0 |
| 36 | 9.1 | 9.2 | 9.2 | 9.2 | 8.8 | 9.1 |
| 37 | 9.1 | 9.2 | 9.2 | 9.3 | 8.9 | 9.1 |
| 38 | 9.2 | 9.2 | 9.2 | 9.4 | 8.9 | 9.2 |
| 39 | 9.2 | 9.2 | 9.3 | 9.4 | 8.8 | 9.2 |
| 40 | 9.2 | 9.2 | 9.4 | 9.5 | 8.9 | 9.2 |
| 41 | 9.2 | 9.2 | 9.4 | 9.6 | 8.9 | 9.2 |
| 42 | 9.2 | 9.3 | 9.4 | 9.7 | 8.9 | 9.3 |
| 43 | 9.2 | 9.4 | 9.4 | 9.7 | 8.9 | 9.3 |
| 44 | 9.2 | 9.4 | 9.4 | 9.7 | 8.9 | 9.3 |
| 45 | 9.2 | 9.3 | 9.4 | 9.7 | 9.0 | 9.3 |
| 46 | 9.2 | 9.4 | 9.4 | 9.7 | 9.1 | 9.4 |
| 47 | 9.2 | 9.4 | 9.4 | 9.7 | 9.3 | 9.4 |

Trend: overall holds at 9.4; battle improved from 9.1 to 9.3 in round 47. Remaining siege silhouette crowding and
strategic AI are more substantial next steps than further small dialog polish.

## 8. What's next

### The user's big-picture goal (session67): several interesting factions, played online
Proposed path, discussed with the user (not yet approved as a plan):
1. **Foundations** (audited in `docs/FOUNDATIONS_AUDIT.md`, with the order to do it in): every player and computer
   action through one command layer in the rules (screens only send
   commands; today e.g. the town screen recruits and builds directly); all rule randomness through a seeded
   generator saved with the world (about a dozen global `randi`/`randf` calls remain in rules, hero creation and
   towns); a replay test (record a game's commands, replay from the seed, compare the world); faction data (about 60
   "haven"/"necropolis" checks in 9 scripts move into each faction's definition).
   **Progress (2026-10-24):** phase 1 done. Faction data; every map and town action is a command (battles still
   drive `BattleLogic` from `battle.gd`); per-player screen state in `world["views"]`; the world's dice and the
   replay test (`scripts/core/dice.gd`, `tools/replay_test.tscn`). Phase 2 begun: `Net` (host and join by
   address, commands passed between machines, digest checks), battles fought by each person on their own machine,
   room codes through a relay (also from the browser version on GitHub Pages).
   Next: a test between two real computers; joining a saved online game, a lobby, per-player fog on the wire.
2. **Online first version** with the two factions: one player hosts the real game, others send commands; turns one
   after another as HoMM3; human battles live on both screens; direct address first; rejoin from the host's state.
3. **More factions** one at a time through the art pipeline, each checked with the tournament tools. The user's own
   idea, an alien faction themed on Sumerian myth, is in `docs/ERIDU_PROPOSAL.md`; the whole setting (a secret
   history of conspiracies) in `docs/SETTING.md` (both awaiting answers).
4. **Hardening:** relay or dedicated server, lobby, fog filtered per player, version checks, turn timers.
Decisions open with the user: which HoMM3 factions and in what order, how players will connect, and whether to keep
HoMM3's one-after-another turns.

### Proposed next session after `555fedc` — not started

The latest recommendation is **one focused AI round (steps 1–4), then a complete gameplay playtest (step 5)**.
This is a proposed plan, not a record of completed work or approval to implement/publish it. It takes priority
over older suggested next steps below. The last round fixed particular coordination failures, but its fresh-map
results did not establish a general strength gain; preserve that distinction when reporting the next round.

1. **Defense versus conquest.** Start with saved case **427/0**: session51's diagnostic continuation ended with
   no towns, versus one under `f69ad3a`, while its hero survived. Replay and trace the actual decisions before
   changing policy; losing a town alone does not prove a bad decision. Inspect `_defense`, `_counterattack`,
   `_assault_rally` and `choose` in `scripts/adventure/adv_ai.gd`. Compare travel time, reachable enemy threats,
   garrison strength and feasible attack/recapture opportunities. Aim to distinguish a useful offensive trade
   from abandoning the last defendable town, without making the strongest army permanently passive. Add
   focused scenarios for both holding/intercepting and leaving safely; verify through the production turn driver.

2. **Full armies and reinforcement delivery.** Inspect the saved armies that cannot consolidate because all
   seven slots contain incompatible creatures. Trace `_transfer`, `_transfer_value`, `_reinforce` and actual
   friendly meetings before choosing a fix. Evaluate useful exchanges and staging troops in reachable town
   garrisons through existing rules. Preserve creatures, the donor's required last creature, slot limits,
   upgrade costs and normal movement. Check full receivers, compatible merges, unavailable garrison space and
   essential defenders. A larger main army alone is not evidence of improved campaign outcomes.

3. **Unfinished campaigns.** Revisit all nine unresolved session50 snapshots, using `441/1` as a successful
   rally case that must keep working and `441/0` as a consolidation-without-victory case. Investigate repeated
   town exchanges, defensive standoffs and townless surviving heroes. Separate legal long games from concrete
   decision loops or missed feasible objectives; do not lower combat safety thresholds merely to force an end.
   Read synchronized snapshots for ownership; different players' end-turn trace records are different instants.
   Turn each confirmed failure into a small regression case and document any unresolved tradeoffs.

4. **Validation against the version just pushed.** Before changing policy, freeze the AI from **`555fedc`** in
   a new comparison script and verify its adaptation against committed source. Preserve all older baselines;
   ensure new inherited helpers cannot silently change the frozen policy. Run a same-policy zero-difference
   control. The current resume tool hardcodes `f69ad3a` as its before-policy: explicitly add/select the new
   baseline when comparing this round, while keeping the saved worlds' original opponents fixed. These old
   snapshots lack RNG state, so paired explicitly seeded restarts remain diagnostics, not exact continuations.
   Develop on recorded cases; reserve unused map IDs before final validation. Match the previous round's
   initial validation coverage: 24 size-36 two-player maps (48 rotated-seat games) and eight size-48 four-player
   maps (32 games), each at 84 days. Report wins/losses/unresolved, games at the limit and score deltas with
   uncertainty across maps. Do not tune on final validation maps; subsequent changes need a fresh set.
   Run focused AI checks during development and `sh tools/run_tests.sh` after the final implementation.

5. **Complete gameplay playtest afterward.** Play from New Game through a campaign outcome, checking whether
   the opponent creates credible pressure and whether exploration, town management, recruitment, tactical
   battles, leveling and save/reload flow smoothly. Preserve the player's normal save by using an isolated
   test save. Exercise both factions across playtests; capture and inspect screenshots for any visual fixes.
   Existing scripted flow tests do not establish human competitive balance; record who played, what was
   exercised and what remains untested. Human feedback is needed for the subjective difficulty assessment.

**Evidence and tools:** `docs/AI_COORDINATION.md`, `docs/CAMPAIGN_VALIDATION.md`,
`tools/campaign_snapshot_report.tscn`, `tools/campaign_resume_test.tscn`, `tools/campaign_trace_report.py`,
`tools/adventure_ai_test.tscn`, `tools/adventure_tournament.tscn` and `tools/campaign_flow_test.tscn`.
Local inputs are under ignored `shots/session50/states168/`; prior traces and final results are under
`shots/session51/`. They are not on GitHub: on a fresh clone, regenerate snapshots using the validation report's
commands before attempting those replays. Store next-round evidence separately, for example `shots/session52/`.

**Completion criteria for steps 1–4:** confirmed failure cases have focused tests and fixes, remaining cases
are explicitly explained, current regressions and the full suite pass, fresh-map results are reported honestly,
and handoff/architecture documentation identifies the final behavior and limitations. A statistically unclear
result must not be described as stronger AI. No HoMM3 rule changes are part of this plan; flag and ask before
any deviation. Update docs with implementation; commit/push only on the user's instruction.

**Session66 progress:** step 5 done (a Haven campaign won on day 27, see §2); steps 2 and 3 done (stack swaps; garrison heroes step out; the remaining unresolved cases
are legal standoffs within the 1.4x assault margin), validated as step 4 describes. Next map IDs to reserve: 2200+
(2000–2037 development, 2100–2123 and 2140–2147 validation were used in session66).

**Session52 progress on this plan:** steps 1 and 4 done with one kept fix and no measured strength change (see
§2). Remaining: step 2 (incompatible full armies and couriers; leader-only garrisons was tried and rejected),
step 3 for the cases still unresolved, step 5 for Necropolis and a human playtest. Two-player size-36 games are
early rushes; judge long-game changes mainly on four-player/larger maps. Next map IDs to reserve: 1700+ (1300–1323,
1400–1407 validation and 1500–1523, 1600–1607 development were used in session52).

**Hot-seat multiplayer is built (session53, see §2).** Worth a human playtest with two people: turn handover,
human-versus-human battles, a computer attacking the player not at the screen. Fog-information policy, map-spell planning, difficulty settings, remaining
machine wrecks and visual findings stay on the backlog; online multiplayer remains a separate larger project.

### Playtest findings (session66, one Haven campaign on Normal, won on day 27)
Evidence in ignored `shots/session66/play/` (`findings.md`). Two bugs were fixed in play (see §2); the rest are all
fixed in session67 (the battle result's garrison name, neutral rings on grass, quiet sounds, and a slain hero coming
back at level 1).

### Playtest findings (session57, one Necropolis campaign on Normal; not yet fixed)
Ranked by impact. Evidence in ignored `shots/session57/play/` (`findings.md` has the details).
1. **FIXED (session58): a guarded artifact is not picked up after beating its guard.** Walking onto the Orb of Power
   at (15,27) triggered the adjacent Swordsmen; after the win the hero stood on the artifact without it (twice, also
   at (18,30)); stepping off and back on picked it up. `adventure.gd move_hero` checks `rules.guards(p)` before the
   `last` step's visit and returns after the battle, so the target is never visited (the AI's quick-resolved fights
   too). Fix: after a won guard fight on the last step visit that tile's object (a human's across the battle scene,
   resumed in `_post_ready`).
2. **FIXED (session60): No garrison hero slot** (HoMM3 deviation): a hero at the gate blocks the Tavern ("send them out first") and can
   not be moved up into the garrison row; HoMM3 lets a hero stand in the garrison.
3. **FIXED (session60): Hero list click opens the hero screen** at once (HoMM3: the first click selects and centres the hero, a click on
   the selected one opens the screen); switching heroes always needs a Close. The town list now works the same way
   (session61).
4. **FIXED (session59):** Battle: the held right-click creature popup showed base Speed and no active spells, while
   the hover panel showed "Speed 5 (4)" and "Slow (2 rounds left)".
5. **FIXED (session59):** Battle: Slow cast in round 1 did not reorder the current round's turn queue.
6. **FIXED (session59):** Text: "Necromancy raises 1 skeletons" (plural with 1).
7. **FIXED (session59):** Battle: the hero figure was per faction (the Death Knight rode with the Necromancer's staff).
8. **FIXED (session63):** Battle: stacks were coloured by side, attacker red, defender blue, not by owner, so when
   the Blue AI attacked, my troops were blue. Now the classic count boxes (by spells) and flag-coloured rings.
9. **FIXED (session62):** a retreating hero's First Aid Tent was listed among the casualties. The hero kept it (as
   HoMM3: machines are equipment, kept like artifacts); only the result window was wrong.
10. **FIXED (session66):** the missing map popup was harness-only: after a scene change the map hid the hover panel
   because the OS cursor (which the harness does not move) was outside it; the map now reads the cursor from events.
Worked well: Citadel growth (14 -> 21 Pikemen), the walled-town and village map pictures, the Fort siege with the
battered overlays, wrecks, AI hero looting of artifacts, guard zones, week change, save/load, the defeat flow.

### Playtest findings (session52, one Haven campaign on Normal; not yet fixed)
Ranked by impact. Evidence (screenshots `s###.png`, logs) is in ignored `shots/playtest/`.
1. **FIXED (session52): map objects walled off from every route.** In the playtest a Griffin dwelling, a Sawmill and
   six artifacts could not be reached. With the game's real movement rule the sweep found unreachable objects on
   35 of 36 generated maps; now 0 (see §2).
2. **PARTLY ADDRESSED (session54, see §2): AI leaves its capital empty / low pressure.** Gravenmoor (9 buildings) was taken on day 11 with no garrison
   and no hero; the AI's heroes fought one at a time and never combined. This matches the planned §8 step 1
   (defense versus conquest, case 427/0) and suggests checking garrison retention when the main hero leaves.
3. **FIXED (session52, user-approved): meeting your own hero by click, with troop and artifact trading** (see §2).
4. **FIXED (session52): hero drawn behind a building after a visit** (see §2).
5. **FIXED (session52): sand decor that looked like a resource pile** (removed from new maps).
6. **FIXED (session52): right-click is the classic held info popup** (with armies and own garrisons).
7. **Unconfirmed:** a rehired Lord Gareth (killed, then hired again) appeared in the save with the Oaken Buckler his
   earlier self had found, and it was gone after his next battle. A headless repro of kill + rehire gave a clean
   hero, so the path is unknown.
Questions for the user (deviations already in the game, not changed): Necropolis upgrades use custom names/stats
(Arch Lich, Doom Rider with Dread Knight as the base, Wraith from Ghost); the build tree is one shared simplified tree.
Worked well and matched HoMM3: recruit/merge, tavern gate rule, chest gold/XP choice, XP = killed HP, monster stack
splitting, week announcement, siege flow, level-up choices, end-turn warning, remembered routes, victory flow.

### Open findings from judge 47 (overall 9.4; battle 9.3)
1. Other participants in siege melees remain crowded even though the focused Vampire is now clear
   (`battle_siege_later`, x790–1040/y560–720). Local session48 adds bounded staggering and verifies reduced
   silhouette overlap. Residual wing overlap remains; no new judge has reviewed it.
2. Lightning targeting is clear, but its uniform double stroke and blunt top look drawn rather than painted
   (`session47/lightning`, x1325–1355/y395–500). Taper/irregularity is a future visual refinement.
3. Lakes have blurred decal-like edges (`adventure_close` bottom centre; `adventure_overview` right centre).
4. Necropolis battle hero blends into the dark towers (siege shots, upper right). Local session48 adds a modest
   exposure/rim lift, verified in before/after screenshots; awaiting a future judge.
5. Construction thumbnail heights vary around wrapped prices (`town_build_rich`, Mage Guild/upgrades).
6. War-machine labels vary in size in the siege turn queue.
7. Starting-bonus descriptions are cramped (`newgame`, lower left).

### Judge 46 findings (historical; 1–5, 7–8 addressed and verified in round 47)
The monster-density observation (6) remains a possible map-design review, not an automatic request to change rules.
1. The siege-gate knot DID recur in judge 46's run (Vampires, whose turn it is, lying across the Angel; Ghosts on the
   Angel's head; Bone Dragon over the Cavaliers). Round 46's note that it "does not recur" was wrong: it recurs in
   some runs, not all. Needs a real fix (e.g. keep a stack's figure from overlapping a neighbour's, or a stronger
   fade/outline for the stack in play), checked over several runs.
2. In battle_siege_haven the living Bone Dragon and the Angel are drawn semi-transparent while the stack in play is far
   away; they now look like the grey corpses. Find which fade rule fires there.
3. Corpses are too dark (charcoal): raise them to mid-grey near the ground's brightness.
4. adventure_artifacts: the cape lies right behind the castle's tallest tower and reads as a flag on it.
5. Lightning: the cloud forms over the top-row stack; the bolt passes two stacks to reach its target.
6. adventure_overview: about 20 wandering monsters on one screen — denser than HoMM3.
7. battle_spellbook: the two page headings differ in size and colour.
8. hero_screen: the dimmed backpack arrows nearly vanish.

### Open findings from judge 45 (overall 9.3; battle up to 9.0, adventure down to 9.3)
Landed: spell log line with its banner, darker corpses, recognisable greyed combination copy.
1. The "big figure behind the stack in play fades" rule did NOT trigger in battle_siege_later (the judge
   pixel-diffed: the Angel behind the active Vampires is unchanged). Debug `_see_through` on that exact frame.
2. Regression: adventure_artifacts shows only 2 of its 5 artifacts — the tree/stump clearance in
   `_shot_artifacts` pushed three out of view; place them on clear grass near the hero instead.
3. Corpses are darker but warm sepia and upright (the Bone Dragon corpse still reads as a figure): desaturate
   much more and lower the contrast.
4. Lightning cloud over the top-row Skeletons; the bolt passes three stacks (reads as a chain hit).
5. Siege-gate knot (Angel, Ghosts, Vampires; Bone Dragon fused with the Cavaliers).
6. Hero-screen Formation toggle: the selected option is unclear.

### Open findings from judge 44 (first battle-AI round; overall 9.3)
The AI's choices read as sensible on screen (holding back, hitting the Angel after it retaliated, focusing targets).
1. battle_siege_later: the stack in play (Vampires) is buried under the Angel's wings and the Ghosts in a four-stack
   knot; the front-figure fade did not fire for it.
2. Corpses read as living units (battle_2, battle_1): darken/desaturate them more and keep them under the rings.
3. adventure_artifacts: the relic's pale light reads as a dark stain under the banner (drop it or make it warm
   white); a tree stump butts against the cape.
4. hero_screen: the greyed copy in a combination's taken sockets is too dark (~15%): lift it to 40-50%.
5. battle_siege_haven: the living Bone Dragon is drawn semi-transparent while it is not in front of the stack in
   play; its badge sits detached.
6. A spell banner is on screen with no log line yet (battle_0, battle_siege): log the cast when it is announced.
7. town_build_rich: a two-line price shifts that row's caption baseline.
8. adventure_overview: the map reads busier with wandering monsters than HoMM3's typical density.

### Open findings from judge 43 (second artifact polish round; overall 9.3, adventure 9.4)
1. Siege-gate pile-ups (battle_siege_haven, battle_siege_later) — unchanged, the main battle problem.
2. The map artifacts' twinkle shows as a hard white "+" in a still (looks like a debug mark): soft 4-point star with
   falloff, or hidden in its off phase.
3. The relic banner's baked shadow is a reddish disc offset from the pole's foot (`art_banner_of_the_muster.png`):
   a neutral dark ellipse centred under the foot.
4. The chain mark on a combination's taken sockets reads as an orbit symbol: two clearly interlocked links, or a
   greyed copy of the artifact behind the mark, as HoMM3.
5. Lightning cloud covers the top-row stack and the enemy hero (battle_0, battle_siege).
6. Ground flowers ring an artifact (adventure_artifacts, the cape): keep flat decor off artifact tiles.
7. Hero-screen Formation toggle: the selected option is unclear.
8. New Game starting-bonus card text is cramped.

### Open findings from judge 42 (artifact polish round; overall 9.3)
1. Siege-gate melee clusters still unreadable (battle_siege_haven, battle_siege_later); badges drift from their stacks.
2. Lightning: the storm cloud caps the back-row stack; in battle_siege the bolt zig-zags at a slant across other
   stacks instead of dropping straight onto the target.
3. Map artifact glow reads as a flat painted plate (worst: the relic's red disc); HoMM3 shows only a ground shadow —
   use a faint soft glow and a dark contact shadow; the relic banner is the smallest item, scale it up.
4. Hero screen: a combination's ghost sockets share its purple frame — give them iron frames (only the link mark in
   purple) and the combination a strong lit rim; the link mark reads a little like an infinity sign.
5. A few guards still stand pressed between objects (adventure_overview archer between the mound and hut,
   adventure_close wraith between hut and lake) — the new spacing rule did not catch these (decor or footprints).
6. Lakes look like decals (flat blue with a blurred brown halo); HoMM3 shores have a crisp sand or rock rim.
7. Battle figures small for their hexes (battle_turn, battle_upgraded).
8. Build cards with two-line prices make rows ragged (town_build_rich).

### Open findings from judge 41 (artifacts round, mostly fixed in round 42)
1. No artifact appears in any judge screenshot, so the map half of the feature was not judged: add a judge shot
   framed on placed artifacts (`tools/judge_shots.sh`).
2. A combination's linked sockets read as copies of the item: fade/desaturate them much harder and mark them
   (HoMM3 greys out the slots a combination takes); the Dragonheart Arms icon is low-contrast on the maroon ground.
3. Non-artifact sockets (war machines, spellbook, empty backpack cells) use a gold frame that reads as the "major"
   tier: give them a neutral dark-iron frame.
4. Bronze (treasure) and gold (major) tier frames are too close: push bronze toward copper and duller.
5. A flat gold oval on the map (adventure_snow ~1057,357; adventure_overview ~455,282) reads as a placeholder.
6. Map objects on neighbouring tiles overlap (two knights by the mine in adventure_snow; a gold pile inside a tree in
   adventure_close).
7. Backpack page arrows look active when everything fits on one page.
8. Still open from judge 40: storm cloud on the top-row stack, faint open-field bolt, siege-gate pile-ups.

### Open findings from judge 40 (ranked)
1. Lightning storm cloud looks like a flat cartoon blob (`battle.gd` class `_Burst`, the `bolt` branch); its pale
   lit underside reads as a selection ring. Options: paint it properly, or drop the cloud and bring the bolt from
   the top of the screen as HoMM3 does.
2. The bolt's shape varies (thin S-curve in the open field, jagged in the siege) — make it consistently jagged.
3. Unreadable melee clusters at the siege gate (`battle_siege_haven`, `battle_siege_later`): the Ghost, Angel and
   Vampire overlap. Several rounds of plate moves, fades and shrinking only helped a little.
4. Build cards: a row with a two-line price has shorter pictures than other rows (`town_screen.gd` `_BuildCard`,
   `min_rows` set per row in `_open_build`).
5. Empty wood in the town bottom bar between the garrison and the dwelling portraits.
6. The enemy hero is hard to see against the dark Necropolis siege backdrop.
7. War-machine names in the turn queue come out in three sizes (the shrink-to-fit in `_QueueIcon._draw`).
8. Small New Game card text (starting-bonus captions).

The siege drawbridge reads as a stray plank, but it is part of the painted siege wall art; it was left alone.

### The four bigger topics (current status after round 47)
Suggested order remains **artifacts → AI → hot-seat multiplayer**, with the remaining wrecks independent.

1. **Artifacts and combinations — BUILT.** The approved `docs/ARTIFACTS_PROPOSAL.md` is implemented: 38 ordinary
   artifacts plus three combinations, four tiers, guarded map placement, hero equipment/backpack, merging and
   splitting, and battle/adventure effects. There are no pending proposal questions.
2. **Computer opponent — tactical/local-defense, coordination and conquest improvements in this checkpoint.** Battle AI scores
   damage, surviving retaliation, shooter blocking and collateral; it waits/defends with ranged support for at most
   eight rounds. Adventure AI recruits under immediate threat and assigns a nearby viable defender, while ordinary
   expansion remains value divided by route cost. Session48 adds target persistence/coordination, bounded troop
   deliveries, paid upgrades and a paired campaign benchmark. Session49 fixes passive defenders, improves
   reinforcement/assault coordination and shows a clear gain against that checkpoint in the benchmark (§2).
   Remaining work: better conquest/reinforcement priorities, map-spell planning, fog policy and difficulty.
   Adventure AI still enumerates world targets regardless of fog. Keep the frozen baseline and use fresh map
   pairs for comparisons; strategic scores and eliminations measure different outcomes.
3. **Multiplayer.** Step 1, hot-seat (players sharing one computer, as HoMM3) — BUILT in session53 (§2, §9).
   Step 2, online play, is its own large project: an authoritative host, deterministic
   seeded randomness in battle and on the map, disconnects, saving. Keep these rules from now on: all game state
   stays in saveable dictionaries, all randomness goes through a seeded generator, screens never change the rules'
   state directly (the split of `adv_rules`/`battle_logic` from the views already helps).
4. **War-machine wrecks — DONE (session57).** All four machines leave a painted wreck (see §2).

## 9. Where the recent systems live

- **Online (session67):** `scripts/core/net.gd` (autoload `Net`), `Commands.run` (passes commands on, turn rule),
  `adventure.gd` "Online (Net)" section and `_start_battle`, `battle.gd` `_carry` / `_turn`, `main_menu._multiplayer`
  / `_join` / `_open_room`, `tools/net_test.tscn`, `tools/net_battle_test.tscn`, `tools/net_diff.tscn`. Relay:
  `relay/src/index.js`, `scripts/core/relay_peer.gd`. Browser version: `export_presets.cfg`,
  `.github/workflows/pages.yml`. ARCHITECTURE.md "Online".
- **Dice and replay (session67):** `scripts/core/dice.gd` (`Dice.roll/chance/index/pick`, `gen`/`keep`, `derived`,
  `look`), `world["rng"]`, `world["battles"]`, `AdvRules.battle_seed`, `Commands.log`/`log_world`,
  `tools/replay_test.tscn`. ARCHITECTURE.md "Dice and the replay test" says which generator each roll uses.
- **Per-player screen state (session67):** `GameState.view(p)` (`world["views"][p]`: `selected_hero`, `selected_town`,
  `intro_shown`, `news`, `defeat_told`), `adventure._v()`, unsaved `GameState.viewer`, `AdvRules.removed`; save
  version `GameState.SAVE_VERSION` = 2 with `_views_from_v1` for older saves. Commands: `scripts/adventure/commands.gd`
  (list at its top), `AdvRules.do(cmd)`, test `tools/commands_test.tscn`.
- **Fortification levels (session56):** `TownLogic.siege_level`; map picture `MapView.town_sprite`
  (`assets/map/town_<faction>{_village,_fort,}.png`); siege `BattleLogic.is_moat` (Citadel+), `SOLID_SEGS` (corners),
  `breakable` (corners only with a Castle); `battle.gd` `bg_siege_<faction>_<level>`, `siege.json` per level,
  `WALL_BANDS`, `ARCHER_SPOTS`; art `tools/art/siege_levels_paint.py`, `tools/art/town_levels_paint.py`; checks
  `battle_test._siege_rules`; shots `--setup=siege|siege_haven --siege=N`, `--setup=town_levels`. Battered walls
  (session57): `siege_<faction>_<level>_dmg_<seg>.png`, `battle.gd._show_battered`, shots `--battered=a,b`.
- **Town garrisons (session54):** `AdvAI._collect_garrison` / `_garrison_keep` (garrison kept against a next-turn
  threat), `_counterattack` margin 1.3x; frozen previous policy `tools/ai/adventure_ai_session52.gd`; diagnostic
  `tools/ai/town_defense_report.tscn` (`--maps= --players= --size= --days= --policy= --verbose --trace=`; its RECALL
  line, session55, counts captures returning heroes could have prevented). Frozen session54 policy (`349549d`):
  `tools/ai/adventure_ai_session54.gd`.
- **AI stack swaps and garrison step-out (session66):** `AdvAI._transfer` / `_collect_garrison` swap whole stacks
  into a full army (`_best_stack`, `_weakest_stack`, `_stack_value`); `_step_out` (a garrison hero decides again each
  turn); frozen previous policy `tools/ai/adventure_ai_session65.gd`. Write-up: `docs/AI_COORDINATION.md` "Session66".
- **Hot-seat (session53):** seats on New Game `main_menu._refresh_seats`, per-colour choices `_edit` /
  `_choice` / `_set_choice` / `_fix_seats` / `_taken_heroes`; generation
  `WorldGen.generate` (`humans`, `_player_name`, per-human `start_hero`, `seat_hero` / `seat_bonus`); viewpoint
  `GameState.human_player_index`, `hotseat()`, `hotseat_alive()`, `handed_over` / `was_handed`; turn flow
  `adventure._start_human_turn`, `_cover`, `_turn_banner` (`seen_by`), `_start_battle` (the defence call),
  `_check_game_over` + `_hotseat_defeats`; `AdvRules.eliminate`; battle result `battle._end_battle`; pennant
  `UI.flag_icon`. Test `tools/hotseat_test.gd`.

- **Conquest work (session49):** `AdvAI._counterattack` relieves threatened towns; `_unlocks_assault` evaluates
  substantial deliveries; `_merge_stacks` frees duplicate army slots; `dwelling_recruits` shares purchase
  eligibility. `run_turn` recognizes XP as progress. Frozen `4f126ec` policy: `tools/ai/adventure_ai_checkpoint.gd`.
  Tournament `--baseline` selects either frozen revision; `--trace` writes the driver's JSONL events.
  `python tools/campaign_trace_report.py <trace> --after=42` reports late targets, inactivity and unused garrisons.
- **Strategic campaign work (session48):** `AdvAI.choose` owns the optional target assignment; `_leader`,
  `_transfer_value`, `_transfer`, `exchange_troops` handle legal nearby deliveries. `adventure.gd._interact_with`
  executes AI meetings. `tools/ai/campaign_driver.gd` runs production turns/visits/instant battles without UI;
  `campaign_week_test.gd` and `adventure_tournament.gd` use it. Frozen AI policy is in `tools/ai/`.
- **Twinkle reliability:** `MapView._ArtifactGlow` emits convex triangles instead of triangulating a collapsing
  concave star; `tools/artifact_glow_test.tscn` sweeps phases using the real renderer.
- **Map edge**: `scripts/adventure/fog.gdshader` draws the shroud, the slate void past the edge and a rocky ridge
  (`rock_h` height map: warped power-diagram boulders + crags; `ridge` lighting; `band`/`enc` set how far it runs
  out and onto the map). `map_view.gd` `_build_border()` places the map's own mountain sprites around the edge
  (seeded, varied sizes, pairs, boulders), drawn over the fog at z 51 with `border_rock.gdshader` turning their
  grass skirts to ochre rock. The camera may run 2 tiles past the edge (`adventure.gd`, `margin`).
- **Battle readability** (`scripts/battle/battle.gd`):
  - `_see_through()` / `_figures_overlap()` — only painted figures overlapping a focused stack fade via
    `body_alpha`; no permanent feet-holes in unrelated stacks. `_acting_uid` follows the displayed turn through
    animations. The active stack gets a pulsing halo (`team`); `corpse_tone` softens corpse contrast.
  - `_crowd()` — wide-winged figures and figures in 3+ / 4+ stack melees draw smaller. `stand_pos` staggers aligned
    successive rows by at most 18px inside their footprints; `_footprint_center` keeps the geometric center.
    `_crowd` settles idle figures; `_anim_move` sets `moving` node metadata to protect its tween.
  - `_settle_badges()` — count plates: front corner, moved in under their own figure when a front neighbour is
    taken, never on another stack's figure (body penalty, back-corner and raised spots).
  - `_under_figures()` — low obstacles fade where a figure stands over them.
  - `_Shadow` — rings in the player's flag colour (`side_color`); a struck stack's ring flares lighter.
  - `_Badge` — count boxes as the classic: purple, green / red / yellow by the spells on the stack (`mood`).
  - `_QueueIcon` — turn queue; machines and towers drawn whole with a name band.
  - `_Burst` (bolt) — narrow 220px lightning strike above its target, on the rings layer under figures; no cloud.
  - Damage labels vanish at once (no fade) — `_float_text`.
- **Artifacts** (2026-10-20): data `GameData.ARTIFACTS` / `ARTIFACT_TIERS`; rules `GameState.hero_stat`,
  `hero_flags`, `artifact_slots`, `can_wear`, `give_artifact`, `swap_artifact`, `merge_combinations`,
  `split_combination`, `join_combination`; battle `BattleLogic.max_hp / speed / spell_damage / immune`, necromancy in
  `scripts/battle/necromancy.gd`; map `AdvRules.hero_scout_radius`, `new_day` (gold, mana, muster growth); placement
  `WorldGen._place_artifacts`; hero screen `hero_screen.gd` (`_placed`, `_artifact_tip`, `_Socket.tier_col / linked /
  rpressed`); map picture `MapView._object_node` + `_ArtifactGlow`; test `tools/artifact_test.gd`.
- **Rules change**: the ammo cart never takes a turn (`battle_logic.gd` `_new_round` and `upcoming`), as in HoMM3.
- **Town**: `_BuildCard` price rows (one row at one of three sizes, else two; `min_rows` per card row), the
  full-width inset treasury and date (`town_screen.gd` top), bigger price icons everywhere (`HoverInfo.cost_row`,
  `_DwellingCard`), the upgrade dialog with a drawn gilt arrow (`army_strip.gd` `_Arrow`).
- **Icons** painted this stretch (`tools/art/button_icons_paint.py` sheets `conditions`, `conditions2`, `skills`,
  `stats`, `knowledge`, `misc_stats`, `tome`): scenario conditions `ui/cond_*.png`, all secondary skills
  `icons/skill_*.png`, primary stats and morale `icons/stat_*.png` (Knowledge = lamp and scroll), health / damage /
  xp / speed `icons/stat_*.png`, the hero screen's closed spellbook `icons/spellbook_closed.png`.

## 10. Gotchas learned the hard way

- Browser version (session67): only the cursor over the page is known (edge scrolling must not use screen
  positions; past the page's edge it goes on toward the edge the cursor left by, as the user asked); a room code may start with a digit; ENet does not work in a browser (room codes only). A new
  workers.dev subdomain took a few minutes before its certificate worked. The browser drive used for checks is
  Playwright (`playwright-core` with the installed Chrome) clicking two windows; the screenshot harness does not
  run in a browser.
- Online (session67): anything the screen writes into the world outside a command makes the machines differ (the
  first two-window run found `asleep`). Make it a command, or, if it is truly one machine's own, add its key to
  `Net.PRIVATE`. Two windows on one computer: start each with its own `--remote=<dir>`; they share `user://`. The
  test's host must yield a frame between computer turns or the network is never read. A two-machine battle stays in
  step only if both machines make the same `BattleLogic` calls in the same order: nothing on screen (previews,
  hover) may roll the battle's dice, and a choice must go through `battle.gd _carry`. A test node that must outlive
  a scene change (into a battle and back) goes on the root (`net_test.gd` Client, `net_battle_test.gd` Driver). `git checkout --
  project.godot` (and `run_tests.sh`'s exit trap) also undoes an intended, uncommitted change to it, such as a new
  autoload: re-apply it before testing or committing.
- Randomness (session67): a rule that changes the game rolls with `Dice` on the world and only inside a command; a
  choice made outside a command uses `Dice.derived`; presentation uses `Dice.look()`. Never the global
  `randi()`/`randf()` in game code: `tools/replay_test.tscn` fails on anything that changes the world outside a
  command or rolls on the wrong generator. Changing what rolls changes every seeded game: record new tournament
  references (ARCHITECTURE.md "Commands" gives the two runs).
- Keep screen-only state out of `GameState.world`: `campaign_flow_test` checks that a save/load round trip returns the
  world byte for byte, so a marker erased on load fails it (hot-seat's handover marker lives in `GameState._handed`).
- Python edits sent through a Bash heredoc lost GDScript's backslash line continuations; use parentheses for
  multi-line conditions instead.

- Map reachability must use the game's diagonal rule (AStarGrid2D `DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE`): two
  obstacles touching at a corner are a wall. Any later footprint can seal a pocket, so check access after all
  placement (`WorldGen._ensure_access`), not only before it. Pickups, monsters and entrances are cleared or stepped
  through, so they are not walls for this check; they are solid in AdvRules' planner, which is intended.
- Remote playtests: `--remote` coordinates are window pixels (1600x900), but `adv._event_world`/`_pick` expect
  canvas coordinates (x1.2); `ctile`/`look` avoid the conversion. A shell heredoc or `cat` without input in a
  tool command waits on stdin forever; redirect `< /dev/null` when chaining Godot runs.

- A zero-cost adjacent victory may leave army value unchanged. XP gain is still real turn progress; otherwise
  AI throws away its remaining movement. Do not remove the no-progress guard entirely (repeat visits can loop).
- Defense must distinguish holding against a close match from safely intercepting a weak raider. Always check
  the full current-day route, guards, enemy-town garrisons and other threats before leaving the gate.
- Campaign traces are JSONL, with Vector2i coordinates serialized as strings. Move events precede the AI's
  after-move town reinforcement; end-turn armies include it. Old traces omit XP deltas. No-action counts alone
  cannot distinguish deliberate holding from a missing target. No traces or user saves are committed.
- Paired campaigns need both world UID reset and gameplay seed reset per game. Audio pool availability/dedup
  depends on timing: audio needs its own RNG. Never randomize a caller-supplied level-up generator. Other
  presentation code still consumes global RNG; campaign reproducibility is limited to the headless harness.
- Mark every player AI in the campaign harness, otherwise battles/visits can open modal UI and hang it. Its
  `SilentView`/`SilentHUD` disable presentation while retaining the production controller and rules.
- Godot can emit a script error alongside a zero-failure test summary and exit code zero. Inspect `SCRIPT ERROR`
  lines as well as counts. Old exit-only resource leak warnings remain separate from runtime failures.
- Tiny concave artifact glints intermittently failed triangulation. Explicit triangles plus a subpixel cutoff
  remove that path; verify future changes with a windowed phase sweep.
- Godot shaders: no `return` inside `fragment()`. In a canvas shader, `COLOR` already holds the sampled and
  modulated texture — multiplying by `COLOR` again squares the colour.
- GDScript treats "inferred from Variant" as an error here: type such variables explicitly (`var t: String = ...`).
- Battle shots are not reproducible frame for frame (animation and AI timing vary between runs): a judge's finding
  about one stack's position in an auto-battle shot may not recur; check the rule, not just the frame.
- The judge sees still frames at deterministic times: an effect that is mid-fade at that moment looks broken every
  round. Prefer states that read well at any moment (labels vanish instead of fading).
- A shot can be spoiled by the real OS cursor over the window; the harness ignores off-window motion and parks the
  mouse before capture.
- Painting on magenta leaves pink fringes around glows: recolour pixels where `(r+b)/2 - g` is large.
- Judges contradict each other between rounds (for example plates "on the wrong figure" vs "floating above its
  own"); check against the shots before acting.
- The screenshot harness's `--hover` did not bring up the adventure map's hover panel for objects (tested on an
  artifact); battle and town hover shots work. Not investigated.
- Blender: never remove data blocks one by one in loops (use `bpy.data.batch_remove`); MCP calls over ~2 min report
  "No data received" while the job continues.

- Round47 art gotcha: measure only changed files (`python tools/art/sprite_sizes.py ballista_dead.png`); a full
  remeasurement replaces older hand-tuned Bone Dragon sizes. Machine nodes have no breathing tween.
