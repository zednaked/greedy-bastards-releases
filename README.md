# Greedy Bastards

Arena melee FPS em Godot 4. Lute contra hordas infinitas de goblins com uma espada. Jogue sozinho ou com até 3 amigos em co-op. Cada wave traz inimigos mais rápidos, mais duros e com novos comportamentos. Sobreviva o máximo que conseguir.

---

## Controles

| Ação | Input |
|---|---|
| Mover | WASD |
| Pular | Espaço |
| **Atacar (flick)** | Mover o mouse rápido |
| **Atacar (click)** | LMB — combo de até 3 hits |
| **Bloquear / Aparar** | Segurar RMB |
| **Dash** | Duplo toque em qualquer direção |
| Arremessar espada | RMB enquanto empunha |
| Pegar item / Abrir baú | E |
| Pausar | Esc |

> **Flick:** mova o mouse com velocidade para atacar — a direção determina o tipo de swing (horizontal, vertical, diagonal). **Click:** LMB executa ataques rápidos encadeáveis em combo de até 3 hits.

---

## Sistemas de Jogo

### Combate

- **Flick attack:** janela de 80ms, acúmulo de movimento > 12px com pico 3× acima da média
- **Click attack:** LMB enquanto parado — combo de até 3 hits encadeados
- **Hitstop:** 65ms no hit normal, 105ms no parry, 130ms no kill
- **Parry:** bloquear no momento exato do ataque inimigo — projeta o inimigo com knockback extra e causa o efeito de cower (medo)
- **Lunge:** o ataque empurra o jogador para frente (5.0 força base)
- **Combo:** hits consecutivos aumentam o contador; 2+ combo + kill ativa o Vampirismo (se desbloqueado)
- **Arremessar espada:** jogador fica desarmado (dano dobrado recebido) até recuperar a arma

### Co-op Multiplayer

- Até **4 jogadores** via rede local ou internet (porta 7777)
- No menu inicial: **Hospedar Jogo** ou **Entrar** (digitar IP)
- O host inicia a partida quando todos estiverem prontos
- Inimigos miram no jogador mais próximo
- Jogadores remotos aparecem como **névoa etérea** com a espada real — a cor da névoa reflete a vida do jogador (azul = cheio, amarelo = meio, vermelho = crítico)

### Waves

| Wave | Goblins | Novidades |
|---|---|---|
| 1 | 3 | Goblins básicos |
| 2 | 5 | Líderes podem aparecer, berserk no último vivo |
| 3 | 7 | — |
| 4+ | até 9 | Arqueiros ranged, 3 atacantes simultâneos |
| 6+ | até 9 | Bombers |
| 8+ | até 9 | Trappers, goblins com +1 HP |
| 9+ | até 9 | Goblins causam 2 de dano |
| 12+ | até 9 | Goblins com +2 HP |

Cada wave encerra quando todos os inimigos morrem → baú aparece no centro → fase de upgrade → próxima wave.

### Inimigos

| Tipo | Comportamento |
|---|---|
| **Básico** | Persegue, circunda, finge ataques (feint), recua se ferido |
| **Ranged** | Mantém distância (7-16m), arremessa projéteis em arco |
| **Bomber** | Lança bombas com 2.2s de detonação ou ao tocar o chão, raio 3m |
| **Trapper** | Planta armadilhas de espinhos quase invisíveis (alpha 0.15) |
| **Líder** | Shader dourado, morte afeta moral dos aliados (rage ou cower) |
| **Berserk** | Último vivo — fica mais rápido e agressivo, grita frases |
| **Rage** | Aliado morreu perto → shader vermelho de veias, velocidade e dano aumentados |
| **Howler** | Grita guerra (cooldown 15-30s) bufando aliados em raio de 8m |

**IA com 26+ subsistemas ativos por inimigo:** token pool de ataque (max 2-3 simultâneos), circling, feint, retreat, jump attack, guard stance, pack awareness, flanking coordenado, sistema de falas procedural com estilo por emoção.

### Upgrades (baú entre waves)

| ID | Nome | Efeito | Custo |
|---|---|---|---|
| `heal` | Poção de Vida | +2 HP | 3 moedas |
| `max_hp` | Vida Extra | +1 HP máximo, cura total | 8 moedas |
| `atk_speed` | Fúria | Ataques 15% mais rápidos | 5 moedas |
| `knockback` | Força Bruta | +25% knockback | 5 moedas |
| `dash_cd` | Agilidade | Dash recarrega 0.12s mais rápido | 4 moedas |
| `iframes` | Reflexos | +0.3s de invencibilidade | 4 moedas |
| `lunge` | Investida | +3.0 força de avanço no ataque | 3 moedas |
| `bloodlust` | Vampirismo | Kill com 2+ combo restaura 1 HP | 6 moedas |
| `magnet` | Ganância | Raio de coleta de moedas ×3 | 2 moedas |
| `armor` | Armadura | Dano sem arma reduzido 1.5× | 7 moedas |

3 upgrades aleatórios por wave. Se HP ≤ 1, Poção de Vida é garantida na oferta.

### Movimentação

