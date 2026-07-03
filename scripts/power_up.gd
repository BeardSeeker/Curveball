class_name PowerUp
extends Area2D

## A floating, collectable power-up. Ownership is decided by the arena (the
## player whose bar last hit the ball gets it). The arena connects to
## `body_entered` and queues this free on pickup. Power-ups are "on-use": the
## owning player stores it and activates it later with their activation key.
##
## It also acts as a weak magnet: joining the "gravity_rocks" group makes the
## ball's gravity pass pull toward it, so a shot aimed near the pickup gets
## reeled in instead of grazing past.

enum Kind { EXTRA_LIFE, SHRINK, REVERSE, GHOST }

@export var kind: Kind = Kind.EXTRA_LIFE
## Magnet field: half a gravity rock's pull (rock: 170 / 2200).
@export var influence_radius: float = 170.0
@export var strength: float = 1100.0

const RADIUS := 26.0
## Matches the CircleShape2D in power_up.tscn (3x the visual core).
const PICKUP_RADIUS := 78.0


func _ready() -> void:
	add_to_group("power_ups")
	add_to_group("gravity_rocks")
	queue_redraw()


static func kind_label(k: int) -> String:
	match k:
		Kind.EXTRA_LIFE:
			return "Extra Life"
		Kind.SHRINK:
			return "Shrink Foe"
		Kind.REVERSE:
			return "Reverse Foe"
		Kind.GHOST:
			return "Ghost Ball"
	return "?"


func _kind_color() -> Color:
	match kind:
		Kind.EXTRA_LIFE:
			return Color(0.3, 0.9, 0.45)
		Kind.SHRINK:
			return Color(0.95, 0.35, 0.6)
		Kind.REVERSE:
			return Color(0.95, 0.8, 0.25)
		Kind.GHOST:
			return Color(0.7, 0.75, 0.88)
	return Color.WHITE


func _kind_glyph() -> String:
	match kind:
		Kind.EXTRA_LIFE:
			return "+"
		Kind.SHRINK:
			return "S"
		Kind.REVERSE:
			return "R"
		Kind.GHOST:
			return "G"
	return "?"


func _draw() -> void:
	var tint := _kind_color()
	# Magnet field, then pickup zone, so players can read both ranges.
	draw_circle(Vector2.ZERO, influence_radius, Color(tint.r, tint.g, tint.b, 0.05))
	draw_arc(Vector2.ZERO, influence_radius, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, 0.22), 2.0)
	draw_circle(Vector2.ZERO, PICKUP_RADIUS, Color(tint.r, tint.g, tint.b, 0.14))
	draw_arc(Vector2.ZERO, PICKUP_RADIUS, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.45), 2.5)
	draw_circle(Vector2.ZERO, RADIUS, _kind_color())
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.85), 3.0)
	var font := ThemeDB.fallback_font
	var font_size := 30
	var glyph := _kind_glyph()
	var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(-glyph_size.x / 2.0, font_size * 0.38), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.1, 0.1, 0.12))
