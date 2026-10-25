extends Node
## Online play, first version (HANDOFF §8, phase 2). One player hosts the real game; the others join it by address
## (ENet) or by a room code (through the relay: RelayPeer, relay/; the only way from a browser).
## Every command a machine accepts on its world (Commands.run) is passed on: a joining player's to the host, which
## checks it against its own world and passes it to everyone else; the host's own (its player's and the computer
## players') to everyone. Each machine applies them in the same order to its copy of the world, and the rules give
## the same world on each (the dice are the world's: Dice). The host's world is the true one: each turn's end
## carries its digest, and a machine whose world differs, or that had a command refused, is sent the host's world.
## Each machine shows its own player (`seat`, GameState.human_player_index) and its own view (GameState.view); the
## computer players move on the host only.
## A connection that goes during a game can be got back (`resume`, Reconnect): a joining machine joins again as the
## same player (it asks for it: _hello), the host opens its room again under the same code (its key) or its address.
## The host keeps the game it hosts saved as it goes (`online_path`), so that it can be resumed after a restart or a
## reload of the page (resume_saved); the others rejoin it.
## Before the game, the lobby: the machines that join wait on the host's New Game screen, shown to them as it changes
## (lobby_send / lobby_changed); the host gives each a colour open to people (lobby_assign, lobby_take), each picks its
## own town, hero and bonus (lobby_ask / lobby_request), and the host begins (lobby_begin); the colours they held are
## the ones they are seated as (`_greeted`).
## Not yet: the fog hides the others' maps on screen only.

signal remote_command(cmd: Dictionary, res: Dictionary)  ## a command from another machine was applied
signal world_received                                    ## the host's world arrived (joined, or put right)
signal roster_changed                                    ## a player joined or left
signal lost(reason: String)                              ## the connection is gone (or never came)
signal room_opened(code: String)                         ## host through the relay: the code others join with
signal lobby_changed                                     ## joining machine: the host's lobby arrived (`lobby`)
signal lobby_request(id: int, change: Dictionary)        ## host: a machine in the lobby asks for a change
signal lobby_begun                                       ## joining machine: the host has begun the game

const PORT := 24680
const RELAY := "wss://heroes-relay.shatteredcrown.workers.dev"  ## the relay for room codes (relay/, RelayPeer)
const ONLINE_SAVE := "user://online_game.dat"  ## host: the online game, saved as it is played (not the player's slot)
const LAST_JOIN := "user://online_join.dat"    ## joining machine: the game it last joined and the player it played
const SAVE_DELAY := 2000                        ## host: the game is saved at most this often (msec), and at turn ends
## Keys that are not game state, left out of the digest: each player's own view, the computer's notes, a walking
## hero's route and facing on screen, the screen's note to take a treasure once its guard is beaten, and the game's
## end as this machine saw it.
const PRIVATE := ["views", "ai_day", "ai_goal", "yield", "dest", "face_left", "visit_after_guard", "game_over"]

var active := false
var is_host := false
var seat := -1           ## this machine's player (-1: joining, not yet given one)
var peers := {}          ## host: peer id -> the player it plays
var applying := false    ## a command from the network is being applied: it is not passed on again
var syncing := false     ## joining machine: its world differed and the host's is on its way (it makes no moves)
var rules: AdvRules      ## the map screen's rules while it is open (their tile cache stays right); else made anew
var _waiting := []       ## host: peers that joined before the world existed
var sent := 0            ## commands passed on from this machine (a diagnostic)
var received := 0        ## commands from other machines applied here
var resyncs := 0         ## times the host's world was received after the first
var notes: Array = []    ## what went astray, as printed (a diagnostic)
var room := ""           ## the room code, when the game goes through the relay ("" while it opens, or by address)
var room_key := ""       ## host: the room's key, with which the relay gives the same room again
var relay := RELAY       ## (tools/net_test.gd points it at a relay of its own)
var port := PORT         ## the port hosting and joining by address use (the menu's; tests use their own)
var online_path := ONLINE_SAVE  ## (the tests point these two at files of their own)
var join_path := LAST_JOIN
var playing := false     ## a game is under way: the host's map screen has opened, or the host's world has come
## The connection went during a game: how to get back (Reconnect, rejoin). {"host", "room", "key", "address", "seat"}
var resume := {}
var _want := -1          ## joining: the player asked for (the one this machine played before)
var _greeted := {}       ## host: peer -> the player it asked for
var _save_at := 0        ## host: when the game is next saved (msec; 0: nothing new)
## The lobby. Host: colour -> the machine holding it (1: the host). Joining machine: the host's lobby as last sent,
## {"settings": the New Game settings, "seats": colour -> machine, "waiting": machines without a colour}.
var lobby_seats := {}
var lobby := {}