- Velocidade: 5.0 m/s, aceleração no chão 60 / ar 18
- **Coyote time:** 0.12s após sair de plataforma ainda pode pular
- **Jump buffer:** input buffering 0.12s antes de tocar o chão
- **Dash:** 18 m/s por 0.18s, cooldown 0.7s, spike de FOV 90°→118°
- Head bob, weapon sway, camera lean no strafe, trauma de câmera por dano

---

## Arquitetura

### Cena principal (`scenes/main.tscn`)

```
Root
├─ Arena          → chão + iluminação (instances scenes/arena/arena.tscn)
├─ Player         → FPS CharacterBody3D (scenes/player/player.tscn)
├─ EnemySpawner   → Node3D, scripts/enemies/enemy_spawner.gd
├─ Props          → cages + obstáculos estáticos
├─ HUD            → CanvasLayer, scripts/hud.gd
└─ PostProcess    → quad com post_process.gdshader
```

### Scripts

| Script | Tipo | Responsabilidade |
|---|---|---|
| `scripts/player/player_controller.gd` | `CharacterBody3D` | Movimento, dash, HP, upgrades, sync multiplayer, ghost body |
| `scripts/player/sword_attack.gd` | `Node3D` (WeaponPivot) | Flick/click attack, hitbox, block/parry, lunge, weapon throw; desativado em peers remotos |
| `scripts/enemies/enemy_controller.gd` | `CharacterBody3D` | IA completa, 26+ subsistemas, animação procedural, puppet mode em clientes |
| `scripts/enemies/enemy_spawner.gd` | `Node3D` | Wave state machine, spawn, scaling, chest/upgrade flow; server-authoritative |
| `scripts/enemies/projectile.gd` | `Area3D` | Projétil arcing do ranged goblin |
| `scripts/enemies/bomb.gd` | `RigidBody3D` | Bomba com fusível, explosão em raio, FX |
| `scripts/hud.gd` | `CanvasLayer` | HP pips, kill counter, combo, wave announce, vignettes |
| `scripts/ui/title_overlay.gd` | `CanvasLayer` | Título + lobby multiplayer (hospedar/entrar/iniciar) |
| `scripts/ui/upgrade_panel.gd` | `Control` | Cards de upgrade com categoria/cor/ícone, animação escalonada |
| `scripts/ui/defeat_screen.gd` | `Control` | Tela de derrota com stats e entrada dramática sequencial |
| `scripts/ui/pause_screen.gd` | `Control` | Pause com slide animation |
| `scripts/fx/screen_fx.gd` | `CanvasLayer` | Vinhetas, flashes, chromatic aberration, trauma |
| `scripts/network_manager.gd` | **AutoLoad** | ENet host/join, spawn de jogadores via RPC, lifecycle de peers |
| `scripts/arena_walls.gd` | `Node3D` | Boundary da arena, reposiciona inimigos que saem |

### Shaders

| Shader | Efeito |
|---|---|
| `shaders/goblin_rim.gdshader` | Rim base laranja; veias vermelhas em rage; sparkles dourados em líder |
| `shaders/sword_glow.gdshader` | Rim azul-branco fresnel + pulso de emissão durante ataque |
| `shaders/post_process.gdshader` | Chromatic aberration, sharpening, vignette, film grain, hit flash |
| `shaders/floor_wet.gdshader` | Poças procedurais (Voronoi dual-freq), manchas de sangue, especular molhado |
| `shaders/ghost_player.gdshader` | Rim fresnel + drift animado de névoa para jogadores remotos |

### Grupos

| Grupo | Usado por |
|---|---|
| `"player"` | `enemy_controller` para localizar o alvo mais próximo |
| `"enemies"` | Hitbox de espada, spawner (contagem de vivos), cache de IA |
| `"hud"` | `enemy_controller._die()` chama `register_kill()` |
| `"spawner"` | NetworkManager / HUD para localizar o spawner |
| `"block_spawn"` | Props que bloqueiam spawn de inimigos dentro de 3.5m |

### Multiplayer

**Listen server** — host joga e serve simultaneamente. Single player inalterado (`is_multiplayer_authority()` retorna true para todos os nós sem peer configurado).

- Lógica de inimigos roda **exclusivamente no servidor**; clientes recebem posição via RPC a ~15Hz
- Posição do jogador sincronizada a 20Hz via `unreliable_ordered`
- Jogadores remotos renderizados como névoa etérea: 3 emissores de partículas volumétricas + modelo real da arma com `ghost_player.gdshader`
- Cor da névoa reflete vida em tempo real (cyan → amarelo → vermelho)
- `MAX_CLIENTS = 3` → 4 jogadores total, porta 7777

### GameManager (AutoLoad)

Singleton que persiste entre cenas:
- `kills`, `wave`, `coins` — stats da run passados para tela de derrota

---

## Build

Requer **Godot 4.3+** com templates de exportação instalados.

Exportar via **Project → Export** no editor Godot. Binários disponíveis em [greedy-bastards-releases](https://github.com/zednaked/greedy-bastards-releases/releases).

---

## Créditos

Por **ZeD** — convertido de um protótipo Unity VR para FPS de arena Godot 4.
