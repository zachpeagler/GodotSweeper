extends PanelContainer

@onready var game_over_message: Label = $OuterMarginContainer/MarginContainer/VBoxContainer/GameOverMessage
@onready var difficulty_label: Label = $OuterMarginContainer/MarginContainer/VBoxContainer/DifficultyLabel
@onready var final_time_label: Label = $OuterMarginContainer/MarginContainer/VBoxContainer/FinalTimeLabel

var diff: int = 0

func _ready() -> void:
	SignalBus.game_over.connect(_on_game_over)
	
# callbacks

func _on_game_over(won, difficulty, minutes, seconds):
	self.show()
	diff = difficulty
	match difficulty:
		0:
			difficulty_label.text = "Difficulty: Easy"
		1:
			difficulty_label.text = "Difficulty: Medium"
		2:
			difficulty_label.text = "Difficulty: Hard"
		3:
			difficulty_label.text = "Difficulty: Custom"
	if won == true:
		game_over_message.text = "You Won!"
	else:
		game_over_message.text = "You Lost!"
	final_time_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_play_again_button_pressed() -> void:
	SignalBus.play_again.emit(diff)
	self.hide()
