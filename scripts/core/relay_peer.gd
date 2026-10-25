class_name RelayPeer
extends MultiplayerPeerExtension
## Online play through the relay (relay/src/index.js, a Cloudflare Worker): a WebSocket to it instead of ENet's UDP,
## so that a browser can play (it cannot open UDP sockets, nor be found by others) and nobody's router must let the
## game in. To the rest of the game it is a MultiplayerPeer like ENet's, in ENet's shape: the host is peer 1, every
## joined machine talks to the host only, and the host passes messages between them (server relay).
## Frames: 4 bytes peer (int32), 1 byte flags (1: more of this message follows), data; a long message goes in
## pieces (CHUNK), put back together per sender. The relay's own notes come as text (JSON): see the relay.

signal room_opened(code: String)   ## host: the room is open; others join with this code
signal closed(reason: String)      ## the connection to the relay is gone (or never came)

const CHUNK := 60000

var reason := ""        ## why the relay refused, or the connection ended
var _ws := WebSocketPeer.new()
var _hosting := false
var _id := 0
var _status := CONNECTION_DISCONNECTED
var _target := 0
var _channel := 0
var _mode := TRANSFER_MODE_RELIABLE
var _in: Array = []     ## [from, data] messages waiting to be read, in order
var _parts := {}        ## from -> the pieces of a long message so far
var _from := 0          ## the sender of the message last read
var _joined := {}       ## host: the machines in the room

## Connects to the relay: `<relay>/host` opens a room, `<relay>/join/<code>` joins one.
func open(url: String, hosting: bool) -> Error:
	_hosting = hosting
	_ws.inbound_buffer_size = 1 << 22
	_ws.outbound_buffer_size = 1 << 22
	_ws.max_queued_packets = 8192
	var err := _ws.connect_to_url(url)
	if err == OK:
		_status = CONNECTION_CONNECTING
	return err

func _poll() -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	_ws.poll()
	while _ws.get_available_packet_count() > 0:
		var pkt := _ws.get_packet()
		if _ws.was_string_packet():
			_note(JSON.parse_string(pkt.get_string_from_utf8()))
		elif pkt.size() >= 5:
			var from := pkt.decode_s32(0)
			var piece := pkt.slice(5)
			if pkt[4] & 1:
				_parts[from] = _parts.get(from, PackedByteArray()) + piece
			else:
				_in.append([from, _parts.get(from, PackedByteArray()) + piece])
				_parts.erase(from)
	if _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_lost("The connection to the relay was lost." if reason == "" else reason)

func _note(n) -> void:
	if not n is Dictionary:
		return
	match str(n.get("t", "")):
		"room":
			_id = 1
			_status = CONNECTION_CONNECTED
			room_opened.emit(str(n["code"]))
		"id":
			_id = int(n["id"])
			_status = CONNECTION_CONNECTED
			peer_connected.emit(1)
		"join":
			_joined[int(n["id"])] = true
			peer_connected.emit(int(n["id"]))
		"leave":
			if _joined.erase(int(n["id"])):
				peer_disconnected.emit(int(n["id"]))
		"error":
			reason = str(n.get("reason", "The relay refused."))
		"host_left":
			reason = "The host has left the game."

func _lost(why: String) -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	var was := _status
	_status = CONNECTION_DISCONNECTED
	reason = why
	for id in _joined.keys():
		peer_disconnected.emit(id)
	_joined.clear()
	if was == CONNECTION_CONNECTED and not _hosting:
		peer_disconnected.emit(1)
	closed.emit.call_deferred(why)  # (after the multiplayer's poll: whoever hears it may close this peer)

func _get_available_packet_count() -> int:
	return _in.size()

func _get_packet_script() -> PackedByteArray:
	if _in.is_empty():
		return PackedByteArray()
	var m: Array = _in.pop_front()
	_from = m[0]
	return m[1]

func _get_packet_peer() -> int:
	return _in[0][0] if not _in.is_empty() else _from  # (asked before the message is read)

func _put_packet_script(p: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var to := _target if _hosting else 1
	var at := 0
	while true:
		var piece := p.slice(at, at + CHUNK)
		at += CHUNK
		var frame := PackedByteArray()
		frame.resize(5)
		frame.encode_s32(0, to)
		frame[4] = 1 if at < p.size() else 0
		frame.append_array(piece)
		var err := _ws.send(frame)
		if err != OK:
			return err
		if at >= p.size():
			return OK
	return OK

func _get_packet_channel() -> int:
	return 0

func _get_packet_mode() -> TransferMode:
	return TRANSFER_MODE_RELIABLE  # (a WebSocket delivers everything, in order)

func _set_transfer_channel(c: int) -> void:
	_channel = c

func _get_transfer_channel() -> int:
	return _channel

func _set_transfer_mode(m: TransferMode) -> void:
	_mode = m

func _get_transfer_mode() -> TransferMode:
	return _mode

func _set_target_peer(p: int) -> void:
	_target = p

func _get_max_packet_size() -> int:
	return 1 << 24

func _is_server() -> bool:
	return _hosting

func _is_server_relay_supported() -> bool:
	return true

func _get_unique_id() -> int:
	return _id

func _get_connection_status() -> ConnectionStatus:
	return _status

func _disconnect_peer(p: int, _force: bool) -> void:
	if _joined.erase(p):
		peer_disconnected.emit(p)

func _close() -> void:
	_ws.close()
	_status = CONNECTION_DISCONNECTED
	_in.clear()
	_parts.clear()
	_joined.clear()
