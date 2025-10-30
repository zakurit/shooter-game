extends Control

func _process(delta):
	$Label.text = "Red: %d   Blue: %d" % [GameState.scores["red"], GameState.scores["blue"]]
