# Campaign validation — 2026-10-22

Session50 checkpoint `eb2c96c` added validation tools; its production AI and battle rules remained those of `f69ad3a`.
Later coordination changes and their separate measurements are in [AI_COORDINATION.md](AI_COORDINATION.md).
Comparator: frozen `4f126ec` in `tools/ai/adventure_ai_checkpoint.gd`. No policy tuning followed these runs.
Raw logs, traces, snapshots and screenshots are local under ignored `shots/session50/`.

## Larger maps and four players

One current-policy player faces three independent checkpoint-policy players, rotating through all four seats
on each generated map. They are opponents, not a team. UID and gameplay RNG reset for each rotation.
Games continue after the first elimination until one player remains or 84 days have been played.

| Map size | Map IDs | Games | Current wins | Current eliminated | Current alive, unresolved | All games reaching limit | Score delta, 2 SE | Instant battles |
|---|---|---:|---:|---:|---:|---:|---|---:|
| 48 | 600–607 | 32 | 11 | 20 | 1 | 13 | +15.50 ± 24.86 | 2818 |
| 64 | 700–707 | 32 | 11 | 19 | 2 | 5 | +14.36 ± 17.05 | 3362 |

Both score intervals include zero. These small samples do **not** establish a general strength gain on four-player
maps. The current policy wins 22/64 games against three opponents, but rotations of one map are correlated:
do not treat the 64 games as independent samples or compare this win fraction directly with two-player results.
Loss means the candidate was eliminated; the remaining opponents can still be fighting at the cutoff.

For N players, a map's score statistic sums
`(candidate score - mean(other scores)) / max(1, total score) * 100/N` across its N seat rotations.
Two standard errors are calculated across maps. The two-player formula is unchanged; the four-player scale
is different and should not be compared numerically with the session49 two-player delta.
The strategic score itself remains army value + 5000/town + half gold + 100/hero level + five days' mine income.

Same-policy four-seat control on maps 600–601, size 48, 84 days: **0.00 ± 0.00** (868 battles).
The normal suite also checks the original two-player control and a shorter four-player control.
No campaign script errors occurred. Some runs print the pre-existing resource/ObjectDB cleanup warnings on exit.
The two-player convention is retained: day 85 means 84 days played, followed by next-day reset/income.

Reproduce (replace `Godot` with the Godot 4.7.2 console executable):

```text
Godot --headless --path . res://tools/adventure_tournament.tscn -- --pairs=8 --start=600 --size=48 --players=4 --days=84 --baseline=res://tools/ai/adventure_ai_checkpoint.gd
Godot --headless --path . res://tools/adventure_tournament.tscn -- --pairs=8 --start=700 --size=64 --players=4 --days=84 --baseline=res://tools/ai/adventure_ai_checkpoint.gd
Godot --headless --path . res://tools/adventure_tournament.tscn -- --self --pairs=2 --start=600 --size=48 --players=4 --days=84 --baseline=res://tools/ai/adventure_ai_checkpoint.gd
```

Logs: `large48.log`, `large64.log`, `control4.log`. The long runs preceded the added `games_at_limit` summary;
their limit counts above come from the per-game `day=85` lines and alive flags.

## The 17 unfinished session49 games

All 17 reproduced at 84 days with traces. Extending the same 14 map pairs (28 games, including the other seats)
to 168 days resolved eight of the previously unfinished games: four current wins and four losses.
Nine remain unfinished. This is diagnosis of selected cases, not a fresh strength sample.

| Map / current seat | Outcome by day 168 | Observation in remaining final snapshot |
|---|---|---|
| 404/0 | Unresolved | Main army holds its town against a comparable raider; other armies still target towns. |
| 408/1 | Win, day 135 | — |
| 409/1 | Unresolved | Three separate armies each fall below the enemy town assault threshold; two hold gates. |
| 412/0 | Loss, day 132 | — |
| 412/1 | Unresolved | Both sides still move between towns; not a total movement halt. |
| 415/1 | Unresolved | Armies remain divided; two hold gates, none individually qualifies for the remaining assault. |
| 420/0 | Loss, day 88 | — |
| 425/0 | Unresolved | Two comparable large armies still target towns rather than each other. |
| 427/0 | Unresolved | Allies obstruct the leader's route; removing them in a diagnostic copy restores the path. The leader also lacks the required assault margin. |
| 434/0 | Win, day 160 | — |
| 439/0 | Loss, day 100 | — |
| 439/1 | Win, day 125 | — |
| 441/0 | Unresolved | Current armies seek smaller objectives; the much stronger checkpoint defender holds its town. |
| 441/1 | Unresolved | Large forces remain divided between holding, visiting and a planned delivery. |
| 444/0 | Unresolved | Both sides hold defended towns; each individual attacking force is below threshold. |
| 445/0 | Win, day 144 | — |
| 446/0 | Loss, day 99 | — |

