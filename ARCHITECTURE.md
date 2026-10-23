# Architecture — Heroes of the Shattered Crown (Godot 4.7, GDScript)

Godot exe: `C:\Users\PC\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe`
Design resolution 1920x1080, stretch mode canvas_items/expand. All UI coordinates assume 1920x1080.

## Autoloads (scripts/core)
- `GameData` — static tables (creatures, heroes, spells, buildings, artifacts, terrains, mines). Source of all ids.
- `Assets` — `Assets.tex("creatures/pikeman.png")` with placeholder fallback; `Assets.anchor(path)` returns the
  foot point of a Blender-rendered sprite (from `<dir>/anchors.json`). See ASSETS.md for every asset path.
- `Audio` — `Audio.music("battle")`, `Audio.sfx("sword_hit")`; pitch uses a private RNG, independent of gameplay.
- `GameState` — world state across scenes, fade `change_scene()`, battle/town handoff, hero helpers, save/load.
  `save_game`, `load_game`, `has_save` accept an optional path for isolated tests; without one they use
  `GameState.save_path` (default `user://savegame.dat`; remote playtests point it at `user://playtest_save.dat`).
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

## Map access (WorldGen)
`_reachable` floods with the game's movement rule (a diagonal step needs a free orthogonal side tile). `_carve_road`
keeps one corner tile clear at each diagonal road step. After all objects are placed, `_ensure_access` connects every
object and town to the first town: it A*s through trees/rocks (`forest` tiles, weight 6; water, mountains and building
walls solid), clears those tiles and their decor sprites, and removes an object only when no such path exists
(printed as "WorldGen: N unreachable object(s) removed"). `WorldGen.last_cleared` lists the opened tiles.

## Optional seven-day townless rule
`world["townless_limit"]` (New Game "Without a town": 0 = play on, 7 = classic; `WorldGen` copies the setting, missing
in old saves = 0). `AdvRules.capture_town` starts the loser's `townless_days` at limit+1 when it loses its last town
and clears the new owner's; `tick_townless` (first thing in `new_day`) counts each townless living player down and,
at 0, removes its heroes and marks `defeated_townless` before `check_eliminations`. `townless_days_left(player)` is
-1 when not counting. `adventure._turn_banner` warns the human; `_check_game_over` has its own defeat text;
`GameData.loss_text(loss, townless)` adds it to the Defeat line. `AdvAI.choose` lowers a townless player's town-assault
threshold to 1.1x and raises its value. `adventure_tournament --townless=7` enables it in benchmarks.

## Announcements
Battle result (`battle.gd._end_battle`): lists the loser hero's `artifacts` + `backpack` as "captures" when both sides
have heroes and the loser did not retreat/surrender (the transfer itself is `AdvRules._loot` in `apply_battle`).
Town visits: `adventure._enter_own_town(hero, town)` -> `{hero, learned, mana}` -> `open_town(uid, report)` ->
`GameState.pending_town["report"]`; `town_screen._announce_learning(learned, mana_gain)` shows the "Mage Guild"
dialog (also after building a guild level or hiring, via `_learn_guild_spells`). `Modal.add_icon_flow` wraps long
icon lists. Test: `tools/announce_test.tscn` (real battle end -> adventure transfer; real visit -> town dialog).

