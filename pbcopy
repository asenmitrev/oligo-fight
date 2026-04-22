# Add Character

Add a new fighter character to the game.

Usage: `/add-character <NewName> [replaces <OldName>]`

## What to provide

- The new character's **display name** (e.g. `Siyana`)
- Optionally, the character to **replace** (e.g. `Georgi`)
- PNG sprite sheets already placed in `assets/<lowercased-name>/`

## Steps

### 1. Inspect the source assets

List `assets/<newname>/` and read each PNG visually to confirm:
- Grid layout (2×2 = 4 frames, or other)
- Which animations are present (walk, punch, kick, block, falls, getting-hit, getting-up, etc.)
- Which animations are **missing** vs the full set: idle, walk, jump, punch, kick, block, falls, gets_hit, getup, flypunch, flykick
- Whether the **idle** is a single full-height image (one pose) or already a sprite sheet

For missing animations use these fallbacks:
- `idle` → first frame of walk only
- `jump` → walk frames (looped)
- `flypunch` → punch frames
- `flykick` → kick frames

### 2. Resize images to 256×256

**If the idle PNG is a single full-height image** (not a 2×2 sprite sheet), tile it first:

```bash
convert assets/<newname>/<newname>-idle.png -filter point -resize 128x128! /tmp/<newname>_idle_frame.png
convert \( /tmp/<newname>_idle_frame.png /tmp/<newname>_idle_frame.png +append \) \
        \( /tmp/<newname>_idle_frame.png /tmp/<newname>_idle_frame.png +append \) \
        -append assets/<newname>/<newname>-idle.png
```

Then resize all sprite sheets (including the now-tiled idle) to 256×256:

```bash
for f in assets/<newname>/<newname>-*.png; do
  convert "$f" -filter point -resize 256x256! "$f"
done
```

Verify: `identify assets/<newname>/*.png`

Visually confirm the idle looks correct (should show 4 identical poses in a 2×2 grid).

### 3. Create `resources/<newname>_sprite_frames.tres`

Copy the structure from `resources/sasho_sprite_frames.tres` as a template.

- One `[ext_resource]` entry per PNG file
- One `[sub_resource type="AtlasTexture"]` per frame (4 per sheet for a 2×2 grid)
  - `flags = 4`
  - `region = Rect2(0,0,128,128)`, `Rect2(128,0,128,128)`, `Rect2(0,128,128,128)`, `Rect2(128,128,128,128)`
- `[resource]` section lists all 11 animations, referencing the correct SubResources
- For **idle**: use a single SubResource (top-left frame) repeated 4 times in the animation array

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

Total sub_resources: 41 (4 per animation × 10 non-idle animations + 1 for idle). `load_steps = 53`.

### 4. Update `scripts/character_db.gd`

Add the new character's preload and definition:

```gdscript
const _newname_frames: SpriteFrames = preload("res://resources/newname_sprite_frames.tres")
```

Add a `_make_def` block (or replace the old one if replacing):

```gdscript
var siyana = _make_def("siyana", "Siyana", _siyana_frames, Color(1, 1, 1, 1))
siyana.speed = 350.0
siyana.jump_velocity = JUMP_VELOCITY
siyana.punch_damage = 13
siyana.kick_damage = 10
siyana.block_damage_modifier = 0.15
siyana.max_health = 105
_register(siyana)
```

### 5. Update `scripts/character_select.gd`

The `_setup_select_grid` function has a `centers_x` array with one entry per character. Add an entry for the new character, evenly dividing the screen width by `(count + 1)`:

- 5 characters → `[0.167, 0.333, 0.500, 0.667, 0.833]` (divide by 6)
- 6 characters → `[0.143, 0.286, 0.429, 0.571, 0.714, 0.857]` (divide by 7)
- 7 characters → `[0.125, 0.250, 0.375, 0.500, 0.625, 0.750, 0.875]` (divide by 8)

Also update the `flip_h` line so the right half of characters face left (inward):

```gdscript
preview.flip_h = (i >= centers_x.size() / 2)
```

### 6. (If replacing) Update `scripts/game_state.gd`

If the replaced character was the default P2, update:

```gdscript
var p2_character: String = "NewName"
```

### 7. (If replacing) Update `scripts/fight.gd`

Find the special fake-win sequence (search for the old character name) and rename both the variable and the string references:

```gdscript
var veli_beat_simonka: bool = (not is_online) and winner_name == "Veli" and loser_name == "Simonka"
var win_text: String = "Veli thinks he's won!" if veli_beat_simonka else winner_name + " Wins!"
var round_text: String = "Veli thinks he's won Round %d!" % current_round if veli_beat_simonka else winner_name + " wins Round %d!" % current_round

if veli_beat_simonka:
```

### 8. Verify no remaining references (if replacing)

```bash
grep -r "OldName\|oldname" --include="*.gd" --include="*.tscn" --include="*.tres"
```

Any hits in `.gd`/`.tscn`/`.tres` files need fixing. Hits in old asset `.import` files and `oldname_sprite_frames.tres` are harmless.
