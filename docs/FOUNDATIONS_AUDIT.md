# Foundations audit: what stands between the game and several factions played online

Status: **audit** (2026-10-24, at `d17502e`). Step 1, faction data, is **done** (section 4, "Done"). Step 2, the
command layer, is **done** for the map and towns (section 1, "Progress"; battles still to follow). Step 3, interface
state, is **done** (section 2, "Done"). Step 4, randomness and the replay test, is **done** (section 3, "Done"). It sizes "Phase 1: Foundations" of the plan in
HANDOFF §8: one action layer, repeatable randomness, a replay test, faction data. Line numbers are as of that commit.

## Summary

| Area | State | Size of the work |
|---|---|---|
| Battle actions | already command-shaped (`BattleLogic.do_move/do_melee/do_shoot/cast/do_wait/do_defend`); only the turn driver lives in the screen | small |
| Map and town actions | about a dozen player actions are carried out inside screens; the computer player has its own copies of several | **large** |
| Interface state in the saved world | selection, viewer, banners and "already shown" flags live in `GameState.world` beside the game | small to medium |
| Randomness | battles use their own generator but are seeded from the clock; map rules, hero creation and quick battles use the global stream, which battle animations also draw from; saves keep no random state | medium |
| Faction data | few direct "haven"/"necropolis" checks, but faction tables are spread over five files and some rules name one faction's buildings, classes or creatures | medium |

## 1. Where actions are carried out

The target: every action a player or the computer takes is one call into the rules (a command such as
`recruit(town, tier, n)`), which checks it, applies it and reports what happened. Screens only send commands and show
results; the computer sends the same commands. That is what lets an online host apply a remote player's actions, and
what makes a replay possible.

| Action | Done today in | Duplicate in the AI | Target |
|---|---|---|---|
| Move a hero along a path (spend movement, step, reveal fog, meet guards, visit) | `adventure.gd` 812–890, step by step while animating; the AI calls the same scene function | — (it uses the scene) | a rules command per step or per path; the screen animates the events it returns |
| Set a destination, sleep or wake | `adventure.gd` 512, 760, 788 | — | small commands |
| Take an unguarded town | `adventure.gd` 910–914 (calls `rules.capture_town`) | — | part of the move command |
| End turn, next player, new day | `adventure.gd` 1078–1083 (`rules.new_day` is a rule; who plays next is decided in the screen) | — | `end_turn(player)` in the rules |
| Recruit in a town | `town_screen.gd` 781 → `AdventureHUD.recruit_dialog` (993–994 pays and adds troops; a callback lowers `available`) | `adv_ai.gd` 228–232 (town), 338–340 (map dwelling) | `recruit(town|dwelling, tier, n, army)` |
| Recruit at a map dwelling | `adventure_hud.gd` 911 (same dialog) | `adv_ai.gd` 338–340 | the same command |
| Hire a hero at the Tavern | `town_screen.gd` 881–889 | `adv_ai.gd` 184–190 | `hire_hero(town, hero_id)` |
| Marketplace trade | `town_screen.gd` 968–972 | — | `trade(player, give, get, n)` |
| Move, split and merge stacks; exchange between heroes and with a garrison | `army_strip.gd` 86–101 | `adv_ai.gd` 243, 271–272, 289–292, 509–513 | `move_stack`, `split_stack` |
| A garrison hero takes in the town's garrison when the screen opens | `town_screen.gd` 86–91 | — | a rule on entering or opening, not the screen |
| Learn the Mage Guild's spells | `town_screen.gd` 56 and `rules.hero_in_town` (`adventure.gd` 1051) | — | the rule only |
| Battle formation | `hero_screen.gd` 412 | — | `set_formation` |
| Level-up skill choice | `rules.roll_level_up` / `apply_level_up` are rules; the computer's pick is `adventure.gd` 1032 | — | the computer's pick into the AI |
| Already rules (keep): build (`TownLogic.build`), war machines (`GameState.buy_war_machine`), garrison enter/leave/swap (`AdvRules`), Skeleton Transformer, artifacts (`GameState.swap_artifact`, `split_combination`), dismiss (`AdvRules.dismiss_hero`), chests (`rules.resolve_chest`), battle results (`rules.apply_battle`) | | | wrap as commands |
| Battle turn driver: machines act, fear, bad and good morale, next stack | `battle.gd` 733–797 | — | `BattleLogic.next_turn()` returning events |

