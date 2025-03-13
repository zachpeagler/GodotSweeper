class_name Tile extends TextureButton

var virtual_pos: int = 0
var row: int = 0
var column: int = 0
var state: int = 0
var mines_nearby: int = 0
var is_hidden: bool = true
var is_flagged: bool = false


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and is_hidden:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				SignalBus.tile_pressed.emit(virtual_pos, MOUSE_BUTTON_LEFT)
			MOUSE_BUTTON_RIGHT:
				SignalBus.tile_pressed.emit(virtual_pos, MOUSE_BUTTON_RIGHT)
