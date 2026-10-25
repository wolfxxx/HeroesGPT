extends Node
## Online battle test: one battle fought on two machines at once (Net.battle_send / battle_next, battle.gd `_carry`).
## This process hosts and fights the attacker; it starts a second Godot process that joins and fights the defender.
## Both open the real battle screen on the same setup (seed included), each side in auto combat, so each machine's
## computer chooses its own side's actions and sends them to the other. Both must end with the same result.
##   Godot --headless --path . res://tools/net_battle_test.tscn

const PORT := 24792

static var _started := false

func _ready() -> void:
	if _started:  # (the battle's end returns to this scene: the driver on the root carries on)
		return
	_started = true
	Net.online_path = "user://net_battle_test_online.dat"  # (not the player's own online files)
	Net.join_path = "user://net_battle_test_join.dat"
	var d := Driver.new()
	d.client = "--net-role=client" in OS.get_cmdline_user_args()
	get_tree().root.add_child.call_deferred(d)

class Driver extends Node:
	var client := false
	var checks := 0
	var failures := 0
	var mine := {}
	var theirs := {}
	var pid := -1

	func _ok(cond: bool, what: String) -> void:
		checks += 1
		if not cond:
			failures += 1
			print("FAIL ", what)

	func _ready() -> void:
		get_tree().create_timer(240.0).timeout.connect(func():
			print("FAIL the online battle test ran out of time")
			_finish(1))
		GameState.battle_finished.connect(func(r): mine = r.duplicate(true))
		if client:
			Net.join("127.0.0.1", PORT)
			await multiplayer.connected_to_server
			Net.seat = 1
		else:
			_ok(Net.host(PORT) == "", "the game is hosted")
			pid = OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"res://tools/net_battle_test.tscn", "--", "--net-role=client"])
			while multiplayer.get_peers().is_empty():
				await get_tree().process_frame
			Net.peers[multiplayer.get_peers()[0]] = 1  # (the joined machine plays the defender)
		var s := _setup()
		s["remote_sides"] = [client, not client]  # (each machine fights its own side; the other's actions arrive)
		GameState.return_scene = "res://tools/net_battle_test.tscn"
		GameState.start_battle(s)
		while mine.is_empty():
			_press_dialogs()
			await get_tree().process_frame
		if client:
			mine["_sent"] = Net.battle_sent
			mine["_got"] = Net.battle_got
			_report.rpc_id(1, var_to_bytes(mine))
			await get_tree().create_timer(1.0).timeout
			_finish(0)
			return
		var t0 := Time.get_ticks_msec()
		while theirs.is_empty() and Time.get_ticks_msec() - t0 < 30000:
			await get_tree().process_frame
		_ok(not theirs.is_empty(), "the defender's machine reports its result")
		for k in ["winner", "attacker_army", "defender_army", "xp", "spell_points", "machines", "raised"]:
			_ok(str(mine.get(k)) == str(theirs.get(k)), "both machines agree on %s (%s / %s)" % [k, str(mine.get(k)).left(80), str(theirs.get(k)).left(80)])
		_ok(mine.has("spell_points") and mine.has("machines"), "the result carries the heroes' spell points and war machines")
		_ok(Net.battle_sent > 3 and Net.battle_got > 3, "the attacker's actions went out and the defender's came in (%d / %d)" % [Net.battle_sent, Net.battle_got])
		_ok(int(theirs.get("_sent", 0)) == Net.battle_got and int(theirs.get("_got", 0)) == Net.battle_sent,
			"every action crossed (%s sent, %s received by the defender)" % [theirs.get("_sent"), theirs.get("_got")])
		print("  winner %s, spell points %s, attacker left %s" % [mine.get("winner"), mine.get("spell_points"), mine.get("attacker_army")])
		print("NET BATTLE TEST: %d checks, failures: %d" % [checks, failures])
		_finish(1 if failures > 0 else 0)

	@rpc("any_peer", "call_remote", "reliable")
	func _report(b: PackedByteArray) -> void:
		theirs = bytes_to_var(b)

	func _finish(code: int) -> void:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
		Net.leave()
		get_tree().quit(code)

	## The result window (and any other dialog) answered with its default, as a click on OK.
	func _press_dialogs() -> void:
		var layer := get_tree().root.get_node_or_null("ModalLayer")
		if layer == null:
			return
		for c in layer.get_children():
			if c is Modal and not c.is_queued_for_deletion() and c.has_meta("default"):
				c.close(c.get_meta("default"))

	## Two heroes with armies, spells and war machines, in auto combat on both sides; the same on both machines.
	func _setup() -> Dictionary:
		GameState._uid = 1000
		var a := GameState.make_hero("sir_aldric", 0)
		var d := GameState.make_hero("lord_morthis", 1)
		a["army"] = [{"id": "pikeman", "count": 30}, {"id": "archer", "count": 14}, {"id": "griffin", "count": 6},
			{"id": "swordsman", "count": 5}, null, null, null]
		d["army"] = [{"id": "skeleton", "count": 34}, {"id": "zombie", "count": 16}, {"id": "ghost", "count": 6},
			{"id": "vampire", "count": 3}, null, null, null]
		for h in [a, d]:
			h["spells"] = ["magic_arrow", "bless", "slow"]
			h["mana"] = 20
			h["machines"] = ["ballista", "first_aid_tent"]
		return {"attacker_army": a["army"], "defender_army": d["army"], "attacker_hero": a, "defender_hero": d,
			"terrain": "grass", "attacker_player": 0, "defender_player": 1, "attacker_ai": false, "defender_ai": false,
			"seed": 4242, "context": {"type": "test"}, "auto": true}
