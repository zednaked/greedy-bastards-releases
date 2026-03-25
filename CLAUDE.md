# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Greedy Bastards** — Arena melee FPS in Godot 4. Player fights endless spawning goblins with a sword. Co-op multiplayer for up to 4 players. Converted from a Unity VR project. No VR, standard keyboard+mouse FPS.

## Development

Open `project.godot` in Godot 4.3+. No CLI build commands — use the Godot Editor. Run with F5 (Play) or F6 (Play current scene).

### Regra: Multiplayer-first

**Toda feature nova deve funcionar em multiplayer desde a implementação inicial.** Não existe "adiciono MP depois".

Para cada novo sistema, considerar:
- Authority guards onde necessário: `if not is_multiplayer_authority(): return`
- Estado relevante sincronizado via RPC
- Código exclusivo de rede guardado por `NetworkManager.is_multiplayer_session`
- O que o servidor precisa executar vs o que os clientes precisam receber

**Main scene**: `scenes/main.tscn`
**Input map**: W/A/S/D movement, Space jump, double-tap dash, RMB throw/block, E interact (weapon pickup), Escape pause/cursor release. Attack is triggered by mouse flick, not a button.

## Architecture

### Scene tree (`scenes/main.tscn`)
- `Arena` — static floor + lighting (instances `scenes/arena/arena.tscn`)
- `Player` — FPS character (instances `scenes/player/player.tscn`)
- `EnemySpawner` — Node3D with `enemy_spawner.gd`
- `Props` — static cages and obstacles
- `HUD` — CanvasLayer with HP, kill counter, combo, wave announcer
- `PostProcess` — fullscreen quad with `post_process.gdshader`

### Scripts

| Script | Node type | Purpose |
|---|---|---|
| `scripts/player/player_controller.gd` | `CharacterBody3D` | WASD+mouse FPS movement, dash, HP, upgrades, multiplayer authority guards, ghost body for remote players |
| `scripts/player/sword_attack.gd` | `Node3D` (WeaponPivot) | Mouse-flick/click attack, block/parry, lunge, weapon throw/recall/detonate; disabled for non-authority players |
| `scripts/enemies/enemy_controller.gd` | `CharacterBody3D` | Full AI (26+ subsystems), procedural animation, puppet mode for multiplayer clients |
| `scripts/enemies/enemy_spawner.gd` | `Node3D` | Wave state machine, spawn, difficulty scaling, chest/upgrade flow; server-authoritative in multiplayer |
| `scripts/enemies/projectile.gd` | `Area3D` | Arcing projectile from ranged goblin |
| `scripts/enemies/bomb.gd` | `RigidBody3D` | Bomb with fuse, area explosion, FX |
| `scripts/hud.gd` | `CanvasLayer` | HP pips, kill counter, combo, wave announce, vignettes |
| `scripts/ui/title_overlay.gd` | `CanvasLayer` | Title screen embedded in main.tscn; multiplayer lobby (host/join/start) |
| `scripts/ui/upgrade_panel.gd` | `Control` | Upgrade cards between waves |
| `scripts/ui/defeat_screen.gd` | `Control` | Defeat screen with run stats |
| `scripts/ui/pause_screen.gd` | `Control` | Pause menu |
| `scripts/fx/screen_fx.gd` | `CanvasLayer` | Vignettes, flashes, chromatic aberration, trauma |
| `scripts/network_manager.gd` | **AutoLoad** | ENet host/join, player spawning via RPC, peer lifecycle; `is_multiplayer_session` flag guards all MP-specific code |
| `scripts/arena_walls.gd` | `Node3D` | Arena boundary, repositions enemies that escape |
| `scripts/weapon_pickup.gd` | `Node3D` | World weapon pickup |
| `scripts/economy/chest.gd` | `Node3D` | Chest spawned between waves; opens on interact, triggers upgrade panel |
| `scripts/economy/coin.gd` | `Area3D` | Coin dropped by enemies; auto-collects within player's `coin_collect_radius` |
| `scripts/enemies/spike_trap.gd` | `Area3D` | Spike trap planted by trapper goblin; low alpha, damages player on contact |
| `scripts/enemies/poison_bomb.gd` | `Node3D` | Poison bomb projectile (gas bomber variant); spawns `poison_cloud` on impact |
| `scripts/enemies/poison_cloud.gd` | `Area3D` | Lingering poison cloud; applies damage over time to players inside |
| `scripts/props/health_potion.gd` | `Node3D` | Health potion prop; restores 2 HP on pickup, respawns after 20s |
| `scripts/props/ground_spike.gd` | `Area3D` | Static ground spike obstacle; damages and pushes player on contact |
| `scripts/fx/blood_decal.gd` | `Decal` | Auto-frees blood decals after 30s |

