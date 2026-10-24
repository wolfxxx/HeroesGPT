class_name Dice
## The game's dice. The rules roll on the world's own generator, whose state is kept in the world (`world["rng"]`)
## and so saved with it: a reloaded game rolls as it would have, and the same commands replayed on the same starting
## world give the same world (tools/replay_test.gd). Only rules carried out inside a command may roll on it, since a
## replay applies commands only. Choices made outside a command (a computer player's pick, a quick battle's luck, a
## played battle's seed) take a generator of their own seeded from the world's state (`derived`), which leaves the
## world's stream untouched. Presentation (animation timing, particles, sound pitch) has private generators.

## Starts a world's generator (map generation; a save without one starts it from the map's seed on first roll).
static func start(w: Dictionary, seed_v: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(["world dice", seed_v])
	w["rng"] = r.state

## The world's generator at its current state, for a rule that rolls several times; hand it back with `keep`.
static func gen(w: Dictionary) -> RandomNumberGenerator:
	if not w.has("rng"):
		start(w, int(w.get("seed", 0)))
	var r := RandomNumberGenerator.new()
	r.state = int(w["rng"])
	return r

static func keep(w: Dictionary, r: RandomNumberGenerator) -> void:
	w["rng"] = r.state

## An integer from a to b, both included.
static func roll(w: Dictionary, a: int, b: int) -> int:
	var r := gen(w)
	var v := r.randi_range(a, b)
	keep(w, r)
	return v

## A number from 0 up to (not including) 1.
static func chance(w: Dictionary) -> float:
	var r := gen(w)
	var v := r.randf()
	keep(w, r)
	return v

static func index(w: Dictionary, n: int) -> int:
	return roll(w, 0, n - 1)

static func pick(w: Dictionary, items: Array):
	return items[index(w, items.size())]

## A generator of its own for a choice made outside a command: seeded from the world's state and `key` (what is
## being chosen, and for whom), it rolls the same for the same world and never moves the world's stream.
static func derived(w: Dictionary, key) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(w.get("rng", w.get("seed", 0))), key])
	return r

## Presentation's own generator (animation timing, particles, map flourishes): never the world's dice nor the global
## stream, so how long a battle animates cannot change a later roll.
static var _look := RandomNumberGenerator.new()

static func look() -> RandomNumberGenerator:
	return _look
