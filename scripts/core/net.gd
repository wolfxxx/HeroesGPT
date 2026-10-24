extends Node
## Online play, first version (HANDOFF §8, phase 2). One player hosts the real game; the others join it by address.
## Every command a machine accepts on its world (Commands.run) is passed on: a joining player's to the host, which
## checks it against its own world and passes it to everyone else; the host's own (its player's and the computer
## players') to everyone. Each machine applies them in the same order to its copy of the world, and the rules give
## the same world on each (the dice are the world's: Dice). The host's world is the true one: each turn's end
## carries its digest, and a machine whose world differs, or that had a command refused, is sent the host's world.
## Each machine shows its own player (`seat`, GameState.human_player_index) and its own view (GameState.view); the
## computer players move on the host only.
## Not yet: a battle between people on both screens (the side whose machine is not fighting it is led by the
## computer), joining a saved online game, a lobby; the fog hides the others' maps on screen only.

signal remote_command(cmd: Dictionary, res: Dictionary)  ## a command from another machine was applied
signal world_received                                    ## the host's world arrived (joined, or put right)
signal roster_changed                                    ## a player joined or left
signal lost(reason: String)                              ## the connection is gone (or never came)

const PORT := 24680
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

## Opens a game for others to join. Returns "" or what went wrong.
func host(port := PORT) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, 7) != OK:
		return "Cannot open port %d: is another game hosting already?" % port
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	seat = 0
	_link(multiplayer.peer_connected, _on_peer_connected)
	_link(multiplayer.peer_disconnected, _on_peer_disconnected)
	return ""

## Joins a game hosted at the address. The world arrives later (world_received), or `lost` if it cannot.
func join(address: String, port := PORT) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		return "Cannot reach %s." % address
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	seat = -1
	_link(multiplayer.connection_failed, func(): _drop("No game answered at %s." % address))
	_link(multiplayer.server_disconnected, func(): _drop("The host has left the game."))
	return ""

func leave() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	is_host = false
	syncing = false
	seat = -1
	peers = {}
	_inbox = []
	_battle_peer = -1
	_fight_peer = -1
	_waiting = []

func _note(text: String) -> void:
	print("NET ", text)
	notes.append(text)

func _drop(reason: String) -> void:
	leave()
	lost.emit(reason)

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
	for id in _waiting.duplicate():
		_waiting.erase(id)
		_seat_peer(id)

func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	if GameState.world.is_empty():
		_waiting.append(id)
	else:
		_seat_peer(id)

func _seat_peer(id: int) -> void:
	var free := -1
	for p in GameState.world["players"]:
		if not p["is_ai"] and p["index"] != seat and not p["index"] in peers.values():
			free = p["index"]
			break
	if free < 0:
		_refused.rpc_id(id, "The game is full.")
		return
	peers[id] = free
	_welcome.rpc_id(id, free, _pack())
	roster_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	_waiting.erase(id)
	if id == _fight_peer:  # (it left mid-battle: the host settles the battle itself)
		_fight_peer = -1
		battle_result_arrived.emit({})
	if id == _battle_peer:  # (its side of a battle on both screens: the computer fights on for it)
		_battle_peer = -1
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
	GameState.world = w
	GameState._uid = int(d["uid"])
	GameState.viewer = -1
	world_received.emit()

## A joining machine asks for the host's world again (its own differed, or a command was refused).
@rpc("any_peer", "call_remote", "reliable")
func _ask_world() -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host and peers.has(id):
		_dump("host")
		_welcome.rpc_id(id, peers[id], _pack())

# ---------------------------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------------------------
## A command this machine accepted on its world (Commands.run calls it with a copy taken before it applied).
func send(cmd: Dictionary) -> void:
	var b := var_to_bytes(cmd)
	sent += 1
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
