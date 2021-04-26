extends MarginContainer

onready var health_bar = find_node("HealthBar")
onready var room_count_label = find_node("RoomCountLabel")
onready var tween = find_node("Tween")

func init(player, room_manager):
	player.connect("player_health_change", self, "_on_player_health_change")
	room_manager.connect("room_entered", self, "_on_room_entered")

func _on_player_health_change(new_hp: float):
	tween.interpolate_property(
		health_bar,
		"value",
		health_bar.value,
		new_hp,
		0.25,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	tween.start()

func _on_room_entered(_prev_room, _room, _entrance_position, room_count):
	if room_count_label:
		room_count_label.text = str(room_count)
