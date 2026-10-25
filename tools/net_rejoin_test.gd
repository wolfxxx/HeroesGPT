extends Node
## Getting back into an online game (Net.resume, rejoin, resume_saved): this process hosts a map with three people
## (Red here; Blue and Teal free) and starts a second process that joins it. The joining machine is given the first
## free colour, then, joining again and asking for Teal, Teal (the colour it played, though Blue is free). Red plays
## and ends its turn; then the host goes, as a browser page reloaded: its world is dropped and the game it was hosting
## is resumed from its online save, under the same room code. The joining machine, its connection gone, rejoins
## (Net.rejoin, as the Reconnect dialog does) as Teal again. Then the host's connection goes while its game goes on:
## it opens the room again (the same code), the other comes back as Teal, and both worlds match.
##   Godot --headless --path . res://tools/net_rejoin_test.tscn                       (by address, ENet)
##   ... res://tools/net_rejoin_test.tscn -- --relay=ws://127.0.0.1:8787              (by room code through a relay:
##                                          `npx wrangler dev` in relay/, or the online one; not in the suite)

const PORT := 24793
const SAVE := "user://net_rejoin_test_online.dat"
const JOINED := "user://net_rejoin_test_join.dat"

static var _started := false

var checks := 0
var failures := 0
var _client_pid := -1
var _report := {}

func _ready() -> void:
	if _started:
		return
	_started = true
	Net.online_path = SAVE
	Net.join_path = JOINED
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--relay="):
			Net.relay = a.trim_prefix("--relay=")
	if "--net-role=client" in OS.get_cmdline_user_args():
		var c := Client.new()
		c.name = "NetClient"
		get_tree().root.add_child.call_deferred(c)
	else:
		_host()

func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL ", what)

func _quit(code: int) -> void:
	if _client_pid > 0 and OS.is_process_running(_client_pid):
		OS.kill(_client_pid)
	Net.forget()
	for f in [SAVE, JOINED]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	get_tree().quit(code)

func _wait(cond: Callable, secs := 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < secs * 1000:
		await get_tree().process_frame
	return cond.call()

func _open() -> bool:
	if Net.relay == Net.RELAY and not "--relay=" in " ".join(OS.get_cmdline_user_args()):
		return Net.host(PORT) == ""
	if Net.host_room() != "":
		return false
	return await _wait(func(): return Net.room != "")

# ---------------------------------------------------------------------------------------------
# The host (Red)
# ---------------------------------------------------------------------------------------------
func _host() -> void:
	get_tree().create_timer(240.0).timeout.connect(func():
		print("FAIL the rejoin test ran out of time")
		print("NET REJOIN TEST: %d checks, failures: %d" % [checks, failures + 1])
		_quit(1))
	var relay := "--relay=" in " ".join(OS.get_cmdline_user_args())
	_ok(await _open(), "the game is hosted" + ((" in room " + Net.room) if relay else ""))
	var code := Net.room
	GameState._uid = 1000
	var w := WorldGen.generate({"seed": 52003, "map_size": 36, "opponents": 2, "faction": "haven",
		"seat_human": [true, true, true]})
	GameState.world = w
	var rules := AdvRules.new(w)
	Net.rules = rules
	Net.world_ready()
	_ok(not Net.online_save().is_empty(), "the hosted game is saved as soon as it begins")
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tools/net_rejoin_test.tscn",
		"--", "--net-role=client", "--room=" + code]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--relay="):
			args.append(a)
	_client_pid = OS.create_process(OS.get_executable_path(), args)
	_ok(await _wait(func(): return Net.peers.size() == 1), "a machine joins")
	_ok(Net.peers.values() == [1], "it is given the first free colour, Blue (%s)" % [Net.peers.values()])
	_step.rpc_id(Net.peers.keys()[0], "again as teal")
	_ok(await _wait(func(): return Net.peers.values() == [2]), "joining again, asking for Teal, it plays Teal (%s)" % [Net.peers.values()])
	# Red plays: a few steps and the turn's end (saved at once)
	var hero: Dictionary = w["heroes"][w["players"][0]["heroes"][0]]
	var steps := 0
	for k in 4:
		for d in AdvRules.DIRS:
			var q: Vector2i = hero["pos"] + d
			if rules.inside(q) and rules.walkable_ground(q) and rules.at(q).is_empty():
				if rules.do({"t": "step", "p": 0, "hero": hero["uid"], "to": [q.x, q.y]})["ok"]:
					steps += 1
					break
	_ok(steps > 0, "Red walks (%d steps)" % steps)
	_ok(rules.do({"t": "end_turn", "p": 0})["ok"], "Red's turn ends")
	var played := Net.digest(w)
	await get_tree().create_timer(1.0).timeout
	_ok(Net.online_save().get("world", {}).get("current_player", -1) == 1, "the save has the turn's end in it")
	_ok(Net.online_save().get("online", {}).get("room", "?") == code, "and the room it is played in")
	# the host goes, as a page reloaded: the world it held is gone; it resumes the game from its save
	Net.forget()
	GameState.world = {}
	await get_tree().create_timer(2.0).timeout
	_ok(Net.resume_saved() == "", "the saved online game is hosted again")
	if relay:
		_ok(await _wait(func(): return Net.room != ""), "its room opens")
		_ok(Net.room == code, "under the same code (%s, was %s)" % [Net.room, code])
	_ok(not GameState.world.is_empty() and Net.digest(GameState.world) == played, "the world is the one played")
	_ok(Net.seat == 0, "the host plays Red again")
	Net.rules = AdvRules.new(GameState.world)
	Net.world_ready()
	_ok(await _wait(func(): return Net.peers.size() == 1, 60.0), "the joined machine comes back")
	_ok(Net.peers.values() == [2], "as Teal, the colour it played (%s)" % [Net.peers.values()])
	# the host's connection goes while its game goes on (as the map screen: Reconnect opens the room again)
	Net._drop("the connection went")
	_ok(Net.resume.get("host", false) and Net.my_seat() == 0, "the host has its way back, as Red")
	_ok(Net.rejoin() == "", "it opens its game again")
	if relay:
		_ok(await _wait(func(): return Net.room != ""), "its room opens again")
		_ok(Net.room == code and Net.resume.is_empty(), "under the same code (%s)" % Net.room)
	_ok(await _wait(func(): return Net.peers.size() == 1, 60.0), "the joined machine comes back again")
	_ok(Net.peers.values() == [2], "as Teal (%s)" % [Net.peers.values()])
	_step.rpc_id(Net.peers.keys()[0], "report")
	_ok(await _wait(func(): return not _report.is_empty()), "it reports back")
	_ok(_report.get("digest", 0) == Net.digest(GameState.world), "its world matches the host's")
	_ok(_report.get("seat", -1) == 2 and _report.get("resume_left", true) == false, "it plays Teal, with nothing left to get back to")
	_ok(_report.get("last_join_seat", -1) == 2, "and it remembers the game it joined, as Teal")
	_ok(int(_report.get("tries", 0)) >= 1, "it tried until the host was back (%d tries)" % int(_report.get("tries", 0)))
	print("NET REJOIN TEST: %d checks, failures: %d" % [checks, failures])
	_quit(1 if failures > 0 else 0)