**Progress (session67):** `AdvRules.do(cmd)` / `scripts/adventure/commands.gd` with `recruit_town`, `recruit_site`,
`hire`, `trade`, then `stack_move`, `move_troops` and `upgrade_stack`, then `step` and `end_turn`, then `visit`, `chest`, `capture` and `battle_result`; the town screen, the map dwelling
dialog, the army bars, the computer's transfers, every hero's walk, what the hero meets and every turn end use them. Each step left the computer's play unchanged: seeded tournaments with
`AdvAI` in a seat (no `--self`, which plays only the frozen baseline) identical before and after, the faction data step
re-checked the same way. Then `build`, the garrison moves, the artifact commands, `buy_machine`, `transform`,
`level_roll` / `level_up`: **every map and town action is a command** (step 2 done for the adventure map). Left: the
battle as commands (its moves are already `BattleLogic` calls; only `battle_result` crosses), the visit report without
textures, and steps 3-4 (interface state out of the world, repeatable randomness and the replay test).

A side benefit: the computer player stops re-implementing recruiting, hiring and troop moves, so it can't drift from
the rules a person plays by.

## 2. Interface state kept in the saved world

These keys live in `GameState.world` (saved, and in an online game shared by everyone) but describe one player's
screen: `selected_hero` (9 uses), `selected_town` (4), `viewer` (3), `intro_shown`, `pending_turn_banner`,
`pending_week` with its `seen_by`, `defeat_told`, `game_over`, `_removed`, hero `dest` and `face_left`, and the
AI's notes (`ai_day`, `ai_goal`, `yield`). In hot-seat this works because one screen serves everyone in turn. Online,
each player needs their own: move them into a per-player view state (or a `world["view"][player]` block that the
host never sends to others).

**Done (session67):** `world["views"][player]` (`GameState.view`) holds the selected hero and town, `intro_shown`,
the day's `news` (was `pending_week` + `seen_by`) and `defeat_told`; `viewer` is an unsaved `GameState` variable;
`_removed` is `AdvRules.removed`; `pending_turn_banner` was dead and is gone. Save version 2 converts version-1
saves on load. Kept as game state: `game_over`, hero `dest` and `face_left` (a route and facing other players see),
the AI's notes (`ai_day`, `ai_goal`, `yield`: the computer's own memory; on a host they stay with the host).

## 3. Randomness

| Where | What | Fix |
|---|---|---|
| `adv_rules.gd` 427–428 | Windmill resource and amount: global stream | world generator |
| `adv_rules.gd` 632 | Quick battle (`quick_resolve`) luck factor: global | world generator |
| `adv_rules.gd` 912 | Creature of the week: global | world generator |
| `adv_rules.gd` 294, 313 | Level-up: a supplied generator, else global | always the world generator |
| `game_state.gd` 105–108 | `make_hero` starting army (also every Tavern hire): global | world generator |
| `adv_ai.gd` 183, `adventure.gd` 1032 | The computer's Tavern pick and level-up pick: global | an AI generator seeded from the world |
| `town_logic.gd` 21 | Town names: global, but only during map generation, right after `seed()` | fine; move to the world generator for clarity |
| `battle_logic.gd` | Its own generator (good), but seeded only if the setup has a `seed`, and the map never passes one | the map draws a battle seed from the world generator |
| `battle.gd` 297, 418–419, 1447, 1674, 1814, 2097, 2590, 2627 | Animation timing and particles draw from the **global** stream, the same one the map rules use, so how long a battle animates changes later map rolls | a private presentation generator (as `Audio` already has) |
| Saves | No generator state is saved, so a reload rolls differently | save the world generator's state |

