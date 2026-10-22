# Architecture — Heroes of the Shattered Crown (Godot 4.7, GDScript)

Godot exe: `C:\Users\PC\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe`
Design resolution 1920x1080, stretch mode canvas_items/expand. All UI coordinates assume 1920x1080.

## Autoloads (scripts/core)
- `GameData` — static tables (creatures, heroes, spells, buildings, artifacts, terrains, mines). Source of all ids.
- `Assets` — `Assets.tex("creatures/pikeman.png")` with placeholder fallback; `Assets.anchor(path)` returns the
  foot point of a Blender-rendered sprite (from `<dir>/anchors.json`). See ASSETS.md for every asset path.
- `Audio` — `Audio.music("battle")`, `Audio.sfx("sword_hit")`; pitch uses a private RNG, independent of gameplay.
- `GameState` — world state across scenes, fade `change_scene()`, battle/town handoff, hero helpers, save/load.
  `save_game`, `load_game`, `has_save` accept an optional path for isolated tests; default remains `user://savegame.dat`.
- `Shot` — screenshot harness for automated visual review (see below).

## Shared classes
- `UI` (scripts/ui/ui.gd) — theme + widget factory. Set `theme = UI.theme()` on your root Control.
  `portrait_button` gives adventure/town hero portraits a shared painted frame, hover/press feedback and optional
  selected state/right gutter; its `portrait` metadata exposes the inset image for the adventure card's bars/sleep tint.
  `build_status_badge` / `build_status_text` share the daily-build hammer/check and tooltip between adventure castle
  cards and the town's Hall button. The badge's `_BuildMark` drawing lives here and ignores mouse input.
- `Modal` (scripts/ui/modal.gd) — awaitable dialogs: `var r = await Modal.choice(self, title, text, options).closed`.
- `ArmyStrip` (scripts/ui/army_strip.gd) — 7 army slots; strips sharing a group dict exchange stacks.
- `HeroScreen` (scripts/ui/hero_screen.gd) — shared hero details, army and artifact dialog, opened by adventure
  hero cards and the town's visiting-hero portrait. Each caller handles dismissal and refreshes its own UI.
- `TownLogic` (scripts/town/town_logic.gd) — town/player rules + dict schemas (READ ITS HEADER).

## Scenes
| Scene | Scripts | Notes |
|---|---|---|
| scenes/main_menu.tscn (main) | scripts/menu/ | menu, new-game setup, quick battle |
| scenes/adventure.tscn | scripts/adventure/ | `WorldGen` (random map), `AdvRules` (pathing, visits, day/week, battles), `AdvAI` (town spending and path-aware local defense), `MapView` (terrain shader, sprites, fog, the mountain border `_build_border`), `AdventureHUD`; `fog.gdshader` also draws the void and rocky ridge past the map edge |
| scenes/town.tscn | scripts/town/ | town screen; building art positions come from `assets/town/layout_<faction>.json` (fallback `TownLayout`) |
| scenes/battle.tscn | scripts/battle/ | `BattleLogic` (pure rules, emits events), `BattleAI` (blast centres, collateral, retaliation, bounded ranged holding), battle.gd (animation/UI; readability helpers `_see_through`, `_crowd`, `_settle_badges`, `_under_figures` run every frame — see HANDOFF.md §9) |

## World dict (GameState.world) — owned by adventure code
```
{ "seed": int, "size": Vector2i, "day": int (1-based total days), "current_player": int,
  "players": Array[player dict], "heroes": {uid: hero}, "towns": {uid: town},
  "objects": {uid: object dict}, "terrain": PackedByteArray (index into WorldGen.TERRAIN_ORDER),
  "blocked": PackedByteArray, "decor": Array, "tavern": Array[hero id], ... }
```
day -> week = (day-1)/7+1, day_of_week = (day-1)%7+1, month = (day-1)/28+1.
Tiles are 64px; objects have an action tile `pos` and an optional footprint (WorldGen.footprint_for).

## Adventure camera and movement
`adventure.gd.move_hero` owns `_follow` for both human commands and AI paths. Each step checks the human player's
existing explored grid. Visible AI movement centers immediately, then `_process` follows the sprite smoothly;
the selected human hero stays unchanged. Entering sight holds the first visible tile until the sprite emerges;
leaving sight releases follow at the last explored tile. Hidden steps skip animation and cannot redirect the
camera. `_interact_with` releases follow before visits/battles can rebuild nodes or replace the scene; normal
route completion also releases it. `_start_human_turn` restores the human hero's view through normal selection.
`MapView.move_hero_step` returns its position `Tween`; callers await `finished`, not a timer of the same duration.
Otherwise a late tween update can overwrite subsequent instant hidden movement and leave a sprite at the fog edge.
No persistent camera state or fog-rule changes; existing saves work after restarting.

