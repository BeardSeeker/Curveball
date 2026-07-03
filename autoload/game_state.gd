extends Node

signal life_lost(side: String, lives_left: int)
signal match_over(winner_side: String)

const STARTING_LIVES := 3

enum AIDifficulty { EASY, MEDIUM, HARD }

# TODO: drive this from the actual networking setup once multiplayer lands.
var is_host: bool = true

## Difficulty used by the 1 vs AI arena; set from the mode-select screen.
var ai_difficulty: int = AIDifficulty.MEDIUM

var lives: Dictionary = {
	"left": STARTING_LIVES,
	"right": STARTING_LIVES,
}


func reset_match() -> void:
	lives["left"] = STARTING_LIVES
	lives["right"] = STARTING_LIVES


func lose_life(side: String) -> void:
	if lives[side] <= 0:
		return
	lives[side] -= 1
	life_lost.emit(side, lives[side])
	if lives[side] <= 0:
		var winner_side: String = "right" if side == "left" else "left"
		match_over.emit(winner_side)


## Extra Life power-up: grant a life. Uncapped, and ignored once a side is out.
func gain_life(side: String) -> void:
	if lives[side] <= 0:
		return
	lives[side] += 1
