extends MarginContainer

onready var health_bar = find_node("HealthBar")
onready var tween = find_node("Tween")

func init(player):
	player.connect("player_health_change", self, "_on_player_health_change")

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
