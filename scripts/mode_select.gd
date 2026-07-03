extends Control


func _on_1v1_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/maps/arena_1v1.tscn")


func _start_vs_ai(difficulty: int) -> void:
	GameState.ai_difficulty = difficulty
	get_tree().change_scene_to_file("res://scenes/maps/arena_1vai.tscn")


func _on_ai_easy_pressed() -> void:
	_start_vs_ai(GameState.AIDifficulty.EASY)


func _on_ai_medium_pressed() -> void:
	_start_vs_ai(GameState.AIDifficulty.MEDIUM)


func _on_ai_hard_pressed() -> void:
	_start_vs_ai(GameState.AIDifficulty.HARD)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
