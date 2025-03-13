### Main game script for GodotSweeper by Zach Peagler
# based on the Godot minesweeper by Awf Ibrahim (@awfyboy)
extends Node

# cache nodes
@onready var custom_popup: PanelContainer = $PopupLayer/CustomPopup
@onready var game_over_popup: PanelContainer = $PopupLayer/GameOverPopup
@onready var mine_counter: Label = %MineCounter
#@onready var flag_counter: Label = %FlagCounter
@onready var timer: Timer = %Timer
@onready var time_elapsed: Label = %TimeElapsed
@onready var game_layer: CanvasLayer = $GameLayer
# enum for tile states
enum states {SAFE, CAUTION, MINE}

# preload tiles
const TILE = preload("res://scenes/tile.tscn")
## all our textures are 32x32
const GRID_SIZE: int = 32

# preload textures
const CAUTION_1 = preload("res://textures/01.png")
const CAUTION_2 = preload("res://textures/02.png")
const CAUTION_3 = preload("res://textures/03.png")
const CAUTION_4 = preload("res://textures/04.png")
const CAUTION_5 = preload("res://textures/05.png")
const CAUTION_6 = preload("res://textures/06.png")
const CAUTION_7 = preload("res://textures/07.png")
const CAUTION_8 = preload("res://textures/08.png")
const MINE = preload("res://textures/mine.png")
const MINE_SELECTED = preload("res://textures/mine_selected.png")
const FLAG = preload("res://textures/flag.png")
const HIDDEN = preload("res://textures/hidden.png")
const SAFE = preload("res://textures/safe.png")

# game vars
@export var total_rows: int = 12
@export var total_columns: int = 12
@export var total_mines: int = 20

var grid: Array[Tile] = []
var is_first_click: bool = true
var can_click: bool = true
var minutes: int = 0
var seconds: int = 0
var mine_guesses: int = 0
var difficulty: int = 0

### Functions

# initialize new game at the start of program
func _ready() -> void:
	## connect signals from bus
	SignalBus.tile_pressed.connect(on_tile_pressed)
	SignalBus.custom_game_pressed.connect(_on_custom_difficulty_selected)
	SignalBus.play_again.connect(_on_play_again)
	## start a new easy game
	_on_difficulty_button_item_selected(0)


# return the size of the viewport
func get_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

# add a tile scene onto the given position and set a virtual position
# store their references as elements of the grid
func add_tile(pos: Vector2, virtual_pos: int, row: int, column: int) -> void:
	## create new instance of a tile and add it to the root node
	var tile_instance: Tile = TILE.instantiate()
	game_layer.add_child(tile_instance)
	
	## set initial values and states of the tile
	tile_instance.position = pos
	tile_instance.virtual_pos = virtual_pos
	tile_instance.row = row
	tile_instance.column = column
	tile_instance.state = states.SAFE
	tile_instance.texture_normal = HIDDEN
	
	## store its reference as an element of the grid
	grid.append(tile_instance)


# update the time elapsed counter
func update_time() -> void:
	time_elapsed.text = "Time: %02d:%02d" % [minutes, seconds]


# update mine counter
func update_mine_guess_counter() -> void:
	## if it is the first click, make the amount of mines hidden
	## this is done because, mines are generated only after the first click
	## so edge cases like mines > total tiles need to be checked
	if is_first_click:
		mine_counter.text = "Mines: ???"
	else:
		mine_counter.text = "Mines: %s" % mine_guesses

# clear the grid and create new game
func reset_game() -> void:
	## reset default values
	is_first_click = true
	can_click = true
	minutes = 0
	seconds = 0
	mine_guesses = 0
	update_mine_guess_counter()
	update_time()
	timer.start()
	
	## ensure that the grid isn't already empty before clearing
	if grid.size() > 0:
		for i in range(grid.size()):
			var tile: Tile = grid[i]
			tile.queue_free()
		grid.clear()

# create tiles inside of the grid
func generate_tiles(rows: int, columns: int, mines: int) -> void:
	## first, reset the game
	reset_game()
	
	## add tiles to the root node and grid
	## the tile scenes are treated like abstract objects
	## they will have 'virtual positions' based on the grid
	## these positions are simply their index position on the grid array
	## columns for x-axis and rows for y-axis
	for y in range(rows):
		for x in range(columns):
			## calculate offsets for tile position
			var grid_width: int = GRID_SIZE * columns
			var grid_height: int = GRID_SIZE * rows
			var screen_width: int = get_viewport_size().x
			var screen_height: int = get_viewport_size().y
			var hor_offset: int = ((screen_width - grid_width)/2)
			var ver_offset: int = ((screen_height - grid_height)/2)
			
			## add new tile and set its position and virtual position
			var tile_pos: Vector2 = Vector2((GRID_SIZE * x) + hor_offset, (GRID_SIZE * y) + ver_offset)
			var virtual_pos: int = x + (y * columns)
			add_tile(tile_pos, virtual_pos, y, x)


