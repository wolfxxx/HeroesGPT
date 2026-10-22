# AI coordination — session51, 2026-10-22

Implemented after validation checkpoint `eb2c96c`; comparison policy is the unchanged `f69ad3a` AI.
Included in the user-requested coordination checkpoint and push to `origin/main`, together with `eb2c96c`.
No new game rules, costs, combat thresholds, save fields or art.

## Behavior

- `_assault_rally` considers nearby donors together. If sequential transfers into a copy of the leader's army
  cross the existing safety threshold for a nearby enemy town, donors that can arrive today move before the
  leader. This deliberate assault delivery may take a full day's normal travel; ordinary courier trips still
  use the half-day limit. Required defenders are excluded, slots are respected, and each donor keeps one creature.
- `_plan_with_passage` can ask a blocking ally to step off the leader's route. A relaxed AStar route is only a
  preview: the grid is restored before executing anything. The ally makes one legal, paid step onto an empty,
  unguarded tile; the leader then replans against actual occupancy. Town gates, heroes assigned to defense,
  occupied sites and insufficient movement prevent the request. Idle heroes keep their unspent movement so
  they can help a later army during the same turn. No teleporting or movement refund.
- Visiting an occupied shop can resolve as a friendly meeting. The AI now skips that target when no useful
  troop exchange can occur, instead of repeatedly attempting an empty exchange and losing the rest of its turn.
  Useful incidental exchanges still work. Intended courier meetings retain their normal eligibility rules.

`tools/adventure_ai_test.tscn`: **75 checks pass** (previously 54), including real controller execution of two
deliveries followed by conquest, an earlier idle hero stepping aside for a later leader, exact movement payment,
defender protection, insufficient movement, absent/guarded alcoves and useless versus useful occupied-site meetings.

## Recorded stalemates

`tools/campaign_resume_test.tscn` reads the nine unresolved day-169 worlds from session50 and runs two variants
from each copied snapshot: candidate seat uses `f69ad3a` then current policy; the original opposing `4f126ec`
policy stays fixed. Both variants receive the same explicit RNG seed and reconstructed UID counter. These old
snapshots lack RNG state, so this is a controlled diagnostic restart, not exact continuation of the original stream.

In **441/1**, the new rally combines two couriers with the main army and wins on **day 169**. The previous policy
still has both players alive after the 28-day diagnostic window (day 197). Case **415/1** finishes on day 187 with
both policies, so that is not a new gain. The other seven cases remain unresolved in both variants.
Outcomes are not uniformly better: **427/0** ends this window with no towns under the candidate versus one town
under the previous policy, though its hero survives. Clearing routes does not solve the broader conquest/defense
tradeoff. **441/0** concentrates more troops in its largest army but still does not win. Do not call army growth
or movement alone a solved campaign.

Logs: ignored `shots/session51/resume-final.log` (18 games), `rally-trace.log`, `rally.jsonl` (focused 441/1 trace).
`armies-before.log` and `armies-after.log` describe the saved armies; the latter predates the narrower occupied-site
check, but its rally and passage previews still describe those unchanged helpers. Regenerate with the snapshot tool.

```text
Godot --headless --path . res://tools/campaign_resume_test.tscn -- --days=28
Godot --headless --path . res://tools/campaign_resume_test.tscn -- --case=441_1.dat --trace=shots/session51/rally.jsonl
Godot --headless --path . res://tools/campaign_snapshot_report.tscn -- --dir=shots/session50/states168
```

## Fresh-map validation

`tools/ai/adventure_ai_session49.gd` freezes `f69ad3a`, verified byte-for-byte after subclass, constructor and
constant-name adaptation. Older frozen policies remain unchanged. Final production logic was fixed before
the following separate validation sets; no tuning followed these results.

| Configuration | Map IDs | Games | Wins / losses / candidate unresolved | Score delta, 2 SE | Instant battles |
|---|---|---:|---|---|---:|
| 36, two players, 84 days | 1100–1123 | 48 | 21 / 23 / 4 | -3.12 ± 8.68 | 1126 |
| 48, four players, 84 days | 1200–1207 | 32 | 9 / 22 / 1 | +7.78 ± 10.22 | 1875 |

Both intervals include zero. There is **no demonstrated overall strength gain**, nor evidence here sufficient
to rule out a regression. These are targeted coordination fixes with mixed aggregate results. A candidate faces
one or three independent opponents respectively; rotate through all seats, estimate error across maps, and do not
compare raw win fractions or score scales between player counts. See `CAMPAIGN_VALIDATION.md` for definitions.
Four two-player games and one four-player game reached the limit. Logs: `final36.log`, `final48.log`.

```text
Godot --headless --path . res://tools/adventure_tournament.tscn -- --pairs=24 --start=1100 --days=84 --baseline=res://tools/ai/adventure_ai_session49.gd
Godot --headless --path . res://tools/adventure_tournament.tscn -- --pairs=8 --start=1200 --players=4 --size=48 --days=84 --baseline=res://tools/ai/adventure_ai_session49.gd
```

Earlier experiments are retained rather than presented as final evidence: initial rally/passage development on
800–807 scored 0.00 ± 0.00 (8 wins/8 losses); selected older maps at 168 days scored +25.00 ± 32.73 (10/6).
The intermediate version rejected every incidental meeting at an occupied site. On 900–923 it scored
-7.14 ± 9.95 (20/24/4), and on four-player 1000–1007, -3.13 ± 6.26 (7/24/1). Code review narrowed the rejection
to useless exchanges and added a check preserving useful ones. Final results use different maps; differences
between these samples cannot be attributed solely to that adjustment.
Frozen-`f69ad3a` same-policy control on two 42-day map pairs remains exactly 0.00 ± 0.00 (`control.log`).

