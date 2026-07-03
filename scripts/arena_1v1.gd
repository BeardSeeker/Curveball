extends Node2D

const CENTER := Vector2(1800, 1350)
const ARENA_RADIUS := 1275.0
## A ball past this distance from the center has escaped the circle.
const ESCAPE_RADIUS := ARENA_RADIUS + 40.0
const MAX_FOULS := 2
## Ignore repeat bar contacts for the same ball within this window, so one
## physical graze can't count as two hits/fouls.
const HIT_COOLDOWN_MS := 120

# Offset aiming: the return angle tilts up to MAX_AIM_ANGLE depending on where
# along the arc the ball lands; a moving bar adds SPIN_RATE curve.
const MAX_AIM_ANGLE := 0.9
const SPIN_RATE := 1.5
## Every this many rally hits, both bars shrink a step.
const SHRINK_EVERY_HITS := 10
const GHOST_DURATION := 1.0

# Obstacle / power-up spawning.
const SWAP_INTERVAL := 30.0
const OBSTACLES_PER_CYCLE := 3
const POWERUP_KIND_COUNT := 4  # PowerUp.Kind: EXTRA_LIFE, SHRINK, REVERSE, GHOST
const SPAWN_RADIUS := 900.0
const MIN_SEPARATION := 200.0
const BALL_CLEARANCE := 260.0
const SPAWN_ATTEMPTS := 40

const ChargerScene := preload("res://scenes/entities/charger.tscn")
const GravityRockScene := preload("res://scenes/entities/gravity_rock.tscn")
const PowerUpScene := preload("res://scenes/entities/power_up.tscn")
const PowerUpScript := preload("res://scripts/power_up.gd")

@onready var ball: RigidBody2D = $Ball
@onready var left_bar: CharacterBody2D = $LeftBar
@onready var right_bar: CharacterBody2D = $RightBar
@onready var camera: Camera2D = $Camera2D
@onready var obstacle_root: Node2D = $Obstacles
@onready var swap_timer: Timer = $SwapTimer
@onready var left_lives_label: Label = $UI/LeftLives
@onready var right_lives_label: Label = $UI/RightLives
@onready var left_item_label: Label = $UI/LeftItem
@onready var right_item_label: Label = $UI/RightItem
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/VBoxContainer/ResultLabel
@onready var countdown_label: Label = $UI/CountdownLabel
@onready var pause_menu: Control = $UI/PauseMenu
@onready var pause_buttons: Control = $UI/PauseMenu/CenterContainer
@onready var pause_settings_panel: Control = $UI/PauseMenu/SettingsPanel
@onready var restart_button: Button = $UI/PauseMenu/CenterContainer/VBoxContainer/RestartButton

var _obstacles: Array[Node] = []
var _active_powerup = null

# -1 means an empty inventory slot; otherwise a PowerUp.Kind value.
var _inventory := {"left": -1, "right": -1}
var _fouls := {"left": 0, "right": 0}
var _last_hitter := ""
var _round_active := false
var _rally_hits := 0
## Who must hit the ball first this round; alternates every round.
var _first_hitter := "left"


func _ready() -> void:
	GameState.reset_match()
	_reset_powerup_state()
	camera.make_current()
	game_over_panel.visible = false
	countdown_label.visible = false
	pause_menu.visible = false
	pause_settings_panel.visible = false
	restart_button.disabled = not GameState.is_host

	GameState.life_lost.connect(_on_life_lost)
	GameState.match_over.connect(_on_match_over)

	left_bar.other_bar = right_bar
	right_bar.other_bar = left_bar
	ball.arena_center = CENTER

	ball.body_entered.connect(_on_ball_body_entered)
	ball.reset_to_center(CENTER)

	swap_timer.wait_time = SWAP_INTERVAL
	swap_timer.one_shot = false
	swap_timer.timeout.connect(_run_swap)
	swap_timer.start()
	_run_swap()

	_start_round()


func _process(_delta: float) -> void:
	# The landing marker tracks the ball every frame.
	queue_redraw()


