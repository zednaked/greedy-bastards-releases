# Greedy Bastards

Arena melee FPS. Lute contra hordas infinitas de goblins com uma espada. Sem armas de fogo, sem magia — só você, uma lâmina e reflexos.

> **[⬇ Baixar última versão](../../releases/latest)**

---

## Como jogar

### Controles

| Ação | Input |
|---|---|
| Mover | WASD |
| Pular | Espaço |
| **Atacar** | Mover o mouse rápido (flick) |
| **Bloquear / Aparar** | Segurar botão direito |
| **Dash** | Duplo toque em qualquer direção WASD |
| Arremessar espada | Botão direito enquanto empunha |
| Abrir baú / Pegar item | E |
| Pausar | Esc |

### O ataque

Não há botão de ataque. Você ataca **movendo o mouse com velocidade** — como um golpe de espada de verdade. A direção do flick determina o tipo de swing:

- Horizontal → corte lateral
- Vertical → golpe de cima para baixo
- Diagonal → combinação

### Bloqueio e Parry

Segurar o botão direito levanta a espada. Se um inimigo atacar **exatamente nesse momento**, você executa um **parry** — o inimigo é projetado com força extra e entra em pânico temporário.

### Dash

Toque duas vezes na mesma direção rapidamente para dar um dash. Útil para escapar de cercamentos ou fechar distância.

---

## Progressão

Cada **wave** (onda) de goblins que você eliminar abre um **baú** no centro da arena. Gaste suas moedas em upgrades:

| Upgrade | Efeito |
|---|---|
| Poção de Vida | Recupera 2 HP imediatamente |
| Vida Extra | +1 HP máximo permanente |
| Fúria | Ataques 15% mais rápidos |
| Força Bruta | Knockback 25% mais forte |
| Agilidade | Dash recarrega mais rápido |
| Reflexos | +0.3s de invencibilidade após levar dano |
| Investida | Avanço mais forte no ataque |
| Vampirismo | Kills com combo 2+ restauram HP |
| Ganância | Moedas voam para você de longe |
| Armadura | Leva menos dano quando desarmado |

Moedas são dropadas pelos goblins ao morrer.

---

## Inimigos

Os goblins ficam mais rápidos, mais duros e mais variados a cada wave:

| Wave | Novidade |
|---|---|
| 1 | Goblins básicos — circulam, fingem ataque, recuam se feridos |
| 2 | **Líder** com shader dourado; último vivo entra em **modo berserk** |
| 4 | **Arqueiros** que mantêm distância e arremessam projéteis |
| 6 | **Bombers** com bombas de fusível (explodem após 2s ou no impacto) |
| 8 | **Trappers** que plantam armadilhas invisíveis de espinhos |
| 8+ | Goblins mais resistentes; grupos ficam com raiva ao ver aliados morrerem |

Os goblins se comunicam — morte de um aliado pode deixar outros com raiva (mais agressivos) ou com medo. O **howler** bufa aliados próximos. O **líder** coordena o grupo; sua morte afeta o moral de todos.

---

## Download

| Plataforma | Arquivo | Instruções |
|---|---|---|
| **Linux** x86_64 | `GreedyBastards-linux-x86_64.tar.gz` | Extrair → `chmod +x GreedyBastards.x86_64` → executar |
| **Windows** x86_64 | `GreedyBastards-windows-x86_64.tar.gz` | Extrair → `GreedyBastards.exe` |

Veja a aba **[Releases](../../releases)** para todas as versões.

---

## Sobre

Godot 4.6 · Jolt Physics · GDScript
Por **ZeD**
