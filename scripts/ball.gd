extends RigidBody2D

const START_SPEED := 600.0
const RAMP_CAP := 800.0
const RAMP_STEP := 100.0
## Past the cap the rally keeps creeping up so it can't stall forever.
const CREEP_STEP := 10.0
const CHARGE_BONUS := 50.0
const RADIUS := 16.0
## Weak permanent pull toward the arena center so the ball can't settle into a
## rim-hugging orbit; it keeps re-crossing contested space.
const CENTER_PULL := 130.0
## Spin imparted by a moving bar decays so a curved shot straightens back out.
const SPIN_DECAY := 1.5

const COLOR_LEFT := Color(0.3, 0.7, 1.0)
const COLOR_RIGHT := Color(1.0, 0.35, 0.3)

## The rally ramps up: 600 -> 700 -> 800 on the first two correct hits, then
## +CREEP_STEP per hit. Resets to START_SPEED each round.
var rally_speed := START_SPEED
## Charger pads add +50 each, cleared on the next correct bar hit.
var charge_bonus := 0.0
## Effective target speed the physics renormalizes to each tick.
var current_speed := START_SPEED
## Curvature (rad/s) imparted by a moving bar; bends the flight path.
var spin := 0.0
## Set by the arena; used for the center pull.
var arena_center := Vector2.ZERO

var _ghost_time := 0.0

## Which player must hit this ball next ("left" or "right"); drives the colour.
var pending_side := "left":
	set(value):
		pending_side = value
		queue_redraw()


func _ready() -> void:
	linear_damp = 0.0
	angular_damp = 0.0
	freeze = true
	add_to_group("balls")


func _process(delta: float) -> void:
	if _ghost_time > 0.0:
		_ghost_time -= delta
		if _ghost_time <= 0.0:
			show()


func _draw() -> void:
	var color := COLOR_LEFT if pending_side == "left" else COLOR_RIGHT
	draw_circle(Vector2.ZERO, RADIUS, color)
	# Charged ball gets an orange ring until the next correct hit spends it.
	if charge_bonus > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 24, Color(1.0, 0.72, 0.15), 4.0)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var velocity: Vector2 = state.linear_velocity
	var origin: Vector2 = state.transform.origin
	# Gravitational rocks bend the path: add a pull toward each rock in range,
	# then renormalize so the curve changes direction but not speed.
	for rock in get_tree().get_nodes_in_group("gravity_rocks"):
		var offset: Vector2 = rock.global_position - origin
		var dist := offset.length()
		if dist > 1.0 and dist < rock.influence_radius:
			velocity += offset.normalized() * rock.strength * state.step
	# Whirlpool currents push tangentially while inside their band.
	for pool in get_tree().get_nodes_in_group("whirlpools"):
		velocity += pool.flow_at(origin) * state.step
	velocity += (arena_center - origin).normalized() * CENTER_PULL * state.step
	# Bar-imparted spin curves the flight, fading out over time.
	velocity = velocity.rotated(spin * state.step)
	spin *= exp(-SPIN_DECAY * state.step)
	if velocity.length() > 0.001:
		state.linear_velocity = velocity.normalized() * current_speed


## Serve toward the first hitter: anywhere in a 90-degree cone centered on
## `toward_angle` (the pending player's bar), never away from them.
func launch(toward_angle: float) -> void:
	freeze = false
	var angle := toward_angle + randf_range(-PI / 4.0, PI / 4.0)
	linear_velocity = Vector2.from_angle(angle) * current_speed


func reset_to_center(reset_position: Vector2) -> void:
	freeze = true
	rally_speed = START_SPEED
	charge_bonus = 0.0
	spin = 0.0
	_ghost_time = 0.0
	show()
	_update_speed()
	# While frozen the body is static, so the node transform is authoritative;
	# writing the transform through PhysicsServer2D gets overwritten by it.
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = reset_position
	reset_physics_interpolation()


## A correct bar hit ramps the rally speed and spends any charge.
func register_hit() -> void:
	if rally_speed < RAMP_CAP:
		rally_speed = minf(rally_speed + RAMP_STEP, RAMP_CAP)
	else:
		rally_speed += CREEP_STEP
	charge_bonus = 0.0
	_update_speed()


## Offset aiming + motion curve, applied by the arena on a correct hit.
func redirect(direction: Vector2, new_spin: float) -> void:
	linear_velocity = direction.normalized() * current_speed
	spin = new_spin


## Charger pad: +50 speed until the next correct bar hit.
func apply_charge() -> void:
	charge_bonus += CHARGE_BONUS
	_update_speed()


## Ghost Ball power-up: the ball disappears for `duration` seconds.
func apply_ghost(duration: float) -> void:
	_ghost_time = duration
	hide()


func _update_speed() -> void:
	current_speed = rally_speed + charge_bonus
	queue_redraw()