## Adventure strategy
`AdvAI.choose` scores safe reachable objectives, favors its existing viable target by 20%, and discounts recent
assignments to another nearby hero for consumable/capturable sites. Repeatable shops and friendly towns remain
available to everyone. Optional `hero.ai_goal={pos:Vector2i,day:int}` persists through saves and is revalidated
on each decision; stale reservations expire. Defense overrides ordinary errands. `_counterattack` allows a
resident defender to remove a weaker reachable raider without abandoning the gate to other uncovered threats.
It checks the current movement budget, destination guards and an enemy's town garrison before committing.

`_leader` identifies the strongest army/hero. A small secondary army can deliver troops within half a day's
journey. `adventure.gd._interact_with` calls `exchange_troops` only at a normal friendly meeting. `_transfer`
obeys army slot limits and retains one creature; `_transfer_value` previews on deep copies. `_unlocks_assault`
also allows substantial nearby deliveries when the added troops make an enemy town within two days' travel
viable to attack; delivery itself still has the half-day limit. A changed army or gained XP counts as progress
when an adjacent meeting/victory consumes no movement. `_reinforce` pays ordinary upgrade costs, merges identical
stacks before collecting troops to free slots, then merges again after upgrading the additions. `dwelling_recruits`
shares the exact affordable/carryable count between selection and purchase, including rare resources.
Map-spell planning and fog-aware strategic knowledge remain unimplemented. Campaign results in HANDOFF.md show
a gain against `4f126ec` on fresh size-36/two-player maps with instant AI battles. Four-player size-48/64 validation
is recorded in `docs/CAMPAIGN_VALIDATION.md`; small samples do not establish a broader strength gain.

`AdvRules.roll_level_up(hero, rng=null)` honors a supplied generator for both stats and skill options; otherwise
it uses the global gameplay stream. No reseeding from wall-clock time. Other presentation randomness still needs
isolation before deterministic network/replay support.

## Battle presentation
`stand_pos` starts from `_footprint_center` and offsets aligned figures on successive rows by up to 18px within
their footprints. `_crowd` settles idle nodes and keeps existing crowd scaling; `_anim_move` marks its node
`moving` so layout cannot override its tween. Rings follow the actual node. Combat hexes, movement costs, hit
testing and depth order are unchanged. Focus fading still handles residual wing overlap. The Necropolis corner
hero uses the existing outline shader with a modest rim/exposure lift against dark towers.

