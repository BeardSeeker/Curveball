# Curveball

A multiplayer pinball arena game built in Godot 4 (GDScript).

## Concept

Players compete on pinball-style arenas with flippers, bumpers, and other
pinball elements, but the core challenge comes from the **maps** themselves:
each map introduces different obstacles, interactable terrain, and power-ups
that change how matches play out.

## Game Modes

- 1v1
- 1v1v1
- 2v2
- 1v1v1v1

## Project Structure

```
scenes/
  main/        # boot/entry scene
  maps/        # individual arena/map scenes
  entities/    # ball, flippers, power-ups, obstacles
  ui/          # menus, HUD, lobby
scripts/       # shared/reusable scripts (non-scene-bound)
autoload/      # singletons (game state, networking, etc.)
assets/
  sprites/
  audio/
  fonts/
```

## Requirements

- Godot 4.3+ (GDScript)

## Status

Early setup — see [DESIGN.md](DESIGN.md) for design notes and open questions.