func _draw() -> void:
	# Drawn on the root so it sits behind every child node.
	draw_rect(Rect2(0, 0, 3600, 2700), Color(0.06, 0.06, 0.08))
	draw_circle(CENTER, ARENA_RADIUS, Color(0.13, 0.13, 0.17))
	draw_arc(CENTER, ARENA_RADIUS, 0.0, TAU, 128, Color(0.35, 0.35, 0.45), 6.0)
	_draw_landing_marker()


## Rim marker where the ball is headed, tinted for the player who must hit it.
## Hidden while the ball is ghosted. (Local play shares one screen, so both
## players can see it; per-player visibility becomes possible with networking.)
func _draw_landing_marker() -> void:
	if not _round_active or ball.freeze or not ball.visible:
		return
	var hit := _predict_rim_crossing()
	if hit == Vector2.INF:
		return
	var marker_angle := (hit - CENTER).angle()
	var mcolor: Color = ball.COLOR_LEFT if ball.pending_side == "left" else ball.COLOR_RIGHT
	mcolor.a = 0.55
	draw_arc(CENTER, ARENA_RADIUS - 14.0, marker_angle - 0.06, marker_angle + 0.06, 8, mcolor, 10.0)


## Straight-line projection of the ball onto the rim circle (ignores curve, so
## it is a hint, not a promise).
func _predict_rim_crossing() -> Vector2:
	var v: Vector2 = ball.linear_velocity
	if v.length_squared() < 1.0:
		return Vector2.INF
	var p: Vector2 = ball.global_position - CENTER
	var d := v.normalized()
	var proj := p.dot(d)
	var perp_sq := p.length_squared() - proj * proj
	var r_sq := ARENA_RADIUS * ARENA_RADIUS
	if perp_sq >= r_sq:
		return Vector2.INF
	var t := -proj + sqrt(r_sq - perp_sq)
	if t < 0.0:
		return Vector2.INF
	return CENTER + p + d * t


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause_menu()
	elif event.is_action_pressed("p1_activate"):
		_activate_powerup("left")
	elif event.is_action_pressed("p2_activate"):
		_activate_powerup("right")


# --- Pause / menu -----------------------------------------------------------

func _toggle_pause_menu() -> void:
	pause_menu.visible = not pause_menu.visible
	if pause_menu.visible:
		pause_buttons.visible = true
		pause_settings_panel.visible = false
	get_tree().paused = pause_menu.visible


func _on_restart_pressed() -> void:
	if not GameState.is_host:
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_pause_settings_pressed() -> void:
	pause_buttons.visible = false
	pause_settings_panel.visible = true


func _on_pause_settings_back_pressed() -> void:
	pause_settings_panel.visible = false
	pause_buttons.visible = true


func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# --- Round flow -------------------------------------------------------------

func _start_round() -> void:
	_fouls = {"left": 0, "right": 0}
	_rally_hits = 0
	ball.pending_side = _first_hitter
	_first_hitter = _other(_first_hitter)
	_update_labels()
	await _run_countdown()
	var receiver: CharacterBody2D = left_bar if ball.pending_side == "left" else right_bar
	ball.launch(receiver.angle)
	_round_active = true


func _run_countdown() -> void:
	countdown_label.visible = true
	for count in [3, 2, 1]:
		countdown_label.text = str(count)
		Sfx.play("count")
		await get_tree().create_timer(1.0).timeout
	countdown_label.visible = false
	Sfx.play("go")


func _other(side: String) -> String:
	return "right" if side == "left" else "left"


## Players are shown by colour, never by side: left = Blue, right = Red.
func _side_name(side: String) -> String:
	return "Blue" if side == "left" else "Red"


# --- Lives (escape + fouls) --------------------------------------------------

## No walls: a ball that flies out of the circle costs a life to the player
## whose turn it was to hit it.
func _physics_process(_delta: float) -> void:
	if not _round_active:
		return
	if ball.global_position.distance_to(CENTER) > ESCAPE_RADIUS:
		_round_active = false
		GameState.lose_life(ball.pending_side)


