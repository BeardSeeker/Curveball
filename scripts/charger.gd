extends Area2D

## A charge pad. The ball passes straight through and gains +50 speed until
## the next correct bar hit spends the charge. Charges stack.

const RADIUS := 45.0

var _time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("balls"):
		body.apply_charge()
		Sfx.play("charge")


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.72, 0.15, 0.16 + 0.1 * pulse))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(1.0, 0.72, 0.15, 0.5 + 0.3 * pulse), 3.0)
	draw_circle(Vector2.ZERO, 14.0 + 5.0 * pulse, Color(1.0, 0.85, 0.3))
