extends Spatial

const ROOMS_DIR = "res://rooms"

signal reset_game()
signal room_entered(prev_room, room, entrance_position, room_count)

enum EntranceDirection {
	NONE,
	LEFT,
	RIGHT
}

onready var loaded_rooms = get_node("LoadedRooms")
onready var player = get_node("../Player")
onready var hud = get_node("../HUD")
onready var menu = get_node("../MenuUI")

var active_room = null
var room_scene_files = []
var room_count = -1
var game_started = false

const ROOM_SPAWN_OFS = 10
const ROOM_SPAWN_SECS = 0.5
var room_spawn_tween = null

var restart_held = false
var pause_held = false

func reset():
	for loaded_room in loaded_rooms.get_children():
		loaded_room.queue_free()

	active_room = null
	room_count = -1
	player.translation = Vector3.ZERO

	var room0 = load_room(ROOMS_DIR + "/SpawnRoom.tscn")
	next_room(room0, Vector3.ZERO)
	emit_signal("reset_game")

func get_active_navmesh():
	if not active_room:
		return null
	return active_room.get_node("Navigation")

func next_room(room: Spatial, parent_exit_position: Vector3, entrance_direction = EntranceDirection.NONE):
	var spawn_position = Vector3.ZERO
	var entrance_position = Vector3.ZERO

	# Line up exit and entrance
	if parent_exit_position and entrance_direction != EntranceDirection.NONE:
		var entrance_node_name
		if entrance_direction == EntranceDirection.LEFT:
			spawn_position = active_room.right_of(parent_exit_position)
			entrance_node_name = "Entrance_Left"
		else:
			spawn_position = active_room.left_of(parent_exit_position)
			entrance_node_name = "Entrance_Right"

		entrance_position = room.get_node(entrance_node_name).translation
		spawn_position -= entrance_position

		# Move room up from below
		room.translation = spawn_position
		room.translation.y -= ROOM_SPAWN_OFS
		room_spawn_tween.interpolate_property(
			room,
			"translation",
			room.translation,
			spawn_position,
			ROOM_SPAWN_SECS,
			Tween.TRANS_LINEAR,
			Tween.EASE_IN_OUT
		)
		room_spawn_tween.start()
	else:
		# No preceding room (i.e., room 0)
		room.translation = spawn_position

	loaded_rooms.add_child(room)
	set_active_room(room, spawn_position + entrance_position)

func set_active_room(new_active_room: Spatial, entrance_position: Vector3):
	if active_room:
		active_room.disable()
		for exit in active_room.get_node("Exits").get_children():
			exit.queue_free()

	for exit in new_active_room.get_node("Exits").get_children():
		exit.connect("exited_left", self, "_on_exit_left")
		exit.connect("exited_right", self, "_on_exit_right")

	room_count += 1
	emit_signal("room_entered", active_room, new_active_room, entrance_position, room_count)
	active_room = new_active_room

func load_room(room_path: String):
	var room_resource = load(room_path)
	var inst = room_resource.instance()
	inst.init(player, room_count)
	return inst

func load_random_room(entrance_direction):
	var valid_room = false

	while true:
		var room_path = room_scene_files[randi() % len(room_scene_files)]
		var room_scene = load_room(room_path)

		valid_room = (
			entrance_direction == EntranceDirection.LEFT and room_scene.has_node("Entrance_Left")
			or entrance_direction == EntranceDirection.RIGHT and room_scene.has_node("Entrance_Right")
			or entrance_direction == EntranceDirection.NONE
		)

		if valid_room:
			return room_scene
		else:
			room_scene.queue_free()

func _on_exit_left(exit_position: Vector3):
	if not active_room.is_alert():
		var entrance_direction = EntranceDirection.RIGHT
		var room = load_random_room(entrance_direction)
		next_room(room, exit_position, entrance_direction)

func _on_exit_right(exit_position: Vector3):
	if not active_room.is_alert():
		var entrance_direction = EntranceDirection.LEFT
		var room = load_random_room(entrance_direction)
		next_room(room, exit_position, entrance_direction)

func _ready():
	randomize()

	hud.init(player, self)

	room_spawn_tween = Tween.new()
	add_child(room_spawn_tween)

	# Discover available rooms
	var dir = Directory.new()
	dir.open(ROOMS_DIR)
	dir.list_dir_begin(true)

	while true:
		var room_scene_file = dir.get_next()
		if not room_scene_file:
			break
		if room_scene_file.find("Room") == 0:
			room_scene_files.push_back(ROOMS_DIR + "/" + room_scene_file)

	connect("reset_game", player, "_on_reset")
	player.connect("player_begin", self, "_on_player_begin")
	reset()

func _on_player_begin():
	pause_held = true
	game_started = true
	menu.hide()
	hud.show()

func _process(_delta):
	if not game_started:
		return

	if Input.is_action_pressed("pause"):
		if not pause_held:
			pause_held = true
			get_tree().paused = not get_tree().paused
	else:
		pause_held = false

	if not get_tree().paused:
		if Input.is_action_pressed("restart"):
			if not restart_held:
				restart_held = true
				reset()
		else:
			restart_held = false