## Opens a game for others to join by this machine's address (ENet). Returns "" or what went wrong.
func host(p := 0) -> String:
	leave()
	var at := p if p > 0 else port
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(at, 7) != OK:
		return "Cannot open port %d: is another game hosting already?" % at
	_hosting(peer)
	return ""

## Opens a game for others to join by a room code, through the relay (RelayPeer): from a browser too, and with no
## port to open. The code comes later (room_opened), or `lost` if the relay cannot be reached.
## With a code and its key: that room again (if someone else has it, the relay gives another code).
func host_room(code := "", key := "") -> String:
	leave()
	var peer := RelayPeer.new()
	if peer.open(relay + "/host" + (("/%s/%s" % [code, key]) if code != "" and key != "" else ""), true) != OK:
		return "Cannot reach the relay."
	peer.room_opened.connect(func(c: String):
		room = c
		room_key = peer.key
		resume = {}
		print("NET room ", c)
		room_opened.emit(c))
	peer.closed.connect(func(why: String): if multiplayer.multiplayer_peer == peer: _drop(why))
	_hosting(peer)
	return ""

func _hosting(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	seat = 0
	_link(multiplayer.peer_connected, _on_peer_connected)
	_link(multiplayer.peer_disconnected, _on_peer_disconnected)

## Joins a game hosted at the address (ENet). The world arrives later (world_received), or `lost` if it cannot.
## `want`: the player to play, if it is free (the one played before the connection went); else the first free one.
func join(address: String, port := PORT, want := -1) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		return "Cannot reach %s." % address
	_joining(peer, want)
	_link(multiplayer.connection_failed, _no_answer)
	_link(multiplayer.server_disconnected, _host_left)
	_address = address
	return ""

## Joins the game with the room code, through the relay.
func join_room(code: String, want := -1) -> String:
	leave()
	var peer := RelayPeer.new()
	if peer.open(relay + "/join/" + code.strip_edges().to_upper().uri_encode(), false) != OK:
		return "Cannot reach the relay."
	peer.closed.connect(func(why: String): if multiplayer.multiplayer_peer == peer: _drop(why))
	_joining(peer, want)
	room = code.strip_edges().to_upper()
	return ""

func _joining(peer: MultiplayerPeer, want: int) -> void:
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	seat = -1
	_want = want
	_link(multiplayer.peer_connected, _on_peer_connected)

var _address := ""

func _no_answer() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		_drop("No game answered at %s." % _address)

func _host_left() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		_drop("The host has left the game.")

## A text is a room code (3 to 8 letters and digits), else an address.
static func is_room_code(text: String) -> bool:
	var t := text.strip_edges().to_upper()
	if t.length() < 3 or t.length() > 8 or t == "LOCALHOST":
		return false
	for c in t:
		if not c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			return false
	return true

func leave() -> void:
	if _save_at > 0:  # (what the host has played since its last save is kept)
		_save_now()
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	is_host = false
	syncing = false
	seat = -1
	room = ""
	room_key = ""
	peers = {}
	_greeted = {}
	lobby_seats = {}
	lobby = {}
	_inbox = []
	_battle_peer = -1
	_fight_peer = -1
	_waiting = []

func _note(text: String) -> void:
	print("NET ", text)
	notes.append(text)

func _drop(reason: String) -> void:
	if playing and resume.is_empty():  # (in a game: the way back, Reconnect)
		resume = {"host": is_host, "room": room, "key": room_key, "address": _address, "seat": seat}
	leave()
	lost.emit(reason)

## Out of online play altogether (the main menu): no game to get back to.
func forget() -> void:
	leave()
	playing = false
	resume = {}

## This machine's player online, also while it gets back into the game after its connection went; else -1.
func my_seat() -> int:
	if active and seat >= 0:
		return seat
	return int(resume.get("seat", -1))

## In an online game, connected or getting back to it.
func online() -> bool:
	return active or not resume.is_empty()

## Back into the game the connection went from (`resume`): the host opens its room again under the same code (or
## its address), a joining machine joins again as the same player. "" or what went wrong; then as host_room (the
## code comes with room_opened) or join_room (the host's world with world_received), or `lost` again.
func rejoin() -> String:
	var r := resume
	if r.is_empty():
		return "There is no game to go back to."
	var err := ""
	if r["host"]:
		err = host_room(r["room"], r["key"]) if r["room"] != "" else host()
		seat = int(r["seat"])
	else:
		err = join_room(r["room"], int(r["seat"])) if r["room"] != "" else join(r["address"], PORT, int(r["seat"]))
	resume = {} if err == "" and r["host"] and r["room"] == "" else r  # (kept until back in: room_opened, _welcome)
	return err

func _link(sig: Signal, f: Callable) -> void:
	if not sig.is_connected(f):
		sig.connect(f)

## Whether this machine moves the player: its own, and on the host the computer players.
func mine(pi: int) -> bool:
	if not active:
		return true
	if pi == seat:
		return true
	var w := GameState.world
	return is_host and not w.is_empty() and pi >= 0 and pi < w["players"].size() and w["players"][pi]["is_ai"]

## Host: someone plays the player (this machine, or one that joined for it).
func joined(pi: int) -> bool:
	return pi == seat or pi in peers.values()

# ---------------------------------------------------------------------------------------------
# The host: seats and the world
# ---------------------------------------------------------------------------------------------
## The host's world now exists (its map screen opened): players who joined before are given their seats.
func world_ready() -> void:
	if not is_host:
		return
	playing = true
	_save_now()
	for id in _waiting.duplicate():
		_waiting.erase(id)
		_seat_peer(id)

## A joining machine reaches the host: it says which player it would play (_hello), and is given its seat then.
func _on_peer_connected(id: int) -> void:
	if not is_host and id == 1:
		_hello.rpc_id(1, _want)

@rpc("any_peer", "call_remote", "reliable")
func _hello(want: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host or peers.has(id) or id in _waiting:
		return
	_greeted[id] = want
	if not playing or GameState.world.is_empty():
		_waiting.append(id)  # (in the lobby until the game begins)
		roster_changed.emit()
	else:
		_seat_peer(id)

## The player it asked for if that one is free (it played it before its connection went), else the first free one.
func _seat_peer(id: int) -> void:
	var want: int = _greeted.get(id, -1)
	var free := -1
	for p in GameState.world["players"]:
		if not p["is_ai"] and p["index"] != seat and not p["index"] in peers.values():
			if free < 0 or p["index"] == want:
				free = p["index"]
	if free < 0:
		_refused.rpc_id(id, "The game is full.")
		return
	peers[id] = free
	_welcome.rpc_id(id, free, _pack())
	roster_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	var in_lobby := _waiting.has(id)
	_waiting.erase(id)
	_greeted.erase(id)
	if in_lobby:
		roster_changed.emit()
	if id == _fight_peer:  # (it left mid-battle: the host settles the battle itself)
		_fight_peer = -1
		battle_result_arrived.emit({})
	if id == _battle_peer:  # (its side of a battle on both screens: the computer fights on for it)
		_battle_peer = -1
		battle_left = true
		_inbox.append({"k": "left"})
		battle_action_arrived.emit()
	if peers.erase(id):
		roster_changed.emit()

func _pack() -> PackedByteArray:
	var raw := var_to_bytes({"world": GameState.world, "uid": GameState._uid})
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return out

func _unpack(b: PackedByteArray) -> Dictionary:
	return bytes_to_var(b.slice(4).decompress(b.decode_u32(0), FileAccess.COMPRESSION_ZSTD))

@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	_drop(reason)

## Joining (or put right): the host's world and the player this machine plays. Its own view is kept.
@rpc("authority", "call_remote", "reliable")
func _welcome(pi: int, packed: PackedByteArray) -> void:
	if seat >= 0:
		resyncs += 1
	syncing = false
	var d := _unpack(packed)
	var w: Dictionary = d["world"]
	var old: Dictionary = GameState.world.get("views", {}).get(pi, {}) if not GameState.world.is_empty() else {}
	if not old.is_empty():
		w["views"][pi] = old
	seat = pi
	playing = true
	resume = {}
	GameState.world = w
	GameState._uid = int(d["uid"])
	GameState.viewer = -1
	var f := FileAccess.open(join_path, FileAccess.WRITE)  # (to join again after a restart: the main menu offers it)
	if f:
		f.store_var({"room": room, "address": "" if room != "" else _address, "seat": pi})
	world_received.emit()

## The game this machine last joined ({"room", "address", "seat"}), or empty.
func last_join() -> Dictionary:
	var f := FileAccess.open(join_path, FileAccess.READ) if FileAccess.file_exists(join_path) else null
	var d = f.get_var() if f else null
	return d if d is Dictionary else {}

# ---------------------------------------------------------------------------------------------
# The host's game, saved as it goes (resumed from the main menu)
# ---------------------------------------------------------------------------------------------
## Host: the game is saved soon (`now`: at once); a joining machine keeps none.
func save(now := false) -> void:
	if not is_host or not playing:
		return
	if now:
		_save_now()
	elif _save_at == 0:
		_save_at = Time.get_ticks_msec() + SAVE_DELAY

func _process(_d: float) -> void:
	if _save_at > 0 and Time.get_ticks_msec() >= _save_at:
		_save_now()

func _save_now() -> void:
	_save_at = 0
	if not is_host or not playing or GameState.world.is_empty():
		return
	var f := FileAccess.open(online_path, FileAccess.WRITE)
	if f:
		f.store_var({"version": GameState.SAVE_VERSION, "world": GameState.world, "uid": GameState._uid, "online": {
			"room": room if room != "" else str(resume.get("room", "")),
			"key": room_key if room_key != "" else str(resume.get("key", "")), "seat": seat}})

## The online game this machine hosted last, as saved ({"world", "uid", "online": {"room", "key", "seat"}}), or empty
## (none, or it has ended).
func online_save() -> Dictionary:
	var f := FileAccess.open(online_path, FileAccess.READ) if FileAccess.file_exists(online_path) else null
	var d = f.get_var() if f else null
	if not d is Dictionary or not d.get("world") is Dictionary or not d.get("online") is Dictionary:
		return {}
	return {} if d["world"].get("game_over", false) else d  # (a game that has ended is not offered)

## Hosts the saved online game again: under its room code (by its key) if it had one, else by address. The world is
## the saved one; the others rejoin it as the players they played. "" or what went wrong; the code comes later
## (room_opened: another one if someone else has the old code meanwhile).
func resume_saved() -> String:
	var d := online_save()
	if d.is_empty() or not GameState.load_game(online_path):
		return "There is no online game to resume."
	var o: Dictionary = d["online"]
	var by_room: bool = o.get("room", "") != "" or OS.has_feature("web")
	var err := host_room(str(o.get("room", "")), str(o.get("key", ""))) if by_room else host()
	seat = int(o.get("seat", 0))
	return err

## A joining machine asks for the host's world again (its own differed, or a command was refused).
@rpc("any_peer", "call_remote", "reliable")
func _ask_world() -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host and peers.has(id):
		_dump("host")
		_welcome.rpc_id(id, peers[id], _pack())

# ---------------------------------------------------------------------------------------------
# The lobby (before the game)
# ---------------------------------------------------------------------------------------------
## Host: the colour each machine in the lobby holds, given the colours open to people (`open`): one whose colour is
## no longer open loses it; one without a colour takes the one it asked for if that is open and free, else the first
## free one. It is seated as that colour when the game begins.
func lobby_assign(open: Array) -> void:
	for pi in lobby_seats.keys():
		if pi != seat and (not pi in open or not lobby_seats[pi] in _waiting):
			lobby_seats.erase(pi)
	for id in _waiting:
		if id in lobby_seats.values():
			continue
		var want: int = _greeted.get(id, -1)
		var pick := -1
		for pi in open:
			if not lobby_seats.has(pi) and (pick < 0 or pi == want):
				pick = pi
		if pick >= 0:
			lobby_seats[pick] = id
	lobby_seats[seat] = 1
	for pi in lobby_seats:
		if lobby_seats[pi] != 1:
			_greeted[lobby_seats[pi]] = pi

## Host: a machine moves to another open colour, if no one holds it.
func lobby_take(id: int, pi: int, open: Array) -> void:
	if not id in _waiting or not pi in open or lobby_seats.has(pi):
		return
	for k in lobby_seats.keys():
		if lobby_seats[k] == id:
			lobby_seats.erase(k)
	lobby_seats[pi] = id
	_greeted[id] = pi

## Host: the colour a machine holds in the lobby, or -1.
func lobby_seat_of(id: int) -> int:
	for pi in lobby_seats:
		if lobby_seats[pi] == id:
			return pi
	return -1

## Host: the lobby as it now is, to every machine in it.
func lobby_send(settings: Dictionary) -> void:
	var b := var_to_bytes({"settings": settings, "seats": lobby_seats,
		"waiting": _waiting.filter(func(id): return not id in lobby_seats.values())})
	for id in _waiting:
		_lobby_state.rpc_id(id, b)

@rpc("authority", "call_remote", "reliable")
func _lobby_state(b: PackedByteArray) -> void:
	var d = bytes_to_var(b)
	if d is Dictionary and not playing:
		lobby = d
		lobby_changed.emit()

## Joining machine: the colour it holds in the lobby, or -1.
func lobby_mine() -> int:
	var me := multiplayer.get_unique_id()
	for pi in lobby.get("seats", {}):
		if lobby["seats"][pi] == me:
			return int(pi)
	return -1

## Joining machine: asks the host for a change: {"take": colour}, or {"choice": {"faction", "hero", "bonus"}} for its
## own colour.
func lobby_ask(change: Dictionary) -> void:
	_lobby_ask.rpc_id(1, var_to_bytes(change))

@rpc("any_peer", "call_remote", "reliable")
func _lobby_ask(b: PackedByteArray) -> void:
	var id := multiplayer.get_remote_sender_id()
	var d = bytes_to_var(b)
	if is_host and not playing and id in _waiting and d is Dictionary:
		lobby_request.emit(id, d)

## Host: the game begins; the machines in the lobby wait for the world (it comes once the map screen has made it).
func lobby_begin() -> void:
	for id in _waiting:
		_lobby_begun.rpc_id(id)

@rpc("authority", "call_remote", "reliable")
func _lobby_begun() -> void:
	lobby_begun.emit()

# ---------------------------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------------------------
## A command this machine accepted on its world (Commands.run calls it with a copy taken before it applied).
func send(cmd: Dictionary) -> void:
	var b := var_to_bytes(cmd)
	sent += 1
	save(cmd.get("t", "") == "end_turn")
	if is_host:
		var dg := digest(GameState.world) if cmd.get("t", "") == "end_turn" else 0
		for id in peers:
			_apply.rpc_id(id, b, dg)
	elif seat >= 0:
		_submit.rpc_id(1, b)

func _rules() -> AdvRules:
	return rules if rules != null and is_same(rules.world, GameState.world) else AdvRules.new(GameState.world)

func _run(cmd: Dictionary) -> Dictionary:
	applying = true
	var res := _rules().do(cmd)
	applying = false
	return res

## The host: a joining player's command. Only for its own player; checked on the host's world, then passed on.
@rpc("any_peer", "call_remote", "reliable")
func _submit(b: PackedByteArray) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host or not peers.has(id) or GameState.world.is_empty():
		return
	var cmd = bytes_to_var(b)
	if not cmd is Dictionary or int(cmd.get("p", -1)) != peers[id]:
		_welcome.rpc_id(id, peers[id], _pack())
		return
	var res := _run(cmd)
	if not res["ok"]:
		_note("refused from player %d: %s (%s)" % [peers[id], cmd.get("t", ""), res["reason"]])
		_welcome.rpc_id(id, peers[id], _pack())  # (its world had gone astray: put it right)
		return
	received += 1
	save(cmd.get("t", "") == "end_turn")
	var dg := digest(GameState.world) if cmd.get("t", "") == "end_turn" else 0
	for other in peers:
		if other != id:
			_apply.rpc_id(other, b, dg)
	if dg != 0:
		_check.rpc_id(id, dg)
	remote_command.emit(cmd, res)

## A joining machine: a command from the host (its own, a computer player's, or another player's).
@rpc("authority", "call_remote", "reliable")
func _apply(b: PackedByteArray, dg: int) -> void:
	if GameState.world.is_empty() or seat < 0 or syncing:
		return
	var cmd: Dictionary = bytes_to_var(b)
	var res := _run(cmd)
	if not res["ok"] or (dg != 0 and digest(GameState.world) != dg):
		_note("out of step at %s: %s" % [cmd.get("t", ""), res.get("reason", "the worlds differ")])
		_resync()
		return
	received += 1
	remote_command.emit(cmd, res)

## A joining machine's own turn end, checked against the host's world.
@rpc("authority", "call_remote", "reliable")
func _check(dg: int) -> void:
	if not GameState.world.is_empty() and digest(GameState.world) != dg:
		_note("out of step after the turn")
		_resync()

## Asks for the host's world; until it comes, this machine makes no moves (Commands.run refuses them), so none are
## lost when it arrives. Commands from the host meanwhile are already in the world it sends.
func _resync() -> void:
	if syncing:
		return
	syncing = true
	_dump("mine")
	_ask_world.rpc_id(1)

## A world that went out of step, kept for tools/net_diff.tscn (user://net_out_of_step_<mine|host>.dat).
func _dump(which: String) -> void:
	var f := FileAccess.open("user://net_out_of_step_%s.dat" % which, FileAccess.WRITE)
	if f:
		f.store_var({"world": GameState.world, "uid": GameState._uid})

## The game state of a world as one number (views, the computer's notes and screen leftovers set aside; keys in
## order, so the same state gives the same digest on every machine).
static func digest(w: Dictionary) -> int:
	return hash(var_to_bytes([_canon(w), GameState._uid]))

static func _canon(v):
	if v is Dictionary:
		var keys: Array = v.keys().filter(func(k): return not str(k) in PRIVATE)
		keys.sort_custom(func(a, b): return str(a) < str(b))
		var out := []
		for k in keys:
			out.append([k, _canon(v[k])])
		return out
	if v is Array:
		return v.map(func(x): return _canon(x))
	return v

# ---------------------------------------------------------------------------------------------
# Battles fought on two machines
# ---------------------------------------------------------------------------------------------
## A battle between two machines' players is played on both screens at once: the machine that starts it sends the
## setup (seed included), each sends its own side's actions (battle.gd `_carry`), and both carry them out alike. A
## battle the host's computer player starts against another machine's player is fought on that machine, which
## sends the result back (fight_remote / battle_done).
signal battle_action_arrived
signal battle_result_arrived(result: Dictionary)

var _inbox: Array = []        ## actions from the other machine's player in the battle, in order
var _battle_peer := -1        ## host: the joined machine in the current battle (its leaving hands its side over)
var _fight_peer := -1         ## host: the machine fighting a battle the computer started (fight_remote)
var battle_left := false      ## host: the other machine in the battle left it (this machine applies its result)
var battle_sent := 0          ## battle actions sent from this machine, and received (a diagnostic)
var battle_got := 0

## The peer that plays a player (1, the host, for its own player and the computer players).
func machine_of(pi: int) -> int:
	for id in peers:
		if peers[id] == pi:
			return id
	return 1

func _route(to_pi: int, method: StringName, b: PackedByteArray) -> void:
	var id := machine_of(to_pi) if is_host else -1
	if is_host and id == 1:
		call(method, b)
	elif is_host:
		rpc_id(id, method, b)
	else:
		_relay.rpc_id(1, to_pi, method, b)

## The host passes a battle message between two joined machines (or takes one meant for its own player).
@rpc("any_peer", "call_remote", "reliable")
func _relay(to_pi: int, method: StringName, b: PackedByteArray) -> void:
	if not is_host or not method in [&"_battle_begin", &"_battle_action"]:
		return
	if machine_of(to_pi) == 1:
		_battle_peer = multiplayer.get_remote_sender_id()
		call(method, b)
	else:
		rpc_id(machine_of(to_pi), method, b)

## Starts a battle that `other`'s player also fights: their screen opens it with this setup (as they see it).
func battle_begin(setup: Dictionary, other: int) -> void:
	_inbox.clear()
	battle_left = false
	if is_host:
		_battle_peer = machine_of(other)
	_route(other, &"_battle_begin", var_to_bytes(setup))

@rpc("any_peer", "call_remote", "reliable")
func _battle_begin(b: PackedByteArray) -> void:
	_inbox.clear()
	GameState.return_scene = GameState.SCENE_ADVENTURE
	GameState.start_battle(bytes_to_var(b))

## One action of this machine's side, to the machine of the other side's player.
func battle_send(a: Dictionary, other: int) -> void:
	battle_sent += 1
	_route(other, &"_battle_action", var_to_bytes(a))

@rpc("any_peer", "call_remote", "reliable")
func _battle_action(b: PackedByteArray) -> void:
	_inbox.append(bytes_to_var(b))
	battle_got += 1
	battle_action_arrived.emit()

## The other side's next action ({"k": "left"} if its machine left the game).
func battle_next() -> Dictionary:
	while _inbox.is_empty():
		await battle_action_arrived
	return _inbox.pop_front()

## Host: the computer player attacks another machine's player; that machine fights it (with this setup) and sends
## the result. Empty if it left the game first.
func fight_remote(setup: Dictionary, pi: int) -> Dictionary:
	_fight_peer = machine_of(pi)
	_route(pi, &"_battle_begin", var_to_bytes(setup))
	var r: Dictionary = await battle_result_arrived
	_fight_peer = -1
	return r

## A joined machine: the result of a battle the host's computer player started against this machine's player.
func battle_done(result: Dictionary) -> void:
	_battle_done.rpc_id(1, var_to_bytes(result))

@rpc("any_peer", "call_remote", "reliable")
func _battle_done(b: PackedByteArray) -> void:
	if is_host and multiplayer.get_remote_sender_id() == _fight_peer:
		battle_result_arrived.emit(bytes_to_var(b))
