# Ballista wreck (round 47)

Created with the built-in imagegen tool, using `assets/creatures/ballista.png` as the reference.
The output is copied unmodified to `assets/creatures/ballista_dead.png`, preserving its real alpha.
`python tools/art/sprite_sizes.py ballista_dead.png` measures only this sprite; `anchors.json` anchors the solid bottom centre. The battle pose loader
matches a machine wreck to its idle painted width, so native generator resolution needs no resampling.

## Exact prompt

Use case: precise-object-edit. Asset type: transparent PNG destroyed-unit sprite for a classic painted fantasy strategy game. Input image 1 is the intact ballista edit target/style reference. Create its destroyed wreck: the same brown timber-and-iron ballista in the same side-on, slightly elevated three-quarter camera, facing right, collapsed close to the ground. Break the tall bow limbs and release the bowstring; snap the chassis, tilt one wheel outward, leave a few coherent splintered beams around the low recognizable carriage. Preserve the reference's warm hand-painted wood, iron rivets, restrained dark outlines, lighting from top left, and level of detail. All parts remain within a compact footprint about the width of the intact ballista. Clearly destroyed, not an intact ballista tipped sideways. No person, no flames, no smoke, no text, no border, no environment, no backdrop or opaque ground patch. True transparent background, only a subtle contact shadow. Entire wreck visible with padding. Compose it horizontally, low in the canvas; ground contact near 85 percent image height. Return one sprite, not a sheet.