## Touching a ball out of turn is a foul; MAX_FOULS fouls count as a goal
## against you. Fouls reset every round.
func _register_foul(side: String) -> void:
	if not _round_active:
		return
	_fouls[side] += 1
	Sfx.play("foul")
	_update_labels()
	if _fouls[side] >= MAX_FOULS:
		_round_active = false
		GameState.lose_life(side)


func _on_life_lost(side: String, _lives_left: int) -> void:
	Sfx.play("life_lost")
	_update_labels()
	if GameState.lives["left"] > 0 and GameState.lives["right"] > 0:
		ball.reset_to_center(CENTER)
		left_bar.reset_to_start()
		right_bar.reset_to_start()
		# Fresh obstacles + power-up each round; restart the 30 s cadence too.
		swap_timer.start()
		_run_swap()
		_start_round()


func _on_match_over(winner_side: String) -> void:
	_round_active = false
	swap_timer.stop()
	ball.linear_velocity = Vector2.ZERO
	ball.freeze = true
	game_over_label.text = "%s player wins!" % _side_name(winner_side)
	game_over_panel.visible = true
	Sfx.play("win")


# --- Ball / bar contact (turns, fouls, aiming, escalation) -------------------

func _on_ball_body_entered(body: Node) -> void:
	var side := ""
	if body == left_bar:
		side = "left"
	elif body == right_bar:
		side = "right"
	else:
		return

	var now := Time.get_ticks_msec()
	if now - int(ball.get_meta("last_hit_ms", -HIT_COOLDOWN_MS)) < HIT_COOLDOWN_MS:
		return
	ball.set_meta("last_hit_ms", now)

	if ball.pending_side != side:
		_register_foul(side)
		return

	var bar: CharacterBody2D = left_bar if side == "left" else right_bar

	# A correct hit passes the turn, ramps the rally, and clears this player's
	# debuffs (temporary shrink, reversed controls).
	ball.pending_side = _other(side)
	ball.register_hit()
	bar.clear_powerup_shrink()
	bar.reversed = false
	_last_hitter = side
	# Hit pitch creeps up with the rally, selling the escalation.
	Sfx.play("hit", 1.0 + minf(_rally_hits * 0.015, 0.35))

	# Offset aiming: landing near an edge of the arc tilts the return angle
	# toward that edge; a moving bar adds curve to the flight.
	var ball_angle: float = (ball.global_position - CENTER).angle()
	var offset: float = clampf(
		wrapf(ball_angle - bar.angle, -PI, PI) / maxf(bar.scaled_half_arc(), 0.01),
		-1.0, 1.0)
	var out_dir: Vector2 = (CENTER - ball.global_position).normalized().rotated(offset * MAX_AIM_ANGLE)
	ball.redirect(out_dir, bar.move_direction * SPIN_RATE)

	# Rally escalation: every SHRINK_EVERY_HITS hits, both bars shrink a step.
	_rally_hits += 1
	if _rally_hits % SHRINK_EVERY_HITS == 0:
		left_bar.apply_rally_shrink()
		right_bar.apply_rally_shrink()


# --- Power-up inventory / activation ----------------------------------------

func _reset_powerup_state() -> void:
	_inventory = {"left": -1, "right": -1}
	_last_hitter = ""


func _on_powerup_touched(body: Node, pu) -> void:
	if pu != _active_powerup:
		return
	if not body.is_in_group("balls"):
		return
	# Awarded to whoever last hit the ball; if nobody has yet, or that player's
	# slot is full, leave the power-up floating.
	if _last_hitter == "":
		return
	if _inventory[_last_hitter] != -1:
		return
	_inventory[_last_hitter] = pu.kind
	_active_powerup = null
	pu.queue_free()
	Sfx.play("pickup")
	_update_labels()


