extends Node
## What differs between the two worlds Net keeps when a joining machine goes out of step (user://net_out_of_step_mine.dat
## and _host.dat; both machines on one computer share user://). Views and the computer's notes set aside, as Net.digest.
##   Godot --headless --path . res://tools/net_diff.tscn

func _ready() -> void:
	var a = _read("user://net_out_of_step_host.dat")
	var b = _read("user://net_out_of_step_mine.dat")
	if a == null or b == null:
		print("NET DIFF: no saved worlds")
	else:
		var out := []
		if a["uid"] != b["uid"]:
			out.append("uid counter: %d vs %d" % [a["uid"], b["uid"]])
		_diff(a["world"], b["world"], "world", out)
		for d in out.slice(0, 40):
			print("  ", d)
		print("NET DIFF: %d differences (host vs joined)" % out.size())
	get_tree().quit()

func _read(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_var() if f else null

func _diff(x, y, path: String, out: Array) -> void:
	if out.size() > 60:
		return
	if x is Dictionary and y is Dictionary:
		var keys := {}
		for k in x:
			keys[k] = true
		for k in y:
			keys[k] = true
		for k in keys:
			if str(k) in Net.PRIVATE:
				continue
			if not x.has(k) or not y.has(k):
				out.append("%s.%s only on the %s" % [path, k, "host" if x.has(k) else "joined machine"])
			else:
				_diff(x[k], y[k], "%s.%s" % [path, k], out)
	elif x is Array and y is Array:
		if x.size() != y.size():
			out.append("%s: %d items vs %d" % [path, x.size(), y.size()])
			return
		for i in x.size():
			_diff(x[i], y[i], "%s[%d]" % [path, i], out)
	elif typeof(x) != typeof(y) or x != y:
		out.append("%s: %s vs %s" % [path, str(x).left(70), str(y).left(70)])
