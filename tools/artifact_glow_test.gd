extends Node2D
## Render all twinkle phases, with extra samples at appearance/disappearance thresholds.
## A windowed run exercises the renderer; -- --shot=... holds a labelled contact sheet for inspection.
var glows := []
var phases := []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.19, 0.24, 0.13)
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	var title := UI.label("Artifact twinkle — real map drawing at sampled phases", 30)
	title.position = Vector2(100, 70)
	add_child(title)
	# The former concave polygon could collapse as sin(...) crossed 0.375.
	for k in 2:
		for angle in [asin(0.375), PI - asin(0.375)]:
			for epsilon in [-0.000001, 0.0, 0.000001, 0.001, 0.02, 0.2]:
				phases.append((angle - k * 2.6 + epsilon) / 1.6)
	for i in 32:
		var glow := MapView._ArtifactGlow.new()
		glow.col = Color(1, 0.6, 0.2)
		glow.strong = true
		glow.position = Vector2(170 + (i % 8) * 220, 300 + (i / 8) * 220)
		glow.t = phases[i] if i < phases.size() else float(i - phases.size()) / 7.0 * TAU / 1.6
		add_child(glow)
		glow.set_process(false)
		glows.append(glow)
		var label := UI.label("t = %.6f" % glow.t, 18)
		label.position = glow.position + Vector2(-65, 30)
		add_child(label)
	if Shot.active: return
	for frame in 128:
		for i in glows.size():
			glows[i].t = phases[(frame + i) % phases.size()] if frame < 24 else (frame + float(i) / 32.0) * TAU / 128.0
			glows[i].queue_redraw()
		await get_tree().process_frame
	print("ARTIFACT GLOW TEST: 4096 phase draws completed")
	get_tree().quit()