**Done (session67):** `scripts/core/dice.gd`. The world's dice (`world["rng"]`, saved) for every rule roll inside a
command (week creature, Windmill, level rolls, a hired hero's troops); `Dice.derived` (seeded from the world's state,
never moving it) for choices outside commands (the computer's Tavern and skill picks, `quick_resolve`'s luck, a
played battle's seed, which the map now always passes); `Dice.look()` for battle and map presentation. Town names
stay on the seeded global stream during map generation. The replay test (`tools/replay_test.tscn`) records every
command of two computer-played maps, replays them on the starting world and compares: it found one rule outside the
commands (a hero learning the Mage Guild's spells), now `town_visit`, and the `build` and `hire` results.
Seeded games changed with this step, so the tournament references were recorded afresh (HANDOFF §2).
**How much determinism online play needs depends on the model.** With a host that runs the game and sends results
(recommended in HANDOFF §8), the other players never run the rules, so the game does not have to be exactly
repeatable for online play to work. Repeatable randomness is still worth doing: reloads behave the same, the replay
test becomes possible, and a desync check can compare the host's and a client's world. A lockstep model (everyone runs
the rules) would need exact repeatability everywhere, including float maths in `quick_resolve`; it is not
recommended.

## 4. Faction data

Direct `"haven"`/`"necropolis"` checks in logic are few (`battle.gd` 302: the Necropolis hero figure brightened;
defaults and shot setups). The coupling is elsewhere:

**Faction tables spread over five files:** `GameData.FACTIONS`, `SMITH_MACHINE`, `FACTION_REQUIRES`, `SPECIALS`,
`DWELLING_NAMES`; `TownLogic.TOWN_NAMES`; `battle.gd` `ARCHER_SPOTS`; `town_layout.gd` (positions of the specials).
Move them into one `FACTIONS[id]` record: name, description, terrain, creatures, upgrades, smith machine, specials,
extra requirements, dwelling names, town names, hero classes; presentation details (siege archer spots, building
positions) into one presentation table keyed by faction with a default.

**Rules that name one faction's things:**

| Where | Names | Make it data |
|---|---|---|
| `adv_rules.gd` 534 | `brotherhood` → siege morale | a building effect `{"siege_morale": 2}` |
| `adv_rules.gd` 882 | `stables` → movement | a building effect `{"start_day_movement": 400}` |
| `necromancy.gd` 9–24, `adv_rules.gd` 732 | `skeleton`, `skeleton_warrior`, `zombie`, `necromancy_amplifier` | a faction "raise" rule `{skill, creature, upgrade, amplifier}`; Eridu's Shaping is the same rule with Lulu |
| `town_logic.gd` 111, `town_screen.gd` 545, 589–591 | `skeleton_transformer`, `skeleton` | a building effect `{"transform_to": "skeleton"}` and a generic "click a special" handler |
| `game_state.gd` 125, `adv_rules.gd` 292 | `Knight`, `Death Knight` as might classes | a `CLASSES` table: faction, might or magic, starting machine, figures |
| `adv_ai.gd` 7–8 | build order lists both factions' specials | derive from the faction's specials |
| `battle.gd` 1399, `army_strip.gd` 202–203 | per-creature sound and portrait tweaks by id | fine (per-creature presentation data); move into the creature records when touched |

**Asset paths keyed by faction id** (`town_<f>`, `layout_<f>.json`, `bg_siege_<f>_<n>`, `heroes/map_<f>`,
`battle_<f>`) are already data-driven: a new faction adds files under its id. Keep that.

**Done (session67):** the faction tables are one `FACTIONS` record each, `CLASSES` replaces the class lists, the
specials' effects are building data read by `TownLogic.effect`, Necromancy's creature comes from the skill's data, and
the computer's build order is derived per faction. `battle.gd`'s Order of the Dragon figure brightening is a faction flag. Left as
presentation keyed by id (fine): `battle.gd` `ARCHER_SPOTS`, `town_layout.gd` positions, `army_strip.gd` portrait
crops, per-creature sounds. Verified unchanged: a seeded four-player computer tournament (2 maps, 21 days, 244
battles) gives identical results before and after, and `tools/faction_data_test.tscn` checks the old build orders.

**Ids vs. names:** the setting renamed what players see; ids (`haven`, `necropolis`, `pikeman`...) stay. New
factions should get ids that match their names from the start (`eridu`).

## 5. Proposed order

1. **Faction data** (medium): one record per faction, building effects instead of building ids, a `CLASSES` table, a
   general "raise after battle" rule. Visible result: none; Eridu or a HoMM3 town then becomes mostly data and art.
2. **Command layer** (large, in steps): start with the town (recruit, hire, trade, stack moves), then hero movement and
   end of turn; the computer switches to the same commands as each lands. The AI benchmarks guard against behaviour
   changes.
3. **Interface state out of the world** (small to medium).
4. **Randomness and the replay test** (medium): a world generator saved with the game, battle seeds from it, a private
   presentation generator; then a test that records a short scripted game's commands, replays them from the seed and
   compares the worlds.

Then the online first version (HANDOFF §8, phase 2).

## Risks

- **AI baselines move.** Changing how random numbers are consumed changes every seeded game, so the frozen AI
  comparisons (`docs/CAMPAIGN_VALIDATION.md`) need a fresh same-policy control after step 4, and step 2 must keep the
  computer's behaviour identical (checked with the existing tournament tools).
- **Seeded tests.** Tests that expect a particular map or roll from a seed may need new expectations after step 4.
- **Saves.** Moving interface state and adding generator state changes the save layout: bump the save `version` and
  load older saves with defaults (the player's own save, `user://savegame.dat`, must keep loading).