# assign random tiles as mines and nearby tiles as caution tiles
# this will not be done in tile generation, it will be done on the first tile click
# this will prevent the user from accidentally selecting a mine on the first click
func assign_tiles(rows: int, columns: int, mines: int, first_tile: Tile) -> void:
	## randomly select some tiles to be mines
	## ensure that no tile can be selected more than once
	## this is done by creating a copy of the grid, shuffling it, then getting elements from the back
	var grid_copy = grid.duplicate(true)
	grid_copy.shuffle()
	
	## remove the first tile clicked and its nearby tiles from the grid_copy
	## these tiles won't be selected as mines
	first_tile.state = states.SAFE
	grid_copy.erase(first_tile)
	
	var nearby_tiles_before: Array[Tile] = get_nearby_tiles(first_tile, total_rows, total_columns)
	for nearby_tile in nearby_tiles_before:
		grid_copy.erase(nearby_tile)
	
	## prevent mine count from being greater than the maximum tiles or less than 0
	## there should at least be nine tiles that are not mines, so max is total tiles - 9
	var mine_count: int = clamp(mines, 0, (rows * columns) - 9)
	
	## update mine_guesses and total mines to ensure they match
	## mine guesses is added here because the user may have flagged a tile before mine assignment
	mine_guesses += mine_count
	total_mines = mine_count
	
	## assign some tiles as mines
	for i in range(mine_count):
		var tile: Tile = grid_copy.pop_back()
		tile.state = states.MINE
	
	## update grid to have caution tiles
	## tiles with mines next to them should be a caution tile
	## update 'mine_nearby' for each mine next to the tile
	for y in range(rows):
		for x in range(columns):
			## get current tile of this loop
			var tile: Tile = grid[x + (y * columns)]
			
			## if this tile is a mine, ignore it and immediately skip to the next iteration
			if tile.state == states.MINE:
				continue
			
			## get the tiles nearby this tile
			var nearby_tiles_after: Array[Tile] = get_nearby_tiles(tile, rows, columns)
			
			## if a nearby tile is a mine, increment 'mines_nearby' and set state to caution
			for nearby_tile in nearby_tiles_after:
				if nearby_tile.state == states.MINE:
					tile.state = states.CAUTION
					tile.mines_nearby += 1


# get the nearby tiles from the given tile
# use current row and current column of the given tile to find the nearby tiles
func get_nearby_tiles(tile: Tile, rows: int, columns: int) -> Array[Tile]:
	## get row and column of this tile
	var row: int = tile.row
	var column: int = tile.column
	
	## append nearby tiles' index to this array
	var nearby_tiles: Array[Tile] = []
	
	## all possible nearby tiles, including out-of-bounds tiles
	var top_left: int = (column - 1) + ((row - 1) * columns)
	var top: int = column + ((row - 1) * columns)
	var top_right: int = (column + 1) + ((row - 1) * columns)
	var left: int = (column - 1) + (row * columns)
	var right: int = (column + 1) + (row * columns)
	var bottom_left: int = (column - 1) + ((row + 1) * columns)
	var bottom: int = column + ((row + 1) * columns)
	var bottom_right: int = (column + 1) + ((row + 1) * columns)
	
	## the first and last tiles of each nearby row
	var left_bound: int = row * columns
	var right_bound: int = (row * columns) + columns - 1
	var top_left_bound: int = (row - 1) * columns
	var top_right_bound: int = ((row - 1) * columns) + columns - 1
	var bottom_left_bound: int = (row + 1) * columns
	var bottom_right_bound: int = ((row + 1) * columns) + columns - 1
	
	## append tiles that are within bounds of the grid
	if top_left >= 0 and top_left >= top_left_bound:
		nearby_tiles.append(grid[top_left])
	if top >= 0:
		nearby_tiles.append(grid[top])
	if top_right >= 0 and top_right <= top_right_bound:
		nearby_tiles.append(grid[top_right])
	if left >= 0 and left >= left_bound:
		nearby_tiles.append(grid[left])
	if right < (rows * columns) and right <= right_bound:
		nearby_tiles.append(grid[right])
	if bottom_left < (rows * columns) and bottom_left >= bottom_left_bound:
		nearby_tiles.append(grid[bottom_left])
	if bottom < (rows * columns):
		nearby_tiles.append(grid[bottom])
	if bottom_right < (rows * columns) and bottom_right <= bottom_right_bound:
		nearby_tiles.append(grid[bottom_right])
	
	## return the list of possible nearby tiles
	return nearby_tiles


# reveal the tile selected from the grid
func reveal_tile(tile: Tile) -> void:
	## after reveal, the tile shouldn't be clickable
	tile.is_hidden = false
	
	## update texture and do actions based on its state
	match tile.state:
		states.SAFE:
			tile.texture_normal = SAFE
		
		## if this is a mine tile, end the game and reveal all mines
		states.MINE:
			reveal_mines()
			timer.stop()
			SignalBus.game_over.emit(false, difficulty, minutes, seconds)
			can_click = false
			tile.texture_normal = MINE_SELECTED
		
		## if this is a caution tile, check the number of bombs nearby
		## you can probably just check the integer and get the texture using a string
		## I did it this way since I preload my textures anyways
		states.CAUTION:
			match tile.mines_nearby:
				1:
					tile.texture_normal = CAUTION_1
				2:
					tile.texture_normal = CAUTION_2
				3:
					tile.texture_normal = CAUTION_3
				4:
					tile.texture_normal = CAUTION_4
				5:
					tile.texture_normal = CAUTION_5
				6:
					tile.texture_normal = CAUTION_6
				7:
					tile.texture_normal = CAUTION_7
				8:
					tile.texture_normal = CAUTION_8


