extends Control

# node variables
@onready var row_label: Label = $OuterMarginContainer/MarginContainer/VBoxContainer/RowLabel
@onready var row_slider: HSlider = $OuterMarginContainer/MarginContainer/VBoxContainer/RowSlider
@onready var col_label: Label = $OuterMarginContainer/MarginContainer/VBoxContainer/ColumnLabel
@onready var col_slider: HSlider = $OuterMarginContainer/MarginContainer/VBoxContainer/ColumnSlider
@onready var mine_label: Label = $OuterMarginContainer/MarginContainer/VBoxContainer/MineLabel
@onready var mine_slider: HSlider = $OuterMarginContainer/MarginContainer/VBoxContainer/MineSlider

# local variables
var num_rows: int = 0
var num_cols: int = 0
var num_mines: int = 0

# initialize
#func _enter_tree() -> void:
#	row_label.text = "Rows: %s" % row_slider.value
#	col_label.text = "Columns: %s" % col_slider.value
#	mine_label.text = "Mines: %s" % mine_slider.value

# functions
func update_column_label(value: int) -> void:
	col_label.text = "Columns: %s" % value
func update_row_label(value: int) -> void:
	row_label.text = "Rows: %s" % value
func update_mine_label(value: int) -> void:
	mine_label.text = "Mines: %s" % value

# callbacks
func _on_custom_confirm_button_pressed() -> void:
	### we're not narrowing conversion here as the slider values are rounded to the nearest integer
	### they also step in integer increments
	@warning_ignore("narrowing_conversion")
	num_rows = row_slider.value
	@warning_ignore("narrowing_conversion")
	num_cols = col_slider.value
	@warning_ignore("narrowing_conversion")
	num_mines = mine_slider.value
	SignalBus.custom_game_pressed.emit(num_rows, num_cols, num_mines)
	self.hide()

func _on_row_slider_value_changed(value: float) -> void:
	update_row_label(value)
func _on_column_slider_value_changed(value: float) -> void:
	update_column_label(value)
func _on_mine_slider_value_changed(value: float) -> void:
	update_mine_label(value)

func _on_custom_cancel_button_pressed() -> void:
	self.hide()