@rpc("any_peer", "call_remote", "reliable")
func _done(report: Dictionary) -> void:
	_report = report

@rpc("authority", "call_remote", "reliable")
func _step(what: String) -> void:
	get_tree().root.get_node("NetClient").step(self, what)

# ---------------------------------------------------------------------------------------------
# The joining machine
# ---------------------------------------------------------------------------------------------
class Client extends Node:
	var _code := ""
	var _tries := 0
	var _busy := false
	var _losses := 0

	func _ready() -> void:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--room="):
				_code = a.trim_prefix("--room=")
		_join(-1)
		Net.lost.connect(_on_lost)

	func _join(want: int) -> void:
		if _code != "":
			Net.join_room(_code, want)
		else:
			Net.join("127.0.0.1", PORT, want)

	func step(scene: Node, what: String) -> void:
		if what == "again as teal":
			Net.forget()
			await get_tree().create_timer(0.5).timeout
			_join(2)
		elif what == "report":
			scene._done.rpc_id(1, {"digest": Net.digest(GameState.world), "seat": Net.seat, "tries": _tries,
				"resume_left": not Net.resume.is_empty(), "last_join_seat": int(Net.last_join().get("seat", -1))})
			await get_tree().create_timer(1.0).timeout
			Net.forget()
			get_tree().quit()

	## The host has gone: join again until it is back, as the Reconnect dialog (each try waits for its answer, then
	## half a second).
	func _on_lost(_why: String) -> void:
		_losses += 1
		if Net.resume.is_empty() or _busy:
			return
		_busy = true
		while not Net.resume.is_empty() and _tries < 200:
			_tries += 1
			var seen := _losses
			Net.rejoin()
			var t0 := Time.get_ticks_msec()
			while Net.resume.size() > 0 and _losses == seen and Time.get_ticks_msec() - t0 < 15000:
				await get_tree().process_frame
			if Net.resume.size() > 0:
				Net.leave()
				await get_tree().create_timer(0.5).timeout
		_busy = false
