# Asset Manifest (contract between art/audio pipeline and code)

Sprites rendered by tools/art/blender use a fixed world scale and write their foot point to `<dir>/anchors.json`
(map art: 64 px per Blender unit, drawn at 0.5 => 2 units per 64px tile; creatures: 150 px/unit). Code reads it
with `Assets.anchor()`. Extra map decor ids: `map/mountain_snow_1..2.png`; `map/obelisk.png` is the Obelisk of Thoth (id `learning_stone`).

All paths relative to `res://assets/`. Code loads via `Assets.tex("<path>")` which falls back to a
generated placeholder if the file is missing, so code and art can progress independently.
**PNG with real alpha transparency** for all sprites/icons. Style: painterly high-fantasy,
rich saturated colours, warm lighting from the top-left, in the spirit of Heroes of Might and Magic III/V.

## Creatures — `creatures/<id>.png`
Side-view full-body battle sprite, **facing RIGHT**, transparent background, feet touching bottom-centre,
~512px tall canvas (square 512x512, 2-hex creatures 768x512). Ids: see `GameData.CREATURES`:
pikeman archer griffin swordsman monk cavalier angel skeleton zombie ghost vampire lich dread_knight bone_dragon
Also `creatures/portraits/<id>.png` — 128x128 bust/head close-up with painted background (used in recruit/army slots).

**Source models.** Creatures, hero portraits and mounted hero sprites are rendered from Sketchfab library models
(see `CREDITS.md`), not the procedural `figures.py` bodies. `tools/art/blender/imported.py` downloads a model
(key from the Blender MCP addon), `adopt()`s it (3/4 facing, height, feet on the ground), and renders it with the
same camera/lights/scale as before. Per-model settings (turn, height, hidden parts, tint, portrait framing) live
in `tools/art/imported_specs.json`; the posed models are cached as `tools/art/raw/models/<id>.glb` (git-ignored).
Re-render everything with batch step `"imported"`, then the usual `postfx.py` + `portrait_bg.py`.
`python tools/art/credits.py` regenerates `CREDITS.md`. The ghost model is CC-BY-NC (non-commercial only).

**Painted over.** All renders are then painted over by Gemini image models on Vertex AI (`tools/art/vertex_paint.py`,
project id from `GOOGLE_CLOUD_PROJECT` or `imagegen/vertex_project.txt`): portraits and towns via
`imagegen_prep.py` / `town_groups.py` / `imagegen_ingest.py`, sprites and battlefields via `sprite_paint.py`
(original alpha and soft shadows kept). `assets/creatures/sizes.json` (`tools/art/sprite_sizes.py`) holds each
figure's solid size; battle scales units by tier from it.

**Poses** — `creatures/<id>_attack.png`, `_hit.png`, `_dead.png` (optional; anchors in `creatures/anchors.json`).
Drawn by the image model from the painted idle sprite on a magenta backdrop (`tools/art/pose_paint.py`), keyed,
scaled to the idle figure, with a synthetic cast shadow. Battle swaps to them during attacks, on damage, and
leaves the `_dead` sprite on the hex as a corpse.

**Machine wrecks:** `creatures/{ballista,first_aid_tent,ammo_cart,catapult}_dead.png` — a destroyed war machine's
broken remains, left level on its hex. The ballista's came from built-in imagegen in round47 (prompt in
`tools/art/ballista_wreck_prompt.md`); the tent, cart and catapult from `tools/art/machine_wreck_paint.py`
(imagegen/batch30: the idle sprite on magenta, repainted wrecked, keyed, a cast shadow added). Its `shrink` step
resamples every wreck to about 1.5x its on-screen size (the battle draws them at a quarter of their painted size or
less, without mipmaps, which speckled the splinters). Anchor = the solid bottom centre; battle scales a wreck's
painted width to the idle machine's footprint and keeps its colours (dimmed, not the creatures' grey corpse tone).
Measure with `python tools/art/sprite_sizes.py <id>_dead.png` to preserve unrelated hand-tuned entries in `sizes.json`.

