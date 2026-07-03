extends Node2D

## A gravitational obstacle. It does not collide with the ball; instead, while a
## ball is within `influence_radius`, the ball script pulls itself toward this
## rock each physics frame, curving the ball's path without changing its speed.
## The ball reads every node in the "gravity_rocks" group, so this just needs to
## register itself and expose `influence_radius` / `strength`.
##
## A NEGATIVE strength makes it a repulsor: the same field pushes the ball away,
## acting like an invisible bumper to bank shots around. Drawn teal so players
## can tell the two apart at a glance.

@export var influence_radius: float = 170.0
@export var strength: float = 2200.0

const CORE_RADIUS := 26.0


func _ready() -> void:
	add_to_group("gravity_rocks")
	queue_redraw()


func _draw() -> void:
	var repel := strength < 0.0
	var field := Color(0.2, 0.8, 0.7, 0.08) if repel else Color(0.5, 0.3, 0.9, 0.08)
	var ring := Color(0.25, 0.9, 0.8, 0.30) if repel else Color(0.6, 0.4, 1.0, 0.30)
	var core := Color(0.16, 0.72, 0.62) if repel else Color(0.5, 0.28, 0.82)
	var inner := Color(0.75, 1.0, 0.92) if repel else Color(0.82, 0.62, 1.0)
	# Faint field of influence so players can read where the pull/push is.
	draw_circle(Vector2.ZERO, influence_radius, field)
	draw_arc(Vector2.ZERO, influence_radius, 0.0, TAU, 64, ring, 2.0)
	# Solid-looking core.
	draw_circle(Vector2.ZERO, CORE_RADIUS, core)
	draw_circle(Vector2.ZERO, CORE_RADIUS * 0.5, inner)
