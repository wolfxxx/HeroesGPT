#!/bin/sh
# Full test pass for a round (about 4 minutes). Expected results:
#   CHECK DONE, failures: 0
#   BATTLE TEST: 40 battles ended of 40, failures: 0
#   BATTLE VISUAL TEST: N checks, failures: 0
#   BATTLE AI TEST: N checks, failures: 0
#   ADVENTURE AI TEST: N checks, failures: 0
#   CAMPAIGN WEEK TEST: N checks, failures: 0
#   ADVENTURE TOURNAMENT: self=true, score delta 0.00 +/- 0.00
#   ARTIFACT GLOW TEST: 4096 phase draws completed (no renderer errors)
#   ADVENTURE CAMERA TEST: N checks, failures: 0
#   WAR MACHINE TEST: N checks, failures: 0
#   NECROMANCY TEST: N checks, failures: 0
#   CLICK TEST: N clicks, 0 without a path    + DRAG TEST ... plan unchanged: true   + PENDING TEST ... shown: true
#   5                                           (visit test: five VISIT lines)
#   ARTIFACT TEST: N checks, failures: 0
#   SIM DONE                                    (no SCRIPT ERROR lines)
# "N resources still in use at exit" warnings are old and harmless.
#   sh tools/run_tests.sh
cd "$(dirname "$0")/.."
G=${GODOT:-/c/Users/PC/Documents/Godot/Godot_v4.7.2-stable_win64_console.exe}
# Restore windowed Godot's editor settings even when the test pass is interrupted.
trap 'git checkout -- project.godot' EXIT
$G --headless --path . --import >/dev/null 2>&1
sh tools/check.sh 2>&1 | grep -E "CHECK DONE|SCRIPT ERROR|Parse Error|ERROR" | head -8
echo "--battle"; timeout 300 $G --headless --path . res://tools/battle_test.tscn 2>&1 | grep -E "BATTLE TEST|SCRIPT ERROR" | tail -4
echo "--battle-visual"; timeout 60 $G --headless --path . res://tools/battle_visual_test.tscn 2>&1 | grep -E "BATTLE VISUAL TEST|SCRIPT ERROR|FAIL" | tail -6
echo "--battle-ai"; timeout 60 $G --headless --path . res://tools/battle_ai_test.tscn 2>&1 | grep -E "BATTLE AI TEST|SCRIPT ERROR|FAIL" | tail -8
echo "--adventure-ai"; timeout 60 $G --headless --path . res://tools/adventure_ai_test.tscn 2>&1 | grep -E "ADVENTURE AI TEST|SCRIPT ERROR|FAIL" | tail -8
echo "--campaign-week"; timeout 60 $G --headless --path . res://tools/campaign_week_test.tscn 2>&1 | grep -E "CAMPAIGN WEEK TEST|SCRIPT ERROR|FAIL" | tail -8
echo "--campaign-control"; timeout 60 $G --headless --path . res://tools/adventure_tournament.tscn -- --self --pairs=2 2>&1 | grep -E "ADVENTURE TOURNAMENT|SCRIPT ERROR|FAIL" | tail -8
echo "--artifact-glow"; timeout 60 $G --path . res://tools/artifact_glow_test.tscn 2>&1 | grep -E "ARTIFACT GLOW TEST|SCRIPT ERROR|Invalid polygon|FAIL" | tail -8
echo "--adventure-camera"; timeout 60 $G --headless --path . res://tools/adventure_camera_test.tscn 2>&1 | grep -E "ADVENTURE CAMERA TEST|SCRIPT ERROR|FAIL" | tail -8
echo "--war-machines"; timeout 120 $G --headless --path . res://tools/war_machine_test.tscn 2>&1 | grep -E "WAR MACHINE TEST|SCRIPT ERROR|FAIL" | tail -8
echo "--necromancy"; timeout 60 $G --headless --path . res://tools/necromancy_test.tscn 2>&1 | grep -E "NECROMANCY TEST|SCRIPT ERROR|FAIL" | tail -8
echo "--click"; timeout 300 $G --path . res://tools/click_test.tscn 2>&1 | grep -E "clicks|DRAG|PENDING|SCRIPT ERROR|FAIL" | tail -5
echo "--visit"; timeout 300 $G --headless --path . res://tools/visit_test.tscn 2>&1 | grep -cE "VISIT"
echo "--artifacts"; timeout 300 $G --headless --path . res://tools/artifact_test.tscn 2>&1 | grep -E "ARTIFACT TEST|FAIL|SCRIPT ERROR" | tail -6
echo "--sim"; timeout 300 $G --headless --path . res://tools/sim_test.tscn 2>&1 | grep -E "SCRIPT ERROR|FAIL|DONE|done" | tail -3
# (Godot rewrites project.godot when run with a window: always restore it)
git checkout -- project.godot