## Heroes
- `heroes/portraits/<hero_id>.png` — 256x256 painted portrait (ids in `GameData.HEROES`). The heroes from legend
  (`jacques_de_molay`, `hugues_de_payens`, `saint_germain`, `edward_kelley`) are painted by
  `tools/art/legend_portraits.py` (`paint`, `ingest`; imagegen/batch35) with a same-faction portrait as the style
  reference.
- `heroes/map_<faction>.png` — mounted hero on horse, 3/4 top-down view for the adventure map, transparent, 160x160, facing right.
  The faction's figure stands for its first class on the map (Haven a Knight, Necropolis a dark lance knight: the
  Death Knight). `heroes/map_<class>.png` and `map_<class>_run<0-3>.png` (`cleric`, `necromancer`) — the other
  classes, the same horses in the same standing and gallop poses repainted with another rider, all five poses in one
  sheet so the rider stays the same, by `tools/art/map_class_paint.py` (imagegen/batch32; ingest aligns each figure's
  hooves with its source, gives it the gallop frames' synthetic cast shadow and copies the source's anchor).
  `MapView.hero_figure` picks the class's figure, else the faction's.
- `heroes/battle_<faction>.png` — hero on horse for the battle screen corner, transparent, ~300x300, facing right:
  the faction's first class (Haven a Knight, Necropolis a Necromancer). `heroes/battle_<class>.png` (`cleric`,
  `death_knight`) — the other classes, the same horse repainted with another rider by `tools/art/hero_class_paint.py`
  (imagegen/batch31; ingest lays the new figure over the old one's ground shadow). The Cleric holds the mace resting
  on the shoulder (repainted in session67; it was raised in every pose).
  `heroes/battle_<fig>_idle<0-3>.png` and `battle_<fig>_cast.png` (`fig` = `haven`, `cleric`, `necropolis`,
  `death_knight`) — a 4-frame idle loop and a casting pose for each battle figure, painted from it on magenta by
  `tools/art/battle_anim_paint.py` (imagegen/batch33: the four idle frames in one 2x2 sheet so the rider stays the
  same); ingest stands each frame on the figure's feet on its canvas with a cast shadow of the frame's own outline.
  `battle.gd` rests the hero on `_idle0`, plays the loop now and then and shows `_cast` while it casts.
  `battle_necropolis.png` (a necromancer on a skeletal horse) is painted over the old knight by
  `tools/art/hero_battle_paint.py` (imagegen/batch18); the knight is kept in `tools/art/raw/heroes/`.
- `heroes/flag_<color>.png` optional (color = red/blue/green/gold).

## Adventure map
- `terrain/<terrain>.png` — seamless tileable 512x512 top-down ground textures: grass dirt sand snow swamp water road.
- `map/town_<faction>.png` — town as seen on adventure map (3/4 oblique top-down), transparent, ~384x288 (occupies ~5x3 tiles at 64px; the entrance gate at bottom centre).
  This is the full castle (a town with a Castle). `map/town_<faction>_village.png` (no Fort: houses, no wall) and
  `map/town_<faction>_fort.png` (Fort or Citadel: a plain wall and gatehouse, no round towers) are repaints of it on the
  same canvas and anchor (`MapView.town_sprite`), by `tools/art/town_levels_paint.py` (imagegen/batch29).
- `map/<mine_id>.png` — mines (ids in `GameData.MINES`), transparent, ~192x160.
- `map/res_<resource>.png` — resource pile on the ground, transparent, ~96x80. `res_sulfur.png` was repainted
  (sheet `sulfur` of `button_icons_paint.py`, then `tools/art/map_pile.py`: smoke dropped, scaled to the old size, shadow).
- `map/chest.png`, `map/campfire.png`, `map/artifact.png` (generic artifact pedestal/glow), `map/shrine.png` (the
  Stone Circle, id `shrine`), `map/windmill.png`, `map/obelisk.png`, `map/dwelling_neutral.png`, `map/watchtower.png`
  (the Observatory, id `watchtower`). The stone circle and the observatory were repainted for the setting by
  `tools/art/map_object_paint.py` (`prep`, `paint`, `ingest`; imagegen/batch34; the old sprite is the reference for
  view, size and light, kept as `imagegen/batch34/in/<name>_ref.png`; `GROW` enlarges a figure past a fit into the
  old one's box). The old sprites are in ignored `shots/session67/art_old/`.
- `map/war_machine_factory.png` — neutral workshop with ballista, medical supplies and ammo wagon. Built-in
  OpenAI imagegen, native 1536x1024 RGBA copied unmodified; exact prompt in `tools/art/war_machine_factory_prompt.md`.
  No Blender anchor: `MapView._object_node` scales it to 3.2 tiles wide and offsets the transparent bottom margin
  by 26px to put the doorway on the action tile. Standard 3x2 building footprint. The factory shop reuses the
  existing machine portraits, gold icon and painted UI panels/buttons.
- Decorations, transparent: `map/tree_oak_1..4.png`, `map/tree_pine_1..3.png`, `map/tree_dead_1..2.png`,
  `map/mountain_1..3.png` (large ~256x224), `map/rock_1..3.png`, `map/bush_1..2.png`, `map/flowers_1..2.png`, `map/snow_pine_1..2.png`.
- Ground details `map/decor_<name>.png` (stump, log, toadstools, tuft, boulders, wildflowers, fern, twigs, pillar, bones,
  thorns, menhir, snow_rock, ice, snow_stump, frost_shrub, cactus, horn_skull, dry_grass, sandstone, reeds, swamp_caps,
  mossy_log, swamp_shrub): painted as two 4x3 sheets on magenta by `tools/art/decor_paint.py` (imagegen/batch12),
  keyed, cut, given a cast shadow and an anchor. Which terrain gets which: `WorldGen.DECOR_KINDS`.
- Roads are not a texture of their own: `MapView` turns road tiles into smoothed polylines and a distance field, and
  `terrain.gdshader` paints cobbles there (gravel shoulder from `terrain/road.png`).
- `map/flag_pole.png` + `map/flag_cloth.png` — owner banner, 4 waving frames of 91x112 side by side; the cloth is
  grey shading multiplied by the player colour (`MapView._Flag`). Painted by `tools/art/flag_paint.py` (imagegen/batch16).
- `terrain/snow.png` is painted (`tools/art/snow_paint.py`, imagegen/batch15, made seamless); the old graded photo is in
  `tools/art/raw/terrain/snow_old_graded.png`.
- `map/monster_<creature_id>.png` optional — default is to reuse the creature sprite scaled.
- Past the map's edge there are no assets: `fog.gdshader` draws the rocky ridge and void, and `MapView._build_border`
  reuses `map/mountain_*.png` and `map/rock_*.png` (with `border_rock.gdshader` recolouring their grass to rock).

## Battle
- `battle/bg_<terrain>.png` — 1920x1080 painted battlefield backdrop (side/elevated view, open flat ground in the
  middle where the hex grid goes, horizon/scenery in the top ~25%). terrains: grass dirt sand snow swamp.
- `battle/bg_siege_<faction>_<level>.png` — the siege backdrop of each fortification level (1 Fort: the wall and
  gate; 2 Citadel: + moat and keep; 3 Castle: + round towers at the wall's ends), painted so the wall stands on grid
  column 11 with a tower (or the wall's end) on rows 0 and 10, stretches on rows 1-2, 3-4, 6-7, 8-9 and the gate on
  row 5. `battle/siege_<faction>_<level>_ruin_<segment>.png` — each breakable segment's breach overlay, and
  `_dmg_<segment>.png` its battered look after one hit (still standing), both placed by `battle/siege.json`
  (`"<faction>_<level>": {segment: [x, y]}`). The Castle's lower tower has a crenellated top for its archer
  (`retop`; it stands at the command bar, so only its top shows). By `tools/art/siege_levels_paint.py`
  (imagegen/batch28: a collage of the first siege painting moved into that layout, repainted, then the lower levels
  and the breaches derived from it). `battle/siege_<faction>_archer.png` — the arrow-tower crew.
- `battle/fx_<fire|frost|spark|arcane|holy|dark>.png` — spell effects, 4x4 flipbooks of 256 px frames on black,
  drawn with additive blending (`battle.gd` FX_OF / _play_fx). Painted by `tools/art/vfx_paint.py` (imagegen/batch13).
- `ui/spellbook.png` — 1536x1024 open leather spellbook with five school tabs (all, air, fire, water, earth), keyed
  from magenta. Page and tab rectangles are in `scripts/ui/spell_book.gd`. `icons/spell_<id>.png` (128 px) are painted
  miniatures. Both by `tools/art/spellbook_paint.py` (imagegen/batch14; `paint <spell_id>` repaints one miniature).
- `ui/paperdoll.png` — 600x800 hero-screen paper-doll: a faint gilded etching of an armoured figure on dark slate;
  the artifact sockets are drawn over it (`scripts/ui/hero_screen.gd` SOCKETS). `tools/art/paperdoll_paint.py`
  (imagegen/batch17).
- `creatures/sizes.json` — per sprite `[w, h, vis_w]`: solid figure size and the width with semi-transparent wings /
  capes, used by `battle.gd` to size stacks within their 1- or 2-hex footprint (`tools/art/sprite_sizes.py`).
- `battle/obstacle_<kind>.png` — obstacles on hexes, varied per terrain (`battle.gd` OBSTACLES): boulders, dead_tree, log,
  crater, thorns, pillar, rock_spire, skull_pile, snow_boulders, ice, frozen_tree, sandstone, cactus, bones, swamp_tree,
  rotten_log. Painted at twice their field size, centred on their feet, by `tools/art/obstacle_paint.py`
  (imagegen/batch22). The old `obstacle_2.png` stump is still used on grass.

## Town screens
- `town/<faction>_bg.png` — 1920x1080 painted landscape backdrop of the town site (sky + ground, no buildings, or only the
  base walls/hill).
- `town/<faction>_<building>.png` — each building as a separate transparent sprite to composite on the backdrop.
  building ids: village_hall (also used for town_hall/city_hall with `town_hall`, `city_hall` variants), fort, citadel,
  tavern, marketplace, mage_guild_1, mage_guild_2 (also shown for guild levels 3-4), blacksmith, dwelling_1 .. dwelling_7.
  Rendered buildings are cropped layers of one 1920x810 scene; their pixel rects live in
  `town/layout_<faction>.json` (written by tools/art/town_crop.py). `scripts/town/town_layout.gd` is the fallback.
  Each faction has its own site: Haven is `tools/art/blender/townscreen.py` (round plaza before a white castle),
  Necropolis is `tools/art/blender/necro_town.py` (a moor below a black crag, skull gate, its own slots and buildings).
  The blockouts are painted over in non-overlapping groups (`tools/art/town_groups.py <faction> --out ... --full ...`,
  which also writes notes.json telling the painter what each building is).
  The Haven guardhouse (`haven_dwelling_1.png`) was cut off at the screen edge in the render; it is repainted whole
  and moved to the front-right lawn by `tools/art/town_edge_paint.py` (imagegen/batch19), which also rewrites its rect.
  The archers' tower (`haven_dwelling_2.png`) had its roof cut at the left edge: `tools/art/tower_edge_paint.py`
  (imagegen/batch21) repaints the roof and platform whole, aligned to the old sprite, and moves it right.

## Icons & UI
- `icons/res_<resource>.png` — 64x64 resource icons.
- `icons/spell_<spell_id>.png` — 96x96 spell icons.
- `icons/artifact_<artifact_id>.png` — 128 px framed paintings on a wine-red ground (one per artifact and combination,
  ids in `GameData.ARTIFACTS`), painted by `tools/art/artifact_icons.py paint [ids]` (imagegen/batch27) and framed by
  `... ingest`. On the map an artifact is drawn as its own icon over a glow of its tier's colour (`MapView._ArtifactGlow`);
  that picture is `map/art_<id>.png`, the item keyed out of its painting with a cast shadow by
  `tools/art/artifact_map_sprites.py`; `map/artifact.png` (the old pedestal) is no longer used. Eleven were repainted
  as relics of the setting (`docs/SETTING.md`; `artifact_icons.RETHEMED`, painted from the neutral reference icon so
  the old item does not show through): the Crystal Skull, Dr. Dee's Scrying Mirror, the Templar Treasure, the
  Count's coronet, cloak and elixir and their set, the Templar cross, the Holy Grail, the Templar surcoat and their
  set; then the Eye of Horus and the Ankh of Life (`amulet_of_insight`, `ring_of_vitality`). Artifact ids are unchanged; only names and pictures changed.
- `icons/skill_<skill_id>.png` — 128 px secondary skills (painted, sheet `skills`; Offense from `conditions`).
- `icons/stat_attack.png stat_defense.png stat_power.png stat_knowledge.png stat_morale.png` — 128 px primary stats and
  morale (sheets `stats`, `knowledge`); `stat_health.png stat_damage.png stat_xp.png stat_speed.png` (sheet `misc_stats`).
- `icons/spellbook_closed.png` — the hero screen's spellbook slot (sheet `tome`).
- `ui/cond_win.png cond_lose.png cond_gold.png cond_hero.png cond_capture.png` — scenario victory / loss pictures on
  New Game (sheets `conditions`, `conditions2`).
  All of these come from `tools/art/button_icons_paint.py` (imagegen/batch20): `paint <sheet>`, then `ingest <sheet>`,
  then keep the chosen take under its final name.
- `icons/building_<faction>_<building>.png` — 160x100 thumbnails for the build screen (can be auto-cropped from town sprites).
- `ui/btn_<kingdom|hero|sleep|move|spellbook|next_hero|end_turn|system>.png` — 128 px adventure panel button icons,
  and `ui/btn_<retreat|auto|defend|surrender|options|ballista|catapult|first_aid>.png` for the battle bar (the last
  five not used yet), painted as sheets by `tools/art/button_icons_paint.py` (imagegen/batch20).
- `ui/panel.png` — 9-slice ornate stone/wood panel texture (256x256, 48px border).
- `ui/button.png`, `ui/button_hover.png`, `ui/button_pressed.png` — 9-slice buttons (192x64, 20px border).
  Hero portrait buttons reuse these for the raised/hover/held states; `ui/button_selected.png` gives the selected
  adventure hero its brighter frame (also used for pressed/selected states by the general button theme).
- `ui/frame_portrait.png` — ornate gold frame 160x160 (transparent centre).
- `ui/main_menu_bg.png` — 1920x1080 epic key art.
- `ui/logo.png` — game title logo "Heroes of the Shattered Crown", transparent.
- `ui/cursor_*.png` — 32x32: normal, move, attack, shoot, horse, spell, blocked.
- `ui/parchment.png` — parchment texture for dialogs.
- `ui/hex.png`, `ui/hex_hover.png` optional.

## Audio — `audio/`
- Music (`.mp3`): `music/menu.mp3`, `music/adventure_grass.mp3`, `music/adventure_dirt.mp3`, `music/town_haven.mp3`,
  `music/town_necropolis.mp3`, `music/battle.mp3`, `music/victory.mp3` (short sting), `music/defeat.mp3` (short sting).
- SFX (`.mp3`) in `sfx/`: click, build, recruit, gold_pickup, resource_pickup, chest_open, footstep_horse,
  new_day, new_week, level_up, spell_cast, magic_arrow, lightning, fireball, bless, curse, heal, meteor,
  arrow_shot (a longbow volley, archers and arrow towers), arrow_hit, sword_hit, blunt_hit, claw_hit, magic_hit, death_human, death_undead, death_beast,
  wings, battle_start, victory_cheer, defeat, move_step, retaliate, miss, flag_capture, mine_capture, error,
  catapult_launch, catapult_hit (a boulder on the wall), catapult_miss (a splash short of it), ballista_shot (a deep
  thunk; best of three takes by low-to-high frequency energy, measured with an `AudioEffectSpectrumAnalyzer`). All by
  `tools/audio/gen_audio.py sfx <names>` (ElevenLabs; prompts in its `SFX` table). Generated loudness varies a lot:
  measure a new sound's peak in a window (`AudioServer.get_bus_peak_volume_left_db` while it plays) and regenerate
  it if it peaks far below the others (about -2 dB); session67 found blunt_hit at -33 dB, arrow_shot
  at -21, mine_capture at -25, death_undead at -15 and resource_pickup at -17, and remade them.
- Per-creature (optional): `sfx/<creature_id>_attack.mp3`, `sfx/<creature_id>_death.mp3`.
- Voice (optional): `voice/<line_id>.mp3` narrator lines: intro, victory, defeat, new_week.
