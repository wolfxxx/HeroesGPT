# Handoff — where the project stands and how to carry on

Read this first, then `ARCHITECTURE.md` (code map), `ASSETS.md` (every asset path and the art pipeline) and
`CREDITS.md`. This file is written so that another person or another AI assistant can pick the work up exactly
where it stopped. Last updated 2026-10-22 (HeroesGPT repository continuation; latest visual review: judge 47,
overall 9.4), branch `main`, remote `https://github.com/wolfxxx/HeroesGPT.git` (public repo).

## 1. The project in one paragraph

"Heroes of the Shattered Crown" is a Heroes of Might and Magic III–style game in Godot 4.7 (GDScript): a random
adventure map with heroes, mines, monsters and fog; two factions (Haven, Necropolis) with painted town screens,
building and recruiting; hex battles with 14 creatures, war machines, spells and sieges; a computer opponent;
music and sound. All art is 3D library models rendered in Blender and then painted over by an image model, plus
painted icons and UI. The work has gone in **rounds**: an independent judge agent scores 33 screenshots against
the look and feel of HoMM3, and each round fixes what the judge found.

## 2. Status

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

## 5. Commands

| What | Command |
|---|---|
| Run the game | `run.bat` |
| Compile-check every script | `sh tools/check.sh` → `CHECK DONE, failures: 0` |
| Full test pass (~4 min) | `sh tools/run_tests.sh` (expected output is in its header) |
| One screenshot | `Godot --path . -- --shot=shots/x.png --scene=res://scenes/battle.tscn --delay=3 --setup=demo` |
| Judge screenshot set | `sh tools/judge_round.sh N` → `shots/judgeN/` (33 shots, 1600x900) |

Screenshot harness flags (`scripts/core/shot.gd`, coordinates in 1920x1080 space, images saved at 1600x900;
`--setup=artifacts` lays an artifact of each tier beside the first hero):
`--shot --scene --delay --shots --interval --click=x,y;x,y (prefix r for right click) --keys=A;S --hover=x,y`;
scenes also read `--setup=` (`demo`, `rich`, `new_game`, `all_spells`, `upgraded`, `siege`, `siege_haven`,
`necro_rich`, `necro_max`, `x`), `--seed --faction --reveal --cam=x,y --zoom --broken=a,b`. The harness parks the
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

**Session52 progress on this plan:** steps 1 and 4 done with one kept fix and no measured strength change (see
§2). Remaining: step 2 (incompatible full armies and couriers; leader-only garrisons was tried and rejected),
step 3 for the cases still unresolved, step 5 for Necropolis and a human playtest. Two-player size-36 games are
early rushes; judge long-game changes mainly on four-player/larger maps. Next map IDs to reserve: 1700+ (1300–1323,
1400–1407 validation and 1500–1523, 1600–1607 development were used in session52).

**Following milestone:** hot-seat multiplayer (human/computer selection, private turn handoff, human-versus-human
battles, saving and turn ownership). Fog-information policy, map-spell planning, difficulty settings, remaining
machine wrecks and visual findings stay on the backlog; online multiplayer remains a separate larger project.

### Playtest findings (session52, one Haven campaign on Normal; not yet fixed)
Ranked by impact. Evidence (screenshots `s###.png`, logs) is in ignored `shots/playtest/`.
1. **FIXED (session52): map objects walled off from every route.** In the playtest a Griffin dwelling, a Sawmill and
   six artifacts could not be reached. With the game's real movement rule the sweep found unreachable objects on
   35 of 36 generated maps; now 0 (see §2).
2. **AI leaves its capital empty / low pressure.** Gravenmoor (9 buildings) was taken on day 11 with no garrison
   and no hero; the AI's heroes fought one at a time and never combined. This matches the planned §8 step 1
   (defense versus conquest, case 427/0) and suggests checking garrison retention when the main hero leaves.
3. **FIXED (session52, user-approved): meeting your own hero by click, with troop and artifact trading** (see §2).
4. **Hero drawn behind a building after a visit.** After walking into a mine/windmill entrance the hero sprite is
   hidden behind the building (only the flag shows) until the scene is rebuilt (reload fixes it).
5. **Decorative red rocks look like a resource pile.** A sand-terrain red-rock decor sprite reads as Sulfur/Crystal;
   walking onto it does nothing.
6. **Right-click on the map shows only a one-line toast** ("A pack of Archers"), not HoMM3's held info popup. The
   hover panel carries the detail, so this is minor.
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
3. **Multiplayer.** None today (`world_gen.gd`: `"is_ai": i != 0`). Step 1, hot-seat (players sharing one
   computer, as HoMM3): choose human/computer per player on New Game, a "pass to the next player" screen,
   human-vs-human battles. Step 2, online play, is its own large project: an authoritative host, deterministic
   seeded randomness in battle and on the map, disconnects, saving. Keep these rules from now on: all game state
   stays in saveable dictionaries, all randomness goes through a seeded generator, screens never change the rules'
   state directly (the split of `adv_rules`/`battle_logic` from the views already helps).
4. **War-machine wrecks — STARTED.** Ballista is implemented and visually checked in round47d. First aid tent,
   ammo cart and catapult still use the old rotated-sprite fallback. Add `<id>_dead.png`, an anchor and a measured
   width for each; the battle loader now scales native-resolution wrecks to their idle footprint.

## 9. Where the recent systems live

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
  - `_Shadow` — rings; a struck stack's ring flares in its own side colour.
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