# reveal any tiles near this tile
# if a nearby tile is safe, recurse this function on that tile as well
# continue recursion until a caution tile is found
func reveal_nearby_tiles(tile: Tile) -> void:
	## reveal the pressed tile
	reveal_tile(tile)
	
	## if the tile is a mine tile or caution tile, stop recursion
	if tile.state == states.CAUTION or tile.state == states.MINE:
		return
	
	## otherwise, this tile is a safe tile
	## get nearby tiles
	var nearby_tiles: Array[Tile] = get_nearby_tiles(tile, total_rows, total_columns)
	
	## for each nearby tile that is hidden, recurse this function for that tile
	for nearby_tile in nearby_tiles:
		if nearby_tile.is_hidden == true:
			## if the tile was flagged, update the mine guess counter
			if nearby_tile.is_flagged:
				mine_guesses += 1
			reveal_nearby_tiles(nearby_tile)


# reveal all the mines in the grid
func reveal_mines() -> void:
	for tile in grid:
		if tile.state == states.MINE:
			tile.texture_normal = MINE
			tile.is_hidden = false


# check if the user has won
# this is done by checking if the remaining tiles are all mines
func check_win() -> bool:
	## get the remaining tiles
	var remaining_tiles: int = 0
	for tile in grid:
		if tile.is_hidden:
			remaining_tiles += 1
	
	## check if the remaining tiles and total mines are equal
	if remaining_tiles == total_mines:
		return true
	return false

# call when a tile is pressed
func on_tile_pressed(virtual_pos: int, mouse_button: int) -> void:
	## get the tile that was just pressed
	var tile: Tile = grid[virtual_pos]
	
	## check if the user can click
	if can_click:
		## if right clicked, toggle the tile flagging
		if mouse_button == MOUSE_BUTTON_RIGHT:
			if tile.texture_normal == HIDDEN:
				tile.texture_normal = FLAG
				tile.is_flagged = true
				mine_guesses -= 1
			else:
				tile.texture_normal = HIDDEN
				tile.is_flagged = false
				mine_guesses += 1
			
			## update the mine guess counter so it reflets the amount of flags
			update_mine_guess_counter()
		
		## if left clicked, reveal the tile
		## ensure tile isn't flagged and the user can press tiles
		elif mouse_button == MOUSE_BUTTON_LEFT and not tile.is_flagged:
			## if it is the first click, start assigning mines to the tiles
			## it is done here to ensure that the user's first click will never be a mine
			if is_first_click:
				assign_tiles(total_rows, total_columns, total_mines, tile)
				is_first_click = false
			
			## reveal this tile and any nearby tiles that are safe
			## repeat until it reaches a caution tile
			reveal_nearby_tiles(tile)
			
			## update the mine guess counter after a tile is pressed
			update_mine_guess_counter()
			
			## check if the user has won
			if check_win():
				## flag the remaining tiles
				for mine_tile in grid:
					if mine_tile.is_hidden:
						mine_tile.texture_normal = FLAG
						mine_tile.is_flagged = true
				
				mine_guesses = 0
				SignalBus.game_over.emit(true, difficulty, minutes, seconds)
				timer.stop()
				can_click = false


### Callbacks
func _on_custom_game_button_pressed() -> void:
	if !custom_popup.is_visible_in_tree():
		custom_popup.show()
	else:
		custom_popup.hide()

func _on_timer_timeout() -> void:
	seconds += 1
	if seconds >= 60:
		minutes += 1
		seconds = 0
	update_time()

func _on_difficulty_button_item_selected(index: int) -> void:
	## easy
	match index:
		0:
			total_rows = 10
			total_columns = 10
			total_mines = 12
			difficulty = 0
			generate_tiles(total_rows, total_columns, total_mines)
	## medium
		1:
			total_rows = 16
			total_columns = 12
			total_mines = 25
			difficulty = 1
			generate_tiles(total_rows, total_columns, total_mines)
	## hard
		2:
			total_rows = 18
			total_columns = 16
			total_mines = 40
			difficulty = 2
			generate_tiles(total_rows, total_columns, total_mines)

func _on_custom_difficulty_selected(rows: int, cols: int, mines: int) -> void:
	total_rows = rows
	total_columns = cols
	total_mines = mines
	difficulty = 3
	generate_tiles(total_rows, total_columns, total_mines)

func _on_play_again(diff):
	# if the difficulty is custom, call custom difficulty function with cached vars
	if diff == 3:
		_on_custom_difficulty_selected(total_rows, total_columns, total_mines)
	else:
		_on_difficulty_button_item_selected(diff)