## Verification and remaining work

Full suite passed (`shots/session51/tests-final.log`): compile; 40 battles; 25 visual; 15 battle AI; 75 adventure AI;
63 campaign-week; 29 actual battle/save-flow; two/four-player zero-difference controls; 4096 glow phases;
33 camera; 227 factory; 46 Necromancy; 31 clicks plus drag/queued click; five visits; 306 artifacts; `SIM DONE`.
No script errors. Some benchmark processes retain the existing resource/ObjectDB cleanup warnings at exit.
Windowed tests restored `project.godot`. No presentation changes or new judge score. Existing saves need no migration.

Remaining issues include long defensive standoffs, full incompatible armies that cannot consolidate, repeated
town exchanges and townless surviving heroes. Rally predictions still use approximate army strength and existing
attack thresholds; actual defense/guard checks may prevent an immediate assault. Human competitive balance and
larger samples remain untested. Before further policy tuning, use these diagnostics for development and reserve
new map IDs for the next validation set.

## Session52: rear guard, and two rejected policies

Baseline: `tools/ai/adventure_ai_session51.gd` freezes `555fedc` (live `adv_ai.gd` was byte-identical to that commit;
every function overridden, `BUILD_ORDER` renamed `SESSION51_BUILD_ORDER`). Same-policy control on maps 900–903:
exactly 0.00 ± 0.00. `tools/campaign_resume_test.tscn` gained `--before=<policy>` (default still `f69ad3a`).

**Recorded case 427/0** (trace `shots/session52/r427.jsonl`): two armies of about 600k strength never fight (each
needs a 1.3–1.4x margin). Meanwhile 70k heroes wander into the enemy army's reach and die (day 174), and every
hero passing a town takes its whole garrison, so 3k–20k heroes trade empty towns. The candidate lost its last town
on day 196 to a 3k hero after its 640k army left it empty.

| Change | Dev 2p, 24 maps (1500–1523) | Dev 4p, 8 maps (1600–1607) | Kept |
|---|---|---|---|
| Danger filter (no errand ending where a stronger enemy can strike next turn; own towns as refuges) + rear guard | -27.28 ± 24.84 (17/30/1) | -6.56 ± 15.48 (6/25/1) | no |
| Danger filter only | -23.56 ± 24.22 (18/29/1) | — | no |
| Rear guard only | -4.83 ± 9.82 (21/23/4) | -4.17 ± 8.33 (7/25/0) | **yes** |
| Rear guard + only the leader collects garrisons | -22.11 ± 16.77 (15/26/7) | -7.12 ± 13.38 (5/25/2) | no |

The danger filter first made one main army stand still for 28 days (441/0); a relative version and a town-capture
exemption reduced but did not remove the loss on two-player maps, where early empty-town captures decide games.
Leader-only garrison collection left secondary heroes too weak to contest towns. Both were removed.

**Kept: `AdvAI._leave_rear_guard`.** A hero leaving its own town that an enemy army can reach next turn leaves enough
troops (cheapest units first) to hold the gate against that army, if that costs at most 25% of its strength.
Replays of the nine session50 cases (28 days, `shots/session52/resume3.log`): 427/0 ends with one town instead of
none, 425/0 with three instead of two, the other seven identical. Two focused checks plus two edge checks in
`tools/adventure_ai_test.tscn` (79 total).

**Final validation, reserved maps, 84 days, no tuning afterwards:**
24 two-player size-36 maps (1300–1323, 48 games): **23 wins / 25 losses / 0 unresolved, -4.17 ± 14.64 (2 SE)**,
1028 battles. Eight four-player size-48 maps (1400–1407, 32 games): **7 / 24 / 1, -2.42 ± 4.83**, 1733 battles.
Both intervals include zero: no demonstrated strength change either way. The rear guard is a fix for a confirmed
failure (empty towns taken by trivial raiders), not evidence of a stronger AI.

Benchmark note: two-player size-36 games are short (median about 16–18 days with the old generator too) and turn on
day-1 to day-5 captures of empty towns, so policies that trade tempo for safety lose there. Results on larger maps
with more players are a better guide to long-game behaviour; neither showed a gain this round.
Logs: ignored `shots/session52/{control51,dev1,dev2,final36,final48,resume1,resume2,resume3}.log`.

### Seven-day townless rule and unfinished games (session52)

Same eight four-player size-48 maps (1700–1707, 32 games, 84 days, current vs `555fedc`), rule off then on:
off: 27 finished / 5 at the limit (score -1.45 ± 6.66); on (`--townless=7`): 28 / 4 (-3.81 ± 10.08); median end day
37 both times. Every game still unfinished at the limit has two survivors who both hold towns (4/2, 5/1, 6/0+heroes
split), so the rule rarely applies. The nine saved session50 stalemates (`campaign_resume_test --townless=7`,
28 days) end exactly as without it: towns change hands but nobody stays townless for seven days.
Conclusion: the rule is a faithful option, not a fix for AI stalemates; those are between town-holding armies that
never commit to a decisive assault (see 427/0 above). Logs: `shots/session52/townless{0,7}.log`,
`resume_townless{0,7}.log`.
