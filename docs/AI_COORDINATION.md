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
