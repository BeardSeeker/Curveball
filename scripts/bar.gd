extends CharacterBody2D

## A concave arc paddle riding the rim of the circular arena. The node sits at
## the arena center and `angle` (radians) slides it around the rim; the
## collision polygon and the drawn shape are the same annulus sector, so the
## inner face curves to match the circle.

@export var cw_action: String = "p1_cw"
@export var ccw_action: String = "p1_ccw"
@export var angular_speed: float = 2.0
@export var angle: float = 0.0
@export var inner_radius: float = 1235.0
@export var outer_radius: float = 1275.0
@export var half_arc: float = 0.175
@export var color: Color = Color(0.3, 0.7, 1.0)
## When false the bar ignores the keyboard; an AI drives it via `ai_direction`.
@export var player_controlled := true

const ARC_SEGMENTS := 16

# Shrinking: -10% of full size per step, -1% once at/below 10%, floor 5%.
const MIN_SCALE := 0.05
const SHRINK_STEP := 0.10
const SMALL_SHRINK_STEP := 0.01
const SMALL_STEP_BELOW := 0.10
const PULSE_TIME := 1.2

# Shove: pressing into the other bar knocks it back, then goes on cooldown.
const SHOVE_SPEED := 2.2
const SHOVE_DECAY := 5.5
const SHOVE_COOLDOWN := 1.2

## Set by the arena; bars block each other when their arcs would touch.
var other_bar: CharacterBody2D = null
## 1.0 = full size; shrinks from rally escalation and the Shrink power-up.
var bar_scale := 1.0
## Reverse-controls debuff; cleared when this bar makes a correct hit.
var reversed := false
## Which way the bar moved this frame (-1/0/1); gives the ball its curve.
var move_direction := 0.0
## AI steering input; fractional values scale the speed.
var ai_direction := 0.0

var _start_angle: float
var _points := PackedVector2Array()
var _pre_powerup_scale := -1.0  # restore point for the temporary power-up shrink
var _pulse_left := 0.0
var _shove_velocity := 0.0
var _shove_cooldown := 0.0


func _ready() -> void:
	_start_angle = angle
	_rebuild_shape()
	rotation = angle


func scaled_half_arc() -> float:
	return half_arc * bar_scale


func _rebuild_shape() -> void:
	_points = _arc_points()
	# Deferred: shrinks can be triggered from physics callbacks, where the
	# collision shape can't be mutated directly.
	$CollisionPolygon2D.set_deferred("polygon", _points)
	queue_redraw()


func _arc_points() -> PackedVector2Array:
	var arc := scaled_half_arc()
	var pts := PackedVector2Array()
	for i in ARC_SEGMENTS + 1:
		var t: float = lerpf(-arc, arc, float(i) / ARC_SEGMENTS)
		pts.append(Vector2.from_angle(t) * outer_radius)
	for i in ARC_SEGMENTS + 1:
		var t: float = lerpf(arc, -arc, float(i) / ARC_SEGMENTS)
		pts.append(Vector2.from_angle(t) * inner_radius)
	return pts


func _process(delta: float) -> void:
	if _pulse_left > 0.0:
		_pulse_left = maxf(_pulse_left - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var c := color
	if _pulse_left > 0.0:
		var flash := 0.5 + 0.5 * sin(_pulse_left * 25.0)
		c = color.lerp(Color.WHITE, 0.65 * flash)
	draw_colored_polygon(_points, c)


func reset_to_start() -> void:
	angle = _start_angle
	rotation = angle
	bar_scale = 1.0
	_pre_powerup_scale = -1.0
	reversed = false
	_shove_velocity = 0.0
	_shove_cooldown = 0.0
	_pulse_left = 0.0
	_rebuild_shape()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_shove_cooldown = maxf(_shove_cooldown - delta, 0.0)
	var direction := 0.0
	if player_controlled:
		if Input.is_action_pressed(cw_action):
			direction += 1.0
		if Input.is_action_pressed(ccw_action):
			direction -= 1.0
	else:
		direction = clampf(ai_direction, -1.0, 1.0)
	if reversed:
		direction = -direction
	move_direction = direction

	var delta_angle := direction * angular_speed * delta + _shove_velocity * delta
	_shove_velocity = move_toward(_shove_velocity, 0.0, SHOVE_DECAY * delta)
	if delta_angle == 0.0:
		return
	var target := wrapf(angle + delta_angle, -PI, PI)
	var clamped := _clamp_against_other(target)
	if direction != 0.0 and clamped != target and _shove_cooldown <= 0.0:
		other_bar.receive_shove(direction)
		_shove_cooldown = SHOVE_COOLDOWN
	angle = clamped
	rotation = angle


func receive_shove(direction: float) -> void:
	_shove_velocity = direction * SHOVE_SPEED
	_pulse_left = maxf(_pulse_left, 0.35)


## Bars collide when they meet: stop at the point where the two arcs touch.
func _clamp_against_other(target: float) -> float:
	if other_bar == null:
		return target
	var min_sep: float = scaled_half_arc() + other_bar.scaled_half_arc()
	var diff := wrapf(target - other_bar.angle, -PI, PI)
	if absf(diff) >= min_sep:
		return target
	var side := wrapf(angle - other_bar.angle, -PI, PI)
	var direction := 1.0 if side >= 0.0 else -1.0
	return wrapf(other_bar.angle + direction * min_sep, -PI, PI)


# --- Shrinking ---------------------------------------------------------------

## One shrink step, shared by rally escalation and the Shrink power-up.
func apply_shrink_step() -> void:
	var step := SHRINK_STEP if bar_scale > SMALL_STEP_BELOW else SMALL_SHRINK_STEP
	bar_scale = maxf(bar_scale - step, MIN_SCALE)
	_pulse_left = PULSE_TIME
	_rebuild_shape()


## Temporary shrink from the Shrink power-up; lasts until this bar's next
## correct hit (clear_powerup_shrink).
func apply_powerup_shrink() -> void:
	if _pre_powerup_scale < 0.0:
		_pre_powerup_scale = bar_scale
	apply_shrink_step()


func clear_powerup_shrink() -> void:
	if _pre_powerup_scale >= 0.0:
		bar_scale = _pre_powerup_scale
		_pre_powerup_scale = -1.0
		_rebuild_shape()


## Rally-escalation shrink is permanent for the round: it also lowers the
## power-up restore point so a temporary shrink can't undo it.
func apply_rally_shrink() -> void:
	if _pre_powerup_scale >= 0.0:
		var step := SHRINK_STEP if _pre_powerup_scale > SMALL_STEP_BELOW else SMALL_SHRINK_STEP
		_pre_powerup_scale = maxf(_pre_powerup_scale - step, MIN_SCALE)
	apply_shrink_step()
