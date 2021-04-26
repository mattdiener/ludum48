extends Camera

onready var room_manager = get_node("../RoomManager")
onready var tween = get_node("Tween")

var UNITS_PER_SCALE = 11

var base_size;

func _on_room_entered(prev_room: Spatial, room: Spatial, _entrance_position: Vector3, _room_count):
	if prev_room:
		# Focus on room
		var prev_room_center = prev_room.get_center()
		var room_center = room.get_center()
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
		var new_size = base_size * scale
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
	base_size = size
	room_manager.connect("room_entered", self, "_on_room_entered")