These observations identify limits of defense, consolidation and route coordination. They do not prove that
loosening any one safety threshold would improve play. In particular, a path blocked by allies in 427/0 is
not its only obstacle: the leader's force ratio is about 0.83 where attacking a town requires more than 1.40.
No new gameplay rules or AI heuristics were introduced during this validation.

```text
Godot --headless --path . res://tools/adventure_tournament.tscn -- --maps=404,408,409,412,415,420,425,427,434,439,441,444,445,446 --days=84 --baseline=res://tools/ai/adventure_ai_checkpoint.gd --trace=shots/session50/unresolved.jsonl --dump=shots/session50/states
python tools/campaign_trace_report.py shots/session50/unresolved.jsonl --after=70
Godot --headless --path . res://tools/adventure_tournament.tscn -- --maps=404,408,409,412,415,420,425,427,434,439,441,444,445,446 --days=168 --baseline=res://tools/ai/adventure_ai_checkpoint.gd --dump=shots/session50/states168
Godot --headless --path . res://tools/campaign_snapshot_report.tscn -- --dir=shots/session50/states168
```

Create `shots/session50` before opening a trace log. `--dump` creates its directory. Snapshots are plain
world dictionaries for diagnostics, not player save files. The report loads them without changing the files.
JSONL turn records occur after each owner's turn, so their last town lists are not a simultaneous snapshot:
a later opponent can capture an earlier owner's town that same day. Use binary snapshots for final ownership.
Logs: `unresolved.log`, `unresolved-report.txt`, `extended168.log`, `snapshot-report.txt`.

## Tactical battle, return and save/load

`tools/campaign_flow_test.tscn`: **29 checks pass**, both windowed and headless. It runs the real scenes and
tactical rules, with no instant resolver and no fabricated battle results:

- Human attack command -> battle -> Defend and Auto controls -> victory -> result dismissal -> human level-up.
- Exact casualties, XP and Expert Necromancy applied once; save/reload does not duplicate the reward; movement
  works after returning and reloading.
- End Turn -> AI chooses/initiates battle -> human defender retreats -> result dismissal -> interrupted AI turn
  resumes, town management is not repeated, next human day starts, and the retreat record survives save/load.
- Each save uses `user://campaign_flow_<pid>.dat`, then deletes only that file. The default player save's hash
  is checked before/after and stays unchanged. Complete world and UID serialization is compared.

This is a controlled scripted smoke test. Buttons are exercised through their pressed signals, most of the
winning battle uses Auto, and save/load uses the production API with an isolated filename. It does not establish
competitive human balance, test the default menu save slot, or cover every siege, spell and defeat branch.

```text
Godot --path . res://tools/campaign_flow_test.tscn -- --capture
git checkout -- project.godot
```

The seven screenshots in `shots/session50/flow/` were viewed: `attacking`, `victory`, `level_up`,
`reloaded_victory`, `defending`, `retreat_result`, `reloaded_retreat`. No visual/art changes or new judge score.
Windowed success log: `flow2.log`; earlier `flow.log` records an initial fixture timeout (retreat left no safe
human army) and an overly timing-sensitive assertion, both corrected in the test. No production fix was needed.

Full `tools/run_tests.sh` passed (`tests.log`): compile; 40 battles; 25 battle visual; 15 battle AI; 54 adventure AI;
63 week; 29 flow; two/four-player zero-difference controls; 4096 glow phases; 33 camera; 227 war machine;
46 Necromancy; 31 clicks plus drag/queued click; five visits; 306 artifacts; `SIM DONE`.

Next AI work should start from the recorded gate-holding/army-consolidation cases and allied-route obstruction,
with focused safety tests and new validation maps. Human tactical balance, fog information policy and map spells
remain separate open work. Freeze the current `f69ad3a` policy as a new comparator before tuning it further.
