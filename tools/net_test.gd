extends Node
## Online test (Net): this process hosts a three-player map (Red and Teal computer players moved here, Blue a person)
## and starts a second Godot process that joins it as Blue. Blue's machine walks its hero and ends its turns; the
## host moves the computer players. Every command crosses the network; on day 2 Blue's world is spoiled on purpose
## and the turn's digest must catch it and the host's world put it right. At the end both worlds must match.
##   Godot --headless --path . res://tools/net_test.tscn      (the host; it starts the joining process itself)

const PORT := 24791
const DAYS := 4
const Driver := preload("res://tools/ai/campaign_driver.gd")

var checks := 0
var failures := 0
var _client_pid := -1
var _report := {}
var _log := []

func _ready() -> void:
	if "--net-role=client" in OS.get_cmdline_user_args():
		_client()
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
	Net.leave()
	get_tree().quit(code)

# ---------------------------------------------------------------------------------------------
# The host
# ---------------------------------------------------------------------------------------------
func _host() -> void:
	get_tree().create_timer(300.0).timeout.connect(func():
		print("FAIL the online test ran out of time")
		print("NET TEST: %d checks, failures: %d" % [checks, failures + 1])
		_quit(1))
	_ok(Net.host(PORT) == "", "the game is hosted")
	GameState._uid = 1000
	var w := WorldGen.generate({"seed": 52001, "map_size": 36, "opponents": 2, "faction": "haven",
		"seat_human": [true, true, false]})
	w["players"][0]["is_ai"] = true  # (Red moves itself here; Blue is the person who joins)
	for hid in w["players"][1]["heroes"]:  # (Blue strong enough to walk for the whole test)
		w["heroes"][hid]["army"][0] = {"id": GameData.FACTIONS[w["players"][1]["faction"]]["creatures"][6], "count": 40}
	var driver = Driver.new()
	add_child(driver)
	driver.configure(w)
	Net.rules = driver.rules
	Net.world_ready()
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tools/net_test.tscn", "--", "--net-role=client"]
	_client_pid = OS.create_process(OS.get_executable_path(), args)
	_ok(_client_pid > 0, "the joining game is started")
	while Net.peers.is_empty():
		await get_tree().process_frame
	_ok(Net.peers.values() == [1], "it joins as Blue")
	var blue: Dictionary = w["players"][1]
	var blue_hero: Dictionary = w["heroes"][blue["heroes"][0]]
	var start: Vector2i = blue_hero["pos"]
	var ais := [AdvAI.new(driver.rules), null, AdvAI.new(driver.rules)]
	var turns := 0
	while w["day"] <= DAYS and turns < 60:
		var cur: int = w["current_player"]
		if cur == 1:
			await Net.remote_command  # (Blue's commands arrive; its turn ends with end_turn)
			continue
		driver.ai = ais[cur]
		await driver.ai.run_turn(driver, w["players"][cur])
		_ok(driver.rules.do({"t": "end_turn", "p": cur})["ok"], "the computer's turn ends")
		turns += 1
		await get_tree().process_frame  # (as the map screen: the network is read between turns)
	_ok(Net.received > 5, "Blue's commands reached the host (%d)" % Net.received)
	_ok(w["heroes"].has(blue_hero["uid"]) and blue_hero["pos"] != start, "Blue's hero walked on the host's map")
	_ok(Net.sent > 20, "the computer players' commands went out (%d)" % Net.sent)
	for i in 60:  # (the last commands and any world sent to put Blue right arrive first)
		await get_tree().process_frame
	_finish.rpc_id(Net.peers.keys()[0])
	var t0 := Time.get_ticks_msec()
	while _report.is_empty() and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	_ok(not _report.is_empty(), "Blue reports back")
	_ok(_report.get("digest", 0) == Net.digest(w), "Blue's world matches the host's at the end")
	_ok(int(_report.get("resyncs", 0)) >= 1, "the spoiled world was caught and put right (%d)" % int(_report.get("resyncs", 0)))
	_ok(int(_report.get("received", 0)) > 20, "Blue applied the host's commands (%d)" % int(_report.get("received", 0)))
	for l in _report.get("log", []):
		print("  blue: ", l)
	print("NET TEST: %d checks, failures: %d" % [checks, failures])
	_quit(1 if failures > 0 else 0)

@rpc("any_peer", "call_remote", "reliable")
func _done(report: Dictionary) -> void:
	_report = report

# ---------------------------------------------------------------------------------------------
# The joining machine (Blue)
# ---------------------------------------------------------------------------------------------
var _finished := false
var _home := {}
var _steps := 0

func _client() -> void:
	Net.join("127.0.0.1", PORT)
	await Net.world_received
	_log.append("joined as player %d on day %d" % [Net.seat, GameState.world["day"]])
	var spoiled := false
	while not _finished:
		var w := GameState.world
		if w["current_player"] != Net.seat or Net.syncing:
			await get_tree().process_frame
			continue
		if w["day"] == 2 and not spoiled:  # (a world gone astray: the next turn's digest must catch it)
			spoiled = true
			w["players"][Net.seat]["resources"]["gold"] += 1
			_log.append("spoiled on day 2")
		var rules := AdvRules.new(w)
		Net.rules = rules
		var me: Dictionary = w["players"][Net.seat]
		for hid in me["heroes"]:
			var h: Dictionary = w["heroes"][hid]
			if not _home.has(hid):
				_home[hid] = h["pos"]
			for k in 6:  # (away from where it started: the walk must show on the host's map)
				var best := Vector2i(-99, -99)
				for d in AdvRules.DIRS:
					var q: Vector2i = h["pos"] + d
					if rules.inside(q) and rules.walkable_ground(q) and rules.at(q).is_empty() and (best.x < -90
							or (q - _home[hid]).length_squared() > (best - _home[hid]).length_squared()):
						best = q
				if best.x < -90 or not rules.do({"t": "step", "p": Net.seat, "hero": hid, "to": [best.x, best.y]})["ok"]:
					break
				_steps += 1
		rules.do({"t": "end_turn", "p": Net.seat})
		_log.append("turn ended on day %d (heroes %d, alive %s)" % [w["day"], me["heroes"].size(), me["alive"]])
		while GameState.world["current_player"] != Net.seat and not _finished:
			await get_tree().process_frame

@rpc("any_peer", "call_remote", "reliable")
func _finish() -> void:
	_finished = true
	_log.append("%d steps taken; day %d; syncing %s; notes %s" % [_steps, GameState.world["day"], Net.syncing, Net.notes])
	_done.rpc_id(1, {"digest": Net.digest(GameState.world), "resyncs": Net.resyncs, "received": Net.received, "log": _log})
	await get_tree().create_timer(1.0).timeout
	Net.leave()
	get_tree().quit()
