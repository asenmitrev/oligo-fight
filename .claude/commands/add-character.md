# Add Character

Add a new fighter character to the game, replacing an existing one.

Usage: `/add-character <NewName> replaces <OldName>`

## What to provide

- The new character's **display name** (e.g. `Veli`)
- The character to **replace** (e.g. `Georgi`)
- PNG sprite sheets already placed in `assets/<lowercased-name>/`

## Steps

### 1. Inspect the source assets

List `assets/<newname>/` and read each PNG visually to confirm:
- Grid layout (2×2 = 4 frames, or other)
- Which animations are present (walk, punch, kick, block, falls, getting-hit, getting-up, etc.)
- Which animations are **missing** vs Georgi's full set: idle, walk, jump, punch, kick, block, falls, gets_hit, getup, flypunch, flykick

For missing animations use these fallbacks:
- `idle` → first frame of walk only
- `jump` → walk frames (looped)
- `flypunch` → punch frames
- `flykick` → kick frames

### 2. Resize images to 256×256

All sprite sheets must be 256×256 total (128×128 per frame for a 2×2 grid).

```bash
for f in assets/<newname>/<newname>-*.png; do
  convert "$f" -filter point -resize 256x256! "$f"
done
```

Verify: `identify assets/<newname>/*.png`

### 3. Create `resources/<newname>_sprite_frames.tres`

Copy the structure from `resources/georgi_sprite_frames.tres` (or another character's `.tres`) as a template.

- One `[ext_resource]` entry per PNG file
- One `[sub_resource type="AtlasTexture"]` per frame (4 per sheet for a 2×2 grid)
  - `flags = 4`
  - `region = Rect2(0,0,128,128)`, `Rect2(128,0,128,128)`, `Rect2(0,128,128,128)`, `Rect2(128,128,128,128)`
- `[resource]` section lists all 11 animations, referencing the correct SubResources

Animation settings:
| Animation | loop | speed |
|-----------|------|-------|
| idle      | true | 8.0   |
| walk      | true | 8.0   |
| jump      | true | 8.0   |
| block     | true | 8.0   |
| punch     | false| 10.0  |
| kick      | false| 10.0  |
| flypunch  | false| 10.0  |
| flykick   | false| 10.0  |
| gets_hit  | false| 12.0  |
| getup     | false| 5.0   |
| falls     | false| 7.0   |

### 4. Update `scripts/character_db.gd`

Replace the old character's preload and definition:

```gdscript
# Replace:
const _oldname_frames: SpriteFrames = preload("res://resources/oldname_sprite_frames.tres")
# With:
const _newname_frames: SpriteFrames = preload("res://resources/newname_sprite_frames.tres")
```

Replace the `_make_def` block, keeping the same stats or adjusting as needed:

```gdscript
var veli = _make_def("veli", "Veli", _veli_frames, Color(1, 1, 1, 1))
veli.speed = 320.0
veli.jump_velocity = JUMP_VELOCITY
veli.punch_damage = 15
veli.kick_damage = 10
veli.block_damage_modifier = 0.18
veli.max_health = 120
_register(veli)
```

### 5. Update `scripts/game_state.gd`

If the replaced character was the default P2, update:

```gdscript
var p2_character: String = "NewName"
```

### 6. Update `scripts/fight.gd`

Find the special fake-win sequence (search for the old character name) and rename both the variable and the string references:

```gdscript
var veli_beat_simonka: bool = (not is_online) and winner_name == "Veli" and loser_name == "Simonka"
var win_text: String = "Veli thinks he's won!" if veli_beat_simonka else winner_name + " Wins!"
var round_text: String = "Veli thinks he's won Round %d!" % current_round if veli_beat_simonka else winner_name + " wins Round %d!" % current_round

if veli_beat_simonka:
```

### 7. Verify no remaining references

```bash
grep -r "OldName\|oldname" --include="*.gd" --include="*.tscn" --include="*.tres"
```

Any hits in `.gd`/`.tscn`/`.tres` files need fixing. Hits in old asset `.import` files and `oldname_sprite_frames.tres` are harmless (those files just become unused).
