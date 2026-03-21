# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Greedy Bastards** — Arena melee FPS in Godot 4. Player fights endless spawning goblins with a sword. Converted from a Unity VR project. No VR, standard keyboard+mouse FPS.

## Development

Open `project.godot` in Godot 4.3+. No CLI build commands — use the Godot Editor. Run with F5 (Play) or F6 (Play current scene).

**Main scene**: `scenes/main.tscn`
**Input map**: W/A/S/D movement, Space jump, RMB block, E interact (weapon pickup), Escape pause/cursor release. Attack is triggered by mouse flick, not a button.

## Architecture

### Scene tree (`scenes/main.tscn`)
- `Arena` — static floor + lighting (instances `scenes/arena/arena.tscn`)
- `Player` — FPS character (instances `scenes/player/player.tscn`)
- `EnemySpawner` — Node3D with `enemy_spawner.gd`, exports `goblin_scene`
- `HUD` — CanvasLayer with kill counter and crosshair

### Scripts

| Script | Node type | Purpose |
|---|---|---|
| `scripts/player/player_controller.gd` | `CharacterBody3D` | WASD+mouse FPS movement; `equip_weapon(name)` called by pickups |
| `scripts/player/sword_attack.gd` | `Node3D` (WeaponPivot) | Mouse-flick attack detection (80ms window), block stance (RMB), spring-damper weapon sway, hitbox window |
| `scripts/enemies/enemy_controller.gd` | `CharacterBody3D` | Follow player, 3-hit health, knockback, procedural run/idle animation, death via scale tween |
| `scripts/enemies/enemy_spawner.gd` | `Node3D` | Spawns goblins every 5s at 20-unit radius, max 20 at once |
| `scripts/hud.gd` | `CanvasLayer` | Kill counter; `register_kill()` called by `enemy_controller._die()` via `"hud"` group |
| `scripts/weapon_pickup.gd` | `Node3D` | World pickup — shows prompt label within `interact_distance`, calls `player.equip_weapon()` on E press |
| `scripts/fx/blood_decal.gd` | `Decal` | Auto-frees blood decals after 30s |

### Groups
- `"player"` — set in `player_controller.gd._ready()`
- `"enemies"` — set in `enemy_controller.gd._ready()`
- `"hud"` — must be set on the HUD node; used by `enemy_controller._die()` to call `register_kill()`

### Combat flow
1. Mouse flick detected (accumulated movement > `attack_threshold` px in 80ms window) → `_trigger_attack()` determines swing type (horizontal/vertical/diagonal) from flick direction
2. Tween animates `SwordMesh`, `SwordHitbox` (Area3D) enabled during swing
3. `SwordHitbox.body_entered` → `body.take_hit(direction * knockback_force)` on enemies in `"enemies"` group
4. `enemy_controller.take_hit()` decrements health, applies knockback velocity, sets `is_knocked` briefly; at 0 health → `_die()`
5. `_die()` disables collision, tweens scale to zero, then calls `hud.register_kill()` via `"hud"` group, then `queue_free()`

RMB hold → block stance (weapon raised, hitbox disabled during `is_blocking`)

### Assets (`assets/`)
- `models/goblin.fbx` + `Goblins 2.fbx` — goblin enemy models (import scale may need `0.01`)
- `models/Sword_01.fbx` — primary weapon; other weapons available (Ax, Dagger, Hammer, etc.)
- `models/Arena.blend` — arena environment (**requires Blender installed** for Godot's importer)
- `textures/Goblin.Texture.png` — goblin albedo texture
- `textures/blood/blood1-7.png` — blood decal textures (converted from TIF)

### Arena.blend import note
Godot imports `.blend` by invoking Blender. Set the Blender path in `Editor > Editor Settings > FileSystem > Import > Blender > Blender Path`. After import, enable collision on the floor mesh or add a `StaticBody3D` with `BoxShape3D` manually.

### FBX scale
Goblin and weapon FBX files likely need scale set to `0.01` in the Import dock after first import.