## Hot-seat
Seats: New Game settings `seat_human` / `seat_faction` / `seat_hero` / `seat_bonus` (arrays of 4; Red is always
human and keeps the plain `faction` / `hero` / `bonus`; "" = random), edited by `main_menu._refresh_seats` and the
left-side cards, which show the colour in `_edit_seat` (`_choice` / `_set_choice`; `_fix_seats` keeps every
person's hero unique, greyed for the others). `WorldGen.generate` draws every computer-style faction from the rng first and then
applies a chosen one, so a one-human game is unchanged; humans get the difficulty's human resources, a per-player
`start_hero` (their chosen hero unless another took it), and their chosen starting bonus (random if none). `player["is_ai"]` is the only switch the rules read.
Viewpoint: `GameState.human_player_index()` = the current player if it is a living human, else `world["viewer"]`
(set at each human turn start), else the first living human (all fallen: the last one, for the defeat). Everything
that shows "your" kingdom (fog, HUD, town fallback, remote `state`) goes through it. `GameState.hotseat()` = two or
more living humans. Turn handover: `adventure._start_human_turn` covers the screen (`_cover`, CanvasLayer 80 under
the modal layer 90), switches the view, selects that player's hero, then shows "<name>'s Turn"; `_post_ready` does the
same for the first turn and a loaded game, using the unsaved `GameState.handed_over / was_handed` (tied to the world
instance). `_turn_banner` shows the new week to each human once (`pending_week["seen_by"]`). `_start_battle`: a
computer attacking a human other than the viewer shows "To Arms" behind the cover and makes them the viewer.
`_check_game_over` first runs `_hotseat_defeats` (each fallen human told once, `defeat_told`; a lost champion in a
hero scenario -> `AdvRules.eliminate`), passes the turn on if the current human fell, then checks defeat/victory for
the viewer (others alive = any other living player). Battles: `BattleLogic.ai_side` per side; `battle._end_battle`
titles a human-vs-human result from the winner's side. Test: `tools/hotseat_test.tscn`.

## Map right-click and depth
Right button down on the map: `adventure._right_click` shows `_tile_info(t, true)` (the hover panel; heroes add
`_army_row`, own towns their garrison) via `HoverInfo.show_for(self, …, 0.0)`; release hides it (`_rclick_info`).
`MapView.hero_foot` is 1px below `foot_of` so heroes win y-sort ties with buildings on their tile.
Selection (as HoMM3, one or the other): `world["selected_hero"]` (uid, -1 for none) or, while it is -1,
`world["selected_town"]`; `adventure.select_town` (the town list's first click) drops the hero selection and centres
the map, `_select_hero` erases the town, `selected_town()` returns the human's selected town or {}. The status
window's view 0 shows the hero, else the town (`adventure_hud._town_view`), else the kingdom.
Garrison hero (as HoMM3): `town["garrison_hero"]` = uid and `hero["in_town"] = true`; the hero keeps the town's pos but
takes no tile in `AdvRules.occ` (the gate stays free, `MapView.rebuild_objects` draws no figure) and cannot plan a
route. `AdvRules.garrison_hero`, `town_army` (its army, else the garrison), `visiting_hero`, `enter_garrison` (the
garrison's troops join its army; false when they don't fit), `leave_garrison`, `swap_garrison`; `town_defender`
returns it first. An enemy at the gate of a town that holds a garrison hero is fought in the open
(`adventure._interact_with`), the garrison hero then in a siege. The town screen's portraits pick, move, swap and open
(`town_screen._hero_slot`). The AI counts a garrison hero in a town's defence (`AdvAI._town_hold`) and never as a raider.
A computer hero holding a threatened town from its gate (`_defense` -> "hold"; `choose` notes it in `holding`)
moves into the garrison in `run_turn` (`AdvAI._garrison`, when the troops fit). Each turn a garrison hero steps out to
the gate (`_step_out`, when it is free) and decides again, going back in if it still holds; `manage_towns` runs while
it is inside, so the free gate can take a hire. A full army swaps its weakest stacks for a courier's or a garrison's
stronger ones (`_transfer`, `_collect_garrison`; `_best_stack`, `_weakest_stack`; never below a threatened gate's
keep, the donor keeps creatures).
Fortification levels (`TownLogic.siege_level`: 0 none, 1 Fort, 2 Citadel, 3 Castle) drive both the town's map picture
(`MapView.town_sprite`: village / walled town / castle, also used by the HUD town list, the kingdom overview and the
town screen's banner) and the siege: `BattleLogic` puts the moat in front of the wall only at level 2+
(`is_moat`), the corner segments (rows 0 and 10, `SOLID_SEGS`) are never walkable and only a Castle's can be hit
(`breakable`); `battle.gd` loads `battle/bg_siege_<faction>_<level>.png` and that level's breach overlays
(`siege.json` key `<faction>_<level>`), `WALL_BANDS` and `ARCHER_SPOTS` matching the painted layout. A segment hit
once shows its painted battered overlay (`_battered`, `_show_battered`); `_Cracks` only draws for one without.

## Meeting your own hero
`adventure.gd._click`: with a hero selected, a click on another of your heroes plans the `meet` route (status line
"Meet <name> (trade troops)"); a second click executes it, and `_interact_with` opens `AdventureHUD.open_exchange`.
With no route the click selects that hero, as before. `open_exchange` shows both armies (shared `ArmyStrip` group)
and, per hero, `_exchange_artifacts`: worn, then "Backpack:" and carried artifacts as `HeroScreen._Socket`s (meta
`artifact`); a click calls `GameState.transfer_artifact(from, to, a)` (receiver wears it if slots are free, else
carries it; combinations move whole; merges announced) and redraws both rows. AI meetings (`AdvAI.exchange_troops`)
do not move artifacts.

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
`_assault_rally` previews multiple donors sequentially on army copies. If their combined transfers make a nearby
town assault viable, donors that can arrive today (at most one normal day's travel) move before the leader.
Assigned defenders stay in place; each donor retains one creature, and execution uses ordinary adjacent meetings.
The rally is local to `run_turn` and is recomputed after a battle; no new save fields. The safety estimate still
does not model every spell/morale effect or guarantee a successful assault.

`_leave_rear_guard` runs in `run_turn` before a hero moves off its own town: if `_town_threat` finds an enemy army that
can reach the gate next turn, the cheapest units needed to hold it (garrison x1.25 >= threat x1.4) stay behind,
whole units only, at most 25% of the hero's strength, at least one creature kept. Frozen `555fedc` policy:
`tools/ai/adventure_ai_session51.gd`; `campaign_resume_test --before=` selects the comparison policy.
A hero collecting a garrison (`_reinforce`, and `choose`'s value of a town's troops) goes through `_collect_garrison`:
when `_town_threat` finds an army able to reach the gate next turn and the garrison can hold it (x1.25 >= threat x1.4),
`_garrison_keep` leaves that much and the hero takes the rest, most valuable first. `_counterattack` strikes a raider
at 1.3x, the margin of any attack on a hero. Frozen `1dfa88b` policy: `tools/ai/adventure_ai_session52.gd`;
frozen `349549d` policy: `tools/ai/adventure_ai_session54.gd`; frozen `efc9a86` policy (session65, garrison
heroes): `tools/ai/adventure_ai_session65.gd`.

`_plan_with_passage` helps only the strongest army when its normal route is blocked. It temporarily relaxes
eligible friendly occupancy in the AStar grid, restores the grid, then returns a transient `yield` plan for a
blocking hero's legal one-step move off that route. Town gates, occupied/guarded tiles and assigned defenders
are excluded. `run_turn` moves that ally through the normal controller, pays movement, and replans the leader
against real occupancy. Idle heroes retain unused movement so a later army can request passage. An occupied
shop/dwelling cannot masquerade as a purchase: a meeting must either be an intended delivery or transfer useful
troops. Useful incidental exchanges remain allowed.
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
  rules, plus `_siege_rules`: per fortification level the moat, which corner segments the catapult may hit, the solid
  corners and no way out past a standing wall; `_speed_spells`: Slow/Haste mid-round re-sort the stacks yet to act), `battle_visual_test` (fixed siege overlap, displayed-turn focus and corpse regressions),
  `battle_ai_test` (15 tactical checks), `adventure_ai_test` (94 spending/defense/coordination/transfer/garrison/RNG checks),
  `campaign_week_test` (63 integrated week/save checks), `campaign_flow_test` (29 real tactical-scene/return/save checks),
  `adventure_tournament --self` (two-player and four-player RNG controls),
  `artifact_glow_test` (4096 phase draws in a window, inspect errors),
  `adventure_camera_test` (33 movement/visibility/turn-camera checks),
  `war_machine_test` (purchases, factory persistence, AI, generated access and battle ammo),
  `necromancy_test` (46 checks of raising rules, slots, casualties and rewards on both sides),
  `meet_test` (18 meeting-by-click and artifact hand-over checks), `announce_test` (10 captured-artifact and town-learning announcement checks), `hotseat_test` (46 hot-seat checks), `map_reach_report` (every object reachable on 36 maps),
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
  `--baseline=res://tools/ai/adventure_ai_session49.gd` selects the frozen `f69ad3a` policy for evaluating the
  rally/passage work. Its code matches that commit after subclass/constant-name adaptation; keep all frozen
  policies unchanged. Current results and limitations live in `docs/AI_COORDINATION.md`.
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
  Also prints carried armies, actual transferable value, delivery costs, current rally orders and requested
  step-aside moves. These are observations/previews, not an execution of the turn.
- `tools/ai/town_defense_report.tscn` — one policy in every seat on generated maps (production driver); every town
  capture with what the owner left at the end of its last turn (garrison, hero at the gate, strongest enemy within
  one and two days, own heroes able to return within one and two days, alone and together, garrison taken / hero
  walked out that turn), a summary and a RECALL line (captures returning heroes could have prevented, last towns).
  `-- --maps=1800,1801 --players=2 --size=36 --days=28 --policy=res://tools/ai/adventure_ai_session52.gd --verbose
  --trace=shots/x.jsonl`. Diagnostic only, not in the suite.
- `tools/campaign_resume_test.tscn` — paired diagnostic continuations of the unresolved session50 snapshots.
  Candidate seat runs frozen `f69ad3a` then current AI; other seats retain the original `4f126ec` opponent.
  Options: `--dir=shots/session50/states168 --days=28 --case=441_1.dat --trace=shots/run.jsonl` (case/trace optional).
  Copies the world, initializes UID above live entities and explicitly reseeds each variant identically. Snapshots
  have no RNG state, so this is not exact continuation of the original random stream or a fresh strength sample.
- `tools/campaign_trace_report.py <trace> --after=42` — standard-library summary of late actions, no-action hero
  turns, final armies/positions and unused garrisons. No-action turns may be intentional defense; the report
  provides evidence for investigation, not an automatic stall verdict. Old traces have no XP delta.
  Each owner's last recorded turn is a different instant; capture later that day can make those town counts
  overlap. Use final binary snapshots for synchronized end-state ownership.
- `tools/artifact_glow_test.tscn` — render 32 glows over 128 frames, sampling appearance/disappearance thresholds
  and the wider cycle. Run windowed for actual renderer verification; `-- --shot=shots/x.png --delay=1` holds a
  labelled phase sheet. Restore `project.godot` after any windowed run (the full suite's exit trap does this).
- `tools/battle_visual_test.tscn` — 40 headless assertions (with every machine's wreck and the battered wall). Add `-- --shot=shots/x.png --case=crowd|distant|corpses|lightning|wreck|movement`
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
- `tools/map_reach_report.tscn` — in the full suite: generates 36 maps (sizes 36/48/64) and counts objects/towns the
  first town cannot reach with the game's movement rule; must print `"maps_with_cut": 0` (exit code 1 otherwise).
  `-- --save=user://x.dat` checks a saved world; `-- --scenario=<id>` lists the tiles the access pass cleared.
- `tools/hotseat_test.tscn` — in the full suite: seats and generation, each player's own town/hero/bonus on the
  New Game screen (greyed heroes, back to the computer and again), the turn handover cover, Blue's own view,
  the new week for each human, save/load handover, a human-versus-human battle, the defence call, hot-seat defeats
  and the last player standing.
- `tools/garrison_hero_test.tscn` — in the full suite: a hero moved into a town's garrison by the town screen's
  portraits (refused when the garrison's troops don't fit its army), the gate freed for the Tavern, the swap, no map
  figure or route for the garrison hero, and an attacker meeting the gate hero outside first, then the garrison hero
  in a siege; the computer garrisoning a hero that holds a threatened town and letting it out once the town is safe.
  `-- --capture=shots/dir` in a window saves the town screen with both heroes.
- `tools/list_click_test.tscn` — in the full suite: the adventure panel's hero and town lists (a first click selects
  and centres, a click on the selected one opens its screen; a town and a hero are never selected together; the
  status window shows the selected town; the town stays selected on the way back from its screen).
  `-- --capture=shots/dir` in a window saves the panel with the town selected.
- `tools/retreat_test.tscn` — in the full suite: a hero retreating from a battle scene loses the army but not the
  war machines still standing (`battle._lost` leaves them out of the result window), waits in the Tavern and is
  hired again with them and the artifacts. `-- --capture=shots/dir` in a window saves the result window.
- `tools/map_figure_test.tscn` — in the full suite: a hero of each class on the adventure map drawn with its class's
  figure (`MapView.hero_figure`: `heroes/map_<class>.png`, else the faction's), and the Cleric's gallop with its own
  frames. Also the hero's pennant (`MapView._face_flag`: behind the rider, above its head, mirrored
  with the facing) and no owner-coloured outline on the figure (the flag tells whose hero it is). `-- --capture=shots/dir` in a window saves the four side by side and the Cleric mid-gallop.
- `tools/guard_pickup_test.tscn` — in the full suite: a hero walking onto an artifact beside a monster fights it and,
  having won, takes the artifact (a computer hero's fight quick-resolved; the human's through the battle scene and
  `_post_ready`). The pending visit is `hero["visit_after_guard"]`, done by `adventure.gd._visit_after_guard`.
  `-- --capture=shots/dir` in a window saves the find.
- `tools/meet_test.tscn` — in the full suite: real clicks on a second own hero show the route, then walk over and open
  the Hero Meeting dialog; an unreachable hero is selected instead.
- Remote play (`scripts/core/shot.gd`, `--remote=<dir>`): runs the real game from the main menu and executes
  command files written to `<dir>/cmd.txt` with real input events, then writes `<dir>/done.txt`. Commands: `click`,
  `rclick x y [hold] [shot]`, `dclick`, `move`, `park`, `key` (`ctrl+s` style), `keydown/keyup`, `wait`, `shot`,
  `state` (JSON of the human kingdom), `ctile x y [right]` (click a map tile, scrolling to it), `rtile x y seconds [file.png]` (hold right on a tile), `look [r]` (status
  text, route kind and cost of nearby explored objects), `probe x y` (what a click there resolves to),
  `hoverstate` (the hover panel and dialog layer, the viewport and OS cursors), `quit`. The harness moves only input
  events, never the OS cursor: code that needs the cursor reads it from events (`adventure._mouse`).
  Coordinates are window pixels (1600x900). Menus and Ctrl+S use `GameState.save_path` = `user://playtest_save.dat`,
  never the player's save; audio is muted; edge scrolling is off. Restore `project.godot` after the windowed run.
  Example: `Godot --path . -- --remote=shots/playtest`, then write commands to `shots/playtest/cmd.txt`.
- Screenshot harness:
```
Godot_v4.7.2-stable_win64_console.exe --path . -- --shot=shots/x.png --scene=res://scenes/battle.tscn --delay=3
```
Options: `--shots=N --interval=S`, `--click=x,y;x,y` (`r` prefix = right click), `--keys=Space;Enter`, `--hover=x,y`,
`--setup=<name>` (`demo`, `rich`, `new_game`, `all_spells`, `upgraded`, `siege`, `siege_haven` (with `--siege=1|2|3`),
`town_levels` (adventure: the first town a Castle, the second a village), `necro_rich`,
`necro_max`, `x`); adventure also `--seed --faction --reveal --cam=x,y --zoom`, battle `--broken=a,b` (breached walls),
`--battered=a,b` (walls hit once), `--heroes=attacker,defender` (battle heroes by id), `--players=a,b` (the demo
battle's player indices, -1 neutral: the flag colours), `--effects=bless;curse;bless+slow` (spells on the attacker's
stacks in order: the count box colours).
Battle colours (as HoMM3): the count box (`battle._Badge`) is the same purple for both sides, green under good spells
only, red under bad ones only (or disease), yellow under both (`_Badge.mood`: a spell targeting allies is good, enemies
bad). Whose stack is whose shows by its facing and its ring, which with the turn queue's cards, the hero's name plate
and spell banners take the player's flag colour (`battle.side_color`: `GameData.PLAYER_COLORS`, neutrals grey).
Battle hero animation (as the classic): `battle._hero_figs` per side; the hero rests on `battle_<fig>_idle0.png`,
`_process` plays `_hero_loop` (the idle frames 1-2-3-2-1-0) every 5-9 s, `_hero_cast` shows `battle_<fig>_cast.png` for
1.1 s when its spell event plays; `_hero_act` counts actions so a cast cuts an idle loop short. Shot case
`battle_visual_test --case=cast`.
Battle heroes: `battle.gd` draws `heroes/battle_<class>.png` (Cleric, Death Knight) or the faction's figure
(`battle_haven` a Knight, `battle_necropolis` a Necromancer). A right click on a stack opens `_show_stack_card` (the
hover panel's live card in a dialog). Turn order: `BattleLogic._turn_before` everywhere; `_resort_order` after a
Haste/Slow/Cure cast mid-round.
Window must not be headless (rendering needed). Screens are saved at the window resolution (1600x900 by default).

## Art & audio pipeline (see ASSETS.md)
- Blender (via the Blender MCP) renders all sprites: `tools/art/blender/*.py`, driven by `batch.py`
  (`run(["creatures", "battle", "towns", ...])`). Textures/HDRIs are CC0 from Poly Haven, cached in tools/art/raw/.
- Siege backdrops per fortification level: `tools/art/siege_levels_paint.py` (`collage`, `paint`, `breach`, `damage`,
  `retop`, `ingest`;
  imagegen/batch28); the earlier single painting's `siege_wall_paint.py` is superseded. Town map pictures per level:
  `tools/art/town_levels_paint.py` (`prep`, `paint`, `ingest`; imagegen/batch29).
- Python post-processing: `tools/art/postfx.py` (ink outline, saturation), `sky.py` (painted skies),
  `portrait_bg.py`, `icons2d.py` (spell icons, icon frames), `town_crop.py` (town layers + layout json),
  `terrain.py` (terrain textures), `ui_art.py` (panels, buttons, logo).
- Audio: `tools/audio/gen_audio.py {sfx|music|voice}` — ElevenLabs (key from ELEVENLABS_API_KEY).

- Machine wrecks: `battle.gd._pose` scales `<machine>_dead.png` by its painted width relative to the idle sprite,
  and `_anim_death` keeps a wreck's colours (saturation 0.8, dimmed) instead of the corpse grey; a machine without a
  wreck sprite keeps the old tipped-over fallback. All four machines have one: `tools/art/machine_wreck_paint.py`
  (`prep`, `paint`, `ingest`, `shrink`), the ballista's provenance in `tools/art/ballista_wreck_prompt.md`.
  `tools/art/sprite_sizes.py` accepts optional filenames to update only those metadata entries.