func _activate_powerup(side: String) -> void:
	if pause_menu.visible:
		return
	var kind: int = _inventory[side]
	if kind < 0:
		return
	_inventory[side] = -1
	Sfx.play("activate")
	var opponent: CharacterBody2D = right_bar if side == "left" else left_bar
	match kind:
		PowerUpScript.Kind.EXTRA_LIFE:
			GameState.gain_life(side)
		PowerUpScript.Kind.SHRINK:
			opponent.apply_powerup_shrink()
		PowerUpScript.Kind.REVERSE:
			opponent.reversed = true
		PowerUpScript.Kind.GHOST:
			ball.apply_ghost(GHOST_DURATION)
	_update_labels()


# --- Obstacle / power-up spawning -------------------------------------------

func _run_swap() -> void:
	_respawn_obstacles()
	_respawn_powerup()


## Replace the current obstacles with a fresh set of OBSTACLES_PER_CYCLE,
## each an even roll between charger, gravity rock, and repulsor (a gravity
## rock with the pull inverted). Leaves any power-up alone.
func _respawn_obstacles() -> void:
	_clear_obstacles()
	var occupied: Array[Vector2] = []
	for i in OBSTACLES_PER_CYCLE:
		var pos := _find_spawn_point(occupied)
		occupied.append(pos)
		var node: Node2D
		match randi() % 3:
			0:
				node = ChargerScene.instantiate()
			1:
				node = GravityRockScene.instantiate()
			_:
				node = GravityRockScene.instantiate()
				node.strength = -node.strength
		node.position = pos
		obstacle_root.add_child(node)
		_obstacles.append(node)


## Replace the floating power-up with a new random one, clear of the obstacles.
func _respawn_powerup() -> void:
	_clear_active_powerup()
	var occupied := _obstacle_points()
	var pu_pos := _find_spawn_point(occupied)
	var pu = PowerUpScene.instantiate()
	pu.kind = randi() % POWERUP_KIND_COUNT
	pu.position = pu_pos
	obstacle_root.add_child(pu)
	pu.body_entered.connect(_on_powerup_touched.bind(pu))
	_active_powerup = pu


func _obstacle_points() -> Array[Vector2]:
	var arr: Array[Vector2] = []
	for o in _obstacles:
		if is_instance_valid(o):
			arr.append(o.position)
	return arr


## Uniform random point in the central disc, away from the rim and the bars.
func _random_spawn_candidate() -> Vector2:
	var direction := Vector2.from_angle(randf_range(0.0, TAU))
	return CENTER + direction * (SPAWN_RADIUS * sqrt(randf()))


func _find_spawn_point(occupied: Array) -> Vector2:
	for _attempt in SPAWN_ATTEMPTS:
		var p := _random_spawn_candidate()
		var ok := true
		for o in occupied:
			if p.distance_to(o) < MIN_SEPARATION:
				ok = false
				break
		if ok and p.distance_to(ball.global_position) < BALL_CLEARANCE:
			ok = false
		if ok:
			return p
	# Fallback if no clear spot was found within the attempt budget.
	return _random_spawn_candidate()


func _clear_obstacles() -> void:
	for o in _obstacles:
		if is_instance_valid(o):
			o.queue_free()
	_obstacles.clear()


func _clear_active_powerup() -> void:
	if is_instance_valid(_active_powerup):
		_active_powerup.queue_free()
	_active_powerup = null


# --- HUD --------------------------------------------------------------------

func _update_labels() -> void:
	left_lives_label.text = "Lives: %d   Fouls: %d/%d" % [GameState.lives["left"], _fouls["left"], MAX_FOULS]
	right_lives_label.text = "Lives: %d   Fouls: %d/%d" % [GameState.lives["right"], _fouls["right"], MAX_FOULS]
	left_item_label.text = _item_text("left", "R")
	right_item_label.text = _item_text("right", "Q")


func _item_text(side: String, key: String) -> String:
	var kind: int = _inventory[side]
	var item_name := "-" if kind < 0 else PowerUpScript.kind_label(kind)
	return "Item: %s  [%s]" % [item_name, key]