## Artifacts
`GameData.ARTIFACTS` (tiers treasure/minor/major/relic, set pieces with `"set"`, combinations with `"parts"`; the
bonus keys and flags are listed in its header comment) and `GameData.ARTIFACT_TIERS`. Rules in `GameState`:
`hero_stat` (numbers), `hero_flags` (immunities, raise), `artifact_slots`, `can_wear`, `give_artifact` / `swap_artifact`
(both return the name of a combination they completed), `merge_combinations`, `split_combination`,
`join_combination` (a hero's `"apart"` list keeps split sets from re-merging). Effects are applied in
`BattleLogic.max_hp / speed / spell_damage / immune`, `Necromancy` (post-battle raising), `AdvRules` (scouting, daily gold and
mana, weekly first-level growth). Placement by tier: `WorldGen._place_artifacts`. Design: `docs/ARTIFACTS_PROPOSAL.md`.

`MapView._ArtifactGlow` draws the twinkle as explicit convex triangles, skipping near-invisible subpixel phases.
This avoids triangulation of a collapsing concave star. A windowed phase sweep is in `tools/artifact_glow_test.tscn`.

## War machine shops
`GameData.WAR_MACHINES` lists the three purchasable types, with prices in `CREATURES`; `SMITH_MACHINE` keeps the
town Blacksmith faction-specific. `GameState.war_machine_reason` / `buy_war_machine` share validation and payment
between the Blacksmith, factory and AI, using the hero's existing `machines` array (one per type, outside the army).
`WorldGen` places neutral `war_machine_factory` objects before other sites, trying one near each start and a wider
fallback if needed. `_factory_access` checks a path with the proposed walls in place; placement reserves the path
and its diagonal side tiles against later building footprints. `MapView` renders the factory painting at 3.2 tiles
wide. `AdvRules.visit` emits a `factory` event without consuming/capturing the site; `adventure.gd` opens
`WarMachineShop` (`scripts/ui/war_machine_shop.gd`) for a human, or calls `AdvAI.buy_from_factory`.
The three-card modal refreshes prices/owned states and the HUD after each purchase. AI shares its planned shopping
list with target valuation, keeps 1000 gold, and only buys a cart for shooters. Existing battle, hero-screen and
save systems already use `machines`; no save schema change. Existing saves keep their map, new games gain factories.

## Necromancy
`scripts/battle/necromancy.gd` (`Necromancy.calculate`) previews the reward against the winner's surviving army;
it does not mutate it. Played battles supply separate lost stacks from `BattleLogic.necromancy_casualties`, including
undead and destroyed war machines, excluding fortification towers. Instant battles supply their defeated army.
Rates are 10/20/30%, plus worn bonuses and each owned Necromancy Amplifier, capped at 100%; count and creature-health
limits are applied per stack with a minimum of one. With no free slot or basic stack, an existing upgraded stack
receives two thirds as many. The existing custom Mantle raises Zombies (or Plague Zombies by the same slot rule).
`battle.gd._end_battle` shows the actual count/type with a portrait, or explains no room/no casualties.
Results carry `raised`, `raised_id`, `necromancy_reason`. `AdvRules.apply_battle` restores survivors first and awards
the troops to either winning hero, including a town defender. `quick_resolve` uses the same calculator. Skills are
read before post-battle level-ups and loot; no new persistent fields or save migration. Existing saves benefit on
future battles after restarting; past missed rewards cannot be reconstructed from the stored world.

## Scene flow
Main menu -> New Game -> sets `GameState.new_game_settings`, clears `GameState.world`, changes to adventure, which
generates the world. Adventure -> town: `open_town(uid)`; town "Exit" -> adventure.
`AdventureHUD._town_card` and `town_screen.refresh` read `built_today` for the shared UI badge and tooltip.
Town refreshes its Hall button immediately after building; returning to adventure or refreshing the HUD after a
new day rebuilds the castle cards from current state.
Adventure -> battle: `GameState.start_battle({...})`; battle -> `GameState.finish_battle(result)`; adventure applies
`GameState.battle_result` in `_post_ready`. Battles with no human side are resolved instantly (`AdvRules.quick_resolve`).
AI turns run inside the adventure scene and resume after a battle scene change.

Every scene also works when launched DIRECTLY (for screenshots): missing state -> demo state.

## Tools (see HANDOFF.md for the workflow and expected outputs)
- `sh tools/check.sh` — re-import + compile every script (prints only errors).
- `sh tools/run_tests.sh` — the full test pass of a round: check, `battle_test` (40 AI-vs-AI battles checking hex
  rules), `battle_visual_test` (fixed siege overlap, displayed-turn focus and corpse regressions),
  `battle_ai_test` (15 tactical checks), `adventure_ai_test` (54 spending/defense/coordination/transfer/RNG checks),
  `campaign_week_test` (63 integrated week/save checks), `campaign_flow_test` (29 real tactical-scene/return/save checks),
  `adventure_tournament --self` (two-player and four-player RNG controls),
  `artifact_glow_test` (4096 phase draws in a window, inspect errors),
  `adventure_camera_test` (33 movement/visibility/turn-camera checks),
  `war_machine_test` (purchases, factory persistence, AI, generated access and battle ammo),
  `necromancy_test` (46 checks of raising rules, slots, casualties and rewards on both sides),
  `click_test` (map clicks, drag, queued clicks), `visit_test` (hover "visited" lines), `artifact_test` (every
  artifact's effect, slots, combinations, tiered placement), `sim_test` (all-AI soak).
- `tools/adventure_camera_test.tscn` — real adventure scene/camera assertions for visible and hidden movement,
  entry/exit at fog boundaries, short routes, different heroes, visit cleanup, human following and End Turn through
  actual AI choice/pathing into the next day. Headless by default; run in a window with `-- --capture` for screenshots
  in `shots/adventure_camera/`, then restore `project.godot`. Uses a generated test world, never the user's save.
- `tools/war_machine_test.tscn` — headless checks for prices/duplicates/funds/ownership, old heroes lacking
  `machines`, repeat visits by either player, serialization, machine deployment and ammo supply, AI spending,
  and factory count/access/roof clicks across 24 maps (32/36/48/64, two/four players, three seeds).
- `tools/necromancy_test.tscn` — rates, small battles, undead/machines, full and upgraded armies, no-room feedback,
  stacked amplifiers/artifacts, Mantle health cap, separate casualty stacks, field/town attacker/defender rewards,
  serialization, and instant resolution on both sides. Does not touch the user's save file.
- `tools/campaign_week_test.tscn` — a controlled seven-day fixture through production movement, visits, battles,
  enemy AI, building/recruiting, factory purchases, Necromancy and weekly growth. Saves/loads an isolated
  `user://campaign_week_test_<pid>.dat`, compares the complete world and removes only that test file.
- `tools/campaign_flow_test.tscn` — a watcher surviving real adventure/battle scene changes. Human attack,
  Defend/Auto controls, tactical victory, XP/level-up/Necromancy, real result dismissal and subsequent movement;
  then End Turn -> AI attack -> human retreat -> interrupted AI turn resumes exactly once. Isolated save API
  round trips after both cases, adventure scene reload, and hash check of the untouched default player save.
  Scripted fixture, not a competitive human playtest; button signals drive controls and saves use the optional
  test path, not the main-menu save slot. `-- --capture` saves screenshots under `shots/session50/flow/`.
  Run windowed for captures and restore `project.godot`; the full suite runs it headless.
- `tools/ai/campaign_driver.gd` — headless subclass of the adventure controller. Suppresses drawing, camera
  visibility and game-over popups; all players must be AI. Runs real turns and instant battles, counts battles.
  Optional JSONL tracing records moves (positions, target, movement/army/XP deltas) and end-turn resources,
  heroes and town garrisons/recruit pools. Recording does not call policy decisions or consume randomness.
- `tools/adventure_tournament.tscn` — generated maps, current policy rotated through every seat versus the frozen
  `tools/ai/adventure_ai_baseline.gd` from `35ed2e6`. Example: `Godot --headless --path .
  res://tools/adventure_tournament.tscn -- --pairs=48 --start=200 --days=42`. `--self` uses baseline on both sides
  and fails if any pair differs. Reset UID and global RNG for each game. Strategic score: army + 5000/town +
  half treasury gold + 100/hero level + five days' mine income (wood/ore valued 100, rare resources 250).
  Report paired normalized score delta with two standard errors and actual wins/losses/unresolved separately.
  Many games hit the limit: a score advantage is not an elimination. Shared rules are the same for both policies.
  `--baseline=res://tools/ai/adventure_ai_checkpoint.gd` selects the frozen `4f126ec` coordination policy;
  original `adventure_ai_baseline.gd` remains the default and unchanged. `--trace=shots/run.jsonl` enables
  diagnostics (create its parent directory first). Session49 validation: `--pairs=48 --start=400 --days=84`
  with the checkpoint baseline; repeat with `--days=42` for the earlier cutoff on the same maps.
  `--players=2|3|4 --size=32|36|48|64` broadens coverage; two-player defaults preserve the original statistic.
  With N players, sum `(candidate - mean(other scores)) / total_score * 100/N` over N rotations of each map;
  estimate two standard errors over maps, not the correlated seats. Four-player score scale differs from two-player.
  Play continues until one player remains or the day limit, even after the candidate loses. Wins mean sole survivor,
  losses mean candidate eliminated; unresolved means candidate survives with opponents. `games_at_limit` counts
  all unfinished games, including losses where other players are still fighting. Day 85 means 84 days played and
  the next day's reset (the historic two-player convention). `--maps=404,408` replays explicit map IDs;
  `--dump=shots/states` writes final world dictionaries to `<map>_<seat>.dat`, separate from player save files.
- `tools/campaign_snapshot_report.tscn -- --dir=shots/states` — reads those final worlds and reports each live
  hero's defense decision, target, route to enemy towns and approximate force ratio. Uses the current policy only
  for the filename's candidate seat, the selected `--baseline` for others (default `4f126ec`). If a route is missing,
  checks a copy with other allied heroes removed to distinguish traffic from terrain. Does not write snapshots.
- `tools/campaign_trace_report.py <trace> --after=42` — standard-library summary of late actions, no-action hero
  turns, final armies/positions and unused garrisons. No-action turns may be intentional defense; the report
  provides evidence for investigation, not an automatic stall verdict. Old traces have no XP delta.
  Each owner's last recorded turn is a different instant; capture later that day can make those town counts
  overlap. Use final binary snapshots for synchronized end-state ownership.
- `tools/artifact_glow_test.tscn` — render 32 glows over 128 frames, sampling appearance/disappearance thresholds
  and the wider cycle. Run windowed for actual renderer verification; `-- --shot=shots/x.png --delay=1` holds a
  labelled phase sheet. Restore `project.godot` after any windowed run (the full suite's exit trap does this).
- `tools/battle_visual_test.tscn` — 25 headless assertions. Add `-- --shot=shots/x.png --case=crowd|distant|corpses|lightning|wreck|movement`
  in a window to hold the same siege layout for screenshot comparison. Battle `_acting_uid` tracks the turn being
  animated (rules can already be on the next turn); `_figures_overlap` samples sprite alpha above the ground shadow.
  Checks also compare painted overlap with/without staggering, unchanged combat cells and smooth flyer movement.
- `tools/ai_tournament.tscn` — the current battle AI against the frozen baseline (`tools/ai/battle_ai_baseline.gd`):
  `Godot --headless --path . res://tools/ai_tournament.tscn -- --games=300` (600 battles; allow several minutes); prints the win rate
  and the paired difference in army kept, with its error bar. Measure every battle-AI change with it; refreeze the
  baseline (copy battle_ai.gd over it, class `BattleAIBaseline`) only after a change is accepted.
  `--start=300` selects fresh pairings. `--baseline=res://path/to/snapshot.gd` compares directly with another
  revision (remove its `class_name` declaration to avoid a global-name collision). Round47 uses a local snapshot
  of `bc013e6:scripts/battle/battle_ai.gd` at `shots/session47/battle_ai_before.gd`; the original frozen baseline
  stays unchanged. Unfinished battles print their pairing/side/remaining stacks for reproduction.
- `AdvAI._town_threat` follows real routes within an enemy's next-day movement budget. `_defense` holds a viable
  resident or selects the nearest capable hero able to arrive today; `_safe_gate` checks entrance guards.
  `_next_building` reuses town legality with tomorrow's build flag; `_recruit` shares ordinary/emergency recruitment.
  No extra persistent world fields or save migration are needed.
- `sh tools/judge_round.sh N` — the 33 judge screenshots (`tools/judge_shots.sh`) into shots/judgeN, size-checked;
  the judge agent's prompt is `tools/judge_prompt.md`.
- `tools/sim_test.tscn` — all-AI soak test: `Godot --path . res://tools/sim_test.tscn -- --seconds=80`
  (prints `SIM day ...` summaries and `SIMBATTLE` lines).
- Screenshot harness:
```
Godot_v4.7.2-stable_win64_console.exe --path . -- --shot=shots/x.png --scene=res://scenes/battle.tscn --delay=3
```
Options: `--shots=N --interval=S`, `--click=x,y;x,y` (`r` prefix = right click), `--keys=Space;Enter`, `--hover=x,y`,
`--setup=<name>` (`demo`, `rich`, `new_game`, `all_spells`, `upgraded`, `siege`, `siege_haven`, `necro_rich`,
`necro_max`, `x`); adventure also `--seed --faction --reveal --cam=x,y --zoom`, battle `--broken=a,b` (breached walls).
Window must not be headless (rendering needed). Screens are saved at the window resolution (1600x900 by default).

## Art & audio pipeline (see ASSETS.md)
- Blender (via the Blender MCP) renders all sprites: `tools/art/blender/*.py`, driven by `batch.py`
  (`run(["creatures", "battle", "towns", ...])`). Textures/HDRIs are CC0 from Poly Haven, cached in tools/art/raw/.
- Python post-processing: `tools/art/postfx.py` (ink outline, saturation), `sky.py` (painted skies),
  `portrait_bg.py`, `icons2d.py` (spell icons, icon frames), `town_crop.py` (town layers + layout json),
  `terrain.py` (terrain textures), `ui_art.py` (panels, buttons, logo).
- Audio: `tools/audio/gen_audio.py {sfx|music|voice}` — ElevenLabs (key from ELEVENLABS_API_KEY).

- Machine wrecks: `battle.gd._pose` scales `<machine>_dead.png` by its painted width relative to the idle sprite;
  missing death sprites retain the existing fallback. First implemented: ballista. `tools/art/sprite_sizes.py`
  accepts optional filenames to update only those metadata entries. Prompt/provenance: `tools/art/ballista_wreck_prompt.md`.
