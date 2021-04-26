extends Camera

onready var player = get_node("../Player")
onready var room_manager = get_node("../RoomManager")
onready var tween = get_node("Tween")

var UNITS_PER_SCALE = 11

var initial_size
var initial_translation

func _on_player_death():
	# Dramatic, deep zoom out
	var new_size = size * 5
	tween.interpolate_property(
		self,
		"size",
		size,
		new_size,
		30,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	tween.start()

func _on_room_entered(prev_room: Spatial, room: Spatial, _entrance_position: Vector3, _room_count):
	if tween.is_active():
		tween.stop()

	if not prev_room:
		# Initial room
		size = initial_size
		translation = initial_translation
	else:
		# Focus on room
		var prev_room_center = prev_room.get_center()
		var room_center = Vector3(
			0,
			room_manager.ROOM_SPAWN_OFS,  # Account for rise up from floor
			0
		) + room.get_center()
		var cam_dest = translation - (prev_room_center - room_center)
		tween.interpolate_property(
			self,
			"translation",
			translation,
			cam_dest,
			1,
			Tween.TRANS_LINEAR,
			Tween.EASE_IN_OUT
		)

		# Fit room in frame
		var room_diagonal = room.get_diagonal_len()
		var scale = max(floor(room_diagonal / UNITS_PER_SCALE), 1)
		var new_size = initial_size * scale
		tween.interpolate_property(
			self,
			"size",
			size,
			new_size,
			1,
			Tween.TRANS_LINEAR,
			Tween.EASE_IN_OUT
		)

		tween.start()

func _ready():
	initial_size = size
	initial_translation = translation

	player.connect("player_death", self, "_on_player_death")
	room_manager.connect("room_entered", self, "_on_room_entered")
