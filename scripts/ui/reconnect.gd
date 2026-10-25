class_name Reconnect
extends Node
## Online: the connection went during a game (Net.lost, with Net.resume set). A joining machine joins the same game
## again every few seconds until the host is back; its screen then starts again on the host's world
## (Net.world_received). The host opens its room again under the same code (the relay knows it by the room's key)
## and goes on; the others rejoin it. A dialog says so meanwhile, with a way out to the main menu.
##   if await Reconnect.run(self, reason): ...   (true: back in the game; false: the person gave up, Net forgotten)

const RETRY := 3.0      ## seconds between tries
const PATIENCE := 15.0  ## seconds a try may take before it is given up

static var running := false  ## a dialog is open (the losses of its own tries are not new losses to the screens)

var _gave_up := false
var _back := false
var _failed := ""

static func run(at: Node, reason: String) -> bool:
	if Net.resume.is_empty() or running:
		return false
	running = true
	var r := Reconnect.new()
	at.get_tree().root.add_child(r)
	var ok: bool = await r._run(at, reason)
	r.queue_free()
	running = false
	return ok

func _run(at: Node, reason: String) -> bool:
	var hosting: bool = Net.resume["host"]
	var code: String = Net.resume["room"]
	var where := ("room " + code) if code != "" else str(Net.resume["address"])
	var m := Modal.custom(at, "Connection Lost", 720)
	m.add_text(reason, 22)
	var line := m.add_text("", 20)
	m.add_buttons([["Main Menu", "menu"]])
	m.set_meta("cancel", "menu")
	m.closed.connect(_on_give_up)
	var arrived: Signal = Net.room_opened if hosting else Net.world_received
	arrived.connect(_on_back)
	Net.lost.connect(_on_failed)
	var tries := 0
	while not _gave_up and not _back:
		tries += 1
		_failed = ""
		line.text = ("Opening %s again, for the others to rejoin..." if hosting else
			"Joining %s again: waiting for the host...") % where + ("" if tries == 1 else "  (try %d)" % tries)
		var err := Net.rejoin()
		if err == "" and hosting and code == "":
			_back = true  # (by address: open at once)
		var t0 := Time.get_ticks_msec()
		while err == "" and _failed == "" and not _back and not _gave_up and Time.get_ticks_msec() - t0 < PATIENCE * 1000:
			await get_tree().process_frame
		if _back or _gave_up:
			break
		Net.leave()  # (a try that hangs is given up too)
		var t1 := Time.get_ticks_msec()
		while not _gave_up and Time.get_ticks_msec() - t1 < RETRY * 1000:
			await get_tree().process_frame
	arrived.disconnect(_on_back)
	Net.lost.disconnect(_on_failed)
	if not _back:
		Net.forget()
		return false
	if is_instance_valid(m):
		m.closed.disconnect(_on_give_up)
		m.close()
	if hosting and code != "" and Net.room != code:  # (someone else took the old code meanwhile)
		await Modal.message(at if is_instance_valid(at) else self, "Online Room",
			"The room has a new code: %s. Tell it to the others; they choose Multiplayer, type it and press Join." % Net.room).closed
	return true

func _on_give_up(_v) -> void:
	_gave_up = true

func _on_back(_a = null) -> void:
	_back = true

func _on_failed(why: String) -> void:
	_failed = why
