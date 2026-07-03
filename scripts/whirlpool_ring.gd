extends Node2D

## A permanent annular current at mid-radius: while the ball is inside the
## band it gets a tangential push, so every crossing shot curves with (or
## fights) the flow. The ball reads every node in the "whirlpools" group and
## adds `flow_at(position)` to its velocity each physics frame; renormalization
## keeps the "direction, never speed" rule.

@export var inner_radius: float = 500.0
@export var outer_radius: float = 700.0
@export var strength: float = 600.0
@export var clockwise: bool = true

const ARROW_COUNT := 10
const ARROW_COLOR := Color(0.75, 0.82, 0.95, 0.22)
const BAND_COLOR := Color(0.6, 0.7, 0.9, 0.05)
## How fast the arrow marks drift around the ring (rad/s), purely visual.
const DRIFT_SPEED := 0.25

var _time := 0.0


func _ready() -> void:
	add_to_group("whirlpools")


## Tangential push (px/s^2) the current applies at `pos`; zero outside the band.
func flow_at(pos: Vector2) -> Vector2:
	var offset := pos - global_position
	var dist := offset.length()
	if dist < inner_radius or dist > outer_radius:
		return Vector2.ZERO
	var turn := PI / 2.0 if clockwise else -PI / 2.0
	return offset.normalized().rotated(turn) * strength


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var mid := (inner_radius + outer_radius) / 2.0
	draw_arc(Vector2.ZERO, mid, 0.0, TAU, 128, BAND_COLOR, outer_radius - inner_radius)
	draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 96, Color(ARROW_COLOR, 0.10), 2.0)
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 96, Color(ARROW_COLOR, 0.10), 2.0)
	# Drifting chevrons show the flow direction.
	var drift := _time * DRIFT_SPEED * (1.0 if clockwise else -1.0)
	for i in ARROW_COUNT:
		var a := TAU * i / ARROW_COUNT + drift
		var p := Vector2.from_angle(a) * mid
		var tangent := Vector2.from_angle(a).rotated(PI / 2.0 if clockwise else -PI / 2.0)
		var radial := Vector2.from_angle(a)
		var tip := p + tangent * 20.0
		draw_line(tip - tangent * 32.0 + radial * 14.0, tip, ARROW_COLOR, 3.0)
		draw_line(tip - tangent * 32.0 - radial * 14.0, tip, ARROW_COLOR, 3.0)
