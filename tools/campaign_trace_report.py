"""Summarize tournament JSONL without rerunning or changing the campaign.

python tools/campaign_trace_report.py shots/run.jsonl --after=42
No recorded action can mean deliberate defense or no viable target, not necessarily a bug.
Army deltas on moves exclude town reinforcement performed later by run_turn; end-turn armies include it.
"""
import argparse
import collections
import json


def report(path, after):
    runs = collections.defaultdict(list)
    with open(path, encoding="utf-8") as source:
        for line in source:
            event = json.loads(line)
            runs[event["run"]].append(event)
    for run, events in runs.items():
        moves = [e for e in events if e["event"] == "move" and e["day"] > after]
        turns = [e for e in events if e["event"] == "turn" and e["day"] > after]
        if not turns:
            continue
        acted = {(e["day"], e["hero"]) for e in moves}
        no_action = collections.Counter()
        last = {}
        for turn in turns:
            last[turn["owner"]] = turn
            for hero in turn["heroes"]:
                if (turn["day"], hero["uid"]) not in acted:
                    no_action[hero["uid"]] += 1
        targets = collections.Counter(e["target"] for e in moves)
        unchanged = sum(e["from"] == e["to"] and e["cost"] == 0
                        and e["army_change"] == 0 and e.get("xp_change", 0) == 0 for e in moves)
        print(f"Run {run}, after day {after}: {len(moves)} actions; {unchanged} unchanged moves")
        print("  Targets:", dict(targets))
        for owner, turn in last.items():
            towns = turn["towns"]
            print(f"  Player {owner}, day {turn['day']}: {len(towns)} towns, "
                  f"{turn['resources']['gold']} gold, "
                  f"{sum(t['garrison'] for t in towns)} garrison value")
            for hero in turn["heroes"]:
                at_town = any(t["pos"] == hero["pos"] for t in towns)
                history = [e for e in moves if e["hero"] == hero["uid"]]
                destination = history[-1]["target"] if history else "none"
                print(f"    Hero {hero['uid']}: strength {hero['strength']:.0f}, "
                      f"at own town={at_town}, {no_action[hero['uid']]} turns without action, "
                      f"last target={destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace")
    parser.add_argument("--after", type=int, default=42)
    args = parser.parse_args()
    report(args.trace, args.after)
