extends Node

signal tile_pressed(virtual_pos: int, mouse_button: int)
signal custom_game_pressed(rows: int, columns: int, mines: int)
signal game_over(won: bool, difficulty: int, minutes: int, seconds: int)
signal play_again(difficulty: int)