### Shaders

| Shader | Effect |
|---|---|
| `shaders/goblin_rim.gdshader` | Rim base orange; red energy veins in rage; gold sparkles for leader |
| `shaders/sword_glow.gdshader` | Blue-white fresnel rim + emission pulse during attack |
| `shaders/post_process.gdshader` | Chromatic aberration, sharpening, vignette, film grain, hit flash |
| `shaders/floor_wet.gdshader` | Procedural puddles (dual-freq Voronoi), blood stains, wet specular |
| `shaders/ghost_player.gdshader` | Rim fresnel + animated UV drift for remote player ghost bodies |

### Groups

| Group | Used by |
|---|---|
| `"player"` | `enemy_controller` to locate nearest player target |
| `"enemies"` | Sword hitbox, spawner (alive count), AI caches |
| `"hud"` | `enemy_controller._die()` calls `register_kill()` |
| `"spawner"` | NetworkManager / HUD to locate spawner node |
| `"block_spawn"` | Props that block enemy spawns within 3.5m |
| `"chest"` | `chest.gd` self-registers; used by player to detect interactable chests |
| `"coins"` | `coin.gd` self-registers; used by player to auto-collect nearby coins |

### Combat flow
1. Mouse flick/click detected → `_trigger_attack()` determines swing type from direction
2. Tween animates `SwordMesh`, `SwordHitbox` (Area3D) enabled during swing
3. `SwordHitbox.body_entered` → `body.take_hit(direction * knockback_force)`
4. In multiplayer: client sends `rpc_id(1, "rpc_take_hit", ...)` to server for validation; server calls `take_hit` and routes damage back to owning peer via `rpc_take_damage`
5. `enemy_controller.take_hit()` decrements HP, applies knockback; at 0 HP → `_die()`
6. `_die()` disables collision, tweens scale to zero, notifies HUD via `"hud"` group, `queue_free()`

### Multiplayer architecture

**Listen server** — host plays and serves simultaneously. Single player is unchanged because `multiplayer.is_server()` and `is_multiplayer_authority()` both return true with no peer set.

Key patterns:
- All MP-specific code guarded by `NetworkManager.is_multiplayer_session`
- `set_multiplayer_authority(peer_id)` determines which peer owns each player node
- Enemy AI runs **server-only**; clients receive position/health via `_net_receive_enemy_state` RPC at ~15Hz
- Player position synced at 20Hz via `unreliable_ordered` RPC
- Enemy names `Enemy_N` are consistent across all peers for RPC routing
- Remote players rendered as ghost bodies: volumetric mist particles (3 layered emitters) + real weapon model with `ghost_player.gdshader`; particle color reflects health ratio (cyan → yellow → red)

**NetworkManager constants:**
- `PORT = 7777`
- `MAX_CLIENTS = 3` (host + 3 = 4 players total)

### GameManager (AutoLoad)

Persists between scenes:
- `kills`, `wave`, `coins` — run stats passed to defeat/victory screens

### Assets (`assets/`)
- `models/goblin.fbx` + `Goblins 2.fbx` — goblin models (import scale `0.01`)
- `models/Sword_01.fbx` — primary weapon; Ax, Dagger, Hammer, etc. available
- `models/Arena.blend` — arena environment (**requires Blender** for Godot importer)
- `textures/Goblin.Texture.png` — goblin albedo
- `textures/blood/blood1-7.png` — blood decal textures

### Arena.blend import note
Set Blender path in `Editor > Editor Settings > FileSystem > Import > Blender > Blender Path`. After import, enable collision on floor mesh or add `StaticBody3D` + `BoxShape3D` manually.

### FBX scale
Goblin and weapon FBX files need scale `0.01` in the Import dock after first import.
