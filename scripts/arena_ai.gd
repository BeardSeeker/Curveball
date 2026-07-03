extends "res://scripts/arena_1v1.gd"

## 1 vs AI: identical rules to the 1v1 arena, but the right (red) bar is
## driven by an interception AI with three difficulty levels
## (GameState.ai_difficulty). The AI predicts the ball's rim crossing (the
## same straight-line projection the landing marker uses), so curve and
## gravity rocks genuinely fool it.

const AI_SIDE := "right"

## Per-difficulty tuning, indexed by GameState.AIDifficulty:
## reaction    - seconds between re-plans (thinking speed)
## noise       - random aim error (radians) added to every plan
## speed       - fraction of full bar speed the AI is allowed to use
## aim         - how far off-center it tries to catch the ball (edge shots
##               aimed away from the player); 0 = plain center returns
## item_chance - probability per plan to fire a held power-up blindly
## smart_items - wait for the right moment instead of firing blindly
const DIFFICULTIES := [
	{"reaction": 0.5, "noise": 0.22, "speed": 0.55, "aim": 0.0, "item_chance": 0.06, "smart_items": false},
	{"reaction": 0.28, "noise": 0.1, "speed": 0.8, "aim": 0.35, "item_chance": 0.2, "smart_items": false},
	{"reaction": 0.1, "noise": 0.03, "speed": 1.0, "aim": 0.7, "item_chance": 1.0, "smart_items": true},
]

var _cfg: Dictionary
var _plan_timer := 0.0
var _ai_target := 0.0
var _ai_has_target := false


func _ready() -> void:
	_cfg = DIFFICULTIES[clampi(GameState.ai_difficulty, 0, DIFFICULTIES.size() - 1)]
	right_bar.player_controlled = false
	super()


## The AI has no keyboard: only P1's activation key is live.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause_menu()
	elif event.is_action_pressed("p1_activate"):
		_activate_powerup("left")


func _update_labels() -> void:
	super()
	right_item_label.text = _item_text(AI_SIDE, "AI")


func _physics_process(delta: float) -> void:
	super(delta)
	_ai_think(delta)


# --- AI driving ---------------------------------------------------------------

func _ai_think(delta: float) -> void:
	if get_tree().paused:
		return
	if not _round_active or ball.freeze:
		right_bar.ai_direction = 0.0
		return
	_plan_timer -= delta
	if _plan_timer <= 0.0:
		_plan_timer = _cfg.reaction
		_plan()
	_steer()


## Re-plan: pick a target angle on the rim, with difficulty-scaled aim error.
func _plan() -> void:
	var hit := _predict_rim_crossing()
	if hit == Vector2.INF:
		_ai_has_target = false
		return
	var crossing := (hit - CENTER).angle()
	if ball.pending_side == AI_SIDE:
		# Intercept off-center: the ball then lands near the arc's edge, which
		# tilts the return toward that edge - aimed away from the player.
		var exit_base := wrapf(crossing + PI, -PI, PI)
		var away: float = wrapf(exit_base - left_bar.angle, -PI, PI)
		var edge_sign := 1.0 if away >= 0.0 else -1.0
		_ai_target = crossing - edge_sign * _cfg.aim * right_bar.scaled_half_arc()
	else:
		# Player's turn: park across from where the ball will land - out of
		# fouling range and central for the next interception.
		_ai_target = crossing + PI
	_ai_target = wrapf(_ai_target + randf_range(-_cfg.noise, _cfg.noise), -PI, PI)
	_ai_has_target = true
	_consider_item()


func _steer() -> void:
	if not _ai_has_target:
		right_bar.ai_direction = 0.0
		return
	var diff := wrapf(_ai_target - right_bar.angle, -PI, PI)
	if absf(diff) < 0.02:
		right_bar.ai_direction = 0.0
		return
	# Full speed far away, easing near the target so it doesn't jitter.
	right_bar.ai_direction = clampf(diff / 0.15, -1.0, 1.0) * _cfg.speed


func _consider_item() -> void:
	var kind: int = _inventory[AI_SIDE]
	if kind < 0:
		return
	if not _cfg.smart_items:
		if randf() < _cfg.item_chance:
			_activate_powerup(AI_SIDE)
		return
	# Hard AI picks its moment.
	match kind:
		PowerUpScript.Kind.EXTRA_LIFE:
			_activate_powerup(AI_SIDE)
		PowerUpScript.Kind.SHRINK, PowerUpScript.Kind.REVERSE:
			# Debuffs matter while the player is the one who has to hit.
			if ball.pending_side == "left":
				_activate_powerup(AI_SIDE)
		PowerUpScript.Kind.GHOST:
			# Vanish the ball while it is far from the player's catch point.
			if ball.pending_side == "left" and ball.global_position.distance_to(CENTER) < ARENA_RADIUS * 0.6:
				_activate_powerup(AI_SIDE)
