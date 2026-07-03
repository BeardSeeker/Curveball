# Curveball - Design Notes

## Pitch

A multiplayer arena game built around one signature idea: turn-based rallies
on a shared circular table, where curve - imparted by moving paddles and by
gravity obstacles - is the core skill. Players compete across maps whose
identity comes from their layout and mechanics:

- **Obstacles** - geometry and fields that change ball trajectories
  (gravity rocks, charger pads; more types planned)
- **Interactable terrain** - elements players or balls can affect during
  play (planned: switches, gates, holes/traps, conveyor sections)
- **Power-ups** - collectable, on-use modifiers (extra life, debuffs for
  the opponent, ball effects)

## Modes

| Mode     | Players    | Teams | Status                        |
|----------|------------|-------|-------------------------------|
| 1v1      | 2 (local)  | Solo  | Implemented                   |
| 1 vs AI  | 1          | Solo  | Implemented (3 difficulties)  |
| 1v1v1    | 3          | Solo  | Planned                       |
| 2v2      | 4          | Teams | Planned                       |
| 1v1v1v1  | 4          | Solo  | Planned                       |

## Core Rules (implemented, 1v1 / 1 vs AI)

The arena is a circle with no walls. Both bars ride the outer rim as concave
arcs matching the circle's curve. Players are identified by colour: **Blue**
(left player, A/D + R) and **Red** (right player, arrow keys + Q; the AI in
1 vs AI). Esc pauses.

- **Turn-based hitting**: the ball is tinted the colour of the player who
  must hit it next; a correct hit passes the turn (and the tint) to the
  other player. Each player can only touch the ball once per exchange.
- **Fouls**: touching the ball out of turn is a foul (the ball still
  bounces). 2 fouls in a round count as a goal against you. Fouls reset
  every round.
- **Lives**: 3 each. A ball that escapes the circle costs a life to the
  player whose turn it was. Losing a life resets the round (3-2-1
  countdown); first hitter alternates between rounds.
- **Serve rule**: the opening launch is confined to a 90-degree cone
  centered on the receiving player's bar - the first hitter is never
  served away from.

### Ball physics

- Speed is constant per flight and renormalized every tick; obstacles and
  spin change *direction*, never speed.
- **Escalation**: starts each round at 600 px/s, +100 per correct hit up
  to 800, then +10 per hit forever. Every 10th hit shrinks both bars one
  step (visible as a pulsating flash), so long rallies always break.
- A weak center gravity keeps the ball re-crossing the middle so it cannot
  orbit the rim.

### Bars

- Slide along the rim at 2.0 rad/s; they physically block each other and
  **shove**: pressing into the other bar knocks it back (~0.45 rad), then
  the shove goes on a 1.2 s cooldown.
- **Offset aiming**: where the ball lands on the arc tilts the return
  angle, up to ~52 degrees at the tips; hitting while moving imparts
  decaying curve (spin) - the title mechanic.
- **Shrinking**: one step = -10% of full size (-1% once at/below 10%,
  never below 5%). Sources: rally escalation (permanent for the round)
  and the Shrink power-up (until the victim's next correct hit).

### Reading the game

- **Landing marker**: a rim marker in the pending player's colour shows
  the ball's straight-line exit point. Curve, gravity rocks, the
  whirlpool ring, and the Ghost power-up can all make it lie. (Shared screen: both players see
  it; per-player visibility becomes possible with networking.)

### Obstacles and power-ups

- 3 obstacles (each an even roll: charger / gravity rock / repulsor) + 1
  floating power-up; the whole set is replaced every 30 s and after every
  lost life (the timer restarts on a life loss).
- **Gravity rock** (purple): no collision; bends any ball inside its
  influence radius toward it.
- **Repulsor rock** (teal): the same field inverted - pushes the ball
  away, an invisible bumper to bank shots around. Implemented as a
  gravity rock with negative strength.
- **Charger pad**: pass-through; +50 speed (stacking, orange ring on the
  ball) until the next correct hit spends it.
- **Whirlpool ring**: permanent terrain, not part of the swap - an
  annular current at mid-radius (500-700 px) that pushes any ball inside
  the band clockwise (~20 deg of bend per radial crossing). Shots curved
  with the current whip around; shots against it hang. Drawn as a faint
  band with drifting chevrons.
- **Power-ups** (collected by the ball for whoever last hit it; 1 slot;
  activate with R / Q): Extra Life, Shrink Foe, Reverse Foe (controls
  inverted until their next hit), Ghost Ball (ball invisible for 1 s).
  The pickup zone is 3x the visual core and each power-up is a weak
  magnet (half a gravity rock's pull) that reels nearby shots in, so
  deliberately aiming at a pickup usually succeeds.

### 1 vs AI

Same arena (`arena_1vai` inherits `arena_1v1`); the Red bar is an
interception AI. Difficulty (Easy / Medium / Hard, picked on the
mode-select screen) tunes reaction time, aim noise, movement speed,
edge-shot aggression, and item usage; Hard times its debuffs to the
player's turn.
The AI predicts straight lines only, so player-imparted curve and
gravity rocks genuinely fool it - beating harder AIs is a lesson in
using the curve mechanics.

## Arena Templates

- `arena_1v1` - circular (radius 1275 on a 3600x2700 field), both bars on
  the rim, angular movement. The flagship template.
- `arena_1vai` - inherited from `arena_1v1`, right bar AI-driven.
- `arena_1v1v1` (planned) - the circle scales naturally to 3 players: the
  turn rule becomes a colour queue, elimination can shrink the circle.
- `arena_2v2`, `arena_1v1v1v1` (planned) - originally rectangular designs;
  under reconsideration now that the circular arena is the game's
  identity (e.g. 2v2 as alternating teammates on the same rim).

Each template has fixed sizes shared across all maps that use it; a map is
a template + size + its own layer of obstacles/terrain/power-ups.

## Other Decisions

- **Camera**: single shared view of the whole table (zoomed-out Camera2D).
- **Elimination** (3-4 player modes, planned): when a player runs out of
  lives they are removed from the turn queue; prefer shrinking the arena
  over sealing walls to keep endgames fast.
- **Networking** (planned): listen server (one player hosts and plays),
  Godot `MultiplayerAPI` over ENet. Max 4 players, no dedicated servers.
  Enables per-client landing markers.
- **Audio**: all SFX are synthesized at startup into in-memory
  `AudioStreamWAV`s (`autoload/sfx.gd`) - zero audio assets. Hit pitch
  creeps up with the rally. Real assets (and music) can replace the
  synth streams one entry at a time later.

## Open Questions

- [ ] Bar arc width / shove strength tuning after more playtesting.
- [ ] Does the +10/hit creep need a cap in practice?
- [ ] 2v2 and 1v1v1v1 layouts: rectangular as originally planned, or
	  circle variants?

## Architecture

- `autoload/game_state.gd` - lives, match signals, AI difficulty
- `autoload/sfx.gd` - procedural synth SFX, no audio assets
- `scenes/entities/` - ball, bar, gravity rock, charger, power-up,
  whirlpool ring
- `scenes/maps/` - `arena_1v1.tscn`, `arena_1vai.tscn` (inherited)
- `scripts/arena_1v1.gd` - all match rules; `arena_ai.gd` extends it
- `scenes/ui/` - main menu, mode select (with AI difficulty), settings

## Next Steps

1. Playtest and tune (aim angle, spin strength, shove feel, AI knobs).
2. 1v1v1 on the circle: colour-queue turn order, shrinking elimination.
3. Networking (listen server) + per-client landing markers.
4. Juice pass: hit-stop, trails, screen shake (synth sound done; real
   audio assets later).
